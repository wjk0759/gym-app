from datetime import datetime

import pytest

from app.services.agent import REVIEW_TZ, _normalize_app_actions


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
