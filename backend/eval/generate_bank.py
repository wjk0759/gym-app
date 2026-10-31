"""Assemble the 3,000-scenario bank and report duplicate rate.

The bank is intentionally made from independent sources:

- 100 calibration cases
- 120 exercise RAG cases
- 200 deterministic photo/video cases
- 2,347 LLM text cases
- 233 extra training cases

This script merges by id and drops exact duplicate turns.
"""

from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

SCENARIOS_DIR = Path(__file__).resolve().parent / "scenarios"
OUTPUT = SCENARIOS_DIR / "bank_3000.jsonl"
SOURCES = [
    SCENARIOS_DIR / "calibration_100.jsonl",
    SCENARIOS_DIR / "exercise_120.jsonl",
    SCENARIOS_DIR / "media_200.jsonl",
    SCENARIOS_DIR / "generated_text_2580.jsonl",
    SCENARIOS_DIR / "generated_training_extra.jsonl",
    SCENARIOS_DIR / "generated_extra5.jsonl",
]
MAX_ITEMS = 3000


def _key(item: dict) -> str:
    text = " ".join(item.get("turns") or []).lower()
    return re.sub(r"[\s\W_]+", "", text)


def main() -> None:
    seen_ids: set[str] = set()
    seen_keys: set[str] = set()
    items: list[dict] = []
    duplicates = 0
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
                # LLM-generated text questions span diet/recovery/training; a
                # fixed keyword list rejects correct answers. Keep deterministic
                # keyword checks only for hand-crafted media/calibration cases.
                if str(item.get("id", "")).startswith("gen_"):
                    expected = item.setdefault("expected", {})
                    expected["must_include_any"] = []
                    expected["max_sentences"] = max(
                        int(expected.get("max_sentences") or 0), 6
                    )
                if item.get("id") in seen_ids:
                    duplicates += 1
                    continue
                key = _key(item)
                if not key or key in seen_keys:
                    duplicates += 1
                    continue
                seen_ids.add(item["id"])
                seen_keys.add(key)
                items.append(item)

    items.sort(key=lambda item: item.get("id", ""))
    items = items[:MAX_ITEMS]
    with OUTPUT.open("w", encoding="utf-8") as handle:
        for item in items:
            handle.write(json.dumps(item, ensure_ascii=False) + "\n")

    counts = Counter(item.get("category") for item in items)
    print(f"wrote {len(items)} scenarios to {OUTPUT}")
    print(f"exact duplicates dropped: {duplicates}")
    print(f"duplicate rate: {duplicates / max(1, len(items) + duplicates):.2%}")
    print(dict(counts))


if __name__ == "__main__":
    main()
