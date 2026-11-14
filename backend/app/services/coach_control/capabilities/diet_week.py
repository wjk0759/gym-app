"""One-week diet plan generation with strategy selection.

The model produces a week draft; a proposal card is shown and the plan is only
saved after confirmation. Undo restores every previous day in the week.
"""

from __future__ import annotations

import re
from datetime import date, datetime, timedelta

from fastapi import HTTPException
from sqlalchemy.orm import Session

from ....models import Profile
from ... import access
from ...diet import DIET_STRATEGIES, build_ai_diet_week
from ...food_text import DIET_TZ
from ...meal_plans import get_day, save_day_plan, week_start_for
from ...queries import active_goal, active_program
from ...rate_limit import enforce as enforce_rate_limit
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="diet.generate_week",
        domain="diet",
        kind="write",
        title="生成一周饮食计划",
        description="按策略生成 7 天餐单，确认后保存，可撤销",
        requires_confirmation=True,
        undo=True,
        events=("DietPlanGenerated",),
    )
)

WEEKDAY_LABELS = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]


def _strategy(message: str) -> str:
    for strategy in DIET_STRATEGIES.values():
        if strategy.label in message:
            return strategy.id
    if re.search(r"16\s*[:：]\s*8|168|轻断食|断食", message):
        return "time_restricted_16_8"
    return "balanced"


def _week_start(message: str) -> date:
    today = datetime.now(DIET_TZ).date()
    if re.search(r"下下周", message):
        return week_start_for(today + timedelta(days=14))
    if re.search(r"下周", message):
        return week_start_for(today + timedelta(days=7))
    if re.search(r"本周|这周", message):
        return week_start_for(today)
    if re.search(r"明天|明日", message):
        return week_start_for(today + timedelta(days=1))
    if re.search(r"今天|今日", message):
        return week_start_for(today)
    explicit = re.search(r"(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})", message)
    if explicit:
        try:
            return week_start_for(
                date(
                    int(explicit.group(1)),
                    int(explicit.group(2)),
                    int(explicit.group(3)),
                )
            )
        except ValueError:
            pass
    month_day = re.search(r"(\d{1,2})月(\d{1,2})[日号]", message)
    if month_day:
        try:
            return week_start_for(
                date(
                    today.year,
                    int(month_day.group(1)),
                    int(month_day.group(2)),
                )
            )
        except ValueError:
            pass
    # "排一周餐单" with no date means the upcoming week.
    return week_start_for(today + timedelta(days=7))


def _snapshot(record) -> dict | None:
    if record is None:
        return None
    return {
        "plan": record.plan,
        "strategy": record.strategy,
        "generated_by": record.generated_by,
        "model_name": record.model_name,
    }


async def resolve(db: Session, user_id: str, message: str) -> dict:
    profile = db.get(Profile, user_id)
    if profile is None:
        return {"ready": False, "questions": ["请先完成个人档案。"]}
    try:
        access_mode = access.require_meal_plan_generation(db, user_id)
    except HTTPException:
        return {
            "ready": False,
            "questions": [
                "一周饮食计划需要 Pro 或首次试用；你可以先记录饮食，或继续问我建议。"
            ],
        }
    try:
        enforce_rate_limit(db, "coach_diet_week", user_id, 3, 600)
    except HTTPException:
        return {
            "ready": False,
            "questions": ["一周饮食计划生成有点频繁，十分钟后再试。"],
        }

    strategy_id = _strategy(message)
    strategy = DIET_STRATEGIES.get(strategy_id, DIET_STRATEGIES["balanced"])
    week_start = _week_start(message)
    goal = active_goal(db, user_id)
    program = active_program(db, user_id)
    training_days = (
        sorted({int(day.weekday) for day in program.days if day.week_index == 1})
        if program is not None
        else None
    ) or None
    result = await build_ai_diet_week(
        db,
        profile,
        goal.type if goal is not None else "recomp",
        strategy_id,
        week_start,
        training_days,
    )
    days = [item for item in result.get("days") or [] if isinstance(item, dict)]
    if not days:
        return {"ready": False, "questions": ["这周餐单没有生成成功，稍后再试。"]}
    generated_by = result.get("generated_by")
    model = result.get("model")
    for day in days:
        day["generated_by"] = generated_by
        if result.get("warning"):
            day["warning"] = result["warning"]

    total_kcal = sum(
        float((day.get("targets") or {}).get("target_kcal") or 0)
        for day in days
    )
    watchouts = []
    if result.get("warning"):
        watchouts.append(str(result["warning"]))
    if strategy.caution:
        watchouts.append(strategy.caution)
    return {
        "ready": True,
        "payload": {
            "week_start": week_start.isoformat(),
            "strategy": strategy_id,
            "access_mode": access_mode,
            "model": model,
            "days": days,
            "summary": (
                f"{week_start.month}月{week_start.day}日起一周饮食草案："
                f"{strategy.label}，7 天约 {round(total_kcal)} kcal。"
            ),
            "wins": [
                f"{WEEKDAY_LABELS[index]}："
                f"{(day.get('targets') or {}).get('target_kcal') or '—'} kcal"
                for index, day in enumerate(days[:7])
            ],
            "watchouts": watchouts,
            "actions": [],
        },
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    week_start = date.fromisoformat(str(payload["week_start"]))
    previous = {}
    for offset in range(7):
        day = week_start + timedelta(days=offset)
        previous[day.isoformat()] = _snapshot(get_day(db, user_id, day))
    days = [item for item in payload.get("days") or [] if isinstance(item, dict)]
    for day in days:
        save_day_plan(
            db,
            user_id,
            date.fromisoformat(str(day["date"])),
            day,
            strategy=str(payload.get("strategy") or "balanced"),
            generated_by=day.get("generated_by"),
            model_name=payload.get("model"),
        )
    if payload.get("access_mode") == "trial":
        access.consume_trial(
            db,
            user_id,
            access.FEATURE_MEAL_PLAN,
            source="coach_week_generation",
            result_ref=week_start.isoformat(),
        )
    return {
        "week_start": week_start.isoformat(),
        "saved_days": len(days),
        "before": {"previous": previous},
    }


def undo(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    previous = before.get("previous") if isinstance(before, dict) else {}
    for raw_date, snapshot in (previous or {}).items():
        day = date.fromisoformat(raw_date)
        if isinstance(snapshot, dict) and snapshot.get("plan"):
            save_day_plan(
                db,
                user_id,
                day,
                snapshot["plan"],
                strategy=snapshot.get("strategy"),
                generated_by=snapshot.get("generated_by"),
                model_name=snapshot.get("model_name"),
            )
        else:
            record = get_day(db, user_id, day)
            if record is not None:
                db.delete(record)
    db.flush()
    return {"restored": True, "week_start": payload.get("week_start")}
