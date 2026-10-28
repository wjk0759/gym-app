import asyncio
from types import SimpleNamespace

from app.services import coach_vision
from app.services.coach_vision import review


def test_review_without_image_returns_honest_fallback():
    result = asyncio.run(review(b""))
    assert result["is_training"] is False
    assert result["observations"] == []
    assert result["mode"] == "general"
    assert "没有收到图片" in result["warning"]


def test_food_question_is_not_forced_into_training_review(monkeypatch):
    async def fake_vision(system, user, image, mime="image/jpeg"):
        return {
            "mode": "training",
            "is_training": True,
            "summary": "图片里是分装好的榴莲果肉。",
            "observations": ["大约 5 块，热量需要按重量估算。"],
            "next_cue": "收紧核心，保持背部中立。",
            "safety_flag": None,
        }

    monkeypatch.setattr(
        coach_vision,
        "settings",
        SimpleNamespace(use_mock_vision=False),
    )
    monkeypatch.setattr(coach_vision.llm, "complete_vision_json", fake_vision)

    result = asyncio.run(review(b"durian", "这个榴莲热量有多少？"))

    assert result["mode"] == "nutrition"
    assert result["is_training"] is False
    assert result["next_cue"] == ""
    assert "榴莲" in result["summary"]


def test_vision_response_stays_compact(monkeypatch):
    async def fake_vision(system, user, image, mime="image/jpeg"):
        return {
            "mode": "nutrition",
            "is_training": False,
            "summary": "很长的总结" * 80,
            "observations": ["很长的观察" * 20 for _ in range(5)],
            "next_cue": None,
            "safety_flag": None,
        }

    monkeypatch.setattr(
        coach_vision,
        "settings",
        SimpleNamespace(use_mock_vision=False),
    )
    monkeypatch.setattr(coach_vision.llm, "complete_vision_json", fake_vision)

    result = asyncio.run(review(b"food", "这是什么？"))

    assert len(result["summary"]) <= 240
    assert len(result["observations"]) == 3
    assert all(len(item) <= 80 for item in result["observations"])


def test_training_question_keeps_training_mode(monkeypatch):
    async def fake_vision(system, user, image, mime="image/jpeg"):
        return {
            "mode": "training",
            "is_training": True,
            "summary": "深蹲底部膝盖轻微内扣。",
            "observations": ["脚掌还稳，动作幅度可以。"],
            "next_cue": "起身时把膝盖对准脚尖。",
            "safety_flag": None,
        }

    monkeypatch.setattr(
        coach_vision,
        "settings",
        SimpleNamespace(use_mock_vision=False),
    )
    monkeypatch.setattr(coach_vision.llm, "complete_vision_json", fake_vision)

    result = asyncio.run(review(b"squat", "看看我的深蹲动作标准吗"))

    assert result["mode"] == "training"
    assert result["is_training"] is True
    assert result["next_cue"] == "起身时把膝盖对准脚尖。"
