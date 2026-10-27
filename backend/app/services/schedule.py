"""Cross-device training schedule state.

The local plan is the source of truth for plan content, while this module owns
only user-editable scheduling state: assigned date and skipped state. A
client-authored timestamp gives deterministic last-write-wins behavior without
requiring a shared plan id to be owned by a server Program row.
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import PlanDayState, utcnow
from ..schemas import ScheduleSyncIn


def _utc(value: datetime) -> datetime:
    return (
        value.replace(tzinfo=timezone.utc)
        if value.tzinfo is None
        else value.astimezone(timezone.utc)
    )


def _serialize(item: PlanDayState) -> dict:
    return {
        "day_id": item.day_id,
        "assigned_date": item.assigned_date.isoformat() if item.assigned_date else None,
        "skipped_at": (
            _utc(item.skipped_at).isoformat() if item.skipped_at else None
        ),
        "client_updated_at": _utc(item.client_updated_at).isoformat(),
        "server_updated_at": _utc(item.updated_at).isoformat(),
    }


def get_schedule(db: Session, user_id: str, plan_id: str) -> dict:
    rows = (
        db.execute(
            select(PlanDayState)
            .where(
                PlanDayState.user_id == user_id,
                PlanDayState.plan_id == plan_id,
            )
            .order_by(PlanDayState.day_id)
        )
        .scalars()
        .all()
    )
    return {"plan_id": plan_id, "days": [_serialize(item) for item in rows]}


def sync_schedule(db: Session, user_id: str, payload: ScheduleSyncIn) -> dict:
    incoming: dict[str, object] = {}
    for item in payload.days:
        # Duplicate day ids in one batch: last one wins.
        incoming[item.day_id] = item

    existing_rows = (
        db.execute(
            select(PlanDayState)
            .where(
                PlanDayState.user_id == user_id,
                PlanDayState.plan_id == payload.plan_id,
                PlanDayState.day_id.in_(list(incoming.keys()) or [""]),
            )
            .with_for_update()
        )
        .scalars()
        .all()
    )
    existing = {item.day_id: item for item in existing_rows}
    accepted: list[str] = []
    ignored: list[str] = []
    for day_id, item in incoming.items():
        current = existing.get(day_id)
        incoming_at = _utc(item.client_updated_at or utcnow())
        if current is not None and incoming_at < _utc(current.client_updated_at):
            ignored.append(day_id)
            continue
        if current is None:
            current = PlanDayState(
                user_id=user_id,
                plan_id=payload.plan_id,
                day_id=day_id,
                client_updated_at=incoming_at,
            )
            db.add(current)
            existing[day_id] = current
        current.assigned_date = item.assigned_date
        current.skipped_at = item.skipped_at
        current.plan_version = payload.plan_version
        current.client_updated_at = incoming_at
        current.updated_at = utcnow()
        accepted.append(day_id)

    db.commit()
    data = get_schedule(db, user_id, payload.plan_id)
    data["accepted"] = accepted
    data["ignored"] = ignored
    return data
