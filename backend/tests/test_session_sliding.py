from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.config import settings
from app.db import Base
from app.models import AuthEvent, AuthSession, User
from app.services.auth import (
    _detect_login_anomalies,
    _refresh_hash,
    _revoke_excess_sessions,
    refresh_session,
    touch_session,
)


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
    events = (
        db.query(AuthEvent)
        .filter(AuthEvent.event == "refresh_reuse")
        .all()
    )
    assert len(events) == 1


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


def test_session_limit_revokes_oldest_device(monkeypatch):
    db = _session()
    monkeypatch.setattr(settings, "max_active_sessions_per_user", 2)
    now = datetime.now(timezone.utc)
    db.add(
        AuthSession(
            id="session-2",
            user_id="00000000-0000-0000-0000-000000000001",
            refresh_token_hash=_refresh_hash("token-2"),
            device_id="device-2",
            expires_at=now + timedelta(days=30),
            last_used_at=now + timedelta(minutes=1),
        )
    )
    db.commit()

    _revoke_excess_sessions(
        db,
        "00000000-0000-0000-0000-000000000001",
        device_id="device-3",
        now=now,
    )
    db.commit()

    assert db.get(AuthSession, "session-1").revoked_at is not None
    assert db.get(AuthSession, "session-2").revoked_at is None


def test_same_device_login_revokes_previous_session(monkeypatch):
    db = _session()
    monkeypatch.setattr(settings, "max_active_sessions_per_user", 5)
    now = datetime.now(timezone.utc)
    row = db.get(AuthSession, "session-1")
    row.device_id = "device-1"
    db.commit()

    _revoke_excess_sessions(
        db,
        "00000000-0000-0000-0000-000000000001",
        device_id="device-1",
        now=now,
    )
    db.commit()

    assert row.revoked_at is not None


def test_multi_account_device_is_logged_without_blocking():
    db = _session()
    now = datetime.now(timezone.utc)
    row = db.get(AuthSession, "session-1")
    row.device_id = "shared-device"
    row.created_at = now
    for index in (2, 3):
        user_id = f"00000000-0000-0000-0000-00000000000{index}"
        db.add(User(id=user_id, phone=f"1380013800{index}", status="active"))
        db.add(
            AuthSession(
                id=f"session-{index}",
                user_id=user_id,
                refresh_token_hash=_refresh_hash(f"token-{index}"),
                device_id="shared-device",
                created_at=now,
                expires_at=now + timedelta(days=30),
            )
        )
    db.commit()

    _detect_login_anomalies(
        db,
        "00000000-0000-0000-0000-000000000001",
        {"device_id": "shared-device"},
        now,
    )
    db.commit()

    events = (
        db.query(AuthEvent)
        .filter(AuthEvent.event == "anomaly_multi_account")
        .all()
    )
    assert len(events) == 1
    assert events[0].detail["accounts"] == 3


def test_refresh_without_device_header_is_allowed_for_legacy_clients():
    db = _session()
    row = db.get(AuthSession, "session-1")
    row.device_id = "device-a"
    db.commit()

    result = refresh_session(db, "old-token")

    assert result["access_token"]
    db.refresh(row)
    assert row.revoked_at is None


def test_refresh_from_another_device_is_rejected():
    db = _session()
    row = db.get(AuthSession, "session-1")
    row.device_id = "device-a"
    db.commit()

    with pytest.raises(HTTPException) as exc:
        refresh_session(
            db,
            "old-token",
            request_meta={"device_id": "device-b"},
        )

    assert exc.value.status_code == 401
    db.refresh(row)
    assert row.revoked_at is not None
    events = (
        db.query(AuthEvent)
        .filter(AuthEvent.event == "refresh_device_mismatch")
        .all()
    )
    assert len(events) == 1
