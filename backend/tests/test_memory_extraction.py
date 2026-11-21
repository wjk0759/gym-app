"""Regression tests for coach memory extraction boundaries."""

import asyncio
import json
from types import SimpleNamespace

from app.services import memory


def test_memory_extraction_never_sends_the_assistant_reply(monkeypatch):
    """The extractor must only see what the user actually said.

    Production smoke showed the model copying its own invented sentence
    ("你之前提过想用杠铃卧推...") into long-term memory. That made the
    hallucination look like real history on the next turn.
    """
    captured: dict = {}

    async def fake_complete_json(system_prompt, payload, **kwargs):
        captured["system_prompt"] = system_prompt
        captured["payload"] = json.loads(payload)
        return {"memories": []}

    monkeypatch.setattr(memory, "settings", SimpleNamespace(use_mock_llm=False))
    monkeypatch.setattr(memory.llm, "complete_json", fake_complete_json)
    db = SimpleNamespace(commit=lambda: None)

    result = asyncio.run(
        memory.extract_and_store(
            db,
            "user-1",
            "我想用杠铃卧推",
            "你之前提过想用杠铃卧推，我记住了。",
        )
    )

    assert result == []
    assert captured["payload"] == {"user_message": "我想用杠铃卧推"}
    assert "assistant_reply" not in captured["payload"]
    assert "不要从教练" in captured["system_prompt"]


def test_punctuation_only_turn_does_not_call_the_memory_model(monkeypatch):
    called = False

    async def fake_complete_json(system_prompt, payload, **kwargs):
        nonlocal called
        called = True
        return {"memories": []}

    monkeypatch.setattr(memory, "settings", SimpleNamespace(use_mock_llm=False))
    monkeypatch.setattr(memory.llm, "complete_json", fake_complete_json)
    db = SimpleNamespace(commit=lambda: None)

    result = asyncio.run(
        memory.extract_and_store(
            db,
            "user-1",
            "？？？？？？？？",
            "",
        )
    )

    assert result == []
    assert called is False


def test_conflicting_body_memory_is_detected():
    profile = SimpleNamespace(height_cm=175, weight_kg=72)

    assert memory.memory_conflicts_with_profile(
        profile,
        "height_cm",
        "身高 180cm",
    )
    assert not memory.memory_conflicts_with_profile(
        profile,
        "height_cm",
        "身高 175cm",
    )
    assert memory.memory_conflicts_with_profile(
        profile,
        "weight_kg",
        "体重 80kg",
    )
    assert not memory.memory_conflicts_with_profile(
        profile,
        "weight_kg",
        "体重 72kg",
    )
