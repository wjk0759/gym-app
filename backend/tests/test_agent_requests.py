from datetime import timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import AgentRequestState, User, utcnow
from app.services.agent_requests import (
    AgentRequestInProgress,
    claim_agent_request,
    complete_agent_request,
    fail_agent_request,
    get_agent_request,
)


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
    session.add(User(id="user-2"))
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_claim_blocks_concurrent_duplicate(db):
    first = claim_agent_request(db, "user-1", "request-1")

    assert first.is_replay is False
    assert first.attempts == 1
    state = get_agent_request(db, "user-1", "request-1")
    assert state["status"] == "running"
    assert state["retry_after"] >= 1
    with pytest.raises(AgentRequestInProgress):
        claim_agent_request(db, "user-1", "request-1")


def test_completed_request_replays_saved_response(db):
    claim_agent_request(db, "user-1", "request-1")
    response = {"reply": "今天练腿", "run_id": "run-1"}
    complete_agent_request(
        db,
        "user-1",
        "request-1",
        run_id="run-1",
        response=response,
    )

    replay = claim_agent_request(db, "user-1", "request-1")

    assert replay.is_replay is True
    assert replay.replay == response
    state = get_agent_request(db, "user-1", "request-1")
    assert state["status"] == "completed"
    assert state["run_id"] == "run-1"
    assert state["response"] == response


def test_failed_request_can_be_retried(db):
    claim_agent_request(db, "user-1", "request-1")
    fail_agent_request(db, "user-1", "request-1", error="model timeout")

    state = get_agent_request(db, "user-1", "request-1")
    assert state["status"] == "failed"
    assert state["error"] == "model timeout"

    retry = claim_agent_request(db, "user-1", "request-1")
    assert retry.is_replay is False
    assert retry.attempts == 2


def test_stale_running_request_can_take_over(db):
    claim_agent_request(db, "user-1", "request-1")
    row = db.get(AgentRequestState, ("user-1", "request-1"))
    row.updated_at = utcnow() - timedelta(minutes=10)
    db.commit()

    retry = claim_agent_request(db, "user-1", "request-1")

    assert retry.is_replay is False
    assert retry.attempts == 2


def test_request_state_is_scoped_to_user(db):
    claim_agent_request(db, "user-1", "request-1")
    complete_agent_request(
        db,
        "user-1",
        "request-1",
        run_id=None,
        response={"reply": "用户一的回复"},
    )

    assert get_agent_request(db, "user-2", "request-1") is None
    first = claim_agent_request(db, "user-2", "request-1")
    assert first.is_replay is False
    with pytest.raises(AgentRequestInProgress):
        claim_agent_request(db, "user-2", "request-1")


def test_expired_request_state_is_recreated(db):
    claim_agent_request(db, "user-1", "request-1")
    row = db.get(AgentRequestState, ("user-1", "request-1"))
    row.expires_at = utcnow() - timedelta(seconds=1)
    db.commit()

    assert get_agent_request(db, "user-1", "request-1") is None
    fresh = claim_agent_request(db, "user-1", "request-1")

    assert fresh.is_replay is False
    assert fresh.attempts == 1


def test_missing_request_id_is_a_noop(db):
    claim = claim_agent_request(db, "user-1", None)
    assert claim.request_id is None
    assert claim.is_replay is False
    assert get_agent_request(db, "user-1", "missing") is None
