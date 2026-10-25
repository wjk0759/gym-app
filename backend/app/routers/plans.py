from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from ..deps import CurrentUser, DBSession
from ..models import Exercise, Goal, PlanExercise, Profile, Program, ProgramDay, WorkoutSession
from ..schemas import PlanDayPatch, PlanGenerateIn
from ..services.plan_generator import generate_plan
from ..services.plan_validator import PlanValidationError, injury_tags
from ..services.serializers import (
    clone_program,
    goal_to_dict,
    save_plan,
    serialize_program,
)

router = APIRouter(prefix="/plans", tags=["plans"])


def _active_program(db: DBSession, user_id: str) -> Program | None:
    return (
        db.execute(
            select(Program)
            .where(Program.user_id == user_id, Program.status == "active")
            .order_by(Program.version.desc())
        )
        .scalars()
        .first()
    )


def _owned_program(db: DBSession, user_id: str, plan_id: str) -> Program:
    program = db.get(Program, plan_id)
    if program is None or program.user_id != user_id:
        raise HTTPException(status_code=404, detail="计划不存在")
    return program


@router.post("/generate")
async def generate(
    payload: PlanGenerateIn, user_id: CurrentUser, db: DBSession
):
    profile = db.get(Profile, user_id)
    if profile is None or profile.height_cm is None or profile.weight_kg is None:
        raise HTTPException(status_code=400, detail="请先完成身高、体重等基础档案")

    active = _active_program(db, user_id)
    if active and not payload.force:
        return serialize_program(active)

    goal = db.execute(
        select(Goal).where(Goal.user_id == user_id, Goal.status == "active")
    ).scalar_one_or_none()
    goal_type = goal.type if goal else "recomp"

    try:
        result = await generate_plan(
            db,
            profile,
            goal_type=goal_type,
            goal=goal_to_dict(goal),
            weeks=4,
            equipment_slugs=payload.equipment_slugs,
        )
    except PlanValidationError as exc:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "UNSAFE_PLAN",
                "message": "以你当前的伤病和器械条件，无法生成安全计划。请补充可用器械，或先咨询教练 / 康复师。",
            },
        ) from exc

    program = save_plan(
        db,
        user_id,
        result["plan"],
        goal_type=goal_type,
        generated_by=result["generated_by"],
        model_name=result["model"],
    )
    data = serialize_program(program)
    data["warnings"] = result["warnings"]
    return data


@router.get("/current")
def current(user_id: CurrentUser, db: DBSession):
    program = _active_program(db, user_id)
    if program is None:
        raise HTTPException(status_code=404, detail="还没有训练计划")
    return serialize_program(program)


@router.get("/{plan_id}")
def get_plan(plan_id: str, user_id: CurrentUser, db: DBSession):
    return serialize_program(_owned_program(db, user_id, plan_id))


@router.patch("/{plan_id}/days/{day_id}")
def update_day(
    plan_id: str,
    day_id: str,
    payload: PlanDayPatch,
    user_id: CurrentUser,
    db: DBSession,
):
    program = _owned_program(db, user_id, plan_id)
    day = db.get(ProgramDay, day_id)
    if day is None or day.program_id != program.id:
        raise HTTPException(status_code=404, detail="训练日不存在")

    profile = db.get(Profile, user_id)
    equipment = set(profile.equipment or ["bodyweight"]) if profile else {"bodyweight"}
    equipment.add("bodyweight")
    banned = injury_tags(profile.injuries if profile else [])

    for index, item in enumerate(payload.exercises, start=1):
        exercise = db.get(Exercise, item.slug)
        if exercise is None:
            raise HTTPException(status_code=422, detail=f"动作 {item.slug} 不存在")
        if exercise.equipment not in equipment:
            raise HTTPException(
                status_code=422,
                detail=f"{exercise.name_zh} 需要 {exercise.equipment}，不在你的器械清单里",
            )
        if banned & set(exercise.contraindications or []):
            raise HTTPException(
                status_code=422,
                detail=f"{exercise.name_zh} 与你的伤病冲突，已拒绝",
            )

    day.exercises.clear()
    for index, item in enumerate(payload.exercises, start=1):
        day.exercises.append(
            PlanExercise(
                exercise_slug=item.slug,
                order_index=index,
                sets=item.sets,
                reps=item.reps,
                weight_kg=item.weight_kg,
                rest_sec=item.rest_sec,
                rpe=item.rpe,
            )
        )
    db.commit()
    return serialize_program(program)


@router.post("/{plan_id}/adjust")
def adjust(plan_id: str, user_id: CurrentUser, db: DBSession):
    program = _owned_program(db, user_id, plan_id)
    since = datetime.now(timezone.utc) - timedelta(days=7)
    sessions = (
        db.execute(
            select(WorkoutSession).where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.started_at >= since,
            )
        )
        .scalars()
        .all()
    )

    planned = len([day for day in program.days if day.week_index == 1])
    if planned == 0:
        raise HTTPException(status_code=400, detail="计划缺少训练日")

    completion = len(sessions) / planned
    changes: list[dict] = []
    sets_delta = 0
    weight_multiplier = 1.0

    if not sessions:
        raise HTTPException(
            status_code=400,
            detail="最近 7 天没有训练记录，先完成一次训练再让 AI 调整。",
        )

    if completion >= 0.8:
        weight_multiplier = 1.025
        changes.append(
            {
                "type": "increase_load",
                "detail": f"最近 7 天完成 {len(sessions)}/{planned} 次训练，主项重量上调 2.5%。",
            }
        )
    elif completion >= 0.5:
        changes.append(
            {
                "type": "keep_load",
                "detail": f"完成率 {completion:.0%}，本周保持负荷，优先把训练日补齐。",
            }
        )
    else:
        sets_delta = -1
        changes.append(
            {
                "type": "reduce_volume",
                "detail": f"完成率只有 {completion:.0%}，每个动作减少 1 组，先建立规律。",
            }
        )

    adjusted = clone_program(
        db,
        user_id,
        program,
        sets_delta=sets_delta,
        weight_multiplier=weight_multiplier,
        title_suffix=" · 调整版",
    )
    return {"program": serialize_program(adjusted), "changes": changes}
