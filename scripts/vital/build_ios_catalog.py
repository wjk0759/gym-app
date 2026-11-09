#!/usr/bin/env python3
"""Build the iOS-bundled Vital exercise catalog.

Reads the merged/renamed catalog (data/vital/vital_actions_v2.json) and emits
ios/FitAI/Resources/vital_exercises.json in the exact shape the iOS
``ResourceExercise`` decoder expects, plus ``aliases`` / ``slug_aliases``.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "data" / "vital" / "vital_actions_v2.json"
DST = ROOT / "ios" / "FitAI" / "Resources" / "vital_exercises.json"


def main() -> None:
    actions = json.loads(SRC.read_text(encoding="utf-8"))
    rows = []
    for a in actions:
        steps = a.get("instructions_zh") or []
        instructions = "\n".join(str(s) for s in steps) if steps else None
        rows.append(
            {
                "slug": a["slug"],
                "name_zh": a["name_zh"],
                "name_en": a.get("name_en") or None,
                "muscle_group": a.get("muscle_group") or "core",
                "equipment": a.get("equipment") or "other",
                "is_compound": bool(a.get("is_compound")),
                "difficulty": int(a.get("difficulty") or 1),
                "instructions": instructions,
                "contraindications": [],
                "aliases": sorted(a.get("aliases") or []),
                "slug_aliases": sorted(a.get("slug_aliases") or []),
            }
        )
    rows.sort(key=lambda r: r["name_zh"])
    DST.write_text(
        json.dumps(rows, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    size = DST.stat().st_size
    print(f"actions={len(rows)} bytes={size}")
    print(f"wrote {DST}")


if __name__ == "__main__":
    main()
