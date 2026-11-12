import asyncio

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import AgentRun, ChatMessage, Profile, User
from app.routers import agent as agent_router
from app.schemas import AgentChatIn
from app.services import access


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    session = Session()
    session.add(User(id="user-1"))
    session.add(
        Profile(
            user_id="user-1",
            nickname="幂等测试",
            sex="male",
            equipment=["bodyweight"],
            weekly_days=3,
            session_minutes=45,
        )
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_repeated_request_returns_saved_response_without_rerunning(db, monkeypatch):
    calls: list[str] = []

    async def fake_run_agent(db, user_id, message, **kwargs):
        calls.append(message)
        return {
            "run_id": "run-1",
            "status": "completed",
            "reply": "今天练腿。",
            "proposal": None,
            "actions": [],
            "safety_flag": None,
            "citations": [],
            "elapsed_ms": 1,
            "usage": {},
            "error": None,
        }

    monkeypatch.setattr(agent_router, "run_agent", fake_run_agent)

    payload = AgentChatIn(message="今天练什么？", request_id="request-1")
    first = asyncio.run(agent_router._agent_chat_inner(payload, "user-1", db))
    second = asyncio.run(agent_router._agent_chat_inner(payload, "user-1", db))

    assert calls == ["今天练什么？"]
    assert second == first
    assert second["reply"] == "今天练腿。"


def test_failed_turn_is_not_persisted_for_retry(db, monkeypatch):
    db.add(
        AgentRun(
            id="run-failed",
            user_id="user-1",
            intent="coach_chat",
            status="failed",
            input_text="今天练什么？",
        )
    )
    db.commit()

    async def failed_run_agent(db, user_id, message, **kwargs):
        return {
            "run_id": "run-failed",
            "status": "failed",
            "reply": "这次没有完成。",
            "proposal": None,
            "actions": [],
            "safety_flag": None,
            "citations": [],
            "elapsed_ms": 1,
            "usage": {},
            "error": "model down",
        }

    monkeypatch.setattr(agent_router, "run_agent", failed_run_agent)

    payload = AgentChatIn(message="今天练什么？", request_id="request-failed")
    result = asyncio.run(
        agent_router._agent_chat_inner(payload, "user-1", db)
    )

    assert result["status"] == "failed"
    assert result["message_id"] is None
    assert db.query(ChatMessage).count() == 0
    used, _, _ = access.coach_usage(db, "user-1")
    assert used == 0


def test_in_progress_request_returns_structured_409(db):
    payload = AgentChatIn(message="今天练什么？", request_id="request-2")
    agent_router.claim_agent_request(db, "user-1", payload.request_id)

    with pytest.raises(HTTPException) as exc:
        asyncio.run(agent_router._agent_chat_inner(payload, "user-1", db))

    assert exc.value.status_code == 409
    assert exc.value.detail["code"] == "AGENT_REQUEST_IN_PROGRESS"
    assert exc.value.detail["retry_after"] >= 1
