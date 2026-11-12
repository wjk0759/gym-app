import re

from app.services.agent import AGENT_PROMPT_VERSION
from app.services.prompt_registry import MAX_PROMPT_VERSION, prompt_version


def test_prompt_version_is_stable_and_text_sensitive():
    first = prompt_version("agent", "你是教练", "只输出 JSON")
    second = prompt_version("agent", "你是教练", "只输出 JSON")
    changed = prompt_version("agent", "你是教练", "输出 Markdown")

    assert first == second
    assert first != changed
    assert re.fullmatch(r"agent@[0-9a-f]{8}", first)


def test_prompt_version_is_short_and_slugged():
    version = prompt_version("Coach Vision / V2", "prompt")

    assert version.startswith("coach_vision_v2@")
    assert len(version) <= MAX_PROMPT_VERSION


def test_agent_prompt_version_matches_runtime_prompt():
    assert AGENT_PROMPT_VERSION.startswith("agent@")
    assert len(AGENT_PROMPT_VERSION) <= MAX_PROMPT_VERSION
