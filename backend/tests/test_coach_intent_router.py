from __future__ import annotations

import asyncio
import json
from types import SimpleNamespace

from app.services.coach_control import router


def test_router_returns_a_registered_capability(monkeypatch):
    captured: dict[str, str] = {}

    async def fake_complete_json(system, user, **kwargs):
        captured["user"] = user
        return {
            "capability_id": "diet.log_food",
            "confidence": 0.91,
            "reason": "记录火锅",
        }

    monkeypatch.setattr(
        router,
        "settings",
        SimpleNamespace(use_mock_llm=False),
    )
    monkeypatch.setattr(router.llm, "complete_json", fake_complete_json)

    result = asyncio.run(
        router.route_intent(
            None,
            "user-1",
            "今晚那顿火锅 500g 帮我算进去",
        )
    )

    assert result == "diet.log_food"
    catalog = json.loads(captured["user"])["capabilities"]
    assert any(item["id"] == "diet.log_food" for item in catalog)
    assert any(item["examples"] for item in catalog)


def test_router_rejects_low_confidence_and_unknown_ids(monkeypatch):
    async def low_confidence(system, user, **kwargs):
        return {"capability_id": "diet.log_food", "confidence": 0.2}

    monkeypatch.setattr(
        router,
        "settings",
        SimpleNamespace(use_mock_llm=False),
    )
    monkeypatch.setattr(router.llm, "complete_json", low_confidence)
    assert asyncio.run(router.route_intent(None, "user-1", "随便说说")) is None

    async def unknown(system, user, **kwargs):
        return {"capability_id": "not.real", "confidence": 0.99}

    monkeypatch.setattr(router.llm, "complete_json", unknown)
    assert asyncio.run(router.route_intent(None, "user-1", "随便说说")) is None
