from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import AuthSession, User
from app.services.auth import _refresh_hash, refresh_session, touch_session


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    db = Session(engine)
    now = datetime.now(timezone.utc)
    db.add(
        User(
            id="00000000-0000-0000-0000-000000000001",
            phone="13800138000",
            status="active",
        )
    )
    db.add(
        AuthSession(
            id="session-1",
            user_id="00000000-0000-0000-0000-000000000001",
            refresh_token_hash=_refresh_hash("old-token"),
            expires_at=now + timedelta(days=30),
            last_touched_at=now,
        )
    )
    db.commit()
    return db


def test_refresh_rotates_and_accepts_previous_token_during_grace():
    db = _session()

    first = refresh_session(db, "old-token")
    assert first["refresh_token"] != "old-token"
    assert first["access_token"]

    # The client missed the response; the previous token still works briefly.
    second = refresh_session(db, "old-token")
    assert second["refresh_token"] != first["refresh_token"]


def test_previous_token_is_revoked_after_grace():
    db = _session()
    first = refresh_session(db, "old-token")
    row = db.get(AuthSession, "session-1")
    row.previous_hash_valid_until = datetime.now(timezone.utc) - timedelta(seconds=1)
    db.commit()

    with pytest.raises(HTTPException) as exc:
        refresh_session(db, "old-token")
    assert exc.value.status_code == 401
    db.refresh(row)
    assert row.revoked_at is not None
    assert first["refresh_token"]


def test_touch_extends_session_expiry():
    db = _session()
    row = db.get(AuthSession, "session-1")
    before = row.expires_at
    result = touch_session(
        db,
        "session-1",
        "00000000-0000-0000-0000-000000000001",
    )
    db.refresh(row)
    assert result["ok"] is True
    assert row.expires_at > before
    assert row.last_touched_at is not None
