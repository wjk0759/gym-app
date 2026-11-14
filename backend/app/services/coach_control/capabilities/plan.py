"""Training plan generation capability."""

from __future__ import annotations

from sqlalchemy.orm import Session

from ....models import Profile, Program
from ... import access
from ...plan_generator import generate_plan
from ...queries import active_goal
from ...serializers import (
    archive_active_plans,
    goal_to_dict,
    save_plan,
    serialize_program,
)
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="training.generate_plan",
        domain="training",
        kind="write",
        title="生成训练计划",
        description="按档案和目标生成一份 4 周训练计划，确认后激活",
        requires_confirmation=True,
        undo=False,
        events=("TrainingPlanGenerated",),
    )
)


async def resolve(db: Session, user_id: str) -> dict:
    profile = db.get(Profile, user_id)
    if profile is None or not profile.height_cm or not profile.weight_kg:
        return {
            "ready": False,
            "questions": ["先补全身高和体重，我才能排计划。"],
        }
    if not access.has_pro(db, user_id):
        return {
            "ready": False,
            "questions": ["重新生成训练计划需要 Pro；当前计划仍可继续使用。"],
        }
    goal = active_goal(db, user_id)
    goal_type = goal.type if goal is not None else "recomp"
    result = await generate_plan(
        db,
        profile,
        goal_type=goal_type,
        goal=goal_to_dict(goal),
        weeks=4,
        split=None,
        focus=None,
        strict_equipment=False,
    )
    program = save_plan(
        db,
        user_id,
        result["plan"],
        goal_type=goal_type,
        generated_by=result["generated_by"],
        model_name=result["model"],
        status="pending",
    )
    data = serialize_program(program)
    data["warnings"] = result.get("warnings") or []
    return {"ready": True, "program_id": program.id, "plan": data}


def activate(db: Session, user_id: str, program_id: str) -> dict:
    program = db.get(Program, program_id)
    if program is None or program.user_id != user_id:
        raise LookupError("计划不存在")
    if program.status not in {"pending", "archived"}:
        raise ValueError("这份计划当前不能激活")
    archive_active_plans(db, user_id)
    program.status = "active"
    db.flush()
    return {"program_id": program.id, "plan": serialize_program(program)}


def discard(db: Session, user_id: str, program_id: str) -> None:
    program = db.get(Program, program_id)
    if program is not None and program.user_id == user_id and program.status == "pending":
        program.status = "archived"
        db.flush()
