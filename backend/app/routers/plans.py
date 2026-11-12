import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Header, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from ..deps import CurrentUser, DBSession
from ..models import (
    Exercise,
    Goal,
    PlanExercise,
    Profile,
    Program,
    ProgramDay,
    WorkoutSession,
)
from ..schemas import PlanDayPatch, PlanGenerateIn, PlanImportIn
from ..services import access, generation
from ..services.load_progression import adjustment_multipliers
from ..services.locking import lock_user
from ..services.plan_generator import generate_plan, validate_plan_for_user
from ..services.plan_validator import PlanValidationError, injury_tags
from ..services.queries import (
    active_goal,
    active_program,
    owned_program,
    owned_program_day,
)
from ..services.rate_limit import enforce as enforce_rate_limit
from ..services.serializers import (
    archive_active_plans,
    clone_program,
    goal_to_dict,
    load_program,
    save_plan,
    serialize_program,
)
from ..services.training_stage import refresh_training_stage

router = APIRouter(prefix="/plans", tags=["plans"])


def _active_program(db: DBSession, user_id: str) -> Program | None:
    return active_program(db, user_id)


def _owned_program(db: DBSession, user_id: str, plan_id: str) -> Program:
    program = owned_program(db, user_id, plan_id)
    if program is None:
        raise HTTPException(status_code=404, detail="计划不存在")
    return program


@router.post("/generate")
async def generate(
    payload: PlanGenerateIn,
    user_id: CurrentUser,
    db: DBSession,
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    profile = db.get(Profile, user_id)
    if profile is None or profile.height_cm is None or profile.weight_kg is None:
        raise HTTPException(status_code=400, detail="请先完成身高、体重等基础档案")

    enforce_rate_limit(db, "plan_generate", user_id, 3, 60)
    active = _active_program(db, user_id)
    if active and not payload.force:
        return serialize_program(active)

    lease = generation.begin_generation(
        db,
        user_id,
        access.FEATURE_TRAINING_PLAN,
        idempotency_key=idempotency_key,
    )
    if lease.is_replay:
        replayed = load_program(db, lease.replay_result_ref or "")
        if replayed is not None and replayed.user_id == user_id:
            data = serialize_program(replayed)
            data["access"] = access.access_snapshot(db, user_id)
            data["idempotent_replay"] = True
            return data
        # The referenced program was removed (for example account cleanup).
        # Release the stale replay and generate a fresh plan instead of
        # returning a half-broken idempotent response.
        generation.abort_generation(db, lease, user_id=user_id)
        lease = generation.begin_generation(
            db,
            user_id,
            access.FEATURE_TRAINING_PLAN,
            idempotency_key=None,
        )

    try:
        access_mode = access.require_training_plan_generation(
            db,
            user_id,
            onboarding=payload.onboarding,
        )
    except HTTPException:
        generation.abort_generation(db, lease, user_id=user_id)
        raise

    goal = db.execute(
        select(Goal).where(Goal.user_id == user_id, Goal.status == "active")
    ).scalar_one_or_none()
    goal_type = goal.type if goal else "recomp"

    # Release the read connection while the model runs. Otherwise every LLM
    # request keeps a DB connection checked out for the whole (possibly 30s)
    # generation window.
    db.commit()

    try:
        result = await generate_plan(
            db,
            profile,
            goal_type=goal_type,
            goal=goal_to_dict(goal),
            weeks=4,
            split=payload.split,
            focus=payload.focus,
            strict_equipment=payload.strict_equipment,
        )
        program = save_plan(
            db,
            user_id,
            result["plan"],
            goal_type=goal_type,
            generated_by=result["generated_by"],
            model_name=result["model"],
            status="pending" if payload.onboarding else "active",
        )
    except PlanValidationError as exc:
        generation.abort_generation(db, lease, user_id=user_id)
        raise HTTPException(
            status_code=422,
            detail={
                "code": "UNSAFE_PLAN",
                "message": "以你当前的伤病和器械条件，无法生成安全计划。请补充可用器械，或先咨询教练 / 康复师。",
            },
        ) from exc
    except Exception:
        generation.abort_generation(db, lease, user_id=user_id)
        raise

    data = serialize_program(program)
    data["warnings"] = result["warnings"]
    if access_mode == "onboarding":
        access.consume_trial(
            db,
            user_id,
            access.FEATURE_TRAINING_PLAN,
            source="onboarding",
            result_ref=program.id,
        )
    generation.complete_generation(
        db,
        lease,
        user_id=user_id,
        result_ref=program.id,
    )
    data["access"] = access.access_snapshot(db, user_id)
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


def _normalized_day_id(value: str | None) -> str | None:
    if not value:
        return None
    try:
        return str(uuid.UUID(value.strip()))
    except (ValueError, AttributeError):
        return None


def _plan_day_id(
    db: DBSession,
    value: str | None,
    *,
    allowed: set[str],
    used: set[str],
) -> str:
    candidate = _normalized_day_id(value)
    if (
        candidate is not None
        and candidate not in used
        and (candidate in allowed or db.get(ProgramDay, candidate) is None)
    ):
        used.add(candidate)
        return candidate
    new_value = str(uuid.uuid4())
    while new_value in used:
        new_value = str(uuid.uuid4())
    used.add(new_value)
    return new_value


@router.put("/{plan_id}")
def import_plan(
    plan_id: str,
    payload: PlanImportIn,
    user_id: CurrentUser,
    db: DBSession,
):
    """Create or replace a plan with client-generated IDs.

    iOS can generate a plan locally when the remote generator is unavailable.
    Importing it gives the server the same plan identity, so schedule, coach
    actions and cross-device reads all target the same program.
    """
    program = db.get(Program, plan_id)
    if program is not None and program.user_id != user_id:
        raise HTTPException(status_code=404, detail="计划不存在")
    if program is not None and (
        payload.expected_plan_version is not None
        and program.version != payload.expected_plan_version
    ):
        raise HTTPException(
            status_code=409,
            detail={
                "code": "PLAN_VERSION_CONFLICT",
                "message": "计划已经更新，请刷新后再同步",
                "current_version": program.version,
            },
        )

    try:
        cleaned, warnings = validate_plan_for_user(
            db,
            user_id,
            payload.model_dump(),
        )
    except PlanValidationError as exc:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "UNSAFE_PLAN",
                "message": "计划与当前伤病或器械条件冲突，请重新生成",
            },
        ) from exc
    if warnings:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "UNSAFE_PLAN",
                "message": "计划与当前伤病、器械或训练频率不一致，请重新生成",
                "warnings": warnings,
            },
        )

    lock_user(db, user_id)
    archive_active_plans(db, user_id)
    existing_day_ids = {day.id for day in program.days} if program else set()
    used_day_ids: set[str] = set()
    source_day_ids = {
        (day.week_index, day.weekday): day.id
        for day in payload.days
        if day.id
    }

    if program is None:
        goal = active_goal(db, user_id)
        program = Program(
            id=plan_id,
            user_id=user_id,
            title=payload.title,
            goal_type=goal.type if goal else "recomp",
            version=1,
            status="active",
            weeks=payload.weeks,
            generated_by=payload.generated_by or "local",
        )
        db.add(program)
    else:
        program.title = payload.title
        program.weeks = payload.weeks
        program.generated_by = payload.generated_by or program.generated_by
        program.status = "active"
        program.version += 1
        program.days.clear()
        # Flush the delete-orphan rows before reusing day IDs from the payload.
        db.flush()

    for day_doc in cleaned["days"]:
        source_id = source_day_ids.get(
            (int(day_doc["week_index"]), int(day_doc["weekday"]))
        )
        day_id = _plan_day_id(
            db,
            source_id,
            allowed=existing_day_ids,
            used=used_day_ids,
        )
        day = ProgramDay(
            id=day_id,
            week_index=int(day_doc["week_index"]),
            weekday=int(day_doc["weekday"]),
            title=str(day_doc["title"]),
            focus=list(day_doc.get("focus") or []),
        )
        for item in day_doc["exercises"]:
            day.exercises.append(
                PlanExercise(
                    exercise_slug=item["slug"],
                    order_index=int(item["order_index"]),
                    sets=int(item["sets"]),
                    reps=str(item["reps"]),
                    weight_kg=item.get("weight_kg"),
                    rest_sec=int(item["rest_sec"]),
                    rpe=item.get("rpe"),
                )
            )
        program.days.append(day)

    db.commit()
    current = load_program(db, plan_id)
    if current is None:
        raise HTTPException(status_code=500, detail="计划保存失败")
    return serialize_program(current)


@router.post("/{plan_id}/activate")
def activate_plan(plan_id: str, user_id: CurrentUser, db: DBSession):
    program = _owned_program(db, user_id, plan_id)
    if program.status == "active":
        return serialize_program(program)
    if program.status not in {"pending", "archived"}:
        raise HTTPException(status_code=409, detail="这份计划当前不能激活")
    lock_user(db, user_id)
    archive_active_plans(db, user_id)
    program.status = "active"
    db.commit()
    current = load_program(db, plan_id) or program
    return serialize_program(current)


@router.patch("/{plan_id}/days/{day_id}")
def update_day(
    plan_id: str,
    day_id: str,
    payload: PlanDayPatch,
    user_id: CurrentUser,
    db: DBSession,
):
    program = _owned_program(db, user_id, plan_id)
    if (
        payload.expected_plan_version is not None
        and program.version != payload.expected_plan_version
    ):
        raise HTTPException(
            status_code=409,
            detail={
                "code": "PLAN_VERSION_CONFLICT",
                "message": "计划已经更新，请刷新后再改",
                "current_version": program.version,
            },
        )
    lock_user(db, user_id)
    day = owned_program_day(db, user_id, day_id)
    if day is None or day.program_id != program.id:
        raise HTTPException(status_code=404, detail="训练日不存在")

    profile = db.get(Profile, user_id)
    equipment = set(profile.equipment or ["bodyweight"]) if profile else {"bodyweight"}
    equipment.add("bodyweight")
    banned = injury_tags(profile.injuries if profile else [])
    exercise_slugs = {item.slug for item in payload.exercises}
    if len(exercise_slugs) != len(payload.exercises):
        raise HTTPException(status_code=422, detail="同一天不能重复添加同一个动作")
    exercises = {
        row.slug: row
        for row in db.execute(
            select(Exercise).where(Exercise.slug.in_(exercise_slugs))
        ).scalars()
    } if exercise_slugs else {}

    for item in payload.exercises:
        exercise = exercises.get(item.slug)
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
    db.flush()
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
    program.version += 1
    db.commit()
    program = load_program(db, program.id) or program
    return serialize_program(program)


@router.post("/{plan_id}/adjust")
def adjust(plan_id: str, user_id: CurrentUser, db: DBSession):
    program = _owned_program(db, user_id, plan_id)
    access.require_feature(db, user_id, access.FEATURE_TRAINING_PLAN)
    since = datetime.now(timezone.utc) - timedelta(days=7)
    sessions = (
        db.execute(
            select(WorkoutSession)
            .options(selectinload(WorkoutSession.sets))
            .where(
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

    if not sessions:
        raise HTTPException(
            status_code=400,
            detail="最近 7 天没有训练记录，先完成一次训练再让 AI 调整。",
        )

    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")
    refresh_training_stage(db, user_id)
    weight_multipliers = adjustment_multipliers(
        program,
        sessions,
        profile.training_stage,
    )

    if completion >= 0.8:
        changes.append(
            {
                "type": "increase_load",
                "detail": f"最近 7 天完成 {len(sessions)}/{planned} 次训练，按每个动作的记录单独调整负荷。",
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

    if weight_multipliers:
        named: list[str] = []
        for day in program.days:
            for item in day.exercises:
                multiplier = weight_multipliers.get(item.exercise_slug)
                if multiplier is None:
                    continue
                name = item.exercise.name_zh if item.exercise else item.exercise_slug
                named.append(f"{name} {(multiplier - 1) * 100:+.1f}%")
        if named:
            changes.append(
                {
                    "type": "load_by_exercise",
                    "detail": "按动作调整：" + "、".join(dict.fromkeys(named)),
                }
            )
    else:
        changes.append(
            {
                "type": "keep_load",
                "detail": "没有足够的动作记录，重量保持不变；先把每个动作的次数和 RPE 记录完整。",
            }
        )

    adjusted = clone_program(
        db,
        user_id,
        program,
        sets_delta=sets_delta,
        weight_multipliers=weight_multipliers,
        title_suffix=" · 调整版",
    )
    return {"program": serialize_program(adjusted), "changes": changes}
