"""Build the coach and equipment knowledge bases.

Food nutrition was deliberately removed: it is not used by the vision model and
its 2015 regional composition values did not survive answer-level evaluation.
This builder now only produces:

- ``coach_knowledge.jsonl``: 736 exercise technique cards + curated cards
- ``equipment_knowledge.jsonl``: equipment names, aliases, muscles and cues
- ``manifest.json``: counts, sources, licenses and build metadata

Outputs are committed so production does not rebuild them at boot. Runtime
retrieval is standard-library only.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date, datetime, timezone
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = BACKEND_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
OUT_DIR = DATA_DIR / "knowledge"

SEED_JSON = RAW_DIR / "knowledge_seed.json"
EXERCISES_JSONL = DATA_DIR / "exercises_rag.jsonl"

EXERCISE_SOURCE = "hasaneyldrm/exercises-dataset"
EXERCISE_SOURCE_URL = "https://github.com/hasaneyldrm/exercises-dataset"
EXERCISE_LICENSE = "MIT (text); media excluded"


def _norm_space(value: str) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def _read_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def _write_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True))
            handle.write("\n")


def _write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")


def build_coach(seed: dict) -> tuple[list[dict], dict]:
    stats = {"exercise_rows": 0, "exercise_dropped": 0, "curated_cards": 0}
    rows: list[dict] = []
    seen_names: set[str] = set()
    with EXERCISES_JSONL.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            item = json.loads(line)
            name = _norm_space(item.get("name_zh") or "")
            if not name or name in seen_names:
                stats["exercise_dropped"] += 1
                continue
            seen_names.add(name)
            steps = item.get("steps_zh") or []
            if not isinstance(steps, list):
                steps = [str(steps)]
            aliases = [
                str(alias)
                for alias in (item.get("aliases") or [])
                if isinstance(alias, str) and len(alias) >= 2
            ][:12]
            target = item.get("target_zh") or ""
            body_part = item.get("body_part_zh") or ""
            equipment = item.get("equipment_zh") or ""
            safety = item.get("safety_note") or ""
            text = (
                f"目标肌群：{target or body_part or '未标注'}；"
                f"部位：{body_part or '未标注'}；器械：{equipment or '未标注'}。"
                f"步骤：{' '.join(str(step) for step in steps[:8])}"
                f"{' 安全提示：' + safety if safety else ''}"
            )
            rows.append(
                {
                    "id": f"coach-ex-{item.get('id') or len(rows) + 1}",
                    "domain": "coach",
                    "kind": "exercise",
                    "title": name,
                    "name_en": item.get("name_en") or "",
                    "aliases": aliases,
                    "tags": [tag for tag in [body_part, equipment, target] if tag],
                    "text": text[:1600],
                    "search_text": " ".join(
                        [
                            name,
                            str(item.get("name_en") or ""),
                            " ".join(aliases),
                            body_part,
                            equipment,
                            target,
                        ]
                    ),
                    "source": item.get("source") or EXERCISE_SOURCE,
                    "source_url": EXERCISE_SOURCE_URL,
                    "license": item.get("license") or EXERCISE_LICENSE,
                }
            )
            stats["exercise_rows"] += 1

    for card in seed.get("coach_cards") or []:
        rows.append(
            {
                "id": card["id"],
                "domain": "coach",
                "kind": card.get("kind") or "principle",
                "title": card["title"],
                "aliases": [],
                "tags": list(card.get("tags") or []),
                "text": card["text"],
                "search_text": " ".join(
                    [card["title"], " ".join(card.get("tags") or []), card["text"]]
                ),
                "source": card.get("source") or "FitAI coach knowledge",
                "source_url": card.get("source_url") or "",
                "license": card.get("license") or "original-summary",
            }
        )
        stats["curated_cards"] += 1
    return rows, stats


def build_equipment(seed: dict) -> tuple[list[dict], dict]:
    if str(BACKEND_DIR) not in sys.path:
        sys.path.insert(0, str(BACKEND_DIR))
    from app.services.equipment_catalog_v2 import EQUIPMENT  # noqa: PLC0415

    cues = seed.get("equipment_cues") or {}
    rows: list[dict] = []
    for item in EQUIPMENT:
        slug = item["slug"]
        name = item["name_zh"]
        aliases = [str(alias) for alias in (item.get("aliases") or []) if alias]
        cue = cues.get(slug) or {}
        visual = list(cue.get("visual_cues") or [])
        if not visual:
            visual = [
                f"{item.get('category') or '器械'}类",
                f"目标肌群：{'、'.join(item.get('target_muscles') or [])}",
            ]
        confusions = list(cue.get("confusions") or [])
        setup = cue.get("setup") or ""
        safety = cue.get("safety") or ""
        text = (
            f"名称：{name}；英文：{item.get('name_en') or ''}；"
            f"类别：{item.get('category') or ''}/{item.get('subcategory') or ''}；"
            f"目标肌群：{'、'.join(item.get('target_muscles') or [])}。"
            f"识别线索：{'；'.join(visual)}。"
            f"{'易混淆：' + '、'.join(confusions) + '。' if confusions else ''}"
            f"{'使用要点：' + setup if setup else ''}"
            f"{' 安全：' + safety if safety else ''}"
        )
        rows.append(
            {
                "id": f"equipment-{slug}",
                "domain": "equipment",
                "title": name,
                "slug": slug,
                "name_en": item.get("name_en") or "",
                "aliases": aliases,
                "category": item.get("category") or "",
                "subcategory": item.get("subcategory") or "",
                "target_muscles": list(item.get("target_muscles") or []),
                "visual_cues": visual,
                "confusions": confusions,
                "setup": setup,
                "safety": safety,
                "text": text,
                "search_text": " ".join(
                    [
                        name,
                        str(item.get("name_en") or ""),
                        " ".join(aliases),
                        str(item.get("category") or ""),
                        " ".join(item.get("target_muscles") or []),
                        " ".join(visual),
                    ]
                ),
                "source": "FitAI equipment catalog v2",
                "source_url": "",
                "license": "internal",
            }
        )
    return rows, {"equipment_rows": len(rows), "curated_cues": len(cues)}


def main() -> int:
    if not SEED_JSON.exists():
        raise SystemExit(f"missing seed: {SEED_JSON}")
    seed = _read_json(SEED_JSON)
    coach, coach_stats = build_coach(seed)
    equipment, equipment_stats = build_equipment(seed)

    _write_jsonl(OUT_DIR / "coach_knowledge.jsonl", coach)
    _write_jsonl(OUT_DIR / "equipment_knowledge.jsonl", equipment)

    manifest = {
        "version": 1,
        "generated_at": datetime.now(timezone.utc).date().isoformat(),
        "build_date": date.today().isoformat(),
        "sources": [
            {
                "name": EXERCISE_SOURCE,
                "url": EXERCISE_SOURCE_URL,
                "license": EXERCISE_LICENSE,
                "raw_file": "../exercises_rag.jsonl",
                "note": "Media excluded; safety note retained.",
            },
            {
                "name": "FitAI equipment catalog v2",
                "url": "",
                "license": "internal",
                "raw_file": "../../app/services/equipment_catalog_v2.py",
            },
            {
                "name": "FitAI curated coach cards",
                "url": "",
                "license": "original-summary",
                "raw_file": "knowledge_seed.json",
            },
        ],
        "rounds": {
            "build": {
                **coach_stats,
                **equipment_stats,
                "coach_final": len(coach),
                "equipment_final": len(equipment),
            }
        },
        "counts": {
            "coach_knowledge": len(coach),
            "equipment_knowledge": len(equipment),
            "coach_exercises": coach_stats["exercise_rows"],
            "coach_curated_cards": coach_stats["curated_cards"],
        },
        "files": {
            "coach_knowledge.jsonl": len(coach),
            "equipment_knowledge.jsonl": len(equipment),
        },
        "removed": {
            "food_nutrition": "Removed after answer-level A/B; not used by vision.",
        },
    }
    _write_json(OUT_DIR / "manifest.json", manifest)
    print(json.dumps(manifest["counts"], ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
