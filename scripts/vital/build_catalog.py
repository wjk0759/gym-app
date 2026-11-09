from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

# Equipment mapping: Vital raw equipment -> app equipment.
# Keep "other" for equipment that does not fit the seven app categories.
EQUIPMENT_MAP = {
    "body weight": "bodyweight",
    "dumbbell": "dumbbell",
    "barbell": "barbell",
    "machine": "machine",
    "leverage machine": "machine",
    "smith machine": "machine",
    "cable": "cable",
    "resistance band": "band",
    "band": "band",
    "kettlebell": "kettlebell",
    "hex bar": "barbell",
    "trap bar": "barbell",
    "plate": "barbell",
    "ab wheel": "other",
    "assisted": "other",
    "medicine ball": "other",
    "exercise ball": "other",
    "bosu ball": "other",
    "battle rope": "other",
    "trx": "other",
    "sled": "other",
    "vipr": "other",
    "rope": "other",
    "jump rope": "other",
}

# Body-part mapping for app muscle groups.
BODY_PART_MAP = {
    "chest": "chest",
    "back": "back",
    "waist": "core",
    "upper legs": "legs",
    "lower legs": "legs",
    "shoulders": "shoulders",
    "upper arms": "arms",
    "lower arms": "arms",
    "neck": "shoulders",
    "cardio": "cardio",
}

DIFFICULTY_MAP = {"beginner": 1, "intermediate": 2, "advanced": 3}

GYM_PACKS = {"100gym", "100", "200", "430f1", "430m", "430f2"}
HOME_PACKS = {"homepilates", "office", "wallpilates", "home130", "women400", "face", "yoga"}

GUARDS = {
    "100gym": ("male", r"100gymworkouts"),
    "100": ("male", r"100 Workouts\\100 Workouts"),
    "200": ("male", r"200 Workouts"),
    "430f1": ("female", r"100 female Gym"),
    "430m": ("male", r"130 male gym"),
    "430f2": ("female", r"200 female gym"),
    "homepilates": ("female", r"Home Pilate"),
    "office": ("male", r"Office"),
    "wallpilates": ("female", r"Wall Pilate"),
    "home130": ("female", r"Workouts\\Workouts"),
    "women400": ("female", r"400 Women Workout"),
    "face": ("female", r"Face Exercise"),
    "yoga": ("female", r"Yoga"),
}


def read_json(path: Path):
    with path.open(encoding="utf-8-sig") as fh:
        return json.load(fh)


def norm_key(value: str) -> str:
    value = (value or "").lower().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def slugify(value: str) -> str:
    value = (value or "").lower().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return f"vital-{value}" if value else "vital-action"


def collect_video_index(root: Path):
    videos = []
    for dirpath, _, files in os.walk(root):
        for filename in files:
            if Path(filename).suffix.lower() not in (".mp4", ".mov"):
                continue
            path = Path(dirpath) / filename
            rel = path.relative_to(root).as_posix()
            videos.append(
                {
                    "stem": path.stem.lower(),
                    "name": path.name,
                    "path": path,
                    "rel": rel,
                    "size": path.stat().st_size,
                }
            )
    return videos


def videos_for(videos, keyword: str):
    needle = keyword.lower()
    result = defaultdict(list)
    for item in videos:
        if needle in item["rel"].lower():
            result[item["stem"]].append(item)
    return result


def build_actions(vital_root: Path, pack800_root: Path):
    videos = collect_video_index(vital_root)
    records = []

    # Gym metadata comes from the complete 800 pack. The 1500 pack has the
    # same 832 videos but is missing 200workouts.json and has two ID issues.
    gym_specs = [
        ("100gym", pack800_root / "100 Gym Workouts" / "100gymworkouts.json", r"100gymworkouts", "male"),
        ("100", pack800_root / "100 Workouts" / "100workouts.json", r"100 Workouts/100 Workouts", "male"),
        ("200", pack800_root / "200 Workouts" / "200workouts.json", r"200 Workouts", "male"),
        ("430f1", pack800_root / "430 Workouts" / "430 Workouts" / "100femalegym.json", r"100 female Gym", "female"),
        ("430m", pack800_root / "430 Workouts" / "430 Workouts" / "130malegym.json", r"130 male gym", "male"),
        ("430f2", pack800_root / "430 Workouts" / "430 Workouts" / "200femalegym.json", r"200 female gym", "female"),
    ]
    home_specs = [
        ("homepilates", vital_root / "homeworkouts-20261109T110013Z-1-001" / "homeworkouts" / "Home Pilate" / "Home Pilate" / "pilate.json", r"Home Pilate", "female"),
        ("office", vital_root / "homeworkouts-20261109T110013Z-1-001" / "homeworkouts" / "Office" / "Office" / "office.json", r"Office", "male"),
        ("wallpilates", vital_root / "homeworkouts-20261109T110013Z-1-001" / "homeworkouts" / "Wall Pilate Workouts" / "wallpilate.json", r"Wall Pilate", "female"),
        ("home130", vital_root / "homeworkouts-20261109T110013Z-1-001" / "homeworkouts" / "Workouts" / "130workouts.json", r"Workouts/Workouts", "female"),
        ("women400", vital_root / "homeworkouts-20261109T110013Z-1-002" / "homeworkouts" / "400 Women Workout" / "Women Workout" / "400homeworkout.json", r"400 Women Workout", "female"),
        ("face", vital_root / "homeworkouts-20261109T110013Z-1-002" / "homeworkouts" / "Face Exercise" / "face.json", r"Face Exercise", "female"),
        ("yoga", vital_root / "homeworkouts-20261109T110013Z-1-002" / "homeworkouts" / "Yoga" / "Yoga.json", r"Yoga", "female"),
    ]

    for pack, json_path, keyword, sex in gym_specs + home_specs:
        data = read_json(json_path)
        by_id = videos_for(videos, keyword)
        for item in data:
            rid = str(item.get("id") or "").strip().lower()
            candidates = by_id.get(rid, [])
            if not candidates and rid:
                candidates = by_id.get(rid, [])
            if not candidates and not rid and item.get("name"):
                # The 100gym JSON in 1500 has an empty ID for this action;
                # the video is 0028.mp4.
                candidates = by_id.get("0028", [])
            if not candidates and item.get("name"):
                # Home Pilates "the hundred" video is named after the action.
                candidates = by_id.get(norm_key(str(item["name"])).replace(" ", ""), [])
            if not candidates:
                # Last resort: match by normalized stem/name.
                stem = re.sub(r"[^a-z0-9]+", "", str(item.get("name", "")).lower())
                for candidate_stem, items in by_id.items():
                    if re.sub(r"[^a-z0-9]+", "", candidate_stem) == stem:
                        candidates = items
                        break
            path = candidates[0] if candidates else None
            records.append(
                {
                    "pack": pack,
                    "sex": sex,
                    "id": rid,
                    "name": str(item.get("name") or "").strip(),
                    "body_part": item.get("bodyPart"),
                    "target": item.get("target"),
                    "secondary_muscles": item.get("secondaryMuscles") or [],
                    "equipment_raw": item.get("equipment"),
                    "category": item.get("category"),
                    "difficulty": item.get("difficulty"),
                    "instructions_en": item.get("instructions") or [],
                    "description_en": item.get("description"),
                    "video_path": path["path"] if path else None,
                    "video_rel": path["rel"] if path else None,
                    "video_size": path["size"] if path else None,
                }
            )

    # Group by normalized action name. One action can have many media variants.
    grouped = defaultdict(list)
    for record in records:
        key = norm_key(record["name"])
        if key:
            grouped[key].append(record)

    actions = []
    used_slugs = set()
    for key, variants in sorted(grouped.items()):
        # Prefer gym metadata; then a record with the richest fields.
        variants.sort(
            key=lambda r: (
                0 if r["pack"] in GYM_PACKS else 1,
                0 if r["instructions_en"] else 1,
                r["name"],
            )
        )
        primary = variants[0]
        name_en = primary["name"]
        slug = slugify(name_en)
        if slug in used_slugs:
            suffix = 2
            while f"{slug}-{suffix}" in used_slugs:
                suffix += 1
            slug = f"{slug}-{suffix}"
        used_slugs.add(slug)

        sexes = sorted({r["sex"] for r in variants})
        equipment_raw = (primary.get("equipment_raw") or "").strip().lower()
        equipment = EQUIPMENT_MAP.get(equipment_raw, "other")
        body_part = (primary.get("body_part") or "").strip().lower()
        muscle = BODY_PART_MAP.get(body_part, "core")
        media = []
        for variant in variants:
            if not variant["video_rel"]:
                continue
            media.append(
                {
                    "pack": variant["pack"],
                    "sex": variant["sex"],
                    "video_id": variant["id"],
                    "source_file": variant["video_rel"],
                    "size_bytes": variant["video_size"],
                }
            )
        actions.append(
            {
                "slug": slug,
                "name_en": name_en,
                "name_zh": "",
                "aliases": sorted({r["name"] for r in variants if r["name"] != name_en}),
                "equipment": equipment,
                "equipment_raw": equipment_raw,
                "muscle_group": muscle,
                "body_part": body_part,
                "target": primary.get("target"),
                "secondary_muscles": primary.get("secondary_muscles") or [],
                "category": primary.get("category"),
                "difficulty": DIFFICULTY_MAP.get(str(primary.get("difficulty") or "").lower(), 1),
                "difficulty_raw": primary.get("difficulty"),
                "is_compound": len(primary.get("secondary_muscles") or []) >= 2,
                "instructions_en": primary.get("instructions_en") or [],
                "description_en": primary.get("description_en"),
                "source": "vital_animations",
                "license": "Vital Animations EULA 2026.1",
                "sex_variants": sexes,
                "has_gym": any(r["pack"] in GYM_PACKS for r in variants),
                "has_home": any(r["pack"] in HOME_PACKS for r in variants),
                "media": media,
            }
        )

    return actions, records


def write_outputs(actions, records, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "vital_actions_base.json").write_text(
        json.dumps(actions, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    with (out_dir / "vital_media_manifest.csv").open("w", encoding="utf-8-sig", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(
            [
                "action_slug",
                "action_name_en",
                "pack",
                "sex",
                "video_id",
                "source_file",
                "size_bytes",
            ]
        )
        for action in actions:
            for media in action["media"]:
                writer.writerow(
                    [
                        action["slug"],
                        action["name_en"],
                        media["pack"],
                        media["sex"],
                        media["video_id"],
                        media["source_file"],
                        media["size_bytes"],
                    ]
                )
    with (out_dir / "vital_actions_base.csv").open("w", encoding="utf-8-sig", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(
            [
                "slug",
                "name_en",
                "equipment",
                "muscle_group",
                "target",
                "category",
                "difficulty",
                "sex_variants",
                "has_gym",
                "has_home",
                "media_count",
            ]
        )
        for action in actions:
            writer.writerow(
                [
                    action["slug"],
                    action["name_en"],
                    action["equipment"],
                    action["muscle_group"],
                    action["target"] or "",
                    action["category"] or "",
                    action["difficulty"],
                    "/".join(action["sex_variants"]),
                    action["has_gym"],
                    action["has_home"],
                    len(action["media"]),
                ]
            )
    print(f"actions={len(actions)} media={sum(len(a['media']) for a in actions)}")
    print(f"wrote {out_dir / 'vital_actions_base.json'}")
    print(f"wrote {out_dir / 'vital_actions_base.csv'}")
    print(f"wrote {out_dir / 'vital_media_manifest.csv'}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--vital-root", type=Path, default=Path(os.environ.get("VITAL1500_ROOT", r"E:\3d健身素材\1500VitalAnimations")))
    parser.add_argument("--pack800-root", type=Path, default=Path(os.environ.get("VITAL800_ROOT", r"E:\3d健身素材\800VitalAnimations")))
    parser.add_argument("--out", type=Path, default=Path("data/vital"))
    args = parser.parse_args()
    actions, records = build_actions(args.vital_root, args.pack800_root)
    write_outputs(actions, records, args.out)


if __name__ == "__main__":
    main()
