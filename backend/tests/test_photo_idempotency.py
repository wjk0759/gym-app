import asyncio
import io
from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException, UploadFile
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import EquipmentScan, User, UserEntitlement
from app.routers import body, equipment
from app.services import photo_cache


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    session = SessionLocal()
    session.add(User(id="photo-user", phone="13800138011", status="active"))
    now = datetime.now(timezone.utc)
    session.add(
        UserEntitlement(
            user_id="photo-user",
            plan_code="pro",
            source="admin",
            source_ref="photo-test",
            starts_at=now,
            expires_at=now + timedelta(days=1),
        )
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def _upload(data: bytes = b"image-bytes", name: str = "photo.jpg") -> UploadFile:
    return UploadFile(
        file=io.BytesIO(data),
        filename=name,
        headers={"content-type": "image/jpeg"},
    )


def test_cache_hit_is_scoped_by_idempotency_key(db):
    now = datetime.now(timezone.utc)
    photo_cache.store_cached_result(
        db, "photo-user", "body_photo", "key-1", {"summary": "ok"}, now=now
    )

    assert photo_cache.get_cached_result(
        db, "photo-user", "body_photo", "key-1", now=now
    ) == {"summary": "ok"}
    assert photo_cache.get_cached_result(
        db, "photo-user", "body_photo", "key-2", now=now
    ) is None


def test_expired_cache_entry_is_not_replayed(db):
    now = datetime.now(timezone.utc)
    photo_cache.store_cached_result(
        db,
        "photo-user",
        "body_photo",
        "expiring",
        {"summary": "old"},
        ttl_seconds=1,
        now=now,
    )

    assert photo_cache.get_cached_result(
        db,
        "photo-user",
        "body_photo",
        "expiring",
        now=now + timedelta(seconds=2),
    ) is None


def test_expired_cache_rows_are_cleaned_on_write(db):
    now = datetime.now(timezone.utc)
    photo_cache.store_cached_result(
        db,
        "photo-user",
        "body_photo",
        "old-key",
        {"summary": "old"},
        ttl_seconds=1,
        now=now,
    )

    removed = photo_cache.cleanup_expired(
        db, now=now + timedelta(seconds=2)
    )

    assert removed == 1
    assert photo_cache.get_cached_result(
        db, "photo-user", "body_photo", "old-key"
    ) is None


def test_body_analysis_replays_without_calling_vision_again(db, monkeypatch):
    calls = 0

    async def fake_analyze(data, filename, **kwargs):
        nonlocal calls
        calls += 1
        return {"summary": "腰背稳定", "focus_areas": [], "recommendations": []}

    monkeypatch.setattr(body, "analyze", fake_analyze)

    first = asyncio.run(
        body.analyze_body(
            "photo-user",
            db,
            _upload(),
            idempotency_key="body-key",
        )
    )
    second = asyncio.run(
        body.analyze_body(
            "photo-user",
            db,
            _upload(),
            idempotency_key="body-key",
        )
    )

    assert first == second
    assert calls == 1


def test_free_user_still_gets_403_even_with_cached_result(db):
    now = datetime.now(timezone.utc)
    db.query(UserEntitlement).delete()
    db.commit()
    photo_cache.store_cached_result(
        db,
        "photo-user",
        "body_photo",
        "free-key",
        {"summary": "must not leak"},
        now=now,
    )

    with pytest.raises(HTTPException) as exc:
        asyncio.run(
            body.analyze_body(
                "photo-user",
                db,
                _upload(),
                idempotency_key="free-key",
            )
        )

    assert exc.value.status_code == 403


def test_equipment_scan_replays_without_creating_duplicate_scan(db, monkeypatch):
    calls = 0

    async def fake_recognize(db_session, data, filename, **kwargs):
        nonlocal calls
        calls += 1
        return {
            "scan_id": "engine-id",
            "candidates": [{"slug": "leg_press", "name_zh": "腿举", "confidence": 0.9}],
            "needs_confirmation": False,
            "not_in_library": False,
            "name": "腿举机",
            "description": "一台腿举机",
            "model": "test",
            "image_name": filename,
        }

    monkeypatch.setattr(equipment, "recognize", fake_recognize)

    first = asyncio.run(
        equipment.scan(
            "photo-user",
            db,
            _upload(),
            idempotency_key="scan-key",
        )
    )
    second = asyncio.run(
        equipment.scan(
            "photo-user",
            db,
            _upload(),
            idempotency_key="scan-key",
        )
    )

    assert first["scan_id"] == second["scan_id"]
    assert calls == 1
    assert db.query(EquipmentScan).count() == 1
