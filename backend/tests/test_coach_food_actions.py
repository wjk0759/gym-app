from datetime import date

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import Exercise, FoodLog, Profile, SetLog, User, WorkoutSession
from app.routers.agent import run_agent_action
from app.schemas import AgentActionRunIn
from app.services.coach_actions.executor import execute_action, undo_action
from app.services.coach_actions.schemas import LogFoodPayload
from app.services.food_text import resolve_food_rules
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
            birth_date=date(1996, 1, 1),
            height_cm=178,
            weight_kg=72,
            weekly_days=3,
        )
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_food_rules_parse_noodles_and_milk_tea():
    result = resolve_food_rules("湿炒螺蛳粉一份，半杯奶茶")

    assert [item["name"] for item in result.items] == ["湿炒螺蛳粉", "奶茶"]
    assert result.items[0]["grams"] == 500
    assert result.items[1]["grams"] == 250
    assert result.items[0]["kcal"] > 0
    assert result.items[1]["kcal"] > 0
    assert result.questions == []


def test_log_food_action_writes_and_replays_idempotently(db):
    payload = LogFoodPayload(
        date=date(2026, 11, 13),
        meal="lunch",
        items=[
            {
                "name": "湿炒螺蛳粉",
                "grams": 500,
                "kcal": 600,
                "protein_g": 22,
                "carbs_g": 80,
                "fat_g": 18,
                "confidence": 0.72,
            }
        ],
    )

    first = execute_action(
        db,
        "user-1",
        "action-1",
        "log_food",
        payload.model_dump(mode="json"),
    )
    second = execute_action(
        db,
        "user-1",
        "action-1",
        "log_food",
        payload.model_dump(mode="json"),
    )

    assert first["created_logs"][0]["food_name"] == "湿炒螺蛳粉"
    assert first["today_nutrition"]["logged"]["kcal"] == 600
    assert second == first
    logs = db.execute(select(FoodLog)).scalars().all()
    assert len(logs) == 1
    assert logs[0].source == "coach"
    assert logs[0].source_action_id == "action-1"


def test_undo_food_action_removes_the_group(db):
    payload = LogFoodPayload(
        date=date(2026, 11, 13),
        meal="lunch",
        items=[
            {
                "name": "奶茶",
                "grams": 250,
                "kcal": 175,
                "protein_g": 2.5,
                "carbs_g": 30,
                "fat_g": 5.8,
            }
        ],
    )
    execute_action(
        db,
        "user-1",
        "action-undo",
        "log_food",
        payload.model_dump(mode="json"),
    )

    result = undo_action(db, "user-1", "action-undo")

    assert result["deleted"] == 1
    assert db.execute(select(FoodLog)).scalars().all() == []


def test_log_planned_meal_links_to_plan_and_is_idempotent(db):
    day = date(2026, 11, 13)
    save_day_plan(
        db,
        "user-1",
        day,
        {
            "date": day.isoformat(),
            "targets": {
                "target_kcal": 2100,
                "protein_g": 150,
                "carb_g": 230,
                "fat_g": 65,
            },
            "meals": [
                {
                    "meal": "lunch",
                    "name": "鸡腿饭",
                    "kcal": 700,
                    "protein_g": 50,
                    "carbs_g": 80,
                    "fat_g": 20,
                }
            ],
        },
        strategy="balanced",
        generated_by="ai",
    )
    db.commit()

    first = execute_action(
        db,
        "user-1",
        "action-plan-meal",
        "log_planned_meal",
        {"date": day.isoformat(), "meal": "lunch"},
    )
    second = execute_action(
        db,
        "user-1",
        "action-plan-meal",
        "log_planned_meal",
        {"date": day.isoformat(), "meal": "lunch"},
    )

    assert first["created_logs"][0]["plan_meal"] == "lunch"
    assert first["created_logs"][0]["kcal"] == 700
    assert second == first
    logs = db.execute(select(FoodLog)).scalars().all()
    assert len(logs) == 1
    assert logs[0].plan_date == day


def test_generic_route_wraps_food_action_result(db):
    response = run_agent_action(
        "route-action",
        AgentActionRunIn(
            type="log_food",
            payload={
                "date": "2026-11-13",
                "meal": "breakfast",
                "items": [
                    {
                        "name": "鸡蛋",
                        "grams": 100,
                        "kcal": 143,
                        "protein_g": 13,
                        "carbs_g": 1,
                        "fat_g": 10,
                    }
                ],
            },
        ),
        "user-1",
        db,
    )

    assert response["status"] == "executed"
    assert response["type"] == "log_food"
    assert response["result"]["created_logs"][0]["food_name"] == "鸡蛋"


def test_log_workout_action_writes_session_and_undoes(db):
    db.add(
        Exercise(
            slug="goblet-squat",
            name_zh="高脚杯深蹲",
            muscle_group="legs",
            equipment="dumbbell",
            is_compound=True,
            contraindications=[],
        )
    )
    db.commit()

    payload = {
        "date": "2026-11-12",
        "title": "腿部训练",
        "duration_minutes": 40,
        "kind": "strength",
        "sets": [
            {
                "slug": "goblet-squat",
                "set_index": 1,
                "weight_kg": 24,
                "reps": 10,
                "rpe": 8,
            }
        ],
    }
    first = execute_action(
        db, "user-1", "action-workout", "log_workout", payload
    )
    second = execute_action(
        db, "user-1", "action-workout", "log_workout", payload
    )

    assert first["created_workout"]["duration_min"] == 40
    assert second == first
    sessions = db.execute(select(WorkoutSession)).scalars().all()
    assert len(sessions) == 1
    assert len(db.execute(select(SetLog)).scalars().all()) == 1
    assert sessions[0].source == "coach"

    undo_action(db, "user-1", "action-workout")
    assert db.execute(select(WorkoutSession)).scalars().all() == []


def test_update_and_delete_workout_actions(db):
    db.add(
        Exercise(
            slug="goblet-squat",
            name_zh="高脚杯深蹲",
            muscle_group="legs",
            equipment="dumbbell",
            is_compound=True,
            contraindications=[],
        )
    )
    db.commit()
    created = execute_action(
        db,
        "user-1",
        "action-workout-edit",
        "log_workout",
        {
            "date": "2026-11-12",
            "title": "腿部训练",
            "duration_minutes": 40,
            "kind": "strength",
            "sets": [
                {
                    "slug": "goblet-squat",
                    "set_index": 1,
                    "weight_kg": 24,
                    "reps": 10,
                    "rpe": 8,
                }
            ],
        },
    )
    session_id = created["created_workout"]["id"]

    updated = execute_action(
        db,
        "user-1",
        "action-workout-edit-2",
        "update_workout_log",
        {
            "session_id": session_id,
            "duration_minutes": 50,
            "sets": [
                {
                    "slug": "goblet-squat",
                    "set_index": 1,
                    "weight_kg": 60,
                    "reps": 8,
                    "rpe": 9,
                }
            ],
        },
    )

    assert updated["updated_workout"]["duration_min"] == 50
    assert updated["updated_workout"]["sets"][0]["weight_kg"] == 60

    execute_action(
        db,
        "user-1",
        "action-workout-edit-3",
        "delete_workout_log",
        {"session_id": session_id},
    )
    assert db.execute(select(WorkoutSession)).scalars().all() == []
