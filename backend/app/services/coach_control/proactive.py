"""Scheduled proactive coach checks.

The app has no APNs worker yet, so "push" means a coach inbox item that the app
shows the next time it refreshes. A daily cron calls this service through the
protected endpoint or ``python -m app.services.coach_control.proactive``.

Two high-signal nudges are enough for the first slice:

- recovery pressure is high/strained;
- a planned workout in the last three days was missed.

Each kind is deduplicated by a recent inbox row, so a daily job cannot spam the
same user. The service is deterministic and never calls the LLM.
"""

from __future__ import annotations

import json
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import (
    CoachInbox,
    PlanDayState,
    Profile,
    Program,
    User,
    WorkoutSession,
    utcnow,
)
from ..food_text import DIET_TZ
from ..queries import active_program
from .events import create_inbox_item
from .readiness import snapshot as readiness_snapshot

RECOVERY_COOLDOWN_DAYS = 7
MISSED_COOLDOWN_DAYS = 3
MISSED_LOOKBACK_DAYS = 3


def _recent_inbox(
    db: Session,
    user_id: str,
    kind: str,
    days: int,
    now: datetime,
) -> bool:
    row = db.execute(
        select(CoachInbox.id)
        .where(
            CoachInbox.user_id == user_id,
            CoachInbox.kind == kind,
            CoachInbox.created_at >= now - timedelta(days=days),
        )
        .limit(1)
    ).scalar_one_or_none()
    return row is not None


def _recovery_nudge(
    db: Session,
    user_id: str,
    now: datetime,
) -> dict | None:
    if _recent_inbox(
        db,
        user_id,
        "recovery",
        RECOVERY_COOLDOWN_DAYS,
        now,
    ):
        return None
    readiness = readiness_snapshot(db, user_id, now=now)
    if readiness["status"] not in {"high_risk", "strained"}:
        return None
    actions = readiness.get("actions") or []
    body = str(readiness.get("summary") or "").strip()
    if actions:
        body = f"{body} {actions[0]}".strip()
    item = create_inbox_item(
        db,
        user_id,
        kind="recovery",
        title=(
            "恢复压力偏高"
            if readiness["status"] == "high_risk"
            else "恢复窗口偏紧"
        ),
        body=body,
        payload={
            "prompt": "我恢复得怎么样？",
            "readiness": readiness,
            "source": "proactive",
        },
    )
    return {"user_id": user_id, "kind": "recovery", "title": item.title}


def _scheduled_state(
    db: Session,
    user_id: str,
    program: Program,
    day_id: str,
) -> PlanDayState | None:
    return db.execute(
        select(PlanDayState).where(
            PlanDayState.user_id == user_id,
            PlanDayState.plan_id == program.id.lower(),
            PlanDayState.day_id == day_id.lower(),
        )
    ).scalar_one_or_none()


def _rotated_date(program: Program, day) -> date:
    """Mirror iOS ``PlanScheduleEngine``: week 1 starts at plan.start_date."""
    start = program.start_date or datetime.now(DIET_TZ).date()
    offset = (int(day.weekday) - start.isoweekday()) % 7
    return start + timedelta(days=(int(day.week_index) - 1) * 7 + offset)


def _missed_training_nudge(
    db: Session,
    user_id: str,
    now: datetime,
) -> dict | None:
    if _recent_inbox(
        db,
        user_id,
        "training",
        MISSED_COOLDOWN_DAYS,
        now,
    ):
        return None
    program = active_program(db, user_id)
    if program is None:
        return None
    today = now.astimezone(DIET_TZ).date()
    earliest = today - timedelta(days=MISSED_LOOKBACK_DAYS)
    candidates: list[tuple[object, object]] = []
    for day in program.days:
        state = _scheduled_state(db, user_id, program, day.id)
        if state is not None and state.skipped_at is not None:
            continue
        scheduled = (
            state.assigned_date
            if state is not None and state.assigned_date is not None
            else _rotated_date(program, day)
        )
        if not (earliest <= scheduled < today):
            continue
        starts = datetime.combine(
            scheduled,
            time.min,
            tzinfo=DIET_TZ,
        ).astimezone(timezone.utc)
        ends = starts + timedelta(days=1)
        completed = db.execute(
            select(WorkoutSession.id)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.program_day_id == day.id,
                WorkoutSession.started_at >= starts,
                WorkoutSession.started_at < ends,
            )
            .limit(1)
        ).scalar_one_or_none()
        if completed is None:
            candidates.append((scheduled, day))
    if not candidates:
        return None
    scheduled, day = sorted(candidates, key=lambda item: item[0])[-1]
    title = str(day.title or "训练")
    item = create_inbox_item(
        db,
        user_id,
        kind="training",
        title="有一次训练没完成",
        body=(
            f"{scheduled.month}/{scheduled.day} 的「{title}」还没有记录。"
            "今天补一次轻的，或者告诉我改期。"
        ),
        payload={
            "prompt": f"帮我把 {scheduled.isoformat()} 的{title}改期",
            "date": scheduled.isoformat(),
            "day_id": day.id,
            "source": "proactive",
        },
    )
    return {"user_id": user_id, "kind": "training", "title": item.title}


def run(
    db: Session,
    *,
    now: datetime | None = None,
    limit: int = 500,
) -> dict:
    """Scan active users and create at most one proactive item per run."""
    moment = now or utcnow()
    users = (
        db.execute(
            select(User)
            .where(
                User.status == "active",
                User.deleted_at.is_(None),
            )
            .order_by(User.created_at)
            .limit(max(1, min(limit, 2000)))
        )
        .scalars()
        .all()
    )
    created: list[dict] = []
    for user in users:
        if db.get(Profile, user.id) is None:
            continue
        item = _recovery_nudge(db, user.id, moment)
        if item is None:
            item = _missed_training_nudge(db, user.id, moment)
        if item is not None:
            created.append(item)
    db.flush()
    return {
        "scanned": len(users),
        "created": len(created),
        "items": created,
    }


def main() -> None:
    from ...db import SessionLocal

    with SessionLocal() as db:
        result = run(db)
        db.commit()
        print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
