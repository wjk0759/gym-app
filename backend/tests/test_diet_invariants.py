import json
from datetime import date

from app.models import Profile
from app.services.diet import DIET_STRATEGIES, build_diet_week, build_plan
from app.services.diet_preferences import apply_food_avoidance
from app.services.diet_schema import validate_diet_plan


def _profile() -> Profile:
    return Profile(
        user_id="user-1",
        sex="male",
        height_cm=178,
        weight_kg=72,
        weekly_days=3,
        session_minutes=45,
    )


def test_template_day_plan_has_no_avoided_food_anywhere():
    terms = ["鸡胸肉", "西兰花", "牛奶"]
    plan = build_plan(_profile(), "recomp", date(2026, 11, 18), terms)
    validate_diet_plan(plan)
    text = json.dumps(plan, ensure_ascii=False)
    for term in terms:
        assert term not in text, plan


def test_week_plan_has_no_avoided_food_for_every_strategy():
    terms = ["鸡胸肉", "西兰花", "牛奶", "沙拉"]
    for strategy_id in DIET_STRATEGIES:
        plan = build_diet_week(
            _profile(),
            "recomp",
            strategy_id,
            date(2026, 11, 16),
            avoid_terms=terms,
        )
        validate_diet_plan(plan)
        text = json.dumps(plan, ensure_ascii=False)
        for term in terms:
            assert term not in text, (strategy_id, term, plan)


def test_unknown_nested_fields_are_scrubbed():
    plan = {
        "meals": [
            {
                "meal": "lunch",
                "name": "午餐",
                "items": ["米饭 150g"],
                "future_field": {
                    "note": "可以搭配鸡胸肉",
                    "nested": ["鸡胸肉 100g"],
                },
            }
        ]
    }
    clean = apply_food_avoidance(plan, ["鸡胸肉"])
    text = json.dumps(clean, ensure_ascii=False)
    assert "鸡胸肉" not in text, clean
