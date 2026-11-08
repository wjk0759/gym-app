"""Normalize uploaded photos before they reach a vision model.

Vision providers reject HEIC data that is mislabeled as JPEG, oversized
camera images and images with EXIF rotation. The API accepts the common phone
formats and always hands a small, correctly oriented JPEG to the model.
"""

from __future__ import annotations

from io import BytesIO

from PIL import Image, ImageOps, UnidentifiedImageError

try:  # HEIC/HEIF from older iPhone uploads.
    from pillow_heif import register_heif_opener

    register_heif_opener()
except ImportError:  # pragma: no cover - optional deployment dependency
    pass

MAX_IMAGE_EDGE = 1280
JPEG_QUALITY = 82


class InvalidImageError(ValueError):
    """The upload is empty, truncated or not an image Pillow can decode."""


def normalize_image_bytes(
    data: bytes,
    *,
    max_edge: int = MAX_IMAGE_EDGE,
    quality: int = JPEG_QUALITY,
) -> bytes:
    if not data:
        raise InvalidImageError("empty image")

    try:
        with Image.open(BytesIO(data)) as image:
            image = ImageOps.exif_transpose(image)
            image.thumbnail((max_edge, max_edge), Image.Resampling.LANCZOS)

            if image.mode in {"RGBA", "LA"} or (
                image.mode == "P" and "transparency" in image.info
            ):
                rgba = image.convert("RGBA")
                background = Image.new("RGB", rgba.size, (255, 255, 255))
                background.paste(rgba, mask=rgba.getchannel("A"))
                image = background
            else:
                image = image.convert("RGB")

            output = BytesIO()
            image.save(output, format="JPEG", quality=quality, optimize=True)
            return output.getvalue()
    except (UnidentifiedImageError, OSError, ValueError) as error:
        raise InvalidImageError("unsupported or corrupted image") from error
