import asyncio
import json
from pathlib import Path
from types import SimpleNamespace

from app.models import EquipmentType
from app.services import equipment


def _fake_type(
    slug: str,
    name_zh: str,
    group: str = "leg_press",
    name_en: str | None = None,
    aliases: list[str] | None = None,
) -> EquipmentType:
    return EquipmentType(
        slug=slug,
        name_zh=name_zh,
        name_en=name_en or name_zh,
        category="machine",
        exercise_group=group,
        universal=False,
        aliases=aliases or [],
        recognition_class=0,
        is_active=True,
    )


def _patch_catalog(monkeypatch, types, mapping):
    monkeypatch.setattr(
        equipment, "catalog_types", lambda db, recognition_only=False: types
    )
    monkeypatch.setattr(
        equipment,
        "catalog_get",
        lambda db, slug: next((t for t in types if t.slug == slug), None),
    )
    monkeypatch.setattr(
        equipment,
        "catalog_exercises",
        lambda db, item: mapping.get(item.slug, []),
    )


def _vision_result(**overrides):
    result = {
        "is_gym_equipment": True,
        "equipment_slug": "leg_press",
        "equipment_name": "腿举机",
        "confidence": 0.92,
        "visible_features": ["斜靠背", "脚踏板", "挂片杆"],
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


def _exercise(slug: str, name_zh: str, is_compound: bool = True):
    return SimpleNamespace(
        slug=slug,
        name_zh=name_zh,
        muscle_group="legs",
        equipment="machine",
        difficulty=2,
        is_compound=is_compound,
        video_url=None,
        plan_eligible=True,
    )


def test_catalog_equipment_maps_to_active_exercises(monkeypatch):
    async def fake_vision(system, user, image, mime="image/jpeg", **kwargs):
        return _vision_result()

    types = [_fake_type("leg_press", "腿举机")]
    _patch_catalog(monkeypatch, types, {"leg_press": ["vital-leg-press"]})
    monkeypatch.setattr(equipment, "settings", _settings())
    monkeypatch.setattr(equipment.llm, "complete_vision_json", fake_vision)
    monkeypatch.setattr(
        equipment,
        "_active_exercises",
        lambda db: [_exercise("vital-leg-press", "腿举")],
    )

    result = asyncio.run(
        equipment.recognize(None, b"not-a-real-image", "x.jpg")
    )

    assert result["status"] == "ok"
    assert result["equipment_slug"] == "leg_press"
    assert result["equipment_name"] == "腿举机"
    assert result["candidates"][0]["slug"] == "vital-leg-press"
    assert result["not_in_library"] is False


def test_unknown_equipment_returns_custom_add_signal(monkeypatch):
    async def fake_vision(system, user, image, mime="image/jpeg", **kwargs):
        return _vision_result(
            is_gym_equipment=False,
            equipment_slug="unknown",
            equipment_name="未知",
            description="这不是健身器械。",
        )

    _patch_catalog(monkeypatch, [_fake_type("leg_press", "腿举机")], {})
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
            equipment_slug="tibialis_raise",
            equipment_name="胫骨前肌训练机",
        )

    types = [_fake_type("tibialis_raise", "胫骨前肌训练机", group="tibialis")]
    _patch_catalog(monkeypatch, types, {})
    monkeypatch.setattr(equipment, "settings", _settings())
    monkeypatch.setattr(equipment.llm, "complete_vision_json", fake_vision)
    monkeypatch.setattr(equipment, "_active_exercises", lambda db: [])

    result = asyncio.run(
        equipment.recognize(None, b"not-a-real-image", "x.jpg")
    )

    assert result["status"] == "no_actions"
    assert result["not_in_library"] is True
    assert result["candidates"] == []
    assert result["name"] == "胫骨前肌训练机"


def test_vision_failure_never_returns_random_candidates(monkeypatch):
    async def failing_vision(*args, **kwargs):
        raise RuntimeError("vision HTTP 400")

    _patch_catalog(monkeypatch, [_fake_type("leg_press", "腿举机")], {})
    monkeypatch.setattr(equipment, "settings", _settings())
    monkeypatch.setattr(equipment.llm, "complete_vision_json", failing_vision)

    result = asyncio.run(
        equipment.recognize(None, b"not-a-real-image", "x.jpg")
    )

    assert result["status"] == "unavailable"
    assert result["candidates"] == []
    assert result["warning"]


def test_two_close_equipment_candidates_are_returned(monkeypatch):
    async def fake_vision(system, user, image, mime="image/jpeg", **kwargs):
        return _vision_result(
            equipment_slug="chest_press_seated",
            equipment_name="坐姿推胸机",
            confidence=0.78,
            equipment_candidates=[
                {"slug": "chest_press_seated", "confidence": 0.78},
                {"slug": "shoulder_press", "confidence": 0.66},
            ],
        )

    types = [
        _fake_type("chest_press_seated", "坐姿推胸机", group="chest_press"),
        _fake_type("shoulder_press", "坐姿推肩机", group="shoulder_press"),
    ]
    _patch_catalog(
        monkeypatch,
        types,
        {
            "chest_press_seated": ["vital-seated-machine-chest-press"],
            "shoulder_press": ["vital-seated-shoulder-press-machine"],
        },
    )
    monkeypatch.setattr(equipment, "settings", _settings())
    monkeypatch.setattr(equipment.llm, "complete_vision_json", fake_vision)
    monkeypatch.setattr(
        equipment,
        "_active_exercises",
        lambda db: [
            _exercise("vital-seated-machine-chest-press", "器械推胸"),
            _exercise("vital-seated-shoulder-press-machine", "器械推举"),
        ],
    )

    result = asyncio.run(
        equipment.recognize(None, b"not-a-real-image", "x.jpg")
    )

    assert result["status"] == "ok"
    assert len(result["equipment_candidates"]) == 2
    assert result["needs_confirmation"] is True


def test_ocr_text_is_included_and_matched_to_catalog(monkeypatch):
    captured = {}

    async def fake_vision(system, user, image, mime="image/jpeg", **kwargs):
        captured["user"] = user
        return _vision_result()

    types = [
        _fake_type(
            "shoulder_press",
            "坐姿推肩机",
            group="shoulder_press",
            name_en="Seated Shoulder Press",
            aliases=["Hammer Strength Shoulder Press"],
        )
    ]
    _patch_catalog(monkeypatch, types, {"shoulder_press": ["vital-seated-shoulder-press-machine"]})
    monkeypatch.setattr(equipment, "settings", _settings())
    monkeypatch.setattr(equipment.llm, "complete_vision_json", fake_vision)
    monkeypatch.setattr(
        equipment,
        "_active_exercises",
        lambda db: [_exercise("vital-seated-shoulder-press-machine", "器械推举")],
    )

    asyncio.run(
        equipment.recognize(
            None,
            b"not-a-real-image",
            "x.jpg",
            ocr_text="HAMMER STRENGTH SHOULDER PRESS",
        )
    )

    assert "HAMMER STRENGTH SHOULDER PRESS" in captured["user"]
    assert "shoulder_press" in captured["user"]


def test_catalog_actions_exist_in_active_library():
    root = Path(__file__).resolve().parents[2]
    mapping = json.loads(
        (root / "data" / "vital" / "equipment_exercise_map.json").read_text(
            encoding="utf-8"
        )
    )["mapping"]
    rows = json.loads(
        (root / "ios" / "FitAI" / "Resources" / "vital_exercises.json").read_text(
            encoding="utf-8"
        )
    )
    active = {row["slug"] for row in rows}
    missing = {
        slug
        for slugs in mapping.values()
        for slug in slugs
        if slug not in active
    }

    assert not missing, sorted(missing)
