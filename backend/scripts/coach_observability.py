"""Print coach quality and cost metrics from the configured database.

Run from backend:
    .\\.venv\\Scripts\\python.exe scripts\\coach_observability.py --days 7
    .\\.venv\\Scripts\\python.exe scripts\\coach_observability.py --days 30 --json

Read-only. Uses AI jobs, agent runs and user feedback that production already
writes; no model call is made.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from app.db import SessionLocal  # noqa: E402
from app.services.coach_observability import build_report, format_report  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=7, help="window size (1-90)")
    parser.add_argument("--json", action="store_true", help="emit JSON")
    args = parser.parse_args()

    with SessionLocal() as db:
        report = build_report(db, days=args.days)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(format_report(report))


if __name__ == "__main__":
    main()
