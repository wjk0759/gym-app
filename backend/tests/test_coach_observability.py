from datetime import timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    AgentRun,
    AIJob,
    ChatMessage,
    ChatSession,
    CoachActionRecord,
    CoachFeedback,
    CoachPending,
    CoachSession,
    CoachTurn,
    DomainEvent,
    User,
    utcnow,
)
from app.services.coach_observability import build_report, format_report


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
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture()
def seeded(db):
    now = utcnow()
    db.add(User(id="user-1"))
    db.add(ChatSession(id="session-1", user_id="user-1"))
    db.add_all(
        [
            ChatMessage(
                id="message-1",
                session_id="session-1",
                role="assistant",
                content="今天练腿。",
            ),
            ChatMessage(
                id="message-2",
                session_id="session-1",
                role="assistant",
                content="明天休息。",
            ),
            ChatMessage(
                id="message-3",
                session_id="session-1",
                role="assistant",
                content="先热身。",
            ),
        ]
    )
    db.add_all(
        [
            AIJob(
                kind="agent",
                status="ok",
                model="deepseek-chat",
                prompt_version="agent@abc12345",
                input_tokens=100,
                output_tokens=50,
                latency_ms=1000,
                created_at=now - timedelta(hours=1),
            ),
            AIJob(
                kind="agent",
                status="fallback",
                model="deepseek-chat",
                prompt_version="agent@abc12345",
                input_tokens=40,
                output_tokens=0,
                latency_ms=3000,
                created_at=now - timedelta(hours=2),
            ),
            AIJob(
                kind="plan",
                status="ok",
                model="deepseek-chat",
                prompt_version="plan@def67890",
                input_tokens=500,
                output_tokens=300,
                latency_ms=2000,
                created_at=now - timedelta(days=2),
            ),
            AIJob(
                kind="agent",
                status="ok",
                prompt_version="agent@old",
                input_tokens=999,
                latency_ms=9999,
                created_at=now - timedelta(days=30),
            ),
        ]
    )
    db.add_all(
        [
            AgentRun(
                user_id="user-1",
                intent="coach_chat",
                status="completed",
                model="deepseek-chat",
                prompt_version="agent@abc12345",
                input_text="今天练什么",
                step_count=2,
                created_at=now - timedelta(minutes=2),
                completed_at=now - timedelta(minutes=1),
            ),
            AgentRun(
                user_id="user-1",
                intent="coach_chat",
                status="failed",
                model="deepseek-chat",
                prompt_version="agent@abc12345",
                input_text="换个动作",
                step_count=1,
                created_at=now - timedelta(minutes=3),
            ),
        ]
    )
    db.add_all(
        [
            CoachFeedback(
                user_id="user-1",
                message_id="message-1",
                rating="up",
                prompt_version="agent@abc12345",
            ),
            CoachFeedback(
                user_id="user-1",
                message_id="message-2",
                rating="down",
                reason="inaccurate",
                prompt_version="agent@abc12345",
            ),
            CoachFeedback(
                user_id="user-1",
                message_id="message-3",
                rating="down",
                reason="unsafe",
                prompt_version="plan@def67890",
            ),
        ]
    )
    db.add(CoachSession(id="coach-1", user_id="user-1"))
    db.add_all(
        [
            CoachTurn(
                session_id="coach-1",
                user_id="user-1",
                input_text="复盘本周",
                intent="review.weekly",
                status="completed",
                created_at=now - timedelta(minutes=5),
            ),
            CoachTurn(
                session_id="coach-1",
                user_id="user-1",
                input_text="你好",
                intent="coach.answer",
                status="completed",
                created_at=now - timedelta(minutes=4),
            ),
        ]
    )
    db.add(
        CoachActionRecord(
            user_id="user-1",
            session_id="coach-1",
            capability_id="body.log_weight",
            status="executed",
            idempotency_key="action-1",
            created_at=now - timedelta(minutes=3),
        )
    )
    db.add(
        CoachPending(
            session_id="coach-1",
            user_id="user-1",
            kind="card",
            capability_id="body.log_weight",
            payload={},
            status="consumed",
            expires_at=now + timedelta(minutes=10),
            created_at=now - timedelta(minutes=3),
        )
    )
    db.add_all(
        [
            DomainEvent(
                user_id="user-1",
                type="ClientEvent",
                payload={"name": "app_open"},
                occurred_at=now - timedelta(minutes=2),
            ),
            DomainEvent(
                user_id="user-1",
                type="ClientEvent",
                payload={"name": "coach_turn_completed"},
                occurred_at=now - timedelta(minutes=2),
            ),
            DomainEvent(
                user_id="user-1",
                type="SafetyBlocked",
                payload={"flag": "injury_guard"},
                occurred_at=now - timedelta(minutes=1),
            ),
        ]
    )
    db.commit()
    return now


def test_report_aggregates_jobs_runs_and_feedback(db, seeded):
    report = build_report(db, days=7, now=seeded)

    assert report["window"]["days"] == 7
    jobs = report["jobs"]
    assert jobs["total"] == 3
    assert jobs["input_tokens"] == 640
    assert jobs["output_tokens"] == 350
    by_kind = {item["kind"]: item for item in jobs["kinds"]}
    assert by_kind["agent"]["total"] == 2
    assert by_kind["agent"]["fallback"] == 1
    assert by_kind["agent"]["non_ok_rate"] == 0.5
    assert by_kind["agent"]["avg_latency_ms"] == 2000
    assert by_kind["plan"]["input_tokens"] == 500

    runs = report["runs"]
    assert runs["total"] == 2
    assert runs["completed"] == 1
    assert runs["failed"] == 1
    assert runs["completion_rate"] == 0.5
    assert runs["avg_steps"] == 1.5
    assert runs["avg_ms"] == 60000

    feedback = report["feedback"]
    assert feedback["total"] == 3
    assert feedback["up"] == 1
    assert feedback["down"] == 2
    assert feedback["satisfaction"] == 0.333
    assert feedback["reasons"] == {"inaccurate": 1, "unsafe": 1}
    assert feedback["unsafe_reports"] == 1
    by_prompt = {
        item["prompt_version"]: item for item in feedback["prompts"]
    }
    assert by_prompt["agent@abc12345"]["satisfaction"] == 0.5
    assert by_prompt["plan@def67890"]["satisfaction"] == 0.0


def test_report_ignores_rows_outside_the_window(db, seeded):
    report = build_report(db, days=1, now=seeded)

    by_kind = {item["kind"]: item for item in report["jobs"]["kinds"]}
    assert "plan" not in by_kind
    assert by_kind["agent"]["total"] == 2
    # The 30-day-old agent job must not leak into the token totals.
    assert report["jobs"]["input_tokens"] == 140


def test_report_includes_control_plane_and_client_funnel(db, seeded):
    report = build_report(db, days=7, now=seeded)
    control = report["control"]

    assert control["turns"]["total"] == 2
    assert control["turns"]["intents"]["review.weekly"] == 1
    assert control["turns"]["statuses"]["completed"] == 2
    assert control["actions"]["statuses"]["executed"] == 1
    assert control["pending"]["statuses"]["consumed"] == 1
    assert control["client_events"] == {
        "app_open": 1,
        "coach_turn_completed": 1,
    }
    assert control["safety_blocks"] == {"injury_guard": 1}

    text = format_report(report)
    assert "Control plane" in text
    assert "Client funnel" in text
    assert "app_open" in text
    assert "injury_guard=1" in text


def test_report_text_mentions_prompts_and_unsafe(db, seeded):
    text = format_report(build_report(db, days=7, now=seeded))

    assert "Coach observability" in text
    assert "agent@abc12345" in text
    assert "inaccurate=1" in text
    assert "unsafe report" in text
