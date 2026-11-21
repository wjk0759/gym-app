"""Tests for life-event rescheduling and habit reminder parsing."""

import asyncio
from datetime import datetime, timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import Profile, User
from app.services.coach_control import runtime
from app.services.coach_control.life_events import resolve
from app.services.food_text import DIET_TZ


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session = sessionmaker(
        bind=engine,
        autoflush=False,
        expire_on_commit=False,
    )()
    session.add(User(id="user-1"))
    session.add(Profile(user_id="user-1", nickname="小林", onboarded_at=datetime.now(DIET_TZ)))
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _plan_context() -> dict:
    today = datetime.now(DIET_TZ).date()
    monday = today + timedelta(days=7 - today.weekday())
    days = []
    for index, (offset, title) in enumerate(
        ((0, "胸日"), (2, "腿日"), (4, "背日"))
    ):
        value = monday + timedelta(days=offset)
        days.append(
            {
                "id": f"day-{index}",
                "date": value.isoformat(),
                "title": title,
                "weekday": value.isoweekday(),
                "completed": False,
                "skipped": False,
            }
        )
    return {
        "plan": {
            "id": "plan-1",
            "version": 4,
            "days": days,
        }
    }


def test_life_event_moves_only_affected_sessions(db):
    resolution = resolve(
        db,
        "user-1",
        "下周一到周二出差，训练怎么办",
        _plan_context(),
    )

    assert resolution["ready"] is True
    batch = resolution["payload"]["batch"]
    assert len(batch) == 1
    action = batch[0]
    assert action["capability_id"] == "training.reschedule"
    assert action["payload"]["title"] == "胸日"
    assert action["payload"]["to_date"] > action["payload"]["from_date"]


def test_life_event_skips_when_user_will_not_make_up(db):
    resolution = resolve(
        db,
        "user-1",
        "下周一到周三出差，练不了，都跳过",
        _plan_context(),
    )

    assert resolution["ready"] is True
    batch = resolution["payload"]["batch"]
    assert len(batch) == 2
    assert {item["capability_id"] for item in batch} == {"training.skip"}
    assert {"胸日", "腿日"} == {
        item["payload"]["title"] for item in batch
    }


def test_life_event_without_training_word_still_builds_a_card(db):
    context = _plan_context()
    result = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "下周一到周三出差",
            app_context=context,
        )
    )

    assert result["intent"] == "coach.batch"
    assert result["pending"]["capability_id"] == "coach.batch"
    batch = result["pending"]["payload"]["batch"]
    assert len(batch) == 2
    assert {item["capability_id"] for item in batch} == {
        "training.reschedule"
    }


def test_long_absence_explains_that_the_window_is_too_large(db):
    context = _plan_context()
    start = datetime.fromisoformat(
        context["plan"]["days"][0]["date"]
    )
    context["plan"]["days"] = [
        {
            "id": f"long-{index}",
            "date": (start + timedelta(days=offset)).date().isoformat(),
            "title": f"第{index + 1}练",
            "weekday": (start + timedelta(days=offset)).isoweekday(),
            "completed": False,
            "skipped": False,
        }
        for index, offset in enumerate((0, 2, 4, 7, 9, 11, 14, 16))
    ]
    result = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "接下来30天都在外地",
            app_context=context,
        )
    )

    assert result["intent"] == "training.life_event"
    assert result["pending"] is None
    assert "跨度" in result["reply"] or "跳过" in result["reply"]


def test_life_event_without_training_is_terminal(db):
    context = _plan_context()
    context["plan"]["days"] = [context["plan"]["days"][2]]  # Friday only

    resolution = resolve(
        db,
        "user-1",
        "下周一到周三出差，训练怎么办",
        context,
    )

    assert resolution["ready"] is False
    assert resolution["terminal"] is True
    assert "没有训练安排" in resolution["question"]


def test_life_event_routes_to_one_card(db):
    context = _plan_context()
    result = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "下周一到周二出差，训练怎么办",
            app_context=context,
        )
    )

    assert result["intent"] == "training.reschedule"
    assert result["pending"]["capability_id"] == "training.reschedule"
    assert result["pending"]["payload"]["title"] == "胸日"
    assert result["pending"]["payload"]["to_date"]


def test_life_event_draft_accepts_a_date_range(db):
    context = _plan_context()
    first = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "下周出差，训练怎么办",
            app_context=context,
        )
    )
    assert first["intent"] == "training.life_event"
    assert first["pending"]["kind"] == "draft"

    second = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "11月24到26号",
            session_id=first["session"]["id"],
        )
    )
    assert second["pending"]["capability_id"] == "training.reschedule"
    assert second["pending"]["payload"]["title"] == "腿日"


def test_habit_reminder_parses_kind_and_time(db):
    from app.services.coach_control.capabilities.ui_actions import (
        resolve_reminders,
    )

    hydration = resolve_reminders("每天10点提醒我喝水")
    sleep = resolve_reminders("晚上10点提醒我睡觉")
    disable = resolve_reminders("关闭喝水提醒")

    assert hydration["payload"] == {
        "enabled": True,
        "kind": "hydration",
        "hour": 10,
        "minute": 0,
    }
    assert sleep["payload"]["kind"] == "sleep"
    assert sleep["payload"]["hour"] == 22
    assert disable["payload"] == {"enabled": False, "kind": "hydration"}


def test_multiple_habit_reminders_are_kept_together(db):
    from app.services.coach_control.capabilities.ui_actions import (
        resolve_reminders,
    )

    resolution = resolve_reminders("每天10点提醒我喝水和睡觉")

    assert resolution["ready"] is True
    items = resolution["payload"]["reminder_items"]
    assert [item["kind"] for item in items] == ["hydration", "sleep"]
    assert {item["hour"] for item in items} == {10}


def test_training_and_habit_reminders_ask_for_separation(db):
    from app.services.coach_control.capabilities.ui_actions import (
        resolve_reminders,
    )

    resolution = resolve_reminders("每天10点提醒我训练和喝水")

    assert resolution["ready"] is False
    assert "分开" in resolution["questions"][0]


def test_first_week_schedule_lists_each_day(db):
    context = _plan_context()
    for item in context["plan"]["days"]:
        item["week_index"] = 1

    result = asyncio.run(
        runtime.handle_turn(
            db,
            "user-1",
            "第一周每天练什么",
            app_context=context,
        )
    )

    assert result["intent"] == "training.week_schedule"
    assert "胸日" in result["reply"]
    assert "腿日" in result["reply"]


def test_habit_reminder_routes_to_confirmation_card(db):
    result = asyncio.run(
        runtime.handle_turn(db, "user-1", "每天10点提醒我喝水")
    )

    assert result["intent"] == "ui.configure_reminders"
    assert result["pending"]["kind"] == "card"
    assert result["pending"]["payload"]["kind"] == "hydration"
    assert result["pending"]["payload"]["hour"] == 10


def test_plan_explanation_without_context_stays_read_only(db):
    result = asyncio.run(
        runtime.handle_turn(db, "user-1", "为什么这样安排计划？")
    )

    assert result["intent"] == "coach.answer"
    assert result["pending"] is None


def test_broad_diet_history_is_read_only(db):
    assert not runtime._looks_like_food("我上周吃了什么")
    assert not runtime._looks_like_diet_review("我上周吃了什么")

    result = asyncio.run(
        runtime.handle_turn(db, "user-1", "我上周吃了什么")
    )

    assert result["intent"] == "coach.answer"
    assert result["pending"] is None
