from types import SimpleNamespace

from app.models import Exercise
from app.services.plan_generator import fallback_plan


def _exercise(slug: str, muscle: str) -> Exercise:
    return Exercise(
        slug=slug,
        name_zh=slug,
        muscle_group=muscle,
        equipment="dumbbell",
        is_compound=True,
        difficulty=1,
        contraindications=[],
        is_active=True,
    )


def _profile() -> SimpleNamespace:
    return SimpleNamespace(
        weekly_days=3,
        session_minutes=45,
        experience="beginner",
        equipment=["dumbbell"],
    )


def test_focus_areas_are_inserted_into_every_training_day():
    available = [
        _exercise("bench", "chest"),
        _exercise("row", "back"),
        _exercise("squat", "legs"),
        _exercise("curl", "arms"),
        _exercise("press", "shoulders"),
        _exercise("plank", "core"),
    ]

    plan = fallback_plan(
        _profile(),
        "build_muscle",
        available,
        weeks=1,
        split="3分化",
        focus=["arms"],
    )

    assert plan["days"]
    assert all("arms" in day["focus"] for day in plan["days"])
    # The split is still present; focus is a priority, not a replacement.
    assert all(len(day["exercises"]) >= 4 for day in plan["days"])


def test_focus_areas_are_not_truncated_to_two():
    available = [
        _exercise("bench", "chest"),
        _exercise("row", "back"),
        _exercise("squat", "legs"),
        _exercise("curl", "arms"),
        _exercise("press", "shoulders"),
        _exercise("plank", "core"),
    ]

    plan = fallback_plan(
        _profile(),
        "build_muscle",
        available,
        weeks=1,
        split="3分化",
        focus=["arms", "chest", "back"],
    )

    for day in plan["days"]:
        assert {"arms", "chest", "back"} <= set(day["focus"])


def test_all_focus_areas_means_balanced_training():
    available = [
        _exercise("bench", "chest"),
        _exercise("row", "back"),
        _exercise("squat", "legs"),
        _exercise("curl", "arms"),
        _exercise("press", "shoulders"),
        _exercise("plank", "core"),
    ]
    all_focus = ["chest", "back", "legs", "glutes", "shoulders", "arms", "core"]

    balanced = fallback_plan(
        _profile(),
        "build_muscle",
        available,
        weeks=1,
        split="3分化",
        focus=[],
    )
    selected_all = fallback_plan(
        _profile(),
        "build_muscle",
        available,
        weeks=1,
        split="3分化",
        focus=all_focus,
    )

    assert [day["focus"] for day in balanced["days"]] == [
        day["focus"] for day in selected_all["days"]
    ]
