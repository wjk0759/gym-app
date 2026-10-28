import json
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    AIMemory,
    BodyMetric,
    EquipmentLibraryItem,
    Exercise,
    FoodLog,
    Goal,
    PlanDayState,
    PlanExercise,
    Profile,
    Program,
    ProgramDay,
    SetLog,
    User,
    WorkoutSession,
)
from app.services.coach_context import (
    CONTEXT_VERSION,
    build_coach_context,
    context_as_text,
)


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    session = Session()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture()
def seeded(db):
    now = datetime.now(timezone.utc)
    today = now.date()
    db.add(User(id="user-1"))
    db.add(
        Profile(
            user_id="user-1",
            nickname="小林",
            sex="male",
            birth_date=today.replace(year=today.year - 28),
            height_cm=178,
            weight_kg=72,
            experience="intermediate",
            injuries=["knee_pain"],
            equipment=["bodyweight", "dumbbell"],
            weekly_days=3,
            session_minutes=50,
            onboarded_at=now,
        )
    )
    db.add(
        Goal(
            id="goal-1",
            user_id="user-1",
            type="build_muscle",
            target_weight_kg=76,
            status="active",
        )
    )
    db.add(
        Exercise(
            slug="goblet-squat",
            name_zh="高脚杯深蹲",
            muscle_group="legs",
            equipment="dumbbell",
            is_compound=True,
            contraindications=[],
        )
    )
    db.add(
        Program(
            id="program-1",
            user_id="user-1",
            title="增肌基础 4 周",
            goal_type="build_muscle",
            version=2,
            status="active",
            start_date=today,
            weeks=4,
            generated_by="ai",
        )
    )
    db.add(
        ProgramDay(
            id="day-1",
            program_id="program-1",
            week_index=1,
            weekday=today.isoweekday(),
            title="下肢力量",
            focus=["legs"],
        )
    )
    db.add(
        PlanExercise(
            id="plan-ex-1",
            program_day_id="day-1",
            exercise_slug="goblet-squat",
            order_index=1,
            sets=4,
            reps="8-10",
            weight_kg=24,
            rest_sec=90,
            rpe=7,
        )
    )
    db.add(
        PlanDayState(
            user_id="user-1",
            plan_id="program-1",
            day_id="day-1",
            plan_version=2,
            assigned_date=today,
            client_updated_at=now,
        )
    )
    session = WorkoutSession(
        id="session-1",
        user_id="user-1",
        program_day_id="day-1",
        started_at=now - timedelta(days=1),
        finished_at=now - timedelta(days=1) + timedelta(minutes=50),
        duration_min=50,
        feeling=4,
    )
    db.add(session)
    db.add_all(
        [
            SetLog(
                session_id=session.id,
                exercise_slug="goblet-squat",
                set_index=1,
                weight_kg=24,
                reps=10,
                rpe=7,
                completed=True,
            ),
            SetLog(
                session_id=session.id,
                exercise_slug="goblet-squat",
                set_index=2,
                weight_kg=24,
                reps=9,
                rpe=8,
                completed=True,
            ),
        ]
    )
    db.add(
        FoodLog(
            user_id="user-1",
            client_id="food-1",
            logged_at=now - timedelta(days=1),
            meal="lunch",
            food_name="鸡胸饭",
            grams=350,
            kcal=620,
            protein=48,
            carbs=70,
            fat=14,
            fiber=6,
        )
    )
    db.add(
        BodyMetric(
            user_id="user-1",
            client_id="body-1",
            measured_at=now - timedelta(days=1),
            weight_kg=72,
            body_fat_pct=16,
            waist_cm=80,
        )
    )
    db.add(
        AIMemory(
            user_id="user-1",
            kind="schedule",
            memory_key="weekly_schedule",
            content="用户每周二、四、六训练，每次 50 分钟",
            active=True,
        )
    )
    db.add(
        EquipmentLibraryItem(
            user_id="user-1",
            client_id="equipment-1",
            name="可调哑铃",
            slug="adjustable-dumbbell",
            muscle="full_body",
            equipment="dumbbell",
            notes="家里有一对 5-25kg",
        )
    )
    db.commit()
    return now


def test_context_has_version_and_profile(db, seeded):
    now = datetime.now(timezone.utc)
    context = build_coach_context(db, "user-1", now=now)

    assert context["version"] == CONTEXT_VERSION
    assert context["needs_profile"] is False
    assert context["profile"]["nickname"] == "小林"
    assert context["profile"]["equipment"] == ["bodyweight", "dumbbell"]
    assert context["today"]["date"] == now.date().isoformat()
    json.dumps(context, ensure_ascii=False)


def test_context_contains_current_plan_week(db, seeded):
    context = build_coach_context(db, "user-1")

    plan = context["current_plan"]
    assert plan["id"] == "program-1"
    assert plan["version"] == 2
    assert plan["current_week"] == 1
    assert plan["days"][0]["title"] == "下肢力量"
    assert plan["days"][0]["exercises"][0]["name_zh"] == "高脚杯深蹲"
    assert plan["day_states"][0]["day_id"] == "day-1"
    assert plan["day_states"][0]["skipped"] is False


def test_context_contains_recent_training(db, seeded):
    context = build_coach_context(db, "user-1")

    training = context["recent_training"]
    assert training["session_count"] == 1
    assert training["completed_sets"] == 2
    assert training["total_volume_kg"] == 456
    assert training["recent_sessions"][0]["set_count"] == 2


def test_context_contains_nutrition_and_body_metrics(db, seeded):
    context = build_coach_context(db, "user-1")

    assert context["nutrition_7d"]["logged_days"] == 1
    assert context["nutrition_7d"]["protein_g"] == 48
    assert context["body_metrics"][0]["weight_kg"] == 72
    assert context["body_metrics"][0]["waist_cm"] == 80


def test_context_contains_memories_equipment_and_app_context(db, seeded):
    app_context = {
        "selected_tab": "coach",
        "plan": {"days": [{"id": "day-1", "title": "下肢力量"}]},
    }
    context = build_coach_context(db, "user-1", app_context=app_context)

    assert context["app_context"] == app_context
    assert context["memories"][0]["key"] == "weekly_schedule"
    assert context["equipment_library"][0]["name"] == "可调哑铃"
    assert "每周二、四、六" in context_as_text(context)


def test_context_without_profile_is_honest(db):
    db.add(User(id="user-2"))
    db.commit()

    context = build_coach_context(db, "user-2")

    assert context["needs_profile"] is True
    assert context["version"] == CONTEXT_VERSION
    assert "profile" not in context
    assert "memory" not in context
