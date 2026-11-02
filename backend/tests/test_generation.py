from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import User
from app.services import generation

USER_ID = "00000000-0000-0000-0000-000000000002"


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    db = Session(engine)
    db.add(User(id=USER_ID, phone="13800138001", status="active"))
    db.commit()
    return db


def _begin(db: Session, now: datetime, key: str | None = None):
    return generation.begin_generation(
        db,
        USER_ID,
        "training_plan",
        idempotency_key=key,
        now=now,
    )


def test_successful_generation_starts_cooldown_and_replays_same_key():
    db = _session()
    base = datetime.now(timezone.utc)

    lease = _begin(db, base, "retry-1")
    assert not lease.is_replay
    generation.complete_generation(
        db,
        lease,
        user_id=USER_ID,
        result_ref="plan-1",
        now=base + timedelta(seconds=5),
    )

    with pytest.raises(HTTPException) as exc:
        _begin(db, base + timedelta(seconds=30), "retry-2")
    assert exc.value.status_code == 429
    assert exc.value.detail["code"] == "GENERATION_COOLDOWN"

    replay = _begin(db, base + timedelta(seconds=30), "retry-1")
    assert replay.is_replay
    assert replay.replay_result_ref == "plan-1"

    fresh = _begin(db, base + timedelta(seconds=70), "retry-2")
    assert not fresh.is_replay


def test_running_generation_blocks_concurrent_request_until_aborted():
    db = _session()
    base = datetime.now(timezone.utc)

    lease = _begin(db, base)
    with pytest.raises(HTTPException) as exc:
        _begin(db, base + timedelta(seconds=5))
    assert exc.value.detail["code"] == "GENERATION_IN_PROGRESS"

    generation.abort_generation(db, lease, user_id=USER_ID)
    retry = _begin(db, base + timedelta(seconds=6))
    assert not retry.is_replay


def test_stale_running_generation_can_be_replaced():
    db = _session()
    base = datetime.now(timezone.utc)

    _begin(db, base)
    retry = _begin(db, base + timedelta(seconds=generation.IN_FLIGHT_TIMEOUT_SECONDS + 1))
    assert not retry.is_replay


def test_per_feature_cooldown_is_persisted():
    db = _session()
    base = datetime.now(timezone.utc)

    lease = generation.begin_generation(
        db,
        USER_ID,
        "food_photo",
        cooldown_seconds=5,
        now=base,
    )
    generation.complete_generation(
        db,
        lease,
        user_id=USER_ID,
        result_ref="photo-1",
        now=base + timedelta(seconds=1),
    )

    with pytest.raises(HTTPException):
        generation.begin_generation(
            db,
            USER_ID,
            "food_photo",
            now=base + timedelta(seconds=4),
        )

    allowed = generation.begin_generation(
        db,
        USER_ID,
        "food_photo",
        now=base + timedelta(seconds=7),
    )
    assert not allowed.is_replay


def test_zero_cooldown_allows_immediate_next_turn():
    db = _session()
    base = datetime.now(timezone.utc)

    lease = generation.begin_generation(
        db,
        USER_ID,
        "coach_chat",
        cooldown_seconds=0,
        now=base,
    )
    generation.complete_generation(
        db,
        lease,
        user_id=USER_ID,
        result_ref="message-1",
        now=base,
    )

    next_lease = generation.begin_generation(
        db,
        USER_ID,
        "coach_chat",
        cooldown_seconds=0,
        now=base,
    )
    assert not next_lease.is_replay
