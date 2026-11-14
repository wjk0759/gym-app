"""Replace the exercises of one plan day.

The user can say "今天的练胸计划帮我改成：杠铃卧推、上斜杠铃卧推、器械推胸、
蝴蝶机". The capability resolves each name to the exercise library, shows the
proposal, and only writes after confirmation.
"""

from __future__ import annotations

import re
from datetime import date, datetime
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ....models import Exercise, PlanExercise, Program, ProgramDay
from ...exercise_search import search_exercises
from ...serializers import serialize_program
from ..registry import Capability, register
from .training import _source_day

CAPABILITY = register(
    Capability(
        id="training.edit_day_exercises",
        domain="training",
        kind="write",
        title="修改当天动作",
        description="把某一天的计划动作替换为指定动作，确认后生效",
        requires_confirmation=True,
        undo=True,
        events=("TrainingPlanAdjusted",),
    )
)

_NAME_SPLIT = re.compile(r"[、,，;；/]+")
_TARGET = re.compile(r"(?:改成|换成|换为|替换为|替换成)\s*[:：]?\s*(.+)$")
_FOCUS_WORDS = (
    ("胸", ("胸", "chest")),
    ("背", ("背", "back")),
    ("腿", ("腿", "legs")),
    ("臀", ("臀", "glutes")),
    ("肩", ("肩", "shoulders")),
    ("手臂", ("手臂", "arms")),
    ("全身", ("全身", "full")),
    ("上肢", ("上肢", "upper")),
    ("下肢", ("下肢", "lower")),
)


def _day_by_focus(
    context: dict,
    message: str,
    today,
) -> dict | None:
    plan = context.get("plan") if isinstance(context, dict) else None
    days = plan.get("days") if isinstance(plan, dict) else None
    if not isinstance(days, list):
        return None
    labels = [label for label, _ in _FOCUS_WORDS if label in message]
    if not labels:
        return None
    candidates = []
    for item in days:
        if not isinstance(item, dict):
            continue
        title = str(item.get("title") or "")
        focus = [str(value) for value in (item.get("focus") or [])]
        if not any(
            label in title
            or any(token in focus for token in tokens)
            for label, tokens in _FOCUS_WORDS
            if label in labels
        ):
            continue
        raw_date = str(item.get("date") or "")
        try:
            when = date.fromisoformat(raw_date) if raw_date else today
        except ValueError:
            when = today
        candidates.append((when, item))
    if not candidates:
        return None
    upcoming = [item for item in candidates if item[0] >= today]
    pool = upcoming or candidates
    pool.sort(key=lambda item: item[0])
    return pool[0][1]


def _exercise_names(message: str) -> list[str]:
    match = _TARGET.search(message)
    if match is None:
        return []
    raw = match.group(1)
    names = [item.strip(" 。.！!") for item in _NAME_SPLIT.split(raw)]
    return [item for item in names if item][:8]


def _resolve_exercise(db: Session, name: str) -> tuple[Exercise | None, str]:
    exact = (
        db.execute(
            select(Exercise)
            .where(Exercise.name_zh == name)
            .order_by(Exercise.slug)
        )
        .scalars()
        .first()
    )
    if exact is not None:
        return exact, exact.name_zh
    contains = (
        db.execute(
            select(Exercise)
            .where(Exercise.name_zh.contains(name))
            .order_by(func.length(Exercise.name_zh), Exercise.slug)
        )
        .scalars()
        .first()
    )
    if contains is not None:
        return contains, contains.name_zh
    for item in search_exercises(name, limit=3):
        slug = str(item.get("slug") or item.get("id") or "")
        exercise = db.get(Exercise, slug) if slug else None
        if exercise is not None:
            return exercise, exercise.name_zh
    return None, name


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


def resolve(
    db: Session,
    user_id: str,
    message: str,
    context: dict,
) -> dict:
    names = _exercise_names(message)
    if not names:
        return {
            "ready": False,
            "questions": ["想换成哪些动作？用顿号分开，例如“杠铃卧推、上斜卧推”。"],
        }
    plan = context.get("plan") if isinstance(context, dict) else None
    if not isinstance(plan, dict):
        return {"ready": False, "questions": ["还没有可修改的训练计划。"]}
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    day = _source_day(message, context, today=today)
    if day is None:
        day = _day_by_focus(context, message, today)
    if day is None:
        return {"ready": False, "questions": ["想改哪一天？告诉我今天、明天或周几。"]}
    day_id = str(day.get("id") or "")
    program = db.get(Program, str(plan.get("id") or ""))
    if program is None or program.user_id != user_id or program.status != "active":
        return {"ready": False, "questions": ["当前计划不在服务端，先在训练手账里同步计划。"]}
    program_day = db.get(ProgramDay, day_id)
    if program_day is None or program_day.program_id != program.id:
        return {"ready": False, "questions": ["没有找到这一天的训练。"]}

    resolved: list[dict] = []
    watchouts: list[str] = []
    if re.search(r"今天|今日", message) and str(day.get("date") or "") != today.isoformat():
        watchouts.append(
            f"今天没有对应训练，按 {day.get('date') or '下一个训练日'} 处理。"
        )
    for name in names:
        exercise, resolved_name = _resolve_exercise(db, name)
        if exercise is None:
            return {
                "ready": False,
                "questions": [f"没有找到「{name}」这个动作，换个说法或从动作库选择。"],
            }
        if resolved_name != name:
            watchouts.append(f"「{name}」按「{resolved_name}」处理。")
        resolved.append(
            {
                "slug": exercise.slug,
                "name": resolved_name,
                "sets": 0,
                "reps": "",
            }
        )

    template = program_day.exercises[0] if program_day.exercises else None
    sets = template.sets if template is not None else 3
    reps = template.reps if template is not None else "8-12"
    rest = template.rest_sec if template is not None else 90
    rpe = template.rpe if template is not None else 7.5
    exercises = [
        {
            "slug": item["slug"],
            "name": item["name"],
            "sets": sets,
            "reps": reps,
            "weight_kg": None,
            "rest_sec": rest,
            "rpe": rpe,
            "notes": None,
        }
        for item in resolved
    ]
    date_label = str(day.get("date") or "")
    summary = (
        f"准备把{date_label}的「{program_day.title}」替换为："
        + "、".join(item["name"] for item in exercises)
        + f"。每个动作 {sets} 组 × {reps}。"
    )
    return {
        "ready": True,
        "payload": {
            "plan_id": program.id,
            "day_id": program_day.id,
            "date": date_label,
            "title": program_day.title,
            "before": _snapshot(program_day),
            "exercises": exercises,
            "summary": summary,
            "wins": [item["name"] for item in exercises],
            "watchouts": watchouts,
            "actions": [],
        },
    }


def rewrite_day(
    db: Session,
    day: ProgramDay,
    items: list[dict],
) -> None:
    day.exercises.clear()
    db.flush()
    for index, item in enumerate(items, start=1):
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


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    program = db.get(Program, str(payload.get("plan_id") or ""))
    if program is None or program.user_id != user_id:
        raise LookupError("计划不存在")
    day = db.get(ProgramDay, str(payload.get("day_id") or ""))
    if day is None or day.program_id != program.id:
        raise LookupError("训练日不存在")
    rewrite_day(db, day, payload.get("exercises") or [])
    return {
        "before": {"previous": payload.get("before") or []},
        "plan": serialize_program(program),
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
    day = db.get(ProgramDay, str(payload.get("day_id") or ""))
    if day is None or day.program_id != program.id:
        raise LookupError("训练日不存在")
    previous = before.get("previous") if isinstance(before, dict) else []
    rewrite_day(db, day, previous or [])
    return {"restored": True, "plan": serialize_program(program)}
