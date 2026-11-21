"""Life-event rescheduling for planned workouts.

A trip, a work deadline or a family event is not a single "move this day to
that day" request. The user gives a blocked window; the server finds the
planned sessions inside it and builds one confirmation card with either:

- ``training.reschedule`` actions that move the sessions to the next free slots;
- or ``training.skip`` actions when the user says they will not make them up.

The resolver is deterministic and read-only. The runtime owns confirmation,
execution and undo through the existing training capabilities.
"""

from __future__ import annotations

import itertools
import re
from collections import Counter
from datetime import date, datetime, timedelta

from sqlalchemy.orm import Session

from ..food_text import DIET_TZ

MAX_EVENT_ACTIONS = 5
MAX_SHIFT_DAYS = 30

# A life event must be tied to training, otherwise "今天开会好累" should stay a
# normal coaching conversation.
EVENT_WORDS = re.compile(
    r"出差|旅行|旅游|回老家|探亲|加班|开会|培训|考试|婚礼|"
    r"家里有事|生病|发烧|感冒|住院|手术|聚餐|应酬|"
    r"在外地|外地|不在本地|出国|驻外"
)
TRAINING_WORDS = re.compile(
    r"训练|计划|练|怎么办|怎么练|挪|顺延|跳过|没时间|不方便"
)
SKIP_WORDS = re.compile(r"跳过|不练|取消|算了|不补|不补了|先休息|都歇")

_WEEKDAYS = {
    "一": 0,
    "二": 1,
    "三": 2,
    "四": 3,
    "五": 4,
    "六": 5,
    "日": 6,
    "天": 6,
}
_CN_NUMBERS = {
    "一": 1,
    "两": 2,
    "二": 2,
    "三": 3,
    "四": 4,
    "五": 5,
    "六": 6,
    "七": 7,
    "八": 8,
    "九": 9,
    "十": 10,
}


def _cn_number(value: str) -> int | None:
    text = value.strip()
    if text.isdigit():
        return int(text)
    return _CN_NUMBERS.get(text)


def _this_monday(today: date) -> date:
    return today - timedelta(days=today.weekday())


def _next_monday(today: date) -> date:
    return today + timedelta(days=7 - today.weekday())


def _weekday(value: str) -> int | None:
    return _WEEKDAYS.get(value)


def _iso_range(message: str) -> tuple[date, date] | None:
    match = re.search(
        r"(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\s*"
        r"(?:到|至|-|~|—|－)\s*"
        r"(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})",
        message,
    )
    if match is None:
        return None
    try:
        return (
            date(int(match.group(1)), int(match.group(2)), int(match.group(3))),
            date(int(match.group(4)), int(match.group(5)), int(match.group(6))),
        )
    except ValueError:
        return None


def _month_day_range(message: str, today: date) -> tuple[date, date] | None:
    match = re.search(
        r"(\d{1,2})月(\d{1,2})[日号]?\s*"
        r"(?:到|至|-|~|—|－)\s*"
        r"(?:(\d{1,2})月)?(\d{1,2})[日号]?",
        message,
    )
    if match is None:
        return None
    month = int(match.group(1))
    start_day = int(match.group(2))
    end_month = int(match.group(3) or month)
    end_day = int(match.group(4))
    year = today.year
    try:
        start = date(year, month, start_day)
        end = date(year, end_month, end_day)
    except ValueError:
        return None
    if end < start:
        try:
            if end_month == month:
                end = date(
                    year + (1 if month == 12 else 0),
                    1 if month == 12 else month + 1,
                    end_day,
                )
            else:
                end = date(year + 1, end_month, end_day)
        except ValueError:
            return None
    return start, end


def _weekday_range(message: str, today: date) -> tuple[date, date] | None:
    match = re.search(
        r"(下周|下星期|下礼拜|这周|本周|这星期|本星期|这礼拜|本礼拜)?\s*"
        r"(?:周|星期|礼拜)([一二三四五六日天])\s*"
        r"(?:到|至|-|~|—|－)\s*"
        r"(?:周|星期|礼拜)?([一二三四五六日天])",
        message,
    )
    if match is None:
        return None
    mode = match.group(1) or ""
    start_index = _weekday(match.group(2))
    end_index = _weekday(match.group(3))
    if start_index is None or end_index is None:
        return None
    base = _next_monday(today) if mode.startswith("下") else _this_monday(today)
    start = base + timedelta(days=start_index)
    end = base + timedelta(days=end_index)
    if end < start:
        end += timedelta(days=7)
    if not mode and start < today:
        start += timedelta(days=7)
        end += timedelta(days=7)
    return start, end


def _single_weekday(message: str, today: date) -> tuple[date, date] | None:
    match = re.search(
        r"(下周|下星期|下礼拜|这周|本周|这星期|本星期|这礼拜|本礼拜)?\s*"
        r"(?:周|星期|礼拜)([一二三四五六日天])",
        message,
    )
    if match is None:
        return None
    mode = match.group(1) or ""
    index = _weekday(match.group(2))
    if index is None:
        return None
    if mode.startswith("下"):
        target = _next_monday(today) + timedelta(days=index)
    elif mode:
        target = _this_monday(today) + timedelta(days=index)
        if target < today:
            target += timedelta(days=7)
    else:
        target = today + timedelta(days=(index - today.weekday()) % 7)
    return target, target


def _weekend(message: str, today: date) -> tuple[date, date] | None:
    if "周末" not in message:
        return None
    if "下周末" in message:
        base = _next_monday(today)
        start = base + timedelta(days=5)
    elif today.weekday() == 6:
        start = today
    else:
        start = today + timedelta(days=(5 - today.weekday()) % 7)
    return start, start + timedelta(days=1)


def _next_week_duration(message: str, today: date) -> tuple[date, date] | None:
    if "下周" not in message:
        return None
    match = re.search(
        r"([一二两三四五六七八九十\d]+)\s*天",
        message,
    )
    if match is None:
        return None
    count = _cn_number(match.group(1))
    if count is None or not 1 <= count <= 14:
        return None
    start = _next_monday(today)
    return start, start + timedelta(days=count - 1)


def _relative_duration(message: str, today: date) -> tuple[date, date] | None:
    if not re.search(r"接下来|未来|后面|之后", message):
        return None
    if "一个月" in message:
        return today, today + timedelta(days=29)
    match = re.search(r"([一二两三四五六七八九十\d]+)\s*天", message)
    if match is None:
        return None
    count = _cn_number(match.group(1))
    if count is None or not 1 <= count <= 90:
        return None
    return today, today + timedelta(days=count - 1)


def parse_event_window(message: str, today: date) -> tuple[date, date] | None:
    """Parse the blocked window, not the workout date.

    Supported shapes: explicit ISO/month-day ranges, weekday ranges (下周一
    到周三), a single weekday, today/tomorrow, weekends and "下周出差三天".
    """
    window = _iso_range(message)
    if window is not None:
        return window
    window = _month_day_range(message, today)
    if window is not None:
        return window
    window = _weekday_range(message, today)
    if window is not None:
        return window
    if "周末" in message:
        return _weekend(message, today)
    window = _next_week_duration(message, today)
    if window is not None:
        return window
    window = _relative_duration(message, today)
    if window is not None:
        return window

    offsets = (
        ("大后天", 3),
        ("后天", 2),
        ("明天", 1),
        ("明日", 1),
        ("今天", 0),
        ("今日", 0),
    )
    for word, days in offsets:
        if word in message:
            target = today + timedelta(days=days)
            return target, target
    return _single_weekday(message, today)


def _plan_days(app_context: dict) -> list[dict]:
    plan = app_context.get("plan") if isinstance(app_context, dict) else None
    if not isinstance(plan, dict):
        return []
    days = plan.get("days")
    return [item for item in days if isinstance(item, dict)] if isinstance(days, list) else []


def _day_date(day: dict) -> date | None:
    try:
        return date.fromisoformat(str(day.get("date") or ""))
    except ValueError:
        return None


def _plan_gap(days: list[dict]) -> int:
    dates = sorted(
        value
        for value in (_day_date(day) for day in days)
        if value is not None
    )
    gaps = [
        (later - earlier).days
        for earlier, later in itertools.pairwise(dates)
        if 1 <= (later - earlier).days <= 7
    ]
    if not gaps:
        return 2
    return Counter(gaps).most_common(1)[0][0]


def _event_label(message: str) -> str:
    match = EVENT_WORDS.search(message)
    return match.group(0) if match else "这段时间"


def _range_label(start: date, end: date) -> str:
    if start == end:
        return f"{start.month}/{start.day}"
    return f"{start.month}/{start.day}–{end.month}/{end.day}"


def _day_labels(days: list[dict]) -> str:
    parts = []
    for day in days:
        value = _day_date(day)
        if value is None:
            continue
        parts.append(f"{value.month}/{value.day} {day.get('title') or '训练'}")
    return "、".join(parts)


def _target_label(targets: list[date]) -> str:
    return "、".join(f"{value.month}/{value.day}" for value in targets)


def resolve(
    db: Session,
    user_id: str,
    message: str,
    app_context: dict | None = None,
) -> dict:
    """Build a batch of reschedule/skip actions for one life event."""
    context = app_context if isinstance(app_context, dict) else {}
    plan = context.get("plan") if isinstance(context.get("plan"), dict) else {}
    plan_id = str(plan.get("id") or "")
    if not plan_id:
        return {
            "ready": False,
            "terminal": True,
            "question": "还没有训练计划；先让教练生成一份，再按生活安排重排。",
        }

    today = datetime.now(DIET_TZ).date()
    window = parse_event_window(message, today)
    if window is None:
        return {
            "ready": False,
            "question": (
                "这次大概哪几天不方便？可以说“下周一到周三出差”，"
                "或者“11月24到26号”。"
            ),
        }
    start, end = window
    if end < today:
        return {
            "ready": False,
            "terminal": True,
            "question": "这段时间已经过去了，告诉我接下来哪几天不方便。",
        }
    if (end - start).days > 14:
        return {
            "ready": False,
            "terminal": True,
            "question": (
                f"这次跨度有 {(end - start).days + 1} 天，逐次顺延会把整个计划推乱。"
                "建议这段时间先不要按原计划排，回来后再重新生成或调整；"
                "如果要逐次跳过，请把范围缩小到一周内再告诉我。"
            ),
        }

    days = _plan_days(context)
    affected = [
        day
        for day in days
        if (value := _day_date(day)) is not None
        and start <= value <= end
        and not day.get("completed")
        and not day.get("skipped")
    ]
    affected.sort(key=lambda day: _day_date(day) or today)
    label = _event_label(message)
    if not affected:
        return {
            "ready": False,
            "terminal": True,
            "question": f"{_range_label(start, end)} 本来没有训练安排，不用改。",
        }
    if len(affected) > MAX_EVENT_ACTIONS:
        return {
            "ready": False,
            "terminal": True,
            "question": (
                f"这段时间有 {len(affected)} 次训练，一次最多处理 "
                f"{MAX_EVENT_ACTIONS} 次。请把范围缩小到一周内，"
                "再告诉我哪几天不方便。"
            ),
        }

    if SKIP_WORDS.search(message):
        actions = []
        for day in affected:
            value = _day_date(day)
            if value is None:
                continue
            title = str(day.get("title") or "训练")
            summary = f"跳过 {value.month}/{value.day} {title}"
            actions.append(
                {
                    "capability_id": "training.skip",
                    "payload": {
                        "plan_id": plan_id,
                        "day_id": str(day.get("id") or ""),
                        "plan_version": plan.get("version"),
                        "date": value.isoformat(),
                        "title": title,
                        "summary": summary,
                    },
                    "summary": summary,
                }
            )
        reply = (
            f"{label}这几天有 {len(actions)} 次训练，我先按跳过处理，"
            "回来从下一次继续，不硬补。确认后生效。"
        )
    else:
        gap = _plan_gap(days)
        affected_ids = {id(day) for day in affected}
        occupied = {
            value
            for day in days
            if id(day) not in affected_ids
            for value in [_day_date(day)]
            if value is not None
        }
        targets: list[date] = []
        cursor = end + timedelta(days=1)
        previous: date | None = None
        for _ in affected:
            if previous is not None:
                cursor = max(cursor, previous + timedelta(days=gap))
            while (
                cursor in occupied
                or cursor in targets
                or cursor <= end
            ):
                cursor += timedelta(days=1)
            targets.append(cursor)
            previous = cursor
        if not targets or (targets[-1] - end).days > MAX_SHIFT_DAYS:
            return {
                "ready": False,
                "terminal": True,
                "question": (
                    "后面 30 天没有足够的空档来顺延这些训练。"
                    "要不要改成跳过？直接说“都跳过”。"
                ),
            }
        actions = []
        for day, target in zip(affected, targets, strict=False):
            value = _day_date(day)
            if value is None:
                continue
            title = str(day.get("title") or "训练")
            summary = (
                f"{value.month}/{value.day} {title} → "
                f"{target.month}/{target.day}"
            )
            actions.append(
                {
                    "capability_id": "training.reschedule",
                    "payload": {
                        "plan_id": plan_id,
                        "day_id": str(day.get("id") or ""),
                        "plan_version": plan.get("version"),
                        "from_date": value.isoformat(),
                        "to_date": target.isoformat(),
                        "title": title,
                        "summary": summary,
                    },
                    "summary": summary,
                }
            )
        reply = (
            f"{label}这几天有 {len(actions)} 次训练受影响："
            f"{_day_labels(affected)}。我按空档排到 {_target_label(targets)}，"
            "确认后生效。"
        )

    if not actions:
        return {
            "ready": False,
            "terminal": True,
            "question": "没有找到可以调整的训练，先看看训练手账。",
        }
    return {
        "ready": True,
        "payload": {
            "summary": f"调整 {len(actions)} 次训练",
            "batch": actions,
            "reply": reply,
        },
        "reply": reply,
    }
