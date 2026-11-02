import uuid
from datetime import date, datetime, time, timedelta, timezone

from fastapi import APIRouter, File, Header, HTTPException, Query, UploadFile
from sqlalchemy import select

from ..deps import CurrentUser, DBSession
from ..models import BodyMetric
from ..schemas import BodyMetricIn
from ..services import access, generation, photo_cache
from ..services.body_analysis import analyze
from ..services.body_metrics import (
    body_metric_dict,
    delete_metric,
    upsert_metric,
)
from ..services.rate_limit import enforce as enforce_rate_limit

router = APIRouter(prefix="/body", tags=["body"])

MAX_IMAGE_BYTES = 8 * 1024 * 1024
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}


@router.post("/analyze")
async def analyze_body(
    user_id: CurrentUser,
    db: DBSession,
    file: UploadFile = File(...),
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=415, detail="仅支持 jpeg/png/webp/heic 图片")

    access.require_feature(db, user_id, access.FEATURE_BODY_PHOTO)
    enforce_rate_limit(db, "body_analysis", user_id, 5, 60)
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="图片为空")
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="图片不能超过 8MB")

    feature_key = access.FEATURE_BODY_PHOTO
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
        # 原图不落盘、不入库；只缓存脱敏后的分析文本供短时重试
        result = await analyze(
            data,
            file.filename or "body.jpg",
            db=db,
            user_id=user_id,
        )
        photo_cache.store_cached_result(
            db, user_id, feature_key, key, result
        )
    except Exception:
        generation.abort_generation(db, lease, user_id=user_id)
        raise
    generation.complete_generation(
        db,
        lease,
        user_id=user_id,
        result_ref=uuid.uuid4().hex,
    )
    return result


@router.post("/metrics", status_code=201)
def upsert_body_metric(payload: BodyMetricIn, user_id: CurrentUser, db: DBSession):
    item = upsert_metric(db, user_id, payload)
    return body_metric_dict(item)


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
            < datetime.combine(
                date_to + timedelta(days=1), time.min, tzinfo=timezone.utc
            )
        )
    rows = (
        db.execute(query.order_by(BodyMetric.measured_at.desc()).limit(limit))
        .scalars()
        .all()
    )
    return {"items": [body_metric_dict(item) for item in rows]}


@router.delete("/metrics/{client_id}")
def delete_body_metric(client_id: str, user_id: CurrentUser, db: DBSession):
    if not delete_metric(db, user_id, client_id):
        raise HTTPException(status_code=404, detail="身体数据不存在")
    return {"status": "deleted", "client_id": client_id}
