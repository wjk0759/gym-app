from __future__ import annotations

import asyncio
import time

from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from ..deps import CurrentUser, DBSession
from ..models import (
    AgentActionEvent,
    AgentPlanProposal,
    AgentRun,
    ChatMessage,
    ChatSession,
    CoachFeedback,
    Profile,
    utcnow,
)
from ..schemas import (
    AgentActionResultIn,
    AgentChatIn,
    AgentFeedbackIn,
    WorkoutActionExecuteIn,
)
from ..services import access, generation
from ..services.agent import apply_proposal, generate_weekly_review, run_agent
from ..services.coach_feedback import save_feedback
from ..services.memory import list_memories
from ..services.rate_limit import enforce as enforce_rate_limit
from ..services.safety import assess_safety
from ..services.serializers import serialize_program
from ..services.workout_actions import (
    WorkoutActionConflict,
    WorkoutActionError,
    execute_modify_workout,
    prepare_modify_workout,
    undo_modify_workout,
)

router = APIRouter(prefix="/agent", tags=["agent"])

# 开发/单进程部署下的短时幂等缓存。正式多 worker 部署应替换为 Redis 或
# 数据库任务表；它至少能覆盖“客户端超时后立刻点重试”的常见情况。
_AGENT_RESULT_TTL_SECONDS = 600
_AGENT_RESULT_CACHE_LIMIT = 256
_agent_result_cache: dict[str, tuple[float, dict]] = {}
_agent_request_locks: dict[str, asyncio.Lock] = {}


def _agent_cache_key(user_id: str, request_id: str) -> str:
    return f"{user_id}:{request_id}"


def _cached_agent_result(user_id: str, request_id: str | None) -> dict | None:
    if not request_id:
        return None
    key = _agent_cache_key(user_id, request_id)
    item = _agent_result_cache.get(key)
    if item is None:
        return None
    created_at, result = item
    if time.monotonic() - created_at > _AGENT_RESULT_TTL_SECONDS:
        _agent_result_cache.pop(key, None)
        return None
    return result


def _remember_agent_result(user_id: str, request_id: str | None, result: dict) -> None:
    if not request_id or result.get("status") == "failed":
        return
    now = time.monotonic()
    _agent_result_cache[_agent_cache_key(user_id, request_id)] = (now, result)
    if len(_agent_result_cache) > _AGENT_RESULT_CACHE_LIMIT:
        expired = [
            key
            for key, (created_at, _) in _agent_result_cache.items()
            if now - created_at > _AGENT_RESULT_TTL_SECONDS
        ]
        for key in expired:
            _agent_result_cache.pop(key, None)
        while len(_agent_result_cache) > _AGENT_RESULT_CACHE_LIMIT:
            _agent_result_cache.pop(next(iter(_agent_result_cache)))


async def _agent_chat_inner(
    payload: AgentChatIn,
    user_id: str,
    db: DBSession,
):
    cached = _cached_agent_result(user_id, payload.request_id)
    if cached is not None:
        return cached

    enforce_rate_limit(db, "agent_chat", user_id, 10, 60)
    session: ChatSession | None = None
    if payload.session_id:
        session = db.get(ChatSession, payload.session_id)
        if session is None or session.user_id != user_id:
            raise HTTPException(status_code=404, detail="对话不存在")
    if session is None:
        session = ChatSession(
            user_id=user_id,
            title=payload.message[:30] or "新对话",
        )
        db.add(session)
        db.commit()

    history = list(session.messages)
    profile = db.get(Profile, user_id)
    safety = assess_safety(profile, payload.message) if profile else None
    reserved = False
    coach_period = None
    lease = None
    if safety is None or safety.reply is None:
        used, coach_period, reset_at = access.coach_usage(db, user_id)
        if not access.has_pro(db, user_id) and used >= access.COACH_DAILY_LIMIT:
            raise HTTPException(
                status_code=429,
                detail={
                    "code": "COACH_QUOTA_EXHAUSTED",
                    "message": "今日免费 AI 教练额度已用完",
                    "reset_at": reset_at.isoformat(),
                },
            )
        reserved = True
        if not access.reserve_coach_message(db, user_id, period=coach_period):
            raise HTTPException(
                status_code=429,
                detail={
                    "code": "COACH_QUOTA_EXHAUSTED",
                    "message": "今日免费 AI 教练额度已用完",
                },
            )
        try:
            lease = generation.begin_generation(
                db,
                user_id,
                "agent_chat",
                cooldown_seconds=0,
            )
        except Exception:
            access.release_coach_message(db, user_id, period=coach_period)
            raise
    try:
        result = await run_agent(
            db,
            user_id,
            payload.message,
            session_id=session.id,
            history=history,
            skill=payload.skill,
            app_context=payload.app_context,
        )
    except Exception as exc:  # safety net: never turn an Agent crash into a 500
        if lease is not None:
            generation.abort_generation(db, lease, user_id=user_id)
        if reserved and coach_period is not None:
            access.release_coach_message(db, user_id, period=coach_period)
        raise HTTPException(
            status_code=503,
            detail="教练 Agent 暂时不可用，请重试",
        ) from exc
    if lease is not None:
        generation.complete_generation(
            db,
            lease,
            user_id=user_id,
            result_ref=result["run_id"],
        )

    user_message = ChatMessage(role="user", content=payload.message)
    assistant_message = ChatMessage(
        role="assistant",
        content=result["reply"],
        safety_flag=result.get("safety_flag"),
    )
    session.messages.extend([user_message, assistant_message])
    db.commit()

    response = {
        "session_id": session.id,
        "message_id": assistant_message.id,
        "run_id": result["run_id"],
        "status": result["status"],
        "reply": result["reply"],
        "proposal": result["proposal"],
        "actions": result.get("actions", []),
        "safety_flag": result.get("safety_flag"),
        "elapsed_ms": result["elapsed_ms"],
        "usage": result.get("usage", {}),
    }
    _remember_agent_result(user_id, payload.request_id, response)
    return response


@router.post("/chat")
async def agent_chat(
    payload: AgentChatIn,
    user_id: CurrentUser,
    db: DBSession,
):
    # 同一 request_id 的并发重试等待第一个请求完成后再读缓存，
    # 避免客户端断开/重试时同时创建两条 AgentRun。
    if not payload.request_id:
        return await _agent_chat_inner(payload, user_id, db)

    key = _agent_cache_key(user_id, payload.request_id)
    lock = _agent_request_locks.get(key)
    if lock is None:
        if len(_agent_request_locks) > _AGENT_RESULT_CACHE_LIMIT:
            for old_key, old_lock in list(_agent_request_locks.items()):
                if not old_lock.locked():
                    _agent_request_locks.pop(old_key, None)
        lock = asyncio.Lock()
        _agent_request_locks[key] = lock
    async with lock:
        return await _agent_chat_inner(payload, user_id, db)


@router.post("/actions/{action_id}/result")
def report_action_result(
    action_id: str,
    payload: AgentActionResultIn,
    user_id: CurrentUser,
    db: DBSession,
):
    action_id = action_id.strip()
    if not 1 <= len(action_id) <= 64:
        raise HTTPException(status_code=400, detail="action_id 不合法")
    run = None
    if payload.run_id:
        run = db.get(AgentRun, payload.run_id)
        if run is None or run.user_id != user_id:
            raise HTTPException(status_code=400, detail="run_id 不合法")
    event = db.execute(
        select(AgentActionEvent).where(
            AgentActionEvent.user_id == user_id,
            AgentActionEvent.action_id == action_id,
        )
    ).scalar_one_or_none()
    if event is None:
        event = AgentActionEvent(
            user_id=user_id,
            action_id=action_id,
            action_type=payload.action_type,
            status=payload.status,
        )
        db.add(event)
    event.run_id = payload.run_id or (run.id if run else event.run_id)
    event.action_type = payload.action_type
    event.status = payload.status
    event.message = (payload.message or "")[:500] or None
    event.detail = {**(event.detail or {}), **(payload.detail or {})}
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        event = db.execute(
            select(AgentActionEvent).where(
                AgentActionEvent.user_id == user_id,
                AgentActionEvent.action_id == action_id,
            )
        ).scalar_one()
        event.run_id = payload.run_id or (run.id if run else event.run_id)
        event.action_type = payload.action_type
        event.status = payload.status
        event.message = (payload.message or "")[:500] or None
        event.detail = {**(event.detail or {}), **(payload.detail or {})}
        db.commit()
    return {"ok": True, "action_id": event.action_id, "status": event.status}


@router.post("/feedback")
def coach_feedback(
    payload: AgentFeedbackIn,
    user_id: CurrentUser,
    db: DBSession,
):
    enforce_rate_limit(db, "coach_feedback", user_id, 30, 3600)
    try:
        item = save_feedback(
            db,
            user_id,
            message_id=payload.message_id,
            run_id=payload.run_id,
            rating=payload.rating,
            reason=payload.reason,
            comment=payload.comment,
        )
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return {
        "id": item.id,
        "message_id": item.message_id,
        "run_id": item.run_id,
        "rating": item.rating,
        "reason": item.reason,
        "created_at": item.created_at.isoformat() if item.created_at else None,
    }


@router.get("/feedback")
def list_coach_feedback(
    user_id: CurrentUser,
    db: DBSession,
    limit: int = 20,
):
    limit = max(1, min(100, limit))
    rows = (
        db.execute(
            select(CoachFeedback)
            .where(CoachFeedback.user_id == user_id)
            .order_by(CoachFeedback.created_at.desc())
            .limit(limit)
        )
        .scalars()
        .all()
    )
    return {
        "items": [
            {
                "id": item.id,
                "message_id": item.message_id,
                "run_id": item.run_id,
                "rating": item.rating,
                "reason": item.reason,
                "comment": item.comment,
                "created_at": (
                    item.created_at.isoformat() if item.created_at else None
                ),
                "updated_at": (
                    item.updated_at.isoformat() if item.updated_at else None
                ),
            }
            for item in rows
        ]
    }


def _clean_action_id(action_id: str) -> str:
    value = (action_id or "").strip()
    if not 1 <= len(value) <= 64:
        raise HTTPException(status_code=400, detail="action_id 不合法")
    return value


def _workout_changes(payload: WorkoutActionExecuteIn) -> list[dict]:
    return [
        item.model_dump(exclude_none=True)
        for item in payload.changes
    ]


@router.post("/actions/{action_id}/dry-run")
def dry_run_workout_action(
    action_id: str,
    payload: WorkoutActionExecuteIn,
    user_id: CurrentUser,
    db: DBSession,
):
    action_id = _clean_action_id(action_id)
    try:
        program, day, before, after = prepare_modify_workout(
            db,
            user_id,
            plan_id=payload.plan_id,
            day_id=payload.day_id,
            changes=_workout_changes(payload),
            expected_plan_version=payload.expected_plan_version,
        )
    except WorkoutActionConflict as exc:
        raise HTTPException(
            status_code=409,
            detail={"code": "PLAN_VERSION_CONFLICT", "message": str(exc)},
        ) from exc
    except WorkoutActionError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return {
        "ok": True,
        "action_id": action_id,
        "plan_id": program.id,
        "day_id": day.id,
        "before": before,
        "after": after,
    }


@router.post("/actions/{action_id}/execute")
def execute_workout_action(
    action_id: str,
    payload: WorkoutActionExecuteIn,
    user_id: CurrentUser,
    db: DBSession,
):
    action_id = _clean_action_id(action_id)
    existing = db.execute(
        select(AgentActionEvent).where(
            AgentActionEvent.user_id == user_id,
            AgentActionEvent.action_id == action_id,
        )
    ).scalar_one_or_none()

    if existing is not None:
        detail = existing.detail or {}
        if existing.status == "executed" and detail.get("server_executed"):
            return {
                "program": detail.get("result"),
                "action_id": action_id,
                "status": "executed",
                "idempotent": True,
            }
        if existing.status == "undone":
            raise HTTPException(
                status_code=409,
                detail="这次改课已经撤销，请重新生成方案",
            )

    try:
        program, before, after_version = execute_modify_workout(
            db,
            user_id,
            plan_id=payload.plan_id,
            day_id=payload.day_id,
            changes=_workout_changes(payload),
            expected_plan_version=payload.expected_plan_version,
        )
    except WorkoutActionConflict as exc:
        raise HTTPException(
            status_code=409,
            detail={"code": "PLAN_VERSION_CONFLICT", "message": str(exc)},
        ) from exc
    except WorkoutActionError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    detail = {
        **(existing.detail if existing is not None else {}),
        "server_executed": True,
        "plan_id": payload.plan_id,
        "day_id": payload.day_id,
        "before": before,
        "after_version": after_version,
        "changes": _workout_changes(payload),
        "result": program,
    }
    if existing is None:
        existing = AgentActionEvent(
            user_id=user_id,
            action_id=action_id,
            action_type="modify_workout",
            status="executed",
        )
        db.add(existing)
    existing.action_type = "modify_workout"
    existing.status = "executed"
    existing.message = "服务端已应用改课"
    existing.detail = detail
    db.commit()
    return {
        "program": program,
        "action_id": action_id,
        "status": "executed",
        "idempotent": False,
    }


@router.post("/actions/{action_id}/undo")
def undo_workout_action(
    action_id: str,
    user_id: CurrentUser,
    db: DBSession,
):
    action_id = _clean_action_id(action_id)
    event = db.execute(
        select(AgentActionEvent).where(
            AgentActionEvent.user_id == user_id,
            AgentActionEvent.action_id == action_id,
        )
    ).scalar_one_or_none()
    detail = (event.detail or {}) if event is not None else {}
    if event is None or not detail.get("server_executed"):
        raise HTTPException(status_code=404, detail="改课记录不存在")
    if event.status != "executed":
        raise HTTPException(status_code=409, detail="改课当前不能撤销")
    before = detail.get("before") or []
    if not before:
        raise HTTPException(status_code=409, detail="缺少撤销快照")

    try:
        program = undo_modify_workout(
            db,
            user_id,
            plan_id=str(detail.get("plan_id") or ""),
            day_id=str(detail.get("day_id") or ""),
            before=before,
            expected_version=int(detail.get("after_version") or 0),
        )
    except WorkoutActionConflict as exc:
        raise HTTPException(
            status_code=409,
            detail={"code": "PLAN_VERSION_CONFLICT", "message": str(exc)},
        ) from exc
    except WorkoutActionError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    event.status = "undone"
    event.message = "用户撤销改课"
    event.detail = {
        **detail,
        "undone_at": utcnow().isoformat(),
    }
    db.commit()
    return {
        "program": program,
        "action_id": action_id,
        "status": "undone",
    }


@router.get("/actions")
def list_action_events(user_id: CurrentUser, db: DBSession, limit: int = 20):
    limit = max(1, min(100, limit))
    rows = db.execute(
        select(AgentActionEvent)
        .where(AgentActionEvent.user_id == user_id)
        .order_by(AgentActionEvent.created_at.desc())
        .limit(limit)
    ).scalars().all()
    return {
        "items": [
            {
                "action_id": item.action_id,
                "run_id": item.run_id,
                "action_type": item.action_type,
                "status": item.status,
                "message": item.message,
                "detail": item.detail or {},
                "created_at": item.created_at.isoformat() if item.created_at else None,
            }
            for item in rows
        ]
    }


@router.get("/proposals/{proposal_id}")
def get_proposal(
    proposal_id: str,
    user_id: CurrentUser,
    db: DBSession,
):
    proposal = db.get(AgentPlanProposal, proposal_id)
    if proposal is None or proposal.user_id != user_id:
        raise HTTPException(status_code=404, detail="计划草案不存在")
    return {
        "id": proposal.id,
        "title": proposal.title,
        "status": proposal.status,
        "changes": (proposal.diff_data or {}).get("changes", []),
        "diff": proposal.diff_data or {},
        "validation": proposal.validation_data or {},
        "expires_at": proposal.expires_at.isoformat() if proposal.expires_at else None,
        "created_at": proposal.created_at.isoformat() if proposal.created_at else None,
    }


@router.post("/reviews/weekly")
def weekly_review(user_id: CurrentUser, db: DBSession):
    access.require_feature(db, user_id, access.FEATURE_ADVANCED_REVIEW)
    try:
        return generate_weekly_review(db, user_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/memories")
def get_memories(user_id: CurrentUser, db: DBSession):    return {
        "items": [
            {
                "id": item.id,
                "kind": item.kind,
                "key": item.memory_key,
                "content": item.content,
                "source": item.source,
                "confidence": item.confidence,
                "updated_at": item.updated_at.isoformat() if item.updated_at else None,
            }
            for item in list_memories(db, user_id, 50)
        ]
    }


@router.delete("/memories/{memory_id}")
def delete_memory(memory_id: str, user_id: CurrentUser, db: DBSession):
    from ..models import AIMemory

    item = db.get(AIMemory, memory_id)
    if item is None or item.user_id != user_id:
        raise HTTPException(status_code=404, detail="记忆不存在")
    item.active = False
    db.commit()
    return {"status": "deleted", "id": item.id}


@router.post("/proposals/{proposal_id}/apply")
def apply_agent_proposal(
    proposal_id: str,
    user_id: CurrentUser,
    db: DBSession,
):
    access.require_feature(db, user_id, access.FEATURE_TRAINING_PLAN)
    try:
        program, proposal = apply_proposal(db, user_id, proposal_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except ValueError as exc:
        message = str(exc)
        status = 410 if "过期" in message else 409
        raise HTTPException(status_code=status, detail=message) from exc
    return {
        "proposal_id": proposal.id,
        "status": proposal.status,
        "program": serialize_program(program),
    }
