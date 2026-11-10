from fastapi import APIRouter, File, Form, Header, HTTPException, Query, UploadFile
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError

from ..deps import CurrentUser, DBSession
from ..models import (
    EquipmentLibraryItem,
    EquipmentScan,
    Exercise,
    UserEquipmentExercise,
    UserUniversalEquipment,
)
from ..schemas import EquipmentExercisesIn, EquipmentLibraryIn, UniversalEquipmentIn
from ..services import access, generation, photo_cache
from ..services.equipment import recognize, refresh_profile_equipment_cache
from ..services.equipment_catalog_v2 import get as get_equipment_type
from ..services.image_input import InvalidImageError, normalize_image_bytes

router = APIRouter(tags=["equipment"])

MAX_IMAGE_BYTES = 8 * 1024 * 1024
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}

# 通用器械：10 个；徒手默认勾选。
UNIVERSAL_EQUIPMENT = [
    {"slug": "bodyweight", "name_zh": "徒手", "default": True},
    {"slug": "dumbbell", "name_zh": "哑铃", "default": False},
    {"slug": "barbell", "name_zh": "杠铃", "default": False},
    {"slug": "kettlebell", "name_zh": "壶铃", "default": False},
    {"slug": "band", "name_zh": "弹力带", "default": False},
    {"slug": "pullup", "name_zh": "单杠", "default": False},
    {"slug": "dip", "name_zh": "双杠", "default": False},
    {"slug": "battle_rope", "name_zh": "战绳", "default": False},
    {"slug": "medicine_ball", "name_zh": "药球", "default": False},
    {"slug": "sled", "name_zh": "雪橇", "default": False},
]
UNIVERSAL_SLUGS = {item["slug"] for item in UNIVERSAL_EQUIPMENT}


@router.post("/equipment/scan")
async def scan(
    user_id: CurrentUser,
    db: DBSession,
    file: UploadFile = File(...),
    ocr_text: str = Form(default="", max_length=500),
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    # Check entitlement before the cache, generation lock or vision model so a
    # free account cannot read cached results or burn a cooldown.
    access.require_feature(db, user_id, access.FEATURE_EQUIPMENT_SCAN)

    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=415, detail="仅支持 jpeg/png/webp/heic 图片"
        )

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="图片为空")
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="图片不能超过 8MB")
    try:
        data = normalize_image_bytes(data)
    except InvalidImageError as error:
        raise HTTPException(
            status_code=422,
            detail="图片格式不支持或已损坏，请重新拍照或换一张图片",
        ) from error

    feature_key = "equipment_scan"
    key = photo_cache.normalize_key(idempotency_key)
    cached = photo_cache.get_cached_result(
        db, user_id, feature_key, key
    )
    if cached is not None:
        return cached

    lease = generation.begin_generation(
        db,
        user_id,
        feature_key,
        idempotency_key=key,
        cooldown_seconds=5,
    )
    try:
        result = await recognize(
            db,
            data,
            file.filename or "image",
            user_id=user_id,
            ocr_text=ocr_text.strip() if isinstance(ocr_text, str) else "",
        )

        record = EquipmentScan(
            user_id=user_id,
            status=str(result.get("status") or "succeeded")[:20],
            result=result["candidates"],
            model=result["model"],
            image_url=None,  # 生产环境写入 OSS 签名 URL；当前不落原图
        )
        db.add(record)
        db.commit()

        result["scan_id"] = record.id
        photo_cache.store_cached_result(
            db, user_id, feature_key, key, result
        )
        generation.complete_generation(
            db,
            lease,
            user_id=user_id,
            result_ref=record.id,
        )
    except Exception:
        generation.abort_generation(db, lease, user_id=user_id)
        raise
    return result


@router.get("/exercises/search")
def search_exercises(
    db: DBSession,
    q: str = Query(default="", max_length=50),
    muscle: str | None = Query(default=None),
    equipment: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=50),
):
    query = select(Exercise).where(Exercise.is_active.is_(True))
    if q:
        query = query.where(Exercise.name_zh.contains(q))
    if muscle:
        query = query.where(Exercise.muscle_group == muscle)
    if equipment:
        query = query.where(Exercise.equipment == equipment)

    rows = db.execute(query.limit(limit)).scalars().all()
    return {
        "items": [
            {
                "slug": item.slug,
                "name_zh": item.name_zh,
                "name_en": item.name_en,
                "muscle_group": item.muscle_group,
                "equipment": item.equipment,
                "is_compound": item.is_compound,
                "instructions": item.instructions,
                "video_url": item.video_url,
                "motion_start_url": item.motion_start_url,
                "motion_end_url": item.motion_end_url,
            }
            for item in rows
        ]
    }


def _enabled_by_equipment(db, user_id: str) -> dict[str, list[str]]:
    rows = (
        db.execute(
            select(UserEquipmentExercise).where(
                UserEquipmentExercise.user_id == user_id
            )
        )
        .scalars()
        .all()
    )
    result: dict[str, list[str]] = {}
    for row in rows:
        result.setdefault(row.equipment_id, []).append(row.exercise_slug)
    return result


def _equipment_item_dict(item: EquipmentLibraryItem, enabled_slugs=None) -> dict:
    return {
        "client_id": item.client_id,
        "name": item.name,
        "equipment_type": item.equipment_type,
        "category": item.category,
        "photo_url": item.photo_url,
        "slug": item.slug,
        "muscle": item.muscle,
        "equipment": item.equipment,
        "notes": item.notes,
        "source": item.source,
        "enabled_exercise_slugs": enabled_slugs or [],
        "created_at": item.created_at.isoformat(),
    }


def _apply_equipment_item(item: EquipmentLibraryItem, payload: EquipmentLibraryIn) -> None:
    item.name = payload.name
    item.equipment_type = payload.equipment_type
    catalog = get_equipment_type(payload.equipment_type) if payload.equipment_type else None
    item.category = payload.category or (catalog or {}).get("category")
    item.photo_url = payload.photo_url
    item.slug = payload.slug
    item.muscle = payload.muscle
    item.equipment = payload.equipment or item.category
    item.notes = payload.notes
    item.source = payload.source or "manual"


def _replace_equipment_exercises(
    db, user_id: str, equipment_id: str, slugs: list[str]
) -> None:
    db.execute(
        delete(UserEquipmentExercise).where(
            UserEquipmentExercise.user_id == user_id,
            UserEquipmentExercise.equipment_id == equipment_id,
        )
    )
    if not slugs:
        return
    valid = set(
        db.execute(
            select(Exercise.slug).where(
                Exercise.slug.in_(slugs),
                Exercise.is_active.is_(True),
            )
        )
        .scalars()
        .all()
    )
    for slug in dict.fromkeys(slugs):
        if slug in valid:
            db.add(
                UserEquipmentExercise(
                    user_id=user_id,
                    equipment_id=equipment_id,
                    exercise_slug=slug,
                )
            )


def _equipment_enabled_slugs(db, user_id: str, equipment_id: str) -> list[str]:
    rows = (
        db.execute(
            select(UserEquipmentExercise.exercise_slug).where(
                UserEquipmentExercise.user_id == user_id,
                UserEquipmentExercise.equipment_id == equipment_id,
            )
        )
        .scalars()
        .all()
    )
    return list(rows)


@router.post("/equipment/items", status_code=201)
def upsert_equipment_item(
    payload: EquipmentLibraryIn,
    user_id: CurrentUser,
    db: DBSession,
):
    item = db.execute(
        select(EquipmentLibraryItem).where(
            EquipmentLibraryItem.user_id == user_id,
            EquipmentLibraryItem.client_id == payload.client_id,
        )
    ).scalar_one_or_none()
    if item is None:
        item = EquipmentLibraryItem(user_id=user_id, client_id=payload.client_id)
        db.add(item)
    _apply_equipment_item(item, payload)
    refresh_profile_equipment_cache(db, user_id)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        item = db.execute(
            select(EquipmentLibraryItem).where(
                EquipmentLibraryItem.user_id == user_id,
                EquipmentLibraryItem.client_id == payload.client_id,
            )
        ).scalar_one()
        _apply_equipment_item(item, payload)
        refresh_profile_equipment_cache(db, user_id)
        db.commit()

    if payload.enabled_exercise_slugs is not None:
        _replace_equipment_exercises(
            db, user_id, item.id, payload.enabled_exercise_slugs
        )
        db.commit()

    return _equipment_item_dict(
        item, _equipment_enabled_slugs(db, user_id, item.id)
    )


@router.get("/equipment/items")
def list_equipment_items(
    user_id: CurrentUser,
    db: DBSession,
    limit: int = Query(default=500, ge=1, le=1000),
):
    rows = (
        db.execute(
            select(EquipmentLibraryItem)
            .where(EquipmentLibraryItem.user_id == user_id)
            .order_by(EquipmentLibraryItem.created_at.desc())
            .limit(limit)
        )
        .scalars()
        .all()
    )
    enabled = _enabled_by_equipment(db, user_id)
    return {
        "items": [
            _equipment_item_dict(item, enabled.get(item.id)) for item in rows
        ]
    }


@router.delete("/equipment/items/{client_id}")
def delete_equipment_item(
    client_id: str,
    user_id: CurrentUser,
    db: DBSession,
):
    item = db.execute(
        select(EquipmentLibraryItem).where(
            EquipmentLibraryItem.user_id == user_id,
            EquipmentLibraryItem.client_id == client_id,
        )
    ).scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="器械不存在")
    db.delete(item)
    db.flush()
    refresh_profile_equipment_cache(db, user_id)
    db.commit()
    return {"status": "deleted", "client_id": client_id}


@router.put("/equipment/items/{client_id}/exercises")
def replace_equipment_exercises(
    client_id: str,
    payload: EquipmentExercisesIn,
    user_id: CurrentUser,
    db: DBSession,
):
    item = db.execute(
        select(EquipmentLibraryItem).where(
            EquipmentLibraryItem.user_id == user_id,
            EquipmentLibraryItem.client_id == client_id,
        )
    ).scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="器械不存在")
    _replace_equipment_exercises(db, user_id, item.id, payload.exercise_slugs)
    db.commit()
    return {
        "enabled_exercise_slugs": _equipment_enabled_slugs(db, user_id, item.id)
    }


@router.get("/equipment/universal")
def list_universal_equipment(user_id: CurrentUser, db: DBSession):
    rows = (
        db.execute(
            select(UserUniversalEquipment).where(
                UserUniversalEquipment.user_id == user_id
            )
        )
        .scalars()
        .all()
    )
    enabled = {row.equipment_slug: bool(row.enabled) for row in rows}
    return {
        "items": [
            {
                "slug": item["slug"],
                "name_zh": item["name_zh"],
                "enabled": enabled.get(item["slug"], item["default"]),
            }
            for item in UNIVERSAL_EQUIPMENT
        ]
    }


@router.put("/equipment/universal")
def replace_universal_equipment(
    payload: UniversalEquipmentIn,
    user_id: CurrentUser,
    db: DBSession,
):
    slugs = [
        slug for slug in dict.fromkeys(payload.enabled_slugs)
        if slug in UNIVERSAL_SLUGS
    ]
    db.execute(
        delete(UserUniversalEquipment).where(
            UserUniversalEquipment.user_id == user_id
        )
    )
    for slug in slugs:
        db.add(
            UserUniversalEquipment(
                user_id=user_id,
                equipment_slug=slug,
                enabled=True,
            )
        )
    refresh_profile_equipment_cache(db, user_id)
    db.commit()
    return {"enabled_slugs": slugs}
