import asyncio
from types import SimpleNamespace

from app.services import equipment


def _vision_result(**overrides):
    result = {
        "is_gym_equipment": True,
        "equipment_slug": "leg_press",
        "equipment_name": "腿举机",
        "confidence": 0.92,
        "visible_features": ["斜靠背", "脚踏板", "挂片杆"],
        "exercise_slugs": ["cm_leg_press"],
        "description": "一台挂片式线性腿举机。",
    }
    result.update(overrides)
    return result


def _settings():
    return SimpleNamespace(
        use_mock_vision=False,
        vision_model="test-vision",
        vision_model_name="test-vision",
    )


def _exercise(slug: str, name_zh: str):
    return SimpleNamespace(
        slug=slug,
        name_zh=name_zh,
        muscle_group="legs",
        equipment="machine",
        difficulty=2,
        video_url=None,
    )


def test_catalog_equipment_maps_to_active_exercises(monkeypatch):
    async def fake_vision(system, user, image, mime="image/jpeg", **kwargs):
        return _vision_result()

    monkeypatch.setattr(equipment, "settings", _settings())
    monkeypatch.setattr(equipment.llm, "complete_vision_json", fake_vision)
    monkeypatch.setattr(
        equipment,
        "_active_exercises",
        lambda db: [_exercise("cm_leg_press", "腿举")],
    )

    result = asyncio.run(
        equipment.recognize(None, b"not-a-real-image", "x.jpg")
    )

    assert result["status"] == "ok"
    assert result["equipment_slug"] == "leg_press"
    assert result["equipment_name"] == "腿举机"
    assert result["candidates"][0]["slug"] == "cm_leg_press"
    assert result["not_in_library"] is False


def test_unknown_equipment_returns_custom_add_signal(monkeypatch):
    async def fake_vision(system, user, image, mime="image/jpeg", **kwargs):
        return _vision_result(
            is_gym_equipment=False,
            equipment_slug="unknown",
            equipment_name="未知",
            exercise_slugs=[],
            description="这不是健身器械。",
        )

    monkeypatch.setattr(equipment, "settings", _settings())
    monkeypatch.setattr(equipment.llm, "complete_vision_json", fake_vision)

    result = asyncio.run(
        equipment.recognize(None, b"not-a-real-image", "x.jpg")
    )

    assert result["status"] == "not_gym_equipment"
    assert result["candidates"] == []
    assert result["not_in_library"] is False


def test_catalog_equipment_without_actions_is_not_in_library(monkeypatch):
    async def fake_vision(system, user, image, mime="image/jpeg", **kwargs):
        return _vision_result(
            equipment_slug="torso_rotation",
            equipment_name="转体机",
            exercise_slugs=[],
        )

    monkeypatch.setattr(equipment, "settings", _settings())
    monkeypatch.setattr(equipment.llm, "complete_vision_json", fake_vision)
    monkeypatch.setattr(equipment, "_active_exercises", lambda db: [])

    result = asyncio.run(
        equipment.recognize(None, b"not-a-real-image", "x.jpg")
    )

    assert result["status"] == "no_actions"
    assert result["not_in_library"] is True
    assert result["candidates"] == []
    assert result["name"] == "转体机"


def test_vision_failure_never_returns_random_candidates(monkeypatch):
    async def failing_vision(*args, **kwargs):
        raise RuntimeError("vision HTTP 400")

    monkeypatch.setattr(equipment, "settings", _settings())
    monkeypatch.setattr(equipment.llm, "complete_vision_json", failing_vision)

    result = asyncio.run(
        equipment.recognize(None, b"not-a-real-image", "x.jpg")
    )

    assert result["status"] == "unavailable"
    assert result["candidates"] == []
    assert result["warning"]
