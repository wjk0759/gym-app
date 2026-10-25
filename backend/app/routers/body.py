from fastapi import APIRouter, File, HTTPException, UploadFile

from ..deps import CurrentUser, DBSession
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
