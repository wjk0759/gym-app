"""Media upload contract tests for coach photos and video keyframes.

Video is not uploaded as a movie: iOS extracts ordered keyframes and sends them
to the batch endpoint. These tests cover that contract, the size limits, and
the clear rejection when a video file is posted to the image endpoint.
"""

import asyncio
import io

import pytest
from fastapi import HTTPException, UploadFile
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import Profile, User
from app.routers import coach


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    session = Session()
    session.add(User(id="media-user"))
    session.add(
        Profile(
            user_id="media-user",
            nickname="小林",
            sex="male",
            height_cm=178,
            weight_kg=72,
            onboarded_at=None,
        )
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _upload(data: bytes, content_type: str = "image/jpeg", name: str = "photo.jpg"):
    return UploadFile(
        file=io.BytesIO(data),
        filename=name,
        headers={"content-type": content_type},
    )


def _vision_result():
    return {
        "mode": "training",
        "is_training": True,
        "summary": "深蹲底部膝盖轻微内扣。",
        "observations": ["脚掌稳定", "下蹲深度可以"],
        "next_cue": "起身时把膝盖对准脚尖。",
        "safety_flag": None,
        "warning": None,
    }


def test_photo_endpoint_rejects_video_file(db):
    upload = _upload(b"not-a-real-video", "video/mp4", "squat.mp4")
    with pytest.raises(HTTPException) as exc:
        asyncio.run(coach.vision("media-user", db, upload, question="", session_id=None))
    assert exc.value.status_code == 415
    assert "关键帧" in exc.value.detail


def test_photo_endpoint_rejects_empty_file(db):
    with pytest.raises(HTTPException) as exc:
        asyncio.run(coach.vision("media-user", db, _upload(b""), question="", session_id=None))
    assert exc.value.status_code == 400


def test_photo_endpoint_rejects_oversize_file(db):
    data = b"x" * (coach.MAX_VISION_FILE_BYTES + 1)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(coach.vision("media-user", db, _upload(data), question="", session_id=None))
    assert exc.value.status_code == 413


def test_batch_endpoint_rejects_more_than_six_files(db):
    files = [_upload(b"frame") for _ in range(coach.MAX_VISION_FILES + 1)]
    with pytest.raises(HTTPException) as exc:
        asyncio.run(coach.vision_batch("media-user", db, files, question="", session_id=None))
    assert exc.value.status_code == 413
    assert "6" in exc.value.detail


def test_batch_endpoint_rejects_total_size_over_24mb(db):
    chunk = b"x" * (5 * 1024 * 1024)
    files = [_upload(chunk) for _ in range(5)]
    with pytest.raises(HTTPException) as exc:
        asyncio.run(coach.vision_batch("media-user", db, files, question="", session_id=None))
    assert exc.value.status_code == 413
    assert "24MB" in exc.value.detail


def test_batch_accepts_six_video_keyframes(db, monkeypatch):
    async def fake_review_many(
        images,
        question="",
        safety_context=None,
        conversation_context=None,
    ):
        assert len(images) == 6
        assert question == "看看我深蹲的动作"
        return _vision_result()

    monkeypatch.setattr(coach.coach_vision, "review_many", fake_review_many)

    files = [_upload(b"frame", name=f"frame-{index}.jpg") for index in range(6)]
    result = asyncio.run(
        coach.vision_batch(
            "media-user",
            db,
            files,
            question="看看我深蹲的动作",
            session_id=None,
        )
    )

    assert result["session_id"]
    assert result["summary"] == "深蹲底部膝盖轻微内扣。"
    assert result["next_cue"] == "起身时把膝盖对准脚尖。"


def test_single_photo_still_works(db, monkeypatch):
    async def fake_review(
        image,
        question="",
        safety_context=None,
        conversation_context=None,
    ):
        assert image == b"jpeg"
        return _vision_result()

    monkeypatch.setattr(coach.coach_vision, "review", fake_review)

    result = asyncio.run(
        coach.vision(
            "media-user",
            db,
            _upload(b"jpeg"),
            question="看看动作",
            session_id=None,
        )
    )
    assert result["mode"] == "training"
    assert result["is_training"] is True
