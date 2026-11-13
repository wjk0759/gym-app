"""Server-owned coach session and pending state."""

from __future__ import annotations

from datetime import timedelta, timezone
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import CoachPending, CoachSession, utcnow

PENDING_TTL = timedelta(minutes=30)
ACTIVE_STATUS = "pending"


def _is_expired(pending: CoachPending) -> bool:
    expires = pending.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    return expires < utcnow()


def get_or_create_session(
    db: Session,
    user_id: str,
    session_id: str | None = None,
) -> CoachSession:
    if session_id:
        session = db.get(CoachSession, session_id)
        if session is not None and session.user_id == user_id:
            return session
    session = CoachSession(
        id=str(uuid4()),
        user_id=user_id,
        status="active",
    )
    db.add(session)
    db.flush()
    return session


def get_active_pending(
    db: Session,
    user_id: str,
    session_id: str,
) -> CoachPending | None:
    pending = (
        db.execute(
            select(CoachPending)
            .where(
                CoachPending.user_id == user_id,
                CoachPending.session_id == session_id,
                CoachPending.status == ACTIVE_STATUS,
            )
            .order_by(CoachPending.updated_at.desc())
        )
        .scalars()
        .first()
    )
    if pending is None:
        return None
    if _is_expired(pending):
        pending.status = "expired"
        db.flush()
        return None
    return pending


def cancel_active_pending(db: Session, session: CoachSession) -> None:
    pending = get_active_pending(db, session.user_id, session.id)
    if pending is not None:
        pending.status = "cancelled"
        pending.updated_at = utcnow()
    session.pending_id = None
    session.status = "active"


def set_pending(
    db: Session,
    session: CoachSession,
    *,
    kind: str,
    capability_id: str,
    payload: dict,
    action_id: str | None = None,
) -> CoachPending:
    cancel_active_pending(db, session)
    pending = CoachPending(
        id=str(uuid4()),
        session_id=session.id,
        user_id=session.user_id,
        kind=kind,
        capability_id=capability_id,
        payload=payload,
        status=ACTIVE_STATUS,
        action_id=action_id,
        expires_at=utcnow() + PENDING_TTL,
    )
    db.add(pending)
    db.flush()
    session.pending_id = pending.id
    session.status = "waiting"
    session.active_topic = capability_id
    session.updated_at = utcnow()
    return pending


def consume_pending(db: Session, session: CoachSession, pending: CoachPending) -> None:
    pending.status = "consumed"
    pending.updated_at = utcnow()
    if session.pending_id == pending.id:
        session.pending_id = None
        session.status = "active"
    session.updated_at = utcnow()


def cancel_pending(db: Session, session: CoachSession, pending: CoachPending) -> None:
    pending.status = "cancelled"
    pending.updated_at = utcnow()
    if session.pending_id == pending.id:
        session.pending_id = None
        session.status = "active"
    session.updated_at = utcnow()


def serialize_pending(pending: CoachPending | None) -> dict | None:
    if pending is None:
        return None
    return {
        "id": pending.id,
        "kind": pending.kind,
        "capability_id": pending.capability_id,
        "payload": pending.payload or {},
        "status": pending.status,
        "action_id": pending.action_id,
        "expires_at": pending.expires_at.isoformat() if pending.expires_at else None,
    }


def serialize_session(session: CoachSession, pending: CoachPending | None) -> dict:
    return {
        "id": session.id,
        "status": session.status,
        "active_topic": session.active_topic,
        "pending": serialize_pending(pending),
        "updated_at": session.updated_at.isoformat() if session.updated_at else None,
    }
