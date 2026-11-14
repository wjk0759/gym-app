"""Client-side coach actions expressed as control-plane cards.

Starting a workout or opening a screen does not write domain data, but it still
needs a confirmed intent and a receipt. These capabilities return a payload the
iOS app executes after the user confirms.
"""

from __future__ import annotations

import re

from sqlalchemy.orm import Session

from ..registry import Capability, register

START_TRAINING = register(
    Capability(
        id="ui.start_training",
        domain="ui",
        kind="write",
        title="开始训练",
        description="打开今天或下一练的训练页",
        requires_confirmation=True,
        undo=False,
        events=("UIActionRequested",),
    )
)
OPEN_SCREEN = register(
    Capability(
        id="ui.open_screen",
        domain="ui",
        kind="write",
        title="打开页面",
        description="打开训练、饮食、身体或设置页面",
        requires_confirmation=True,
        undo=False,
        events=("UIActionRequested",),
    )
)

SCREENS = {
    "今天": "today",
    "训练记录": "workout_history",
    "训练历史": "workout_history",
    "日程": "training_schedule",
    "训练安排": "training_schedule",
    "饮食": "nutrition",
    "餐": "nutrition",
    "体型分析": "body_analysis",
    "体态分析": "body_analysis",
    "照片分析": "body_analysis",
    "体型": "body_analysis",
    "身体打卡": "body_checkin",
    "身体": "body_checkin",
    "设置": "profile_edit",
    "档案": "profile_edit",
    "计划": "plan",
    "教练": "coach",
    "器械识别": "equipment_scan",
    "器械扫描": "equipment_scan",
    "识别器械": "equipment_scan",
    "器械": "equipment",
    "记忆": "agent_memory",
    "经期": "period_schedule",
}


def _plan(context: dict) -> dict:
    plan = context.get("plan") if isinstance(context, dict) else None
    return plan if isinstance(plan, dict) else {}


def resolve_start(db: Session, user_id: str, context: dict) -> dict:
    plan = _plan(context)
    days = [
        item
        for item in (plan.get("days") or [])
        if isinstance(item, dict)
        and not item.get("skipped")
        and not item.get("completed")
        and item.get("date")
    ]
    if not days:
        return {
            "ready": False,
            "questions": ["当前没有可开始的训练，先看看计划安排。"],
        }
    days.sort(key=lambda item: str(item.get("date")))
    today = days[0]
    return {
        "ready": True,
        "payload": {
            "day_id": today.get("id"),
            "title": today.get("title") or "训练",
            "date": today.get("date"),
        },
        "summary": f"准备开始「{today.get('title') or '训练'}」。",
    }


def resolve_open(message: str) -> dict:
    if re.search(r"识别|扫描|拍照|拍张|看看", message) and re.search(
        r"器械|设备", message
    ):
        return {
            "ready": True,
            "payload": {"screen": "equipment_scan", "title": "器械识别"},
            "summary": "准备打开器械识别。",
        }
    if re.search(r"分析|评估|看看|照片", message) and re.search(
        r"体型|体态|身材", message
    ):
        return {
            "ready": True,
            "payload": {"screen": "body_analysis", "title": "体型分析"},
            "summary": "准备打开体型分析。",
        }
    for label, screen in SCREENS.items():
        if label in message:
            return {
                "ready": True,
                "payload": {"screen": screen, "title": label},
                "summary": f"准备打开「{label}」。",
            }
    return {
        "ready": False,
        "questions": [
            "想打开哪个页面？训练记录、训练安排、饮食、身体、计划或设置。"
        ],
    }


def execute_ui(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return {"ui_action": payload}


def undo_ui(
    db: Session,
    user_id: str,
    action_id: str,
    payload: dict,
) -> dict:
    return {"restored": False, "ui_action": payload}
