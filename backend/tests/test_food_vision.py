import asyncio

from app.services.food_vision import DISCLAIMER, _normalize, analyze


def test_food_analysis_returns_editable_items():
    result = asyncio.run(analyze(b"meal-photo", "meal.jpg"))

    assert result["items"], result
    assert result["total_kcal"] > 0
    assert result["total_protein_g"] >= 0
    assert result["disclaimer"] == DISCLAIMER
    assert result["model"] == "mock"

    first = result["items"][0]
    assert first["grams"] > 0
    assert first["kcal_per_100g"] > 0
    assert 0 < first["confidence"] <= 1


def test_food_analysis_is_deterministic():
    first = asyncio.run(analyze(b"same-bytes", "meal.jpg"))
    second = asyncio.run(analyze(b"same-bytes", "other.jpg"))

    assert first["items"] == second["items"]
    assert first["total_kcal"] == second["total_kcal"]


def test_normalize_fills_default_portion_range():
    result = _normalize(
        {
            "summary": "米饭",
            "reference": {"type": "plate", "basis": "白色圆盘"},
            "items": [{"name": "米饭", "grams": 150, "kcal": 174,
                       "protein_g": 3.9, "carbs_g": 38.9, "fat_g": 0.5}],
        },
        "meal.jpg",
    )
    item = result["items"][0]
    assert item["grams_min"] <= item["grams"] <= item["grams_max"]
    assert item["portion_confidence"] > 0
    assert item["portion_basis"] == "白色圆盘"


def test_normalize_clamps_explicit_range_and_recomputes_macros():
    result = _normalize(
        {
            "reference": {"type": "none"},
            "items": [
                {
                    "name": "混合菜",
                    "grams": 150,
                    "grams_min": 140,
                    "grams_max": 160,
                    "kcal": 600,
                    "protein_g": 4,
                    "carbs_g": 40,
                    "fat_g": 1,
                }
            ],
        },
        "meal.jpg",
    )
    item = result["items"][0]
    assert item["grams_min"] <= item["grams"] <= item["grams_max"]
    assert item["kcal"] < 600
    assert item["kcal"] == 4 * 4 + 40 * 4 + 1 * 9


def test_non_food_has_no_items():
    result = _normalize(
        {"summary": "空盘", "is_food": False, "items": []},
        "empty.jpg",
    )
    assert result["is_food"] is False
    assert result["items"] == []
