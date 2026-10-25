from datetime import date

from fastapi import APIRouter, File, HTTPException, Query, UploadFile
from sqlalchemy import select

from ..deps import CurrentUser, DBSession
from ..models import Goal, MealPlan, Profile
from ..schemas import DietPlanIn
from ..services.diet import build_plan, calculate_targets, meituan_link
from ..services.food_vision import analyze as analyze_food_photo

router = APIRouter(prefix="/diet", tags=["diet"])

MAX_IMAGE_BYTES = 8 * 1024 * 1024
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}


def _goal_type(db: DBSession, user_id: str) -> str:
    goal = db.execute(
        select(Goal).where(Goal.user_id == user_id, Goal.status == "active")
    ).scalar_one_or_none()
    return goal.type if goal else "recomp"


@router.post("/analyze")
async def analyze_meal(
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

    # 原图不落盘、不入库；只返回本次识别结果
    return await analyze_food_photo(data, file.filename or "meal.jpg")


@router.get("/targets")
def targets(user_id: CurrentUser, db: DBSession):
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")
    return {"targets": calculate_targets(profile, _goal_type(db, user_id))}


@router.post("/plan")
def plan(payload: DietPlanIn, user_id: CurrentUser, db: DBSession):
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")

    plan_date = payload.date or date.today()
    result = build_plan(profile, _goal_type(db, user_id), plan_date)

    record = db.execute(
        select(MealPlan).where(
            MealPlan.user_id == user_id, MealPlan.plan_date == plan_date
        )
    ).scalar_one_or_none()
    if record is None:
        record = MealPlan(user_id=user_id, plan_date=plan_date)
        db.add(record)

    record.target_kcal = result["targets"]["target_kcal"]
    record.target_protein_g = result["targets"]["protein_g"]
    record.target_carb_g = result["targets"]["carb_g"]
    record.target_fat_g = result["targets"]["fat_g"]
    record.plan = result
    db.commit()

    return result


@router.get("/meituan-link")
def get_meituan_link(
    keyword: str = Query(default="轻食", max_length=30),
):
    link = meituan_link(keyword)
    if link is None:
        raise HTTPException(
            status_code=501,
            detail="美团联盟未配置；配置 MEITUAN_DEEPLINK_BASE 后可用。",
        )
    return link
