"""Declarative batch registry.

The runtime still resolves each clause through the legacy capability chain, but
membership, the action cap and duplicate keys live here. Adding a capability to
batch requires an explicit registry entry.
"""

from __future__ import annotations

MAX_BATCH_ACTIONS = 5

BATCHABLE = frozenset(
    {
        "diet.log_food",
        "diet.update_log",
        "diet.delete_log",
        "diet.log_planned_meal",
        "diet.skip_planned_meal",
        "diet.restore_planned_meal",
        "diet.swap_meal",
        "training.restore_plan",
        "training.configure_plan",
        "training.reschedule",
        "training.add_plan_day",
        "training.skip",
        "training.dislike_exercise",
        "diet.dislike_food",
        "profile.update_equipment",
        "body.log_weight",
        "profile.update_goal",
        "training.edit_day_exercise",
        "training.edit_day_exercises",
        "training.delete_workout",
        "training.update_workout",
        "training.log_strength",
        "training.log_cardio",
    }
)


def key_for(capability_id: str, payload: dict) -> str:
    if capability_id in {
        "diet.log_planned_meal",
        "diet.skip_planned_meal",
        "diet.restore_planned_meal",
        "diet.swap_meal",
    }:
        return (
            f"{capability_id}:{payload.get('date')}:{payload.get('meal')}"
        )
    if capability_id in {"diet.update_log", "diet.delete_log"}:
        return f"{capability_id}:{payload.get('client_id')}"
    if capability_id == "diet.dislike_food":
        return f"{capability_id}:{payload.get('food_key')}"
    if capability_id == "training.dislike_exercise":
        return f"{capability_id}:{payload.get('slug')}"
    return capability_id
