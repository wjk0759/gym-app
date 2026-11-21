"""Tests for guided conversational onboarding."""

import asyncio
from datetime import date

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import Goal, Profile, User, utcnow
from app.services.coach_control.capabilities.profile import (
    execute_update,
    undo_update,
)
from app.services.coach_control.onboarding import resolve


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


def test_onboarding_parses_multiple_basic_slots(db):
    resolution = resolve(db, "user-1", "男，1995年6月，178cm，72kg")

    assert resolution["ready"] is False
    assert resolution["slots"]["sex"] == "male"
    assert resolution["slots"]["birth_date"] == "1995-06-01"
    assert resolution["slots"]["height_cm"] == 178
    assert resolution["slots"]["weight_kg"] == 72
    assert "目标" in resolution["question"]


def test_onboarding_completes_with_one_batch_card(db):
    draft = {
        "slots": {
            "sex": "male",
            "birth_date": "1995-06-01",
            "height_cm": 178,
            "weight_kg": 72,
        },
        "asked": ["goal_type"],
        "skipped": [],
    }

    resolution = resolve(
        db,
        "user-1",
        "增肌，每周3天，每次45分钟，只有哑铃",
        draft=draft,
    )

    assert resolution["ready"] is True
    batch = resolution["payload"]["batch"]
    assert [item["capability_id"] for item in batch] == [
        "profile.update",
        "body.log_weight",
        "profile.update_goal",
        "profile.update_equipment",
    ]
    profile_action = batch[0]["payload"]
    assert profile_action["mark_onboarded"] is True
    assert profile_action["weekly_days"] == 3
    assert profile_action["session_minutes"] == 45
    assert batch[3]["payload"]["equipment"] == ["bodyweight", "dumbbell"]


def test_onboarding_skip_saves_without_marking_complete(db):
    draft = {
        "slots": {
            "sex": "male",
            "height_cm": 178,
            "weight_kg": 72,
            "goal_type": "build_muscle",
            "weekly_days": 3,
            "session_minutes": 45,
            "equipment": ["bodyweight"],
        },
        "asked": ["birth_date"],
        "skipped": [],
    }

    resolution = resolve(db, "user-1", "跳过", draft=draft)

    assert resolution["ready"] is True
    payload = resolution["payload"]["batch"][0]["payload"]
    assert "mark_onboarded" not in payload
    assert "跳过的项目" in resolution["reply"]


def test_complete_profile_does_not_start_a_new_onboarding_card(db):
    db.add(Goal(user_id="user-1", type="build_muscle", status="active"))
    profile = db.get(Profile, "user-1")
    profile.sex = "female"
    profile.birth_date = date(1995, 6, 1)
    profile.height_cm = 168
    profile.weight_kg = 60
    profile.weekly_days = 3
    profile.session_minutes = 45
    profile.equipment = ["bodyweight", "dumbbell"]
    profile.onboarded_at = utcnow()
    db.commit()

    resolution = resolve(db, "user-1", "帮我完善档案")

    assert resolution["ready"] is False
    assert resolution["terminal"] is True
    assert "已经完整" in resolution["question"]


def test_profile_update_persists_birth_date_schedule_and_undo(db):
    result = execute_update(
        db,
        "user-1",
        "action-1",
        {
            "birth_date": "1995-06-01",
            "weekly_days": 4,
            "session_minutes": 60,
            "mark_onboarded": True,
        },
    )
    profile = db.get(Profile, "user-1")

    assert profile.birth_date == date(1995, 6, 1)
    assert profile.weekly_days == 4
    assert profile.session_minutes == 60
    assert profile.onboarded_at is not None
    assert result["before"]["birth_date"] is None
    assert result["after"]["birth_date"] == "1995-06-01"

    undo_update(db, "user-1", result["before"])
    assert profile.birth_date is None
    assert profile.onboarded_at is None


def test_runtime_onboarding_flows_from_draft_to_batch_card(db):
    from app.services.coach_control import runtime

    first = asyncio.run(runtime.handle_turn(db, "user-1", "帮我完善档案"))
    assert first["intent"] == "profile.onboard"
    assert first["pending"]["kind"] == "draft"

    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "男，1995年6月，178cm，72kg",
            session_id=first["session"]["id"],
        )
    )
    assert second["intent"] == "profile.onboard"
    assert second["pending"]["kind"] == "draft"
    assert "目标" in second["reply"]

    third = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "增肌，每周3天，每次45分钟，只有哑铃",
            session_id=first["session"]["id"],
        )
    )
    assert third["pending"]["capability_id"] == "coach.batch"
    assert len(third["pending"]["payload"]["batch"]) == 4
    assert "信息齐了" in third["reply"]

    result = runtime.confirm_pending(db, "user-1", third["pending"]["id"])
    assert result["status"] == "executed"

    db.expire_all()
    profile = db.get(Profile, "user-1")
    assert profile.sex == "male"
    assert profile.birth_date == date(1995, 6, 1)
    assert profile.height_cm == 178
    assert profile.weight_kg == 72
    assert profile.weekly_days == 3
    assert profile.session_minutes == 45
    assert profile.onboarded_at is not None
    assert profile.equipment == ["bodyweight", "dumbbell"]
    goal = db.query(Goal).filter(Goal.user_id == "user-1").one()
    assert goal.type == "build_muscle"
