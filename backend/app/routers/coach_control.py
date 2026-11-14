"""Coach control-plane API.

This is the new session/capability/action surface. The legacy ``/agent`` and
``/coach`` chat endpoints remain during migration.
"""

from __future__ import annotations

from datetime import timedelta
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import and_, func, or_, select

from ..deps import CurrentUser, DBSession
from ..models import (
    CoachActionRecord,
    CoachInbox,
    CoachPending,
    CoachSession,
    CoachTurn,
    DomainEvent,
    utcnow,
)
from ..services import access
from ..services.coach_control import runtime
from ..services.coach_control.context import build_control_context
from ..services.coach_control.events import emit_event, list_inbox
from ..services.coach_control.registry import capability_payloads
from ..services.rate_limit import enforce as enforce_rate_limit

router = APIRouter(prefix="/coach", tags=["coach-control"])


class CoachTurnIn(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    session_id: str | None = Field(default=None, max_length=36)
    app_context: dict[str, Any] | None = None


class ClientDiagnosticIn(BaseModel):
    kind: str = Field(default="metrickit", max_length=40)
    app_version: str | None = Field(default=None, max_length=40)
    data_base64: str = Field(min_length=1, max_length=400_000)


@router.post("/diagnostics")
def upload_client_diagnostic(
    payload: ClientDiagnosticIn,
    user_id: CurrentUser,
    db: DBSession,
):
    enforce_rate_limit(db, "client_diagnostics", user_id, 10, 60)
    emit_event(
        db,
        user_id,
        "ClientDiagnostic",
        entity_type="ios",
        payload={
            "kind": payload.kind,
            "app_version": payload.app_version,
            "data_base64": payload.data_base64,
        },
    )
    db.commit()
    return {"ok": True}


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
    intent_rows = db.execute(
        select(CoachTurn.intent, func.count())
        .where(CoachTurn.user_id == user_id)
        .group_by(CoachTurn.intent)
    ).all()
    pending_rows = db.execute(
        select(CoachPending.status, func.count())
        .where(CoachPending.user_id == user_id)
        .group_by(CoachPending.status)
    ).all()
    day = func.date(CoachTurn.created_at)
    daily_rows = db.execute(
        select(day, func.count())
        .where(
            CoachTurn.user_id == user_id,
            CoachTurn.created_at >= utcnow() - timedelta(days=7),
        )
        .group_by(day)
        .order_by(day)
    ).all()
    unread = db.execute(
        select(func.count()).where(
            CoachInbox.user_id == user_id,
            CoachInbox.status == "unread",
        )
    ).scalar_one()
    return {
        "turns": {str(key): int(value) for key, value in turn_rows},
        "intents": {str(key or "unknown"): int(value) for key, value in intent_rows},
        "pending": {str(key): int(value) for key, value in pending_rows},
        "actions": {str(key): int(value) for key, value in action_rows},
        "events": {str(key): int(value) for key, value in event_rows},
        "daily_turns": [
            {"date": str(key), "count": int(value)} for key, value in daily_rows
        ],
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
    before_id: str | None = None,
):
    session = db.get(CoachSession, session_id)
    if session is None or session.user_id != user_id:
        raise HTTPException(status_code=404, detail="会话不存在")
    limit = max(1, min(100, limit))
    statement = select(CoachTurn).where(
        CoachTurn.session_id == session_id,
        CoachTurn.user_id == user_id,
    )
    if before_id:
        anchor = db.get(CoachTurn, before_id)
        if (
            anchor is None
            or anchor.user_id != user_id
            or anchor.session_id != session_id
        ):
            raise HTTPException(status_code=404, detail="消息不存在")
        statement = statement.where(
            or_(
                CoachTurn.created_at < anchor.created_at,
                and_(
                    CoachTurn.created_at == anchor.created_at,
                    CoachTurn.id < anchor.id,
                ),
            )
        )
    rows = (
        db.execute(
            statement.order_by(
                CoachTurn.created_at.desc(),
                CoachTurn.id.desc(),
            ).limit(limit + 1)
        )
        .scalars()
        .all()
    )
    has_more = len(rows) > limit
    rows = rows[:limit]
    rows.reverse()
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
        ],
        "has_more": has_more,
        "next_before_id": rows[0].id if has_more and rows else None,
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
