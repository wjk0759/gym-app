"""Private body-analysis history and photo storage.

Photos are written under ``settings.private_media_root`` and are never exposed
by the public ``/media`` StaticFiles mount. The API serves them through an
owner-checked endpoint.
"""

from __future__ import annotations

import io
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..media import BODY_PHOTO_DIR, PRIVATE_MEDIA_ROOT
from ..models import BodyAnalysisRecord, utcnow

MAX_SOURCE_PIXELS = 20_000_000
MAX_IMAGE_EDGE = 1600
THUMB_EDGE = 400


def _error(message: str) -> ValueError:
    return ValueError(message)


def _to_rgb(image: Image.Image) -> Image.Image:
    if image.mode in {"RGBA", "LA"} or (
        image.mode == "P" and "transparency" in image.info
    ):
        rgba = image.convert("RGBA")
        background = Image.new("RGB", rgba.size, (255, 255, 255))
        background.paste(rgba, mask=rgba.getchannel("A"))
        return background
    return image.convert("RGB")


def _encode(image: Image.Image, max_edge: int) -> bytes:
    value = image.copy()
    value.thumbnail((max_edge, max_edge), Image.Resampling.LANCZOS)
    output = io.BytesIO()
    value.save(output, format="JPEG", quality=86, optimize=True)
    return output.getvalue()


def prepare_photo(data: bytes) -> tuple[bytes, bytes]:
    try:
        with Image.open(io.BytesIO(data)) as source:
            if source.width * source.height > MAX_SOURCE_PIXELS:
                raise _error("图片尺寸过大")
            image = _to_rgb(ImageOps.exif_transpose(source))
            return _encode(image, MAX_IMAGE_EDGE), _encode(image, THUMB_EDGE)
    except _error:
        raise
    except (
        UnidentifiedImageError,
        Image.DecompressionBombError,
        OSError,
        ValueError,
    ) as exc:
        raise _error("图片格式不支持或已损坏") from exc


def _photo_dir(user_id: str, client_id: str) -> Path:
    return BODY_PHOTO_DIR / user_id / client_id


def _write_photos(user_id: str, client_id: str, data: bytes) -> tuple[str, str]:
    photo, thumb = prepare_photo(data)
    directory = _photo_dir(user_id, client_id)
    directory.mkdir(parents=True, exist_ok=True)
    image_path = directory / "original.jpg"
    thumb_path = directory / "thumb.jpg"
    image_path.write_bytes(photo)
    thumb_path.write_bytes(thumb)
    prefix = BODY_PHOTO_DIR.relative_to(PRIVATE_MEDIA_ROOT)
    return (
        str(prefix / user_id / client_id / "original.jpg"),
        str(prefix / user_id / client_id / "thumb.jpg"),
    )


def photo_path(key: str | None) -> Path | None:
    if not key:
        return None
    path = (PRIVATE_MEDIA_ROOT / key).resolve()
    try:
        path.relative_to(BODY_PHOTO_DIR.resolve())
    except ValueError:
        return None
    return path if path.exists() else None


def analysis_dict(item: BodyAnalysisRecord) -> dict:
    return {
        "client_id": item.client_id,
        "created_at": item.created_at.isoformat(),
        "updated_at": item.updated_at.isoformat(),
        "summary": item.summary,
        "focus_areas": item.focus_areas or [],
        "recommendations": item.recommendations or [],
        "confidence": item.confidence,
        "disclaimer": item.disclaimer,
        "safety_flag": item.safety_flag,
        "model": item.model,
        "applied_to_plan": item.applied_to_plan,
        "has_photo": bool(item.image_key),
    }


def list_analyses(db: Session, user_id: str, limit: int = 50) -> list[dict]:
    rows = (
        db.execute(
            select(BodyAnalysisRecord)
            .where(
                BodyAnalysisRecord.user_id == user_id,
                BodyAnalysisRecord.deleted_at.is_(None),
            )
            .order_by(BodyAnalysisRecord.created_at.desc())
            .limit(max(1, min(100, limit)))
        )
        .scalars()
        .all()
    )
    return [analysis_dict(item) for item in rows]


def save_analysis(
    db: Session,
    user_id: str,
    client_id: str,
    result: dict,
    image_bytes: bytes | None,
) -> BodyAnalysisRecord:
    item = db.execute(
        select(BodyAnalysisRecord).where(
            BodyAnalysisRecord.user_id == user_id,
            BodyAnalysisRecord.client_id == client_id,
        )
    ).scalar_one_or_none()
    if item is None:
        item = BodyAnalysisRecord(
            user_id=user_id,
            client_id=client_id,
            summary="",
        )
        db.add(item)
    item.summary = str(result.get("summary") or "")[:4000]
    item.focus_areas = list(result.get("focus_areas") or [])
    item.recommendations = list(result.get("recommendations") or [])
    item.confidence = result.get("confidence")
    item.disclaimer = str(result.get("disclaimer") or "")
    item.safety_flag = result.get("safety_flag")
    item.model = result.get("model")
    item.deleted_at = None
    item.updated_at = utcnow()
    if image_bytes:
        image_key, thumb_key = _write_photos(user_id, client_id, image_bytes)
        item.image_key = image_key
        item.thumbnail_key = thumb_key
    db.commit()
    db.refresh(item)
    return item


def mark_applied(
    db: Session, user_id: str, client_id: str, applied: bool
) -> dict | None:
    item = db.execute(
        select(BodyAnalysisRecord).where(
            BodyAnalysisRecord.user_id == user_id,
            BodyAnalysisRecord.client_id == client_id,
            BodyAnalysisRecord.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if item is None:
        return None
    item.applied_to_plan = applied
    item.updated_at = utcnow()
    db.commit()
    db.refresh(item)
    return analysis_dict(item)


def delete_analysis(db: Session, user_id: str, client_id: str) -> bool:
    item = db.execute(
        select(BodyAnalysisRecord).where(
            BodyAnalysisRecord.user_id == user_id,
            BodyAnalysisRecord.client_id == client_id,
            BodyAnalysisRecord.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if item is None:
        return False
    item.deleted_at = datetime.now(timezone.utc)
    item.image_key = None
    item.thumbnail_key = None
    directory = _photo_dir(user_id, client_id)
    if directory.exists():
        for child in directory.iterdir():
            child.unlink(missing_ok=True)
        directory.rmdir()
    db.commit()
    return True


def delete_user_photos(user_id: str) -> None:
    directory = BODY_PHOTO_DIR / user_id
    if not directory.exists():
        return
    for child in directory.rglob("*"):
        if child.is_file():
            child.unlink(missing_ok=True)
    for child in sorted(directory.rglob("*"), reverse=True):
        if child.is_dir():
            child.rmdir()
    directory.rmdir()


def ensure_private_dirs() -> None:
    BODY_PHOTO_DIR.mkdir(parents=True, exist_ok=True)
