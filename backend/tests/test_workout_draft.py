from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import User
from app.schemas import WorkoutDraftIn
from app.services.workout_draft import clear_draft, draft_dict, get_draft, upsert_draft


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
    session.add(User(id="user-1", phone="13428104171", status="active"))
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_workout_draft_last_write_wins(db):
    now = datetime.now(timezone.utc)
    accepted, first = upsert_draft(
        db,
        "user-1",
        WorkoutDraftIn(
            day_id="day-1",
            updated_at=now,
            payload={"currentIndex": 1, "logs": []},
        ),
    )
    assert accepted is True
    assert first["day_id"] == "day-1"

    accepted, ignored = upsert_draft(
        db,
        "user-1",
        WorkoutDraftIn(
            day_id="day-1",
            updated_at=now - timedelta(minutes=1),
            payload={"currentIndex": 0},
        ),
    )
    assert accepted is False
    assert ignored["payload"]["currentIndex"] == 1

    accepted, newer = upsert_draft(
        db,
        "user-1",
        WorkoutDraftIn(
            day_id="day-1",
            updated_at=now + timedelta(seconds=5),
            payload={"currentIndex": 2},
        ),
    )
    assert accepted is True
    assert newer["payload"]["currentIndex"] == 2


def test_workout_draft_clear_only_matching_day(db):
    now = datetime.now(timezone.utc)
    upsert_draft(
        db,
        "user-1",
        WorkoutDraftIn(day_id="day-1", updated_at=now, payload={"a": 1}),
    )
    assert clear_draft(db, "user-1", "day-2") is False
    assert draft_dict(get_draft(db, "user-1")) is not None
    assert clear_draft(db, "user-1", "day-1") is True
    assert get_draft(db, "user-1") is None
