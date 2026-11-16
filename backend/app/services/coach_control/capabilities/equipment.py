"""Personal equipment library actions from the coach."""

from __future__ import annotations

import re

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from ....models import EquipmentLibraryItem, UserEquipmentExercise
from ...equipment import (
    catalog_exercises,
    catalog_get,
    match_name,
    refresh_profile_equipment_cache,
)
from ..registry import Capability, register

ADD_CAPABILITY = register(
    Capability(
        id="equipment.add",
        domain="equipment",
        kind="write",
        title="加入个人器械库",
        description="把识别到的或说出的器械加入个人器械库",
        requires_confirmation=True,
        undo=True,
        events=("EquipmentAdded",),
        refreshes=("equipment", "plan", "profile"),
    )
)
UPDATE_CAPABILITY = register(
    Capability(
        id="equipment.update",
        domain="equipment",
        kind="write",
        title="修改个人器械",
        description="修改个人器械库里的器械名称",
        requires_confirmation=True,
        undo=True,
        events=("EquipmentUpdated",),
        refreshes=("equipment", "plan", "profile"),
    )
)
DELETE_CAPABILITY = register(
    Capability(
        id="equipment.delete",
        domain="equipment",
        kind="write",
        title="删除个人器械",
        description="从个人器械库删除一件器械",
        requires_confirmation=True,
        undo=True,
        events=("EquipmentDeleted",),
        refreshes=("equipment", "plan", "profile"),
    )
)


def _library_item(db: Session, user_id: str, name: str):
    normalized = name.strip().lower()
    if not normalized:
        return None, []
    rows = (
        db.execute(
            select(EquipmentLibraryItem).where(
                EquipmentLibraryItem.user_id == user_id
            )
        )
        .scalars()
        .all()
    )
    exact = [
        item
        for item in rows
        if item.name.strip().lower() == normalized
    ]
    if exact:
        return (exact[0] if len(exact) == 1 else None, exact)
    matches = [
        item
        for item in rows
        if normalized in item.name.lower()
        or item.name.lower() in normalized
    ]
    return (matches[0] if len(matches) == 1 else None, matches)


def _exact_library_item(
    db: Session,
    user_id: str,
    name: str,
) -> EquipmentLibraryItem | None:
    normalized = name.strip().lower()
    if not normalized:
        return None
    rows = (
        db.execute(
            select(EquipmentLibraryItem).where(
                EquipmentLibraryItem.user_id == user_id
            )
        )
        .scalars()
        .all()
    )
    return next(
        (
            item
            for item in rows
            if item.name.strip().lower() == normalized
        ),
        None,
    )


def _explicit_name(message: str) -> str | None:
    patterns = (
        r"把\s*(.+?)\s*(?:加|添加|放进|加入|存到)\s*(?:我的)?器械库",
        r"把\s*(.+?)\s*(?:加|添加|放进|加入)\s*(?:进来|进去|到我的)",
        r"(?:添加|加入|新增)\s*(?:一台|一个)?\s*器械\s*[：:，,\s]*(.+)",
    )
    for pattern in patterns:
        match = re.search(pattern, message)
        if match is not None:
            value = match.group(1).strip(" ，,。；;：:")
            value = re.sub(r"^(?:我刚才|刚才|这个|这台)\s*", "", value)
            if value and value not in {"器械", "设备"}:
                return value[:120]
    return None


def resolve_add(
    db: Session,
    user_id: str,
    message: str,
    context: dict,
) -> dict:
    name = _explicit_name(message)
    equipment_type = None
    equipment_context = (
        context.get("equipment_context")
        if isinstance(context, dict)
        else None
    )
    if isinstance(equipment_context, dict) and re.search(
        r"刚才|这个|这台|识别", message
    ):
        name = (
            str(equipment_context.get("equipment_name") or "").strip()
            or str(equipment_context.get("name") or "").strip()
            or name
        )
        equipment_type = (
            str(equipment_context.get("equipment_type") or "").strip()
            or None
        )
    if not name:
        return {
            "ready": False,
            "questions": ["要加入哪件器械？例如“把坐姿划船机加入器械库”。"],
        }
    catalog = None
    if equipment_type:
        catalog = catalog_get(db, equipment_type)
    if catalog is None:
        catalog = match_name(db, name)
    if catalog is not None:
        name = catalog.name_zh
        enabled = catalog_exercises(db, catalog)
        payload = {
            "name": name,
            "equipment_type": catalog.slug,
            "category": catalog.category,
            "equipment": catalog.category,
            "enabled_exercise_slugs": enabled,
            "summary": f"准备把「{name}」加入个人器械库",
        }
    else:
        payload = {
            "name": name,
            "equipment_type": None,
            "category": None,
            "equipment": None,
            "enabled_exercise_slugs": [],
            "summary": f"准备把「{name}」作为自定义器械加入器械库",
        }
    if _exact_library_item(db, user_id, name) is not None:
        payload["duplicate_name"] = True
        payload["summary"] += "；器械库已有同名器械，确认会再添加一台"
    return {"ready": True, "payload": payload}


def resolve_update(db: Session, user_id: str, message: str) -> dict:
    match = re.search(
        r"(?:把|将)?\s*(.+?)\s*"
        r"(?:改名(?:为)?|重命名(?:为)?|名称改成|名称改为)\s*[：:]?\s*(.+)",
        message,
    )
    if match is None:
        return {
            "ready": False,
            "questions": ["想改哪件器械的名字？例如“把坐姿划船机改名为坐姿划船”。"],
        }
    old_name = match.group(1).strip(" ，,。；;：:")
    new_name = match.group(2).strip(" ，,。；;：:")
    item, matches = _library_item(db, user_id, old_name)
    if item is None:
        if matches:
            return {
                "ready": False,
                "questions": [
                    "器械库里有多个匹配项："
                    + "、".join(row.name for row in matches[:3])
                ],
            }
        return {
            "ready": False,
            "questions": [f"器械库里没有找到「{old_name}」。"],
        }
    if not new_name or len(new_name) > 120:
        return {"ready": False, "questions": ["新名字太短或太长，换一个试试。"]}
    duplicate = _exact_library_item(db, user_id, new_name)
    if duplicate is not None and duplicate.id != item.id:
        return {
            "ready": False,
            "terminal": True,
            "questions": [f"器械库里已经有同名器械「{duplicate.name}」了。"],
        }
    return {
        "ready": True,
        "payload": {
            "client_id": item.client_id,
            "old_name": item.name,
            "name": new_name,
            "summary": f"准备把「{item.name}」改名为「{new_name}」",
        },
    }


def resolve_delete(db: Session, user_id: str, message: str) -> dict:
    match = re.search(
        r"(?:删掉|删除|移除|去掉)\s*(?:我的)?\s*(?:器械|设备)?\s*[：:]?\s*(.+)",
        message,
    )
    name = match.group(1).strip(" ，,。；;：:") if match else ""
    name = re.sub(r"\s*(?:这台|那个|这件)?\s*(?:器械|设备)$", "", name)
    if not name:
        return {
            "ready": False,
            "questions": ["要删哪件器械？例如“删掉坐姿划船机”。"],
        }
    item, matches = _library_item(db, user_id, name)
    if item is None:
        if matches:
            return {
                "ready": False,
                "questions": [
                    "器械库里有多个匹配项："
                    + "、".join(row.name for row in matches[:3])
                ],
            }
        return {
            "ready": False,
            "questions": [f"器械库里没有找到「{name}」。"],
        }
    return {
        "ready": True,
        "payload": {
            "client_id": item.client_id,
            "name": item.name,
            "summary": f"准备从器械库删除「{item.name}」",
        },
    }


def _enabled_slugs(db: Session, user_id: str, equipment_id: str) -> list[str]:
    return list(
        db.execute(
            select(UserEquipmentExercise.exercise_slug).where(
                UserEquipmentExercise.user_id == user_id,
                UserEquipmentExercise.equipment_id == equipment_id,
            )
        )
        .scalars()
        .all()
    )


def execute_add(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    name = str(payload.get("name") or "").strip()[:120]
    if not name:
        raise ValueError("器械名称不能为空")
    client_id = action_id
    item = EquipmentLibraryItem(
        user_id=user_id,
        client_id=client_id,
        name=name,
        equipment_type=payload.get("equipment_type"),
        category=payload.get("category"),
        equipment=payload.get("equipment"),
        source="coach",
        target_muscles=[],
    )
    db.add(item)
    db.flush()
    for slug in payload.get("enabled_exercise_slugs") or []:
        db.add(
            UserEquipmentExercise(
                user_id=user_id,
                equipment_id=item.id,
                exercise_slug=str(slug),
            )
        )
    db.flush()
    refresh_profile_equipment_cache(db, user_id)
    return {"client_id": client_id, "name": name}


def undo_add(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    client_id = action_id
    item = db.execute(
        select(EquipmentLibraryItem).where(
            EquipmentLibraryItem.user_id == user_id,
            EquipmentLibraryItem.client_id == client_id,
        )
    ).scalar_one_or_none()
    if item is not None:
        db.delete(item)
        db.flush()
        refresh_profile_equipment_cache(db, user_id)
    return {"removed": item is not None}


def execute_update(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    item = db.execute(
        select(EquipmentLibraryItem).where(
            EquipmentLibraryItem.user_id == user_id,
            EquipmentLibraryItem.client_id == str(payload.get("client_id") or ""),
        )
    ).scalar_one_or_none()
    if item is None:
        raise LookupError("器械不存在")
    before = {"name": item.name}
    item.name = str(payload.get("name") or item.name)[:120]
    db.flush()
    refresh_profile_equipment_cache(db, user_id)
    return {"before": before, "after": {"name": item.name}}


def undo_update(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    item = db.execute(
        select(EquipmentLibraryItem).where(
            EquipmentLibraryItem.user_id == user_id,
            EquipmentLibraryItem.client_id == str(payload.get("client_id") or ""),
        )
    ).scalar_one_or_none()
    if item is not None and before.get("name"):
        item.name = str(before["name"])[:120]
        db.flush()
        refresh_profile_equipment_cache(db, user_id)
    return {"restored": item is not None}


def _snapshot(item: EquipmentLibraryItem, enabled: list[str]) -> dict:
    return {
        "client_id": item.client_id,
        "name": item.name,
        "equipment_type": item.equipment_type,
        "category": item.category,
        "photo_url": item.photo_url,
        "slug": item.slug,
        "muscle": item.muscle,
        "equipment": item.equipment,
        "target_muscles": list(item.target_muscles or []),
        "notes": item.notes,
        "source": item.source,
        "enabled_exercise_slugs": enabled,
    }


def execute_delete(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    item = db.execute(
        select(EquipmentLibraryItem).where(
            EquipmentLibraryItem.user_id == user_id,
            EquipmentLibraryItem.client_id == str(payload.get("client_id") or ""),
        )
    ).scalar_one_or_none()
    if item is None:
        raise LookupError("器械不存在")
    before = _snapshot(item, _enabled_slugs(db, user_id, item.id))
    db.execute(
        delete(UserEquipmentExercise).where(
            UserEquipmentExercise.user_id == user_id,
            UserEquipmentExercise.equipment_id == item.id,
        )
    )
    db.delete(item)
    db.flush()
    refresh_profile_equipment_cache(db, user_id)
    return {"before": before}


def undo_delete(
    db: Session,
    user_id: str,
    before: dict,
) -> dict:
    if not before.get("client_id"):
        return {"restored": False}
    item = db.execute(
        select(EquipmentLibraryItem).where(
            EquipmentLibraryItem.user_id == user_id,
            EquipmentLibraryItem.client_id == before["client_id"],
        )
    ).scalar_one_or_none()
    if item is None:
        item = EquipmentLibraryItem(
            user_id=user_id,
            client_id=str(before["client_id"]),
            name=str(before.get("name") or "器械"),
            equipment_type=before.get("equipment_type"),
            category=before.get("category"),
            photo_url=before.get("photo_url"),
            slug=before.get("slug"),
            muscle=before.get("muscle"),
            equipment=before.get("equipment"),
            target_muscles=list(before.get("target_muscles") or []),
            notes=before.get("notes"),
            source=before.get("source") or "coach",
        )
        db.add(item)
        db.flush()
        for slug in before.get("enabled_exercise_slugs") or []:
            db.add(
                UserEquipmentExercise(
                    user_id=user_id,
                    equipment_id=item.id,
                    exercise_slug=str(slug),
                )
            )
        db.flush()
    refresh_profile_equipment_cache(db, user_id)
    return {"restored": True}
