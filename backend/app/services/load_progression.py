from __future__ import annotations

import re
from typing import Any

from ..models import Exercise, Profile

STAGE_ORDER = ("beginner", "intermediate", "advanced")
STAGE_UPPER = {"beginner": 0.025, "intermediate": 0.025, "advanced": 0.0125}
STAGE_LOWER = {"beginner": 0.05, "intermediate": 0.05, "advanced": 0.025}


def parse_rep_range(value: str | None) -> tuple[int, int]:
    numbers = [int(item) for item in re.findall(r"\d+", value or "")]
    if not numbers:
        return (8, 10)
    if len(numbers) == 1:
        return (numbers[0], numbers[0])
    return (min(numbers[0], numbers[1]), max(numbers[0], numbers[1]))


def _round_weight(value: float) -> float:
    return round(max(0.5, min(300.0, value)) * 2) / 2


def _barbell_ratio(exercise: Exercise) -> float:
    name = f"{exercise.name_zh or ''} {exercise.name_en or ''}".lower()
    if "硬拉" in name or "deadlift" in name:
        return 0.60
    if "深蹲" in name or "squat" in name:
        return 0.50
    if "腿举" in name or "leg press" in name:
        return 0.80
    if "卧推" in name or "bench" in name:
        return 0.35
    if "划船" in name or "row" in name:
        return 0.30
    if "推举" in name or "overhead" in name or "肩推" in name:
        return 0.20
    return 0.30


def estimate_weight(exercise: Exercise, profile: Profile) -> float | None:
    """Conservative first-plan estimate when no history exists."""
    if exercise.equipment == "bodyweight":
        return None

    experience = profile.experience or "beginner"
    factor = {"beginner": 1.0, "intermediate": 1.5, "advanced": 2.0}.get(
        experience, 1.0
    )
    bodyweight = float(profile.weight_kg or 0)
    if exercise.equipment == "barbell" and exercise.is_compound and bodyweight > 0:
        ratio_factor = {"beginner": 0.85, "intermediate": 1.0, "advanced": 1.15}.get(
            experience, 0.85
        )
        return _round_weight(bodyweight * _barbell_ratio(exercise) * ratio_factor)

    base = {
        "dumbbell": 8.0,
        "barbell": 20.0,
        "machine": 15.0,
        "cable": 10.0,
        "band": 5.0,
        "kettlebell": 8.0,
    }.get(exercise.equipment, 10.0)
    if not exercise.is_compound:
        factor *= 0.6
    return _round_weight(base * factor)


def _week_multiplier(
    stage: str,
    week_index: int,
    *,
    lower: bool,
    compound: bool,
    has_log: bool,
) -> float:
    """Return the planned 4-week progression multiplier.

    The schedule is deliberately front-loaded differently per stage: beginners
    get two small steps, intermediate users one, advanced users one smaller
    step. Without a real logged anchor we never invent progression.
    """
    if not has_log:
        return 1.0
    # Isolation work follows the upper-body cadence but a smaller increment.
    pace = "lower" if lower and compound else "upper"
    if stage == "beginner":
        if week_index in (2, 4):
            return 1.0 + (STAGE_LOWER["beginner"] if pace == "lower" else STAGE_UPPER["beginner"])
    elif stage == "intermediate":
        if week_index == 3:
            return 1.0 + (STAGE_LOWER["intermediate"] if pace == "lower" else STAGE_UPPER["intermediate"])
    elif stage == "advanced" and week_index == 4:
        return 1.0 + (STAGE_LOWER["advanced"] if pace == "lower" else STAGE_UPPER["advanced"])
    return 1.0


def target_weight(
    exercise: Exercise,
    profile: Profile,
    history: dict[str, Any] | None,
    week_index: int,
    reps: str | None,
) -> float | None:
    if exercise.equipment == "bodyweight":
        return None

    rep_min, rep_max = parse_rep_range(reps)
    stage = getattr(profile, "training_stage", None) or "beginner"
    if stage not in STAGE_ORDER:
        stage = "beginner"

    source = history.get("source") if history else None
    anchor: float | None = None
    has_log = False
    if source == "log" and history:
        anchor = history.get("last_weight_kg")
        last_reps = history.get("last_reps")
        if anchor and last_reps and last_reps < rep_min:
            e1rm = float(anchor) * (1 + int(last_reps) / 30)
            target_reps = (rep_min + rep_max) / 2
            anchor = e1rm / (1 + target_reps / 30)
        has_log = anchor is not None
    elif source == "plan" and history:
        anchor = history.get("plan_weight_kg")
    if anchor is None:
        return estimate_weight(exercise, profile)

    multiplier = _week_multiplier(
        stage,
        week_index,
        lower=exercise.muscle_group in {"legs", "glutes"},
        compound=bool(exercise.is_compound),
        has_log=has_log,
    )
    return _round_weight(float(anchor) * multiplier)


def adjustment_multipliers(program, sessions, stage: str | None) -> dict[str, float]:
    """Per-exercise multipliers for the coach's weekly plan adjustment.

    Only the latest session per exercise in the 7-day window is evaluated, so
    two sessions in one week do not double-count completed sets.
    """
    stage = stage if stage in STAGE_ORDER else "beginner"
    rpe_cap = {"beginner": 7.5, "intermediate": 8.0, "advanced": 8.0}[stage]
    latest: dict[str, list] = {}
    for session in sorted(sessions, key=lambda item: item.started_at, reverse=True):
        grouped: dict[str, list] = {}
        for log in session.sets:
            if not log.completed or not log.weight_kg or not log.reps:
                continue
            grouped.setdefault(log.exercise_slug, []).append(log)
        for slug, logs in grouped.items():
            latest.setdefault(slug, logs)

    multipliers: dict[str, float] = {}
    for day in program.days:
        for item in day.exercises:
            logs = latest.get(item.exercise_slug)
            if not logs:
                continue
            rep_min, _ = parse_rep_range(item.reps)
            completed = len(logs)
            avg_reps = sum(log.reps or 0 for log in logs) / completed
            rpes = [log.rpe for log in logs if log.rpe is not None]
            avg_rpe = sum(rpes) / len(rpes) if rpes else 0
            if avg_rpe >= 9 or completed < max(1, item.sets * 0.8):
                multipliers[item.exercise_slug] = 0.95
                continue
            if completed < item.sets or avg_reps < rep_min:
                continue
            if avg_rpe > rpe_cap:
                continue
            lower = bool(
                item.exercise
                and item.exercise.is_compound
                and item.exercise.muscle_group in {"legs", "glutes"}
            )
            if stage == "advanced":
                multipliers[item.exercise_slug] = 1.025 if lower else 1.0125
            else:
                multipliers[item.exercise_slug] = 1.05 if lower else 1.025
    return multipliers


def apply_plan_weights(
    db,
    profile: Profile,
    plan: dict,
    exercises_by_slug: dict[str, Exercise],
) -> dict:
    from .training_history import load_exercise_history

    slugs = {
        item.get("slug")
        for day in plan.get("days", [])
        for item in day.get("exercises", [])
        if item.get("slug")
    }
    history = load_exercise_history(db, profile.user_id, slugs)
    for day in plan.get("days", []):
        week_index = int(day.get("week_index") or 1)
        for item in day.get("exercises", []):
            exercise = exercises_by_slug.get(item.get("slug", ""))
            if exercise is None:
                continue
            item["weight_kg"] = target_weight(
                exercise,
                profile,
                history.get(item["slug"]),
                week_index,
                item.get("reps"),
            )
    return plan
