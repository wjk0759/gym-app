"""Read-only preview of the next planned workout.

The client already owns the concrete schedule (including reschedules), so this
capability reads the plan snapshot from ``app_context`` and only enriches it
with exercise targets and the last logged weight.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import ProgramDay, SetLog, WorkoutSession, utcnow
from ..registry import Capability, register

DIET_TZ = timezone(timedelta(hours=8))

CAPABILITY = register(
    Capability(
        id="training.preview_next",
        domain="training",
        kind="read",
        title="下一练预览",
        description="读取下一节未完成训练，列出动作、组次和上次重量",
        requires_confirmation=False,
        undo=False,
        events=("TrainingPreviewed",),
    )
)


def _day_label(value: str, today: date) -> str:
    try:
        target = datetime.fromisoformat(value).date()
    except ValueError:
        return value
    if target == today:
        return f"今天（{target.month}月{target.day}日）"
    if target == today + timedelta(days=1):
        return f"明天（{target.month}月{target.day}日）"
    weekday = "一二三四五六日"[target.weekday()]
    return f"周{weekday}（{target.month}月{target.day}日）"


def _last_weight(db: Session, user_id: str, slug: str) -> float | None:
    return db.execute(
        select(SetLog.weight_kg)
        .join(WorkoutSession, SetLog.session_id == WorkoutSession.id)
        .where(
            WorkoutSession.user_id == user_id,
            SetLog.exercise_slug == slug,
            SetLog.weight_kg.is_not(None),
        )
        .order_by(WorkoutSession.started_at.desc())
        .limit(1)
    ).scalar_one_or_none()


def _exercise_lines(db: Session, user_id: str, day_id: str) -> list[str]:
    day = db.get(ProgramDay, day_id)
    if day is None:
        return []
    lines: list[str] = []
    exercises = sorted(day.exercises, key=lambda item: item.order_index)
    for item in exercises[:8]:
        name = item.exercise.name_zh if item.exercise else item.exercise_slug
        line = f"{name} {item.sets} 组 × {item.reps}"
        last = _last_weight(db, user_id, item.exercise_slug)
        if last is not None:
            line += f"，上次 {float(last):.1f} kg"
        lines.append(line)
    return lines


def resolve(db: Session, user_id: str, context: dict) -> dict:
    plan = context.get("plan") if isinstance(context, dict) else None
    days = plan.get("days") if isinstance(plan, dict) else None
    today = datetime.now(DIET_TZ).date()
    if not isinstance(days, list) or not days:
        return {
            "ready": True,
            "payload": {
                "summary": "现在还没有训练计划，先让教练生成一份。",
                "wins": [],
                "watchouts": ["没有计划时，先生成 4 周计划再开始训练。"],
                "actions": [],
                "generated_at": utcnow().isoformat(),
            },
        }

    candidates = [
        item
        for item in days
        if isinstance(item, dict)
        and not item.get("completed")
        and not item.get("skipped")
        and str(item.get("date") or "") >= today.isoformat()
    ]
    if not candidates:
        return {
            "ready": True,
            "payload": {
                "summary": "当前计划里的训练都完成了，剩下的是恢复。",
                "wins": [],
                "watchouts": ["如果还想加练，优先补有氧或核心，不要连续加同一部位。"],
                "actions": [],
                "generated_at": utcnow().isoformat(),
            },
        }

    candidates.sort(key=lambda item: str(item.get("date") or ""))
    next_day = candidates[0]
    title = str(next_day.get("title") or "训练")
    label = _day_label(str(next_day.get("date") or ""), today)
    summary = f"下一练是{label}：{title}。"
    lines = _exercise_lines(db, user_id, str(next_day.get("id") or ""))
    watchouts: list[str] = []
    if not lines:
        watchouts.append("这份计划还没有动作明细，打开训练手账确认。")
    if label.startswith("今天"):
        watchouts.append("今天就是训练日，先热身再上重量。")
    if len(lines) >= 6:
        watchouts.append("动作较多，优先完成前 4 个复合动作。")

    return {
        "ready": True,
        "payload": {
            "summary": summary,
            "wins": lines,
            "watchouts": watchouts,
            "actions": [],
            "generated_at": utcnow().isoformat(),
        },
    }
