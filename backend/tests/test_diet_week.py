from datetime import date
from types import SimpleNamespace

from app.services.diet import (
    _normalize_ai_week,
    build_diet_week,
)


def _profile() -> SimpleNamespace:
    return SimpleNamespace(
        sex="female",
        age=28,
        height_cm=165,
        weight_kg=58,
        body_fat_pct=24,
        waist_cm=70,
        hip_cm=94,
        experience="beginner",
        weekly_days=3,
        injuries=[],
    )


def test_template_week_has_a_recipe_for_every_meal():
    week = build_diet_week(
        _profile(),
        "recomp",
        "balanced",
        date(2026, 10, 26),
        training_days=[1, 3, 5],
    )

    assert len(week["days"]) == 7
    for day in week["days"]:
        for meal in day["meals"]:
            assert meal["dishes"]
            for dish in meal["dishes"]:
                assert dish["recipe"]["ingredients"]
                assert len(dish["recipe"]["steps"]) >= 2


def test_ai_week_normalization_keeps_recipes_and_falls_back_missing_days():
    fallback = {
        "week_start": "2026-10-26",
        "days": [
            {
                "date": "2026-10-26",
                "weekday": 1,
                "day_type": "high",
                "day_type_label": "高碳日",
                "title": "周一 · 高碳日",
                "targets": {"target_kcal": 1800},
                "meals": [
                    {
                        "meal": "breakfast",
                        "name": "早餐",
                        "kcal": 450,
                        "items": ["燕麦 40g"],
                        "dishes": [
                            {
                                "name": "燕麦早餐",
                                "items": ["燕麦 40g"],
                                "recipe": {
                                    "title": "燕麦早餐",
                                    "ingredients": ["燕麦 40g", "牛奶 200ml"],
                                    "steps": ["混合。", "加热至合适温度。"],
                                    "tip": None,
                                },
                            }
                        ],
                    }
                ],
            },
            {
                "date": "2026-10-27",
                "weekday": 2,
                "day_type": "low",
                "day_type_label": "低碳日",
                "title": "周二 · 低碳日",
                "targets": {"target_kcal": 1600},
                "meals": [
                    {
                        "meal": "lunch",
                        "name": "午餐",
                        "kcal": 550,
                        "items": ["鸡腿 150g"],
                        "dishes": [
                            {
                                "name": "香菇鸡腿",
                                "items": ["鸡腿 150g", "香菇 100g"],
                                "recipe": {
                                    "title": "香菇鸡腿",
                                    "ingredients": ["鸡腿 150g", "香菇 100g"],
                                    "steps": ["鸡腿切块。", "和香菇一起焖熟。"],
                                    "tip": "少油少盐。",
                                },
                            }
                        ],
                    }
                ],
            },
        ],
        "strategy": {"id": "balanced"},
        "disclaimer": "估算",
        "generated_by": "template",
    }
    raw = {
        "days": [
            {
                "date": "2026-10-26",
                "meals": [
                    {
                        "meal": "breakfast",
                        "name": "早餐",
                        "kcal": 480,
                        "items": ["番茄鸡蛋面"],
                        "dishes": [
                            {
                                "name": "番茄鸡蛋面",
                                "items": ["番茄 1 个", "鸡蛋 2 个", "面条 80g"],
                                "recipe": {
                                    "title": "番茄鸡蛋面",
                                    "ingredients": ["番茄 1 个", "鸡蛋 2 个", "面条 80g"],
                                    "steps": ["番茄切块。", "炒蛋后加入番茄。", "下面煮熟。"],
                                    "tip": "少油。",
                                },
                            }
                        ],
                    }
                ],
            }
        ],
        "note": "家常菜优先。",
    }

    result = _normalize_ai_week(raw, fallback)

    assert result["generated_by"] == "ai"
    assert result["days"][0]["meals"][0]["dishes"][0]["name"] == "番茄鸡蛋面"
    assert result["days"][0]["meals"][0]["dishes"][0]["recipe"]["steps"]
    # Missing dates keep the template day instead of disappearing.
    assert result["days"][1]["meals"][0]["name"] == "午餐"
    assert result["warning"]


def test_ai_week_without_valid_days_is_rejected():
    fallback = {
        "week_start": "2026-10-26",
        "days": [],
        "strategy": {},
        "disclaimer": "",
        "generated_by": "template",
    }

    try:
        _normalize_ai_week({"days": []}, fallback)
    except ValueError as exc:
        assert "days" in str(exc) or "餐次" in str(exc)
    else:
        raise AssertionError("empty AI week should be rejected")
