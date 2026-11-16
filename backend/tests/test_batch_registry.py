from app.services.coach_control.batch import BATCHABLE, MAX_BATCH_ACTIONS, key_for


def test_batch_registry_is_declarative():
    assert MAX_BATCH_ACTIONS == 5
    assert "diet.dislike_food" in BATCHABLE
    assert "profile.update_equipment" in BATCHABLE
    assert "training.edit_day_exercise" in BATCHABLE


def test_duplicate_keys_are_per_resource_not_per_capability():
    lunch = key_for(
        "diet.log_planned_meal",
        {"date": "2026-11-18", "meal": "lunch"},
    )
    dinner = key_for(
        "diet.log_planned_meal",
        {"date": "2026-11-18", "meal": "dinner"},
    )
    assert lunch != dinner

    chicken = key_for(
        "diet.dislike_food",
        {"food_key": "library:鸡胸肉"},
    )
    broccoli = key_for(
        "diet.dislike_food",
        {"food_key": "library:西兰花"},
    )
    assert chicken != broccoli


def test_simple_actions_still_dedupe_by_capability():
    assert key_for("profile.update_equipment", {"equipment": ["dumbbell"]}) == (
        "profile.update_equipment"
    )
    assert key_for("body.log_weight", {"weight_kg": 73}) == "body.log_weight"
