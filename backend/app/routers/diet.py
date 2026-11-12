import uuid
from datetime import date, datetime, time, timedelta, timezone

from fastapi import APIRouter, File, Header, HTTPException, Query, UploadFile
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from ..deps import CurrentUser, DBSession
from ..models import FoodLog, Goal, Profile
from ..schemas import DietPlanIn, DietWeekIn, FoodLogIn
from ..services import access, generation, photo_cache
from ..services.diet import (
    build_ai_diet_week,
    build_ai_plan,
    calculate_targets,
    list_diet_strategies,
)
from ..services.food_vision import analyze as analyze_food_photo
from ..services.image_input import InvalidImageError, normalize_image_bytes
from ..services.meal_plans import (
    get_day,
    list_week,
    save_day_plan,
    week_start_for,
    week_summary,
)
from ..services.queries import active_program
from ..services.rate_limit import enforce as enforce_rate_limit

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
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=415, detail="仅支持 jpeg/png/webp/heic 图片")

    access.require_feature(db, user_id, access.FEATURE_FOOD_PHOTO)
    enforce_rate_limit(db, "food_analysis", user_id, 5, 60)
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

    feature_key = access.FEATURE_FOOD_PHOTO
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
        # 原图不落盘、不入库；只缓存脱敏后的识别文本供短时重试
        result = await analyze_food_photo(
            data,
            file.filename or "meal.jpg",
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
        "plan_date": item.plan_date.isoformat() if item.plan_date else None,
        "plan_meal": item.plan_meal,
    }


def _apply_food_log(item: FoodLog, payload: FoodLogIn) -> None:
    item.logged_at = payload.logged_at
    item.meal = payload.meal
    item.food_name = payload.food_name
    item.grams = payload.grams
    item.kcal = payload.kcal
    item.protein = payload.protein
    item.carbs = payload.carbs
    item.fat = payload.fat
    item.fiber = payload.fiber
    item.plan_date = payload.plan_date
    item.plan_meal = payload.plan_meal


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
    _apply_food_log(item, payload)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        item = db.execute(
            select(FoodLog).where(
                FoodLog.user_id == user_id,
                FoodLog.client_id == payload.client_id,
            )
        ).scalar_one()
        _apply_food_log(item, payload)
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
            < datetime.combine(
                date_to + timedelta(days=1), time.min, tzinfo=timezone.utc
            )
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
def targets(
    user_id: CurrentUser,
    db: DBSession,
    plan_date: date | None = Query(default=None, alias="date"),
):
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")
    target_date = plan_date or date.today()

    # Prefer the saved plan for this exact day. The daily nutrition view then
    # follows the weekly plan's day-specific targets (carb-cycle high/low days)
    # instead of recalculating a flat target from the profile.
    record = get_day(db, user_id, target_date)
    if record is not None and record.plan:
        saved = record.plan.get("targets")
        if saved:
            return {
                "date": target_date.isoformat(),
                "targets": saved,
                "strategy": record.strategy,
                "source": "saved_day",
            }

    return {
        "date": target_date.isoformat(),
        "targets": calculate_targets(profile, _goal_type(db, user_id)),
        "strategy": None,
        "source": "calculated",
    }


@router.get("/plan")
def saved_plan(
    user_id: CurrentUser,
    db: DBSession,
    plan_date: date | None = Query(default=None, alias="date"),
):
    """Return the saved plan for a day so reopening the app does not fall back
    to the generic local template."""
    target_date = plan_date or date.today()
    record = get_day(db, user_id, target_date)
    if record is None or not record.plan:
        raise HTTPException(status_code=404, detail="当天还没有饮食计划")
    result = dict(record.plan)
    result["strategy"] = record.strategy
    result["generated_by"] = record.generated_by or result.get("generated_by")
    result["warning"] = result.get("warning")
    return result


@router.post("/plan")
async def plan(
    payload: DietPlanIn,
    user_id: CurrentUser,
    db: DBSession,
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")

    enforce_rate_limit(db, "diet_plan_generate", user_id, 3, 60)
    plan_date = payload.date or date.today()
    lease = generation.begin_generation(
        db,
        user_id,
        access.FEATURE_MEAL_PLAN,
        idempotency_key=idempotency_key,
    )
    if lease.is_replay:
        try:
            replay_date = date.fromisoformat(lease.replay_result_ref or "")
        except ValueError:
            replay_date = None
        if replay_date is not None:
            record = get_day(db, user_id, replay_date)
            if record is not None and record.plan:
                result = dict(record.plan)
                result["access"] = access.access_snapshot(db, user_id)
                result["idempotent_replay"] = True
                return result
        generation.abort_generation(db, lease, user_id=user_id)
        lease = generation.begin_generation(
            db,
            user_id,
            access.FEATURE_MEAL_PLAN,
            idempotency_key=None,
        )

    try:
        access_mode = access.require_meal_plan_generation(db, user_id)
    except HTTPException:
        generation.abort_generation(db, lease, user_id=user_id)
        raise

    try:
        result = await build_ai_plan(
            db, profile, _goal_type(db, user_id), plan_date
        )
        save_day_plan(
            db,
            user_id,
            plan_date,
            result,
            strategy="balanced",
            generated_by=result.get("generated_by"),
            model_name=result.get("model"),
        )
        try:
            db.commit()
        except IntegrityError:
            # Another device inserted the same user/day concurrently.
            db.rollback()
            save_day_plan(
                db,
                user_id,
                plan_date,
                result,
                strategy="balanced",
                generated_by=result.get("generated_by"),
                model_name=result.get("model"),
            )
            db.commit()

        if access_mode == "trial":
            access.consume_trial(
                db,
                user_id,
                access.FEATURE_MEAL_PLAN,
                source="first_generation",
                result_ref=plan_date.isoformat(),
            )
    except Exception:
        generation.abort_generation(db, lease, user_id=user_id)
        raise

    generation.complete_generation(
        db,
        lease,
        user_id=user_id,
        result_ref=plan_date.isoformat(),
    )
    result["access"] = access.access_snapshot(db, user_id)
    return result


@router.get("/strategies")
def strategies(user_id: CurrentUser):
    return {"items": list_diet_strategies()}


def _program_training_days(program) -> list[int] | None:
    if program is None:
        return None
    days = sorted(
        {int(day.weekday) for day in program.days if day.week_index == 1}
    )
    return days or None


def _week_payload(db: DBSession, user_id: str, start: date) -> dict:
    rows = list_week(db, user_id, start)
    summary = week_summary(rows)
    return {
        "week_start": start.isoformat(),
        "days": [row.plan for row in rows if row.plan],
        "generated_by": summary["generated_by"],
        "warning": summary["warning"],
        "strategy": summary["strategy"],
        "model": summary["model"],
    }


@router.post("/plan/week")
async def plan_week(
    payload: DietWeekIn,
    user_id: CurrentUser,
    db: DBSession,
    idempotency_key: str | None = Header(
        default=None, alias="Idempotency-Key", max_length=64
    ),
):
    profile = db.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=404, detail="请先完成个人档案")

    enforce_rate_limit(db, "meal_plan_generate", user_id, 3, 60)
    lease = generation.begin_generation(
        db,
        user_id,
        access.FEATURE_MEAL_PLAN,
        idempotency_key=idempotency_key,
    )
    if lease.is_replay:
        try:
            replay_start = date.fromisoformat(lease.replay_result_ref or "")
        except ValueError:
            replay_start = None
        if replay_start is not None:
            result = _week_payload(db, user_id, replay_start)
            result["access"] = access.access_snapshot(db, user_id)
            result["idempotent_replay"] = True
            return result
        generation.abort_generation(db, lease, user_id=user_id)
        lease = generation.begin_generation(
            db,
            user_id,
            access.FEATURE_MEAL_PLAN,
            idempotency_key=None,
        )

    try:
        access_mode = access.require_meal_plan_generation(db, user_id)
    except HTTPException:
        generation.abort_generation(db, lease, user_id=user_id)
        raise

    week_start = week_start_for(payload.week_start or date.today())
    try:
        program = active_program(db, user_id)
        result = await build_ai_diet_week(
            db,
            profile,
            _goal_type(db, user_id),
            payload.strategy,
            week_start,
            _program_training_days(program),
        )

        strategy_id = payload.strategy or (result.get("strategy") or {}).get("id")
        # MealPlan stores one day per row, so keep the week-level provenance on
        # each day for the GET endpoint and the AI/template badge in iOS.
        for day in result["days"]:
            day["generated_by"] = result.get("generated_by")
            if result.get("warning"):
                day["warning"] = result["warning"]
            save_day_plan(
                db,
                user_id,
                date.fromisoformat(day["date"]),
                day,
                strategy=strategy_id,
                generated_by=result.get("generated_by"),
                model_name=result.get("model"),
            )
        try:
            db.commit()
        except IntegrityError:
            # Another device generated the same week concurrently; re-apply.
            db.rollback()
            for day in result["days"]:
                save_day_plan(
                    db,
                    user_id,
                    date.fromisoformat(day["date"]),
                    day,
                    strategy=strategy_id,
                    generated_by=result.get("generated_by"),
                    model_name=result.get("model"),
                )
            db.commit()

        if access_mode == "trial":
            access.consume_trial(
                db,
                user_id,
                access.FEATURE_MEAL_PLAN,
                source="first_generation",
                result_ref=week_start.isoformat(),
            )
    except Exception:
        generation.abort_generation(db, lease, user_id=user_id)
        raise

    generation.complete_generation(
        db,
        lease,
        user_id=user_id,
        result_ref=week_start.isoformat(),
    )
    result["access"] = access.access_snapshot(db, user_id)
    return result


@router.get("/plan/week")
def get_plan_week(
    user_id: CurrentUser,
    db: DBSession,
    week_start: date | None = Query(default=None),
):
    return _week_payload(db, user_id, week_start_for(week_start or date.today()))
