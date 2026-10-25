from types import SimpleNamespace

import pytest

from app.services.plan_validator import (
    PlanValidationError,
    injury_tags,
    validate_plan,
)


def exercise(slug, muscle="chest", equipment="bodyweight", contraindications=None):
    return SimpleNamespace(
        slug=slug,
        name_zh=slug,
        muscle_group=muscle,
        equipment=equipment,
        is_compound=True,
        contraindications=contraindications or [],
    )


EXERCISES = {
    "pushup": exercise("pushup"),
    "squat": exercise("squat", "legs", contraindications=["knee_pain"]),
    "row": exercise("row", "back", "dumbbell"),
    "curl": exercise("curl", "arms", "dumbbell"),
}


def make_plan(slugs, weeks=4):
    days = []
    for week in range(1, weeks + 1):
        days.append(
            {
                "week_index": week,
                "weekday": 1,
                "title": "全身",
                "focus": ["chest"],
                "exercises": [
                    {"slug": slug, "sets": 3, "reps": "8-10", "rest_sec": 60}
                    for slug in slugs
                ],
            }
        )
    return {"title": "测试计划", "weeks": weeks, "days": days}


def test_injury_keyword_map():
    assert injury_tags(["左膝半月板旧伤"]) == {"knee_pain"}
    assert injury_tags(["腰椎间盘突出", "肩袖"]) == {"lower_back", "shoulder_pain"}
    assert injury_tags([]) == set()


def test_valid_plan_passes():
    plan, warnings = validate_plan(
        make_plan(["pushup", "row", "curl"]),
        EXERCISES,
        equipment=["bodyweight", "dumbbell"],
        injuries=[],
        weekly_days=3,
        weeks=4,
    )
    assert len(plan["days"]) == 4
    assert not warnings


def test_unknown_slug_is_removed_and_day_dropped():
    plan, warnings = validate_plan(
        make_plan(["pushup", "not_real", "row", "curl"]),
        EXERCISES,
        equipment=["bodyweight", "dumbbell"],
        injuries=[],
        weekly_days=3,
        weeks=4,
    )
    assert all(
        item["slug"] != "not_real"
        for day in plan["days"]
        for item in day["exercises"]
    )
    assert any("not_real" in item for item in warnings)


def test_contraindicated_exercise_is_removed():
    plan, warnings = validate_plan(
        make_plan(["squat", "row", "curl", "pushup"]),
        EXERCISES,
        equipment=["bodyweight", "dumbbell"],
        injuries=["膝盖疼"],
        weekly_days=3,
        weeks=4,
    )
    assert all(
        item["slug"] != "squat"
        for day in plan["days"]
        for item in day["exercises"]
    )
    assert any("knee_pain" in item or "squat" in item for item in warnings)


def test_too_few_valid_exercises_raises():
    with pytest.raises(PlanValidationError):
        validate_plan(
            make_plan(["pushup", "not_real"]),
            EXERCISES,
            equipment=["bodyweight"],
            injuries=[],
            weekly_days=3,
            weeks=4,
        )


def test_values_are_clamped():
    raw = make_plan(["pushup", "row", "curl"])
    raw["days"][0]["exercises"][0].update(
        {"sets": 99, "rest_sec": 9999, "rpe": 42, "weight_kg": -5}
    )
    plan, _ = validate_plan(
        raw,
        EXERCISES,
        equipment=["bodyweight", "dumbbell"],
        injuries=[],
        weekly_days=3,
        weeks=4,
    )
    first = plan["days"][0]["exercises"][0]
    assert first["sets"] == 6
    assert first["rest_sec"] == 300
    assert first["rpe"] == 10
    assert first["weight_kg"] == 0


def test_missing_week_raises():
    raw = make_plan(["pushup", "row", "curl"])
    raw["days"] = raw["days"][:2]
    with pytest.raises(PlanValidationError):
        validate_plan(
            raw,
            EXERCISES,
            equipment=["bodyweight", "dumbbell"],
            injuries=[],
            weekly_days=3,
            weeks=4,
        )
