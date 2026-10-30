"""Assemble the scenario bank from the category-specific files.

The 3,000-scenario target is built up incrementally: start with the 100-case
calibration and 120-case exercise RAG sets, then grow. This script merges and
dedupes the current inputs so `round.py` always runs against one bank.
"""

from __future__ import annotations

import json
from pathlib import Path

SCENARIOS_DIR = Path(__file__).resolve().parent / "scenarios"
OUTPUT = SCENARIOS_DIR / "bank.jsonl"
SOURCES = [
    SCENARIOS_DIR / "calibration_100.jsonl",
    SCENARIOS_DIR / "exercise_120.jsonl",
]


def main() -> None:
    seen: set[str] = set()
    items: list[dict] = []
    for source in SOURCES:
        if not source.exists():
            print(f"skip missing {source}")
            continue
        with source.open(encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                item = json.loads(line)
                if item.get("id") in seen:
                    continue
                seen.add(item["id"])
                items.append(item)
    items.sort(key=lambda item: item.get("id", ""))
    with OUTPUT.open("w", encoding="utf-8") as handle:
        for item in items:
            handle.write(json.dumps(item, ensure_ascii=False) + "\n")
    print(f"wrote {len(items)} scenarios to {OUTPUT}")


if __name__ == "__main__":
    main()
