"""Deactivate exact duplicate active memories.

Older versions of the coach stored the same generic preference more than once.
The live upsert path now replaces stable keys and skips exact duplicates, but
this script cleans rows created before that guard existed.

Run from backend:
    .\\.venv\\Scripts\\python.exe scripts\\dedupe_memories.py --dry-run
    .\\.venv\\Scripts\\python.exe scripts\\dedupe_memories.py
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sqlalchemy import select  # noqa: E402

from app.db import SessionLocal  # noqa: E402
from app.models import AIMemory  # noqa: E402


def _is_generic_preference(item: AIMemory) -> bool:
    return item.kind == "preference" and item.memory_key in {"preference", "general"}


def _is_specific(item: AIMemory) -> bool:
    return item.kind in {"schedule", "equipment", "injury", "goal"} or item.memory_key in {
        "weekly_schedule",
        "training_days",
        "session_minutes",
        "equipment",
        "injury",
        "goal",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    with SessionLocal() as db:
        rows = (
            db.execute(
                select(AIMemory)
                .where(AIMemory.active.is_(True))
                .order_by(
                    AIMemory.user_id,
                    AIMemory.updated_at.desc().nullslast(),
                    AIMemory.created_at.desc(),
                )
            )
            .scalars()
            .all()
        )

        seen: set[tuple[str, str, str, str]] = set()
        duplicates: list[tuple[AIMemory, str]] = []
        specific_users = {
            item.user_id for item in rows if _is_specific(item)
        }
        redundant_tokens = (
            "每周",
            "训练日",
            "分钟",
            "器械",
            "哑铃",
            "杠铃",
            "出差",
        )
        for item in rows:
            key = (
                item.user_id,
                item.kind,
                item.memory_key,
                " ".join((item.content or "").split()).lower(),
            )
            if key in seen:
                duplicates.append((item, "exact duplicate"))
                continue
            seen.add(key)
            if (
                item.user_id in specific_users
                and _is_generic_preference(item)
                and any(token in (item.content or "") for token in redundant_tokens)
            ):
                duplicates.append((item, "covered by specific memory"))

        if not duplicates:
            print("No duplicate or redundant active memories found.")
            return

        for item, reason in duplicates:
            print(
                f"{'[dry-run] ' if args.dry_run else ''}deactivate "
                f"{item.id} user={item.user_id} kind={item.kind} "
                f"key={item.memory_key} reason={reason} "
                f"content={item.content[:60]!r}"
            )
            if not args.dry_run:
                item.active = False

        if not args.dry_run:
            db.commit()
            print(f"Deactivated {len(duplicates)} duplicate/redundant memories.")
        else:
            print(f"Would deactivate {len(duplicates)} duplicate/redundant memories.")


if __name__ == "__main__":
    main()
