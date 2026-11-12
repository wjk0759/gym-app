from datetime import date

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import User
from app.services.diet_swap import swap_planned_meal, undo_planned_meal
from app.services.meal_plans import get_day, save_day_plan


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
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _plan(day: date, lunch_name: str) -> dict:
    return {
        "date": day.isoformat(),
        "targets": {
            "target_kcal": 2100,
            "protein_g": 150,
            "carb_g": 230,
            "fat_g": 65,
        },
        "meals": [
            {"meal": "breakfast", "name": "早餐", "kcal": 500, "protein_g": 30},
            {
                "meal": "lunch",
                "name": lunch_name,
                "kcal": 700,
                "protein_g": 50.0,
                "carbs_g": 70.0,
                "fat_g": 22.0,
            },
            {"meal": "dinner", "name": "晚餐", "kcal": 700, "protein_g": 55},
        ],
        "generated_by": "ai",
    }


def test_swap_uses_same_meal_from_another_day_and_keeps_macros(db):
    monday = date(2026, 11, 9)
    tuesday = date(2026, 11, 10)
    save_day_plan(
        db, "user-1", monday, _plan(monday, "周一鸡腿饭"),
        strategy="balanced", generated_by="ai",
    )
    save_day_plan(
        db, "user-1", tuesday, _plan(tuesday, "周二牛肉饭"),
        strategy="balanced", generated_by="ai",
    )
    db.commit()

    result = swap_planned_meal(db, "user-1", monday, "lunch")

    swapped = next(meal for meal in result["meals"] if meal["meal"] == "lunch")
    assert swapped["name"] == "周二牛肉饭"
    assert swapped["kcal"] == 700
    assert swapped["protein_g"] == 50.0
    assert swapped["carbs_g"] == 70.0
    assert result["swapped_meal"]["from"] == "周一鸡腿饭"
    assert get_day(db, "user-1", tuesday).plan["meals"][1]["name"] == "周二牛肉饭"


def test_swap_single_day_plan_uses_a_recipe_alternative(db):
    day = date(2026, 11, 9)
    save_day_plan(
        db, "user-1", day, _plan(day, "周一鸡腿饭"),
        strategy="balanced", generated_by="ai",
    )
    db.commit()

    result = swap_planned_meal(db, "user-1", day, "lunch")

    swapped = next(meal for meal in result["meals"] if meal["meal"] == "lunch")
    assert swapped["name"] != "周一鸡腿饭"
    assert swapped["dishes"][0]["recipe"]["steps"]
    assert swapped["kcal"] == 700


def test_undo_swap_restores_the_original_meal(db):
    monday = date(2026, 11, 9)
    save_day_plan(
        db, "user-1", monday, _plan(monday, "周一鸡腿饭"),
        strategy="balanced", generated_by="ai",
    )
    db.commit()

    swapped = swap_planned_meal(db, "user-1", monday, "lunch")
    assert next(meal for meal in swapped["meals"] if meal["meal"] == "lunch")[
        "name"
    ] != "周一鸡腿饭"

    restored = undo_planned_meal(db, "user-1", monday, "lunch")
    lunch = next(meal for meal in restored["meals"] if meal["meal"] == "lunch")
    assert lunch["name"] == "周一鸡腿饭"
    assert restored["restored_meal"]["name"] == "周一鸡腿饭"


def test_swap_missing_day_or_meal_is_reported(db):
    with pytest.raises(LookupError):
        swap_planned_meal(db, "user-1", date(2026, 11, 9), "lunch")

    day = date(2026, 11, 9)
    save_day_plan(
        db, "user-1", day, _plan(day, "周一鸡腿饭"),
        strategy="balanced", generated_by="ai",
    )
    db.commit()
    with pytest.raises(LookupError):
        swap_planned_meal(db, "user-1", day, "snack")
