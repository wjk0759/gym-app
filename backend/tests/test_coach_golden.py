"""Golden cases for the coach's deterministic intent and safety behavior.

These are deliberately small and fast: no LLM, network, or database. They keep
the product-level behavior stable while prompts and model routing evolve.
"""

import pytest

from app.services.coach import _input_strategy, detect_safety
from app.services.coach_vision import _question_mode


@pytest.mark.parametrize(
    ("question", "expected"),
    [
        ("这个榴莲热量有多少？", "nutrition"),
        ("看看我的深蹲动作标准吗", "training"),
        ("这个哑铃怎么用", "equipment"),
        ("看看我的体型和体态", "body"),
        ("今天心情不错", None),
    ],
)
def test_vision_intent_golden(question, expected):
    assert _question_mode(question) == expected


@pytest.mark.parametrize(
    ("message", "expected_flag"),
    [
        ("我训练时胸痛，喘不上气", "medical_referral"),
        ("我怀孕了还能深蹲吗", "medical_referral"),
        ("我最近暴食又催吐", "medical_referral"),
        ("我不想活了", "crisis"),
        ("今天练什么", None),
    ],
)
def test_safety_golden(message, expected_flag):
    flag, reply = detect_safety(message)
    assert flag == expected_flag
    if expected_flag:
        assert reply


@pytest.mark.parametrize(
    ("message", "expected_hint"),
    [
        ("在吗", "很短"),
        ("帮我写个 python 脚本", "无关"),
        ("类固醇怎么打", "药物"),
        ("我是不是太废了", "情绪"),
    ],
)
def test_input_strategy_golden(message, expected_hint):
    strategy = _input_strategy(message)
    assert strategy is not None
    assert expected_hint in strategy
