"""Unified equipment availability.

One table stores both category declarations (onboarding / coach / universal)
and precise library items. Plan generation only reads enabled entries, so a
removal from one screen cannot be silently re-added by another source.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import (
    EquipmentLibraryItem,
    Profile,
    UserEquipmentEntry,
    UserUniversalEquipment,
    utcnow,
)
from .lexicon import EQUIPMENT_LABELS

TYPE_TO_EQUIPMENT = {
    "dumbbell": "dumbbell",
    "barbell": "barbell",
    "kettlebell": "kettlebell",
    "band": "band",
    "bodyweight": "bodyweight",
}
CATEGORY_TO_EQUIPMENT = {
    "machine": "machine",
    "multi": "machine",
    "cable": "cable",
    "cardio": "bodyweight",
    "accessory": "other",
    "bodyweight": "bodyweight",
}
UNIVERSAL_TO_EQUIPMENT = {
    "bodyweight": "bodyweight",
    "dumbbell": "dumbbell",
    "barbell": "barbell",
    "kettlebell": "kettlebell",
    "band": "band",
    "pullup": "bodyweight",
    "dip": "bodyweight",
    "battle_rope": "other",
    "medicine_ball": "other",
    "sled": "other",
}


def map_library_equipment(
    equipment_type: str | None,
    category: str | None,
    equipment: str | None,
) -> str:
    mapped = TYPE_TO_EQUIPMENT.get(str(equipment_type or ""))
    if mapped is None:
        mapped = CATEGORY_TO_EQUIPMENT.get(str(category or ""))
    if mapped is None and equipment:
        mapped = str(equipment)
    return mapped or "other"


def _ordered(types: set[str]) -> list[str]:
    order = list(EQUIPMENT_LABELS)
    return sorted(
        (item for item in types if item),
        key=lambda item: (
            order.index(item) if item in order else len(order),
            item,
        ),
    )


def _entry(
    db: Session,
    user_id: str,
    client_id: str,
) -> UserEquipmentEntry | None:
    return db.execute(
        select(UserEquipmentEntry).where(
            UserEquipmentEntry.user_id == user_id,
            UserEquipmentEntry.client_id == client_id,
        )
    ).scalar_one_or_none()


def _upsert(
    db: Session,
    user_id: str,
    *,
    client_id: str,
    level: str,
    equipment_type: str,
    name: str,
    source: str,
    metadata: dict | None = None,
) -> UserEquipmentEntry:
    item = _entry(db, user_id, client_id)
    if item is None:
        item = UserEquipmentEntry(
            user_id=user_id,
            client_id=client_id,
            level=level,
            equipment_type=equipment_type,
            name=name,
            source=source,
            metadata_json=metadata or {},
        )
        db.add(item)
    item.level = level
    item.equipment_type = equipment_type
    item.name = name
    item.source = source
    item.enabled = True
    item.deleted_at = None
    item.metadata_json = metadata or {}
    db.flush()
    return item


def active_entries(db: Session, user_id: str) -> list[UserEquipmentEntry]:
    return list(
        db.execute(
            select(UserEquipmentEntry).where(
                UserEquipmentEntry.user_id == user_id,
                UserEquipmentEntry.enabled.is_(True),
                UserEquipmentEntry.deleted_at.is_(None),
            )
        )
        .scalars()
        .all()
    )


def declared_profile_equipment(db: Session, user_id: str) -> list[str]:
    rows = list(
        db.execute(
            select(UserEquipmentEntry).where(
                UserEquipmentEntry.user_id == user_id,
                UserEquipmentEntry.source == "profile",
            )
        )
        .scalars()
        .all()
    )
    if not rows:
        profile = db.get(Profile, user_id)
        return [
            str(item)
            for item in (profile.equipment or [])
            if str(item)
        ] if profile is not None else []
    return _ordered(
        {
            row.equipment_type
            for row in rows
            if row.enabled and row.deleted_at is None
        }
    )


def _legacy_types(
    db: Session,
    user_id: str,
    profile_equipment: list[str] | None,
) -> set[str]:
    if profile_equipment is None:
        profile = db.get(Profile, user_id)
        profile_equipment = list(profile.equipment or []) if profile else []
    types = {str(item) for item in (profile_equipment or []) if item}
    for row in db.execute(
        select(
            EquipmentLibraryItem.equipment_type,
            EquipmentLibraryItem.category,
            EquipmentLibraryItem.equipment,
        ).where(EquipmentLibraryItem.user_id == user_id)
    ).all():
        types.add(map_library_equipment(row[0], row[1], row[2]))
    for slug in db.execute(
        select(UserUniversalEquipment.equipment_slug).where(
            UserUniversalEquipment.user_id == user_id,
            UserUniversalEquipment.enabled.is_(True),
        )
    ).scalars():
        mapped = UNIVERSAL_TO_EQUIPMENT.get(str(slug))
        if mapped:
            types.add(mapped)
    return types


def effective_equipment_types(
    db: Session,
    user_id: str,
    profile_equipment: list[str] | None = None,
) -> list[str]:
    """Resolve the effective equipment set from profile + library + universal."""
    entries = active_entries(db, user_id)
    if entries:
        types = {item.equipment_type for item in entries}
        types.update(_legacy_types(db, user_id, []))
    else:
        types = _legacy_types(db, user_id, profile_equipment)
    types.add("bodyweight")
    return _ordered(types)


def effective_after_profile(
    db: Session,
    user_id: str,
    profile_types: list[str],
) -> list[str]:
    entries = active_entries(db, user_id)
    if entries:
        types = {
            item.equipment_type
            for item in entries
            if item.source != "profile"
        }
        types.update(profile_types)
        types.update(_legacy_types(db, user_id, []))
    else:
        types = _legacy_types(db, user_id, profile_types)
    types.add("bodyweight")
    return _ordered(types)


def sync_profile_cache(db: Session, user_id: str) -> None:
    profile = db.get(Profile, user_id)
    if profile is None:
        return
    profile.equipment = effective_equipment_types(
        db, user_id, profile.equipment
    )


def replace_profile_equipment(
    db: Session,
    user_id: str,
    types: list[str],
) -> None:
    wanted = {item for item in types if item}
    rows = list(
        db.execute(
            select(UserEquipmentEntry).where(
                UserEquipmentEntry.user_id == user_id,
                UserEquipmentEntry.source == "profile",
            )
        )
        .scalars()
        .all()
    )
    for row in rows:
        if row.equipment_type not in wanted:
            row.enabled = False
            row.deleted_at = utcnow()
    for equipment_type in wanted:
        _upsert(
            db,
            user_id,
            client_id=f"profile:{equipment_type}",
            level="category",
            equipment_type=equipment_type,
            name=EQUIPMENT_LABELS.get(equipment_type, equipment_type),
            source="profile",
        )
    # Removing a category in the profile/onboarding screen must also clear the
    # legacy universal checklist and the unified universal entries. Otherwise
    # `effective_equipment_types` unions the old value back into `/me` and the
    # next plan still programs equipment the user just removed.
    for row in db.execute(
        select(UserUniversalEquipment).where(
            UserUniversalEquipment.user_id == user_id
        )
    ).scalars():
        if UNIVERSAL_TO_EQUIPMENT.get(row.equipment_slug) not in wanted:
            row.enabled = False
    for row in db.execute(
        select(UserEquipmentEntry).where(
            UserEquipmentEntry.user_id == user_id,
            UserEquipmentEntry.source == "universal",
        )
    ).scalars():
        slug = row.client_id.removeprefix("universal:")
        if UNIVERSAL_TO_EQUIPMENT.get(slug, "other") not in wanted:
            row.enabled = False
            row.deleted_at = utcnow()
    sync_profile_cache(db, user_id)


def sync_library_entry(
    db: Session,
    user_id: str,
    item: EquipmentLibraryItem,
) -> None:
    _upsert(
        db,
        user_id,
        client_id=item.client_id,
        level="item",
        equipment_type=map_library_equipment(
            item.equipment_type, item.category, item.equipment
        ),
        name=item.name,
        source="library",
        metadata={
            "category": item.category,
            "slug": item.slug,
            "muscle": item.muscle,
            "photo_url": item.photo_url,
            "notes": item.notes,
        },
    )
    sync_profile_cache(db, user_id)


def delete_library_entry(
    db: Session,
    user_id: str,
    client_id: str,
) -> None:
    item = _entry(db, user_id, client_id)
    if item is not None:
        item.enabled = False
        item.deleted_at = utcnow()
    sync_profile_cache(db, user_id)


def replace_universal_entries(
    db: Session,
    user_id: str,
    slugs: list[str],
) -> None:
    wanted = {slug for slug in slugs if slug}
    rows = list(
        db.execute(
            select(UserEquipmentEntry).where(
                UserEquipmentEntry.user_id == user_id,
                UserEquipmentEntry.source == "universal",
            )
        )
        .scalars()
        .all()
    )
    for row in rows:
        if row.client_id.removeprefix("universal:") not in wanted:
            row.enabled = False
            row.deleted_at = utcnow()
    for slug in wanted:
        _upsert(
            db,
            user_id,
            client_id=f"universal:{slug}",
            level="category",
            equipment_type=UNIVERSAL_TO_EQUIPMENT.get(slug, "other"),
            name=slug,
            source="universal",
        )
    # Saving the universal checklist is an explicit category choice for free
    # weights. Clear the matching profile categories the user just unchecked,
    # but leave machine/cable declarations from onboarding untouched.
    wanted_types = {
        UNIVERSAL_TO_EQUIPMENT.get(slug, "other") for slug in wanted
    }
    managed_types = {"bodyweight", "dumbbell", "barbell", "kettlebell", "band"}
    profile_rows = list(
        db.execute(
            select(UserEquipmentEntry).where(
                UserEquipmentEntry.user_id == user_id,
                UserEquipmentEntry.source == "profile",
            )
        )
        .scalars()
        .all()
    )
    for row in profile_rows:
        if (
            row.equipment_type in managed_types
            and row.equipment_type not in wanted_types
        ):
            row.enabled = False
            row.deleted_at = utcnow()
    sync_profile_cache(db, user_id)
