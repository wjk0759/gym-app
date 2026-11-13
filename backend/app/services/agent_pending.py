"""Server-owned pending coach action cards.

The iOS app normally holds the confirmation card itself. Storing it on the
server keeps two devices consistent and gives the backend the original payload
when the user corrects a card without sending ``app_context``.
"""

from __future__ import annotations

from datetime import timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import AgentPendingAction, AgentPlanProposal, utcnow


def _is_past(value) -> bool:
    if value is None:
        return True
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value < utcnow()

PENDING_TTL = timedelta(minutes=30)
ACTIVE_STATUSES = {"pending"}


def _is_expired(row: AgentPendingAction) -> bool:
    expires = row.expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    return expires < utcnow()


def _active_rows(
    db: Session,
    user_id: str,
    session_id: str | None = None,
) -> list[AgentPendingAction]:
    query = select(AgentPendingAction).where(
        AgentPendingAction.user_id == user_id,
        AgentPendingAction.status.in_(ACTIVE_STATUSES),
    )
    if session_id:
        query = query.where(AgentPendingAction.session_id == session_id)
    return (
        db.execute(query.order_by(AgentPendingAction.updated_at.desc()))
        .scalars()
        .all()
    )


def store_pending_actions(
    db: Session,
    user_id: str,
    session_id: str,
    run_id: str | None,
    actions: list[dict],
) -> AgentPendingAction | None:
    """Replace the session's pending card with this turn's actions.

    A turn without actions supersedes the previous card, matching the client
    behaviour where sending a new message clears the old card.
    """

    rows = _active_rows(db, user_id, session_id)
    for row in rows:
        row.status = "superseded"
    values = [
        dict(item)
        for item in (actions or [])
        if isinstance(item, dict) and item.get("id")
    ]
    if not values:
        if rows:
            db.flush()
        return None

    row = AgentPendingAction(
        user_id=user_id,
        session_id=session_id,
        run_id=run_id,
        actions=values,
        status="pending",
        expires_at=utcnow() + PENDING_TTL,
    )
    db.add(row)
    db.flush()
    return row


def latest_pending_action(
    db: Session,
    user_id: str,
    session_id: str | None = None,
) -> AgentPendingAction | None:
    rows = _active_rows(db, user_id, session_id)
    result: AgentPendingAction | None = None
    changed = False
    for row in rows:
        if _is_expired(row):
            row.status = "expired"
            changed = True
        elif result is None:
            result = row
    if changed:
        db.flush()
    return result


def pending_action_payload(row: AgentPendingAction) -> dict:
    return {
        "id": row.id,
        "run_id": row.run_id,
        "actions": row.actions or [],
        "expires_at": row.expires_at.isoformat() if row.expires_at else None,
    }


def pending_food_action_context(
    db: Session,
    user_id: str,
    session_id: str | None,
) -> dict | None:
    """Return the last log_food action in the session's pending card."""

    if not session_id:
        return None
    row = latest_pending_action(db, user_id, session_id)
    if row is None:
        return None
    for action in reversed(row.actions or []):
        if not isinstance(action, dict):
            continue
        payload = action.get("payload")
        if action.get("type") == "log_food" and isinstance(payload, dict):
            return {
                "id": action.get("id"),
                "type": "log_food",
                "payload": payload,
            }
    return None


def latest_pending_proposal(
    db: Session,
    user_id: str,
) -> AgentPlanProposal | None:
    """Latest unexpired draft proposal, used for cross-device restore."""

    rows = (
        db.execute(
            select(AgentPlanProposal)
            .where(
                AgentPlanProposal.user_id == user_id,
                AgentPlanProposal.status == "draft",
            )
            .order_by(AgentPlanProposal.created_at.desc())
        )
        .scalars()
        .all()
    )
    result: AgentPlanProposal | None = None
    changed = False
    for row in rows:
        if _is_past(row.expires_at):
            row.status = "expired"
            changed = True
        elif result is None:
            result = row
    if changed:
        db.flush()
    return result


def supersede_pending_proposals(db: Session, user_id: str) -> None:
    """A new turn without a proposal clears the previous card, like iOS does."""

    rows = (
        db.execute(
            select(AgentPlanProposal).where(
                AgentPlanProposal.user_id == user_id,
                AgentPlanProposal.status == "draft",
            )
        )
        .scalars()
        .all()
    )
    for row in rows:
        row.status = "superseded"
    if rows:
        db.flush()


def update_pending_action(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
    summary: str | None = None,
) -> dict:
    """Persist a client-side card edit so other devices see the same values."""

    for row in _active_rows(db, user_id):
        actions = [
            dict(action) if isinstance(action, dict) else action
            for action in (row.actions or [])
        ]
        for action in actions:
            if not isinstance(action, dict) or action.get("id") != action_id:
                continue
            action["payload"] = payload
            if summary is not None:
                action["summary"] = summary
            row.actions = actions
            row.updated_at = utcnow()
            db.flush()
            return action
    raise LookupError("待确认操作不存在")


def resolve_pending_action(
    db: Session,
    user_id: str,
    action_id: str,
) -> bool:
    """Remove one executed/rejected action from its pending card."""

    changed = False
    for row in _active_rows(db, user_id):
        actions = list(row.actions or [])
        remaining = [
            action
            for action in actions
            if not isinstance(action, dict) or action.get("id") != action_id
        ]
        if len(remaining) == len(actions):
            continue
        row.actions = remaining
        row.status = "consumed" if not remaining else "pending"
        row.updated_at = utcnow()
        changed = True
        break
    if changed:
        db.flush()
    return changed
