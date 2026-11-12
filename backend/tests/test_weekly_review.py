from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    Exercise,
    PlanDayState,
    PlanExercise,
    Profile,
    Program,
    ProgramDay,
    SetLog,
    User,
    WorkoutSession,
)
from app.services.agent import REVIEW_TZ, _plan_week_adherence


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


def _local(year: int, month: int, day: int, hour: int = 8) -> datetime:
    return datetime(year, month, day, hour, tzinfo=REVIEW_TZ)


def test_plan_week_adherence_uses_schedule_and_skips(db):
    monday = _local(2026, 11, 9)
    tuesday = _local(2026, 11, 10)
    now = _local(2026, 11, 12, 12)
    week_start = monday.astimezone(timezone.utc)

    db.add(User(id="user-1"))
    db.add(Profile(user_id="user-1", nickname="小林", weekly_days=3))
    db.add(
        Program(
            id="program-1",
            user_id="user-1",
            title="测试计划",
            goal_type="build_muscle",
            version=1,
            status="active",
            start_date=monday.date(),
            weeks=4,
            generated_by="template",
            created_at=monday,
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
    day_ids = ["day-mon", "day-tue", "day-wed"]
    for index, day_id in enumerate(day_ids):
        day = ProgramDay(
            id=day_id,
            program_id="program-1",
            week_index=1,
            weekday=index + 1,
            title=f"训练{index + 1}",
            focus=["legs"],
        )
        day.exercises.append(
            PlanExercise(
                exercise_slug="goblet-squat",
                order_index=1,
                sets=3,
                reps="10",
                weight_kg=24,
                rest_sec=90,
                rpe=7,
            )
        )
        db.add(day)
        db.add(
            PlanDayState(
                user_id="user-1",
                plan_id="program-1",
                day_id=day_id,
                plan_version=1,
                assigned_date=monday.date() + timedelta(days=index),
                skipped_at=tuesday if index == 1 else None,
                client_updated_at=now,
            )
        )
    session = WorkoutSession(
        id="session-1",
        user_id="user-1",
        program_day_id="day-mon",
        started_at=monday.astimezone(timezone.utc) + timedelta(hours=9),
        duration_min=40,
        feeling=3,
    )
    db.add(session)
    db.add_all(
        [
            SetLog(
                session_id=session.id,
                exercise_slug="goblet-squat",
                set_index=index,
                weight_kg=24,
                reps=10,
                rpe=8,
                completed=True,
            )
            for index in range(1, 4)
        ]
    )
    db.commit()

    result = _plan_week_adherence(
        db,
        db.get(Program, "program-1"),
        "user-1",
        week_start,
        week_start + timedelta(days=7),
        now,
    )

    assert result["planned"] == 3
    assert result["completed"] == 1
    assert result["skipped"] == 1
    assert result["missed"] == 1
    assert result["rate"] == 0.5
