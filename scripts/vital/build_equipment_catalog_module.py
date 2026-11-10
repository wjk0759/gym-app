#!/usr/bin/env python3
"""Generate backend/app/services/equipment_catalog_v2.py from the JSON catalog.

Embeds the 94-type equipment catalog + exercise mapping as Python literals so the
backend does not depend on the repo-root data/ directory at runtime.
"""

from __future__ import annotations

import json
import pprint
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAT = ROOT / "data" / "vital" / "equipment_catalog_v2.json"
MAP = ROOT / "data" / "vital" / "equipment_exercise_map.json"
OUT = ROOT / "backend" / "app" / "services" / "equipment_catalog_v2.py"

HEADER = '''# Auto-generated from data/vital/equipment_catalog_v2.json + equipment_exercise_map.json.
# Do not edit by hand. Regenerate with:
#   python scripts/vital/build_equipment_catalog_module.py

from __future__ import annotations


def _equipment() -> list[dict]:
    return EQUIPMENT


def _map() -> dict[str, list[str]]:
    return EXERCISE_MAP


def get(slug: str | None) -> dict | None:
    for item in EQUIPMENT:
        if item["slug"] == slug:
            return item
    return None


def match_name(name: str | None) -> dict | None:
    if not name:
        return None
    text = name.strip().lower()
    for item in EQUIPMENT:
        if text and (text in item["name_zh"].lower() or text in item["name_en"].lower()
                     or any(text in a.lower() for a in item["aliases"])):
            return item
    return None


def exercises_for(slug: str | None) -> list[str]:
    item = get(slug)
    if item is None:
        return []
    return EXERCISE_MAP.get(item["exercise_group"], [])


def confusables(slug: str | None) -> list[str]:
    """Machines sharing the same subcategory (press / pull / squat / ...)."""
    item = get(slug)
    if item is None:
        return []
    sub = item.get("subcategory") or ""
    if not sub:
        return []
    return [e["slug"] for e in EQUIPMENT
            if e["slug"] != slug and (e.get("subcategory") or "") == sub]


def prompt_catalog() -> str:
    """Recognition catalog: fixed machines + obvious free-weight/cardio anchors."""
    lines = []
    for item in EQUIPMENT:
        if item["recognition_class"] is None:
            continue
        aliases = " / ".join(item["aliases"][:3])
        lines.append(f"- {item['slug']}（{item['name_zh']}）" + (f"，也叫 {aliases}" if aliases else ""))
    return "\\n".join(lines)


'''

EQUIPMENT_PY = pprint.pformat(
    json.loads(CAT.read_text(encoding="utf-8"))["equipment"],
    width=88,
    sort_dicts=False,
)
MAP_PY = pprint.pformat(
    json.loads(MAP.read_text(encoding="utf-8"))["mapping"],
    width=88,
    sort_dicts=False,
)

body = HEADER + f"EQUIPMENT = {EQUIPMENT_PY}\n\n\nEXERCISE_MAP = {MAP_PY}\n"
OUT.write_text(body, encoding="utf-8")
print(f"wrote {OUT} ({len(body.splitlines())} lines)")
