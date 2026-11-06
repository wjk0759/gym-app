import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import AuthSession, User
from app.services.auth import (
    check_access_session,
    decode_access_token,
    issue_watch_session,
    refresh_session,
)


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    db = Session(engine)
    db.add(User(id="watch-user", phone="13800138013", status="active"))
    db.commit()
    return db


def test_watch_session_is_independent_and_rotates_itself():
    db = _session()
    first = issue_watch_session(
        db,
        "watch-user",
        "watch-11111111",
        "Apple Watch",
    )

    payload = decode_access_token(first["access_token"])
    assert check_access_session(db, payload) == "watch-user"
    assert first["refresh_token"]

    second = issue_watch_session(
        db,
        "watch-user",
        "watch-11111111",
        "Apple Watch",
    )
    rows = db.execute(
        select(AuthSession).where(AuthSession.user_id == "watch-user")
    ).scalars().all()
    assert len(rows) == 2
    assert sum(1 for row in rows if row.revoked_at is None) == 1

    refreshed = refresh_session(
        db,
        second["refresh_token"],
        {"device_id": "watch-11111111"},
    )
    assert refreshed["access_token"]
    assert refreshed["refresh_token"] != second["refresh_token"]


def test_watch_session_rejects_bad_or_inactive_devices():
    db = _session()
    with pytest.raises(HTTPException) as exc:
        issue_watch_session(db, "watch-user", "phone-device-id")
    assert exc.value.status_code == 400

    db.get(User, "watch-user").status = "disabled"
    db.commit()
    with pytest.raises(HTTPException) as exc:
        issue_watch_session(db, "watch-user", "watch-22222222")
    assert exc.value.status_code == 403


def test_watch_refresh_device_mismatch_revokes_only_watch_session():
    db = _session()
    watch = issue_watch_session(db, "watch-user", "watch-33333333")
    phone = issue_watch_session(db, "watch-user", "watch-44444444")

    with pytest.raises(HTTPException):
        refresh_session(
            db,
            watch["refresh_token"],
            {"device_id": "watch-99999999"},
        )

    phone_payload = decode_access_token(phone["access_token"])
    assert check_access_session(db, phone_payload) == "watch-user"

    watch_row = db.execute(
        select(AuthSession).where(AuthSession.device_id == "watch-33333333")
    ).scalar_one()
    assert watch_row.revoked_at is not None
    assert watch_row.expires_at is not None
