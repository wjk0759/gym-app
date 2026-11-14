"""Configure the weekly plan shape from a coach message.

The old agent could change frequency, weekdays, session length and split via
its plan tool. This capability ports that path without an LLM round trip.
"""

from __future__ import annotations

import re

from sqlalchemy.orm import Session

from ....models import Profile
from ... import access
from ...plan_generator import DEFAULT_WEEKDAYS, build_template_plan
from ...queries import active_goal
from ...serializers import save_plan, serialize_program
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="training.configure_plan",
        domain="training",
        kind="write",
        title="调整计划频率",
        description="修改每周训练天数、训练日、时长或分化",
        requires_confirmation=True,
        undo=True,
        events=("TrainingPlanAdjusted",),
        refreshes=("plan", "schedule", "workouts", "diet"),
    )
)

WEEKDAY_MAP = {
    "一": 1,
    "二": 2,
    "三": 3,
    "四": 4,
    "五": 5,
    "六": 6,
    "日": 7,
    "天": 7,
}
WEEKDAY_LABELS = ["", "一", "二", "三", "四", "五", "六", "日"]
SPLIT_ALIASES = {
    "1分化": "1分化",
    "2分化": "2分化",
    "3分化": "3分化",
    "4分化": "4分化",
    "5分化": "5分化",
    "推拉腿": "3分化",
    "全身": "1分化",
}


def _weekdays(text: str) -> list[int]:
    found: list[int] = []
    for match in re.finditer(r"(?:周|星期|礼拜)([一二三四五六日天])", text):
        value = WEEKDAY_MAP.get(match.group(1))
        if value is not None:
            found.append(value)
    for match in re.finditer(
        r"(?<![一二三四五六日天])([一二三四五六日天]{2,})(?![一二三四五六日天])",
        text,
    ):
        for char in match.group(1):
            value = WEEKDAY_MAP.get(char)
            if value is not None:
                found.append(value)
    return sorted(set(found))


def _weekly_days(text: str) -> int | None:
    match = re.search(r"(?:每周|一周)\s*(\d)\s*(?:练|次|天)?", text)
    if match:
        return max(1, min(7, int(match.group(1))))
    match = re.search(r"(\d)\s*(?:练|次|天)", text)
    if match:
        return max(1, min(7, int(match.group(1))))
    return None


def _session_minutes(text: str) -> int | None:
    match = re.search(r"(\d{2,3})\s*(?:分钟|min)", text, flags=re.IGNORECASE)
    if match:
        return max(15, min(180, int(match.group(1))))
    return None


def _split(text: str) -> str | None:
    match = re.search(r"([1-5])\s*分化", text)
    if match:
        return f"{match.group(1)}分化"
    for label, value in SPLIT_ALIASES.items():
        if label in text:
            return value
    return None


def _goal_type(db: Session, user_id: str) -> str:
    goal = active_goal(db, user_id)
    return goal.type if goal is not None else "recomp"


def resolve(db: Session, user_id: str, message: str) -> dict:
    if not access.has_pro(db, user_id):
        return {
            "ready": False,
            "questions": ["调整训练频率需要 Pro；当前计划仍可继续使用。"],
        }
    profile = db.get(Profile, user_id)
    if profile is None:
        return {"ready": False, "questions": ["先完成基础档案。"]}

    weekdays = _weekdays(message)
    weekly_days = len(weekdays) if weekdays else _weekly_days(message)
    minutes = _session_minutes(message)
    split = _split(message)
    if weekly_days is None and not weekdays and minutes is None and split is None:
        return {
            "ready": False,
            "questions": [
                "想怎么调？可以说“每周 3 练，二四六，45 分钟，3 分化”。"
            ],
        }
    if weekly_days is None:
        weekly_days = max(1, min(7, int(profile.weekly_days or 3)))
    if weekdays and len(weekdays) != weekly_days:
        weekly_days = len(weekdays)

    goal_type = _goal_type(db, user_id)
    result = build_template_plan(
        db,
        profile,
        goal_type,
        weeks=4,
        split=split,
        weekly_days=weekly_days,
        session_minutes=minutes,
        weekdays=weekdays or None,
    )
    plan_doc = result.get("plan") if isinstance(result, dict) else None
    if not isinstance(plan_doc, dict):
        plan_doc = result
    program = save_plan(
        db,
        user_id,
        plan_doc,
        goal_type=goal_type,
        generated_by="rule-configure",
        model_name="template",
        status="pending",
    )
    # Keep the profile in sync so later plan generations use the same shape.
    profile.weekly_days = weekly_days
    if minutes is not None:
        profile.session_minutes = minutes
    if split is not None:
        profile.split = split
    db.flush()

    data = serialize_program(program)
    regular_days = weekdays or DEFAULT_WEEKDAYS.get(weekly_days, [])
    weekday_label = "、".join(f"周{WEEKDAY_LABELS[item]}" for item in regular_days)
    summary = (
        f"已排好新计划：每周 {weekly_days} 练"
        f"（{weekday_label}），每次 {minutes or profile.session_minutes or 45} 分钟"
        + (f"，{split}" if split else "")
        + "。确认后激活。"
    )
    return {
        "ready": True,
        "program_id": program.id,
        "plan": data,
        "summary": summary,
    }


def activate(db: Session, user_id: str, program_id: str) -> dict:
    from .plan import activate as activate_plan

    return activate_plan(db, user_id, program_id)


def undo_activate(
    db: Session,
    user_id: str,
    program_id: str,
    previous_program_id: str | None,
) -> dict:
    from .plan import undo_activate as undo_plan_activate

    return undo_plan_activate(db, user_id, program_id, previous_program_id)
