"""Coach control-plane API.

This is the new session/capability/action surface. The legacy ``/agent`` and
``/coach`` chat endpoints remain during migration.
"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func, select

from ..deps import CurrentUser, DBSession
from ..models import (
    CoachActionRecord,
    CoachInbox,
    CoachSession,
    CoachTurn,
    DomainEvent,
    utcnow,
)
from ..services import access
from ..services.coach_control import runtime
from ..services.coach_control.context import build_control_context
from ..services.coach_control.events import list_inbox
from ..services.coach_control.registry import capability_payloads
from ..services.rate_limit import enforce as enforce_rate_limit

router = APIRouter(prefix="/coach", tags=["coach-control"])


class CoachTurnIn(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    session_id: str | None = Field(default=None, max_length=36)
    app_context: dict[str, Any] | None = None


@router.get("/capabilities")
def capabilities():
    return {"items": capability_payloads()}


@router.get("/context")
def coach_context(
    user_id: CurrentUser,
    db: DBSession,
):
    return build_control_context(db, user_id)


@router.get("/stats")
def coach_stats(
    user_id: CurrentUser,
    db: DBSession,
):
    turn_rows = db.execute(
        select(CoachTurn.status, func.count())
        .where(CoachTurn.user_id == user_id)
        .group_by(CoachTurn.status)
    ).all()
    action_rows = db.execute(
        select(CoachActionRecord.status, func.count())
        .where(CoachActionRecord.user_id == user_id)
        .group_by(CoachActionRecord.status)
    ).all()
    event_rows = db.execute(
        select(DomainEvent.type, func.count())
        .where(DomainEvent.user_id == user_id)
        .group_by(DomainEvent.type)
    ).all()
    unread = db.execute(
        select(func.count()).where(
            CoachInbox.user_id == user_id,
            CoachInbox.status == "unread",
        )
    ).scalar_one()
    return {
        "turns": {str(key): int(value) for key, value in turn_rows},
        "actions": {str(key): int(value) for key, value in action_rows},
        "events": {str(key): int(value) for key, value in event_rows},
        "inbox_unread": int(unread or 0),
    }


@router.post("/turns")
async def create_turn(
    payload: CoachTurnIn,
    user_id: CurrentUser,
    db: DBSession,
):
    enforce_rate_limit(db, "coach_control", user_id, 20, 60)
    reserved = False
    coach_period = None
    if not access.has_pro(db, user_id):
        used, coach_period, reset_at = access.coach_usage(db, user_id)
        if used >= access.COACH_DAILY_LIMIT:
            raise HTTPException(
                status_code=429,
                detail={
                    "code": "COACH_QUOTA_EXHAUSTED",
                    "message": "今日免费 AI 教练额度已用完",
                    "reset_at": reset_at.isoformat(),
                },
            )
        if not access.reserve_coach_message(
            db, user_id, period=coach_period
        ):
            raise HTTPException(
                status_code=429,
                detail={
                    "code": "COACH_QUOTA_EXHAUSTED",
                    "message": "今日免费 AI 教练额度已用完",
                },
            )
        reserved = True
    try:
        return await runtime.handle_turn(
            db,
            user_id,
            payload.message,
            session_id=payload.session_id,
            app_context=payload.app_context,
        )
    except Exception as exc:  # noqa: BLE001 - never leak model/provider errors
        db.rollback()
        if reserved and coach_period is not None:
            access.release_coach_message(db, user_id, period=coach_period)
        raise HTTPException(
            status_code=503,
            detail="教练暂时不可用，请重试",
        ) from exc


@router.get("/sessions/{session_id}")
def get_session(
    session_id: str,
    user_id: CurrentUser,
    db: DBSession,
):
    try:
        return runtime.session_state(db, user_id, session_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/sessions/{session_id}/turns")
def coach_history(
    session_id: str,
    user_id: CurrentUser,
    db: DBSession,
    limit: int = 50,
):
    session = db.get(CoachSession, session_id)
    if session is None or session.user_id != user_id:
        raise HTTPException(status_code=404, detail="会话不存在")
    limit = max(1, min(100, limit))
    rows = (
        db.execute(
            select(CoachTurn)
            .where(
                CoachTurn.session_id == session_id,
                CoachTurn.user_id == user_id,
            )
            .order_by(CoachTurn.created_at.asc())
            .limit(limit)
        )
        .scalars()
        .all()
    )
    return {
        "items": [
            {
                "id": item.id,
                "intent": item.intent,
                "status": item.status,
                "input_text": item.input_text,
                "reply": item.reply,
                "created_at": (
                    item.created_at.isoformat() if item.created_at else None
                ),
            }
            for item in rows
        ]
    }


@router.post("/pending/{pending_id}/confirm")
def confirm_pending(
    pending_id: str,
    user_id: CurrentUser,
    db: DBSession,
):
    try:
        return runtime.confirm_pending(db, user_id, pending_id)
    except LookupError as exc:
        db.rollback()
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        db.rollback()
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.post("/pending/{pending_id}/cancel")
def cancel_pending(
    pending_id: str,
    user_id: CurrentUser,
    db: DBSession,
):
    try:
        return runtime.cancel(db, user_id, pending_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/actions/{action_id}/undo")
def undo_action(
    action_id: str,
    user_id: CurrentUser,
    db: DBSession,
):
    try:
        return runtime.undo_action(db, user_id, action_id)
    except LookupError as exc:
        db.rollback()
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        db.rollback()
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get("/inbox")
def coach_inbox(
    user_id: CurrentUser,
    db: DBSession,
    limit: int = 20,
    status: str | None = None,
):
    items = list_inbox(db, user_id, limit, status)
    return {"items": items}


@router.post("/inbox/read-all")
def read_all_coach_inbox(
    user_id: CurrentUser,
    db: DBSession,
):
    items = (
        db.execute(
            select(CoachInbox).where(
                CoachInbox.user_id == user_id,
                CoachInbox.status == "unread",
            )
        )
        .scalars()
        .all()
    )
    for item in items:
        item.status = "read"
        item.read_at = utcnow()
    db.commit()
    return {"ok": True, "updated": len(items)}


@router.post("/inbox/{item_id}/read")
def read_coach_inbox(
    item_id: str,
    user_id: CurrentUser,
    db: DBSession,
):
    item = db.get(CoachInbox, item_id)
    if item is None or item.user_id != user_id:
        raise HTTPException(status_code=404, detail="消息不存在")
    item.status = "read"
    item.read_at = utcnow()
    db.commit()
    return {"ok": True, "id": item.id, "status": item.status}
