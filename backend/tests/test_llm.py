import pytest

from app.services.llm import LLMError, _parse_json_object


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
