"""Training schedule capability."""

from __future__ import annotations

import re
from datetime import date, datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import PlanDayState, utcnow
from ...food_text import DIET_TZ
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

    source_date = today
    if re.search(r"后天", message):
        source_date = today + timedelta(days=2)
    elif re.search(r"明天|明日", message):
        source_date = today + timedelta(days=1)
    for item in days:
        if str(item.get("date") or "") == source_date.isoformat():
            return item
    if not re.search(r"今天|今日|明天|明日|后天", message):
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
