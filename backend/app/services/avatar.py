from __future__ import annotations

import io
import secrets
from pathlib import Path

from fastapi import HTTPException, UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError

from ..media import AVATAR_DIR, public_media_url

MAX_AVATAR_BYTES = 8 * 1024 * 1024
MAX_SOURCE_PIXELS = 20_000_000
AVATAR_SIZE = 512
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
AVATAR_URL_PREFIX = "/media/avatars/"


def _error(status_code: int, code: str, message: str) -> HTTPException:
    return HTTPException(
        status_code=status_code,
        detail={"code": code, "message": message},
    )


async def read_avatar_upload(file: UploadFile) -> bytes:
    if file.content_type not in ALLOWED_TYPES:
        raise _error(415, "AVATAR_UNSUPPORTED_TYPE", "仅支持 JPEG/PNG/WebP 图片")
    data = await file.read()
    if not data:
        raise _error(400, "AVATAR_EMPTY", "图片为空")
    if len(data) > MAX_AVATAR_BYTES:
        raise _error(413, "AVATAR_TOO_LARGE", "头像不能超过 8MB")
    return data


def _to_rgb(image: Image.Image) -> Image.Image:
    """Flatten transparency onto white instead of Pillow's default black."""
    if image.mode in {"RGBA", "LA"} or (
        image.mode == "P" and "transparency" in image.info
    ):
        rgba = image.convert("RGBA")
        background = Image.new("RGB", rgba.size, (255, 255, 255))
        background.paste(rgba, mask=rgba.getchannel("A"))
        return background
    return image.convert("RGB")


def process_avatar(data: bytes) -> bytes:
    """Validate, square-crop, resize and re-encode an uploaded avatar.

    Re-encoding strips EXIF/GPS metadata before the file is stored under the
    public media path.
    """
    try:
        with Image.open(io.BytesIO(data)) as source:
            if source.width * source.height > MAX_SOURCE_PIXELS:
                raise _error(413, "AVATAR_TOO_LARGE", "图片尺寸过大")
            image = ImageOps.exif_transpose(source)
            image = _to_rgb(image)
            image = ImageOps.fit(
                image,
                (AVATAR_SIZE, AVATAR_SIZE),
                method=Image.Resampling.LANCZOS,
                centering=(0.5, 0.5),
            )
            output = io.BytesIO()
            image.save(output, format="JPEG", quality=88, optimize=True)
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
            "AVATAR_DECODE_FAILED",
            "无法识别这张图片，请换一张",
        ) from exc


def save_avatar_file(user_id: str, data: bytes) -> str:
    AVATAR_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{user_id}-{secrets.token_hex(8)}.jpg"
    (AVATAR_DIR / filename).write_bytes(data)
    return f"{AVATAR_URL_PREFIX}{filename}"


def delete_local_avatar(value: str | None) -> None:
    """Best-effort removal of a previously stored local avatar file."""
    if not value:
        return
    path = value.split("?", 1)[0]
    if not path.startswith(AVATAR_URL_PREFIX):
        return
    filename = Path(path).name
    if not filename:
        return
    (AVATAR_DIR / filename).unlink(missing_ok=True)


def avatar_public_url(value: str | None) -> str | None:
    return public_media_url(value)
