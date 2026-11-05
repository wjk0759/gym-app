import asyncio
import io
from pathlib import Path

import pytest
from fastapi import HTTPException, UploadFile
from PIL import Image
from starlette.datastructures import Headers

from app.config import settings
from app.services import avatar


def _jpeg(width: int = 800, height: int = 400) -> bytes:
    image = Image.new("RGB", (width, height), (200, 30, 30))
    output = io.BytesIO()
    image.save(output, format="JPEG")
    return output.getvalue()


def test_process_avatar_crops_square_and_strips_exif() -> None:
    image = Image.new("RGB", (800, 400), (200, 30, 30))
    exif = Image.Exif()
    exif[0x0112] = 6
    output = io.BytesIO()
    image.save(output, format="JPEG", exif=exif)

    processed = avatar.process_avatar(output.getvalue())

    with Image.open(io.BytesIO(processed)) as result:
        assert result.size == (avatar.AVATAR_SIZE, avatar.AVATAR_SIZE)
        assert result.mode == "RGB"
        assert not result.getexif()


def test_process_avatar_rejects_invalid_bytes() -> None:
    with pytest.raises(HTTPException) as exc:
        avatar.process_avatar(b"not-an-image")
    assert exc.value.status_code == 400


def test_read_avatar_rejects_unsupported_content_type() -> None:
    upload = UploadFile(
        filename="avatar.txt",
        file=io.BytesIO(b"hello"),
        headers=Headers({"content-type": "text/plain"}),
    )

    with pytest.raises(HTTPException) as exc:
        asyncio.run(avatar.read_avatar_upload(upload))
    assert exc.value.status_code == 415


def test_save_and_delete_local_avatar(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setattr(avatar, "AVATAR_DIR", tmp_path)

    relative = avatar.save_avatar_file("user-1", _jpeg())
    assert relative.startswith(avatar.AVATAR_URL_PREFIX)
    path = tmp_path / Path(relative).name
    assert path.exists()

    avatar.delete_local_avatar(relative)
    assert not path.exists()


def test_public_avatar_url(monkeypatch) -> None:
    monkeypatch.setattr(settings, "public_base_url", "https://example.com")

    assert (
        avatar.avatar_public_url("/media/avatars/a.jpg")
        == "https://example.com/media/avatars/a.jpg"
    )
    assert (
        avatar.avatar_public_url("https://cdn.example.com/a.jpg")
        == "https://cdn.example.com/a.jpg"
    )
    assert avatar.avatar_public_url(None) is None


def test_public_avatar_url_keeps_relative_path_without_base(monkeypatch) -> None:
    monkeypatch.setattr(settings, "public_base_url", "")

    assert (
        avatar.avatar_public_url("/media/avatars/a.jpg")
        == "/media/avatars/a.jpg"
    )
