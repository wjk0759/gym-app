"""训练计划生成：LLM 优先，规则模板兜底。"""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import Exercise, Profile
from . import llm
from .plan_validator import PlanValidationError, injury_tags, validate_plan

PROMPT_PATH = Path(__file__).resolve().parent.parent / "prompts" / "plan_system.md"

GOAL_LABELS = {
    "lose_fat": "减脂",
    "build_muscle": "增肌",
    "recomp": "重塑体型",
    "endurance": "体能",
}

GOAL_PARAMS = {
    "lose_fat": {"sets": 3, "reps": "12-15", "rest": 45, "rpe": 7.0},
    "build_muscle": {"sets": 4, "reps": "8-10", "rest": 90, "rpe": 7.5},
    "recomp": {"sets": 3, "reps": "10-12", "rest": 60, "rpe": 7.0},
    "endurance": {"sets": 3, "reps": "15-20", "rest": 30, "rpe": 6.5},
}

DEFAULT_WEEKDAYS = {
    1: [3],
    2: [2, 5],
    3: [1, 3, 5],
    4: [1, 2, 4, 5],
    5: [1, 2, 3, 5, 6],
    6: [1, 2, 3, 4, 5, 6],
    7: [1, 2, 3, 4, 5, 6, 7],
}

FULL_BODY = ["legs", "chest", "back", "shoulders", "core"]
UPPER = ["chest", "back", "shoulders", "arms", "arms"]
LOWER = ["legs", "glutes", "legs", "core", "core"]
PUSH = ["chest", "chest", "shoulders", "shoulders", "arms"]
PULL = ["back", "back", "back", "arms", "core"]
LEGS = ["legs", "legs", "glutes", "legs", "core"]
RECOVERY = ["core", "cardio", "core", "glutes"]

SPLITS: dict[int, list[tuple[str, list[str]]]] = {
    1: [("全身训练", FULL_BODY)],
    2: [("全身 A", FULL_BODY), ("全身 B", ["legs", "back", "chest", "core"])],
    3: [
        ("全身 A", ["legs", "chest", "back", "core"]),
        ("全身 B", ["legs", "shoulders", "back", "core"]),
        ("全身 C", ["glutes", "chest", "arms", "core"]),
    ],
    4: [
        ("上肢 A", UPPER),
        ("下肢 A", LOWER),
        ("上肢 B", ["back", "chest", "shoulders", "arms", "arms"]),
        ("下肢 B", ["glutes", "legs", "legs", "core", "core"]),
    ],
    5: [
        ("推 · 胸肩三头", PUSH),
        ("拉 · 背二头", PULL),
        ("腿 · 下肢", LEGS),
        ("上肢综合", UPPER),
        ("下肢综合", LOWER),
    ],
    6: [
        ("推 A", PUSH),
        ("拉 A", PULL),
        ("腿 A", LEGS),
        ("推 B", ["shoulders", "chest", "chest", "arms", "arms"]),
        ("拉 B", ["back", "back", "arms", "arms", "core"]),
        ("腿 B", ["glutes", "legs", "legs", "core", "core"]),
    ],
    7: [
        ("推", PUSH),
        ("拉", PULL),
        ("腿", LEGS),
        ("上肢", UPPER),
        ("下肢", LOWER),
        ("全身", FULL_BODY),
        ("恢复与核心", RECOVERY),
    ],
}


def _session_exercise_count(minutes: int) -> int:
    if minutes <= 30:
        return 4
    if minutes <= 45:
        return 5
    if minutes <= 60:
        return 6
    return 7


def _allowed_exercises(
    db: Session, equipment: list[str] | None, injuries: list[str] | None
) -> list[Exercise]:
    allowed_equipment = set(equipment or ["bodyweight"])
    allowed_equipment.add("bodyweight")
    banned = injury_tags(injuries)

    rows = db.execute(select(Exercise)).scalars().all()
    result: list[Exercise] = []
    for exercise in rows:
        if exercise.equipment not in allowed_equipment:
            continue
        if banned & set(exercise.contraindications or []):
            continue
        result.append(exercise)
    return result


def _pick_for_day(
    available: list[Exercise], focus: list[str], count: int
) -> list[Exercise]:
    picks: list[Exercise] = []
    used: set[str] = set()

    for muscle in focus:
        if len(picks) >= count:
            break
        candidates = [
            item
            for item in available
            if item.muscle_group == muscle and item.slug not in used
        ]
        candidates.sort(key=lambda item: (not item.is_compound, item.difficulty))
        if candidates:
            picks.append(candidates[0])
            used.add(candidates[0].slug)

    if len(picks) < count:
        rest = [item for item in available if item.slug not in used]
        rest.sort(key=lambda item: (not item.is_compound, item.difficulty))
        for item in rest:
            if len(picks) >= count:
                break
            if item.muscle_group == "cardio" and "cardio" not in focus:
                continue
            picks.append(item)
            used.add(item.slug)

    return picks[:count]


def _suggest_weight(exercise: Exercise, experience: str) -> float | None:
    if exercise.equipment == "bodyweight":
        return None
    base = {
        "dumbbell": 8.0,
        "barbell": 20.0,
        "machine": 15.0,
        "cable": 10.0,
        "band": 5.0,
        "kettlebell": 8.0,
    }.get(exercise.equipment, 10.0)
    multiplier = {"beginner": 1.0, "intermediate": 1.5, "advanced": 2.0}.get(
        experience, 1.0
    )
    if not exercise.is_compound:
        multiplier *= 0.6
    return round(base * multiplier * 2) / 2


def _reps_for(exercise: Exercise, goal_type: str) -> str:
    if exercise.slug == "plank":
        return "30-45s"
    if exercise.slug in {"rowing_machine", "treadmill_walk"}:
        return "8-12 min"
    return GOAL_PARAMS.get(goal_type, GOAL_PARAMS["recomp"])["reps"]


def _build_day(
    week_index: int,
    weekday: int,
    title: str,
    focus: list[str],
    picks: list[Exercise],
    profile: Profile,
    goal_type: str,
) -> dict:
    params = GOAL_PARAMS.get(goal_type, GOAL_PARAMS["recomp"])
    exercises = []
    for order, exercise in enumerate(picks, start=1):
        weight = _suggest_weight(exercise, profile.experience)
        if weight is not None and week_index > 1:
            weight = round(weight * (1 + 0.025 * (week_index - 1)) * 2) / 2
        exercises.append(
            {
                "slug": exercise.slug,
                "order_index": order,
                "sets": params["sets"],
                "reps": _reps_for(exercise, goal_type),
                "weight_kg": weight,
                "rest_sec": params["rest"],
                "rpe": params["rpe"],
            }
        )
    return {
        "week_index": week_index,
        "weekday": weekday,
        "title": title,
        "focus": focus,
        "exercises": exercises,
    }


def fallback_plan(
    profile: Profile,
    goal_type: str,
    available: list[Exercise],
    weeks: int = 4,
) -> dict:
    weekly_days = max(1, min(7, int(profile.weekly_days or 3)))
    weekdays = DEFAULT_WEEKDAYS[weekly_days]
    split = SPLITS[weekly_days]
    count = min(_session_exercise_count(profile.session_minutes or 45), 6)

    days = []
    for week_index in range(1, weeks + 1):
        for index, weekday in enumerate(weekdays):
            title, focus = split[index % len(split)]
            picks = _pick_for_day(available, focus, count)
            if not picks:
                continue
            days.append(
                _build_day(
                    week_index=week_index,
                    weekday=weekday,
                    title=title,
                    focus=focus,
                    picks=picks,
                    profile=profile,
                    goal_type=goal_type,
                )
            )

    label = GOAL_LABELS.get(goal_type, "训练")
    return {
        "title": f"{weeks} 周{label}计划 · 每周 {weekly_days} 练",
        "weeks": weeks,
        "days": days,
    }


def _system_prompt() -> str:
    if PROMPT_PATH.exists():
        return PROMPT_PATH.read_text(encoding="utf-8")
    return "你是严谨的体能教练。只输出 JSON，禁止发明动作。"


def _user_prompt(
    profile: Profile,
    goal_type: str,
    goal: Any,
    available: list[Exercise],
    weeks: int,
) -> str:
    candidates = [
        {
            "slug": item.slug,
            "name": item.name_zh,
            "muscle": item.muscle_group,
            "equipment": item.equipment,
            "compound": item.is_compound,
        }
        for item in available[:80]
    ]
    payload = {
        "user": {
            "sex": profile.sex,
            "age": profile.age,
            "height_cm": profile.height_cm,
            "weight_kg": profile.weight_kg,
            "experience": profile.experience,
            "injuries": profile.injuries,
            "equipment": profile.equipment,
            "weekly_days": profile.weekly_days,
            "session_minutes": profile.session_minutes,
            "goal_type": goal_type,
            "goal": goal,
        },
        "weeks": weeks,
        "candidates": candidates,
        "output_rules": {
            "days_count": int(profile.weekly_days) * weeks,
            "exercises_per_day": [4, 6],
            "must_use_candidate_slugs_only": True,
            "weekday_range": [1, 7],
        },
    }
    return json.dumps(payload, ensure_ascii=False)


async def generate_plan(
    db: Session,
    profile: Profile,
    goal_type: str,
    goal: Any = None,
    weeks: int = 4,
) -> dict:
    available = _allowed_exercises(db, profile.equipment, profile.injuries)
    if not available:
        available = db.execute(select(Exercise)).scalars().all()

    by_slug = {item.slug: item for item in available}
    started = time.perf_counter()
    error: str | None = None
    warnings: list[str] = []

    if not settings.use_mock_llm:
        try:
            raw = await llm.complete_json(
                _system_prompt(),
                _user_prompt(profile, goal_type, goal, available, weeks),
            )
            cleaned, warnings = validate_plan(
                raw,
                exercises=by_slug,
                equipment=profile.equipment,
                injuries=profile.injuries,
                weekly_days=profile.weekly_days,
                weeks=weeks,
            )
            latency = int((time.perf_counter() - started) * 1000)
            llm.record_job(
                db,
                getattr(profile, "user_id", None),
                kind="plan",
                status="ok",
                model=settings.llm_model,
                latency_ms=latency,
            )
            return {
                "plan": cleaned,
                "generated_by": "ai",
                "warnings": warnings,
                "model": settings.llm_model,
                "error": None,
            }
        except Exception as exc:  # noqa: BLE001 - 任何模型/校验失败都必须降级
            error = str(exc)[:500]
            warnings.append("AI 生成失败，已切换到规则模板")
            llm.record_job(
                db,
                getattr(profile, "user_id", None),
                kind="plan",
                status="fallback",
                model=settings.llm_model,
                latency_ms=int((time.perf_counter() - started) * 1000),
                error=error,
            )

    raw = fallback_plan(profile, goal_type, available, weeks=weeks)
    cleaned, fallback_warnings = validate_plan(
        raw,
        exercises=by_slug,
        equipment=profile.equipment,
        injuries=profile.injuries,
        weekly_days=profile.weekly_days,
        weeks=weeks,
    )
    warnings.extend(fallback_warnings)
    return {
        "plan": cleaned,
        "generated_by": "template",
        "warnings": warnings,
        "model": None,
        "error": error,
    }
