"""Body endpoints: photo analysis, private photo retrieval, body metrics.

Photos are private per user; analysis is Pro-gated/rate-limited/idempotent and
does not become a body metric until the user records one.
"""

import uuid
from datetime import date, datetime, time, timedelta, timezone

from fastapi import APIRouter, File, Header, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy import select

from ..deps import CurrentUser, DBSession
from ..models import BodyMetric
from ..schemas import BodyAnalysisAppliedIn, BodyMetricIn
from ..services import access, generation, photo_cache
from ..services.body_analysis import analyze
from ..services.body_analysis_store import (
    delete_analysis,
    list_analyses,
    mark_applied,
    photo_for,
    save_analysis,
)
from ..services.body_metrics import (
    body_metric_dict,
    delete_metric,
    upsert_metric,
)
from ..services.image_input import InvalidImageError, normalize_image_bytes
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
    x_client_id: str | None = Header(
        default=None, alias="X-Client-ID", max_length=36
    ),
):
    """Analyze a body photo; result storage is separate from body metrics."""
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=415, detail="仅支持 jpeg/png/webp/heic 图片")

    access.require_feature(db, user_id, access.FEATURE_BODY_PHOTO)
    enforce_rate_limit(db, "body_analysis", user_id, 5, 60)
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
            detail="图片格式不支持或已损坏，请换一张图片",
        ) from error

    feature_key = access.FEATURE_BODY_PHOTO
    key = photo_cache.normalize_key(
        idempotency_key if isinstance(idempotency_key, str) else None
    )
    raw_client_id = x_client_id if isinstance(x_client_id, str) else None
    client_key = (raw_client_id or "").strip().lower()
    if not client_key:
        client_key = (
            str(uuid.uuid5(uuid.NAMESPACE_URL, f"body:{user_id}:{key}"))
            if key
            else str(uuid.uuid4())
        )
    try:
        uuid.UUID(client_key)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="X-Client-ID 必须是 UUID") from exc

    cached = photo_cache.get_cached_result(
        db, user_id, feature_key, key
    )
    if cached is not None:
        result = dict(cached)
    else:
        lease = generation.begin_generation(
            db,
            user_id,
            feature_key,
            idempotency_key=key,
            cooldown_seconds=5,
        )
        try:
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

    saved = save_analysis(
        db,
        user_id,
        client_key,
        result,
        data,
    )
    return {
        **result,
        "client_id": client_key,
        "analysis_id": saved.id,
        "created_at": saved.created_at.isoformat(),
        "has_photo": bool(saved.image_key),
    }


@router.get("/analyses")
def list_body_analyses(
    user_id: CurrentUser,
    db: DBSession,
    limit: int = Query(default=50, ge=1, le=100),
):
    return {"items": list_analyses(db, user_id, limit)}


@router.get("/analyses/{client_id}/photo")
def body_analysis_photo(
    client_id: str,
    user_id: CurrentUser,
    db: DBSession,
    size: str = Query(default="full", pattern="^(full|thumb)$"),
):
    path = photo_for(db, user_id, client_id, thumbnail=size == "thumb")
    if path is None:
        raise HTTPException(status_code=404, detail="照片不存在")
    # Sensitive photo: keep it out of URLSession/disk caches; the app caches
    # decoded images in memory for the current session only.
    return FileResponse(
        path,
        media_type="image/jpeg",
        headers={"Cache-Control": "no-store"},
    )


@router.patch("/analyses/{client_id}")
def update_body_analysis(
    client_id: str,
    payload: BodyAnalysisAppliedIn,
    user_id: CurrentUser,
    db: DBSession,
):
    item = mark_applied(
        db, user_id, client_id.lower(), payload.applied_to_plan
    )
    if item is None:
        raise HTTPException(status_code=404, detail="体型分析不存在")
    return item


@router.delete("/analyses/{client_id}")
def remove_body_analysis(client_id: str, user_id: CurrentUser, db: DBSession):
    if not delete_analysis(db, user_id, client_id.lower()):
        raise HTTPException(status_code=404, detail="体型分析不存在")
    return {"status": "deleted", "client_id": client_id.lower()}


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
