"""Tests for deterministic recovery/readiness facts and routing."""

import asyncio
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import CoachInbox, Exercise, Profile, SetLog, User, WorkoutSession
from app.services.coach_control import runtime
from app.services.coach_control.consumers import consume_event
from app.services.coach_control.events import emit_event
from app.services.coach_control.insights import build_readonly_context
from app.services.coach_control.readiness import snapshot


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session = sessionmaker(
        bind=engine,
        autoflush=False,
        expire_on_commit=False,
    )()
    session.add(User(id="user-1"))
    session.add(Profile(user_id="user-1", nickname="小林"))
    session.add(
        Exercise(
            slug="squat",
            name_zh="深蹲",
            muscle_group="legs",
            equipment="barbell",
        )
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _add_session(
    db,
    session_id: str,
    days_ago: int,
    *,
    duration: int = 60,
    rpe: float = 7,
) -> None:
    started = datetime.now(timezone.utc) - timedelta(days=days_ago)
    db.add(
        WorkoutSession(
            id=session_id,
            user_id="user-1",
            started_at=started,
            duration_min=duration,
        )
    )
    db.add(
        SetLog(
            session_id=session_id,
            exercise_slug="squat",
            set_index=1,
            weight_kg=50,
            reps=10,
            rpe=rpe,
            completed=True,
        )
    )


def test_readiness_flags_high_acute_load(db):
    for index, days_ago in enumerate((1, 2, 4, 6)):
        _add_session(db, f"recent-{index}", days_ago, rpe=9)
    for index, days_ago in enumerate((10, 15, 20, 26)):
        _add_session(db, f"old-{index}", days_ago, rpe=6)
    db.commit()

    payload = snapshot(db, "user-1")

    assert payload["status"] == "high_risk"
    assert payload["acwr"] is not None and payload["acwr"] >= 1.5
    assert payload["sessions_7d"] == 4
    assert payload["average_rpe_7d"] == 9
    assert "减载" in " ".join(payload["actions"])


def test_readiness_without_data_is_honest(db):
    payload = snapshot(db, "user-1")

    assert payload["status"] == "no_data"
    assert payload["sessions_28d"] == 0
    assert payload["acwr"] is None
    assert "没有训练记录" in payload["summary"]


def test_recovery_question_gets_readiness_facts(db):
    _add_session(db, "session-1", 1, rpe=9)
    _add_session(db, "session-2", 3, rpe=8)
    db.commit()

    context = build_readonly_context(
        db,
        "user-1",
        "我最近恢复得怎么样",
        None,
    )

    assert context is not None
    assert "恢复状态" in context
    assert "近 7 天 2 次" in context
    assert "训练负荷" in context


def test_recovery_question_stays_read_only(db):
    result = asyncio.run(
        runtime.handle_turn(db, "user-1", "我最近太累了，训练怎么办")
    )

    assert result["intent"] == "coach.answer"
    assert result["pending"] is None


def test_body_status_question_is_readiness_not_body_trend(db):
    assert runtime._looks_like_body_review("身体状态怎么样") is False
    result = asyncio.run(
        runtime.handle_turn(db, "user-1", "身体状态怎么样")
    )

    assert result["intent"] == "coach.answer"
    assert result["pending"] is None


def test_high_load_creates_one_recovery_nudge(db):
    for index, days_ago in enumerate((1, 2, 4, 6)):
        _add_session(db, f"recent-{index}", days_ago, rpe=9)
    for index, days_ago in enumerate((10, 15, 20, 26)):
        _add_session(db, f"old-{index}", days_ago, rpe=6)
    db.commit()

    first = emit_event(db, "user-1", "WorkoutLogged")
    consume_event(db, first)
    second = emit_event(db, "user-1", "WorkoutLogged")
    consume_event(db, second)
    db.commit()

    items = (
        db.execute(select(CoachInbox).where(CoachInbox.kind == "recovery"))
        .scalars()
        .all()
    )
    assert len(items) == 1
    assert "恢复" in items[0].title
    assert items[0].payload["prompt"] == "我恢复得怎么样？"
