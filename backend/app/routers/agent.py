from __future__ import annotations

from fastapi import APIRouter, HTTPException
from ..deps import CurrentUser, DBSession
from ..models import AgentPlanProposal, ChatMessage, ChatSession
from ..schemas import AgentChatIn
from ..services.agent import apply_proposal, run_agent
from ..services.serializers import serialize_program

router = APIRouter(prefix="/agent", tags=["agent"])


@router.post("/chat")
async def agent_chat(
    payload: AgentChatIn,
    user_id: CurrentUser,
    db: DBSession,
):
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
    result = await run_agent(
        db,
        user_id,
        payload.message,
        session_id=session.id,
        history=history,
    )

    session.messages.append(ChatMessage(role="user", content=payload.message))
    session.messages.append(ChatMessage(role="assistant", content=result["reply"]))
    db.commit()

    return {
        "session_id": session.id,
        "run_id": result["run_id"],
        "status": result["status"],
        "reply": result["reply"],
        "proposal": result["proposal"],
        "elapsed_ms": result["elapsed_ms"],
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


@router.post("/proposals/{proposal_id}/apply")
def apply_agent_proposal(
    proposal_id: str,
    user_id: CurrentUser,
    db: DBSession,
):
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
