"""Server-side validation and execution for coach workout changes."""

from __future__ import annotations

from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import Exercise, PlanExercise, Profile, Program, ProgramDay
from .plan_validator import injury_tags
from .serializers import load_program, serialize_program

WORKOUT_CHANGE_OPS = {
    "swap",
    "sets",
    "reps",
    "weight",
    "rest",
    "remove",
    "add",
}


class WorkoutActionError(ValueError):
    """The proposed change cannot be applied to the current plan."""


class WorkoutActionConflict(RuntimeError):
    """The plan changed after the proposal was shown."""


def _exercise_payload(item: PlanExercise) -> dict[str, Any]:
    return {
        "slug": item.exercise_slug,
        "sets": item.sets,
        "reps": item.reps,
        "weight_kg": item.weight_kg,
        "rest_sec": item.rest_sec,
        "rpe": item.rpe,
    }


def _find_day(program: Program, day_id: str) -> ProgramDay:
    for day in program.days:
        if day.id == day_id:
            return day
    raise WorkoutActionError("训练日不存在")


def _validate_exercises(
    db: Session,
    user_id: str,
    items: list[dict[str, Any]],
) -> None:
    if not items:
        raise WorkoutActionError("训练日至少保留一个动作")
    slugs = [str(item["slug"]) for item in items]
    if len(slugs) != len(set(slugs)):
        raise WorkoutActionError("同一天不能重复动作")

    rows = {
        row.slug: row
        for row in db.execute(
            select(Exercise).where(Exercise.slug.in_(slugs))
        ).scalars()
    }
    profile = db.get(Profile, user_id)
    equipment = set(profile.equipment or ["bodyweight"]) if profile else {"bodyweight"}
    equipment.add("bodyweight")
    banned = injury_tags(profile.injuries if profile else [])

    for slug in slugs:
        exercise = rows.get(slug)
        if exercise is None:
            raise WorkoutActionError(f"动作 {slug} 不存在")
        if exercise.equipment not in equipment:
            raise WorkoutActionError(
                f"{exercise.name_zh} 需要 {exercise.equipment}，不在你的器械清单里"
            )
        if banned & set(exercise.contraindications or []):
            raise WorkoutActionError(
                f"{exercise.name_zh} 与你的伤病冲突，已拒绝"
            )


def _apply_changes(
    items: list[dict[str, Any]],
    changes: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[str]]:
    result = [dict(item) for item in items]
    warnings: list[str] = []

    # Structural changes first, then field edits, so a following weight/sets
    # change addresses the replacement.
    ordered = [
        change
        for change in changes
        if str(change.get("op")) in {"swap", "add"}
    ] + [
        change
        for change in changes
        if str(change.get("op")) not in {"swap", "add"}
    ]

    for change in ordered:
        op = str(change.get("op") or "")
        if op not in WORKOUT_CHANGE_OPS:
            raise WorkoutActionError(f"不支持的改课操作：{op}")

        if op == "swap":
            from_slug = str(change.get("from_slug") or "")
            to_slug = str(change.get("to_slug") or "")
            index = next(
                (i for i, item in enumerate(result) if item["slug"] == from_slug),
                -1,
            )
            if index < 0:
                raise WorkoutActionError(f"今天没有动作 {from_slug}")
            if any(item["slug"] == to_slug for item in result):
                raise WorkoutActionError(f"今天已经有动作 {to_slug}")
            result[index] = {
                "slug": to_slug,
                "sets": result[index]["sets"],
                "reps": result[index]["reps"],
                "weight_kg": None,
                "rest_sec": result[index]["rest_sec"],
                "rpe": result[index]["rpe"],
            }
            continue

        if op == "add":
            slug = str(change.get("slug") or "")
            if any(item["slug"] == slug for item in result):
                raise WorkoutActionError(f"今天已经有动作 {slug}")
            result.append(
                {
                    "slug": slug,
                    "sets": max(1, min(10, int(change.get("sets") or 3))),
                    "reps": str(change.get("reps") or "10-12")[:20],
                    "weight_kg": change.get("weight_kg"),
                    "rest_sec": max(0, min(300, int(change.get("rest_sec") or 60))),
                    "rpe": 7.5,
                }
            )
            continue

        slug = str(change.get("slug") or "")
        item = next((row for row in result if row["slug"] == slug), None)
        if item is None:
            raise WorkoutActionError(f"今天没有动作 {slug}")

        if op == "sets":
            item["sets"] = max(1, min(10, int(change.get("sets") or item["sets"])))
        elif op == "reps":
            item["reps"] = str(change.get("reps") or item["reps"])[:20]
        elif op == "weight":
            weight = change.get("weight_kg")
            item["weight_kg"] = (
                None
                if weight is None
                else max(0, min(500, float(weight)))
            )
        elif op == "rest":
            item["rest_sec"] = max(
                0,
                min(300, int(change.get("rest_sec") or item["rest_sec"])),
            )
        elif op == "remove":
            if len(result) <= 1:
                raise WorkoutActionError("训练日至少保留一个动作")
            result.remove(item)
            continue

    return result, warnings


def prepare_modify_workout(
    db: Session,
    user_id: str,
    *,
    plan_id: str,
    day_id: str,
    changes: list[dict[str, Any]],
    expected_plan_version: int | None = None,
) -> tuple[Program, ProgramDay, list[dict], list[dict]]:
    program = load_program(db, plan_id)
    if program is None or program.user_id != user_id:
        raise WorkoutActionError("训练计划不存在")
    if (
        expected_plan_version is not None
        and program.version != expected_plan_version
    ):
        raise WorkoutActionConflict("计划已经更新，请刷新后重试")

    day = _find_day(program, day_id)
    before = [_exercise_payload(item) for item in day.exercises]
    after, _warnings = _apply_changes(before, changes)
    _validate_exercises(db, user_id, after)
    return program, day, before, after


def execute_modify_workout(
    db: Session,
    user_id: str,
    *,
    plan_id: str,
    day_id: str,
    changes: list[dict[str, Any]],
    expected_plan_version: int | None = None,
) -> tuple[dict, list[dict], int]:
    program, day, before, after = prepare_modify_workout(
        db,
        user_id,
        plan_id=plan_id,
        day_id=day_id,
        changes=changes,
        expected_plan_version=expected_plan_version,
    )

    day.exercises.clear()
    db.flush()
    for index, item in enumerate(after, start=1):
        day.exercises.append(
            PlanExercise(
                exercise_slug=item["slug"],
                order_index=index,
                sets=int(item["sets"]),
                reps=str(item["reps"]),
                weight_kg=item["weight_kg"],
                rest_sec=int(item["rest_sec"]),
                rpe=item["rpe"],
            )
        )
    program.version += 1
    db.commit()
    updated = load_program(db, plan_id)
    if updated is None:
        raise WorkoutActionError("训练计划不存在")
    return serialize_program(updated), before, updated.version


def undo_modify_workout(
    db: Session,
    user_id: str,
    *,
    plan_id: str,
    day_id: str,
    before: list[dict[str, Any]],
    expected_version: int,
) -> dict:
    program = load_program(db, plan_id)
    if program is None or program.user_id != user_id:
        raise WorkoutActionError("训练计划不存在")
    if program.version != expected_version:
        raise WorkoutActionConflict("计划已经更新，无法撤销")
    day = _find_day(program, day_id)
    _validate_exercises(db, user_id, before)

    day.exercises.clear()
    db.flush()
    for index, item in enumerate(before, start=1):
        day.exercises.append(
            PlanExercise(
                exercise_slug=item["slug"],
                order_index=index,
                sets=int(item["sets"]),
                reps=str(item["reps"]),
                weight_kg=item["weight_kg"],
                rest_sec=int(item["rest_sec"]),
                rpe=item["rpe"],
            )
        )
    program.version += 1
    db.commit()
    updated = load_program(db, plan_id)
    if updated is None:
        raise WorkoutActionError("训练计划不存在")
    return serialize_program(updated)
