from fastapi import APIRouter, File, HTTPException, Query, UploadFile
from sqlalchemy import select

from ..deps import CurrentUser, DBSession
from ..models import EquipmentScan, Exercise
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
