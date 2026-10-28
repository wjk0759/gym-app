import asyncio
from types import SimpleNamespace

from app.routers.coach import _vision_history_text
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


def test_vision_prompt_allows_visible_estimate_with_limits():
    assert "视觉区间" in coach_vision.SYSTEM_PROMPT
    assert "视觉估算" in coach_vision.SYSTEM_PROMPT
    assert "不是训练动作" in coach_vision.SYSTEM_PROMPT
    assert "先回答" in coach_vision.USER_PROMPT


def test_vision_history_is_text_only_and_compact():
    text = _vision_history_text(
        {
            "summary": "能看到人物上半身，坐姿和衣着限制了体脂判断。",
            "observations": ["室内办公桌前", "怀里抱着一只猫", "只能看到上半身"],
            "next_cue": "收紧核心",
        }
    )

    assert "能看到人物上半身" in text
    assert "可见：" in text
    assert "猫" in text
    assert "提示：" in text
    assert len(text) <= 4000


def test_conversation_context_reaches_vision_prompt(monkeypatch):
    captured: dict[str, str] = {}

    async def fake_vision(system, user, image, mime="image/jpeg"):
        captured["prompt"] = user
        return {
            "mode": "body",
            "is_training": False,
            "summary": "只看到上半身，体脂只能粗略估。",
            "observations": ["人物坐在桌前"],
            "next_cue": None,
            "safety_flag": None,
        }

    monkeypatch.setattr(
        coach_vision,
        "settings",
        SimpleNamespace(use_mock_vision=False),
    )
    monkeypatch.setattr(coach_vision.llm, "complete_vision_json", fake_vision)

    asyncio.run(
        review(
            b"person",
            "图中人物体脂率多少？",
            conversation_context="用户：她体脂率多少？\n助手：能看到人物。",
        )
    )

    assert "图中人物体脂率多少" in captured["prompt"]
    assert "前文" in captured["prompt"]
    assert "助手：能看到人物" in captured["prompt"]


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
