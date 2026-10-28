import asyncio

from app.services.coach_vision import review


def test_review_without_image_returns_honest_fallback():
    result = asyncio.run(review(b""))
    assert result["is_training"] is False
    assert result["observations"] == []
    assert "没有收到图片" in result["warning"]
