import asyncio
from datetime import date

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import Profile, User
from app.routers import plans
from app.schemas import PlanGenerateIn

USER_ID = "00000000-0000-0000-0000-000000000001"


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    db = Session(engine)
    db.add(User(id=USER_ID, phone="13800138000", status="active"))
    db.add(
        Profile(
            user_id=USER_ID,
            nickname="测试",
            sex="male",
            birth_date=date(1996, 1, 1),
            height_cm=178,
            weight_kg=72,
            weekly_days=3,
            session_minutes=45,
        )
    )
    db.commit()
    return db


def test_plan_generate_uses_30s_cooldown_and_daily_limit(monkeypatch):
    db = _session()
    calls: dict = {}
    original = plans.generation.begin_generation

    def wrapped(*args, **kwargs):
        calls.update(kwargs)
        return original(*args, **kwargs)

    monkeypatch.setattr(plans.generation, "begin_generation", wrapped)
    monkeypatch.setattr(
        plans.access,
        "require_training_plan_generation",
        lambda *args, **kwargs: "pro",
    )
    monkeypatch.setattr(
        plans.access,
        "reserve_plan_generation",
        lambda *args, **kwargs: False,
    )

    with pytest.raises(HTTPException) as exc:
        asyncio.run(
            plans.generate(
                PlanGenerateIn(force=True),
                USER_ID,
                db,
                idempotency_key=None,
            )
        )

    assert calls["cooldown_seconds"] == 30
    assert exc.value.status_code == 429
    assert exc.value.detail["code"] == "PLAN_DAILY_LIMIT"
    assert exc.value.detail["retry_after"] > 0
