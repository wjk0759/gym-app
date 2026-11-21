"""Per-exercise progression for the next plan week.

The weekly review already looks at global load. This module answers the more
specific question: "for this exercise, should next week be heavier, lighter or
the same?" It reads the last session for each planned exercise, compares RPE
and rep completion with the plan's target range, and builds either:

- a read-only summary for coach answers and weekly review;
- one confirmation card that updates the next week's plan through the existing
  ``training.edit_day_exercise`` capability.

Nothing writes until the user confirms. The adjustment is deliberately small
(2.5% up, 5% down) and rounded to a realistic plate/dumbbell increment.
"""

from __future__ import annotations

import re
from datetime import date, datetime, timedelta
from statistics import mean

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import (
    PlanDayState,
    PlanExercise,
    Program,
    ProgramDay,
    SetLog,
    WorkoutSession,
)
from ..food_text import DIET_TZ

LOOKBACK_DAYS = 28
UP_RATE = 1.025
DOWN_RATE = 0.95
MAX_PROGRESSION_DAYS = 5


def _snapshot(day: ProgramDay) -> list[dict]:
    return [
        {
            "id": item.id,
            "order_index": item.order_index,
            "slug": item.exercise_slug,
            "sets": item.sets,
            "reps": item.reps,
            "weight_kg": item.weight_kg,
            "rest_sec": item.rest_sec,
            "rpe": item.rpe,
            "notes": item.notes,
        }
        for item in sorted(day.exercises, key=lambda row: row.order_index)
    ]


def _rep_range(value: str | None) -> tuple[int, int]:
    numbers = [int(item) for item in re.findall(r"\d+", value or "")]
    if len(numbers) >= 2:
        return numbers[0], numbers[1]
    if len(numbers) == 1:
        return numbers[0], numbers[0]
    return 8, 12


def _round_load(value: float, equipment: str | None) -> float:
    step = 2.5 if equipment in {"barbell", "machine", "cable"} else 1.0
    return round(value / step) * step


def _recent_performance(
    db: Session,
    user_id: str,
    slugs: set[str],
    since: datetime,
) -> dict[str, dict]:
    if not slugs:
        return {}
    rows = db.execute(
        select(SetLog, WorkoutSession.started_at)
        .join(WorkoutSession, SetLog.session_id == WorkoutSession.id)
        .where(
            WorkoutSession.user_id == user_id,
            WorkoutSession.started_at >= since,
            SetLog.exercise_slug.in_(slugs),
            SetLog.completed.is_(True),
        )
        .order_by(WorkoutSession.started_at, SetLog.set_index)
    ).all()
    by_slug: dict[str, list[tuple[SetLog, datetime]]] = {}
    for item, started_at in rows:
        by_slug.setdefault(item.exercise_slug, []).append((item, started_at))
    result: dict[str, dict] = {}
    for slug, entries in by_slug.items():
        latest_date = max(started_at for _, started_at in entries)
        latest = [
            (item, started_at)
            for item, started_at in entries
            if started_at == latest_date
        ]
        reps = [int(item.reps or 0) for item, _ in latest]
        rpes = [
            float(item.rpe)
            for item, _ in latest
            if item.rpe is not None
        ]
        weights = [
            float(item.weight_kg)
            for item, _ in latest
            if item.weight_kg is not None
        ]
        result[slug] = {
            "reps": reps,
            "average_rpe": round(mean(rpes), 1) if rpes else None,
            "weight_kg": max(weights) if weights else None,
            "session_date": latest_date.astimezone(DIET_TZ).date().isoformat(),
        }
    return result


def _next_week(program: Program, today: date) -> int:
    if program.start_date is None:
        return 1
    if today < program.start_date:
        return 1
    elapsed = (today - program.start_date).days
    current = max(1, elapsed // 7 + 1)
    return min(int(program.weeks or 4), current) + 1


def _day_date(
    db: Session,
    user_id: str,
    program: Program,
    day: ProgramDay,
) -> str:
    state = db.execute(
        select(PlanDayState).where(
            PlanDayState.user_id == user_id,
            PlanDayState.plan_id == program.id.lower(),
            PlanDayState.day_id == day.id.lower(),
        )
    ).scalar_one_or_none()
    if state is not None and state.assigned_date is not None:
        return state.assigned_date.isoformat()
    start = program.start_date or date.today()
    offset = (int(day.weekday) - start.isoweekday()) % 7
    return (
        start + timedelta(days=(day.week_index - 1) * 7 + offset)
    ).isoformat()


def _recommend(
    item: PlanExercise,
    performance: dict | None,
) -> dict:
    current = item.weight_kg
    exercise = item.exercise
    name = exercise.name_zh if exercise else item.exercise_slug
    equipment = exercise.equipment if exercise else None
    base = {
        "slug": item.exercise_slug,
        "name": name,
        "current_weight_kg": current,
        "target_weight_kg": current,
        "action": "hold",
    }
    if current is None or float(current) <= 0 or performance is None:
        base["reason"] = "没有可用重量或记录"
        return base
    bottom, top = _rep_range(item.reps)
    reps = performance.get("reps") or []
    avg_rpe = performance.get("average_rpe")
    if not reps:
        base["reason"] = "上一轮没有完成次数"
        return base
    if (avg_rpe is not None and avg_rpe >= 9) or min(reps) < bottom:
        target = _round_load(float(current) * DOWN_RATE, equipment)
        base.update(
            {
                "target_weight_kg": target,
                "action": "down",
                "reason": (
                    f"上一组 RPE {avg_rpe}" if avg_rpe is not None else "次数低于目标"
                ),
            }
        )
    elif avg_rpe is not None and avg_rpe <= 8 and max(reps) >= top:
        target = _round_load(float(current) * UP_RATE, equipment)
        base.update(
            {
                "target_weight_kg": target,
                "action": "up",
                "reason": f"上一组 RPE {avg_rpe}，次数到 {max(reps)}",
            }
        )
    else:
        base["reason"] = (
            f"上一组 RPE {avg_rpe}" if avg_rpe is not None else "还没记录 RPE"
        )
    base["rep_target"] = f"{bottom}-{top}" if bottom != top else str(bottom)
    return base


def build_plan(
    db: Session,
    user_id: str,
    program: Program | None,
) -> dict:
    """Return next-week per-exercise targets and day-edit payloads."""
    if program is None:
        return {
            "ready": False,
            "terminal": True,
            "question": "还没有训练计划；先生成计划才能做按动作进阶。",
        }
    today = datetime.now(DIET_TZ).date()
    next_week = _next_week(program, today)
    if next_week > int(program.weeks or 4):
        return {
            "ready": False,
            "terminal": True,
            "question": "这已经是计划最后一周；先完成本周，之后重新生成或调整计划。",
        }
    days = [
        day
        for day in program.days
        if day.week_index == next_week
    ]
    if not days:
        return {
            "ready": False,
            "terminal": True,
            "question": "计划里没有下一周的明细，先同步计划再试。",
        }
    slugs = {item.exercise_slug for day in days for item in day.exercises}
    since = datetime.now(DIET_TZ) - timedelta(days=LOOKBACK_DAYS)
    performance = _recent_performance(db, user_id, slugs, since)

    targets: list[dict] = []
    actions: list[dict] = []
    for day in sorted(days, key=lambda item: item.weekday):
        before = _snapshot(day)
        adjusted: list[dict] = []
        changed = False
        wins: list[str] = []
        for item in sorted(day.exercises, key=lambda row: row.order_index):
            value = dict(next(row for row in before if row["id"] == item.id))
            # Progression currently only owns weighted strength work. Mobility,
            # bodyweight and cardio rows should not flood the weekly review.
            if item.weight_kg is None or float(item.weight_kg) <= 0:
                adjusted.append(value)
                continue
            target = _recommend(item, performance.get(item.exercise_slug))
            targets.append(target)
            if target["action"] in {"up", "down"} and target["target_weight_kg"]:
                value["weight_kg"] = target["target_weight_kg"]
                changed = True
                arrow = "↑" if target["action"] == "up" else "↓"
                wins.append(
                    f"{target['name']} {float(target['current_weight_kg']):g}"
                    f"→{float(target['target_weight_kg']):g}kg {arrow}"
                )
            adjusted.append(value)
        if not changed:
            continue
        date_label = _day_date(db, user_id, program, day)
        summary = (
            f"下周 {date_label} 的「{day.title}」："
            + "、".join(wins)
            + "。"
        )
        actions.append(
            {
                "capability_id": "training.edit_day_exercise",
                "payload": {
                    "plan_id": program.id,
                    "day_id": day.id,
                    "date": date_label,
                    "title": day.title,
                    "before": before,
                    "exercises": adjusted,
                    "summary": summary,
                    "wins": wins,
                    "watchouts": [],
                    "actions": [],
                },
                "summary": summary,
            }
        )

    if not actions:
        return {
            "ready": False,
            "terminal": True,
            "question": (
                "按最近 28 天的记录，下周先保持原重量。"
                "等主项稳定到目标次数、RPE 不超过 8，再加 2.5%。"
            ),
            "targets": targets,
        }
    truncated = max(0, len(actions) - MAX_PROGRESSION_DAYS)
    actions = actions[:MAX_PROGRESSION_DAYS]
    lines = "；".join(
        f"{item['name']} {item['current_weight_kg']}→{item['target_weight_kg']}kg"
        for item in targets
        if item["action"] in {"up", "down"}
    )
    return {
        "ready": True,
        "week_index": next_week,
        "targets": targets,
        "days": actions,
        "truncated": truncated,
        "summary": f"下周进阶建议：{lines}。",
    }


def resolve_apply(
    db: Session,
    user_id: str,
    program: Program | None,
) -> dict:
    """Build one confirmation card for all changed next-week days."""
    plan = build_plan(db, user_id, program)
    if not plan.get("ready"):
        return plan
    actions = plan["days"]
    reply = f"{plan['summary']} 确认后一次性写入下周计划，整组可撤销。"
    if plan.get("truncated"):
        reply += (
            f" 另外 {plan['truncated']} 天先保持原计划，"
            "下次可以再单独调整。"
        )
    return {
        "ready": True,
        "payload": {
            "summary": f"调整下周 {len(actions)} 天训练",
            "batch": actions,
            "reply": reply,
        },
        "reply": reply,
    }


def format_facts(plan: dict) -> str:
    """Turn progression targets into compact facts for the coach answer."""
    if not plan.get("ready"):
        return str(plan.get("question") or "暂时没有可用的进阶建议。")
    lines = [f"下周进阶建议（第 {plan['week_index']} 周）："]
    for item in (plan.get("targets") or [])[:8]:
        current = item.get("current_weight_kg")
        target = item.get("target_weight_kg")
        if item["action"] == "hold":
            weight = (
                f"{float(current):g}kg"
                if current is not None
                else "原重量"
            )
            lines.append(
                f"{item['name']}：保持 {weight}（{item.get('reason') or '先稳住'}）。"
            )
        else:
            arrow = "加" if item["action"] == "up" else "降"
            lines.append(
                f"{item['name']}：{current}→{target}kg，{arrow}；"
                f"目标 {item.get('rep_target')} 次。"
            )
    return "\n".join(lines)
