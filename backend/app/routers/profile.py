from datetime import date, timedelta

from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from ..deps import CurrentUser, DBSession
from ..models import Goal, Profile, Program, SetLog, User, WorkoutSession, utcnow
from ..schemas import GoalIn, ProfileIn
from ..services.serializers import (
    goal_to_dict,
    profile_to_dict,
    serialize_program,
)


router = APIRouter(prefix="/me", tags=["profile"])


def _active_goal(db: DBSession, user_id: str) -> Goal | None:
    return db.execute(
        select(Goal).where(Goal.user_id == user_id, Goal.status == "active")
    ).scalar_one_or_none()


@router.get("")
def get_me(user_id: CurrentUser, db: DBSession):
    profile = db.get(Profile, user_id)
    goal = _active_goal(db, user_id)
    return {
        "user_id": user_id,
        "profile": profile_to_dict(profile) if profile else None,
        "goal": goal_to_dict(goal),
    }


@router.put("/profile")
def upsert_profile(payload: ProfileIn, user_id: CurrentUser, db: DBSession):
    profile = db.get(Profile, user_id)
    if profile is None:
        profile = Profile(user_id=user_id)
        db.add(profile)

    data = payload.model_dump()
    if data.get("birth_date"):
        age = date.today().year - data["birth_date"].year - (
            (date.today().month, date.today().day)
            < (data["birth_date"].month, data["birth_date"].day)
        )
        if age < 14 or age > 70:
            raise HTTPException(
                status_code=400,
                detail={
                    "code": "AGE_OUT_OF_RANGE",
                    "message": "年龄需在 14–70 岁之间；未成年人需监护人同意。",
                },
            )

    for field, value in data.items():
        setattr(profile, field, value)

    if profile.onboarded_at is None:
        profile.onboarded_at = utcnow()

    # 已存在减脂目标时，重新校验 BMI（提交前拦截，避免脏数据）
    goal = _active_goal(db, user_id)
    if goal and goal.type == "lose_fat" and profile.bmi and profile.bmi < 18.5:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail={
                "code": "UNSAFE_GOAL",
                "message": "当前 BMI 低于 18.5，不建议以减脂为目标。可以先选择重塑体型或增肌。",
            },
        )

    db.commit()

    return {"profile": profile_to_dict(profile)}


@router.put("/goal")
def upsert_goal(payload: GoalIn, user_id: CurrentUser, db: DBSession):
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")

    if payload.type == "lose_fat" and profile.bmi and profile.bmi < 18.5:
        raise HTTPException(
            status_code=400,
            detail={
                "code": "UNSAFE_GOAL",
                "message": "当前 BMI 低于 18.5，不建议减脂。可以改为重塑体型或增肌。",
            },
        )

    if payload.target_date and profile.weight_kg and payload.target_weight_kg:
        weeks = (payload.target_date - date.today()).days / 7
        if weeks <= 0:
            raise HTTPException(
                status_code=400,
                detail={"code": "INVALID_DATE", "message": "目标日期需要晚于今天。"},
            )
        diff = abs(payload.target_weight_kg - profile.weight_kg)
        limit = 0.5 if payload.type == "lose_fat" else 0.25
        if diff / weeks > limit:
            suggested = date.today() + timedelta(weeks=diff / limit)
            raise HTTPException(
                status_code=400,
                detail={
                    "code": "UNREALISTIC_GOAL",
                    "message": (
                        f"按每周 {limit}kg 的安全速度，最早可达日期为 "
                        f"{suggested.isoformat()}。"
                    ),
                    "details": {
                        "suggested_date": suggested.isoformat(),
                        "weekly_rate_kg": limit,
                    },
                },
            )

    goal = _active_goal(db, user_id)
    if goal is None:
        goal = Goal(user_id=user_id, status="active")
        db.add(goal)

    for field, value in payload.model_dump().items():
        setattr(goal, field, value)
    goal.status = "active"

    db.commit()
    return {"goal": goal_to_dict(goal)}


@router.get("/export")
def export_me(user_id: CurrentUser, db: DBSession):
    profile = db.get(Profile, user_id)
    goal = _active_goal(db, user_id)

    programs = (
        db.execute(select(Program).where(Program.user_id == user_id))
        .scalars()
        .all()
    )
    sessions = (
        db.execute(
            select(WorkoutSession).where(WorkoutSession.user_id == user_id)
        )
        .scalars()
        .all()
    )
    set_logs = (
        db.execute(
            select(SetLog).where(
                SetLog.session_id.in_([item.id for item in sessions] or [""])
            )
        )
        .scalars()
        .all()
    )

    return {
        "user_id": user_id,
        "profile": profile_to_dict(profile) if profile else None,
        "goal": goal_to_dict(goal),
        "programs": [serialize_program(item) for item in programs],
        "workouts": [
            {
                "id": item.id,
                "started_at": item.started_at.isoformat(),
                "finished_at": item.finished_at.isoformat() if item.finished_at else None,
                "duration_min": item.duration_min,
                "feeling": item.feeling,
                "notes": item.notes,
                "sets": [
                    {
                        "slug": log.exercise_slug,
                        "set_index": log.set_index,
                        "weight_kg": log.weight_kg,
                        "reps": log.reps,
                        "rpe": log.rpe,
                        "completed": log.completed,
                    }
                    for log in set_logs
                    if log.session_id == item.id
                ],
            }
            for item in sessions
        ],
    }


@router.delete("")
def delete_me(user_id: CurrentUser, db: DBSession):
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="用户不存在")
    user.deleted_at = utcnow()
    db.commit()
    return {"status": "pending_deletion", "cooling_off_days": 15}
