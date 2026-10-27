from datetime import date, datetime, time, timezone

from fastapi import APIRouter, File, HTTPException, Query, UploadFile
from sqlalchemy import select

from ..deps import CurrentUser, DBSession
from ..models import BodyMetric, Profile
from ..schemas import BodyMetricIn
from ..services.body_analysis import analyze

router = APIRouter(prefix="/body", tags=["body"])

MAX_IMAGE_BYTES = 8 * 1024 * 1024
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}


@router.post("/analyze")
async def analyze_body(
    user_id: CurrentUser,
    db: DBSession,
    file: UploadFile = File(...),
):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=415, detail="仅支持 jpeg/png/webp/heic 图片")

    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="图片为空")
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="图片不能超过 8MB")

    # 原图不落盘、不入库；只返回本次分析结果
    return await analyze(data, file.filename or "body.jpg")


def _body_metric_dict(item: BodyMetric) -> dict:
    return {
        "client_id": item.client_id,
        "measured_at": item.measured_at.isoformat(),
        "weight_kg": item.weight_kg,
        "body_fat_pct": item.body_fat_pct,
        "waist_cm": item.waist_cm,
        "arm_cm": item.arm_cm,
        "thigh_cm": item.thigh_cm,
    }


@router.post("/metrics", status_code=201)
def upsert_body_metric(payload: BodyMetricIn, user_id: CurrentUser, db: DBSession):
    item = db.execute(
        select(BodyMetric).where(
            BodyMetric.user_id == user_id,
            BodyMetric.client_id == payload.client_id,
        )
    ).scalar_one_or_none()
    if item is None:
        item = BodyMetric(user_id=user_id, client_id=payload.client_id)
        db.add(item)
    item.measured_at = payload.measured_at
    item.weight_kg = payload.weight_kg
    item.body_fat_pct = payload.body_fat_pct
    item.waist_cm = payload.waist_cm
    item.arm_cm = payload.arm_cm
    item.thigh_cm = payload.thigh_cm
    profile = db.get(Profile, user_id)
    if profile is not None:
        profile.weight_kg = payload.weight_kg
        profile.body_fat_pct = payload.body_fat_pct
        profile.waist_cm = payload.waist_cm
    db.commit()
    return _body_metric_dict(item)


@router.get("/metrics")
def list_body_metrics(
    user_id: CurrentUser,
    db: DBSession,
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    limit: int = Query(default=500, ge=1, le=1000),
):
    query = select(BodyMetric).where(BodyMetric.user_id == user_id)
    if date_from:
        query = query.where(
            BodyMetric.measured_at
            >= datetime.combine(date_from, time.min, tzinfo=timezone.utc)
        )
    if date_to:
        query = query.where(
            BodyMetric.measured_at
            < datetime.combine(date_to, time.max, tzinfo=timezone.utc)
        )
    rows = (
        db.execute(query.order_by(BodyMetric.measured_at.desc()).limit(limit))
        .scalars()
        .all()
    )
    return {"items": [_body_metric_dict(item) for item in rows]}


@router.delete("/metrics/{client_id}")
def delete_body_metric(client_id: str, user_id: CurrentUser, db: DBSession):
    item = db.execute(
        select(BodyMetric).where(
            BodyMetric.user_id == user_id,
            BodyMetric.client_id == client_id,
        )
    ).scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="???????")
    db.delete(item)
    db.commit()
    return {"status": "deleted", "client_id": client_id}
