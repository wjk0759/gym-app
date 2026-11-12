"""Durable feedback for one assistant coach message."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import AgentRun, ChatMessage, ChatSession, CoachFeedback, utcnow

ALLOWED_REASONS = {
    "inaccurate",
    "unsafe",
    "too_long",
    "not_understood",
    "other",
}


def save_feedback(
    db: Session,
    user_id: str,
    *,
    message_id: str,
    rating: str,
    reason: str | None = None,
    comment: str | None = None,
    run_id: str | None = None,
) -> CoachFeedback:
    """Create or update feedback for an assistant message owned by the user."""
    message = db.get(ChatMessage, message_id)
    if message is None or message.role != "assistant":
        raise LookupError("教练消息不存在")

    session = db.get(ChatSession, message.session_id)
    if session is None or session.user_id != user_id:
        raise LookupError("教练消息不存在")

    if rating not in {"up", "down"}:
        raise ValueError("rating 必须是 up 或 down")

    normalized_reason = (reason or "").strip() or None
    if normalized_reason and normalized_reason not in ALLOWED_REASONS:
        raise ValueError("不支持的反馈原因")
    if rating == "up":
        normalized_reason = None

    run = db.get(AgentRun, run_id) if run_id else None
    if run_id and (run is None or run.user_id != user_id):
        raise LookupError("运行记录不存在")

    existing = db.execute(
        select(CoachFeedback).where(
            CoachFeedback.user_id == user_id,
            CoachFeedback.message_id == message.id,
        )
    ).scalar_one_or_none()

    if existing is None:
        item = CoachFeedback(
            user_id=user_id,
            message_id=message.id,
            run_id=run.id if run is not None else None,
            rating=rating,
            reason=normalized_reason,
            comment=(comment or "").strip()[:500] or None,
            prompt_version=run.prompt_version if run is not None else None,
            model=run.model if run is not None else None,
        )
        db.add(item)
    else:
        item = existing
        item.run_id = run.id if run is not None else item.run_id
        item.rating = rating
        item.reason = normalized_reason
        item.comment = (comment or "").strip()[:500] or None
        item.prompt_version = (
            run.prompt_version if run is not None else item.prompt_version
        )
        item.model = run.model if run is not None else item.model
        item.updated_at = utcnow()

    db.commit()
    db.refresh(item)
    return item
