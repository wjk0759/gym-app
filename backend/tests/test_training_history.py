from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import Exercise, SetLog, User, WorkoutSession
from app.services.training_history import (
    exercise_history_payload,
    exercise_performance,
    workout_detail_payload,
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
    db.add_all([User(id="user-1"), User(id="user-2")])
    db.add(
        Exercise(
            slug="bench_press",
            name_zh="杠铃卧推",
            name_en="Bench Press",
            muscle_group="chest",
            equipment="barbell",
            is_compound=True,
        )
    )
    first = WorkoutSession(
        id="session-1",
        user_id="user-1",
        started_at=now - timedelta(days=2),
        duration_min=40,
        feeling=4,
    )
    second = WorkoutSession(
        id="session-2",
        user_id="user-1",
        started_at=now - timedelta(days=1),
        duration_min=45,
        feeling=5,
    )
    db.add_all([first, second])
    db.add_all(
        [
            SetLog(
                session_id=first.id,
                exercise_slug="bench_press",
                set_index=1,
                weight_kg=60,
                reps=8,
                rpe=7,
                completed=True,
            ),
            SetLog(
                session_id=first.id,
                exercise_slug="bench_press",
                set_index=2,
                weight_kg=60,
                reps=7,
                rpe=8,
                completed=True,
            ),
            SetLog(
                session_id=second.id,
                exercise_slug="bench_press",
                set_index=1,
                weight_kg=62.5,
                reps=6,
                rpe=8,
                completed=True,
            ),
            SetLog(
                session_id=second.id,
                exercise_slug="bench_press",
                set_index=2,
                weight_kg=62.5,
                reps=5,
                rpe=9,
                completed=True,
            ),
        ]
    )
    db.commit()
    return now


def test_exercise_performance_returns_last_best_and_recent(db, seeded):
    performance = exercise_performance(db, "user-1", ["bench_press"])

    item = performance["bench_press"]
    assert item["session_count"] == 2
    assert item["last"]["weight_kg"] == 62.5
    assert item["last"]["reps"] == 6
    assert item["last"]["session_id"] == "session-2"
    assert item["best"]["weight_kg"] == 62.5
    assert item["best"]["e1rm"] == 75.0
    assert len(item["recent"]) == 2
    assert item["recent"][0]["session_id"] == "session-2"
    assert item["recent"][1]["sets"][1]["reps"] == 7


def test_exercise_history_payload_has_sets_and_best(db, seeded):
    payload = exercise_history_payload(db, "user-1", "bench_press", 5)

    assert payload["ok"] is True
    assert payload["name_zh"] == "杠铃卧推"
    assert len(payload["sessions"]) == 2
    assert payload["best"]["weight_kg"] == 62.5
    assert payload["sessions"][0]["sets"][0]["e1rm"] == 75.0
    assert exercise_history_payload(db, "user-1", "", 5)["ok"] is False
    custom = exercise_history_payload(db, "user-1", "custom_move", 5)
    assert custom["ok"] is True
    assert custom["sessions"] == []


def test_workout_detail_is_owner_scoped(db, seeded):
    own = workout_detail_payload(db, "user-1", "session-1")
    assert own["ok"] is True
    assert own["session"]["id"] == "session-1"
    assert own["exercises"][0]["slug"] == "bench_press"
    assert len(own["exercises"][0]["sets"]) == 2

    other = workout_detail_payload(db, "user-2", "session-1")
    assert other["ok"] is False
