"""Apply a body analysis focus to the active training plan."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import BodyAnalysisRecord, Exercise, Program
from ...queries import active_program
from ...serializers import (
    archive_active_plans,
    load_program,
    save_plan,
    serialize_program,
)
from ..registry import Capability, register
from .plan import activate

CAPABILITY = register(
    Capability(
        id="body.apply_analysis",
        domain="body",
        kind="write",
        title="应用体型分析",
        description="把体型分析重点应用到当前训练计划",
        requires_confirmation=True,
        undo=True,
        events=("BodyAnalysisApplied",),
        refreshes=("body", "plan", "schedule", "workouts", "review"),
    )
)


def _latest_analysis(db: Session, user_id: str) -> BodyAnalysisRecord | None:
    return (
        db.execute(
            select(BodyAnalysisRecord)
            .where(
                BodyAnalysisRecord.user_id == user_id,
                BodyAnalysisRecord.deleted_at.is_(None),
            )
            .order_by(BodyAnalysisRecord.created_at.desc())
        )
        .scalars()
        .first()
    )


def _focus(record: BodyAnalysisRecord) -> list[str]:
    return [
        str(value).strip()
        for value in record.focus_areas or []
        if str(value).strip()
    ]


def _affected(
    db: Session,
    program: Program,
    focus: list[str],
) -> list[tuple[str, str]]:
    result: list[tuple[str, str]] = []
    for day in program.days:
        for item in day.exercises:
            exercise = db.get(Exercise, item.exercise_slug)
            if exercise is None:
                continue
            if exercise.muscle_group not in focus:
                continue
            if int(item.sets or 0) >= 6:
                continue
            result.append((day.title, exercise.name_zh or exercise.slug))
    return result


def resolve(db: Session, user_id: str) -> dict:
    record = _latest_analysis(db, user_id)
    if record is None:
        return {
            "ready": False,
            "questions": ["还没有可应用的体型分析，先做一次体型分析。"],
        }
    if record.applied_to_plan:
        return {
            "ready": False,
            "questions": ["这份体型分析已经应用到计划了。"],
        }
    focus = _focus(record)
    if not focus:
        return {
            "ready": False,
            "questions": ["这份分析没有明确的训练重点，先看看分析详情。"],
        }
    program = active_program(db, user_id)
    if program is None:
        return {
            "ready": False,
            "questions": ["当前还没有训练计划，先生成计划再应用分析。"],
        }
    program = load_program(db, program.id) or program
    affected = _affected(db, program, focus)
    if not affected:
        return {
            "ready": False,
            "questions": [
                "分析重点和当前计划动作没有匹配，或这些动作已经到组数上限。"
            ],
        }
    focus_labels = "、".join(focus)
    summary = (
        f"准备把体型分析应用到当前计划：重点 {focus_labels}，"
        f"调整 {len(affected)} 个动作，每个 +1 组"
    )
    return {
        "ready": True,
        "payload": {
            "analysis_id": record.client_id,
            "program_id": program.id,
            "focus_areas": focus,
            "affected_count": len(affected),
            "summary": summary,
        },
    }


def execute(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    record = db.execute(
        select(BodyAnalysisRecord).where(
            BodyAnalysisRecord.user_id == user_id,
            BodyAnalysisRecord.client_id == str(payload.get("analysis_id") or ""),
            BodyAnalysisRecord.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if record is None:
        raise LookupError("体型分析不存在")
    program = db.get(Program, str(payload.get("program_id") or ""))
    if program is None or program.user_id != user_id:
        raise LookupError("计划不存在")
    if program.status != "active":
        raise ValueError("计划已变化，请重新生成这张卡")
    focus = _focus(record)
    if not focus:
        raise ValueError("体型分析没有明确重点")
    program = load_program(db, program.id) or program
    data = serialize_program(program)
    for day in data.get("days") or []:
        for item in day.get("exercises") or []:
            exercise = db.get(Exercise, str(item.get("slug") or ""))
            if exercise is None or exercise.muscle_group not in focus:
                continue
            item["sets"] = min(6, int(item.get("sets") or 0) + 1)
    data["title"] = (str(data.get("title") or "训练计划") + " · 体型分析")[:120]
    new_program = save_plan(
        db,
        user_id,
        data,
        goal_type=program.goal_type,
        generated_by="body-analysis",
        model_name=program.model_name,
        status="active",
    )
    applied_before = bool(record.applied_to_plan)
    record.applied_to_plan = True
    db.flush()
    return {
        "before": {
            "previous_program_id": program.id,
            "new_program_id": new_program.id,
            "analysis_id": record.client_id,
            "applied_before": applied_before,
        },
        "after": {
            "program_id": new_program.id,
            "analysis_id": record.client_id,
        },
        "plan": serialize_program(new_program),
    }


def undo(
    db: Session,
    user_id: str,
    before: dict,
    payload: dict,
) -> dict:
    previous_id = str((before or {}).get("previous_program_id") or "")
    new_id = str((before or {}).get("new_program_id") or "")
    if previous_id:
        activate(db, user_id, previous_id)
    elif new_id:
        current = db.get(Program, new_id)
        if current is not None and current.user_id == user_id:
            archive_active_plans(db, user_id)
    analysis_id = str(
        (before or {}).get("analysis_id")
        or payload.get("analysis_id")
        or ""
    )
    record = db.execute(
        select(BodyAnalysisRecord).where(
            BodyAnalysisRecord.user_id == user_id,
            BodyAnalysisRecord.client_id == analysis_id,
            BodyAnalysisRecord.deleted_at.is_(None),
        )
    ).scalar_one_or_none()
    if record is not None:
        record.applied_to_plan = bool(
            (before or {}).get("applied_before", False)
        )
    db.flush()
    return {"restored": True, "program_id": previous_id or None}
