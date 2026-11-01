from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import AuthSession, User
from app.routers.auth import set_password
from app.schemas import PasswordSetIn
from app.services.auth import hash_password


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    db = Session(engine)
    db.add(
        User(
            id="00000000-0000-0000-0000-000000000001",
            phone="13800138000",
            password_hash=hash_password("OldPass123"),
            status="active",
        )
    )
    db.commit()
    return db


def _add_session(db: Session, session_id: str) -> None:
    db.add(
        AuthSession(
            id=session_id,
            user_id="00000000-0000-0000-0000-000000000001",
            refresh_token_hash=f"hash-{session_id}",
            expires_at=datetime.now(timezone.utc) + timedelta(days=7),
        )
    )
    db.commit()


def test_password_change_requires_current_password():
    db = _session()
    with pytest.raises(HTTPException) as exc:
        set_password(
            PasswordSetIn(password="NewPass123"),
            "00000000-0000-0000-0000-000000000001",
            db,
        )
    assert exc.value.status_code == 400

    with pytest.raises(HTTPException):
        set_password(
            PasswordSetIn(password="NewPass123", current_password="WrongPass123"),
            "00000000-0000-0000-0000-000000000001",
            db,
        )


def test_password_change_revokes_other_sessions():
    db = _session()
    _add_session(db, "session-1")
    _add_session(db, "session-2")

    set_password(
        PasswordSetIn(password="NewPass123", current_password="OldPass123"),
        "00000000-0000-0000-0000-000000000001",
        db,
    )

    sessions = db.query(AuthSession).all()
    assert len(sessions) == 2
    assert all(session.revoked_at is not None for session in sessions)
