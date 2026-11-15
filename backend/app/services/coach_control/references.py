"""Resolve omitted dates, meals and metrics from the recent conversation.

This module is deliberately pure: it never writes data and never calls an LLM.
The control plane uses it before routing so deterministic capabilities can
receive an explicit date/meal instead of re-parsing pronouns themselves.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Any, Protocol, Sequence
from zoneinfo import ZoneInfo

from ..food_text import parse_food_date, parse_meal

DIET_TZ = ZoneInfo("Asia/Shanghai")
WEEKDAYS = {
    "一": 0,
    "二": 1,
    "三": 2,
    "四": 3,
    "五": 4,
    "六": 5,
    "日": 6,
    "天": 6,
}
METRICS = (
    ("body_fat", r"体脂"),
    ("waist", r"腰围"),
    ("arm", r"臂围|手臂围"),
    ("thigh", r"腿围|大腿围"),
    ("weight", r"体重|称重|称了"),
)


class TurnLike(Protocol):
    input_text: str
    reply: str | None
    intent: str | None


@dataclass(frozen=True)
class ReferenceSet:
    date: str | None = None
    previous_date: str | None = None
    meal: str | None = None
    metric: str | None = None
    exercise: str | None = None
    intent: str | None = None
    source: str = "none"

    def as_dict(self) -> dict[str, str | None]:
        return {
            "date": self.date,
            "previous_date": self.previous_date,
            "meal": self.meal,
            "metric": self.metric,
            "exercise": self.exercise,
            "intent": self.intent,
            "source": self.source,
        }


def _explicit_date(text: str, today: date) -> str | None:
    parsed = parse_food_date(text, now=datetime.now(DIET_TZ))
    if parsed is not None:
        return parsed.isoformat()

    explicit = re.search(r"(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})", text)
    if explicit is not None:
        try:
            return date(
                int(explicit.group(1)),
                int(explicit.group(2)),
                int(explicit.group(3)),
            ).isoformat()
        except ValueError:
            return None

    month_day = re.search(r"(\d{1,2})月(\d{1,2})[日号]", text)
    if month_day is not None:
        try:
            return date(today.year, int(month_day.group(1)), int(month_day.group(2))).isoformat()
        except ValueError:
            return None

    weekday = re.search(r"(下周|本周|这周|周|星期|礼拜)([一二三四五六日天])", text)
    if weekday is not None:
        target = WEEKDAYS[weekday.group(2)]
        delta = (target - today.weekday()) % 7
        if delta == 0 and re.search(r"下周", text):
            delta = 7
        return (today + timedelta(days=delta)).isoformat()
    return None


def _last_turn_date(turns: Sequence[TurnLike], today: date) -> str | None:
    for turn in reversed(turns):
        parsed = _explicit_date(turn.input_text or "", today)
        if parsed is not None:
            return parsed
    return None


def _last_meal(turns: Sequence[TurnLike]) -> str | None:
    for turn in reversed(turns):
        meal = parse_meal(turn.input_text or "")
        if meal is not None:
            return meal
    return None


def _metric(text: str) -> str | None:
    for value, pattern in METRICS:
        if re.search(pattern, text):
            return value
    return None


def _intent(text: str, turns: Sequence[TurnLike]) -> str | None:
    last_intent = next(
        (turn.intent for turn in reversed(turns) if turn.intent),
        None,
    )
    if re.search(r"改到|改期|挪到|顺延|换到|调到", text) and re.search(
        r"训练|计划|课", text
    ):
        return "training.reschedule"
    if re.search(r"练什么|练哪|下一练|下次训练|训练安排|接下来.*练", text):
        return "training.preview_next"
    if re.search(r"那\s*(明天|后天|今天|周|星期|礼拜)", text) and last_intent == (
        "training.preview_next"
    ):
        return "training.preview_next"
    if re.search(r"那\s*(体重|体脂|腰围|臂围|腿围)", text):
        return "body.review_trend"
    return None


def resolve_references(
    message: str,
    turns: Sequence[TurnLike],
    *,
    pending: Any = None,
    plan: dict | None = None,
) -> ReferenceSet:
    """Best-effort, deterministic resolution of short follow-up messages."""
    text = message.strip()
    today = datetime.now(DIET_TZ).date()
    payload = getattr(pending, "payload", None)
    payload = payload if isinstance(payload, dict) else {}

    date_value = _explicit_date(text, today)
    source = "explicit" if date_value else "none"
    previous_date = _last_turn_date(turns, today)
    if date_value is None and re.search(r"那天|上次|之前|刚刚|刚才", text):
        inherited = previous_date or payload.get("date")
        if inherited:
            date_value = str(inherited)
            source = "inherited"
    if date_value is None and payload.get("date"):
        date_value = str(payload.get("date"))
        source = "pending"

    meal = parse_meal(text) or payload.get("meal") or _last_meal(turns)
    metric = _metric(text) or None
    intent = _intent(text, turns)

    return ReferenceSet(
        date=date_value,
        previous_date=previous_date,
        meal=str(meal) if meal else None,
        metric=metric,
        intent=intent,
        source=source,
    )
