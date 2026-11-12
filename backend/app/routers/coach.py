import asyncio
import json
import re

from fastapi import APIRouter, File, Form, Header, HTTPException, UploadFile
from fastapi.responses import StreamingResponse

from ..deps import CurrentUser, DBSession
from ..models import ChatMessage, ChatSession, Profile, Program, utcnow
from ..schemas import ChatIn, VoiceChatIn
from ..services import access, coach_vision, generation, photo_cache
from ..services.coach import coach_reply, watch_voice_reply
from ..services.coach_core import (
    requires_phone_confirmation as _requires_phone_confirmation,
)
from ..services.memory import schedule_memory_extraction
from ..services.queries import active_program
from ..services.rate_limit import enforce as enforce_rate_limit
from ..services.safety import assess_safety

router = APIRouter(prefix="/coach", tags=["coach"])


def _active_program(db: DBSession, user_id: str) -> Program | None:
    return active_program(db, user_id)


def _reserve_coach_turn(db: DBSession, profile: Profile, message: str):
    enforce_rate_limit(db, "coach_chat", profile.user_id, 10, 60)
    decision = assess_safety(profile, message)
    if decision.reply is not None:
        return None
    used, coach_period, reset_at = access.coach_usage(db, profile.user_id)
    if not access.has_pro(db, profile.user_id) and used >= access.COACH_DAILY_LIMIT:
        raise HTTPException(
            status_code=429,
            detail={
                "code": "COACH_QUOTA_EXHAUSTED",
                "message": "今日免费 AI 教练额度已用完",
                "reset_at": reset_at.isoformat(),
            },
        )
    if not access.reserve_coach_message(
        db,
        profile.user_id,
        period=coach_period,
    ):
        raise HTTPException(
            status_code=429,
            detail={
                "code": "COACH_QUOTA_EXHAUSTED",
                "message": "今日免费 AI 教练额度已用完",
            },
        )
    return coach_period


def _should_extract_memory(message: str, safety_flag: str | None) -> bool:
    """Only learn from substantive, non-safety turns.

    Safety messages can contain sensitive health facts; don't persist them
    automatically. Very short messages ("在吗") don't carry stable facts.
    """
    return safety_flag is None and len(message.strip()) >= 8


MAX_VISION_FILES = 6
MAX_VISION_FILE_BYTES = 8 * 1024 * 1024
MAX_VISION_TOTAL_BYTES = 24 * 1024 * 1024
IMAGE_CONTENT_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/heic",
    "image/heif",
    "image/webp",
}


def _require_image_upload(upload: UploadFile) -> None:
    """Photos are the API contract; video must be converted to frames first.

    The iOS client already extracts keyframes before calling this endpoint.
    Rejecting video here keeps a 200MB upload from reaching the vision model
    by mistake and gives the client a precise error.
    """
    content_type = (upload.content_type or "").lower()
    if content_type and content_type not in IMAGE_CONTENT_TYPES:
        raise HTTPException(
            status_code=415,
            detail="请上传图片；视频请先抽取关键帧再上传",
        )




def _vision_safety_response(decision) -> dict:
    return {
        "mode": "general",
        "is_training": False,
        "summary": decision.reply or "",
        "observations": [],
        "next_cue": "",
        "safety_flag": decision.flag,
        "warning": None,
    }

def _vision_profile(db: DBSession, user_id: str) -> Profile:
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")
    return profile


def _vision_session(
    db: DBSession,
    user_id: str,
    session_id: str | None,
    question: str,
) -> ChatSession:
    """Keep a text-only visual turn so later Agent replies can follow up.

    Raw images are deliberately not stored; only the question, a marker and the
    compact visual summary are persisted.
    """
    if session_id:
        session = db.get(ChatSession, session_id.strip().lower())
        if session is None or session.user_id != user_id:
            raise HTTPException(status_code=404, detail="对话不存在")
        return session
    session = ChatSession(
        user_id=user_id,
        title=(question.strip()[:30] or "图片分析"),
    )
    db.add(session)
    db.commit()
    return session


def _vision_conversation_context(session: ChatSession, limit: int = 6) -> str:
    lines: list[str] = []
    for item in session.messages[-limit:]:
        if item.role not in {"user", "assistant"}:
            continue
        role = "用户" if item.role == "user" else "助手"
        lines.append(f"{role}：{item.content[:300]}")
    return "\n".join(lines)


def _vision_history_text(result: dict) -> str:
    parts: list[str] = []
    summary = str(result.get("summary") or "").strip()
    if summary:
        parts.append(summary)
    observations = result.get("observations") or []
    if observations:
        parts.append("可见：" + "；".join(str(item)[:80] for item in observations[:3]))
    next_cue = str(result.get("next_cue") or "").strip()
    if next_cue:
        parts.append("提示：" + next_cue[:240])
    return "\n".join(parts)[:4000] or "图片分析完成。"


def _record_vision_turn(
    db: DBSession,
    session: ChatSession,
    question: str,
    image_count: int,
    result: dict,
) -> dict:
    marker = "[图片]" if image_count <= 1 else f"[图片 x{image_count}]"
    content = f"{marker} {question.strip()}".strip()
    session.messages.append(
        ChatMessage(role="user", content=content[:2000])
    )
    session.messages.append(
        ChatMessage(
            role="assistant",
            content=_vision_history_text(result),
            safety_flag=result.get("safety_flag"),
        )
    )
    db.commit()
    result["session_id"] = session.id
    return result


@router.post("/vision")
async def vision(
    user_id: CurrentUser,
    db: DBSession,
    file: UploadFile = File(...),
    question: str = Form(default=""),
    session_id: str | None = Form(default=None),
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    """Review one photo, then keep a text-only visual turn for follow-ups."""
    profile = _vision_profile(db, user_id)
    decision = assess_safety(profile, question)
    if decision.reply:
        session = _vision_session(db, user_id, session_id, question)
        return _record_vision_turn(
            db, session, question, 1, _vision_safety_response(decision)
        )
    access.require_feature(db, user_id, access.FEATURE_AI_VISION)
    enforce_rate_limit(db, "coach_vision", user_id, 6, 60)
    _require_image_upload(file)

    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="图片为空")
    if len(image_bytes) > MAX_VISION_FILE_BYTES:
        raise HTTPException(status_code=413, detail="图片不能超过 8MB")

    feature_key = access.FEATURE_AI_VISION
    key = photo_cache.normalize_key(idempotency_key)
    cached = photo_cache.get_cached_result(
        db, user_id, feature_key, key
    )
    if cached is not None:
        return cached

    session = _vision_session(db, user_id, session_id, question)
    conversation_context = _vision_conversation_context(session)
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
        result = _record_vision_turn(db, session, question, 1, result)
        photo_cache.store_cached_result(
            db, user_id, feature_key, key, result
        )
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


@router.post("/vision/batch")
async def vision_batch(
    user_id: CurrentUser,
    db: DBSession,
    files: list[UploadFile] = File(...),
    question: str = Form(default=""),
    session_id: str | None = Form(default=None),
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    """Review several staged photos as one ordered set."""
    profile = _vision_profile(db, user_id)
    decision = assess_safety(profile, question)
    if decision.reply:
        session = _vision_session(db, user_id, session_id, question)
        return _record_vision_turn(
            db, session, question, len(files), _vision_safety_response(decision)
        )
    access.require_feature(db, user_id, access.FEATURE_AI_VISION)
    enforce_rate_limit(db, "coach_vision", user_id, 6, 60)
    if not files:
        raise HTTPException(status_code=400, detail="没有收到图片")
    if len(files) > MAX_VISION_FILES:
        raise HTTPException(status_code=413, detail="一次最多上传 6 张图片")

    images: list[bytes] = []
    total_bytes = 0
    for upload in files:
        _require_image_upload(upload)
        image_bytes = await upload.read()
        if not image_bytes:
            continue
        if len(image_bytes) > MAX_VISION_FILE_BYTES:
            raise HTTPException(status_code=413, detail="单张图片不能超过 8MB")
        total_bytes += len(image_bytes)
        if total_bytes > MAX_VISION_TOTAL_BYTES:
            raise HTTPException(status_code=413, detail="图片总大小不能超过 24MB")
        images.append(image_bytes)

    if not images:
        raise HTTPException(status_code=400, detail="图片为空")
    feature_key = access.FEATURE_AI_VISION
    key = photo_cache.normalize_key(idempotency_key)
    cached = photo_cache.get_cached_result(
        db, user_id, feature_key, key
    )
    if cached is not None:
        return cached

    session = _vision_session(db, user_id, session_id, question)
    conversation_context = _vision_conversation_context(session)
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
        result = _record_vision_turn(
            db, session, question, len(images), result
        )
        photo_cache.store_cached_result(
            db, user_id, feature_key, key, result
        )
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


def _speech_text(reply: str) -> str:
    text = re.sub(r"```.*?```", "", reply, flags=re.DOTALL)
    text = re.sub(r"[#*_`>\-]", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        return "详细内容看手机。"
    if len(text) <= 120:
        return text
    return text[:118].rstrip("，。；;、 ") + "…详细内容看手机。"


@router.post("/voice")
async def voice_chat(payload: VoiceChatIn, user_id: CurrentUser, db: DBSession):
    """Short, read-only coach answer for the Apple Watch.

    The watch never creates plans or actions here. Plan-changing requests are
    returned to the phone, and nothing is written to long-term memory.
    """
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")
    access.require_feature(db, user_id, access.FEATURE_WATCH_TRAINING)

    message = payload.message.strip()
    if not message:
        raise HTTPException(status_code=422, detail="请输入问题")
    requires_phone = _requires_phone_confirmation(message)

    # Safety always wins over the read-only plan-change shortcut. A sentence
    # such as “膝盖疼，帮我把下周改成四练” must surface the injury guidance.
    safety = assess_safety(profile, message)
    if safety.reply:
        return {
            "reply": safety.reply,
            "speech_text": _speech_text(safety.reply),
            "safety_flag": safety.flag,
            "requires_phone_confirmation": requires_phone,
            "citations": [],
            "server_time": utcnow().isoformat(),
        }

    if requires_phone:
        reply = "这个需要到 iPhone 上确认。"
        return {
            "reply": reply,
            "speech_text": reply,
            "safety_flag": None,
            "requires_phone_confirmation": True,
            "citations": [],
            "server_time": utcnow().isoformat(),
        }

    enforce_rate_limit(db, "coach_voice", user_id, 10, 60)
    result = await watch_voice_reply(
        db,
        profile,
        _active_program(db, user_id),
        message,
        payload.context,
        safety_checked=True,
    )
    reply = result["reply"]
    return {
        "reply": reply,
        "speech_text": _speech_text(reply),
        "safety_flag": result["safety_flag"],
        "requires_phone_confirmation": result[
            "requires_phone_confirmation"
        ],
        "citations": result.get("citations", []),
        "server_time": utcnow().isoformat(),
    }


@router.post("/chat")
async def chat(payload: ChatIn, user_id: CurrentUser, db: DBSession):
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")

    session: ChatSession | None = None
    if payload.session_id:
        session = db.get(ChatSession, payload.session_id)
        if session is None or session.user_id != user_id:
            raise HTTPException(status_code=404, detail="对话不存在")

    if session is None:
        session = ChatSession(
            user_id=user_id, title=payload.message[:30] or "新对话"
        )
        db.add(session)
        db.commit()

    history = list(session.messages)
    reserved_period = _reserve_coach_turn(db, profile, payload.message)
    lease = None
    if reserved_period is not None:
        try:
            lease = generation.begin_generation(
                db,
                user_id,
                "coach_chat",
                cooldown_seconds=0,
            )
        except Exception:
            access.release_coach_message(db, user_id, period=reserved_period)
            raise
    try:
        result = await coach_reply(
            db,
            profile,
            _active_program(db, user_id),
            history,
            payload.message,
            payload.skill,
            payload.context,
        )
    except Exception:
        if lease is not None:
            generation.abort_generation(db, lease, user_id=user_id)
        if reserved_period is not None:
            access.release_coach_message(db, user_id, period=reserved_period)
        raise
    if lease is not None:
        generation.complete_generation(
            db,
            lease,
            user_id=user_id,
            result_ref=session.id,
        )

    session.messages.append(
        ChatMessage(role="user", content=payload.message)
    )
    session.messages.append(
        ChatMessage(
            role="assistant",
            content=result["reply"],
            citations=result["citations"],
            safety_flag=result["safety_flag"],
        )
    )
    db.commit()
    if _should_extract_memory(payload.message, result["safety_flag"]):
        schedule_memory_extraction(
            user_id, payload.message, result["reply"], source="coach"
        )

    return {
        "session_id": session.id,
        "reply": result["reply"],
        "safety_flag": result["safety_flag"],
        "citations": result["citations"],
    }


@router.post("/chat/stream")
async def chat_stream(payload: ChatIn, user_id: CurrentUser, db: DBSession):
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")

    session: ChatSession | None = None
    if payload.session_id:
        session = db.get(ChatSession, payload.session_id)
        if session is None or session.user_id != user_id:
            raise HTTPException(status_code=404, detail="对话不存在")
    if session is None:
        session = ChatSession(
            user_id=user_id, title=payload.message[:30] or "新对话"
        )
        db.add(session)
        db.commit()

    history = list(session.messages)
    reserved_period = _reserve_coach_turn(db, profile, payload.message)
    lease = None
    if reserved_period is not None:
        try:
            lease = generation.begin_generation(
                db,
                user_id,
                "coach_chat",
                cooldown_seconds=0,
            )
        except Exception:
            access.release_coach_message(db, user_id, period=reserved_period)
            raise
    try:
        result = await coach_reply(
            db,
            profile,
            _active_program(db, user_id),
            history,
            payload.message,
            payload.skill,
            payload.context,
        )
    except Exception:
        if lease is not None:
            generation.abort_generation(db, lease, user_id=user_id)
        if reserved_period is not None:
            access.release_coach_message(db, user_id, period=reserved_period)
        raise
    if lease is not None:
        generation.complete_generation(
            db,
            lease,
            user_id=user_id,
            result_ref=session.id,
        )

    session.messages.append(ChatMessage(role="user", content=payload.message))
    session.messages.append(
        ChatMessage(
            role="assistant",
            content=result["reply"],
            citations=result["citations"],
            safety_flag=result["safety_flag"],
        )
    )
    db.commit()
    if _should_extract_memory(payload.message, result["safety_flag"]):
        schedule_memory_extraction(
            user_id, payload.message, result["reply"], source="coach"
        )

    session_id = session.id
    reply = result["reply"]
    safety_flag = result["safety_flag"]
    citations = result["citations"]

    async def event_stream():
        for index in range(0, len(reply), 6):
            chunk = reply[index : index + 6]
            yield f"event: delta\ndata: {json.dumps({'text': chunk}, ensure_ascii=False)}\n\n"
            await asyncio.sleep(0.015)
        yield (
            "event: done\ndata: "
            + json.dumps(
                {
                    "session_id": session_id,
                    "safety_flag": safety_flag,
                    "citations": citations,
                },
                ensure_ascii=False,
            )
            + "\n\n"
        )

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
