"""计划校验器：不信任模型输出，所有硬约束在这里兜底。"""

from __future__ import annotations

from typing import Any

VALID_MUSCLES = {
    "chest",
    "back",
    "legs",
    "glutes",
    "shoulders",
    "arms",
    "core",
    "cardio",
}

INJURY_KEYWORDS = {
    "膝": "knee_pain",
    "半月板": "knee_pain",
    "腰": "lower_back",
    "腰椎": "lower_back",
    "肩": "shoulder_pain",
    "肩袖": "shoulder_pain",
    "腕": "wrist_pain",
    "手腕": "wrist_pain",
    "踝": "ankle_pain",
    "脚踝": "ankle_pain",
    "肘": "elbow_pain",
    "网球肘": "elbow_pain",
}


class PlanValidationError(ValueError):
    pass


def injury_tags(injuries: list[str] | None) -> set[str]:
    tags: set[str] = set()
    for text in injuries or []:
        for keyword, tag in INJURY_KEYWORDS.items():
            if keyword in text:
                tags.add(tag)
    return tags


def _clamp(value: Any, low: float, high: float, default: float) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return default
    return max(low, min(high, number))


def _as_reps(value: Any) -> str:
    if isinstance(value, (int, float)):
        return str(int(value))
    text = str(value or "").strip()
    if not text:
        return "10"
    return text[:20]


def validate_plan(
    plan: dict,
    exercises: dict[str, Any],
    equipment: list[str] | set[str],
    injuries: list[str] | None,
    weekly_days: int | None = None,
    weeks: int = 4,
) -> tuple[dict, list[str]]:
    """返回清理后的计划和警告列表；结构性问题直接抛异常。"""
    if not isinstance(plan, dict):
        raise PlanValidationError("plan must be an object")

    raw_days = plan.get("days")
    if not isinstance(raw_days, list) or not raw_days:
        raise PlanValidationError("plan.days is empty")

    allowed_equipment = {str(item) for item in (equipment or ["bodyweight"])}
    allowed_equipment.add("bodyweight")
    banned_tags = injury_tags(injuries)

    cleaned_days: list[dict] = []
    warnings: list[str] = []
    seen_slots: set[tuple[int, int]] = set()

    for raw_day in raw_days:
        if not isinstance(raw_day, dict):
            warnings.append("跳过格式不正确的训练日")
            continue

        try:
            week_index = int(raw_day.get("week_index", 1))
            weekday = int(raw_day.get("weekday", 1))
        except (TypeError, ValueError):
            warnings.append("跳过周次/星期不正确的训练日")
            continue

        if not 1 <= week_index <= weeks:
            warnings.append(f"周次 {week_index} 超出范围，已跳过")
            continue
        if not 1 <= weekday <= 7:
            warnings.append(f"星期 {weekday} 不合法，已跳过")
            continue
        if (week_index, weekday) in seen_slots:
            warnings.append(f"第 {week_index} 周星期 {weekday} 重复，已合并")
            continue

        raw_exercises = raw_day.get("exercises")
        if not isinstance(raw_exercises, list):
            continue

        cleaned_exercises: list[dict] = []
        seen_slugs: set[str] = set()

        for raw_exercise in raw_exercises:
            if not isinstance(raw_exercise, dict):
                continue
            slug = str(raw_exercise.get("slug", "")).strip()
            exercise = exercises.get(slug)
            if exercise is None:
                warnings.append(f"动作 {slug or '(空)'} 不在动作库，已移除")
                continue
            if exercise.equipment not in allowed_equipment:
                warnings.append(f"{exercise.name_zh} 需要 {exercise.equipment}，已移除")
                continue
            if banned_tags & set(exercise.contraindications or []):
                warnings.append(f"{exercise.name_zh} 与伤病冲突，已移除")
                continue
            if slug in seen_slugs:
                continue

            seen_slugs.add(slug)
            cleaned_exercises.append(
                {
                    "slug": slug,
                    "order_index": len(cleaned_exercises) + 1,
                    "sets": int(_clamp(raw_exercise.get("sets"), 1, 6, 3)),
                    "reps": _as_reps(raw_exercise.get("reps")),
                    "weight_kg": (
                        None
                        if raw_exercise.get("weight_kg") in (None, "")
                        else round(_clamp(raw_exercise.get("weight_kg"), 0, 500, 0), 1)
                    ),
                    "rest_sec": int(_clamp(raw_exercise.get("rest_sec"), 0, 300, 60)),
                    "rpe": round(_clamp(raw_exercise.get("rpe"), 1, 10, 7), 1),
                }
            )

        if len(cleaned_exercises) < 3:
            warnings.append(
                f"第 {week_index} 周星期 {weekday} 有效动作不足 3 个，已跳过"
            )
            continue

        seen_slots.add((week_index, weekday))
        cleaned_days.append(
            {
                "week_index": week_index,
                "weekday": weekday,
                "title": str(raw_day.get("title") or "训练日")[:30],
                "focus": [
                    str(item)
                    for item in (raw_day.get("focus") or [])
                    if str(item) in VALID_MUSCLES
                ][:6],
                "exercises": cleaned_exercises,
            }
        )

    if not cleaned_days:
        raise PlanValidationError("no valid training day")

    weeks_present = {day["week_index"] for day in cleaned_days}
    if len(weeks_present) < weeks:
        raise PlanValidationError("plan does not cover every week")

    if weekly_days:
        kept: list[dict] = []
        per_week: dict[int, int] = {}
        for day in cleaned_days:
            count = per_week.get(day["week_index"], 0)
            if count >= weekly_days:
                warnings.append(
                    f"第 {day['week_index']} 周训练日超过 {weekly_days} 天，已截断"
                )
                continue
            per_week[day["week_index"]] = count + 1
            kept.append(day)
        cleaned_days = kept

    cleaned_days.sort(key=lambda item: (item["week_index"], item["weekday"]))
    title = str(plan.get("title") or "AI 训练计划")[:60]

    return (
        {
            "title": title,
            "weeks": weeks,
            "days": cleaned_days,
        },
        warnings,
    )
