from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import User, UserEntitlement
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
