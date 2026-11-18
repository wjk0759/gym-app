from __future__ import annotations

import asyncio
from datetime import date

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import Profile, User
from app.services.agent import _multi_intent_action_turn

USER_ID = "00000000-0000-0000-0000-000000000001"


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session = Session(engine)
    session.add(User(id=USER_ID, phone="13800138000", status="active"))
    session.add(
        Profile(
            user_id=USER_ID,
            nickname="测试",
            sex="male",
            birth_date=date(1996, 1, 1),
            height_cm=178,
            weight_kg=72,
            equipment=["bodyweight", "dumbbell"],
        )
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_food_and_body_metric_become_two_cards(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "午餐吃了200g米饭，再记体重72kg",
            {},
        )
    )

    assert result is not None
    assert [action["type"] for action in result["actions"]] == [
        "log_food",
        "log_body_metric",
    ]
    assert result["actions"][1]["payload"]["weight_kg"] == 72


def test_food_correction_without_pending_card_asks_instead_of_new_log(db):
    result = asyncio.run(
        _multi_intent_action_turn(
            db,
            USER_ID,
            "把午餐米饭改成200g，再记体重72kg",
            {},
        )
    )

    assert result is not None
    assert result["actions"] == []
    assert "修改" in result["reply"]
    assert "新记" in result["reply"]
