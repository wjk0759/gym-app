from __future__ import annotations

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import User
from app.schemas import (
    CustomFoodSyncIn,
    CycleSyncIn,
    ExerciseDislikeSyncIn,
    FavoriteFoodSyncIn,
    FoodDislikeSyncIn,
    PreferencesIn,
    SyncIn,
)
from app.services.user_sync import apply_sync, sync_snapshot


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
    session.add(User(id="user-1", phone="13428104171", status="active"))
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_sync_snapshot_creates_default_preferences(db):
    snapshot = sync_snapshot(db, "user-1")
    db.commit()

    assert snapshot["preferences"]["use_remote_ai"] is True
    assert snapshot["preferences"]["reminder_hour"] == 19
    assert snapshot["custom_foods"] == []
    assert snapshot["favorites"] == []
    assert snapshot["disliked_exercises"] == []
    assert snapshot["disliked_foods"] == []


def test_sync_upserts_and_deletes_reusable_data(db):
    result = apply_sync(
        db,
        "user-1",
        SyncIn(
            preferences=PreferencesIn(
                strict_equipment_mode=True,
                use_remote_ai=False,
                reminder_hour=7,
                reminder_minute=30,
                body_checkin_frequency="weekly",
                body_checkin_weekday=2,
            ),
            custom_foods=[
                CustomFoodSyncIn(
                    client_id="food-1",
                    name="自制鸡肉饭",
                    category="自定义",
                    kcal=520,
                    protein=40,
                    carbs=60,
                    fat=12,
                    fiber=4,
                    default_grams=350,
                )
            ],
            favorites=[
                FavoriteFoodSyncIn(
                    food_key="custom:food-1",
                    name="自制鸡肉饭",
                )
            ],
            disliked_exercises=[ExerciseDislikeSyncIn(slug="burpee")],
            disliked_foods=[
                FoodDislikeSyncIn(
                    food_key="library:鸡胸肉",
                    name="鸡胸肉",
                )
            ],
        ),
    )

    assert result["preferences"]["strict_equipment_mode"] is True
    assert result["preferences"]["use_remote_ai"] is False
    assert result["preferences"]["reminder_hour"] == 7
    assert result["custom_foods"][0]["name"] == "自制鸡肉饭"
    assert result["favorites"][0]["food_key"] == "custom:food-1"
    assert result["disliked_exercises"][0]["slug"] == "burpee"
    assert result["disliked_foods"][0]["food_key"] == "library:鸡胸肉"

    deleted = apply_sync(
        db,
        "user-1",
        SyncIn(
            custom_foods=[
                CustomFoodSyncIn(
                    client_id="food-1",
                    name="自制鸡肉饭",
                    deleted=True,
                )
            ],
            favorites=[
                FavoriteFoodSyncIn(
                    food_key="custom:food-1",
                    name="自制鸡肉饭",
                    deleted=True,
                )
            ],
            disliked_exercises=[
                ExerciseDislikeSyncIn(slug="burpee", deleted=True)
            ],
            disliked_foods=[
                FoodDislikeSyncIn(
                    food_key="library:鸡胸肉",
                    name="鸡胸肉",
                    deleted=True,
                )
            ],
        ),
    )

    assert deleted["custom_foods"] == []
    assert deleted["favorites"] == []
    assert deleted["disliked_exercises"] == []
    assert deleted["disliked_foods"] == []


def test_sync_cycle_dates(db):
    result = apply_sync(
        db,
        "user-1",
        SyncIn(
            cycle=CycleSyncIn(
                range_start="2026-11-16",
                range_end="2026-11-20",
                dates=["2026-11-16", "2026-11-17", "2026-11-18"],
                training_mode="light",
            )
        ),
    )
    assert result["cycle"]["range_start"] == "2026-11-16"
    assert result["cycle"]["dates"] == ["2026-11-16", "2026-11-17", "2026-11-18"]
    assert result["cycle"]["training_mode"] == "light"


def test_sync_replaces_custom_food_by_client_id(db):
    apply_sync(
        db,
        "user-1",
        SyncIn(
            custom_foods=[
                CustomFoodSyncIn(
                    client_id="food-1",
                    name="旧名字",
                    kcal=100,
                )
            ]
        ),
    )
    updated = apply_sync(
        db,
        "user-1",
        SyncIn(
            custom_foods=[
                CustomFoodSyncIn(
                    client_id="food-1",
                    name="新名字",
                    kcal=200,
                )
            ]
        ),
    )

    assert len(updated["custom_foods"]) == 1
    assert updated["custom_foods"][0]["name"] == "新名字"
    assert updated["custom_foods"][0]["kcal"] == 200
