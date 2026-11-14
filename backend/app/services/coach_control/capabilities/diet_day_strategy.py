"""Change one day's diet strategy without regenerating the whole week."""

from __future__ import annotations

from datetime import date, datetime
from zoneinfo import ZoneInfo

from fastapi import HTTPException
from sqlalchemy.orm import Session

from ....models import Profile
from ... import access
from ...diet import DIET_STRATEGIES, build_ai_diet_week
from ...meal_plans import get_day, save_day_plan, week_start_for
from ...queries import active_goal, active_program
from ...rate_limit import enforce as enforce_rate_limit
from ..registry import Capability, register
from .diet_week import _strategy
from .training import parse_training_date

CAPABILITY = register(
    Capability(
        id="diet.edit_day_strategy",
        domain="diet",
        kind="write",
        title="调整单日饮食策略",
        description="把某一天的餐单改为指定策略，确认后保存",
        requires_confirmation=True,
        undo=True,
        events=("DietPlanGenerated",),
    )
)


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
                "调整饮食策略需要 Pro 或首次试用；你可以继续记录饮食，或问我建议。"
            ],
        }
    try:
        enforce_rate_limit(db, "coach_diet_day", user_id, 6, 600)
    except HTTPException:
        return {
            "ready": False,
            "questions": ["饮食策略调整有点频繁，十分钟后再试。"],
        }

    strategy_id = _strategy(message)
    strategy = DIET_STRATEGIES.get(strategy_id, DIET_STRATEGIES["balanced"])
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    target = parse_training_date(message, today=today) or today
    week_start = week_start_for(target)
    goal = active_goal(db, user_id)
    program = active_program(db, user_id)
    training_days = (
        sorted({int(day.weekday) for day in program.days if day.week_index == 1})
        if program is not None
        else None
    ) or None
    week = await build_ai_diet_week(
        db,
        profile,
        goal.type if goal is not None else "recomp",
        strategy_id,
        week_start,
        training_days,
    )
    plan = None
    for day in week.get("days") or []:
        if isinstance(day, dict) and str(day.get("date")) == target.isoformat():
            plan = day
            break
    if plan is None:
        return {"ready": False, "questions": ["没有找到这一天的餐单，稍后再试。"]}
    plan["generated_by"] = week.get("generated_by")
    if week.get("warning"):
        plan["warning"] = week["warning"]

    targets = plan.get("targets") or {}
    meals = [item for item in plan.get("meals") or [] if isinstance(item, dict)]
    watchouts = []
    if week.get("warning"):
        watchouts.append(str(week["warning"]))
    if strategy.caution:
        watchouts.append(strategy.caution)
    return {
        "ready": True,
        "payload": {
            "date": target.isoformat(),
            "strategy": strategy_id,
            "access_mode": access_mode,
            "plan": plan,
            "model": week.get("model"),
            "summary": (
                f"准备把 {target.month}月{target.day}日 的餐单改为"
                f"「{strategy.label}」，约 {targets.get('target_kcal') or '—'} kcal。"
            ),
            "wins": [
                f"{meal.get('name') or meal.get('meal')}："
                f"{meal.get('kcal') or 0} kcal"
                for meal in meals
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
    target = date.fromisoformat(str(payload["date"]))
    previous = _snapshot(get_day(db, user_id, target))
    plan = payload.get("plan") or {}
    save_day_plan(
        db,
        user_id,
        target,
        plan,
        strategy=str(payload.get("strategy") or "balanced"),
        generated_by=plan.get("generated_by"),
        model_name=payload.get("model"),
    )
    if payload.get("access_mode") == "trial":
        access.consume_trial(
            db,
            user_id,
            access.FEATURE_MEAL_PLAN,
            source="coach_day_strategy",
            result_ref=target.isoformat(),
        )
    return {
        "date": target.isoformat(),
        "before": {"previous": previous},
        "target_kcal": (plan.get("targets") or {}).get("target_kcal"),
    }


def undo(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    target = date.fromisoformat(str(payload["date"]))
    previous = before.get("previous") if isinstance(before, dict) else None
    if isinstance(previous, dict) and previous.get("plan"):
        save_day_plan(
            db,
            user_id,
            target,
            previous["plan"],
            strategy=previous.get("strategy"),
            generated_by=previous.get("generated_by"),
            model_name=previous.get("model_name"),
        )
        restored = True
    else:
        record = get_day(db, user_id, target)
        if record is not None:
            db.delete(record)
            db.flush()
        restored = False
    return {"date": target.isoformat(), "restored": restored}
