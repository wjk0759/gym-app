from datetime import date

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import select

from ..deps import CurrentUser, DBSession
from ..models import Goal, MealPlan, Profile
from ..schemas import DietPlanIn
from ..services.diet import build_plan, calculate_targets, meituan_link

router = APIRouter(prefix="/diet", tags=["diet"])


def _goal_type(db: DBSession, user_id: str) -> str:
    goal = db.execute(
        select(Goal).where(Goal.user_id == user_id, Goal.status == "active")
    ).scalar_one_or_none()
    return goal.type if goal else "recomp"


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
