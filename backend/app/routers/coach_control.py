"""Coach control-plane API.

This is the new session/capability/action surface. The legacy ``/agent`` and
``/coach`` chat endpoints remain during migration.
"""

from __future__ import annotations

from datetime import timedelta
from typing import Any, Literal

from fastapi import APIRouter, File, Form, Header, HTTPException, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy import and_, func, or_, select

from ..deps import CurrentUser, DBSession
from ..models import (
    AIMemory,
    CoachActionRecord,
    CoachInbox,
    CoachPending,
    CoachSession,
    CoachTurn,
    DomainEvent,
    Profile,
    utcnow,
)
from ..services import access, coach_vision, generation, photo_cache, vision_turns
from ..services.coach_control import runtime
from ..services.coach_control.context import build_control_context
from ..services.coach_control.events import emit_event, list_inbox
from ..services.coach_control.registry import capability_payloads
from ..services.coach_control.state import (
    cancel_active_pending,
    get_active_pending,
    get_or_create_session,
    serialize_pending,
    serialize_session,
)
from ..services.rate_limit import enforce as enforce_rate_limit
from ..services.safety import assess_safety

router = APIRouter(prefix="/coach", tags=["coach-control"])


class CoachTurnIn(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    session_id: str | None = Field(default=None, max_length=36)
    app_context: dict[str, Any] | None = None


class ClientDiagnosticIn(BaseModel):
    kind: str = Field(default="metrickit", max_length=40)
    app_version: str | None = Field(default=None, max_length=40)
    data_base64: str = Field(min_length=1, max_length=400_000)


class CoachTurnFeedbackIn(BaseModel):
    rating: Literal["up", "down"]
    reason: str | None = Field(default=None, max_length=40)


@router.post("/diagnostics")
def upload_client_diagnostic(
    payload: ClientDiagnosticIn,
    user_id: CurrentUser,
    db: DBSession,
):
    enforce_rate_limit(db, "client_diagnostics", user_id, 3, 600)
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
    # Safety replies must never be blocked by the free daily quota. The runtime
    # repeats the deterministic check; this early pass only bypasses billing.
    safety = assess_safety(db.get(Profile, user_id), payload.message)
    reserved = False
    coach_period = None
    if not safety.reply and not access.has_pro(db, user_id):
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
        result = await runtime.handle_turn(
            db,
            user_id,
            payload.message,
            session_id=payload.session_id,
            app_context=payload.app_context,
        )
        if (
            reserved
            and coach_period is not None
            and result.get("intent") == "unsupported"
        ):
            access.release_coach_message(db, user_id, period=coach_period)
        return result
    except Exception as exc:  # noqa: BLE001 - never leak model/provider errors
        db.rollback()
        if reserved and coach_period is not None:
            access.release_coach_message(db, user_id, period=coach_period)
        raise HTTPException(
            status_code=503,
            detail="教练暂时不可用，请重试",
        ) from exc


@router.post("/turns/{turn_id}/feedback")
def coach_turn_feedback(
    turn_id: str,
    payload: CoachTurnFeedbackIn,
    user_id: CurrentUser,
    db: DBSession,
):
    turn = db.get(CoachTurn, turn_id)
    if turn is None or turn.user_id != user_id or not turn.reply:
        raise HTTPException(status_code=404, detail="消息不存在")
    existing = (
        db.execute(
            select(DomainEvent).where(
                DomainEvent.user_id == user_id,
                DomainEvent.type == "CoachTurnFeedback",
                DomainEvent.entity_id == turn_id,
            )
        )
        .scalars()
        .first()
    )
    if existing is None:
        emit_event(
            db,
            user_id,
            "CoachTurnFeedback",
            entity_type="coach_turn",
            entity_id=turn_id,
            payload={
                "rating": payload.rating,
                "reason": payload.reason,
                "intent": turn.intent,
            },
        )
        db.commit()
    return {"status": "recorded", "turn_id": turn_id}


@router.post("/turns/vision")
async def create_vision_turn(
    user_id: CurrentUser,
    db: DBSession,
    file: UploadFile = File(...),
    question: str = Form(default=""),
    caption: str = Form(default=""),
    session_id: str | None = Form(default=None),
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    """Analyze one photo inside the control-plane coach session.

    Keeps the legacy ``/coach/vision`` endpoint untouched for installed builds,
    but records the text-only visual turn in ``coach_turns`` so follow-up
    questions, history pagination and reinstall recovery share one ledger.
    """
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")
    decision = assess_safety(profile, question)
    session = get_or_create_session(db, user_id, session_id)
    if decision.reply:
        result = vision_turns.record_control_vision_turn(
            db,
            user_id,
            session,
            caption or question,
            1,
            vision_turns.safety_response(decision),
        )
        db.commit()
        return result

    access.require_feature(db, user_id, access.FEATURE_AI_VISION)
    enforce_rate_limit(db, "coach_vision", user_id, 6, 60)
    vision_turns.require_image_upload(file)
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="图片为空")
    if len(image_bytes) > vision_turns.MAX_VISION_FILE_BYTES:
        raise HTTPException(status_code=413, detail="图片不能超过 8MB")

    feature_key = access.FEATURE_AI_VISION
    key = photo_cache.normalize_key(idempotency_key)
    cached = photo_cache.get_cached_result(db, user_id, feature_key, key)
    if cached is not None:
        existing = vision_turns.existing_turn_result(db, user_id, cached)
        if existing is not None:
            return existing
        result = vision_turns.record_control_vision_turn(
            db, user_id, session, caption or question, 1, cached
        )
        db.commit()
        return result

    conversation_context = vision_turns.control_history_context(
        db, user_id, session.id
    )
    lease = generation.begin_generation(
        db,
        user_id,
        feature_key,
        idempotency_key=key,
        cooldown_seconds=5,
    )
    try:
        result = await coach_vision.review(
            image_bytes,
            question,
            safety_context=decision.caution,
            conversation_context=conversation_context,
            db=db,
            user_id=user_id,
        )
        result = vision_turns.record_control_vision_turn(
            db, user_id, session, caption or question, 1, result
        )
        photo_cache.store_cached_result(db, user_id, feature_key, key, result)
    except Exception:
        generation.abort_generation(db, lease, user_id=user_id)
        raise
    generation.complete_generation(
        db,
        lease,
        user_id=user_id,
        result_ref=session.id,
    )
    return result


@router.post("/turns/vision/batch")
async def create_vision_turn_batch(
    user_id: CurrentUser,
    db: DBSession,
    files: list[UploadFile] = File(...),
    question: str = Form(default=""),
    caption: str = Form(default=""),
    session_id: str | None = Form(default=None),
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    """Analyze several staged photos as one control-plane coach turn."""
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")
    decision = assess_safety(profile, question)
    session = get_or_create_session(db, user_id, session_id)
    if decision.reply:
        result = vision_turns.record_control_vision_turn(
            db,
            user_id,
            session,
            caption or question,
            len(files),
            vision_turns.safety_response(decision),
        )
        db.commit()
        return result

    access.require_feature(db, user_id, access.FEATURE_AI_VISION)
    enforce_rate_limit(db, "coach_vision", user_id, 6, 60)
    if not files:
        raise HTTPException(status_code=400, detail="没有收到图片")
    if len(files) > vision_turns.MAX_VISION_FILES:
        raise HTTPException(status_code=413, detail="一次最多上传 6 张图片")

    images: list[bytes] = []
    total_bytes = 0
    for upload in files:
        vision_turns.require_image_upload(upload)
        image_bytes = await upload.read()
        if not image_bytes:
            continue
        if len(image_bytes) > vision_turns.MAX_VISION_FILE_BYTES:
            raise HTTPException(status_code=413, detail="单张图片不能超过 8MB")
        total_bytes += len(image_bytes)
        if total_bytes > vision_turns.MAX_VISION_TOTAL_BYTES:
            raise HTTPException(status_code=413, detail="图片总大小不能超过 24MB")
        images.append(image_bytes)
    if not images:
        raise HTTPException(status_code=400, detail="图片为空")

    feature_key = access.FEATURE_AI_VISION
    key = photo_cache.normalize_key(idempotency_key)
    cached = photo_cache.get_cached_result(db, user_id, feature_key, key)
    if cached is not None:
        existing = vision_turns.existing_turn_result(db, user_id, cached)
        if existing is not None:
            return existing
        result = vision_turns.record_control_vision_turn(
            db, user_id, session, caption or question, len(images), cached
        )
        db.commit()
        return result

    conversation_context = vision_turns.control_history_context(
        db, user_id, session.id
    )
    lease = generation.begin_generation(
        db,
        user_id,
        feature_key,
        idempotency_key=key,
        cooldown_seconds=5,
    )
    try:
        result = await coach_vision.review_many(
            images,
            question,
            safety_context=decision.caution,
            conversation_context=conversation_context,
            db=db,
            user_id=user_id,
        )
        result = vision_turns.record_control_vision_turn(
            db, user_id, session, caption or question, len(images), result
        )
        photo_cache.store_cached_result(db, user_id, feature_key, key, result)
    except Exception:
        generation.abort_generation(db, lease, user_id=user_id)
        raise
    generation.complete_generation(
        db,
        lease,
        user_id=user_id,
        result_ref=session.id,
    )
    return result


@router.get("/sessions/latest")
def latest_session(user_id: CurrentUser, db: DBSession):
    """Resume the most recent coach session after reinstall or a new device."""
    session = (
        db.execute(
            select(CoachSession)
            .where(
                CoachSession.user_id == user_id,
                CoachSession.status != "closed",
            )
            .order_by(CoachSession.updated_at.desc(), CoachSession.id.desc())
            .limit(1)
        )
        .scalars()
        .first()
    )
    if session is None:
        return {"session": None, "pending": None}
    active = get_active_pending(db, user_id, session.id)
    return {
        "session": serialize_session(session, active),
        "pending": serialize_pending(active),
    }


@router.post("/sessions/reset")
def reset_sessions(user_id: CurrentUser, db: DBSession):
    """Start a fresh coach conversation after the user clears the chat.

    Rows are kept for audit; only the status changes so ``latest`` no longer
    resumes them and any unconfirmed card is dropped.
    """
    sessions = (
        db.execute(
            select(CoachSession).where(
                CoachSession.user_id == user_id,
                CoachSession.status != "closed",
            )
        )
        .scalars()
        .all()
    )
    for session in sessions:
        cancel_active_pending(db, session)
        session.status = "closed"
        session.pending_id = None
    db.commit()
    return {"closed": len(sessions)}


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


@router.post("/reviews/weekly")
def coach_weekly_review(user_id: CurrentUser, db: DBSession):
    access.require_feature(db, user_id, access.FEATURE_ADVANCED_REVIEW)
    from ..services.agent import generate_weekly_review

    try:
        return generate_weekly_review(db, user_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/memories")
def coach_memories(user_id: CurrentUser, db: DBSession):
    rows = (
        db.execute(
            select(AIMemory)
            .where(AIMemory.user_id == user_id, AIMemory.active.is_(True))
            .order_by(AIMemory.updated_at.desc())
            .limit(50)
        )
        .scalars()
        .all()
    )
    return {
        "items": [
            {
                "id": item.id,
                "kind": item.kind,
                "key": item.memory_key,
                "content": item.content,
                "source": item.source,
                "confidence": item.confidence,
                "updated_at": (
                    item.updated_at.isoformat() if item.updated_at else None
                ),
            }
            for item in rows
        ]
    }


@router.delete("/memories/{memory_id}")
def delete_coach_memory(memory_id: str, user_id: CurrentUser, db: DBSession):
    item = db.get(AIMemory, memory_id)
    if item is None or item.user_id != user_id:
        raise HTTPException(status_code=404, detail="记忆不存在")
    db.delete(item)
    db.commit()
    return {"deleted": True}


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
