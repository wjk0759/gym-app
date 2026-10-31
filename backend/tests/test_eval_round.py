from eval.round import _provider_down
from eval.runner import _evaluate, _has_approx_body_fat


def test_provider_balance_error_is_not_a_coach_failure():
    assert _provider_down(
        {"error": 'LLM HTTP 402: {"code":"insufficient_balance_error"}'}
    )
    assert _provider_down({"error": "HTTP 429: rate limited"})
    assert not _provider_down({"error": "missing action: update_goal"})
    assert not _provider_down({})


def _result() -> dict:
    return {
        "status": "completed",
        "actions": [],
        "tool_calls": [],
        "lookup_names": [],
    }


def test_turn_expectations_check_each_reply_not_the_concatenation():
    scenario = {
        "expected": {"max_sentences": 5},
        "turn_expectations": [
            {"must_include_any": ["哑铃"]},
            {"must_include_any": ["出差"]},
        ],
    }
    failures = _evaluate(
        scenario,
        _result(),
        "第一轮提到哑铃。\n第二轮忘了。",
        replies=["第一轮提到哑铃。", "第二轮忘了。"],
    )
    assert failures == ["turn 2 missing any of: ['出差']"]


def test_body_fat_must_be_approximate_and_not_a_decimal_or_range():
    assert _has_approx_body_fat("我看大概 20% 左右。", 20)
    assert _has_approx_body_fat("你 BMI 22.3，体脂大概 20% 左右。", 20)
    assert not _has_approx_body_fat("你的体脂是 20.5%。", 20)
    assert not _has_approx_body_fat("大概在 18-22%。", 20)
    assert not _has_approx_body_fat("你的体脂是 20%。", 20)


def test_no_visual_must_not_report_a_body_fat_number():
    scenario = {
        "expected": {
            "max_sentences": 5,
            "forbid_body_fat_number": True,
        },
    }
    failures = _evaluate(
        scenario,
        _result(),
        "我没看到这张照片，发一张现在的全身照吧。",
        replies=["我没看到这张照片，发一张现在的全身照吧。"],
    )
    assert failures == []

    failures = _evaluate(
        scenario,
        _result(),
        "上次记录是体脂大概 22%。",
        replies=["上次记录是体脂大概 22%。"],
    )
    assert failures == ["body fat number without a current visual"]


def test_turn_expectations_handle_missing_turn_and_forbidden_text():
    scenario = {
        "expected": {"max_sentences": 5},
        "turn_expectations": [
            {"must_include_any": ["可以"], "must_not_include": ["后天"]},
            {"must_include_any": ["明天"]},
        ],
    }
    failures = _evaluate(
        scenario,
        _result(),
        "可以，后天吧。",
        replies=["可以，后天吧。"],
    )
    assert "missing turn 2" in failures
    assert "turn 1 forbidden: 后天" in failures
