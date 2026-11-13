"""Deterministic diet-plan execution review.

The review compares what the meal plan asked for with what the user actually
logged. It deliberately uses the soft `plan_date` / `plan_meal` link instead of
guessing from food names: a user can eat the same lunch without following the
plan, and that should not count as completed.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from .diet import ensure_meal_macros

DIET_TZ = timezone(timedelta(hours=8))
MEAL_LABELS = {
    "breakfast": "早餐",
    "lunch": "午餐",
    "dinner": "晚餐",
    "snack": "加餐",
}


def _log_date(log) -> date:
    value = log.logged_at
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(DIET_TZ).date()


def _meal_macros(meal: dict) -> tuple[float, float]:
    return (
        float(meal.get("kcal") or 0),
        float(meal.get("protein_g") or 0),
    )


def build_diet_review(
    plans,
    logs,
    date_from: date,
    date_to: date,
    *,
    today: date | None = None,
) -> dict:
    plan_by_day = {
        plan.plan_date: ensure_meal_macros(plan.plan or {})
        for plan in plans
        if getattr(plan, "plan", None)
    }
    logs_by_day: dict[date, list] = {}
    for log in logs:
        logs_by_day.setdefault(_log_date(log), []).append(log)

    logged_plan_meals: dict[date, set[str]] = {}
    for day, day_logs in logs_by_day.items():
        keys = {
            log.plan_meal
            for log in day_logs
            if getattr(log, "plan_date", None) == day and getattr(log, "plan_meal", None)
        }
        logged_plan_meals[day] = keys

    days = []
    missing_meals = []
    planned_meals_total = 0
    eligible_meals_total = 0
    skipped_meals_total = 0
    logged_meals_total = 0
    planned_kcal_total = 0.0
    actual_kcal_total = 0.0
    planned_protein_total = 0.0
    actual_protein_total = 0.0

    # A current-week review must not call Thursday-Sunday meals "missing" on
    # Monday. Future plans stay out of the denominator until their day arrives.
    review_end = min(date_to, today or date.today())

    current = date_from
    while current <= review_end:
        plan = plan_by_day.get(current)
        day_logs = logs_by_day.get(current, [])
        actual_kcal = sum(float(log.kcal or 0) for log in day_logs)
        actual_protein = sum(float(log.protein or 0) for log in day_logs)
        actual_kcal_total += actual_kcal
        actual_protein_total += actual_protein

        if plan is None and not day_logs:
            current += timedelta(days=1)
            continue

        meals = [meal for meal in (plan or {}).get("meals", []) if isinstance(meal, dict)]
        skipped = {
            str(value) for value in (plan or {}).get("skipped_meals", []) if value
        }
        active_meals = [meal for meal in meals if str(meal.get("meal")) not in skipped]
        planned_kcal = sum(_meal_macros(meal)[0] for meal in active_meals)
        planned_protein = sum(_meal_macros(meal)[1] for meal in active_meals)
        planned_meals = len(meals)
        eligible_meals = len(active_meals)
        logged_meals = len(logged_plan_meals.get(current, set()) & {
            str(meal.get("meal")) for meal in active_meals
        })

        planned_meals_total += planned_meals
        eligible_meals_total += eligible_meals
        skipped_meals_total += len(skipped)
        logged_meals_total += logged_meals
        planned_kcal_total += planned_kcal
        planned_protein_total += planned_protein

        for meal in active_meals:
            key = str(meal.get("meal") or "")
            if key in logged_plan_meals.get(current, set()):
                continue
            missing_meals.append(
                {
                    "date": current.isoformat(),
                    "meal": key,
                    "name": str(meal.get("name") or MEAL_LABELS.get(key, key)),
                    "kcal": round(float(meal.get("kcal") or 0)),
                }
            )

        if not day_logs:
            status = "no_log"
        elif planned_kcal <= 0:
            status = "no_plan"
        elif actual_kcal < planned_kcal * 0.85:
            status = "under"
        elif actual_kcal > planned_kcal * 1.15:
            status = "over"
        else:
            status = "on_track"

        days.append(
            {
                "date": current.isoformat(),
                "planned_meals": planned_meals,
                "skipped_meals": len(skipped),
                "logged_plan_meals": logged_meals,
                "planned_kcal": round(planned_kcal),
                "actual_kcal": round(actual_kcal),
                "planned_protein_g": round(planned_protein),
                "actual_protein_g": round(actual_protein),
                "status": status,
            }
        )
        current += timedelta(days=1)

    adherence = (
        logged_meals_total / eligible_meals_total
        if eligible_meals_total
        else None
    )
    return {
        "from": date_from.isoformat(),
        "to": date_to.isoformat(),
        "totals": {
            "planned_days": sum(1 for day in days if day["planned_meals"] > 0),
            "planned_meals": planned_meals_total,
            "eligible_meals": eligible_meals_total,
            "skipped_meals": skipped_meals_total,
            "logged_plan_meals": logged_meals_total,
            "adherence_rate": round(adherence, 2) if adherence is not None else None,
            "planned_kcal": round(planned_kcal_total),
            "actual_kcal": round(actual_kcal_total),
            "planned_protein_g": round(planned_protein_total),
            "actual_protein_g": round(actual_protein_total),
        },
        "days": days,
        "missing_meals": missing_meals[:12],
        "insight": _insight(
            planned_meals_total=planned_meals_total,
            eligible_meals_total=eligible_meals_total,
            skipped_meals_total=skipped_meals_total,
            logged_meals_total=logged_meals_total,
            missing_count=len(missing_meals),
            planned_kcal=planned_kcal_total,
            actual_kcal=actual_kcal_total,
            planned_protein=planned_protein_total,
            actual_protein=actual_protein_total,
            has_logs=bool(logs_by_day),
        ),
    }


def _insight(
    *,
    planned_meals_total: int,
    eligible_meals_total: int,
    skipped_meals_total: int,
    logged_meals_total: int,
    missing_count: int,
    planned_kcal: float,
    actual_kcal: float,
    planned_protein: float,
    actual_protein: float,
    has_logs: bool,
) -> str:
    if planned_meals_total == 0:
        return "这段时间还没有保存的饮食计划。先让教练排一周餐单，再回来看计划执行。"
    if not has_logs:
        return "有饮食计划，但这段时间还没有任何饮食记录。先做到每天记录一餐。"
    if eligible_meals_total == 0:
        return f"这期 {skipped_meals_total} 餐都标记了跳过。如果这是主动安排，可以重新调整下周餐次。"
    if logged_meals_total == 0:
        return "还没有用「整餐」记录计划餐；手动记录也算摄入，但无法判断是哪一餐按计划执行。"
    adherence = logged_meals_total / eligible_meals_total
    if adherence < 0.5:
        return f"计划餐只记录了 {logged_meals_total}/{eligible_meals_total} 餐（另跳过 {skipped_meals_total} 餐）。先把最容易执行的一餐固定下来，不要一次要求全部做到。"
    if missing_count >= 3:
        return f"有 {missing_count} 餐计划没有记录。先补看最常漏掉的那一餐，是时间不够还是餐单不合适。"
    if planned_kcal > 0 and actual_kcal > planned_kcal * 1.10:
        return "实际摄入高于计划约 10% 以上。先检查加餐、饮料和烹饪油，不必直接砍掉正餐。"
    if planned_kcal > 0 and actual_kcal < planned_kcal * 0.80:
        return "实际摄入明显低于计划。先确认是否有漏记；长期吃不够会影响训练恢复。"
    if planned_protein > 0 and actual_protein < planned_protein * 0.80:
        return "蛋白质低于计划。下一餐优先补一个掌心大小的蛋白质食物。"
    return "计划执行稳定。下周保持餐次结构，只需要微调份量，不需要整周重排。"


def range_bounds(
    date_from: date | None,
    date_to: date | None,
    *,
    today: date | None = None,
) -> tuple[date, date]:
    end = date_to or today or date.today()
    start = date_from or (end - timedelta(days=6))
    if start > end:
        raise ValueError("开始日期不能晚于结束日期")
    if (end - start).days > 366:
        raise ValueError("一次最多查看 366 天")
    return start, end


def utc_window(date_from: date, date_to: date) -> tuple[datetime, datetime]:
    start = datetime.combine(date_from, datetime.min.time(), DIET_TZ)
    end = datetime.combine(date_to + timedelta(days=1), datetime.min.time(), DIET_TZ)
    return start.astimezone(timezone.utc), end.astimezone(timezone.utc)
