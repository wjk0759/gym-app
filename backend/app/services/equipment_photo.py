from __future__ import annotations

import io
import secrets
from pathlib import Path

from fastapi import HTTPException, UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError

from ..media import EQUIPMENT_DIR, public_media_url

try:  # HEIC/HEIF from older iPhone uploads.
    from pillow_heif import register_heif_opener

    register_heif_opener()
except ImportError:  # pragma: no cover - optional deployment dependency
    pass

MAX_EQUIPMENT_PHOTO_BYTES = 8 * 1024 * 1024
MAX_SOURCE_PIXELS = 30_000_000
MAX_EDGE = 1600
JPEG_QUALITY = 85
ALLOWED_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif",
}
EQUIPMENT_PHOTO_URL_PREFIX = "/media/equipment/"


def _error(status_code: int, code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=status_code,
        detail={"code": code, "message": message},
    )


async def read_upload(file: UploadFile) -> bytes:
    content_type = (file.content_type or "").lower()
    if content_type not in ALLOWED_TYPES:
        raise _error(415, "EQUIPMENT_PHOTO_UNSUPPORTED_TYPE", "仅支持 JPEG/PNG/WebP/HEIC 图片")
    data = await file.read()
    if not data:
        raise _error(400, "EQUIPMENT_PHOTO_EMPTY", "图片为空")
    if len(data) > MAX_EQUIPMENT_PHOTO_BYTES:
        raise _error(413, "EQUIPMENT_PHOTO_TOO_LARGE", "器械照片不能超过 8MB")
    return data


def _to_rgb(image: Image.Image) -> Image.Image:
    if image.mode in {"RGBA", "LA"} or (
        image.mode == "P" and "transparency" in image.info
    ):
        rgba = image.convert("RGBA")
        background = Image.new("RGB", rgba.size, (255, 255, 255))
        background.paste(rgba, mask=rgba.getchannel("A"))
        return background
    return image.convert("RGB")


def process(data: bytes) -> bytes:
    """Validate, orient, downscale and re-encode an equipment photo.

    Re-encoding strips EXIF/GPS metadata before the file is stored under the
    public media path.
    """
    try:
        with Image.open(io.BytesIO(data)) as source:
            if source.width * source.height > MAX_SOURCE_PIXELS:
                raise _error(413, "EQUIPMENT_PHOTO_TOO_LARGE", "图片尺寸过大")
            image = ImageOps.exif_transpose(source)
            image = _to_rgb(image)
            image.thumbnail((MAX_EDGE, MAX_EDGE), Image.Resampling.LANCZOS)
            output = io.BytesIO()
            image.save(output, format="JPEG", quality=JPEG_QUALITY, optimize=True)
            return output.getvalue()
    except HTTPException:
        raise
    except (
        UnidentifiedImageError,
        Image.DecompressionBombError,
        OSError,
        ValueError,
    ) as exc:
        raise _error(
            400,
            "EQUIPMENT_PHOTO_DECODE_FAILED",
            "无法识别这张图片，请换一张",
        ) from exc


def save(user_id: str, data: bytes) -> str:
    EQUIPMENT_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{user_id}-{secrets.token_hex(8)}.jpg"
    (EQUIPMENT_DIR / filename).write_bytes(data)
    return f"{EQUIPMENT_PHOTO_URL_PREFIX}{filename}"


def delete_local(value: str | None) -> None:
    """Best-effort removal of a previously stored local equipment photo."""
    if not value:
        return
    path = value.split("?", 1)[0]
    if not path.startswith(EQUIPMENT_PHOTO_URL_PREFIX):
        return
    filename = Path(path).name
    if not filename:
        return
    (EQUIPMENT_DIR / filename).unlink(missing_ok=True)


def public_url(value: str | None) -> str | None:
    return public_media_url(value)
