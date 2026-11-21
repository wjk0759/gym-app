"""Tests for the in-workout co-pilot context."""

import asyncio

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import Profile, User
from app.services.coach_control import runtime
from app.services.coach_control.capabilities import coach_answer


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
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _active_context() -> dict:
    return {
        "active_workout": {
            "day_id": "day-1",
            "title": "胸日",
            "current_index": 0,
            "current_name": "杠铃卧推",
            "current_slug": "bench_press",
            "planned_sets": 4,
            "completed_sets": 2,
            "last_set": {"weight_kg": 80, "reps": 8, "rpe": 9},
            "elapsed_seconds": 900,
            "feeling": 3,
        }
    }


def test_coach_answer_injects_active_workout(db, monkeypatch):
    captured: dict = {}

    async def fake_reply(db, profile, program, history, message, **kwargs):
        captured["context"] = kwargs.get("context")
        return {"reply": "ok", "safety_flag": None}

    monkeypatch.setattr(coach_answer, "coach_reply", fake_reply)
    profile = db.get(Profile, "user-1")
    result = asyncio.run(
        coach_answer.resolve(
            db,
            profile,
            None,
            [],
            "下一组怎么练",
            app_context=_active_context(),
        )
    )

    assert result["reply"] == "ok"
    context = captured["context"]
    assert "当前训练" in context
    assert "杠铃卧推" in context
    assert "80 kg" in context
    assert "RPE 9" in context
    assert "不要建议加重量" in context


def test_next_set_question_stays_read_only(db):
    result = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "下一组怎么练",
            app_context=_active_context(),
        )
    )

    assert result["intent"] == "coach.answer"
    assert result["pending"] is None


def test_high_rpe_last_set_does_not_become_an_edit_card(db):
    result = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "这个重量还能加吗",
            app_context=_active_context(),
        )
    )

    assert result["intent"] == "coach.answer"
    assert result["pending"] is None
