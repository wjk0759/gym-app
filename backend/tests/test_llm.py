import pytest

from app.services.llm import LLMError, _merge_usage, _parse_json_object


def test_parse_concatenated_json_objects_uses_last_complete_object():
    content = (
        '{"action":"tool","tool":"remember","arguments":{"kind":"goal"}}\n'
        '{"action":"tool","tool":"propose_app_actions","arguments":{"actions":[]}}'
    )
    parsed = _parse_json_object(content)
    assert parsed["action"] == "tool"
    assert parsed["tool"] == "propose_app_actions"


def test_parse_json_fence():
    content = '```json\n{"action":"final","message":"ok"}\n```'
    assert _parse_json_object(content)["message"] == "ok"


def test_parse_invalid_json_raises_llm_error():
    with pytest.raises(LLMError):
        _parse_json_object("not json at all")


def test_merge_usage_accumulates_prompt_completion_and_cache():
    usage: dict[str, int] = {}
    _merge_usage(
        usage,
        {
            "prompt_tokens": 1000,
            "completion_tokens": 100,
            "prompt_cache_hit_tokens": 600,
            "prompt_cache_miss_tokens": 400,
        },
    )
    _merge_usage(
        usage,
        {
            "prompt_tokens": 500,
            "completion_tokens": 50,
            "prompt_tokens_details": {"cached_tokens": 300},
        },
    )
    assert usage["calls"] == 2
    assert usage["prompt_tokens"] == 1500
    assert usage["completion_tokens"] == 150
    assert usage["prompt_cache_hit_tokens"] == 600
    assert usage["prompt_cache_miss_tokens"] == 400
    assert usage["prompt_tokens_details"]["cached_tokens"] == 300
