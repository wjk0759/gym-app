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
    User,
)
from app.services.workout_actions import (
    WorkoutActionConflict,
    WorkoutActionError,
    execute_modify_workout,
    prepare_modify_workout,
    undo_modify_workout,
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
    db.add(User(id="user-1"))
    db.add(
        Profile(
            user_id="user-1",
            equipment=["bodyweight", "barbell", "dumbbell", "machine"],
        )
    )
    db.add_all(
        [
            Exercise(
                slug="bench_press",
                name_zh="杠铃卧推",
                muscle_group="chest",
                equipment="barbell",
            ),
            Exercise(
                slug="dumbbell_press",
                name_zh="哑铃卧推",
                muscle_group="chest",
                equipment="dumbbell",
            ),
            Exercise(
                slug="seated_row",
                name_zh="坐姿划船",
                muscle_group="back",
                equipment="machine",
            ),
        ]
    )
    db.add(
        Program(
            id="plan-1",
            user_id="user-1",
            title="测试计划",
            goal_type="build_muscle",
            version=3,
            weeks=4,
        )
    )
    db.add(
        ProgramDay(
            id="day-1",
            program_id="plan-1",
            week_index=1,
            weekday=1,
            title="上肢",
            focus=["chest"],
        )
    )
    db.add_all(
        [
            PlanExercise(
                id="pe-1",
                program_day_id="day-1",
                exercise_slug="bench_press",
                order_index=1,
                sets=4,
                reps="8-10",
                weight_kg=60,
                rest_sec=120,
                rpe=7.5,
            ),
            PlanExercise(
                id="pe-2",
                program_day_id="day-1",
                exercise_slug="seated_row",
                order_index=2,
                sets=3,
                reps="10-12",
                weight_kg=40,
                rest_sec=90,
                rpe=7.5,
            ),
        ]
    )
    db.commit()
    return db


def test_prepare_and_execute_swap_and_sets(db, seeded):
    program, day, before, after = prepare_modify_workout(
        db,
        "user-1",
        plan_id="plan-1",
        day_id="day-1",
        changes=[
            {
                "op": "swap",
                "from_slug": "bench_press",
                "to_slug": "dumbbell_press",
            },
            {"op": "sets", "slug": "dumbbell_press", "sets": 2},
            {"op": "weight", "slug": "dumbbell_press", "weight_kg": 20},
        ],
        expected_plan_version=3,
    )
    assert program.version == 3
    assert day.id == "day-1"
    assert len(before) == 2
    assert after[0]["slug"] == "dumbbell_press"
    assert after[0]["sets"] == 2
    assert after[0]["weight_kg"] == 20

    result, before_snapshot, after_version = execute_modify_workout(
        db,
        "user-1",
        plan_id="plan-1",
        day_id="day-1",
        changes=[
            {
                "op": "swap",
                "from_slug": "bench_press",
                "to_slug": "dumbbell_press",
            },
            {"op": "sets", "slug": "dumbbell_press", "sets": 2},
        ],
        expected_plan_version=3,
    )
    assert result["version"] == 4
    assert after_version == 4
    assert result["days"][0]["exercises"][0]["slug"] == "dumbbell_press"
    assert result["days"][0]["exercises"][0]["sets"] == 2
    assert before_snapshot[0]["slug"] == "bench_press"

    restored = undo_modify_workout(
        db,
        "user-1",
        plan_id="plan-1",
        day_id="day-1",
        before=before_snapshot,
        expected_version=4,
    )
    assert restored["version"] == 5
    assert restored["days"][0]["exercises"][0]["slug"] == "bench_press"


def test_prepare_rejects_version_conflict(db, seeded):
    with pytest.raises(WorkoutActionConflict):
        prepare_modify_workout(
            db,
            "user-1",
            plan_id="plan-1",
            day_id="day-1",
            changes=[{"op": "sets", "slug": "bench_press", "sets": 2}],
            expected_plan_version=2,
        )


def test_prepare_rejects_bad_changes(db, seeded):
    with pytest.raises(WorkoutActionError):
        prepare_modify_workout(
            db,
            "user-1",
            plan_id="plan-1",
            day_id="day-1",
            changes=[{"op": "swap", "from_slug": "bench_press", "to_slug": "missing"}],
        )
    with pytest.raises(WorkoutActionError):
        prepare_modify_workout(
            db,
            "user-1",
            plan_id="plan-1",
            day_id="day-1",
            changes=[
                {"op": "remove", "slug": "bench_press"},
                {"op": "remove", "slug": "seated_row"},
            ],
        )
