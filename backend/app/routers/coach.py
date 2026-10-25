import asyncio
import json

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy import select

from ..deps import CurrentUser, DBSession
from ..models import ChatMessage, ChatSession, Profile, Program
from ..schemas import ChatIn
from ..services.coach import coach_reply

router = APIRouter(prefix="/coach", tags=["coach"])


def _active_program(db: DBSession, user_id: str) -> Program | None:
    return (
        db.execute(
            select(Program)
            .where(Program.user_id == user_id, Program.status == "active")
            .order_by(Program.version.desc())
        )
        .scalars()
        .first()
    )


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
