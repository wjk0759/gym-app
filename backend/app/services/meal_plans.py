"""Meal-plan persistence and week metadata.

`meal_plans` stores one calendar day per row. Week-level provenance (strategy,
generation mode, model, warning) is copied onto each row so reads do not need
to parse the plan JSON to infer it.
"""

from __future__ import annotations

from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import MealPlan

DEFAULT_STRATEGY = "balanced"


def week_start_for(day: date) -> date:
    return day - timedelta(days=day.weekday())


def _targets(plan: dict) -> dict:
    return plan.get("targets") or {}


def save_day_plan(
    db: Session,
    user_id: str,
    plan_date: date,
    plan: dict,
    *,
    strategy: str | None,
    generated_by: str | None,
    model_name: str | None = None,
) -> MealPlan:
    """Upsert one day; callers own the transaction and retry on races."""
    record = db.execute(
        select(MealPlan).where(
            MealPlan.user_id == user_id,
            MealPlan.plan_date == plan_date,
        )
    ).scalar_one_or_none()
    if record is None:
        record = MealPlan(user_id=user_id, plan_date=plan_date)
        db.add(record)

    targets = _targets(plan)
    record.week_start = week_start_for(plan_date)
    record.strategy = (strategy or DEFAULT_STRATEGY)[:30]
    record.generated_by = (generated_by or "template")[:20]
    record.model_name = (model_name or "")[:80] or None
    record.target_kcal = targets.get("target_kcal")
    record.target_protein_g = targets.get("protein_g")
    record.target_carb_g = targets.get("carb_g")
    record.target_fat_g = targets.get("fat_g")
    record.plan = plan
    return record


def list_week(db: Session, user_id: str, start: date) -> list[MealPlan]:
    end = start + timedelta(days=6)
    return list(
        db.execute(
            select(MealPlan)
            .where(
                MealPlan.user_id == user_id,
                MealPlan.plan_date >= start,
                MealPlan.plan_date <= end,
            )
            .order_by(MealPlan.plan_date)
        )
        .scalars()
        .all()
    )


def week_summary(rows: list[MealPlan]) -> dict:
    generated_by = next((row.generated_by for row in rows if row.generated_by), None)
    warning = next(
        (
            (row.plan or {}).get("warning")
            for row in rows
            if isinstance(row.plan, dict) and (row.plan or {}).get("warning")
        ),
        None,
    )
    strategy = next((row.strategy for row in rows if row.strategy), None)
    model_name = next((row.model_name for row in rows if row.model_name), None)
    return {
        "generated_by": generated_by,
        "warning": warning,
        "strategy": strategy,
        "model": model_name,
    }
