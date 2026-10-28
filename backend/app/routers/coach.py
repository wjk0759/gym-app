import asyncio
import json

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import StreamingResponse

from ..deps import CurrentUser, DBSession
from ..models import ChatMessage, ChatSession, Profile, Program
from ..schemas import ChatIn
from ..services import coach_vision
from ..services.coach import coach_reply
from ..services.memory import schedule_memory_extraction
from ..services.queries import active_program

router = APIRouter(prefix="/coach", tags=["coach"])


def _active_program(db: DBSession, user_id: str) -> Program | None:
    return active_program(db, user_id)


def _should_extract_memory(message: str, safety_flag: str | None) -> bool:
    """Only learn from substantive, non-safety turns.

    Safety messages can contain sensitive health facts; don't persist them
    automatically. Very short messages ("在吗") don't carry stable facts.
    """
    return safety_flag is None and len(message.strip()) >= 8


@router.post("/vision")
async def vision(
    user_id: CurrentUser,
    db: DBSession,
    file: UploadFile = File(...),
    question: str = Form(default=""),
):
    """One-shot training-photo review. Photos are not persisted server-side."""
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")

    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="图片为空")
    if len(image_bytes) > 8 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="图片不能超过 8MB")

    return await coach_vision.review(image_bytes, question)


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
    result = await coach_reply(
        db,
        profile,
        _active_program(db, user_id),
        history,
        payload.message,
        payload.skill,
        payload.context,
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
    result = await coach_reply(
        db,
        profile,
        _active_program(db, user_id),
        history,
        payload.message,
        payload.skill,
        payload.context,
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

    async def event_stream():
        for index in range(0, len(reply), 6):
            chunk = reply[index : index + 6]
            yield f"event: delta\ndata: {json.dumps({'text': chunk}, ensure_ascii=False)}\n\n"
            await asyncio.sleep(0.015)
        yield (
            "event: done\ndata: "
            + json.dumps(
                {"session_id": session_id, "safety_flag": safety_flag},
                ensure_ascii=False,
            )
            + "\n\n"
        )

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
