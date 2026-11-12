from datetime import date, datetime, timezone

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import FoodLog, Profile, User
from app.routers.diet import list_food_logs, targets, upsert_food_log
from app.schemas import FoodLogIn
from app.services.meal_plans import save_day_plan


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
    session.add(User(id="user-1", phone="13800138000", status="active"))
    session.add(
        Profile(
            user_id="user-1",
            nickname="小林",
            sex="male",
            height_cm=178,
            weight_kg=72,
            weekly_days=3,
            session_minutes=50,
        )
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_food_log_keeps_plan_link(db):
    logged_at = datetime(2026, 11, 12, 12, 30, tzinfo=timezone.utc)
    payload = FoodLogIn(
        client_id="food-log-1",
        logged_at=logged_at,
        meal="lunch",
        food_name="午餐（计划餐）",
        grams=0,
        kcal=620,
        protein=42,
        carbs=68,
        fat=18,
        fiber=8,
        plan_date=date(2026, 11, 12),
        plan_meal="lunch",
    )

    result = upsert_food_log(payload, "user-1", db)

    assert result["plan_date"] == "2026-11-12"
    assert result["plan_meal"] == "lunch"
    stored = db.execute(select(FoodLog)).scalar_one()
    assert stored.plan_date == date(2026, 11, 12)
    assert stored.plan_meal == "lunch"

    listed = list_food_logs("user-1", db, None, None, 500)
    assert listed["items"][0]["plan_meal"] == "lunch"


def test_daily_targets_follow_saved_plan_shape(db):
    day = date(2026, 11, 12)
    save_day_plan(
        db,
        "user-1",
        day,
        {
            "date": day.isoformat(),
            "targets": {
                "target_kcal": 2360,
                "protein_g": 150,
                "carb_g": 280,
                "fat_g": 62,
            },
            "meals": [],
        },
        strategy="carb_cycle",
        generated_by="ai",
    )
    db.commit()

    result = targets("user-1", db, day)

    assert result["source"] == "saved_day"
    assert result["strategy"] == "carb_cycle"
    assert result["targets"]["target_kcal"] == 2360
    assert result["targets"]["carb_g"] == 280

    fallback = targets("user-1", db, date(2026, 12, 3))
    assert fallback["source"] == "calculated"
    assert fallback["targets"]["target_kcal"] > 0
