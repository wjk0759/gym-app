"""Global model-token budget shared by every AI entry point.

Budgets are configured with ``LLM_DAILY_TOKEN_BUDGET`` and
``LLM_MONTHLY_TOKEN_BUDGET`` (0 disables the guard). Usage is summed from
``ai_jobs`` so a restart or a second worker sees the same number. At 70% and
90% we log an alert once per business period; once a limit is reached future
calls raise :class:`BudgetExceeded` and services fall back to their deterministic
templates.
"""

from __future__ import annotations

import logging
import threading
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import AIJob, AIRuntimeControl, User, utcnow

logger = logging.getLogger(__name__)

BUSINESS_TZ = timezone(timedelta(hours=8))
_lock = threading.Lock()
_last_alert: dict[str, int] = {}


class BudgetExceeded(RuntimeError):
    def __init__(self, period: str, used: int, limit: int) -> None:
        super().__init__(
            f"LLM {period} token budget exhausted: {used}/{limit}"
        )
        self.period = period
        self.used = used
        self.limit = limit


class AIUnavailable(RuntimeError):
    def __init__(self, reason: str | None = None) -> None:
        super().__init__(reason or "AI temporarily paused")
        self.reason = reason


@dataclass(frozen=True)
class BudgetSnapshot:
    day_tokens: int
    month_tokens: int
    daily_limit: int
    monthly_limit: int


def _period_starts(now: datetime) -> tuple[datetime, datetime]:
    local = now.astimezone(BUSINESS_TZ)
    day = local.date()
    month = date(day.year, day.month, 1)
    day_start = datetime.combine(day, datetime.min.time(), tzinfo=BUSINESS_TZ)
    month_start = datetime.combine(month, datetime.min.time(), tzinfo=BUSINESS_TZ)
    return day_start.astimezone(timezone.utc), month_start.astimezone(timezone.utc)


def _token_sum(db: Session, since: datetime) -> int:
    total = db.execute(
        select(
            func.coalesce(
                func.sum(
                    func.coalesce(AIJob.input_tokens, 0)
                    + func.coalesce(AIJob.output_tokens, 0)
                ),
                0,
            )
        ).where(AIJob.created_at >= since)
    ).scalar()
    return int(total or 0)


def _alert(period: str, used: int, limit: int, ratio: float) -> None:
    level = 90 if ratio >= 0.9 else 70
    with _lock:
        if _last_alert.get(period, 0) >= level:
            return
        _last_alert[period] = level
    log = logger.error if level == 90 else logger.warning
    log(
        "LLM %s token budget at %d%%: %d/%d",
        period,
        int(ratio * 100),
        used,
        limit,
    )


def ensure_budget(
    db: Session,
    *,
    now: datetime | None = None,
) -> BudgetSnapshot:
    """Return current usage and raise when a configured limit is exhausted."""
    daily_limit = max(0, int(settings.llm_daily_token_budget))
    monthly_limit = max(0, int(settings.llm_monthly_token_budget))
    if daily_limit == 0 and monthly_limit == 0:
        return BudgetSnapshot(0, 0, 0, 0)

    current = now or utcnow()
    day_start, month_start = _period_starts(current)
    day_tokens = _token_sum(db, day_start)
    month_tokens = _token_sum(db, month_start)
    snapshot = BudgetSnapshot(day_tokens, month_tokens, daily_limit, monthly_limit)

    if daily_limit > 0:
        ratio = day_tokens / daily_limit
        if ratio >= 1:
            raise BudgetExceeded("daily", day_tokens, daily_limit)
        if ratio >= 0.7:
            _alert("daily", day_tokens, daily_limit, ratio)
    if monthly_limit > 0:
        ratio = month_tokens / monthly_limit
        if ratio >= 1:
            raise BudgetExceeded("monthly", month_tokens, monthly_limit)
        if ratio >= 0.7:
            _alert("monthly", month_tokens, monthly_limit, ratio)
    return snapshot


def reset_runtime_state() -> None:
    """Clear alert de-duplication state (tests)."""
    with _lock:
        _last_alert.clear()


def ensure_ai_enabled(db: Session, user_id: str | None) -> None:
    """Reject model calls while an operator has paused AI globally.

    Test accounts remain available as a whitelist so the team can verify a fix
    or exercise TestFlight flows during an incident.
    """
    control = db.get(AIRuntimeControl, 1)
    if control is None or control.enabled:
        return
    if user_id is not None:
        is_test = db.execute(
            select(User.is_test).where(User.id == user_id)
        ).scalar_one_or_none()
        if is_test:
            return
    raise AIUnavailable(control.reason)
