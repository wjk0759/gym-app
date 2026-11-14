"""Training schedule capability."""

from __future__ import annotations

import re
from datetime import date, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import Exercise, PlanDayState, utcnow
from ...coach_actions.schemas import LogWorkoutPayload
from ...coach_actions.workout_actions import execute_log_workout, undo_log_workout
from ...exercise_search import search_exercises
from ...food_text import DIET_TZ, parse_food_date
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="training.reschedule",
        domain="training",
        kind="write",
        title="调整训练日期",
        description="把某一次计划训练改到用户指定的日期",
        requires_confirmation=True,
        undo=True,
        events=("TrainingRescheduled",),
    )
)
CARDIO = register(
    Capability(
        id="training.log_cardio",
        domain="training",
        kind="write",
        title="补录有氧训练",
        description="记录跑步、骑车、游泳等有氧训练",
        requires_confirmation=True,
        undo=True,
        events=("WorkoutLogged",),
    )
)
SKIP = register(
    Capability(
        id="training.skip",
        domain="training",
        kind="write",
        title="跳过训练",
        description="把某一次计划训练标记为主动跳过",
        requires_confirmation=True,
        undo=True,
        events=("TrainingSkipped",),
    )
)
STRENGTH = register(
    Capability(
        id="training.log_strength",
        domain="training",
        kind="write",
        title="补录力量训练",
        description="记录动作、组数、重量和次数",
        requires_confirmation=True,
        undo=True,
        events=("WorkoutLogged",),
    )
)

_WEEKDAYS = {
    "一": 0,
    "二": 1,
    "三": 2,
    "四": 3,
    "五": 4,
    "六": 5,
    "日": 6,
    "天": 6,
}


def parse_training_date(message: str, *, today: date | None = None) -> date | None:
    local_today = today or datetime.now(DIET_TZ).date()
    value = message.strip()
    target = re.search(
        r"(?:改到|改期到|顺延到|挪到|换到|调到|换一天到|改天到)(.+)$",
        value,
    )
    if target is not None:
        value = target.group(1).strip()

    if re.search(r"后天", value):
        return local_today + timedelta(days=2)
    if re.search(r"明天|明日", value):
        return local_today + timedelta(days=1)
    if re.search(r"今天|今日", value):
        return local_today

    explicit = re.search(r"(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})", value)
    if explicit:
        try:
            return date(
                int(explicit.group(1)),
                int(explicit.group(2)),
                int(explicit.group(3)),
            )
        except ValueError:
            return None

    month_day = re.search(r"(\d{1,2})月(\d{1,2})[日号]", value)
    if month_day:
        try:
            return date(
                local_today.year,
                int(month_day.group(1)),
                int(month_day.group(2)),
            )
        except ValueError:
            return None

    weekday = re.search(r"(?:周|星期|礼拜)([一二三四五六日天])", value)
    if weekday:
        target = _WEEKDAYS[weekday.group(1)]
        delta = (target - local_today.weekday()) % 7
        if delta == 0:
            delta = 7
        return local_today + timedelta(days=delta)
    return None


def _plan_days(app_context: dict) -> list[dict]:
    plan = app_context.get("plan") if isinstance(app_context, dict) else None
    if not isinstance(plan, dict):
        return []
    days = plan.get("days")
    return [item for item in days if isinstance(item, dict)] if isinstance(days, list) else []


def _source_day(
    message: str,
    app_context: dict,
    *,
    today: date,
) -> dict | None:
    days = _plan_days(app_context)
    if not days:
        return None
    day_id = ""
    if isinstance(app_context, dict):
        day_id = str(app_context.get("day_id") or "")
        today_day = app_context.get("today_day")
        if isinstance(today_day, dict) and not day_id:
            day_id = str(today_day.get("id") or "")
    if day_id:
        for item in days:
            if str(item.get("id")) == day_id:
                return item

    source_text = re.split(
        r"改到|改期到|顺延到|挪到|换到|调到",
        message,
        maxsplit=1,
    )[0]
    source_date = today
    if re.search(r"后天", source_text):
        source_date = today + timedelta(days=2)
    elif re.search(r"明天|明日", source_text):
        source_date = today + timedelta(days=1)
    elif re.search(r"今天|今日", source_text):
        source_date = today

    weekday = re.search(r"(?:周|星期|礼拜)([一二三四五六日天])", source_text)
    if weekday:
        target_weekday = _WEEKDAYS[weekday.group(1)]
        candidates: list[tuple[date, dict]] = []
        for item in days:
            raw_date = str(item.get("date") or "")
            candidate_date = None
            if raw_date:
                try:
                    candidate_date = date.fromisoformat(raw_date)
                except ValueError:
                    candidate_date = None
            if candidate_date is not None:
                if candidate_date.weekday() == target_weekday:
                    candidates.append((candidate_date, item))
            elif (
                item.get("weekday") is not None
                and int(item["weekday"]) - 1 == target_weekday
            ):
                candidates.append((today, item))
        if candidates:
            upcoming = [item for item in candidates if item[0] >= today]
            pool = upcoming or candidates
            pool.sort(key=lambda item: item[0])
            return pool[0][1]

    for item in days:
        if str(item.get("date") or "") == source_date.isoformat():
            return item
    if not re.search(r"今天|今日|明天|明日|后天", source_text):
        for item in days:
            if str(item.get("date") or "") == today.isoformat():
                return item
    return None


def resolve(
    db: Session,
    user_id: str,
    message: str,
    app_context: dict | None = None,
) -> dict:
    context = app_context if isinstance(app_context, dict) else {}
    today = datetime.now(DIET_TZ).date()
    plan = context.get("plan") if isinstance(context.get("plan"), dict) else {}
    plan_id = str(plan.get("id") or "")
    source = _source_day(message, context, today=today)
    target_date = parse_training_date(message, today=today)

    if not plan_id or source is None:
        return {
            "ready": False,
            "questions": ["你想改哪一天的训练？告诉我日期，或从训练手账里选一天。"],
        }
    if target_date is None:
        return {
            "ready": False,
            "questions": ["想改到哪一天？直接说“周四”“11月20日”都可以。"],
        }

    from_date = str(source.get("date") or "")
    day_id = str(source.get("id") or "")
    if not day_id:
        return {
            "ready": False,
            "questions": ["没有找到这一天的训练，请从训练手账里重新选择。"],
        }
    if from_date == target_date.isoformat():
        return {
            "ready": True,
            "already": True,
            "payload": {
                "plan_id": plan_id,
                "day_id": day_id,
                "plan_version": plan.get("version"),
                "from_date": from_date,
                "to_date": target_date.isoformat(),
                "title": str(source.get("title") or "训练"),
            },
        }
    return {
        "ready": True,
        "payload": {
            "plan_id": plan_id,
            "day_id": day_id,
            "plan_version": plan.get("version"),
            "from_date": from_date,
            "to_date": target_date.isoformat(),
            "title": str(source.get("title") or "训练"),
        },
    }


def resolve_skip(
    db: Session,
    user_id: str,
    message: str,
    app_context: dict | None = None,
) -> dict:
    context = app_context if isinstance(app_context, dict) else {}
    today = datetime.now(DIET_TZ).date()
    plan = context.get("plan") if isinstance(context.get("plan"), dict) else {}
    plan_id = str(plan.get("id") or "")
    source = _source_day(message, context, today=today)
    if not plan_id or source is None:
        return {
            "ready": False,
            "questions": ["你想跳过哪一天训练？告诉我日期，或从训练手账里选一天。"],
        }
    return {
        "ready": True,
        "payload": {
            "plan_id": plan_id,
            "day_id": str(source.get("id") or ""),
            "plan_version": plan.get("version"),
            "date": str(source.get("date") or ""),
            "title": str(source.get("title") or "训练"),
        },
    }


def execute_skip(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    plan_id = str(payload.get("plan_id") or "")
    day_id = str(payload.get("day_id") or "")
    if not plan_id or not day_id:
        raise ValueError("跳过训练缺少计划或训练日")
    state = db.execute(
        select(PlanDayState).where(
            PlanDayState.user_id == user_id,
            PlanDayState.plan_id == plan_id,
            PlanDayState.day_id == day_id,
        )
    ).scalar_one_or_none()
    before = _serialize_state(state)
    if state is None:
        state = PlanDayState(
            user_id=user_id,
            plan_id=plan_id,
            day_id=day_id,
            client_updated_at=utcnow(),
        )
        db.add(state)
    state.skipped_at = utcnow()
    state.client_updated_at = utcnow()
    state.updated_at = utcnow()
    db.flush()
    return {"before": before, "after": _serialize_state(state)}


def undo_skip(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
    before: dict,
) -> dict:
    plan_id = str(payload.get("plan_id") or "")
    day_id = str(payload.get("day_id") or "")
    state = db.execute(
        select(PlanDayState).where(
            PlanDayState.user_id == user_id,
            PlanDayState.plan_id == plan_id,
            PlanDayState.day_id == day_id,
        )
    ).scalar_one_or_none()
    if not before:
        if state is not None:
            db.delete(state)
            db.flush()
        return {"restored": True, "deleted": True}
    if state is None:
        return {"restored": False}
    skipped = before.get("skipped_at")
    state.skipped_at = datetime.fromisoformat(skipped) if skipped else None
    state.client_updated_at = utcnow()
    state.updated_at = utcnow()
    db.flush()
    return {"restored": True, "skipped_at": skipped}


def _cardio_title(message: str) -> str | None:
    if re.search(r"跑|慢跑", message):
        return "跑步"
    if re.search(r"骑车|单车|自行车", message):
        return "骑车"
    if re.search(r"游泳", message):
        return "游泳"
    if re.search(r"快走|走路", message):
        return "快走"
    if re.search(r"划船", message):
        return "划船"
    if re.search(r"有氧", message):
        return "有氧"
    return None


def resolve_cardio(message: str) -> dict:
    title = _cardio_title(message)
    if title is None:
        return {"ready": False, "questions": ["记录哪种训练？跑步、骑车、游泳都可以。"]}
    match = re.search(r"(\d+(?:\.\d+)?)\s*(分钟|min|小时|h)", message, re.IGNORECASE)
    if match is None:
        return {"ready": False, "questions": ["这次大概练了多久？说分钟或小时都可以。"]}
    duration = float(match.group(1))
    if match.group(2).lower() in {"小时", "h"}:
        duration *= 60
    duration_minutes = max(1, min(300, round(duration)))
    target = parse_food_date(message) or datetime.now(DIET_TZ).date()
    if target > datetime.now(DIET_TZ).date():
        return {"ready": False, "questions": ["未来的训练还不能记录，换一个日期？"]}
    return {
        "ready": True,
        "payload": {
            "date": target.isoformat(),
            "title": title,
            "duration_minutes": duration_minutes,
            "kind": "cardio",
            "notes": message[:500],
            "sets": [],
        },
    }


def execute_cardio(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return execute_log_workout(
        db,
        user_id,
        action_id,
        LogWorkoutPayload.model_validate(payload),
    )


def undo_cardio(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return undo_log_workout(
        db,
        user_id,
        action_id,
        LogWorkoutPayload.model_validate(payload),
    )


def resolve_strength(db: Session, message: str) -> dict:
    clean = re.sub(
        r"\d+(?:\.\d+)?\s*(kg|公斤|斤|组|次|个|分钟|小时|reps?)",
        " ",
        message,
        flags=re.IGNORECASE,
    )
    clean = re.sub(
        r"今天|昨天|前天|刚才|补录|记录|练了|做了|每组|大概|训练",
        " ",
        clean,
    ).strip()
    results = search_exercises(clean, limit=3)
    if not results:
        return {"ready": False, "questions": ["记录哪个动作？例如卧推、深蹲、硬拉。"]}
    name = str(results[0].get("name_zh") or "").strip()
    exercise = db.execute(
        select(Exercise).where(Exercise.name_zh == name)
    ).scalar_one_or_none()
    if exercise is None:
        exercise = db.execute(
            select(Exercise).where(Exercise.name_zh.contains(name)).limit(1)
        ).scalar_one_or_none()
    if exercise is None:
        return {"ready": False, "questions": [f"没找到动作「{name}」，换一个名称试试？"]}

    weight_match = re.search(
        r"(\d+(?:\.\d+)?)\s*(kg|公斤|斤)",
        message,
        flags=re.IGNORECASE,
    )
    weight = 0.0
    if weight_match:
        weight = float(weight_match.group(1))
        if weight_match.group(2) == "斤":
            weight = weight / 2
    elif exercise.equipment != "bodyweight":
        return {"ready": False, "questions": [f"{name}用了多重？说公斤或斤都可以。"]}

    reps_match = re.search(r"(\d+)\s*(次|个|reps?)", message, re.IGNORECASE)
    if reps_match is None:
        return {"ready": False, "questions": [f"{name}每组做了几次？"]}
    reps = max(1, min(100, int(reps_match.group(1))))

    sets_match = re.search(r"(\d+)\s*组", message)
    sets = max(1, min(10, int(sets_match.group(1)))) if sets_match else 3
    target = parse_food_date(message) or datetime.now(DIET_TZ).date()
    if target > datetime.now(DIET_TZ).date():
        return {"ready": False, "questions": ["未来的训练还不能记录，换一个日期？"]}
    return {
        "ready": True,
        "payload": {
            "date": target.isoformat(),
            "title": name,
            "duration_minutes": max(15, sets * 4 + 5),
            "kind": "strength",
            "notes": message[:500],
            "sets": [
                {
                    "slug": exercise.slug,
                    "set_index": index,
                    "weight_kg": round(weight, 1),
                    "reps": reps,
                    "rpe": 7,
                    "completed": True,
                }
                for index in range(1, sets + 1)
            ],
        },
    }


def execute_strength(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return execute_log_workout(
        db,
        user_id,
        action_id,
        LogWorkoutPayload.model_validate(payload),
    )


def undo_strength(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return undo_log_workout(
        db,
        user_id,
        action_id,
        LogWorkoutPayload.model_validate(payload),
    )


def _serialize_state(state: PlanDayState | None) -> dict:
    if state is None:
        return {}
    return {
        "assigned_date": (
            state.assigned_date.isoformat() if state.assigned_date else None
        ),
        "skipped_at": state.skipped_at.isoformat() if state.skipped_at else None,
        "plan_version": state.plan_version,
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    plan_id = str(payload.get("plan_id") or "")
    day_id = str(payload.get("day_id") or "")
    to_date = date.fromisoformat(str(payload.get("to_date") or ""))
    if not plan_id or not day_id:
        raise ValueError("改期缺少计划或训练日")

    state = db.execute(
        select(PlanDayState).where(
            PlanDayState.user_id == user_id,
            PlanDayState.plan_id == plan_id,
            PlanDayState.day_id == day_id,
        )
    ).scalar_one_or_none()
    before = _serialize_state(state)
    if state is None:
        state = PlanDayState(
            user_id=user_id,
            plan_id=plan_id,
            day_id=day_id,
            client_updated_at=utcnow(),
        )
        db.add(state)
    state.assigned_date = to_date
    state.skipped_at = None
    state.client_updated_at = utcnow()
    state.updated_at = utcnow()
    if payload.get("plan_version") is not None:
        state.plan_version = int(payload["plan_version"])
    db.flush()
    return {
        "before": before,
        "after": _serialize_state(state),
        "receipt": {
            "from_date": payload.get("from_date"),
            "to_date": to_date.isoformat(),
            "title": payload.get("title"),
        },
    }


def undo(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
    before: dict,
) -> dict:
    plan_id = str(payload.get("plan_id") or "")
    day_id = str(payload.get("day_id") or "")
    state = db.execute(
        select(PlanDayState).where(
            PlanDayState.user_id == user_id,
            PlanDayState.plan_id == plan_id,
            PlanDayState.day_id == day_id,
        )
    ).scalar_one_or_none()
    if not before:
        if state is not None:
            db.delete(state)
            db.flush()
        return {"restored": True, "deleted": True}
    if state is None:
        return {"restored": False}
    previous = before.get("assigned_date")
    previous_skipped = before.get("skipped_at")
    state.assigned_date = date.fromisoformat(previous) if previous else None
    state.skipped_at = (
        datetime.fromisoformat(previous_skipped) if previous_skipped else None
    )
    state.client_updated_at = utcnow()
    state.updated_at = utcnow()
    db.flush()
    return {
        "restored": True,
        "assigned_date": previous,
        "skipped_at": previous_skipped,
    }
