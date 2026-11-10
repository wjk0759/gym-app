"""训练计划生成：LLM 优先，规则模板兜底。"""

from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import (
    EquipmentTypeExercise,
    Exercise,
    Profile,
    UserEquipmentExercise,
    UserUniversalEquipment,
)
from . import llm
from .equipment import available_equipment_types
from .load_progression import apply_plan_weights
from .plan_validator import injury_tags, validate_plan
from .training_stage import refresh_training_stage

PROMPT_PATH = Path(__file__).resolve().parent.parent / "prompts" / "plan_system.md"


def user_plan_pool_slugs(db: Session, user_id: str) -> list[str]:
    """Build the equipment plan pool from the DB.

    Union of fixed-machine enabled exercises and the checked universal
    equipment mappings. Used by the coach/agent path and as the backend
    fallback when the client does not send a pool.
    """
    fixed = (
        db.execute(
            select(UserEquipmentExercise.exercise_slug).where(
                UserEquipmentExercise.user_id == user_id
            )
        )
        .scalars()
        .all()
    )
    universal = (
        db.execute(
            select(UserUniversalEquipment.equipment_slug).where(
                UserUniversalEquipment.user_id == user_id,
                UserUniversalEquipment.enabled.is_(True),
            )
        )
        .scalars()
        .all()
    )
    slugs = set(fixed)
    for group in universal:
        type_slug = "pullup_dip_station" if group in {"pullup", "dip"} else group
        rows = (
            db.execute(
                select(EquipmentTypeExercise.exercise_slug).where(
                    EquipmentTypeExercise.equipment_type_slug == type_slug
                )
            )
            .scalars()
            .all()
        )
        slugs.update(rows)
    return sorted(slugs)

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

# 用户显式选择的训练分化优先于按每周天数推断的模板。
SPLIT_TEMPLATES: dict[str, list[tuple[str, list[str]]]] = {
    "1分化": [
        ("全身 A", FULL_BODY),
        ("全身 B", ["legs", "back", "chest", "core"]),
        ("全身 C", ["glutes", "chest", "arms", "core"]),
    ],
    "3分化": [("推", PUSH), ("拉", PULL), ("腿", LEGS)],
    "5分化": [
        ("胸", ["chest", "chest", "arms", "core"]),
        ("背", ["back", "back", "arms", "core"]),
        ("腿", LEGS),
        ("肩", ["shoulders", "shoulders", "core"]),
        ("手臂", ["arms", "arms", "shoulders"]),
    ],
}


def _session_exercise_count(minutes: int, stage: str | None = None) -> int:
    if minutes <= 30:
        base = 4
    elif minutes <= 45:
        base = 5
    elif minutes <= 60:
        base = 6
    else:
        base = 7
    cap = {"beginner": 4, "intermediate": 5, "advanced": 6}.get(
        stage or "beginner", 4
    )
    return min(base, cap)


_FOCUS_MUSCLES = ("chest", "back", "legs", "glutes", "shoulders", "arms", "core")


def _normalize_focus(focus: list[str] | None) -> list[str]:
    values = [item for item in (focus or []) if item in _FOCUS_MUSCLES]
    deduped = list(dict.fromkeys(values))
    # Selecting every muscle group is the same as balanced training.
    return [] if len(deduped) >= len(_FOCUS_MUSCLES) else deduped


def _allowed_exercises(
    db: Session,
    equipment: list[str] | None,
    injuries: list[str] | None,
    preferred_slugs: list[str] | None = None,
    plan_pool_slugs: list[str] | None = None,
    strict_equipment: bool = False,
) -> list[Exercise]:
    banned = injury_tags(injuries)

    rows = (
        db.execute(select(Exercise).where(Exercise.is_active.is_(True)))
        .scalars()
        .all()
    )

    # 器械计划池：固定器械启用动作 + 通用器械动作。
    # >=8 条默认严格使用；strict_equipment 时不论多少都严格使用，不回退白名单。
    pool = set(plan_pool_slugs or [])
    if pool:
        picked = [
            e for e in rows
            if e.slug in pool
            and not (banned & set(e.contraindications or []))
        ]
        if strict_equipment or len(picked) >= 8:
            return picked

    # 回退：只用「可进计划」的力量动作 + 伤病过滤。
    result: list[Exercise] = [
        e for e in rows
        if e.plan_eligible
        and not (banned & set(e.contraindications or []))
    ]

    if preferred_slugs:
        preferred = set(preferred_slugs)
        narrowed = [item for item in result if item.slug in preferred]
        # 器械库太少时不强行限制，避免生成不出完整计划
        if len(narrowed) >= 8:
            result = narrowed

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
    stage = getattr(profile, "training_stage", None) or "beginner"
    sets = min(params["sets"], {"beginner": 3, "intermediate": 4, "advanced": 5}[stage])
    rpe = min(params["rpe"], {"beginner": 7.0, "intermediate": 8.0, "advanced": 9.0}[stage])
    exercises = []
    for order, exercise in enumerate(picks, start=1):
        exercises.append(
            {
                "slug": exercise.slug,
                "order_index": order,
                "sets": sets,
                "reps": _reps_for(exercise, goal_type),
                "weight_kg": None,
                "rest_sec": params["rest"],
                "rpe": rpe,
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
    split: str | None = None,
    weekly_days: int | None = None,
    session_minutes: int | None = None,
    weekdays: list[int] | None = None,
    focus: list[str] | None = None,
) -> dict:
    normalized_weekdays = sorted({int(item) for item in (weekdays or []) if 1 <= int(item) <= 7})
    if normalized_weekdays:
        weekly_days = len(normalized_weekdays)
        weekday_values = normalized_weekdays
    else:
        weekly_days = max(1, min(7, int(weekly_days or profile.weekly_days or 3)))
        weekday_values = DEFAULT_WEEKDAYS[weekly_days]
    templates = SPLIT_TEMPLATES.get(split or "", SPLITS[weekly_days])
    minutes = max(15, min(180, int(session_minutes or profile.session_minutes or 45)))
    count = _session_exercise_count(
        minutes,
        getattr(profile, "training_stage", None),
    )
    requested_focus = _normalize_focus(focus)

    days = []
    for week_index in range(1, weeks + 1):
        for index, weekday in enumerate(weekday_values):
            title, base_focus = templates[index % len(templates)]
            day_focus = list(base_focus)
            for muscle in requested_focus:
                if muscle not in day_focus:
                    day_focus.insert(0, muscle)
            picks = _pick_for_day(available, day_focus, count)
            if not picks:
                continue
            days.append(
                _build_day(
                    week_index=week_index,
                    weekday=weekday,
                    title=title,
                    focus=day_focus,
                    picks=picks,
                    profile=profile,
                    goal_type=goal_type,
                )
            )

    label = GOAL_LABELS.get(goal_type, "训练")
    split_label = f" · {split}" if split in SPLIT_TEMPLATES else ""
    return {
        "title": f"{weeks} 周{label}计划{split_label} · 每周 {weekly_days} 练",
        "weeks": weeks,
        "days": days,
    }


def _system_prompt() -> str:
    if PROMPT_PATH.exists():
        return PROMPT_PATH.read_text(encoding="utf-8")
    return "你是严谨的体能教练。只输出 JSON，禁止发明动作。"


def build_template_plan(
    db: Session,
    profile: Profile,
    goal_type: str,
    *,
    weeks: int = 4,
    split: str | None = None,
    weekly_days: int | None = None,
    session_minutes: int | None = None,
    weekdays: list[int] | None = None,
    focus: list[str] | None = None,
    plan_pool_slugs: list[str] | None = None,
    strict_equipment: bool = False,
) -> dict:
    """Build a deterministic, validated plan for the agent proposal tool."""
    refresh_training_stage(db, profile.user_id)
    weeks = max(1, min(8, int(weeks)))
    equipment_types = available_equipment_types(
        db, profile.user_id, profile.equipment
    )
    if not plan_pool_slugs:
        plan_pool_slugs = user_plan_pool_slugs(db, profile.user_id)
    available = _allowed_exercises(
        db,
        equipment_types,
        profile.injuries,
        None,
        plan_pool_slugs,
        strict_equipment,
    )
    if not available:
        raise ValueError("当前器械或伤病条件下没有可用动作")
    raw = fallback_plan(
        profile,
        goal_type,
        available,
        weeks=weeks,
        split=split,
        weekly_days=weekly_days,
        session_minutes=session_minutes,
        weekdays=weekdays,
        focus=focus,
    )
    by_slug = {item.slug: item for item in available}
    effective_days = len(sorted({int(item) for item in (weekdays or []) if 1 <= int(item) <= 7})) or max(
        1, min(7, int(weekly_days or profile.weekly_days or 3))
    )
    cleaned, warnings = validate_plan(
        raw,
        exercises=by_slug,
        equipment=equipment_types,
        injuries=profile.injuries,
        weekly_days=effective_days,
        weeks=weeks,
    )
    apply_plan_weights(db, profile, cleaned, by_slug)
    return {
        "plan": cleaned,
        "warnings": warnings,
        "generated_by": "template",
        "model": None,
    }


def _candidate_pool(
    available: list[Exercise], per_muscle: int = 12, cap: int = 96
) -> list[Exercise]:
    """Balanced candidate sample across muscle groups.

    ``available`` is returned in slug order, which after the Xunji switch puts
    hundreds of chest/back variants first. Sending ``available[:80]`` to the
    model starved it of legs/shoulders/arms. Sample compound-first exercises
    per muscle so the model has a representative pool to pick from.
    """
    order = ["legs", "chest", "back", "shoulders", "arms", "glutes", "core", "cardio"]
    groups: dict[str, list[Exercise]] = {}
    for item in available:
        groups.setdefault(item.muscle_group, []).append(item)

    pool: list[Exercise] = []
    for muscle in order:
        items = sorted(
            groups.get(muscle, []),
            key=lambda item: (not item.is_compound, item.difficulty, item.slug),
        )
        pool.extend(items[:per_muscle])
        if len(pool) >= cap:
            return pool[:cap]
    return pool[:cap]


def _user_prompt(
    profile: Profile,
    goal_type: str,
    goal: Any,
    available: list[Exercise],
    weeks: int,
    equipment_slugs: list[str] | None = None,
    split: str | None = None,
    focus: list[str] | None = None,
) -> str:
    candidates = [
        {
            "slug": item.slug,
            "name": item.name_zh,
            "muscle": item.muscle_group,
            "equipment": item.equipment,
            "compound": item.is_compound,
        }
        for item in _candidate_pool(available)
    ]
    split_templates = SPLIT_TEMPLATES.get(split or "", [])
    normalized_focus = _normalize_focus(focus)
    payload = {
        "user": {
            "sex": profile.sex,
            "age": profile.age,
            "height_cm": profile.height_cm,
            "weight_kg": profile.weight_kg,
            "experience": profile.experience,
            "training_stage": getattr(profile, "training_stage", "beginner"),
            "injuries": profile.injuries,
            "equipment": sorted({item.equipment for item in available} | {"bodyweight"}),
            "weekly_days": profile.weekly_days,
            "session_minutes": profile.session_minutes,
            "goal_type": goal_type,
            "goal": goal,
            "split": split,
            "equipment_library_slugs": equipment_slugs or [],
            "focus_areas": normalized_focus,
        },
        "weeks": weeks,
        "candidates": candidates,
        "output_rules": {
            "days_count": int(profile.weekly_days) * weeks,
            "exercises_per_day": [4, 6],
            "must_use_candidate_slugs_only": True,
            "weekday_range": [1, 7],
            "follow_split": bool(split_templates),
            "required_split_titles": [item[0] for item in split_templates],
            "required_split_focus": [item[1] for item in split_templates],
            "focus_priority": normalized_focus,
            "focus_instruction": (
                f"每天优先安排 {', '.join(normalized_focus)} 动作，但不要破坏分化结构。"
                if normalized_focus
                else "不额外指定重点部位。"
            ),
            "split_instruction": (
                f"必须严格使用 {split} 的模板，按顺序循环训练日标题和 focus，"
                "不要改成全身训练或其他分化。"
                if split_templates
                else "按每周训练天数自动选择合理分化。"
            ),
        },
    }
    return json.dumps(payload, ensure_ascii=False)


async def generate_plan(
    db: Session,
    profile: Profile,
    goal_type: str,
    goal: Any = None,
    weeks: int = 4,
    equipment_slugs: list[str] | None = None,
    split: str | None = None,
    focus: list[str] | None = None,
    plan_pool_slugs: list[str] | None = None,
    strict_equipment: bool = False,
) -> dict:
    # Fast path: the reasoning LLM is far too slow for plan generation (see
    # ai_jobs: plan=64s). The deterministic template is instant and already
    # validated, and matches the iOS local generator.
    if not settings.llm_plan_enabled:
        return build_template_plan(
            db,
            profile,
            goal_type,
            weeks=weeks,
            split=split,
            focus=focus,
            plan_pool_slugs=plan_pool_slugs,
            strict_equipment=strict_equipment,
        )

    refresh_training_stage(db, profile.user_id)
    db.commit()
    equipment_types = available_equipment_types(
        db, profile.user_id, profile.equipment
    )
    if not plan_pool_slugs:
        plan_pool_slugs = user_plan_pool_slugs(db, profile.user_id)
    available = _allowed_exercises(
        db,
        equipment_types,
        profile.injuries,
        equipment_slugs,
        plan_pool_slugs,
        strict_equipment,
    )
    if not available:
        available = (
            db.execute(select(Exercise).where(Exercise.is_active.is_(True)))
            .scalars()
            .all()
        )

    by_slug = {item.slug: item for item in available}
    started = time.perf_counter()
    error: str | None = None
    warnings: list[str] = []
    usage: dict[str, int] = {}

    if not settings.use_mock_llm:
        try:
            # Exercise selection is complete; release the read transaction
            # while the model generates the plan.
            db.commit()
            raw = await llm.complete_json(
                _system_prompt(),
                _user_prompt(
                    profile,
                    goal_type,
                    goal,
                    available,
                    weeks,
                    equipment_slugs,
                    split,
                    focus,
                ),
                reasoning_effort=settings.llm_plan_reasoning_effort,
                usage=usage,
                db=db,
                user_id=getattr(profile, "user_id", None),
                kind="plan",
            )
            cleaned, warnings = validate_plan(
                raw,
                exercises=by_slug,
                equipment=equipment_types,
                injuries=profile.injuries,
                weekly_days=profile.weekly_days,
                weeks=weeks,
            )
            apply_plan_weights(db, profile, cleaned, by_slug)
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
                usage=usage,
            )

    raw = fallback_plan(
        profile, goal_type, available, weeks=weeks, split=split, focus=focus
    )
    cleaned, fallback_warnings = validate_plan(
        raw,
        exercises=by_slug,
        equipment=equipment_types,
        injuries=profile.injuries,
        weekly_days=profile.weekly_days,
        weeks=weeks,
    )
    apply_plan_weights(db, profile, cleaned, by_slug)
    warnings.extend(fallback_warnings)
    return {
        "plan": cleaned,
        "generated_by": "template",
        "warnings": warnings,
        "model": None,
        "error": error,
    }
