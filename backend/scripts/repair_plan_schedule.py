"""Repair plan-day dates that fall before the plan's first week.

Plans created midweek can have week-1 schedule states on the Monday before the
plan start. The app now starts such plans on the next Monday, but historical
rows need a one-off repair so synced clients receive the corrected dates.

Run from backend:
    python scripts/repair_plan_schedule.py
    python scripts/repair_plan_schedule.py --apply
"""

from __future__ import annotations

import argparse
import sys
from datetime import timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from sqlalchemy import select  # noqa: E402

from app.db import SessionLocal  # noqa: E402
from app.models import PlanDayState, Program, ProgramDay, utcnow  # noqa: E402


def _first_week_start(program: Program):
    start = program.start_date
    monday = start - timedelta(days=start.weekday())
    if monday < start:
        monday += timedelta(days=7)
    return monday


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="write changes")
    args = parser.parse_args()

    with SessionLocal() as db:
        programs = (
            db.execute(
                select(Program).where(Program.status == "active")
            )
            .scalars()
            .all()
        )
        total = 0
        for program in programs:
            week_start = _first_week_start(program)
            days = {
                day.id: day
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
                        PlanDayState.plan_id == program.id,
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
                day = days.get(state.day_id)
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
                total += 1
                if args.apply:
                    state.assigned_date = corrected
                    state.client_updated_at = utcnow()
                    state.updated_at = utcnow()
        if args.apply:
            db.commit()
            print(f"updated {total} plan-day states")
        else:
            print(f"dry run: {total} plan-day states would be updated")


if __name__ == "__main__":
    main()
