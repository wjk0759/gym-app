"""Diet-plan generation capability.

The model produces a draft; the user confirms before it is saved. A generated
plan can overwrite an existing day plan, and undo restores the previous one.
"""

from __future__ import annotations

from datetime import date

from fastapi import HTTPException
from sqlalchemy.orm import Session

from ....models import MealPlan, Profile
from ... import access
from ...diet import build_ai_plan
from ...food_text import food_log_context
from ...meal_plans import get_day, save_day_plan
from ...queries import active_goal
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="diet.generate_day",
        domain="diet",
        kind="write",
        title="生成饮食计划",
        description="按目标生成一天餐单，确认后保存",
        requires_confirmation=True,
        undo=True,
        events=("DietPlanGenerated",),
    )
)


def _summary(plan: dict, plan_date: date) -> str:
    targets = plan.get("targets") or {}
    meals = plan.get("meals") or []
    names = "、".join(
        str(meal.get("name") or meal.get("meal") or "")
        for meal in meals
        if isinstance(meal, dict)
    )
    return (
        f"{plan_date.month}月{plan_date.day}日饮食草案："
        f"约 {targets.get('target_kcal') or '—'} kcal，"
        f"{targets.get('protein_g') or '—'} g 蛋白质。"
        + (f"包含{names}。" if names else "")
    )


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
                "饮食计划生成需要 Pro 或首次试用；你可以先记录饮食，或继续问我建议。"
            ],
        }

    plan_date = date.fromisoformat(food_log_context(message)["date"])
    goal = active_goal(db, user_id)
    plan = await build_ai_plan(
        db,
        profile,
        goal.type if goal is not None else "recomp",
        plan_date,
    )
    if access_mode == "trial":
        access.consume_trial(
            db,
            user_id,
            access.FEATURE_MEAL_PLAN,
            source="coach_generation",
            result_ref=plan_date.isoformat(),
        )
    targets = plan.get("targets") or {}
    watchouts = []
    if plan.get("warning"):
        watchouts.append(str(plan["warning"]))
    return {
        "ready": True,
        "payload": {
            "date": plan_date.isoformat(),
            "diet_plan": plan,
            "strategy": plan.get("strategy") or "balanced",
            "access_mode": access_mode,
            "summary": _summary(plan, plan_date),
            "wins": [
                f"{meal.get('name') or meal.get('meal')}："
                f"{meal.get('kcal') or 0} kcal"
                for meal in (plan.get("meals") or [])
                if isinstance(meal, dict)
            ],
            "watchouts": watchouts,
            "actions": [],
            "target_kcal": targets.get("target_kcal"),
        },
    }


def _snapshot(record: MealPlan | None) -> dict | None:
    if record is None:
        return None
    return {
        "plan": record.plan,
        "strategy": record.strategy,
        "generated_by": record.generated_by,
        "model_name": record.model_name,
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    plan_date = date.fromisoformat(str(payload["date"]))
    previous = _snapshot(get_day(db, user_id, plan_date))
    plan = payload.get("diet_plan") or {}
    save_day_plan(
        db,
        user_id,
        plan_date,
        plan,
        strategy=str(payload.get("strategy") or "balanced"),
        generated_by=plan.get("generated_by"),
        model_name=plan.get("model"),
    )
    return {
        "date": plan_date.isoformat(),
        "before": {"previous": previous},
        "target_kcal": (plan.get("targets") or {}).get("target_kcal"),
    }


def undo(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    plan_date = date.fromisoformat(str(payload["date"]))
    previous = before.get("previous") if isinstance(before, dict) else None
    record = get_day(db, user_id, plan_date)
    if isinstance(previous, dict) and previous.get("plan"):
        save_day_plan(
            db,
            user_id,
            plan_date,
            previous["plan"],
            strategy=previous.get("strategy"),
            generated_by=previous.get("generated_by"),
            model_name=previous.get("model_name"),
        )
        restored = True
    else:
        if record is not None:
            db.delete(record)
            db.flush()
        restored = False
    return {
        "restored": restored,
        "date": plan_date.isoformat(),
    }
