"""Build a compact, text-only exercise RAG corpus from the Agent data pack.

The raw pack is a 1.9MB JSON report with 1,324 unreviewed exercise records.
It is not suitable as a direct prompt. This script keeps common exercises,
cleans obvious source typos, removes duplicate names, drops media/licensing
fields we should not ship, and adds a safety note.

Usage:
    python scripts/build_exercise_rag.py path/to/FitAI_Agent_数据包.json
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

OUTPUT = Path("data/exercises_rag.jsonl")
MANIFEST = Path("data/exercises_rag_manifest.json")

MIN_STEPS = 2
MIN_INSTRUCTIONS = 40
DROP_BODY_PARTS = {"颈"}


def _norm(value: object) -> str:
    text = str(value or "").strip().lower()
    text = text.replace("（男性）", "").replace("（女性）", "")
    text = text.replace("(male)", "").replace("(female)", "")
    text = re.sub(r"[\s\-_/]+", " ", text)
    text = re.sub(r"[^\w\u4e00-\u9fff ]+", "", text)
    return re.sub(r"\s+", " ", text).strip()


def _clean_name_en(value: object) -> str:
    text = str(value or "").strip()
    # Source typo: "dumbbell incline breeding" means incline bench press.
    text = re.sub(r"\bbreeding\b", "bench press", text, flags=re.IGNORECASE)
    text = re.sub(r"\s*\((male|female)\)\s*", "", text, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", text).strip()


def _clean_name_zh(value: object) -> str:
    text = str(value or "").strip()
    text = re.sub(r"（[男女]性）|\([男女]性\)", "", text)
    return text.strip()


def _steps(value: object) -> list[str]:
    items = (
        value
        if isinstance(value, list)
        else re.split(r"(?<=[。！？])", str(value or ""))
    )
    return [str(item).strip() for item in items if str(item).strip()]


def build(source: Path) -> tuple[list[dict], dict]:
    raw = json.loads(source.read_text(encoding="utf-8"))
    exercises = raw.get("exercises") or []
    kept: list[dict] = []
    dropped = Counter()
    seen_en: set[tuple[str, str]] = set()
    seen_zh: set[tuple[str, str]] = set()

    for item in exercises:
        rank = item.get("common_rank")
        if not isinstance(rank, int):
            dropped["invalid_rank"] += 1
            continue
        if rank >= 999:
            dropped["unranked"] += 1
            continue

        body_part = str(item.get("body_part_zh") or "").strip()
        if body_part in DROP_BODY_PARTS:
            dropped["neck"] += 1
            continue

        name_en = _clean_name_en(item.get("name_en"))
        name_zh = _clean_name_zh(item.get("name_zh"))
        equipment = str(item.get("equipment_zh") or "").strip()
        if not name_en or not name_zh:
            dropped["missing_name"] += 1
            continue

        steps = _steps(item.get("steps_zh"))
        instructions = str(item.get("instructions_zh") or "").strip()
        if len(steps) < MIN_STEPS or len(instructions) < MIN_INSTRUCTIONS:
            dropped["too_short"] += 1
            continue

        key_en = (_norm(name_en), equipment)
        key_zh = (_norm(name_zh), equipment)
        if key_en in seen_en or key_zh in seen_zh:
            dropped["duplicate"] += 1
            continue
        seen_en.add(key_en)
        seen_zh.add(key_zh)

        kept.append(
            {
                "id": item.get("id"),
                "name_zh": name_zh,
                "name_en": name_en,
                "aliases": item.get("aliases") or [],
                "body_part": item.get("body_part"),
                "body_part_zh": body_part,
                "equipment": item.get("equipment"),
                "equipment_zh": equipment,
                "target": item.get("target"),
                "target_zh": item.get("target_zh"),
                "muscle_group": item.get("muscle_group"),
                "muscle_group_zh": item.get("muscle_group_zh"),
                "secondary_muscles": item.get("secondary_muscles") or [],
                "steps_zh": steps,
                "common_rank": rank,
                "source": item.get("source") or raw.get("meta", {}).get("source"),
                "license": item.get("license") or "text: MIT",
                "safety_note": (
                    "通用动作说明，不含禁忌症、替代动作或医疗建议；"
                    "出现疼痛、伤病或术后情况先咨询医生/康复师。"
                ),
            }
        )

    kept.sort(key=lambda item: (item["common_rank"], item["name_zh"]))
    manifest = {
        "source": str(source),
        "source_meta": raw.get("meta", {}),
        "total_source": len(exercises),
        "kept": len(kept),
        "dropped": dict(dropped),
        "by_body_part": dict(Counter(item["body_part_zh"] for item in kept)),
        "by_equipment": dict(Counter(item["equipment_zh"] for item in kept)),
        "license_note": (
            "Text fields are MIT according to the source pack; media is © Gym visual "
            "and is intentionally excluded. Keep attribution when shipping."
        ),
        "schema": [
            "id",
            "name_zh",
            "name_en",
            "aliases",
            "body_part_zh",
            "equipment_zh",
            "steps_zh",
            "safety_note",
        ],
    }
    return kept, manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    args = parser.parse_args()

    kept, manifest = build(args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as handle:
        for item in kept:
            handle.write(json.dumps(item, ensure_ascii=False) + "\n")
    args.manifest.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"kept {len(kept)} / {manifest['total_source']}")
    print(json.dumps(manifest["dropped"], ensure_ascii=False))
    print(f"wrote {args.output}")
    print(f"wrote {args.manifest}")


if __name__ == "__main__":
    main()
