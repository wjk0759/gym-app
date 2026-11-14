"""Normalize plan-day state ids and repair dates before the plan start.

Some production rows store uppercase UUIDs in ``plan_day_states.day_id`` while
``program_days.id`` is lowercase. This script:

1. normalizes ``day_id`` / ``plan_id`` to lowercase and collapses duplicates;
2. moves week-1 dates that fall before the plan's first Monday to the correct
   date and refreshes ``client_updated_at`` so clients receive the repair.

Run from backend:
    python scripts/repair_plan_schedule.py
    python scripts/repair_plan_schedule.py --apply
"""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from datetime import timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from sqlalchemy import func, select  # noqa: E402

from app.db import SessionLocal  # noqa: E402
from app.models import PlanDayState, Program, ProgramDay, utcnow  # noqa: E402


def _first_week_start(program: Program):
    start = program.start_date
    monday = start - timedelta(days=start.weekday())
    if monday < start:
        monday += timedelta(days=7)
    return monday


def _normalize_ids(db) -> int:
    states = db.execute(select(PlanDayState)).scalars().all()
    groups: dict[tuple[str, str, str], list[PlanDayState]] = defaultdict(list)
    for state in states:
        groups[
            (
                state.user_id,
                str(state.plan_id).lower(),
                str(state.day_id).lower(),
            )
        ].append(state)
    changed = 0
    for (_, plan_id, day_id), rows in groups.items():
        rows.sort(
            key=lambda item: (
                item.client_updated_at or item.updated_at or item.created_at,
                item.updated_at or item.created_at,
            ),
            reverse=True,
        )
        keep = rows[0]
        if keep.plan_id != plan_id:
            keep.plan_id = plan_id
            changed += 1
        if keep.day_id != day_id:
            keep.day_id = day_id
            changed += 1
        for duplicate in rows[1:]:
            db.delete(duplicate)
            changed += 1
    db.flush()
    return changed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="write changes")
    args = parser.parse_args()

    with SessionLocal() as db:
        id_changes = _normalize_ids(db)
        programs = (
            db.execute(
                select(Program).where(Program.status == "active")
            )
            .scalars()
            .all()
        )
        date_changes = 0
        for program in programs:
            week_start = _first_week_start(program)
            days = {
                str(day.id).lower(): day
                for day in db.execute(
                    select(ProgramDay).where(
                        ProgramDay.program_id == program.id
                    )
                )
                .scalars()
                .all()
            }
            states = (
                db.execute(
                    select(PlanDayState).where(
                        PlanDayState.user_id == program.user_id,
                        func.lower(PlanDayState.plan_id)
                        == str(program.id).lower(),
                    )
                )
                .scalars()
                .all()
            )
            for state in states:
                if state.assigned_date is None:
                    continue
                if state.assigned_date >= week_start:
                    continue
                day = days.get(str(state.day_id).lower())
                if day is None:
                    continue
                corrected = week_start + timedelta(
                    days=(int(day.week_index) - 1) * 7
                    + int(day.weekday)
                    - 1
                )
                print(
                    f"{program.id} {state.day_id}: "
                    f"{state.assigned_date} -> {corrected}"
                )
                date_changes += 1
                if args.apply:
                    state.assigned_date = corrected
                    state.client_updated_at = utcnow()
                    state.updated_at = utcnow()
        if args.apply:
            db.commit()
            print(
                f"normalized {id_changes} ids; "
                f"updated {date_changes} plan-day states"
            )
        else:
            db.rollback()
            print(
                f"dry run: normalize {id_changes} ids; "
                f"update {date_changes} plan-day states"
            )


if __name__ == "__main__":
    main()
