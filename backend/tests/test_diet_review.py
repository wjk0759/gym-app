from datetime import date, datetime
from types import SimpleNamespace

from app.services.diet_review import DIET_TZ, build_diet_review, range_bounds


def _plan(day: date) -> SimpleNamespace:
    return SimpleNamespace(
        plan_date=day,
        plan={
            "targets": {
                "target_kcal": 2100,
                "protein_g": 150,
                "carb_g": 230,
                "fat_g": 65,
            },
            "meals": [
                {"meal": "breakfast", "name": "早餐", "kcal": 500, "protein_g": 30},
                {"meal": "lunch", "name": "午餐", "kcal": 700, "protein_g": 50},
                {"meal": "dinner", "name": "晚餐", "kcal": 700, "protein_g": 55},
            ],
        },
    )


def _log(day: date, meal: str, kcal: float, protein: float, plan_meal=None):
    logged_at = datetime(day.year, day.month, day.day, 12, tzinfo=DIET_TZ)
    return SimpleNamespace(
        logged_at=logged_at,
        kcal=kcal,
        protein=protein,
        plan_date=day if plan_meal else None,
        plan_meal=plan_meal,
    )


def test_review_counts_only_linked_plan_meals():
    day = date(2026, 11, 9)
    logs = [
        _log(day, "lunch", 680, 48, plan_meal="lunch"),
        _log(day, "snack", 300, 5),
    ]

    result = build_diet_review([_plan(day)], logs, day, day)

    totals = result["totals"]
    assert totals["planned_days"] == 1
    assert totals["planned_meals"] == 3
    assert totals["logged_plan_meals"] == 1
    assert totals["adherence_rate"] == 0.33
    assert totals["actual_kcal"] == 980
    assert len(result["missing_meals"]) == 2
    assert result["missing_meals"][0]["meal"] == "breakfast"
    assert result["insight"]


def test_review_includes_actual_only_days_without_counting_them_as_plan():
    planned_day = date(2026, 11, 9)
    extra_day = date(2026, 11, 10)
    logs = [_log(extra_day, "dinner", 900, 40)]

    result = build_diet_review([_plan(planned_day)], logs, planned_day, extra_day)

    assert result["totals"]["planned_meals"] == 3
    assert result["totals"]["actual_kcal"] == 900
    extra = next(day for day in result["days"] if day["date"] == extra_day.isoformat())
    assert extra["status"] == "no_plan"


def test_range_bounds_rejects_reversed_and_too_long_ranges():
    try:
        range_bounds(date(2026, 11, 10), date(2026, 11, 9))
    except ValueError as exc:
        assert "不能晚于" in str(exc)
    else:
        raise AssertionError("reversed range should fail")

    try:
        range_bounds(date(2025, 1, 1), date(2026, 11, 9))
    except ValueError as exc:
        assert "366" in str(exc)
    else:
        raise AssertionError("long range should fail")
