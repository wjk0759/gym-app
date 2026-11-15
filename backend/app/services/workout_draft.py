"""Cross-device workout draft storage."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy.orm import Session

from ..models import WorkoutDraftRecord
from ..schemas import WorkoutDraftIn
from .locking import lock_user


def _as_utc(value: datetime) -> datetime:
    return (
        value.replace(tzinfo=timezone.utc)
        if value.tzinfo is None
        else value.astimezone(timezone.utc)
    )


def draft_dict(item: WorkoutDraftRecord | None) -> dict | None:
    if item is None:
        return None
    return {
        "day_id": item.day_id,
        "payload": item.payload or {},
        "created_at": item.created_at.isoformat(),
        "updated_at": item.updated_at.isoformat(),
    }


def get_draft(db: Session, user_id: str) -> WorkoutDraftRecord | None:
    return db.get(WorkoutDraftRecord, user_id)


def upsert_draft(db: Session, user_id: str, payload: WorkoutDraftIn) -> tuple[bool, dict]:
    lock_user(db, user_id)
    item = db.get(WorkoutDraftRecord, user_id)
    incoming = _as_utc(payload.updated_at)
    if item is not None and _as_utc(item.updated_at) > incoming:
        return False, draft_dict(item) or {}
    if item is None:
        item = WorkoutDraftRecord(user_id=user_id)
        db.add(item)
    item.day_id = payload.day_id.lower()
    item.payload = payload.payload
    item.updated_at = incoming
    db.commit()
    db.refresh(item)
    return True, draft_dict(item) or {}


def clear_draft(db: Session, user_id: str, day_id: str | None = None) -> bool:
    lock_user(db, user_id)
    item = db.get(WorkoutDraftRecord, user_id)
    if item is None:
        return False
    if day_id and item.day_id.lower() != day_id.lower():
        return False
    db.delete(item)
    db.commit()
    return True
