"""Diet logging capability.

The model never supplies calories. The server resolves the text, builds the
payload and writes the same FoodLog rows used by the rest of the app.
"""

from __future__ import annotations

from sqlalchemy.orm import Session

from ...coach_actions.food_actions import execute_log_food, undo_log_food
from ...coach_actions.schemas import LogFoodPayload
from ...food_text import food_log_context, resolve_food_text
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="diet.log_food",
        domain="diet",
        kind="write",
        title="记录饮食",
        description="把用户描述的食物解析成营养估算并写入饮食记录",
        requires_confirmation=True,
        undo=True,
        events=("FoodLogged",),
    )
)


async def resolve(
    db: Session,
    user_id: str,
    message: str,
) -> dict:
    context = food_log_context(message)
    resolution = await resolve_food_text(
        db,
        user_id,
        message,
        meal=context["meal"],
        target_date=context["date"],
    )
    return {
        **resolution,
        "date": context["date"],
        "meal": context["meal"],
        "text": message,
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    data = LogFoodPayload.model_validate(payload)
    return execute_log_food(db, user_id, action_id, data)


def undo(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return undo_log_food(
        db,
        user_id,
        action_id,
        LogFoodPayload.model_validate(payload),
    )
