from datetime import date

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import MealPlan, User
from app.routers.diet import saved_plan


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
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_saved_plan_round_trips_after_reopen(db):
    day = date(2026, 11, 13)
    plan = {
        "date": day.isoformat(),
        "meals": [
            {"meal": "breakfast", "name": "早餐", "kcal": 500, "items": ["燕麦"]},
            {"meal": "lunch", "name": "午餐", "kcal": 700, "items": ["鸡胸饭"]},
        ],
        "targets": {"target_kcal": 1800},
        "generated_by": "ai",
    }
    db.add(
        MealPlan(
            user_id="user-1",
            plan_date=day,
            strategy="balanced",
            generated_by="ai",
            plan=plan,
        )
    )
    db.commit()

    result = saved_plan("user-1", db, day)

    assert result["date"] == day.isoformat()
    assert result["meals"][1]["name"] == "午餐"
    assert result["targets"]["target_kcal"] == 1800
    assert result["strategy"] == "balanced"
    assert result["generated_by"] == "ai"


def test_saved_plan_returns_404_without_a_day_plan(db):
    with pytest.raises(HTTPException) as exc:
        saved_plan("user-1", db, date(2026, 11, 13))

    assert exc.value.status_code == 404
