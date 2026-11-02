from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.services.rate_limit import enforce


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return Session(engine)


def test_rate_limit_rejects_burst():
    db = _session()
    now = datetime.now(timezone.utc)
    enforce(db, "test-feature", "rate-limit-user", 2, 60, now=now)
    enforce(db, "test-feature", "rate-limit-user", 2, 60, now=now)
    with pytest.raises(HTTPException) as exc:
        enforce(db, "test-feature", "rate-limit-user", 2, 60, now=now)
    assert exc.value.status_code == 429
    assert exc.value.detail["code"] == "RATE_LIMITED"
    assert exc.value.detail["retry_after"] >= 1


def test_rate_limit_refills_continuously():
    db = _session()
    now = datetime.now(timezone.utc)
    enforce(db, "refill", "user", 2, 60, now=now)
    enforce(db, "refill", "user", 2, 60, now=now)
    with pytest.raises(HTTPException):
        enforce(db, "refill", "user", 2, 60, now=now)

    # 2 tokens per 60s = one token every 30s.
    enforce(db, "refill", "user", 2, 60, now=now + timedelta(seconds=30))
    with pytest.raises(HTTPException):
        enforce(db, "refill", "user", 2, 60, now=now + timedelta(seconds=30))
