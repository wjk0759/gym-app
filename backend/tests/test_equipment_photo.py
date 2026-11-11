import asyncio
import io
from pathlib import Path

import pytest
from fastapi import HTTPException, UploadFile
from PIL import Image
from pydantic import ValidationError
from starlette.datastructures import Headers

from app.config import settings
from app.schemas import EquipmentLibraryIn
from app.services import equipment_photo


def _jpeg(width: int = 800, height: int = 400) -> bytes:
    image = Image.new("RGB", (width, height), (30, 120, 200))
    output = io.BytesIO()
    image.save(output, format="JPEG")
    return output.getvalue()


def _upload(data: bytes, content_type: str = "image/jpeg") -> UploadFile:
    return UploadFile(
        filename="equipment.jpg",
        file=io.BytesIO(data),
        headers=Headers({"content-type": content_type}),
    )


def test_custom_equipment_requires_target_muscles() -> None:
    with pytest.raises(ValidationError):
        EquipmentLibraryIn(client_id="equipment-1", name="自定义推胸机")


def test_catalog_equipment_does_not_require_target_muscles() -> None:
    payload = EquipmentLibraryIn(
        client_id="equipment-2",
        name="腿举机",
        equipment_type="leg_press",
    )
    assert payload.target_muscles == []


def test_target_muscles_are_trimmed_and_deduped() -> None:
    payload = EquipmentLibraryIn(
        client_id="equipment-3",
        name="自定义推胸机",
        target_muscles=[" 胸大肌 ", "下胸", "胸大肌", ""],
    )
    assert payload.target_muscles == ["胸大肌", "下胸"]


def test_process_photo_downscales_and_strips_exif() -> None:
    image = Image.new("RGB", (3200, 1600), (30, 120, 200))
    exif = Image.Exif()
    exif[0x0112] = 6
    output = io.BytesIO()
    image.save(output, format="JPEG", exif=exif)

    processed = equipment_photo.process(output.getvalue())

    with Image.open(io.BytesIO(processed)) as result:
        assert max(result.size) == equipment_photo.MAX_EDGE
        assert result.mode == "RGB"
        assert not result.getexif()


def test_process_photo_rejects_invalid_bytes() -> None:
    with pytest.raises(HTTPException) as exc:
        equipment_photo.process(b"not-an-image")
    assert exc.value.status_code == 400


def test_read_upload_rejects_unsupported_content_type() -> None:
    with pytest.raises(HTTPException) as exc:
        asyncio.run(
            equipment_photo.read_upload(
                _upload(b"hello", content_type="text/plain")
            )
        )
    assert exc.value.status_code == 415


def test_read_upload_rejects_empty_file() -> None:
    with pytest.raises(HTTPException) as exc:
        asyncio.run(equipment_photo.read_upload(_upload(b"")))
    assert exc.value.status_code == 400


def test_save_and_delete_local_photo(monkeypatch, tmp_path: Path) -> None:
    monkeypatch.setattr(equipment_photo, "EQUIPMENT_DIR", tmp_path)

    relative = equipment_photo.save("user-1", _jpeg())
    assert relative.startswith(equipment_photo.EQUIPMENT_PHOTO_URL_PREFIX)
    path = tmp_path / Path(relative).name
    assert path.exists()

    equipment_photo.delete_local(relative)
    assert not path.exists()


def test_public_photo_url(monkeypatch) -> None:
    monkeypatch.setattr(settings, "public_base_url", "https://example.com")

    assert (
        equipment_photo.public_url("/media/equipment/a.jpg")
        == "https://example.com/media/equipment/a.jpg"
    )
    assert equipment_photo.public_url(None) is None
