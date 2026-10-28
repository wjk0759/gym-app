#!/usr/bin/env python3
r"""Import the curated basic iron-gym library (B) as the active exercise library.

This is the minimal, demo-first version: ~57 clean commercial-gym movements,
mapped back onto the existing 8 muscle categories (chest/back/legs/glutes/
shoulders/arms/core/cardio) so no iOS enum change is required yet. The full
15-category split + variant dedupe + equipment audit is deferred until before
launch.

The previous active rows (Xunji 1,213 + legacy) are kept but marked inactive,
so existing plans/history keep resolving. Both the active and legacy JSON
resources for iOS are rewritten from this single source of truth.

Usage (from repository root):
    backend/.venv/Scripts/python.exe tools/db/import_curated_library.py --dry-run
    backend/.venv/Scripts/python.exe tools/db/import_curated_library.py
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
os.chdir(ROOT / "backend")

from sqlalchemy import create_engine, select, update  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.config import settings  # noqa: E402
from app.models import Exercise  # noqa: E402

SOURCE = "curated_iron_gym"
LICENSE = "hand-curated"

IOS_ACTIVE = ROOT / "ios" / "FitAI" / "Resources" / "xunji_movements.json"
IOS_LEGACY = ROOT / "ios" / "FitAI" / "Resources" / "legacy_exercises.json"

# (slug, name_zh, name_en, muscle_group, equipment, is_compound)
CURATED: list[tuple[str, str, str, str, str, bool]] = [
    # 胸
    ("cm_bench_press", "杠铃卧推", "Barbell Bench Press", "chest", "barbell", True),
    ("cm_incline_bench_press", "上斜杠铃卧推", "Incline Barbell Bench Press", "chest", "barbell", True),
    ("cm_dumbbell_press", "哑铃卧推", "Dumbbell Bench Press", "chest", "dumbbell", True),
    ("cm_machine_chest_press", "器械推胸", "Machine Chest Press", "chest", "machine", True),
    ("cm_pec_deck", "蝴蝶机夹胸", "Pec Deck", "chest", "machine", False),
    ("cm_cable_fly", "绳索夹胸", "Cable Fly", "chest", "cable", False),
    ("cm_dip", "双杠臂屈伸", "Chest Dip", "chest", "bodyweight", True),
    ("cm_pushup", "俯卧撑", "Push-up", "chest", "bodyweight", True),
    # 背
    ("cm_pullup", "引体向上", "Pull-up", "back", "bodyweight", True),
    ("cm_lat_pulldown", "高位下拉", "Lat Pulldown", "back", "machine", True),
    ("cm_barbell_row", "杠铃划船", "Barbell Row", "back", "barbell", True),
    ("cm_seated_row", "坐姿划船", "Seated Cable Row", "back", "machine", True),
    ("cm_dumbbell_row", "单臂哑铃划船", "One-arm Dumbbell Row", "back", "dumbbell", True),
    ("cm_tbar_row", "T杆划船", "T-bar Row", "back", "barbell", True),
    ("cm_straight_arm_pulldown", "直臂下压", "Straight-arm Pulldown", "back", "cable", False),
    ("cm_back_extension", "山羊挺身", "Back Extension", "back", "bodyweight", False),
    ("cm_barbell_shrug", "杠铃耸肩", "Barbell Shrug", "back", "barbell", False),
    ("cm_dumbbell_shrug", "哑铃耸肩", "Dumbbell Shrug", "back", "dumbbell", False),
    # 腿
    ("cm_squat", "杠铃深蹲", "Barbell Back Squat", "legs", "barbell", True),
    ("cm_front_squat", "前蹲", "Front Squat", "legs", "barbell", True),
    ("cm_leg_press", "腿举", "Leg Press", "legs", "machine", True),
    ("cm_hack_squat", "哈克深蹲", "Hack Squat", "legs", "machine", True),
    ("cm_leg_extension", "腿屈伸", "Leg Extension", "legs", "machine", False),
    ("cm_leg_curl", "腿弯举", "Lying Leg Curl", "legs", "machine", False),
    ("cm_romanian_deadlift", "罗马尼亚硬拉", "Romanian Deadlift", "legs", "barbell", True),
    ("cm_lunge", "箭步蹲", "Lunge", "legs", "dumbbell", True),
    ("cm_standing_calf_raise", "站姿提踵", "Standing Calf Raise", "legs", "machine", False),
    ("cm_seated_calf_raise", "坐姿提踵", "Seated Calf Raise", "legs", "machine", False),
    # 臀
    ("cm_hip_thrust", "杠铃臀推", "Barbell Hip Thrust", "glutes", "barbell", True),
    ("cm_glute_bridge", "臀桥", "Glute Bridge", "glutes", "bodyweight", False),
    ("cm_hip_abduction", "坐姿髋外展", "Seated Hip Abduction", "glutes", "machine", False),
    ("cm_hip_adduction", "坐姿髋内收", "Seated Hip Adduction", "glutes", "machine", False),
    ("cm_cable_kickback", "绳索后踢", "Cable Glute Kickback", "glutes", "cable", False),
    # 肩
    ("cm_shoulder_press", "哑铃推举", "Dumbbell Shoulder Press", "shoulders", "dumbbell", True),
    ("cm_machine_shoulder_press", "器械推举", "Machine Shoulder Press", "shoulders", "machine", True),
    ("cm_lateral_raise", "侧平举", "Lateral Raise", "shoulders", "dumbbell", False),
    ("cm_front_raise", "前平举", "Front Raise", "shoulders", "dumbbell", False),
    ("cm_face_pull", "面拉", "Face Pull", "shoulders", "cable", False),
    ("cm_reverse_fly", "反向飞鸟", "Reverse Fly", "shoulders", "dumbbell", False),
    # 手臂
    ("cm_barbell_curl", "杠铃弯举", "Barbell Curl", "arms", "barbell", False),
    ("cm_dumbbell_curl", "哑铃弯举", "Dumbbell Curl", "arms", "dumbbell", False),
    ("cm_hammer_curl", "锤式弯举", "Hammer Curl", "arms", "dumbbell", False),
    ("cm_preacher_curl", "牧师凳弯举", "Preacher Curl", "arms", "barbell", False),
    ("cm_triceps_pushdown", "绳索下压", "Triceps Pushdown", "arms", "cable", False),
    ("cm_lying_triceps_extension", "仰卧臂屈伸", "Lying Triceps Extension", "arms", "barbell", False),
    ("cm_close_grip_bench", "窄距卧推", "Close-grip Bench Press", "arms", "barbell", True),
    ("cm_machine_pushdown", "器械下压", "Machine Triceps Pushdown", "arms", "machine", False),
    ("cm_wrist_curl", "杠铃腕弯举", "Barbell Wrist Curl", "arms", "barbell", False),
    # 核心
    ("cm_plank", "平板支撑", "Plank", "core", "bodyweight", False),
    ("cm_crunch", "卷腹", "Crunch", "core", "bodyweight", False),
    ("cm_hanging_leg_raise", "悬垂举腿", "Hanging Leg Raise", "core", "bodyweight", False),
    ("cm_cable_crunch", "绳索卷腹", "Cable Crunch", "core", "cable", False),
    ("cm_side_plank", "侧平板", "Side Plank", "core", "bodyweight", False),
    # 有氧
    ("cm_treadmill", "跑步机", "Treadmill", "cardio", "machine", False),
    ("cm_elliptical", "椭圆机", "Elliptical", "cardio", "machine", False),
    ("cm_rowing_machine", "划船机", "Rowing Machine", "cardio", "machine", True),
    ("cm_stationary_bike", "动感单车", "Stationary Bike", "cardio", "machine", False),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", default=settings.database_url)
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def ios_payload(exercise: Exercise) -> dict[str, Any]:
    return {
        "slug": exercise.slug,
        "name_zh": exercise.name_zh,
        "name_en": exercise.name_en,
        "muscle_group": exercise.muscle_group,
        "equipment": exercise.equipment,
        "is_compound": exercise.is_compound,
        "instructions": exercise.instructions,
        "contraindications": exercise.contraindications or [],
        "motion_start_url": exercise.motion_start_url,
        "motion_end_url": exercise.motion_end_url,
    }


def main() -> None:
    args = parse_args()
    engine = create_engine(args.target, pool_pre_ping=True)

    with Session(engine) as session:
        if not args.dry_run:
            session.execute(update(Exercise).values(is_active=False))

        existing = {
            item.slug: item
            for item in session.execute(
                select(Exercise).where(Exercise.slug.in_([c[0] for c in CURATED]))
            ).scalars().all()
        }
        inserted = updated = 0
        for slug, name_zh, name_en, muscle, equipment, compound in CURATED:
            values = {
                "slug": slug,
                "name_zh": name_zh,
                "name_en": name_en,
                "muscle_group": muscle,
                "equipment": equipment,
                "is_compound": compound,
                "difficulty": 2,
                "instructions": None,
                "contraindications": [],
                "source": SOURCE,
                "license": LICENSE,
                "motion_start_url": None,
                "motion_end_url": None,
            }
            item = existing.get(slug)
            if item is None:
                session.add(Exercise(**values, is_active=True))
                inserted += 1
            else:
                for key, value in values.items():
                    setattr(item, key, value)
                item.is_active = True
                updated += 1

        if args.dry_run:
            session.rollback()
            print(f"dry-run: insert {inserted}, update {updated}, archive existing rows")
            return
        session.commit()

        active = session.execute(
            select(Exercise).where(Exercise.is_active.is_(True)).order_by(Exercise.slug)
        ).scalars().all()
        inactive = session.execute(
            select(Exercise).where(Exercise.is_active.is_(False)).order_by(Exercise.slug)
        ).scalars().all()

    IOS_ACTIVE.write_text(
        json.dumps([ios_payload(e) for e in active], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    IOS_LEGACY.write_text(
        json.dumps([ios_payload(e) for e in inactive], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"active {len(active)}, legacy {len(inactive)}")
    print(f"inserted {inserted}, updated {updated}")
    print(f"wrote {IOS_ACTIVE}")
    print(f"wrote {IOS_LEGACY}")


if __name__ == "__main__":
    main()
