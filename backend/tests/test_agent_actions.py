from datetime import datetime

import pytest

from app.services.agent import (
    REVIEW_TZ,
    _forced_food_log_intent,
    _forced_workout_log_intent,
    _is_draft_answer,
    _normalize_app_actions,
    _pending_action_correction,
)


def test_swap_diet_meal_action_keeps_date_and_meal():
    actions = _normalize_app_actions(
        [
            {
                "type": "swap_diet_meal",
                "title": "换一餐",
                "summary": "保持热量不变",
                "payload": {"date": "2026-11-12", "meal": "lunch"},
            }
        ]
    )

    assert actions[0]["type"] == "swap_diet_meal"
    assert actions[0]["payload"]["date"] == "2026-11-12"
    assert actions[0]["payload"]["meal"] == "lunch"


def test_food_log_intent_is_detected_without_misrouting_questions():
    assert _forced_food_log_intent(
        "我今天吃了一份湿炒螺蛳粉，半杯奶茶，帮我记一下"
    )
    assert _forced_food_log_intent("记录一下午餐：鸡腿饭")
    assert not _forced_food_log_intent("打开饮食页")
    assert not _forced_food_log_intent("我今天吃了什么")
    assert not _forced_food_log_intent("我今天吃了什么，还可以吃什么")
    assert not _forced_food_log_intent("我昨天跑了 30 分钟，帮我记一下")
    assert _forced_workout_log_intent("我昨天跑了 30 分钟")
    assert _forced_workout_log_intent("今天补录一次训练")
    assert not _forced_workout_log_intent("开始训练")
    assert not _forced_workout_log_intent("打开训练页")
    assert _is_draft_answer("250ml")
    assert _is_draft_answer("半杯")
    assert _is_draft_answer("对")
    assert _is_draft_answer("不要了")
    assert not _is_draft_answer("我昨天跑了 30 分钟")


def test_pending_food_card_correction_updates_before_write():
    result = _pending_action_correction(
        {
            "pending_action": {
                "type": "log_food",
                "payload": {
                    "date": "2026-11-13",
                    "meal": "dinner",
                    "items": [
                        {
                            "name": "肉肠",
                            "grams": 180,
                            "kcal": 420,
                            "protein_g": 24,
                            "carbs_g": 6,
                            "fat_g": 32,
                        }
                    ],
                },
            }
        },
        "记错了是 230 克",
    )

    assert result is not None
    action = result["actions"][0]
    assert action["payload"]["items"][0]["grams"] == 230
    assert action["payload"]["items"][0]["kcal"] == 536.7


def test_multi_item_card_correction_asks_or_uses_ordinal():
    context = {
        "pending_action": {
            "type": "log_food",
            "payload": {
                "date": "2026-11-13",
                "meal": "dinner",
                "items": [
                    {
                        "name": "肉肠",
                        "grams": 180,
                        "kcal": 420,
                        "protein_g": 24,
                        "carbs_g": 6,
                        "fat_g": 32,
                    },
                    {
                        "name": "奶茶",
                        "grams": 250,
                        "kcal": 175,
                        "protein_g": 2.5,
                        "carbs_g": 30,
                        "fat_g": 5.8,
                    },
                ],
            },
        }
    }

    ambiguous = _pending_action_correction(context, "记错了是 230 克")
    assert ambiguous is not None
    assert ambiguous["actions"] == []
    assert "哪一项" in ambiguous["reply"]

    updated = _pending_action_correction(context, "第二个改成 300 克")
    assert updated is not None
    assert updated["actions"][0]["payload"]["items"][1]["grams"] == 300
    assert updated["actions"][0]["payload"]["items"][0]["grams"] == 180


def test_log_food_action_requires_resolved_items():
    actions = _normalize_app_actions(
        [
            {
                "type": "log_food",
                "title": "记录午餐",
                "payload": {
                    "date": "2026-11-13",
                    "meal": "lunch",
                    "items": [
                        {
                            "name": "湿炒螺蛳粉",
                            "grams": 500,
                            "kcal": 600,
                            "protein_g": 22,
                            "carbs_g": 80,
                            "fat_g": 18,
                        }
                    ],
                },
            }
        ]
    )

    assert actions[0]["payload"]["items"][0]["name"] == "湿炒螺蛳粉"
    assert actions[0]["payload"]["meal"] == "lunch"

    with pytest.raises(ValueError):
        _normalize_app_actions(
            [
                {
                    "type": "log_food",
                    "title": "记录午餐",
                    "payload": {"date": "2026-11-13", "meal": "lunch"},
                }
            ]
        )


def test_swap_diet_meal_defaults_to_today_and_rejects_unknown_meal():
    actions = _normalize_app_actions(
        [
            {
                "type": "swap_diet_meal",
                "title": "换一餐",
                "payload": {"meal": "dinner"},
            }
        ]
    )
    assert actions[0]["payload"]["date"] == datetime.now(REVIEW_TZ).date().isoformat()

    with pytest.raises(ValueError):
        _normalize_app_actions(
            [
                {
                    "type": "swap_diet_meal",
                    "title": "换一餐",
                    "payload": {"date": "2026-11-12", "meal": "brunch"},
                }
            ]
        )
