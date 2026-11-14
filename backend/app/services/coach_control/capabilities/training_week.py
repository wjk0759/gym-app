"""Read-only weekly training schedule.

Summarizes the days in the current or next calendar week from the client plan
snapshot, including completed/skipped state.
"""

from __future__ import annotations

import re
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session

from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="training.week_schedule",
        domain="training",
        kind="read",
        title="本周训练安排",
        description="按周列出计划训练、日期和完成状态",
        requires_confirmation=False,
        undo=False,
        events=("TrainingWeekReviewed",),
    )
)

WEEKDAYS = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]


def _week_start(message: str, today: date) -> date:
    monday = today - timedelta(days=today.weekday())
    if re.search(r"下周|下星期", message):
        return monday + timedelta(days=7)
    if re.search(r"上周|上星期", message):
        return monday - timedelta(days=7)
    return monday


def resolve(db: Session, user_id: str, message: str, context: dict) -> dict:
    plan = context.get("plan") if isinstance(context, dict) else None
    days = plan.get("days") if isinstance(plan, dict) else None
    if not isinstance(days, list) or not days:
        return {
            "ready": True,
            "payload": {
                "summary": "当前还没有可查看的训练计划。",
                "wins": [],
                "watchouts": ["先生成一份训练计划，再查看每周安排。"],
                "actions": [],
            },
        }
    today = datetime.now(ZoneInfo("Asia/Shanghai")).date()
    start = _week_start(message, today)
    end = start + timedelta(days=6)
    chosen = []
    for item in days:
        if not isinstance(item, dict):
            continue
        raw = str(item.get("date") or "")
        try:
            when = date.fromisoformat(raw) if raw else None
        except ValueError:
            when = None
        if when is None or not start <= when <= end:
            continue
        chosen.append((when, item))
    chosen.sort(key=lambda pair: pair[0])
    label = "本周" if start <= today <= end else (
        "下周" if start > today else "上周"
    )
    if not chosen:
        return {
            "ready": True,
            "payload": {
                "summary": f"{label}（{start.month}月{start.day}日–"
                f"{end.month}月{end.day}日）没有安排训练。",
                "wins": [],
                "watchouts": ["休息周也要保持日常活动；需要加练可以直接说。"],
                "actions": [],
            },
        }
    wins = []
    skipped = 0
    completed = 0
    for when, item in chosen:
        status = "已完成" if item.get("completed") else (
            "已跳过" if item.get("skipped") else "待训练"
        )
        if item.get("completed"):
            completed += 1
        if item.get("skipped"):
            skipped += 1
        wins.append(
            f"{WEEKDAYS[when.weekday()]} {when.month}月{when.day}日："
            f"{item.get('title') or '训练'}（{status}）"
        )
    watchouts = []
    if skipped:
        watchouts.append(f"{skipped} 次已跳过，需要的话可以改期。")
    return {
        "ready": True,
        "payload": {
            "summary": (
                f"{label}（{start.month}月{start.day}日–"
                f"{end.month}月{end.day}日）计划 {len(chosen)} 练，"
                f"已完成 {completed} 次。"
            ),
            "wins": wins,
            "watchouts": watchouts,
            "actions": [],
        },
    }
