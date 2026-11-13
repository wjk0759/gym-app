"""Domain event and coach inbox helpers."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import CoachInbox, DomainEvent


def emit_event(
    db: Session,
    user_id: str,
    event_type: str,
    *,
    entity_type: str | None = None,
    entity_id: str | None = None,
    payload: dict | None = None,
) -> DomainEvent:
    event = DomainEvent(
        user_id=user_id,
        type=event_type,
        entity_type=entity_type,
        entity_id=entity_id,
        payload=payload or {},
    )
    db.add(event)
    db.flush()
    return event


def create_inbox_item(
    db: Session,
    user_id: str,
    *,
    kind: str,
    title: str,
    body: str,
    capability_id: str | None = None,
    payload: dict | None = None,
) -> CoachInbox:
    item = CoachInbox(
        user_id=user_id,
        kind=kind,
        title=title,
        body=body,
        capability_id=capability_id,
        payload=payload or {},
    )
    db.add(item)
    db.flush()
    return item


def list_inbox(db: Session, user_id: str, limit: int = 20) -> list[dict]:
    rows = (
        db.execute(
            select(CoachInbox)
            .where(CoachInbox.user_id == user_id)
            .order_by(CoachInbox.created_at.desc())
            .limit(max(1, min(limit, 100)))
        )
        .scalars()
        .all()
    )
    return [
        {
            "id": item.id,
            "kind": item.kind,
            "title": item.title,
            "body": item.body,
            "capability_id": item.capability_id,
            "payload": item.payload or {},
            "status": item.status,
            "created_at": item.created_at.isoformat() if item.created_at else None,
        }
        for item in rows
    ]
