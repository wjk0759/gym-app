"""Add an extra workout day to the active plan.

Useful when the user wants to train on a rest day: "今天加一次练胸". Exercises are
copied from the nearest same-focus day unless the user supplies a list.
"""

from __future__ import annotations

import re
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import PlanExercise, Program, ProgramDay
from ...serializers import serialize_program
from ..registry import Capability, register
from .training import parse_training_date
from .training_edit import _resolve_exercise

CAPABILITY = register(
    Capability(
        id="training.add_plan_day",
        domain="training",
        kind="write",
        title="增加训练日",
        description="在休息日加一次训练，可沿用同部位动作",
        requires_confirmation=True,
        undo=True,
        events=("TrainingPlanAdjusted",),
    )
)

FOCUS = {
    "胸": ("胸", ["chest"]),
    "背": ("背", ["back"]),
    "腿": ("腿", ["legs", "glutes"]),
    "肩": ("肩", ["shoulders"]),
    "手臂": ("手臂", ["arms"]),
    "全身": ("全身", ["legs", "chest", "back", "shoulders", "arms"]),
    "上肢": ("上肢", ["chest", "back", "shoulders", "arms"]),
    "下肢": ("下肢", ["legs", "glutes"]),
}


def _focus(message: str) -> tuple[str, list[str]] | None:
    for label, value in FOCUS.items():
        if label in message:
            return value
    return None


def _exercise_names(message: str) -> list[str]:
    if not re.search(r"[：:]", message):
        return []
    tail = re.split(r"[：:]", message, maxsplit=1)[1]
    names = [
        item.strip(" 动作。.！!")
        for item in re.split(r"[、,，;；/]+", tail)
    ]
    return [item for item in names if item][:8]


def _week_index(program: Program, target: date) -> int:
    start = program.start_date or target
    monday = start - timedelta(days=start.weekday())
    week = (target - monday).days // 7 + 1
    return max(1, min(int(program.weeks or 1), week))


def _template_exercises(
    program: Program,
    focus_tokens: list[str],
    target: date,
) -> tuple[ProgramDay | None, list[dict]]:
    candidates = []
    for day in program.days:
        if not (set(day.focus or []) & set(focus_tokens)):
            continue
        start = program.start_date or target
        monday = start - timedelta(days=start.weekday())
        when = monday + timedelta(
            days=(int(day.week_index) - 1) * 7 + int(day.weekday) - 1
        )
        candidates.append((when, day))
    if not candidates:
        return None, []
    upcoming = [item for item in candidates if item[0] >= target]
    candidates.sort(key=lambda item: item[0])
    pool = upcoming or list(reversed(candidates))
    template = pool[0][1]
    exercises = [
        {
            "slug": item.exercise_slug,
            "sets": item.sets,
            "reps": item.reps,
            "weight_kg": item.weight_kg,
            "rest_sec": item.rest_sec,
            "rpe": item.rpe,
            "notes": item.notes,
        }
        for item in sorted(template.exercises, key=lambda row: row.order_index)
    ]
    return template, exercises


def resolve(
    db: Session,
    user_id: str,
    message: str,
    context: dict,
) -> dict:
    plan = context.get("plan") if isinstance(context, dict) else {}
    program = db.get(Program, str(plan.get("id") or ""))
    if program is None or program.user_id != user_id or program.status != "active":
        return {"ready": False, "questions": ["当前计划不在服务端，先在训练手账里同步计划。"]}
    focus = _focus(message)
    if focus is None:
        return {"ready": False, "questions": ["想加哪个部位？胸、背、腿、肩或手臂。"]}
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    target = parse_training_date(message, today=today) or today
    week_index = _week_index(program, target)
    existing = db.execute(
        select(ProgramDay).where(
            ProgramDay.program_id == program.id,
            ProgramDay.week_index == week_index,
            ProgramDay.weekday == target.isoweekday(),
        )
    ).scalar_one_or_none()
    if existing is not None:
        return {
            "ready": False,
            "questions": [
                f"{target.month}月{target.day}日已经有训练了，直接说要改哪些动作。"
            ],
        }

    label, tokens = focus
    names = _exercise_names(message)
    template = None
    if names:
        exercises = []
        for name in names:
            exercise, resolved_name = _resolve_exercise(db, name)
            if exercise is None:
                return {
                    "ready": False,
                    "questions": [f"没有找到「{name}」这个动作，换个说法试试。"],
                }
            exercises.append(
                {
                    "slug": exercise.slug,
                    "name": resolved_name,
                    "sets": 3,
                    "reps": "8-12",
                    "weight_kg": None,
                    "rest_sec": 90,
                    "rpe": 7.5,
                    "notes": None,
                }
            )
    else:
        template, exercises = _template_exercises(program, tokens, target)
        if not exercises:
            return {
                "ready": False,
                "questions": [
                    "想练哪些动作？例如“今天加一次练胸：杠铃卧推、上斜卧推”。"
                ],
            }
        for item in exercises:
            item["name"] = item["slug"]

    return {
        "ready": True,
        "payload": {
            "plan_id": program.id,
            "date": target.isoformat(),
            "week_index": week_index,
            "weekday": target.isoweekday(),
            "title": label,
            "focus": tokens,
            "exercises": exercises,
            "summary": (
                f"准备在{target.month}月{target.day}日加一次「{label}」，"
                f"{len(exercises)} 个动作。"
                + (
                    f"沿用 {template.title} 的动作。"
                    if template is not None and not names
                    else ""
                )
            ),
            "wins": [
                item.get("name") or item["slug"] for item in exercises
            ],
            "watchouts": [],
            "actions": [],
        },
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    program = db.get(Program, str(payload.get("plan_id") or ""))
    if program is None or program.user_id != user_id:
        raise LookupError("计划不存在")
    day = ProgramDay(
        program_id=program.id,
        week_index=int(payload["week_index"]),
        weekday=int(payload["weekday"]),
        title=str(payload.get("title") or "训练")[:80],
        focus=list(payload.get("focus") or []),
    )
    db.add(day)
    db.flush()
    for index, item in enumerate(payload.get("exercises") or [], start=1):
        day.exercises.append(
            PlanExercise(
                exercise_slug=str(item["slug"]),
                order_index=index,
                sets=int(item.get("sets") or 3),
                reps=str(item.get("reps") or "8-12"),
                weight_kg=item.get("weight_kg"),
                rest_sec=int(item.get("rest_sec") or 90),
                rpe=item.get("rpe"),
                notes=item.get("notes"),
            )
        )
    db.flush()
    return {
        "before": {"created_day_id": day.id},
        "plan": serialize_program(program),
        "day_id": day.id,
    }


def undo(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    program = db.get(Program, str(payload.get("plan_id") or ""))
    if program is None or program.user_id != user_id:
        raise LookupError("计划不存在")
    day_id = str((before or {}).get("created_day_id") or "")
    day = db.get(ProgramDay, day_id) if day_id else None
    if day is not None and day.program_id == program.id:
        db.delete(day)
        db.flush()
    return {"removed": day is not None, "plan": serialize_program(program)}
