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
CONFIGURE_REMINDERS = register(
    Capability(
        id="ui.configure_reminders",
        domain="ui",
        kind="write",
        title="设置提醒",
        description="打开/关闭训练提醒并设置时间",
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


def _reminder_time(message: str) -> tuple[int, int] | None:
    clock = re.search(r"(\d{1,2})\s*[:：]\s*(\d{1,2})", message)
    if clock is not None:
        hour, minute = int(clock.group(1)), int(clock.group(2))
        if 0 <= hour <= 23 and 0 <= minute <= 59:
            return hour, minute
        return None
    point = re.search(
        r"(早上|上午|中午|下午|晚上|傍晚)?\s*(\d{1,2})\s*点\s*(半|\d{1,2})?",
        message,
    )
    if point is None:
        return None
    hour = int(point.group(2))
    minute = 30 if point.group(3) == "半" else int(point.group(3) or 0)
    period = point.group(1) or ""
    if period in {"下午", "晚上", "傍晚"} and hour < 12:
        hour += 12
    if period == "中午" and hour < 11:
        hour += 12
    if 0 <= hour <= 23 and 0 <= minute <= 59:
        return hour, minute
    return None


def resolve_reminders(message: str) -> dict:
    enabled = not bool(re.search(r"关闭|关掉|不要|取消", message))
    if not enabled:
        return {
            "ready": True,
            "payload": {"enabled": False},
            "summary": "准备关闭训练提醒。",
        }
    parsed = _reminder_time(message)
    if parsed is None:
        return {
            "ready": False,
            "questions": ["提醒设在几点？可以说“早上7点”或“20:30”。"],
        }
    hour, minute = parsed
    return {
        "ready": True,
        "payload": {
            "enabled": True,
            "hour": hour,
            "minute": minute,
        },
        "summary": f"准备把训练提醒设为 {hour:02d}:{minute:02d}。",
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
