"""Regression tests for the read-only coach insight context."""

import asyncio
from datetime import date, datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    Exercise,
    FoodLog,
    PlanExercise,
    Profile,
    Program,
    ProgramDay,
    SetLog,
    User,
    WorkoutSession,
)
from app.services.coach_control.capabilities import coach_answer
from app.services.coach_control.insights import _window_for, build_readonly_context


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session = sessionmaker(
        bind=engine,
        autoflush=False,
        expire_on_commit=False,
    )()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture()
def seeded(db):
    now = datetime.now(timezone.utc)
    db.add(User(id="user-1"))
    db.add(
        Profile(
            user_id="user-1",
            nickname="小林",
            sex="male",
            birth_date=date(1995, 1, 1),
            height_cm=175,
            weight_kg=72,
            experience="beginner",
            training_stage="beginner",
            equipment=["dumbbell"],
            weekly_days=3,
            session_minutes=60,
            onboarded_at=now,
        )
    )
    db.add(
        Exercise(
            slug="squat",
            name_zh="深蹲",
            muscle_group="legs",
            equipment="barbell",
        )
    )
    program = Program(
        id="program-1",
        user_id="user-1",
        title="4 周增肌计划",
        goal_type="build_muscle",
        status="active",
        start_date=date(2026, 11, 17),
        weeks=4,
    )
    db.add(program)
    db.flush()
    for weekday, title in ((1, "全身 A"), (3, "全身 B"), (5, "全身 C")):
        day = ProgramDay(
            id=f"day-{weekday}",
            program_id=program.id,
            week_index=1,
            weekday=weekday,
            title=title,
            focus=["legs"],
        )
        db.add(day)
        db.flush()
        db.add(
            PlanExercise(
                program_day_id=day.id,
                exercise_slug="squat",
                order_index=1,
                sets=3,
                reps="10",
                rest_sec=90,
            )
        )

    first = WorkoutSession(
        id="session-1",
        user_id="user-1",
        started_at=now - timedelta(days=1),
        duration_min=45,
    )
    second = WorkoutSession(
        id="session-2",
        user_id="user-1",
        started_at=now - timedelta(days=3),
        duration_min=40,
    )
    db.add_all([first, second])
    db.add_all(
        [
            SetLog(
                session_id=first.id,
                exercise_slug="squat",
                set_index=1,
                weight_kg=60,
                reps=10,
                completed=True,
            ),
            SetLog(
                session_id=first.id,
                exercise_slug="squat",
                set_index=2,
                weight_kg=60,
                reps=8,
                completed=True,
            ),
            SetLog(
                session_id=second.id,
                exercise_slug="squat",
                set_index=1,
                weight_kg=70,
                reps=5,
                completed=True,
            ),
        ]
    )
    db.add_all(
        [
            FoodLog(
                user_id="user-1",
                client_id="food-1",
                logged_at=now,
                meal="lunch",
                food_name="鸡胸肉",
                grams=200,
                kcal=500,
                protein=30,
                carbs=10,
                fat=8,
            ),
            FoodLog(
                user_id="user-1",
                client_id="food-2",
                logged_at=now - timedelta(hours=2),
                meal="breakfast",
                food_name="燕麦",
                grams=80,
                kcal=300,
                protein=10,
                carbs=50,
                fat=5,
            ),
        ]
    )
    db.commit()
    return program


def test_training_question_uses_actual_sessions_and_exercise(db, seeded):
    context = build_readonly_context(
        db,
        "user-1",
        "我最近训练了几次，深蹲有进步吗",
        seeded,
    )

    assert context is not None
    assert "训练（最近 28 天）：2 次" in context
    assert "3 组" in context
    assert "深蹲" in context
    assert "1430 kg" in context


def test_nutrition_question_totals_food_logs(db, seeded):
    context = build_readonly_context(db, "user-1", "我最近饮食怎么样", seeded)

    assert context is not None
    assert "饮食（最近 7 天）" in context
    assert "800 kcal" in context
    assert "蛋白质 40 g" in context


def test_plan_question_describes_week_structure(db, seeded):
    context = build_readonly_context(db, "user-1", "为什么这样安排计划", seeded)

    assert context is not None
    assert "4 周增肌计划" in context
    assert "每周 3 练" in context
    assert "全身 A" in context


def test_profile_question_lists_missing_fields(db, seeded):
    context = build_readonly_context(db, "user-1", "帮我看看档案还缺什么", seeded)

    assert context is not None
    assert "训练目标" in context
    assert "伤病记录：无" in context


def test_last_week_is_a_calendar_window():
    window = _window_for("我上周练了几次", 7)

    assert window.label == "上周"
    assert window.end.weekday() == 0
    assert (window.end - window.start).days == 7


def test_coach_answer_injects_ledger_facts(db, seeded, monkeypatch):
    captured: dict[str, str | None] = {}

    async def fake_reply(db, profile, program, history, message, **kwargs):
        captured["context"] = kwargs.get("context")
        return {"reply": "ok", "safety_flag": None}

    monkeypatch.setattr(coach_answer, "coach_reply", fake_reply)
    profile = db.get(Profile, "user-1")
    result = asyncio.run(
        coach_answer.resolve(
            db,
            profile,
            seeded,
            [],
            "我最近训练了几次",
        )
    )

    assert result["reply"] == "ok"
    assert captured["context"] is not None
    assert "训练（最近 28 天）：2 次" in captured["context"]
