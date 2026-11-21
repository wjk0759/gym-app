"""Compact context for the new coach control plane.

The legacy agent already has a canonical CoachContext. This module adds the
things the new runtime needs: recent domain events and the last executed
action, plus a deterministic plan fallback when the client does not send
``app_context``.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import CoachActionRecord, DomainEvent, Program, utcnow
from ..coach_context import build_coach_context, plan_day_date

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
                DomainEvent.type.notin_(["ClientDiagnostic", "ClientEvent"]),
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
        # iOS sends the full plan days but not the server version. Fill in
        # server-owned metadata so life-event/plan-edit cards carry a real
        # plan_version instead of null.
        plan = dict(context["plan"])
        program_id = str(plan.get("id") or "")
        if program_id:
            program = db.execute(
                select(Program).where(
                    Program.id == program_id,
                    Program.user_id == user_id,
                )
            ).scalar_one_or_none()
            if program is not None:
                if not plan.get("version"):
                    plan["version"] = program.version
                if not plan.get("start_date") and program.start_date:
                    plan["start_date"] = program.start_date.isoformat()
                if not plan.get("weeks"):
                    plan["weeks"] = program.weeks
                context["plan"] = plan
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
    states = {
        str(item.get("day_id")).lower(): item
        for item in (plan.get("day_states") or [])
        if isinstance(item, dict)
    }
    try:
        start = date.fromisoformat(str(plan.get("start_date")))
    except (TypeError, ValueError):
        start = None
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    # Allow a workout explicitly added for today even when the plan has not
    # started yet (e.g. generate a plan on Sunday and add a Sunday session).
    # Older stale pre-start dates still fall back.
    earliest = start
    if earliest is None or today < earliest:
        earliest = today
    normalized = []
    for item in days:
        if not isinstance(item, dict):
            continue
        day_id = str(item.get("id") or "")
        state = states.get(day_id.lower()) or {}
        assigned = state.get("assigned_date")
        computed = None
        if start is not None:
            week_index = int(item.get("week_index") or 1)
            weekday = int(item.get("weekday") or 1)
            computed = plan_day_date(start, week_index, weekday)
        selected = None
        if assigned:
            try:
                assigned_date = date.fromisoformat(str(assigned))
            except ValueError:
                assigned_date = None
            if assigned_date is not None and (
                earliest is None or assigned_date >= earliest
            ):
                selected = assigned
        normalized.append(
            {
                "id": item.get("id"),
                "date": selected
                or (computed.isoformat() if computed else None),
                "week_index": item.get("week_index"),
                "weekday": item.get("weekday"),
                "title": item.get("title"),
                "focus": item.get("focus") or [],
                "completed": item.get("completed", False),
                "skipped": state.get(
                    "skipped",
                    item.get("skipped", False),
                ),
            }
        )
    context["plan"] = {
        "id": plan.get("id"),
        "version": plan.get("version"),
        "start_date": plan.get("start_date"),
        "days": normalized,
    }
    return context
