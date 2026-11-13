import asyncio
import json
from datetime import date, datetime
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import AgentActionDraft, ChatSession, Profile, User
from app.services import agent as agent_service
from app.services import food_text, llm


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
    session.add(
        Profile(
            user_id="user-1",
            nickname="测试",
            sex="male",
            birth_date=date(1996, 1, 1),
            height_cm=178,
            weight_kg=72,
            weekly_days=3,
            session_minutes=45,
        )
    )
    session.add(ChatSession(id="session-1", user_id="user-1", title="测试"))
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _install_fake_llm(monkeypatch, *, food_resolution, agent_decision=None):
    calls = {"agent": 0, "food": 0}

    async def fake_complete_json(system, user, **kwargs):
        if system == agent_service.SYSTEM_PROMPT:
            calls["agent"] += 1
            if agent_decision is None:
                raise AssertionError("agent model should not be called again")
            return agent_decision(user)
        if system == food_text._SYSTEM_PROMPT:
            calls["food"] += 1
            response = (
                food_resolution[min(calls["food"] - 1, len(food_resolution) - 1)]
                if isinstance(food_resolution, list)
                else food_resolution
            )
            if isinstance(response, Exception):
                raise response
            return response
        raise AssertionError(f"unexpected prompt: {system[:40]}")

    monkeypatch.setattr(agent_service.settings, "llm_api_key", "test-key")
    monkeypatch.setattr(llm, "complete_json", fake_complete_json)
    monkeypatch.setattr(
        agent_service,
        "schedule_memory_extraction",
        lambda *args, **kwargs: None,
    )
    return calls


def _first_food_decision(state_json):
    state = json.loads(state_json)
    return {
        "action": "tool",
        "tool": "resolve_food",
        "arguments": {
            "text": state.get("user_message") or "",
            "meal": "snack",
            "date": "2026-11-13",
        },
    }


def test_unresolved_food_stops_the_turn_and_keeps_one_draft(db, monkeypatch):
    message = (
        "我刚刚又吃了 100 克玉米肉肠、180 克牛筋肉肠、"
        "300ml 可乐 帮我记到昨天的加餐去"
    )
    calls = _install_fake_llm(
        monkeypatch,
        food_resolution=llm.LLMError("invalid JSON"),
        agent_decision=_first_food_decision,
    )

    result = asyncio.run(
        agent_service.run_agent(
            db,
            "user-1",
            message,
            session_id="session-1",
            history=[],
        )
    )

    assert result["actions"] == []
    assert result["status"] == "completed"
    assert result["pending_draft"] is not None
    assert "调整训练日" not in result["reply"]
    assert "调整训练" not in result["reply"]
    assert "玉米肉肠" in result["reply"]
    assert "热量" in result["reply"]
    assert "多少克" not in result["reply"]
    assert calls["agent"] == 1
    assert calls["food"] == 1

    draft = db.execute(select(AgentActionDraft)).scalar_one()
    context = food_text.food_log_context(message)
    assert draft.status == "collecting"
    assert draft.payload["date"] == context["date"]
    assert draft.payload["meal"] == "snack"


def test_ready_food_builds_the_card_server_side_without_a_second_model_call(
    db, monkeypatch
):
    message = (
        "我刚刚又吃了 100 克玉米肉肠、180 克牛筋肉肠、"
        "300ml 可乐 帮我记到昨天的加餐去"
    )
    calls = _install_fake_llm(
        monkeypatch,
        food_resolution={
            "items": [
                {
                    "name": "玉米肉肠",
                    "grams": "100g",
                    "kcal": 270,
                    "protein_g": 11,
                    "carbs_g": 16,
                    "fat_g": 19,
                },
                {
                    "name": "牛筋肉肠",
                    "grams": 180,
                    "kcal": 468,
                    "protein_g": 25.2,
                    "carbs_g": 14.4,
                    "fat_g": 34.2,
                },
                {
                    "name": "可乐",
                    "volume_ml": 300,
                    "kcal": 129,
                    "protein_g": 0,
                    "carbs_g": 31.8,
                    "fat_g": 0,
                },
            ],
            "questions": [],
        },
        agent_decision=_first_food_decision,
    )

    result = asyncio.run(
        agent_service.run_agent(
            db,
            "user-1",
            message,
            session_id="session-1",
            history=[],
        )
    )

    assert result["status"] == "needs_confirmation"
    assert len(result["actions"]) == 1
    action = result["actions"][0]
    assert action["type"] == "log_food"
    assert [item["name"] for item in action["payload"]["items"]] == [
        "玉米肉肠",
        "牛筋肉肠",
        "可乐",
    ]
    assert action["payload"]["items"][0]["grams"] == 100
    assert action["payload"]["items"][2]["grams"] == 300
    context = food_text.food_log_context(message)
    assert action["payload"]["date"] == context["date"]
    assert action["payload"]["meal"] == "snack"
    assert result["pending_draft"] is None
    assert calls["agent"] == 1
    assert calls["food"] == 1


def test_partial_llm_answer_keeps_the_unknown_food_question(db, monkeypatch):
    message = (
        "我刚刚又吃了 100 克玉米肉肠、180 克牛筋肉肠、"
        "300ml 可乐 帮我记到昨天的加餐去"
    )
    _install_fake_llm(
        monkeypatch,
        food_resolution={
            "items": [
                {
                    "name": "可乐",
                    "volume_ml": 300,
                    "kcal": 129,
                    "protein_g": 0,
                    "carbs_g": 31.8,
                    "fat_g": 0,
                }
            ],
            "questions": [],
        },
        agent_decision=_first_food_decision,
    )

    result = asyncio.run(
        agent_service.run_agent(
            db,
            "user-1",
            message,
            session_id="session-1",
            history=[],
        )
    )

    assert result["actions"] == []
    assert result["pending_draft"] is not None
    assert "玉米肉肠" in result["reply"]
    assert "牛筋肉肠" in result["reply"]


def test_draft_answer_resolves_and_consumes_the_draft(db, monkeypatch):
    first_message = (
        "我刚刚又吃了 100 克玉米肉肠、180 克牛筋肉肠、"
        "300ml 可乐 帮我记到昨天的加餐去"
    )
    calls = _install_fake_llm(
        monkeypatch,
        food_resolution=[
            llm.LLMError("invalid JSON"),
            {
                "items": [
                    {
                        "name": "玉米鸡肉肠",
                        "grams": 100,
                        "kcal": 200,
                        "protein_g": 13,
                        "carbs_g": 9,
                        "fat_g": 12,
                    },
                    {
                        "name": "牛筋肉肠",
                        "grams": 180,
                        "kcal": 468,
                        "protein_g": 25.2,
                        "carbs_g": 14.4,
                        "fat_g": 34.2,
                    },
                    {
                        "name": "可乐",
                        "volume_ml": 300,
                        "kcal": 129,
                        "protein_g": 0,
                        "carbs_g": 31.8,
                        "fat_g": 0,
                    },
                ],
                "questions": [],
            },
        ],
        agent_decision=_first_food_decision,
    )

    first = asyncio.run(
        agent_service.run_agent(
            db,
            "user-1",
            first_message,
            session_id="session-1",
            history=[],
        )
    )
    assert first["actions"] == []
    assert first["pending_draft"] is not None

    second = asyncio.run(
        agent_service.run_agent(
            db,
            "user-1",
            "玉米鸡肉肠 100 克",
            session_id="session-1",
            history=[],
        )
    )

    assert second["status"] == "needs_confirmation"
    assert len(second["actions"]) == 1
    assert second["pending_draft"] is None
    assert second["actions"][0]["payload"]["items"][0]["name"] == "玉米鸡肉肠"
    assert second["actions"][0]["payload"]["date"] == food_text.food_log_context(
        first_message
    )["date"]
    assert db.execute(select(AgentActionDraft)).scalar_one().status == "consumed"
    assert calls["food"] == 2


def _pending_card(items):
    return {
        "pending_action": {
            "type": "log_food",
            "payload": {
                "date": "2026-11-13",
                "meal": "snack",
                "raw_text": "玉米肉肠 100g",
                "items": items,
            },
        }
    }


def test_short_food_amount_is_a_complete_log_intent():
    assert agent_service._forced_food_log_intent("100 克玉米肉肠")
    assert agent_service._forced_food_log_intent("玉米鸡肉肠 100 克")
    assert not agent_service._forced_food_log_intent("100 克玉米肉肠多少卡")


def test_pending_card_can_replace_a_food_by_name(db, monkeypatch):
    _install_fake_llm(
        monkeypatch,
        food_resolution={
            "items": [
                {
                    "name": "玉米鸡肉肠",
                    "grams": 100,
                    "kcal": 200,
                    "protein_g": 13,
                    "carbs_g": 9,
                    "fat_g": 12,
                }
            ],
            "questions": [],
        },
    )
    context = _pending_card(
        [
            {
                "name": "玉米肉肠",
                "grams": 100,
                "kcal": 250,
                "protein_g": 12,
                "carbs_g": 10,
                "fat_g": 18,
            },
            {
                "name": "牛筋肉肠",
                "grams": 180,
                "kcal": 468,
                "protein_g": 25,
                "carbs_g": 14,
                "fat_g": 36,
            },
        ]
    )

    result = asyncio.run(
        agent_service._pending_food_replacement(
            db,
            "user-1",
            context,
            "不是玉米肉肠，是玉米鸡肉肠 100 克",
        )
    )

    assert result is not None
    assert len(result["actions"]) == 1
    items = result["actions"][0]["payload"]["items"]
    assert items[0]["name"] == "玉米鸡肉肠"
    assert items[0]["grams"] == 100
    assert items[1]["name"] == "牛筋肉肠"
    assert result["actions"][0]["payload"]["date"] == "2026-11-13"


def test_pending_card_amount_only_correction_is_not_a_replacement(db, monkeypatch):
    _install_fake_llm(
        monkeypatch,
        food_resolution=llm.LLMError("should not be called"),
    )
    context = _pending_card(
        [
            {
                "name": "玉米肉肠",
                "grams": 100,
                "kcal": 250,
                "protein_g": 12,
                "carbs_g": 10,
                "fat_g": 18,
            }
        ]
    )

    result = asyncio.run(
        agent_service._pending_food_replacement(
            db,
            "user-1",
            context,
            "记错了是 230 克",
        )
    )

    assert result is None


def test_food_resolution_overrides_model_invented_items():
    action = agent_service._normalize_app_actions(
        [
            {
                "type": "log_food",
                "title": "记录饮食",
                "summary": "模型自己编的",
                "payload": {
                    "date": "2026-11-13",
                    "meal": "snack",
                    "items": [
                        {
                            "name": "模型编的肉肠",
                            "grams": 999,
                            "kcal": 9999,
                            "protein_g": 1,
                            "carbs_g": 1,
                            "fat_g": 1,
                        }
                    ],
                },
            }
        ],
        food_resolution={
            "ready": True,
            "date": "2026-11-13",
            "meal": "snack",
            "items": [
                {
                    "name": "玉米肉肠",
                    "grams": 100,
                    "kcal": 270,
                    "protein_g": 11,
                    "carbs_g": 16,
                    "fat_g": 19,
                }
            ],
        },
    )[0]

    assert action["payload"]["items"][0]["name"] == "玉米肉肠"
    assert action["payload"]["items"][0]["grams"] == 100
    assert action["payload"]["date"] == "2026-11-13"


def test_agent_loop_exhaustion_fails_with_retry_not_a_plan_question(db, monkeypatch):
    message = "帮我记一下午餐"
    calls = _install_fake_llm(
        monkeypatch,
        food_resolution=llm.LLMError("not used"),
        agent_decision=lambda _: {
            "action": "tool",
            "tool": "get_context",
            "arguments": {},
        },
    )

    result = asyncio.run(
        agent_service.run_agent(
            db,
            "user-1",
            message,
            session_id="session-1",
            history=[],
        )
    )

    assert result["status"] == "failed"
    assert result["actions"] == []
    assert "没有完成" in result["reply"]
    assert "调整训练日" not in result["reply"]
    assert result["error"] == "agent_max_steps"
    assert calls["agent"] == agent_service.MAX_STEPS


def test_normalize_llm_result_accepts_volume_strings_and_fiber():
    resolution = food_text._normalize_llm_result(
        {
            "items": [
                {
                    "name": "玉米肉肠",
                    "grams": "100g",
                    "kcal": "270",
                    "protein_g": "11",
                    "carbs_g": 16,
                    "fat_g": 19,
                    "fiber_g": 2,
                },
                {
                    "name": "可乐",
                    "volume_ml": 300,
                    "kcal": 129,
                    "protein_g": 0,
                    "carbs_g": 31.8,
                    "fat_g": 0,
                },
            ]
        }
    )

    assert resolution.items[0]["grams"] == 100
    assert resolution.items[0]["fiber_g"] == 2
    assert resolution.items[1]["grams"] == 300


def test_beijing_timezone_parses_yesterday_snack():
    now = datetime(2026, 11, 14, 1, 39, tzinfo=ZoneInfo("Asia/Shanghai"))
    context = food_text.food_log_context("记到昨天的加餐去", now=now)

    assert context == {"date": "2026-11-13", "meal": "snack"}


def test_unknown_food_question_does_not_ask_for_grams_again():
    resolution = food_text.resolve_food_rules("100 克玉米肉肠")

    assert resolution.items == []
    assert len(resolution.questions) == 1
    assert "玉米肉肠" in resolution.questions[0]
    assert "热量" in resolution.questions[0]
    assert "多少克" not in resolution.questions[0]
