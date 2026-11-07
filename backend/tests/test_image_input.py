from io import BytesIO

import pytest
from PIL import Image

from app.services.image_input import InvalidImageError, normalize_image_bytes


def _png(width: int, height: int) -> bytes:
    image = Image.new("RGB", (width, height), (30, 40, 50))
    output = BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


def test_normalize_image_resizes_and_converts_to_jpeg():
    normalized = normalize_image_bytes(_png(2400, 1200), max_edge=1280)

    assert normalized.startswith(b"\xff\xd8")
    with Image.open(BytesIO(normalized)) as image:
        assert image.format == "JPEG"
        assert max(image.size) <= 1280


def test_normalize_image_rejects_corrupted_data():
    with pytest.raises(InvalidImageError):
        normalize_image_bytes(b"not-an-image")
