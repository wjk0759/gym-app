import asyncio

from app.services.food_vision import DISCLAIMER, analyze


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
