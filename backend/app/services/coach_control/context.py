"""Compact context for the new coach control plane.

The legacy agent already has a canonical CoachContext. This module adds the
things the new runtime needs: recent domain events and the last executed
action, plus a deterministic plan fallback when the client does not send
``app_context``.
"""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import CoachActionRecord, DomainEvent, utcnow
from ..coach_context import build_coach_context

CONTEXT_VERSION = "coach-control-v1"


def build_control_context(
    db: Session,
    user_id: str,
    *,
    app_context: dict | None = None,
) -> dict:
    base = build_coach_context(db, user_id, app_context=app_context)
    events = (
        db.execute(
            select(DomainEvent)
            .where(
                DomainEvent.user_id == user_id,
                DomainEvent.type != "ClientDiagnostic",
                DomainEvent.occurred_at >= utcnow() - timedelta(days=7),
            )
            .order_by(DomainEvent.occurred_at.desc())
            .limit(50)
        )
        .scalars()
        .all()
    )
    last_action = (
        db.execute(
            select(CoachActionRecord)
            .where(CoachActionRecord.user_id == user_id)
            .order_by(CoachActionRecord.created_at.desc())
        )
        .scalars()
        .first()
    )
    return {
        "version": CONTEXT_VERSION,
        "coach_context": base,
        "recent_events": [
            {
                "type": item.type,
                "entity_type": item.entity_type,
                "entity_id": item.entity_id,
                "payload": item.payload or {},
                "occurred_at": item.occurred_at.isoformat(),
            }
            for item in events
        ],
        "last_action": (
            {
                "id": last_action.id,
                "capability_id": last_action.capability_id,
                "status": last_action.status,
                "payload": last_action.payload or {},
            }
            if last_action is not None
            else None
        ),
    }


def with_plan_context(
    db: Session,
    user_id: str,
    app_context: dict | None,
) -> dict:
    context = dict(app_context or {})
    if isinstance(context.get("plan"), dict):
        return context
    try:
        base = build_coach_context(db, user_id, app_context=context)
    except Exception:  # noqa: BLE001 - context must never block a turn
        return context
    plan = base.get("current_plan")
    if not isinstance(plan, dict):
        return context
    days = plan.get("days")
    if not isinstance(days, list) or not days:
        return context
    context["plan"] = {
        "id": plan.get("id"),
        "version": plan.get("version"),
        "days": [
            {
                "id": item.get("id"),
                "date": item.get("date"),
                "title": item.get("title"),
                "completed": item.get("completed", False),
                "skipped": item.get("skipped", False),
            }
            for item in days
            if isinstance(item, dict)
        ],
    }
    return context
