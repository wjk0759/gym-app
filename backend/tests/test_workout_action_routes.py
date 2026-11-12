import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    AgentActionEvent,
    Exercise,
    PlanExercise,
    Profile,
    Program,
    ProgramDay,
    User,
)
from app.routers.agent import (
    execute_workout_action,
    undo_workout_action,
)
from app.schemas import WorkoutActionChangeIn, WorkoutActionExecuteIn


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
    db.add(
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
        )
    )
    db.commit()


def _payload() -> WorkoutActionExecuteIn:
    return WorkoutActionExecuteIn(
        plan_id="plan-1",
        day_id="day-1",
        expected_plan_version=3,
        changes=[
            WorkoutActionChangeIn(
                op="swap",
                from_slug="bench_press",
                to_slug="dumbbell_press",
            ),
            WorkoutActionChangeIn(
                op="sets",
                slug="dumbbell_press",
                sets=2,
            ),
        ],
    )


def test_execute_is_idempotent_and_undo_restores(db, seeded):
    first = execute_workout_action(
        "action-1",
        _payload(),
        "user-1",
        db,
    )
    assert first["status"] == "executed"
    assert first["program"]["version"] == 4
    assert first["program"]["days"][0]["exercises"][0]["slug"] == "dumbbell_press"

    second = execute_workout_action(
        "action-1",
        _payload(),
        "user-1",
        db,
    )
    assert second["idempotent"] is True
    assert second["program"]["version"] == 4

    events = db.execute(select(AgentActionEvent)).scalars().all()
    assert len(events) == 1
    assert events[0].detail["server_executed"] is True

    undone = undo_workout_action("action-1", "user-1", db)
    assert undone["status"] == "undone"
    assert undone["program"]["version"] == 5
    assert undone["program"]["days"][0]["exercises"][0]["slug"] == "bench_press"
    assert db.get(AgentActionEvent, events[0].id).status == "undone"
