from __future__ import annotations

import io

import pytest
from PIL import Image
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import User
from app.services import body_analysis_store


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
    session.add(User(id="user-1", phone="13428104171", status="active"))
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _jpeg() -> bytes:
    output = io.BytesIO()
    Image.new("RGB", (1200, 1600), (160, 120, 100)).save(
        output, format="JPEG", quality=90
    )
    return output.getvalue()


def test_body_analysis_is_private_and_lifecycle(db, tmp_path, monkeypatch):
    private_root = tmp_path / "private"
    photo_root = private_root / "body"
    monkeypatch.setattr(body_analysis_store, "PRIVATE_MEDIA_ROOT", private_root)
    monkeypatch.setattr(body_analysis_store, "BODY_PHOTO_DIR", photo_root)

    item = body_analysis_store.save_analysis(
        db,
        "user-1",
        "analysis-1",
        {
            "summary": "整体比例均衡",
            "focus_areas": ["back", "glutes"],
            "recommendations": ["增加一次背部训练"],
            "confidence": 0.8,
            "disclaimer": "仅供参考",
            "model": "test",
        },
        _jpeg(),
    )
    image_key = item.image_key
    assert image_key
    assert (private_root / image_key).exists()
    assert (private_root / item.thumbnail_key).exists()

    rows = body_analysis_store.list_analyses(db, "user-1")
    assert rows[0]["focus_areas"] == ["back", "glutes"]
    assert rows[0]["has_photo"] is True

    full = body_analysis_store.photo_for(db, "user-1", "analysis-1")
    thumb = body_analysis_store.photo_for(db, "user-1", "analysis-1", thumbnail=True)
    assert full is not None and full.name == "original.jpg"
    assert thumb is not None and thumb.name == "thumb.jpg"
    assert body_analysis_store.photo_for(db, "user-2", "analysis-1") is None

    applied = body_analysis_store.mark_applied(
        db, "user-1", "analysis-1", True
    )
    assert applied is not None
    assert applied["applied_to_plan"] is True

    assert body_analysis_store.delete_analysis(db, "user-1", "analysis-1")
    assert body_analysis_store.list_analyses(db, "user-1") == []
    assert not (private_root / image_key).exists()


def test_body_analysis_photo_path_rejects_escape(db, tmp_path, monkeypatch):
    private_root = tmp_path / "private"
    monkeypatch.setattr(body_analysis_store, "PRIVATE_MEDIA_ROOT", private_root)
    monkeypatch.setattr(
        body_analysis_store, "BODY_PHOTO_DIR", private_root / "body"
    )
    assert body_analysis_store.photo_path("../users/other.jpg") is None
    assert body_analysis_store.photo_path(None) is None
