"""Delete accounts whose 15-day cooling-off period has expired.

Run from a daily cron/job:
    python scripts/purge_deleted_users.py
"""

from __future__ import annotations

import argparse
import sys
from datetime import timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select

from app.db import SessionLocal
from app.models import User, utcnow


def purge(days: int = 15) -> int:
    cutoff = utcnow() - timedelta(days=max(1, days))
    with SessionLocal() as db:
        users = (
            db.execute(
                select(User).where(
                    User.deleted_at.is_not(None),
                    User.deleted_at <= cutoff,
                )
            )
            .scalars()
            .all()
        )
        for user in users:
            db.delete(user)
        db.commit()
        return len(users)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--days", type=int, default=15)
    args = parser.parse_args()
    count = purge(args.days)
    print(f"purged {count} deleted account(s)")


if __name__ == "__main__":
    main()
