from datetime import date, datetime, time, timezone

from fastapi import APIRouter, File, HTTPException, Query, UploadFile
from sqlalchemy import select

from ..deps import CurrentUser, DBSession
from ..models import FoodLog, Goal, MealPlan, Profile
from ..schemas import DietPlanIn, FoodLogIn
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


def _food_log_dict(item: FoodLog) -> dict:
    return {
        "client_id": item.client_id,
        "logged_at": item.logged_at.isoformat(),
        "meal": item.meal,
        "food_name": item.food_name,
        "grams": item.grams,
        "kcal": item.kcal,
        "protein": item.protein,
        "carbs": item.carbs,
        "fat": item.fat,
        "fiber": item.fiber,
    }


@router.post("/logs", status_code=201)
def upsert_food_log(payload: FoodLogIn, user_id: CurrentUser, db: DBSession):
    item = db.execute(
        select(FoodLog).where(
            FoodLog.user_id == user_id,
            FoodLog.client_id == payload.client_id,
        )
    ).scalar_one_or_none()
    if item is None:
        item = FoodLog(user_id=user_id, client_id=payload.client_id)
        db.add(item)
    item.logged_at = payload.logged_at
    item.meal = payload.meal
    item.food_name = payload.food_name
    item.grams = payload.grams
    item.kcal = payload.kcal
    item.protein = payload.protein
    item.carbs = payload.carbs
    item.fat = payload.fat
    item.fiber = payload.fiber
    db.commit()
    return _food_log_dict(item)


@router.get("/logs")
def list_food_logs(
    user_id: CurrentUser,
    db: DBSession,
    date_from: date | None = Query(default=None, alias="from"),
    date_to: date | None = Query(default=None, alias="to"),
    limit: int = Query(default=500, ge=1, le=1000),
):
    query = select(FoodLog).where(FoodLog.user_id == user_id)
    if date_from:
        query = query.where(
            FoodLog.logged_at
            >= datetime.combine(date_from, time.min, tzinfo=timezone.utc)
        )
    if date_to:
        query = query.where(
            FoodLog.logged_at
            < datetime.combine(date_to, time.max, tzinfo=timezone.utc)
        )
    rows = (
        db.execute(
            query.order_by(FoodLog.logged_at.desc()).limit(limit)
        )
        .scalars()
        .all()
    )
    return {"items": [_food_log_dict(item) for item in rows]}


@router.delete("/logs/{client_id}")
def delete_food_log(client_id: str, user_id: CurrentUser, db: DBSession):
    item = db.execute(
        select(FoodLog).where(
            FoodLog.user_id == user_id,
            FoodLog.client_id == client_id,
        )
    ).scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="饮食记录不存在")
    db.delete(item)
    db.commit()
    return {"status": "deleted", "client_id": client_id}


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
