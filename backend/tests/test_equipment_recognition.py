import asyncio
from types import SimpleNamespace

from app.services import equipment


def test_unmatched_equipment_returns_custom_add_signal(monkeypatch):
    async def fake_vision(system, user, image, mime="image/jpeg"):
        return {
            "description": "a machine not in the current library",
            "equipment": "machine",
            "name": "hip_abduction",
            "confidence": 0.88,
        }

    monkeypatch.setattr(
        equipment,
        "settings",
        SimpleNamespace(use_mock_vision=False, vision_model="test-vision"),
    )
    monkeypatch.setattr(equipment.llm, "complete_vision_json", fake_vision)
    monkeypatch.setattr(
        equipment,
        "_active_exercises",
        lambda db: [
            SimpleNamespace(
                slug="leg_press",
                name_zh="leg press",
                muscle_group="legs",
                equipment="machine",
                difficulty=2,
                video_url=None,
            )
        ],
    )

    result = asyncio.run(equipment.recognize(None, b"not-a-real-image", "x.jpg"))

    assert result["not_in_library"] is True
    assert result["candidates"] == []
    assert result["name"] == "hip_abduction"
