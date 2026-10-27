#!/usr/bin/env python3
r"""Import the open exercise dataset into FitAI's exercise library.

Source: https://github.com/hasaneyldrm/exercises-dataset
Data licence: MIT (names, metadata, multilingual instructions). The repository's
images/GIFs are Gym visual media and are deliberately not imported.

The dataset is pinned to a commit so a rerun cannot silently change the
exercise set. Existing curated exercises are preserved by English name.

Usage (from the repository root):
    backend/.venv/Scripts/python.exe tools/db/import_exercises.py --dry-run
    backend/.venv/Scripts/python.exe tools/db/import_exercises.py
    backend/.venv/Scripts/python.exe tools/db/import_exercises.py --source C:\path\to\exercises.json

The script is idempotent for its own source: existing source rows are skipped.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import unicodedata
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
os.chdir(ROOT / "backend")

from sqlalchemy import create_engine, select  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.config import settings  # noqa: E402
from app.models import Exercise  # noqa: E402

DATASET_COMMIT = "7455efae41b330c265e7cd4b78dfa848e7ce5ebd"
DATASET_URL = (
    "https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/"
    f"{DATASET_COMMIT}/data/exercises.json"
)
DATASET_SHA256 = "656634224b8977b99a6d765470ee123260d4979715eaa4e7c0b7c8bb0d79f93d"
DEFAULT_CACHE = ROOT / "tools" / "db" / "data" / "exercise_name_zh.json"
SOURCE = "hasaneyldrm/exercises-dataset"
LICENSE = "MIT; Gym visual media excluded"

MUSCLE_MAP = {
    "abs": "core",
    "abdominals": "core",
    "obliques": "core",
    "hip flexors": "core",
    "serratus anterior": "core",
    "pectorals": "chest",
    "chest": "chest",
    "lats": "back",
    "latissimus dorsi": "back",
    "upper back": "back",
    "spine": "back",
    "lower back": "back",
    "traps": "back",
    "trapezius": "back",
    "rhomboids": "back",
    "delts": "shoulders",
    "deltoids": "shoulders",
    "shoulders": "shoulders",
    "rotator cuff": "shoulders",
    "levator scapulae": "shoulders",
    "neck": "shoulders",
    "biceps": "arms",
    "triceps": "arms",
    "forearms": "arms",
    "wrist flexors": "arms",
    "wrist extensors": "arms",
    "wrists": "arms",
    "hands": "arms",
    "glutes": "glutes",
    "quads": "legs",
    "quadriceps": "legs",
    "hamstrings": "legs",
    "calves": "legs",
    "adductors": "legs",
    "abductors": "legs",
    "ankles": "legs",
    "ankle stabilizers": "legs",
    "soleus": "legs",
    "cardiovascular system": "cardio",
}

EQUIPMENT_MAP = {
    "body weight": "bodyweight",
    "bodyweight": "bodyweight",
    "assisted": "bodyweight",
    "weighted": "bodyweight",
    "stability ball": "bodyweight",
    "bosu ball": "bodyweight",
    "medicine ball": "bodyweight",
    "roller": "bodyweight",
    "foam roll": "bodyweight",
    "wheel roller": "bodyweight",
    "dumbbell": "dumbbell",
    "barbell": "barbell",
    "olympic barbell": "barbell",
    "ez barbell": "barbell",
    "trap bar": "barbell",
    "smith machine": "machine",
    "leverage machine": "machine",
    "sled machine": "machine",
    "cable": "cable",
    "rope": "cable",
    "band": "band",
    "resistance band": "band",
    "kettlebell": "kettlebell",
    "kettlebells": "kettlebell",
    "upper body ergometer": "machine",
    "skierg machine": "machine",
    "stationary bike": "machine",
    "elliptical machine": "machine",
    "stepmill machine": "machine",
    "tire": "bodyweight",
    "hammer": "bodyweight",
}

COMPOUND_TOKENS = (
    "press",
    "squat",
    "deadlift",
    "row",
    "pull-up",
    "pull up",
    "pullup",
    "chin-up",
    "chin up",
    "clean",
    "snatch",
    "jerk",
    "lunge",
    "dip",
    "push-up",
    "push up",
    "pushup",
    "thrust",
    "burpee",
    "swing",
    "carry",
    "step-up",
    "step up",
    "muscle-up",
    "muscle up",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        default="",
        help="Local exercises.json path, or a URL. Defaults to the pinned GitHub snapshot.",
    )
    parser.add_argument("--target", default=settings.database_url, help="SQLAlchemy database URL")
    parser.add_argument("--name-cache", default=str(DEFAULT_CACHE), help="English-to-Chinese name cache")
    parser.add_argument("--limit", type=int, default=0, help="Import only the first N new rows (for testing)")
    parser.add_argument("--dry-run", action="store_true", help="Report changes without writing")
    return parser.parse_args()


def normalize(value: str | None) -> str:
    return re.sub(r"\s+", " ", (value or "").strip().lower())


def slugify(value: str, fallback: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return (slug or fallback)[:60]


def read_dataset(source: str) -> list[dict[str, Any]]:
    if source and Path(source).exists():
        path = Path(source)
    else:
        url = source or DATASET_URL
        cache = Path(tempfile.gettempdir()) / "fitai-exercises-source.json"
        if cache.exists():
            digest = hashlib.sha256(cache.read_bytes()).hexdigest()
            if digest == DATASET_SHA256:
                path = cache
            else:
                path = None
        else:
            path = None
        if path is None:
            print(f"downloading {url}")
            with urllib.request.urlopen(url, timeout=120) as response:
                cache.write_bytes(response.read())
            digest = hashlib.sha256(cache.read_bytes()).hexdigest()
            if not source and digest != DATASET_SHA256:
                raise SystemExit(
                    f"dataset checksum mismatch: expected {DATASET_SHA256}, got {digest}"
                )
            path = cache
    return json.loads(path.read_text(encoding="utf-8"))


def muscle_group(row: dict[str, Any]) -> str:
    category = normalize(row.get("category"))
    body_part = normalize(row.get("body_part"))
    if category == "cardio" or body_part == "cardio":
        return "cardio"
    for candidate in (row.get("target"), row.get("muscle_group"), row.get("body_part")):
        mapped = MUSCLE_MAP.get(normalize(candidate))
        if mapped:
            return mapped
    return "core"


def equipment(row: dict[str, Any]) -> str:
    return EQUIPMENT_MAP.get(normalize(row.get("equipment")), "bodyweight")


def difficulty(name: str, equipment_name: str) -> int:
    lower = name.lower()
    if any(token in lower for token in ("advanced", "expert")):
        return 3
    if equipment_name in {"barbell", "machine"}:
        return 3 if equipment_name == "barbell" else 2
    if equipment_name in {"dumbbell", "cable", "kettlebell", "band"}:
        return 2
    return 1


def is_compound(row: dict[str, Any]) -> bool:
    name = normalize(row.get("name"))
    secondary = row.get("secondary_muscles") or []
    return len(secondary) >= 2 or any(token in name for token in COMPOUND_TOKENS)


def zh_instructions(row: dict[str, Any]) -> str:
    instructions = row.get("instructions") or {}
    value = instructions.get("zh") if isinstance(instructions, dict) else None
    if not value:
        value = (row.get("instruction_steps") or {}).get("zh")
        if isinstance(value, list):
            value = "\n".join(f"{index}. {step}" for index, step in enumerate(value, 1))
    if not value:
        value = instructions.get("en") if isinstance(instructions, dict) else ""
    return re.sub(r"\s+", " ", str(value or "")).strip()


def main() -> int:
    args = parse_args()
    data = read_dataset(args.source)
    cache_path = Path(args.name_cache)
    translations = (
        json.loads(cache_path.read_text(encoding="utf-8")) if cache_path.exists() else {}
    )

    engine = create_engine(args.target, future=True, pool_pre_ping=True)
    with Session(engine) as session:
        existing = session.execute(select(Exercise)).scalars().all()
        existing_slugs = {row.slug for row in existing}
        existing_names = {normalize(row.name_en or row.name_zh) for row in existing}

        candidates: list[dict[str, Any]] = []
        seen_dataset_names = set()
        skipped_existing = 0
        skipped_dataset_duplicate = 0
        for row in data:
            name = str(row.get("name") or "").strip()
            if not name:
                continue
            key = normalize(name)
            if key in existing_names:
                skipped_existing += 1
                continue
            if key in seen_dataset_names:
                skipped_dataset_duplicate += 1
                continue
            seen_dataset_names.add(key)
            dataset_id = str(row.get("id") or "")
            base_slug = slugify(name, f"exercise_{dataset_id}")
            slug = base_slug
            suffix = 2
            while slug in existing_slugs:
                slug = f"{base_slug[:56]}_{suffix}"
                suffix += 1
            existing_slugs.add(slug)
            equipment_name = equipment(row)
            candidates.append(
                {
                    "slug": slug,
                    "name_zh": translations.get(name) or name,
                    "name_en": name[:120],
                    "muscle_group": muscle_group(row),
                    "equipment": equipment_name,
                    "is_compound": is_compound(row),
                    "difficulty": difficulty(name, equipment_name),
                    "instructions": zh_instructions(row),
                    "contraindications": [],
                    "source": SOURCE,
                    "license": LICENSE,
                    "dataset_id": dataset_id,
                }
            )

        if args.limit:
            candidates = candidates[: args.limit]

        print(f"source rows: {len(data)}")
        print(f"existing exercises: {len(existing)}")
        print(f"skipped existing names: {skipped_existing}")
        print(f"skipped duplicate dataset names: {skipped_dataset_duplicate}")
        print(f"new exercises: {len(candidates)}")
        print("by muscle:", dict(Counter(row["muscle_group"] for row in candidates).most_common()))
        print("by equipment:", dict(Counter(row["equipment"] for row in candidates).most_common()))
        print("target:", args.target)
        if args.dry_run:
            for row in candidates[:5]:
                print("sample:", row["slug"], row["name_zh"], row["name_en"], row["muscle_group"], row["equipment"])
            print("dry run only; no writes performed")
            return 0

        for index in range(0, len(candidates), 200):
            batch = candidates[index : index + 200]
            session.add_all(
                [
                    Exercise(
                        slug=row["slug"],
                        name_zh=row["name_zh"],
                        name_en=row["name_en"],
                        muscle_group=row["muscle_group"],
                        equipment=row["equipment"],
                        is_compound=row["is_compound"],
                        difficulty=row["difficulty"],
                        instructions=row["instructions"],
                        video_url=None,
                        thumbnail_url=None,
                        contraindications=row["contraindications"],
                        source=row["source"],
                        license=row["license"],
                    )
                    for row in batch
                ]
            )
            session.commit()
            print(f"committed {min(index + 200, len(candidates))}/{len(candidates)}")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
