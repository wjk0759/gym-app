from app.models import EquipmentLibraryItem
from app.routers.equipment import _apply_equipment_item
from app.schemas import EquipmentLibraryIn


def _item() -> EquipmentLibraryItem:
    return EquipmentLibraryItem(
        user_id="user-1",
        client_id="equipment-1",
        name="旧的器械",
    )


def test_omitting_photo_url_keeps_the_uploaded_photo() -> None:
    item = _item()
    item.photo_url = "/media/equipment/old.jpg"

    payload = EquipmentLibraryIn(
        client_id="equipment-1",
        name="腿举机",
        equipment_type="leg_press",
    )
    _apply_equipment_item(item, payload)

    assert item.photo_url == "/media/equipment/old.jpg"


def test_apply_saves_target_muscles() -> None:
    item = _item()

    payload = EquipmentLibraryIn(
        client_id="equipment-1",
        name="自定义推胸机",
        target_muscles=["胸大肌", "下胸"],
    )
    _apply_equipment_item(item, payload)

    assert item.target_muscles == ["胸大肌", "下胸"]
