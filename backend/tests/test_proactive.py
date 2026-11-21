"""Tests for scheduled proactive inbox nudges."""

from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    CoachInbox,
    Exercise,
    Profile,
    Program,
    ProgramDay,
    SetLog,
    User,
    UserPreference,
    WorkoutSession,
)
from app.services.coach_control.proactive import run

TZ = ZoneInfo("Asia/Shanghai")


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


def _add_program(db, *, weekday: int) -> Program:
    monday = date(2026, 11, 16)
    program = Program(
        user_id="user-1",
        title="测试计划",
        goal_type="build_muscle",
        version=1,
        status="active",
        start_date=monday,
        weeks=4,
    )
    db.add(program)
    db.flush()
    db.add(
        ProgramDay(
            program_id=program.id,
            week_index=1,
            weekday=weekday,
            title="腿日",
        )
    )
    db.commit()
    return program


def _add_high_load(db, now: datetime) -> None:
    db.add(
        Exercise(
            slug="squat",
            name_zh="深蹲",
            muscle_group="legs",
            equipment="barbell",
        )
    )
    for index, days_ago in enumerate((1, 2, 4, 6, 10, 15, 20, 26)):
        session = WorkoutSession(
            user_id="user-1",
            started_at=now - timedelta(days=days_ago),
            duration_min=60,
        )
        db.add(session)
        db.flush()
        db.add(
            SetLog(
                session_id=session.id,
                exercise_slug="squat",
                set_index=1,
                weight_kg=80,
                reps=10,
                rpe=9 if index < 4 else 6,
                completed=True,
            )
        )
    db.commit()


def test_proactive_creates_recovery_nudge_for_high_load(db):
    now = datetime(2026, 11, 21, 9, tzinfo=TZ)
    _add_high_load(db, now)

    first = run(db, now=now)
    second = run(db, now=now)

    assert first["created"] == 1
    assert second["created"] == 0
    item = db.execute(select(CoachInbox)).scalar_one()
    assert item.kind == "recovery"
    assert item.payload["prompt"] == "我恢复得怎么样？"


def test_proactive_creates_missed_training_nudge(db):
    now = datetime(2026, 11, 21, 9, tzinfo=TZ)
    # Friday 2026-11-20; a completed session that day would suppress the nudge.
    _add_program(db, weekday=5)

    result = run(db, now=now)

    assert result["created"] == 1
    item = db.execute(select(CoachInbox)).scalar_one()
    assert item.kind == "training"
    assert "11-20" in item.payload["date"] or item.body.startswith("11/20")


def test_proactive_deduplicates_missed_training(db):
    now = datetime(2026, 11, 21, 9, tzinfo=TZ)
    _add_program(db, weekday=5)

    first = run(db, now=now)
    second = run(db, now=now)

    assert first["created"] == 1
    assert second["created"] == 0


def test_proactive_respects_user_opt_out(db):
    now = datetime(2026, 11, 21, 9, tzinfo=TZ)
    _add_program(db, weekday=5)
    db.add(UserPreference(user_id="user-1", proactive_enabled=False))
    db.commit()

    result = run(db, now=now)

    assert result["created"] == 0
    assert db.execute(select(CoachInbox)).scalars().all() == []


def test_proactive_pages_through_users(db):
    now = datetime(2026, 11, 21, 9, tzinfo=TZ)

    first = run(db, now=now, limit=1, offset=0)
    second = run(db, now=now, limit=1, offset=1)

    assert first["scanned"] == 1
    assert first["next_offset"] == 1
    assert second["scanned"] == 0
    assert second["next_offset"] is None


def test_proactive_endpoint_rejects_missing_or_wrong_token(db, monkeypatch):
    from fastapi import HTTPException

    from app.routers import coach_control as coach_router

    monkeypatch.setattr(coach_router.settings, "proactive_cron_token", "")
    with pytest.raises(HTTPException) as missing:
        coach_router.run_proactive(db, None)
    assert missing.value.status_code == 503

    monkeypatch.setattr(coach_router.settings, "proactive_cron_token", "secret")
    with pytest.raises(HTTPException) as wrong:
        coach_router.run_proactive(db, "wrong")
    assert wrong.value.status_code == 401
