from types import SimpleNamespace

import pytest

from app.services.reply_guard import review_reply


@pytest.mark.parametrize(
    "reply",
    [
        "今天练腿，深蹲 3 组，做完记得拉伸。",
        "疼的时候不要继续练同一个动作，先停下来评估。",
        "补剂剂量我不给具体数字，也不建议你自己加量。",
        "这个不能确诊为骨折，先找医生检查。",
        "有人说疼也继续练，这是错误的，先停下来。",
    ],
)
def test_safe_or_negated_replies_are_not_blocked(reply):
    review = review_reply(SimpleNamespace(age=30), reply)

    assert review.blocked is False
    assert review.reply == reply
    assert review.rules == ()


def test_blocks_training_through_pain():
    review = review_reply(
        SimpleNamespace(age=30),
        "膝盖疼也可以继续练，不用停，忍一忍就过去了。",
    )

    assert review.safety_flag == "injury_guard"
    assert review.rules == ("train_through_pain",)
    assert "不要继续练" in review.reply


def test_blocks_pain_continue_without_stop():
    review = review_reply(
        SimpleNamespace(age=30),
        "疼就继续练，不用停。",
    )

    assert review.safety_flag == "injury_guard"


def test_negation_in_a_later_sentence_does_not_excuse_unsafe_advice():
    review = review_reply(
        SimpleNamespace(age=30),
        "疼就继续练。下一句再说不要偷懒。",
    )

    assert review.safety_flag == "injury_guard"


def test_blocks_extreme_diet_and_uses_minor_guard_when_needed():
    adult = review_reply(
        SimpleNamespace(age=30),
        "每天只吃一顿，再配合催吐，瘦得更快。",
    )
    minor = review_reply(
        SimpleNamespace(age=16),
        "每天只吃一顿，再配合催吐，瘦得更快。",
    )

    assert adult.safety_flag == "medical_referral"
    assert minor.safety_flag == "minor_guard"
    assert "极端断食" in adult.reply


@pytest.mark.parametrize(
    "reply",
    [
        "肌酸每天吃 5 克，训练前半小时喝。",
        "每天吃 5 克肌酸，训练前半小时喝。",
    ],
)
def test_blocks_supplement_dosing(reply):
    review = review_reply(SimpleNamespace(age=30), reply)

    assert review.safety_flag == "supplement_guard"
    assert "补剂剂量" in review.reply


def test_blocks_medical_dismissal():
    review = review_reply(
        SimpleNamespace(age=30),
        "不用看医生，继续练就行。",
    )

    assert review.safety_flag == "medical_referral"
    assert "就医" in review.reply
    assert review.rules == ("medical_dismissal",)


def test_blocks_diagnosis_claim():
    review = review_reply(
        SimpleNamespace(age=30),
        "你这就是骨折，休息两天继续练。",
    )

    assert review.safety_flag == "medical_referral"
    assert review.rules == ("diagnosis_claim",)


def test_multiple_rules_are_reported():
    review = review_reply(
        SimpleNamespace(age=30),
        "膝盖疼也继续练，肌酸每天吃 5 克。",
    )

    assert review.safety_flag == "injury_guard"
    assert set(review.rules) == {"train_through_pain", "supplement_dose"}
