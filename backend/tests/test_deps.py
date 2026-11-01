from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.config import settings
from app.db import Base
from app.deps import get_user_id
from app.models import AuthSession, User
from app.services.auth import check_access_session


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session = Session(engine)
    session.add(User(id="00000000-0000-0000-0000-000000000001", phone="13800138000", status="active"))
    session.commit()
    return session


def test_dev_user_header_requires_explicit_flag(monkeypatch):
    db = _session()
    monkeypatch.setattr(settings, "app_env", "dev")
    monkeypatch.setattr(settings, "allow_dev_user_header", False)
    with pytest.raises(HTTPException) as exc:
        get_user_id(db, authorization=None, x_user_id="00000000-0000-0000-0000-000000000001")
    assert exc.value.status_code == 401


def test_dev_user_header_validates_user(monkeypatch):
    db = _session()
    monkeypatch.setattr(settings, "app_env", "dev")
    monkeypatch.setattr(settings, "allow_dev_user_header", True)
    assert (
        get_user_id(db, authorization=None, x_user_id="00000000-0000-0000-0000-000000000001")
        == "00000000-0000-0000-0000-000000000001"
    )
    with pytest.raises(HTTPException):
        get_user_id(db, authorization=None, x_user_id="00000000-0000-0000-0000-000000000099")


def test_expired_session_is_rejected():
    db = _session()
    db.add(
        AuthSession(
            id="session-1",
            user_id="00000000-0000-0000-0000-000000000001",
            refresh_token_hash="hash",
            created_at=datetime.now(timezone.utc) - timedelta(days=2),
            last_used_at=datetime.now(timezone.utc) - timedelta(days=1),
            expires_at=datetime.now(timezone.utc) - timedelta(hours=1),
        )
    )
    db.commit()
    with pytest.raises(HTTPException):
        check_access_session(
            db,
            {"sid": "session-1", "sub": "00000000-0000-0000-0000-000000000001"},
        )
