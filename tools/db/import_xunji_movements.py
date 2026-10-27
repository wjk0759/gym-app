#!/usr/bin/env python3
r"""Import the user-provided Xunji action list as FitAI's active action library.

Source: tools/db/data/xunji_movements_1213.json (1,213 rows: 序号 / 动作名称 / 分区).
The source file only contains a Chinese name and a body partition. Equipment,
compound classification and stable slugs are derived locally; nothing is
invented for instructions. Existing exercises are retained for historical
plans/workouts but marked inactive so the app only offers the new list.

The two sample RepDB Free frame pairs below are only enabled for local
evaluation. RepDB's free-tier licence requires visible attribution:
"Exercise data by RepDB (repdb.co)". Do not redistribute the raw RepDB dataset.

Usage (from repository root):
    backend/.venv/Scripts/python.exe tools/db/import_xunji_movements.py --ios-only
    backend/.venv/Scripts/python.exe tools/db/import_xunji_movements.py --dry-run
    backend/.venv/Scripts/python.exe tools/db/import_xunji_movements.py
    backend/.venv/Scripts/python.exe tools/db/import_xunji_movements.py --ios-output ios/FitAI/Resources/xunji_movements.json
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))
os.chdir(ROOT / "backend")

from sqlalchemy import select, update  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402

from app.config import settings  # noqa: E402
from app.models import Exercise  # noqa: E402

DEFAULT_SOURCE = ROOT / "tools" / "db" / "data" / "xunji_movements_1213.json"
DEFAULT_IOS_OUTPUT = ROOT / "ios" / "FitAI" / "Resources" / "xunji_movements.json"
SOURCE = "xunji_movements_1213"
LICENSE = "user-provided action list"

REPDB_BASE = "https://cdn.jsdelivr.net/gh/RepDB/exercise-dataset@main/images/flat"
# Only these two actions receive local evaluation frames for now. The app shows
# start/peak as a UI crossfade; no GIF or derived dataset is created.
SAMPLE_MOTIONS: dict[str, dict[str, str]] = {
    "器械推胸": {
        "name_en": "Machine Chest Press",
        "start": f"{REPDB_BASE}/chest-press-machine-start.webp",
        "peak": f"{REPDB_BASE}/chest-press-machine-peak.webp",
    },
    "腿举": {
        "name_en": "Leg Press",
        "start": f"{REPDB_BASE}/leg-press-start.webp",
        "peak": f"{REPDB_BASE}/leg-press-peak.webp",
    },
}

PARTITION_MAP = {
    "胸": "chest",
    "背": "back",
    "腿（股四头/腘绳）": "legs",
    "小腿": "legs",
    "臀部/髋": "glutes",
    "肩": "shoulders",
    "颈部": "shoulders",
    "斜方肌": "back",
    "三头": "arms",
    "二头": "arms",
    "前臂": "arms",
    "核心/腹/功能性": "core",
    "灵活性/拉伸/放松": "core",
    "有氧/体能": "cardio",
    "Tabata": "cardio",
}

# More specific equipment tokens must come before generic machine tokens.
EQUIPMENT_RULES: list[tuple[tuple[str, ...], str]] = [
    (
        (
            "杠铃",
            "奥林匹克杠",
            "ez 杠",
            "ez杠",
            "曲杆杠",
            "曲杆",
            "六角杠",
            "t杆",
            "t-bar",
            "ssb",
            "泽奇",
            "潘德雷",
            "地雷杆",
        ),
        "barbell",
    ),
    (("哑铃", "哑铃片"), "dumbbell"),
    (("壶铃",), "kettlebell"),
    (("弹力带", "阻力带", "弹力绳", "弹力圈", "trx", "悬吊带"), "band"),
    (("绳索", "龙门", "拉力器", "战绳", "拉杆"), "cable"),
    (
        (
            "史密斯",
            "哈克",
            "倒蹬",
            "腿举",
            "腿屈伸",
            "腿弯举",
            "提踵机",
            "推胸",
            "夹胸",
            "蝴蝶",
            "悍马",
            "塔式",
            "分动式",
            "挂片器",
            "硬拉器",
            "轨道划船",
            "器械",
            "划船机",
            "跑步机",
            "椭圆机",
            "单车",
            "登山机",
            "台阶机",
            "下拉",
            "推举机",
            "训练机",
            "牧师器",
            "机",
        ),
        "machine",
    ),
    (
        (
            "俯卧撑",
            "引体",
            "双杠",
            "吊环",
            "平板支撑",
            "卷腹",
            "自重",
            "徒手",
            "拉伸",
            "泡沫轴",
            "瑜伽",
            "药球",
            "跳绳",
            "波比",
            "开合跳",
            "爬行",
            "行走",
            "跑步",
            "冲刺",
            "椅子",
            "毛巾",
            "悬带",
            "反身划船",
        ),
        "bodyweight",
    ),
]

# Last-resort heuristics for names that do not spell out the equipment. These
# run after explicit machine/cable/bodyweight tokens so e.g. "自重深蹲" stays
# bodyweight and "史密斯机卧推" stays a machine.
GENERIC_EQUIPMENT_RULES: list[tuple[tuple[str, ...], str]] = [
    (("卧推", "深蹲", "硬拉"), "barbell"),
    (("飞鸟", "平举", "弯举", "推举"), "dumbbell"),
    (("划船",), "machine"),
]

COMPOUND_TOKENS = (
    "深蹲",
    "硬拉",
    "卧推",
    "推举",
    "推胸",
    "划船",
    "引体",
    "下拉",
    "臂屈伸",
    "弓步",
    "箭步",
    "登阶",
    "上台阶",
    "波比",
    "高翻",
    "抓举",
    "挺举",
    "腿举",
    "臀推",
    "挺身",
    "早安",
    "俯卧撑",
    "双杠",
    "跳",
    "跑",
    "划船机",
    "burpee",
    "clean",
    "snatch",
    "squat",
    "deadlift",
    "press",
    "row",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=str(DEFAULT_SOURCE))
    parser.add_argument("--target", default=settings.database_url)
    parser.add_argument("--ios-output", default=str(DEFAULT_IOS_OUTPUT))
    parser.add_argument("--ios-only", action="store_true", help="Only write the bundled iOS JSON")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def load_source(path: Path) -> list[dict[str, Any]]:
    rows = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(rows, list) or not rows:
        raise ValueError("Xunji source must be a non-empty JSON array")
    for index, row in enumerate(rows, start=1):
        for key in ("序号", "动作名称", "分区"):
            if key not in row:
                raise ValueError(f"row {index} missing {key}")
    return rows


def choose_equipment(name: str) -> str:
    lowered = name.lower()
    for tokens, equipment in EQUIPMENT_RULES:
        if any(token in lowered for token in tokens):
            return equipment
    for tokens, equipment in GENERIC_EQUIPMENT_RULES:
        if any(token in lowered for token in tokens):
            return equipment
    # Most remaining rows are mobility/bodyweight drills. Defaulting to
    # bodyweight is safer than falsely advertising a machine.
    return "bodyweight"


def choose_compound(name: str) -> bool:
    lowered = name.lower()
    return any(token in lowered for token in COMPOUND_TOKENS)


def build_rows(source_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for row in source_rows:
        sequence = int(row["序号"])
        name = str(row["动作名称"]).strip()
        partition = str(row["分区"]).strip()
        if not name:
            continue
        slug = f"xj_{sequence:04d}"
        if slug in seen:
            raise ValueError(f"duplicate sequence: {sequence}")
        seen.add(slug)
        sample = SAMPLE_MOTIONS.get(name)
        result.append(
            {
                "slug": slug,
                "name_zh": name,
                "name_en": (sample or {}).get("name_en"),
                "muscle_group": PARTITION_MAP.get(partition, "core"),
                "equipment": choose_equipment(name),
                "is_compound": choose_compound(name),
                "difficulty": 2,
                "instructions": None,
                "contraindications": [],
                "source": SOURCE,
                "license": LICENSE,
                "motion_start_url": (sample or {}).get("start"),
                "motion_end_url": (sample or {}).get("peak"),
                "partition": partition,
                "sequence": sequence,
            }
        )
    return result


def ios_payload(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    keys = (
        "slug",
        "name_zh",
        "name_en",
        "muscle_group",
        "equipment",
        "is_compound",
        "difficulty",
        "instructions",
        "contraindications",
        "motion_start_url",
        "motion_end_url",
    )
    return [{key: row.get(key) for key in keys} for row in rows]


def write_ios(rows: list[dict[str, Any]], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(ios_payload(rows), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {len(rows)} actions to {output}")


def import_rows(rows: list[dict[str, Any]], target: str, dry_run: bool) -> None:
    from sqlalchemy import create_engine

    engine = create_engine(target, pool_pre_ping=True)
    with Session(engine) as session:
        # Keep historical rows for plan/workout foreign keys. The app only
        # exposes active rows, so this is an archive rather than a deletion.
        session.execute(update(Exercise).values(is_active=False))
        existing = {
            item.slug: item
            for item in session.execute(
                select(Exercise).where(Exercise.slug.in_([row["slug"] for row in rows]))
            )
            .scalars()
            .all()
        }
        inserted = updated = 0
        for row in rows:
            item = existing.get(row["slug"])
            values = {
                key: value
                for key, value in row.items()
                if key not in {"partition", "sequence"}
            }
            if item is None:
                item = Exercise(**values, is_active=True)
                session.add(item)
                inserted += 1
            else:
                for key, value in values.items():
                    setattr(item, key, value)
                item.is_active = True
                updated += 1
        if dry_run:
            session.rollback()
            print(f"dry-run: would insert {inserted}, update {updated}, archive old rows")
            return
        session.commit()
        print(f"imported {inserted} new, updated {updated}; old rows archived")


def main() -> None:
    args = parse_args()
    rows = build_rows(load_source(Path(args.source)))
    counts = Counter(row["equipment"] for row in rows)
    print(f"source rows: {len(rows)}; equipment: {dict(sorted(counts.items()))}")
    write_ios(rows, Path(args.ios_output))
    if args.ios_only:
        return
    import_rows(rows, args.target, args.dry_run)


if __name__ == "__main__":
    main()
