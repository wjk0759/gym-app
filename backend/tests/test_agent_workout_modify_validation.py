from __future__ import annotations

from datetime import date

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import Exercise, Profile, User
from app.services.agent import (
    _lookup_exercise_payload,
    _modify_workout_validation_error,
)

USER_ID = "00000000-0000-0000-0000-000000000001"
DAY_ID = "day-1"


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
    session.add_all(
        [
            Exercise(
                slug="goblet-squat",
                name_zh="高脚杯深蹲",
                name_en="goblet squat",
                muscle_group="legs",
                equipment="dumbbell",
                plan_eligible=True,
            ),
            Exercise(
                slug="vital-forward-lunges",
                name_zh="前弓步",
                name_en="forward lunges",
                muscle_group="legs",
                equipment="bodyweight",
                plan_eligible=True,
            ),
            Exercise(
                slug="barbell-squat",
                name_zh="杠铃深蹲",
                name_en="barbell squat",
                muscle_group="legs",
                equipment="barbell",
                plan_eligible=True,
            ),
        ]
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _context() -> dict:
    return {
        "plan": {
            "id": "plan-1",
            "days": [
                {
                    "id": DAY_ID,
                    "title": "全身 A",
                    "exercises": [
                        {
                            "slug": "goblet-squat",
                            "sets": 3,
                            "reps": "8-10",
                        }
                    ],
                }
            ],
        },
        "today_day": {"id": DAY_ID},
    }


def _action(changes: list[dict]) -> list[dict]:
    return [
        {
            "type": "modify_workout",
            "payload": {
                "day_id": DAY_ID,
                "scope": "day",
                "changes": changes,
            },
        }
    ]


def test_modify_workout_rejects_literal_english_slug(db):
    error = _modify_workout_validation_error(
        db,
        USER_ID,
        _action(
            [
                {
                    "op": "swap",
                    "from_slug": "goblet-squat",
                    "to_slug": "forward-lunge",
                }
            ]
        ),
        _context(),
    )

    assert error is not None
    assert "动作不存在" in error
    assert "vital-forward-lunges" in error


def test_modify_workout_accepts_real_forward_lunge_slug(db):
    error = _modify_workout_validation_error(
        db,
        USER_ID,
        _action(
            [
                {
                    "op": "swap",
                    "from_slug": "goblet-squat",
                    "to_slug": "vital-forward-lunges",
                }
            ]
        ),
        _context(),
    )

    assert error is None


def test_modify_workout_rejects_from_slug_outside_current_day(db):
    error = _modify_workout_validation_error(
        db,
        USER_ID,
        _action(
            [
                {
                    "op": "swap",
                    "from_slug": "missing-squat",
                    "to_slug": "vital-forward-lunges",
                }
            ]
        ),
        _context(),
    )

    assert error is not None
    assert "当天计划里没有动作" in error


def test_modify_workout_rejects_unowned_equipment(db):
    error = _modify_workout_validation_error(
        db,
        USER_ID,
        _action([{"op": "add", "slug": "barbell-squat"}]),
        _context(),
    )

    assert error is not None
    assert "没有这个器械" in error


def test_lookup_exercise_returns_database_slug(db):
    for query in ("前弓步", "forward lunge"):
        payload = _lookup_exercise_payload(db, query)
        assert payload["ok"] is True
        assert any(
            item["slug"] == "vital-forward-lunges"
            for item in payload["exercises"]
        )
