import asyncio
from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import User, UserEntitlement
from app.routers import agent
from app.schemas import AgentChatIn
from app.services import access


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    db = Session(engine)
    db.add(
        User(
            id="00000000-0000-0000-0000-000000000001",
            phone="13800138000",
            status="active",
        )
    )
    db.commit()
    return db


def _grant_pro(db: Session, days: int = 30) -> None:
    now = datetime.now(timezone.utc)
    db.add(
        UserEntitlement(
            user_id="00000000-0000-0000-0000-000000000001",
            plan_code="pro",
            source="admin",
            source_ref="test-grant",
            starts_at=now,
            expires_at=now + timedelta(days=days),
            reason="test",
        )
    )
    db.commit()


def test_pro_snapshot_unlocks_all_features():
    db = _session()
    _grant_pro(db)

    snapshot = access.access_snapshot(db, "00000000-0000-0000-0000-000000000001")

    assert snapshot["is_pro"] is True
    assert snapshot["pro_expires_at"]
    assert snapshot["features"][access.FEATURE_TRAINING_PLAN]["can_generate"] is True
    assert snapshot["features"][access.FEATURE_MEAL_PLAN]["can_generate"] is True
    assert snapshot["features"][access.FEATURE_COACH_AI]["remaining"] is None
    equipment = snapshot["features"][access.FEATURE_EQUIPMENT_SCAN]
    assert equipment["can_scan"] is True
    assert equipment["requires_pro"] is False


def test_scheduled_extension_extends_displayed_expiry():
    db = _session()
    user_id = "00000000-0000-0000-0000-000000000001"
    now = datetime.now(timezone.utc)
    db.add_all(
        [
            UserEntitlement(
                user_id=user_id,
                plan_code="pro",
                source="admin",
                source_ref="current",
                starts_at=now - timedelta(days=1),
                expires_at=now + timedelta(days=30),
            ),
            UserEntitlement(
                user_id=user_id,
                plan_code="pro",
                source="admin",
                source_ref="extension",
                starts_at=now + timedelta(days=30),
                expires_at=now + timedelta(days=60),
            ),
        ]
    )
    db.commit()

    entitlement = access.active_entitlement(db, user_id)

    assert entitlement.active is True
    assert entitlement.expires_at is not None
    assert entitlement.expires_at > now + timedelta(days=59)


def test_meal_trial_is_one_per_account():
    db = _session()
    user_id = "00000000-0000-0000-0000-000000000001"

    assert access.require_meal_plan_generation(db, user_id) == "trial"
    assert access.consume_trial(
        db, user_id, access.FEATURE_MEAL_PLAN, source="first_generation"
    )
    assert not access.consume_trial(
        db, user_id, access.FEATURE_MEAL_PLAN, source="first_generation"
    )
    with pytest.raises(HTTPException) as exc:
        access.require_meal_plan_generation(db, user_id)
    assert exc.value.status_code == 403
    assert exc.value.detail["code"] == "PRO_REQUIRED"


def test_onboarding_training_trial_is_one_per_account():
    db = _session()
    user_id = "00000000-0000-0000-0000-000000000001"

    assert (
        access.require_training_plan_generation(db, user_id, onboarding=True)
        == "onboarding"
    )
    assert access.consume_trial(
        db, user_id, access.FEATURE_TRAINING_PLAN, source="onboarding"
    )
    with pytest.raises(HTTPException):
        access.require_training_plan_generation(db, user_id, onboarding=True)
    with pytest.raises(HTTPException):
        access.require_training_plan_generation(db, user_id)


def test_pro_feature_gate_rejects_free_user():
    db = _session()
    user_id = "00000000-0000-0000-0000-000000000001"

    with pytest.raises(HTTPException) as exc:
        access.require_feature(db, user_id, access.FEATURE_FOOD_PHOTO)
    assert exc.value.status_code == 403
    assert exc.value.detail["code"] == "PRO_REQUIRED"
    assert exc.value.detail["feature"] == access.FEATURE_FOOD_PHOTO

    _grant_pro(db)
    access.require_feature(db, user_id, access.FEATURE_FOOD_PHOTO)


def test_coach_weekly_quota_is_three_for_free_users():
    db = _session()
    user_id = "00000000-0000-0000-0000-000000000001"

    assert access.reserve_coach_message(db, user_id)
    assert access.reserve_coach_message(db, user_id)
    assert access.reserve_coach_message(db, user_id)
    assert not access.reserve_coach_message(db, user_id)

    snapshot = access.access_snapshot(db, user_id)
    coach = snapshot["features"][access.FEATURE_COACH_AI]
    assert coach["used"] == 3
    assert coach["remaining"] == 0
    assert coach["can_send"] is False


def test_agent_chat_rejects_free_user_after_three_messages():
    db = _session()
    user_id = "00000000-0000-0000-0000-000000000001"
    for _ in range(access.COACH_WEEKLY_LIMIT):
        assert access.reserve_coach_message(db, user_id)

    with pytest.raises(HTTPException) as exc:
        asyncio.run(
            agent._agent_chat_inner(
                AgentChatIn(message="今天练什么"),
                user_id,
                db,
            )
        )

    assert exc.value.status_code == 429
    assert exc.value.detail["code"] == "COACH_QUOTA_EXHAUSTED"
