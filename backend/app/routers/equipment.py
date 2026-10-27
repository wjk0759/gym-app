from fastapi import APIRouter, File, HTTPException, Query, UploadFile
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from ..deps import CurrentUser, DBSession
from ..models import EquipmentLibraryItem, EquipmentScan, Exercise
from ..schemas import EquipmentLibraryIn
from ..services.equipment import recognize

router = APIRouter(tags=["equipment"])

MAX_IMAGE_BYTES = 8 * 1024 * 1024
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}


@router.post("/equipment/scan")
async def scan(
    user_id: CurrentUser,
    db: DBSession,
    file: UploadFile = File(...),
):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=415, detail="仅支持 jpeg/png/webp/heic 图片"
        )

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="图片为空")
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="图片不能超过 8MB")

    result = await recognize(db, data, file.filename or "image")

    record = EquipmentScan(
        user_id=user_id,
        status="succeeded",
        result=result["candidates"],
        model=result["model"],
        image_url=None,  # 生产环境写入 OSS 签名 URL；当前不落原图
    )
    db.add(record)
    db.commit()

    result["scan_id"] = record.id
    return result


@router.get("/exercises/search")
def search_exercises(
    db: DBSession,
    q: str = Query(default="", max_length=50),
    muscle: str | None = Query(default=None),
    equipment: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=50),
):
    query = select(Exercise)
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
                "muscle_group": item.muscle_group,
                "equipment": item.equipment,
                "instructions": item.instructions,
                "video_url": item.video_url,
            }
            for item in rows
        ]
    }


def _equipment_item_dict(item: EquipmentLibraryItem) -> dict:
    return {
        "client_id": item.client_id,
        "name": item.name,
        "slug": item.slug,
        "muscle": item.muscle,
        "equipment": item.equipment,
        "notes": item.notes,
        "created_at": item.created_at.isoformat(),
    }


def _apply_equipment_item(item: EquipmentLibraryItem, payload: EquipmentLibraryIn) -> None:
    item.name = payload.name
    item.slug = payload.slug
    item.muscle = payload.muscle
    item.equipment = payload.equipment
    item.notes = payload.notes


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
        db.commit()
    return _equipment_item_dict(item)


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
    return {"items": [_equipment_item_dict(item) for item in rows]}


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
    db.commit()
    return {"status": "deleted", "client_id": client_id}
