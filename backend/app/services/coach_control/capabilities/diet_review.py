"""Deterministic daily diet review.

Answers "今天吃了多少 / 还缺什么" from logged food and the active target,
without calling a model. The result is an insight card, never a write.
"""

from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import FoodLog, MealPlan, Profile, utcnow
from ...diet import calculate_targets
from ...queries import active_goal
from ..registry import Capability, register

DIET_TZ = timezone(timedelta(hours=8))
MEAL_LABELS = {
    "breakfast": "早餐",
    "lunch": "午餐",
    "dinner": "晚餐",
    "snack": "加餐",
}

CAPABILITY = register(
    Capability(
        id="diet.review_day",
        domain="diet",
        kind="read",
        title="今日饮食复盘",
        description="汇总当天摄入、目标差和蛋白质缺口，只读",
        requires_confirmation=False,
        undo=False,
        events=("DietDayReviewed",),
    )
)


def _day_label(value: date, today: date) -> str:
    if value == today:
        return "今天"
    if value == today - timedelta(days=1):
        return "昨天"
    if value == today - timedelta(days=2):
        return "前天"
    return f"{value.month}月{value.day}日"


def _targets(
    db: Session,
    user_id: str,
    profile: Profile | None,
    target_date: date,
) -> dict:
    plan = db.execute(
        select(MealPlan)
        .where(
            MealPlan.user_id == user_id,
            MealPlan.plan_date <= target_date,
        )
        .order_by(MealPlan.plan_date.desc())
    ).scalars().first()
    if plan is None:
        plan = db.execute(
            select(MealPlan)
            .where(
                MealPlan.user_id == user_id,
                MealPlan.plan_date > target_date,
            )
            .order_by(MealPlan.plan_date.asc())
        ).scalars().first()
    if plan is not None and plan.target_kcal:
        return {
            "target_kcal": int(plan.target_kcal),
            "protein_g": float(plan.target_protein_g or 0),
            "carb_g": float(plan.target_carb_g or 0),
            "fat_g": float(plan.target_fat_g or 0),
        }
    if profile is None:
        return {
            "target_kcal": 2000,
            "protein_g": 110,
            "carb_g": 220,
            "fat_g": 65,
        }
    goal = active_goal(db, user_id)
    calculated = calculate_targets(profile, goal.type if goal else "maintain")
    return {
        "target_kcal": calculated["target_kcal"],
        "protein_g": calculated["protein_g"],
        "carb_g": calculated["carb_g"],
        "fat_g": calculated["fat_g"],
    }


def parse_target_date(message: str) -> date:
    today = datetime.now(DIET_TZ).date()
    if "前天" in message:
        return today - timedelta(days=2)
    if "昨天" in message:
        return today - timedelta(days=1)
    return today


def resolve(db: Session, user_id: str, message: str) -> dict:
    target_date = parse_target_date(message)
    profile = db.get(Profile, user_id)
    targets = _targets(db, user_id, profile, target_date)
    start = datetime.combine(
        target_date, time.min, tzinfo=DIET_TZ
    ).astimezone(timezone.utc)
    end = datetime.combine(
        target_date + timedelta(days=1), time.min, tzinfo=DIET_TZ
    ).astimezone(timezone.utc)
    logs = (
        db.execute(
            select(FoodLog)
            .where(
                FoodLog.user_id == user_id,
                FoodLog.logged_at >= start,
                FoodLog.logged_at < end,
            )
            .order_by(FoodLog.logged_at.asc())
        )
        .scalars()
        .all()
    )
    actual_kcal = sum(float(log.kcal or 0) for log in logs)
    actual_protein = sum(float(log.protein or 0) for log in logs)
    actual_carbs = sum(float(log.carbs or 0) for log in logs)
    actual_fat = sum(float(log.fat or 0) for log in logs)
    meals = sorted({log.meal for log in logs if log.meal})
    meal_names = "、".join(MEAL_LABELS.get(item, item) for item in meals)

    plan = db.execute(
        select(MealPlan).where(
            MealPlan.user_id == user_id,
            MealPlan.plan_date == target_date,
        )
    ).scalar_one_or_none()
    skipped = [
        MEAL_LABELS.get(str(item), str(item))
        for item in (((plan.plan if plan else {}) or {}).get("skipped_meals") or [])
        if item
    ]

    today = datetime.now(DIET_TZ).date()
    label = _day_label(target_date, today)
    target_kcal = targets["target_kcal"]
    target_protein = targets["protein_g"]

    watchouts: list[str] = []
    if not logs:
        summary = f"{label}还没有饮食记录，先记一餐再复盘。"
        wins: list[str] = []
        watchouts.append("记录一餐后，我可以按热量和蛋白质帮你算缺口。")
    else:
        remaining = target_kcal - actual_kcal
        direction = "还差" if remaining >= 0 else "超出"
        summary = (
            f"{label}记录了 {len(meals)} 餐（{meal_names}），"
            f"约 {actual_kcal:.0f} kcal；目标 {target_kcal} kcal，"
            f"{direction} {abs(remaining):.0f} kcal。"
            f"蛋白质 {actual_protein:.0f}/{target_protein:.0f} g。"
        )
        wins = [
            f"热量 {actual_kcal:.0f} kcal",
            f"蛋白质 {actual_protein:.0f} g",
            f"碳水 {actual_carbs:.0f} g · 脂肪 {actual_fat:.0f} g",
        ]
        if target_protein and actual_protein < target_protein * 0.8:
            watchouts.append("蛋白质还偏低，下一餐优先补一个掌心大小的蛋白质食物。")
        if target_kcal and actual_kcal > target_kcal * 1.1:
            watchouts.append("摄入超出目标 10% 以上，先检查加餐、饮料和烹饪油。")
        elif target_kcal and actual_kcal < target_kcal * 0.7:
            watchouts.append("摄入明显低于目标，先确认有没有漏记。")
        if skipped:
            watchouts.append(
                "今天跳过：" + "、".join(skipped) + "；如果是有意安排，不用补。"
            )

    return {
        "ready": True,
        "payload": {
            "date": target_date.isoformat(),
            "summary": summary,
            "wins": wins,
            "watchouts": watchouts,
            "actions": [],
            "generated_at": utcnow().isoformat(),
        },
    }
