from datetime import datetime, timedelta

from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

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
from app.services import training_stage
from app.services.load_progression import (
    adjustment_multipliers,
    apply_plan_weights,
    parse_rep_range,
    target_weight,
)
from app.services.training_history import load_exercise_history

USER_ID = "00000000-0000-0000-0000-000000000001"


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    from app.db import Base

    Base.metadata.create_all(engine)
    db = Session(engine)
    db.add(User(id=USER_ID, phone="13800138000", status="active"))
    db.add(Profile(user_id=USER_ID, nickname="测试"))
    db.commit()
    return db


def _exercise(
    slug: str,
    *,
    muscle: str = "chest",
    equipment: str = "dumbbell",
    compound: bool = True,
    name: str = "哑铃卧推",
) -> Exercise:
    return Exercise(
        slug=slug,
        name_zh=name,
        name_en=name,
        muscle_group=muscle,
        equipment=equipment,
        is_compound=compound,
    )


def _workout(
    db: Session,
    started_at: datetime,
    slug: str,
    weight: float,
    reps: int,
    *,
    rpe: float = 8,
    completed: bool = True,
) -> WorkoutSession:
    session = WorkoutSession(
        user_id=USER_ID,
        started_at=started_at,
        feeling=3,
        sets=[
            SetLog(
                exercise_slug=slug,
                set_index=1,
                weight_kg=weight,
                reps=reps,
                rpe=rpe,
                completed=completed,
            )
        ],
    )
    db.add(session)
    db.commit()
    return session


def test_stage_for_days() -> None:
    assert training_stage.stage_for_days(0) == "beginner"
    assert training_stage.stage_for_days(59) == "beginner"
    assert training_stage.stage_for_days(60) == "intermediate"
    assert training_stage.stage_for_days(119) == "intermediate"
    assert training_stage.stage_for_days(120) == "advanced"


def test_completed_days_are_distinct_and_require_completed_sets() -> None:
    db = _session()
    day = datetime(2026, 11, 1, 10, 0)
    _workout(db, day, "bench", 60, 8)
    _workout(db, day + timedelta(hours=1), "bench", 60, 8)
    _workout(db, day + timedelta(days=1), "bench", 60, 8, completed=False)
    _workout(db, day + timedelta(days=2), "bench", 60, 8)

    assert training_stage.completed_training_days(db, USER_ID) == 2


def test_stage_only_promotes(monkeypatch) -> None:
    db = _session()
    monkeypatch.setattr(training_stage, "completed_training_days", lambda *_: 60)
    assert training_stage.refresh_training_stage(db, USER_ID) == "intermediate"

    profile = db.get(Profile, USER_ID)
    profile.training_stage = "advanced"
    db.commit()
    assert training_stage.refresh_training_stage(db, USER_ID) == "advanced"


def test_history_uses_latest_working_set() -> None:
    db = _session()
    base = datetime(2026, 10, 1, 10, 0)
    _workout(db, base, "bench", 50, 8, rpe=9)
    _workout(db, base + timedelta(days=2), "bench", 60, 8, rpe=8)

    history = load_exercise_history(db, USER_ID, {"bench"})
    assert history["bench"]["source"] == "log"
    assert history["bench"]["last_weight_kg"] == 60
    assert history["bench"]["last_reps"] == 8
    assert history["bench"]["last_rpe"] == 8


def test_plan_target_is_fallback_without_logs() -> None:
    db = _session()
    db.add(_exercise("squat", muscle="legs", equipment="barbell", name="深蹲"))
    program = Program(user_id=USER_ID, title="测试计划", goal_type="build_muscle")
    day = ProgramDay(week_index=1, weekday=1, title="腿", focus=["legs"])
    day.exercises.append(
        PlanExercise(
            exercise_slug="squat",
            order_index=1,
            sets=3,
            reps="8-10",
            weight_kg=100,
            rest_sec=90,
            rpe=8,
        )
    )
    program.days.append(day)
    db.add(program)
    db.commit()

    history = load_exercise_history(db, USER_ID, {"squat"})
    assert history["squat"]["source"] == "plan"
    assert history["squat"]["plan_weight_kg"] == 100


def test_target_weight_progression_and_bodyweight() -> None:
    db = _session()
    profile = db.get(Profile, USER_ID)
    assert profile is not None
    profile.training_stage = "beginner"
    bench = _exercise("bench")
    squat = _exercise("squat", muscle="legs", equipment="barbell", name="深蹲")
    pull = _exercise("pull_up", equipment="bodyweight", compound=True, name="引体向上")

    upper = target_weight(
        bench,
        profile,
        {"source": "log", "last_weight_kg": 60, "last_reps": 8},
        2,
        "8-10",
    )
    lower = target_weight(
        squat,
        profile,
        {"source": "log", "last_weight_kg": 100, "last_reps": 8},
        2,
        "8-10",
    )
    assert upper == 61.5
    assert lower == 105
    assert target_weight(pull, profile, None, 1, "8-10") is None


def test_apply_plan_weights_overrides_model_guess() -> None:
    db = _session()
    profile = db.get(Profile, USER_ID)
    assert profile is not None
    profile.training_stage = "beginner"
    bench = _exercise("bench")
    db.add(bench)
    _workout(db, datetime(2026, 11, 1, 10, 0), "bench", 60, 8, rpe=8)

    plan = {
        "days": [
            {
                "week_index": 2,
                "exercises": [
                    {"slug": "bench", "reps": "8-10", "weight_kg": 999}
                ],
            }
        ]
    }

    apply_plan_weights(db, profile, plan, {"bench": bench})

    assert plan["days"][0]["exercises"][0]["weight_kg"] == 61.5


def test_adjustment_multipliers_are_per_exercise() -> None:
    db = _session()
    bench = _exercise("bench")
    row = _exercise("row", name="哑铃划船")
    db.add_all([bench, row])
    program = Program(user_id=USER_ID, title="测试计划", goal_type="build_muscle")
    day = ProgramDay(week_index=1, weekday=1, title="推", focus=["chest"])
    day.exercises.extend(
        [
            PlanExercise(
                exercise_slug="bench",
                order_index=1,
                sets=3,
                reps="8-10",
                weight_kg=60,
                rest_sec=90,
                rpe=8,
            ),
            PlanExercise(
                exercise_slug="row",
                order_index=2,
                sets=3,
                reps="8-10",
                weight_kg=20,
                rest_sec=90,
                rpe=8,
            ),
        ]
    )
    program.days.append(day)
    db.add(program)
    db.commit()

    started = datetime(2026, 11, 1, 10, 0)
    session = WorkoutSession(
        user_id=USER_ID,
        started_at=started,
        feeling=3,
        sets=[
            SetLog(exercise_slug="bench", set_index=1, weight_kg=60, reps=9, rpe=7.5),
            SetLog(exercise_slug="bench", set_index=2, weight_kg=60, reps=9, rpe=7.5),
            SetLog(exercise_slug="bench", set_index=3, weight_kg=60, reps=9, rpe=7.5),
            SetLog(exercise_slug="row", set_index=1, weight_kg=20, reps=5, rpe=10),
        ],
    )
    db.add(session)
    db.commit()

    multipliers = adjustment_multipliers(program, [session], "beginner")
    assert multipliers["bench"] == 1.025
    assert multipliers["row"] == 0.95


def test_parse_rep_range() -> None:
    assert parse_rep_range("8-10") == (8, 10)
    assert parse_rep_range("12") == (12, 12)
    assert parse_rep_range("30-45s") == (30, 45)
