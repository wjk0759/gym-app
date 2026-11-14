"""Training plan generation capability."""

from __future__ import annotations

from sqlalchemy.orm import Session

from ....models import Profile, Program
from ... import access
from ...plan_generator import generate_plan
from ...queries import active_goal, active_program
from ...serializers import (
    archive_active_plans,
    clone_program,
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
        undo=True,
        events=("TrainingPlanGenerated",),
    )
)
ADJUST = register(
    Capability(
        id="training.adjust_plan",
        domain="training",
        kind="write",
        title="调整训练计划",
        description="按减量、加量或降重量生成新版本计划",
        requires_confirmation=True,
        undo=True,
        events=("TrainingPlanAdjusted",),
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


def resolve_adjust(db: Session, user_id: str, message: str) -> dict:
    if not access.has_pro(db, user_id):
        return {
            "ready": False,
            "questions": ["调整计划需要 Pro；当前计划仍可继续使用。"],
        }
    source = active_program(db, user_id)
    if source is None:
        return {"ready": False, "questions": ["还没有可调整的训练计划。"]}

    sets_delta = 0
    multiplier = 1.0
    suffix = ""
    if any(word in message for word in ("减量", "太累", "恢复不过来", "降低强度", "少一点")):
        sets_delta = -1
        multiplier = 0.95
        suffix = " · 减量"
    elif any(word in message for word in ("加量", "太轻", "增加强度", "加重", "加一点")):
        sets_delta = 1
        multiplier = 1.025
        suffix = " · 加量"
    elif any(word in message for word in ("降低重量", "减重", "轻一点")):
        multiplier = 0.9
        suffix = " · 降重量"
    else:
        return {
            "ready": False,
            "questions": [
                "你想怎么调整？可以说“减量”“加量”“降低重量”。"
            ],
        }

    pending = clone_program(
        db,
        user_id,
        source,
        sets_delta=sets_delta,
        weight_multiplier=multiplier,
        title_suffix=suffix,
        generated_by="rule-adjustment",
        status="pending",
    )
    data = serialize_program(pending)
    return {
        "ready": True,
        "program_id": pending.id,
        "plan": data,
        "summary": f"已生成调整草案：{data.get('title') or '训练计划'}",
    }


def activate(db: Session, user_id: str, program_id: str) -> dict:
    program = db.get(Program, program_id)
    if program is None or program.user_id != user_id:
        raise LookupError("计划不存在")
    if program.status not in {"pending", "archived"}:
        raise ValueError("这份计划当前不能激活")
    previous = active_program(db, user_id)
    archive_active_plans(db, user_id)
    program.status = "active"
    db.flush()
    return {
        "program_id": program.id,
        "previous_program_id": previous.id if previous is not None else None,
        "plan": serialize_program(program),
    }


def undo_activate(
    db: Session,
    user_id: str,
    program_id: str,
    previous_program_id: str | None,
) -> dict:
    current = db.get(Program, program_id)
    if current is not None and current.user_id == user_id:
        current.status = "archived"
    previous = db.get(Program, previous_program_id) if previous_program_id else None
    if previous is not None and previous.user_id == user_id:
        previous.status = "active"
    db.flush()
    return {
        "restored": previous is not None,
        "program_id": previous.id if previous is not None else None,
    }


def discard(db: Session, user_id: str, program_id: str) -> None:
    program = db.get(Program, program_id)
    if program is not None and program.user_id == user_id and program.status == "pending":
        program.status = "archived"
        db.flush()
