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
