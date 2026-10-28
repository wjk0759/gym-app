from datetime import date, timedelta

from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from ..deps import CurrentUser, DBSession
from ..models import (
    AgentActionEvent,
    AIMemory,
    AuthSession,
    BodyMetric,
    ChatSession,
    EquipmentLibraryItem,
    FoodLog,
    Goal,
    MealPlan,
    PlanDayState,
    Profile,
    Program,
    User,
    WorkoutSession,
    utcnow,
)
from ..schemas import GoalIn, ProfileIn
from ..services.locking import lock_user
from ..services.queries import active_goal
from ..services.serializers import (
    goal_to_dict,
    profile_to_dict,
    program_load_options,
    serialize_program,
)

router = APIRouter(prefix="/me", tags=["profile"])


def _active_goal(db: DBSession, user_id: str) -> Goal | None:
    return active_goal(db, user_id)


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
    lock_user(db, user_id)
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

    lock_user(db, user_id)
    active_goals = (
        db.execute(
            select(Goal)
            .where(Goal.user_id == user_id, Goal.status == "active")
            .order_by(Goal.created_at.desc())
        )
        .scalars()
        .all()
    )
    goal = active_goals[0] if active_goals else None
    for stale in active_goals[1:]:
        stale.status = "replaced"
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
        db.execute(
            select(Program)
            .options(program_load_options())
            .where(Program.user_id == user_id)
            .order_by(Program.created_at.desc())
        )
        .scalars()
        .all()
    )
    sessions = (
        db.execute(
            select(WorkoutSession)
            .options(selectinload(WorkoutSession.sets))
            .where(WorkoutSession.user_id == user_id)
            .order_by(WorkoutSession.started_at.desc())
        )
        .scalars()
        .all()
    )
    body_metrics = (
        db.execute(
            select(BodyMetric)
            .where(BodyMetric.user_id == user_id)
            .order_by(BodyMetric.measured_at.desc())
        )
        .scalars()
        .all()
    )
    food_logs = (
        db.execute(
            select(FoodLog)
            .where(FoodLog.user_id == user_id)
            .order_by(FoodLog.logged_at.desc())
        )
        .scalars()
        .all()
    )
    equipment = (
        db.execute(
            select(EquipmentLibraryItem)
            .where(EquipmentLibraryItem.user_id == user_id)
            .order_by(EquipmentLibraryItem.created_at.desc())
        )
        .scalars()
        .all()
    )
    meal_plans = (
        db.execute(
            select(MealPlan)
            .where(MealPlan.user_id == user_id)
            .order_by(MealPlan.plan_date.desc())
        )
        .scalars()
        .all()
    )
    memories = (
        db.execute(
            select(AIMemory)
            .where(AIMemory.user_id == user_id)
            .order_by(AIMemory.updated_at.desc(), AIMemory.created_at.desc())
        )
        .scalars()
        .all()
    )
    actions = (
        db.execute(
            select(AgentActionEvent)
            .where(AgentActionEvent.user_id == user_id)
            .order_by(AgentActionEvent.created_at.desc())
        )
        .scalars()
        .all()
    )
    chats = (
        db.execute(
            select(ChatSession)
            .options(selectinload(ChatSession.messages))
            .where(ChatSession.user_id == user_id)
            .order_by(ChatSession.created_at.desc())
        )
        .scalars()
        .all()
    )
    schedule_states = (
        db.execute(
            select(PlanDayState)
            .where(PlanDayState.user_id == user_id)
            .order_by(PlanDayState.plan_id, PlanDayState.day_id)
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
                "client_id": item.client_id,
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
                    for log in item.sets
                ],
            }
            for item in sessions
        ],
        "body_metrics": [
            {
                "client_id": item.client_id,
                "measured_at": item.measured_at.isoformat(),
                "weight_kg": item.weight_kg,
                "body_fat_pct": item.body_fat_pct,
                "waist_cm": item.waist_cm,
                "arm_cm": item.arm_cm,
                "thigh_cm": item.thigh_cm,
            }
            for item in body_metrics
        ],
        "food_logs": [
            {
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
            for item in food_logs
        ],
        "equipment_library": [
            {
                "client_id": item.client_id,
                "name": item.name,
                "slug": item.slug,
                "muscle": item.muscle,
                "equipment": item.equipment,
                "notes": item.notes,
                "created_at": item.created_at.isoformat(),
            }
            for item in equipment
        ],
        "meal_plans": [
            {
                "plan_date": item.plan_date.isoformat(),
                "target_kcal": item.target_kcal,
                "target_protein_g": item.target_protein_g,
                "target_carb_g": item.target_carb_g,
                "target_fat_g": item.target_fat_g,
                "plan": item.plan,
            }
            for item in meal_plans
        ],
        "agent_memories": [
            {
                "kind": item.kind,
                "key": item.memory_key,
                "content": item.content,
                "source": item.source,
                "confidence": item.confidence,
                "active": item.active,
                "created_at": item.created_at.isoformat() if item.created_at else None,
                "updated_at": item.updated_at.isoformat() if item.updated_at else None,
            }
            for item in memories
        ],
        "agent_actions": [
            {
                "action_id": item.action_id,
                "run_id": item.run_id,
                "action_type": item.action_type,
                "status": item.status,
                "message": item.message,
                "detail": item.detail or {},
                "created_at": item.created_at.isoformat() if item.created_at else None,
            }
            for item in actions
        ],
        "chat_sessions": [
            {
                "id": item.id,
                "title": item.title,
                "created_at": item.created_at.isoformat(),
                "messages": [
                    {
                        "role": message.role,
                        "content": message.content,
                        "citations": message.citations or [],
                        "safety_flag": message.safety_flag,
                        "created_at": message.created_at.isoformat(),
                    }
                    for message in item.messages
                ],
            }
            for item in chats
        ],
        "schedule_states": [
            {
                "plan_id": item.plan_id,
                "day_id": item.day_id,
                "plan_version": item.plan_version,
                "assigned_date": item.assigned_date.isoformat()
                if item.assigned_date
                else None,
                "skipped_at": item.skipped_at.isoformat() if item.skipped_at else None,
                "client_updated_at": item.client_updated_at.isoformat()
                if item.client_updated_at
                else None,
                "updated_at": item.updated_at.isoformat() if item.updated_at else None,
            }
            for item in schedule_states
        ],
        "exported_at": utcnow().isoformat(),
    }


@router.delete("")
def delete_me(user_id: CurrentUser, db: DBSession):
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="用户不存在")
    now = utcnow()
    user.deleted_at = now
    user.status = "pending_deletion"
    for session in db.execute(
        select(AuthSession).where(
            AuthSession.user_id == user_id,
            AuthSession.revoked_at.is_(None),
        )
    ).scalars():
        session.revoked_at = now
    db.commit()
    return {"status": "pending_deletion", "cooling_off_days": 15}
