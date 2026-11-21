"""Tests for per-exercise next-week progression."""

from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    Exercise,
    PlanExercise,
    Profile,
    Program,
    ProgramDay,
    SetLog,
    User,
    WorkoutSession,
)
from app.services.coach_control import runtime
from app.services.coach_control.insights import build_readonly_context
from app.services.coach_control.progression import build_plan


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
    session.add(User(id="user-1"))
    session.add(Profile(user_id="user-1", nickname="小林"))
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _program(db, *, weight: float = 80) -> Program:
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    db.add(
        Exercise(
            slug="bench-press",
            name_zh="杠铃卧推",
            muscle_group="chest",
            equipment="barbell",
            is_compound=True,
            contraindications=[],
        )
    )
    program = Program(
        user_id="user-1",
        title="测试计划",
        goal_type="build_muscle",
        version=1,
        status="active",
        start_date=monday,
        weeks=4,
    )
    db.add(program)
    db.flush()
    day = ProgramDay(
        program_id=program.id,
        week_index=2,
        weekday=1,
        title="胸日",
    )
    db.add(day)
    db.flush()
    db.add(
        PlanExercise(
            program_day_id=day.id,
            exercise_slug="bench-press",
            order_index=1,
            sets=3,
            reps="8-12",
            weight_kg=weight,
            rest_sec=120,
        )
    )
    db.commit()
    db.refresh(program)
    return program


def _bodyweight_program(db) -> Program:
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    monday = today - timedelta(days=today.weekday())
    db.add(
        Exercise(
            slug="air-squat",
            name_zh="徒手深蹲",
            muscle_group="legs",
            equipment="bodyweight",
            training_type_code="strength",
            is_compound=True,
            contraindications=[],
        )
    )
    program = Program(
        user_id="user-1",
        title="测试自重计划",
        goal_type="build_muscle",
        version=1,
        status="active",
        start_date=monday,
        weeks=4,
    )
    db.add(program)
    db.flush()
    day = ProgramDay(
        program_id=program.id,
        week_index=2,
        weekday=1,
        title="腿日",
    )
    db.add(day)
    db.flush()
    db.add(
        PlanExercise(
            program_day_id=day.id,
            exercise_slug="air-squat",
            order_index=1,
            sets=3,
            reps="12-15",
            weight_kg=None,
            rest_sec=60,
        )
    )
    db.commit()
    db.refresh(program)
    return program


def _bodyweight_session(db, *, reps: int, rpe: float) -> None:
    session = WorkoutSession(
        user_id="user-1",
        started_at=datetime.now(ZoneInfo("Asia/Shanghai")) - timedelta(days=2),
        duration_min=30,
    )
    db.add(session)
    db.flush()
    for index in range(1, 4):
        db.add(
            SetLog(
                session_id=session.id,
                exercise_slug="air-squat",
                set_index=index,
                weight_kg=0,
                reps=reps,
                rpe=rpe,
                completed=True,
            )
        )
    db.commit()


def _last_session(db, *, reps: int, rpe: float) -> None:
    session = WorkoutSession(
        user_id="user-1",
        started_at=datetime.now(ZoneInfo("Asia/Shanghai")) - timedelta(days=2),
        duration_min=60,
    )
    db.add(session)
    db.flush()
    for index in range(1, 4):
        db.add(
            SetLog(
                session_id=session.id,
                exercise_slug="bench-press",
                set_index=index,
                weight_kg=80,
                reps=reps,
                rpe=rpe,
                completed=True,
            )
        )
    db.commit()


def test_progression_raises_weight_after_top_reps_at_moderate_rpe(db):
    program = _program(db)
    _last_session(db, reps=12, rpe=8)

    plan = build_plan(db, "user-1", program)

    assert plan["ready"] is True
    target = plan["targets"][0]
    assert target["action"] == "up"
    assert target["target_weight_kg"] == 82.5


def test_progression_lowers_weight_after_rpe_nine(db):
    program = _program(db)
    _last_session(db, reps=10, rpe=9)

    plan = build_plan(db, "user-1", program)

    target = plan["targets"][0]
    assert target["action"] == "down"
    assert target["target_weight_kg"] == 75.0


def test_progression_facts_are_injected_for_coach_answer(db):
    program = _program(db)
    _last_session(db, reps=12, rpe=8)

    context = build_readonly_context(
        db,
        "user-1",
        "下周卧推加多少",
        program,
    )

    assert context is not None
    assert "下周进阶建议" in context
    assert "80→82.5kg" in context


def test_next_week_question_stays_read_only(db):
    import asyncio

    _program(db)
    _last_session(db, reps=12, rpe=8)

    result = asyncio.run(
        runtime.handle_turn(db, "user-1", "下周卧推加多少")
    )

    assert result["intent"] == "coach.answer"
    assert result["pending"] is None


def test_progression_apply_card_updates_and_undoes(db):
    _program(db)
    _last_session(db, reps=12, rpe=8)

    import asyncio

    turn = asyncio.run(
        runtime.handle_turn(db, "user-1", "帮我按建议改下周")
    )

    assert turn["intent"] == "training.edit_day_exercise"
    assert turn["pending"]["kind"] == "proposal"
    confirmed = runtime.confirm_pending(db, "user-1", turn["pending"]["id"])
    day = db.get(ProgramDay, turn["pending"]["payload"]["day_id"])
    assert float(day.exercises[0].weight_kg) == 82.5

    runtime.undo_action(db, "user-1", confirmed["action_id"])
    db.refresh(day)
    assert float(day.exercises[0].weight_kg) == 80.0


def test_bodyweight_progression_adds_reps_at_top_of_range(db):
    program = _bodyweight_program(db)
    _bodyweight_session(db, reps=15, rpe=8)

    plan = build_plan(db, "user-1", program)

    target = next(
        item for item in plan["targets"] if item["slug"] == "air-squat"
    )
    assert target["action"] == "up"
    assert target["kind"] == "reps"
    assert target["target_reps"] == "12-17"


def test_bodyweight_progression_reduces_sets_when_rpe_is_high(db):
    program = _bodyweight_program(db)
    _bodyweight_session(db, reps=10, rpe=9)

    plan = build_plan(db, "user-1", program)

    target = next(
        item for item in plan["targets"] if item["slug"] == "air-squat"
    )
    assert target["action"] == "down"
    assert target["kind"] == "sets"
    assert target["target_sets"] == 2
