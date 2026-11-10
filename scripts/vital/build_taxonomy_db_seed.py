#!/usr/bin/env python3
"""Generate V28 seed SQL: taxonomy terms, exercise taxonomy, equipment types, mapping.

Sources:
  data/vital/taxonomy_v1.json
  data/vital/equipment_catalog_v2.json
  data/vital/equipment_exercise_map.json

Output:
  data/vital/v28_seed.sql
"""

from __future__ import annotations

import json
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TAX = ROOT / "data" / "vital" / "taxonomy_v1.json"
CAT = ROOT / "data" / "vital" / "equipment_catalog_v2.json"
MAP = ROOT / "data" / "vital" / "equipment_exercise_map.json"
OUT = ROOT / "data" / "vital" / "v28_seed.sql"
DDL = ROOT / "data" / "vital" / "v28_ddl.sql"
MIG = (
    ROOT
    / "admin-server"
    / "src"
    / "main"
    / "resources"
    / "db"
    / "migration"
    / "V28__exercise_taxonomy_and_equipment_catalog.sql"
)

TRAINING_CODES = {
    "力量": "strength",
    "拉伸": "stretch",
    "有氧": "cardio",
    "瑜伽": "yoga",
    "普拉提": "pilates",
    "灵活性": "mobility",
}
BODY_CODES = {
    "胸": "chest",
    "背": "back",
    "肩": "shoulders",
    "臂": "arms",
    "腿": "legs",
    "臀": "glutes",
    "核心": "core",
    "全身": "full_body",
}
MOVEMENT_CODES = {
    "推": "push",
    "拉": "pull",
    "蹲": "squat",
    "髋铰链": "hinge",
    "弓步": "lunge",
    "旋转": "rotation",
    "提携": "carry",
    "孤立": "isolation",
    "等长": "isometric",
}
MUSCLE_CODES = {
    "腹直肌": "abs",
    "侧腹": "obliques",
    "下背": "lower_back",
    "腰腹": "waist",
    "核心": "core",
    "股四头": "quads",
    "腘绳肌": "hamstrings",
    "小腿": "calves",
    "比目鱼肌": "soleus",
    "内收肌": "adductors",
    "大腿内侧": "inner_thighs",
    "髋内收": "hip_adductors",
    "髋屈肌": "hip_flexors",
    "臀大肌": "glutes",
    "髋外展": "hip_abductors",
    "外展肌": "abductors",
    "阔筋膜张肌": "tfl",
    "三角肌": "delts",
    "中束": "lateral_delts",
    "前束": "front_delts",
    "后束": "rear_delts",
    "肩": "shoulders",
    "肩袖": "rotator_cuff",
    "冈上肌": "supraspinatus",
    "颈": "neck",
    "斜方肌": "traps",
    "上斜方": "upper_traps",
    "背阔肌": "lats",
    "上背": "upper_back",
    "菱形肌": "rhomboids",
    "大圆肌": "teres_major",
    "背": "back",
    "胸大肌": "pectorals",
    "胸": "chest",
    "下胸": "lower_chest",
    "上胸": "upper_chest",
    "三头": "triceps",
    "二头": "biceps",
    "前臂": "forearms",
    "上臂": "upper_arms",
    "肱肌": "brachialis",
    "肱桡肌": "brachioradialis",
    "大腿": "upper_legs",
    "踝稳定肌": "ankle_stabilizers",
    "心肺": "cardio",
}
MUSCLE_PARENT = {
    "abs": "core", "obliques": "core", "lower_back": "core", "waist": "core",
    "core": "core",
    "quads": "legs", "hamstrings": "legs", "calves": "legs", "soleus": "legs",
    "adductors": "legs", "inner_thighs": "legs", "hip_adductors": "legs",
    "hip_flexors": "legs", "upper_legs": "legs", "ankle_stabilizers": "legs",
    "glutes": "glutes", "hip_abductors": "glutes", "abductors": "glutes",
    "tfl": "glutes",
    "delts": "shoulders", "lateral_delts": "shoulders", "front_delts": "shoulders",
    "rear_delts": "shoulders", "shoulders": "shoulders", "rotator_cuff": "shoulders",
    "supraspinatus": "shoulders", "neck": "shoulders",
    "traps": "back", "upper_traps": "back", "lats": "back", "upper_back": "back",
    "rhomboids": "back", "teres_major": "back", "back": "back",
    "pectorals": "chest", "chest": "chest", "lower_chest": "chest", "upper_chest": "chest",
    "triceps": "arms", "biceps": "arms", "forearms": "arms", "upper_arms": "arms",
    "brachialis": "arms", "brachioradialis": "arms",
}


def esc(value: str | None) -> str:
    if value is None:
        return "NULL"
    return "'" + str(value).replace("\\", "\\\\").replace("'", "''") + "'"


def new_id() -> str:
    return str(uuid.uuid4())


def main() -> None:
    tax = json.loads(TAX.read_text(encoding="utf-8"))
    catalog = json.loads(CAT.read_text(encoding="utf-8"))["equipment"]
    mapping = json.loads(MAP.read_text(encoding="utf-8"))["mapping"]

    lines: list[str] = []
    add = lines.append

    # taxonomy_terms
    add("DELETE FROM taxonomy_terms;")
    term_rows: list[str] = []
    order = 0
    for zh, code in TRAINING_CODES.items():
        order += 1
        term_rows.append(
            f"({esc(new_id())}, 'training_type', {esc(code)}, {esc(zh)}, NULL, {order})"
        )
    order = 0
    for zh, code in BODY_CODES.items():
        order += 1
        term_rows.append(
            f"({esc(new_id())}, 'body_part', {esc(code)}, {esc(zh)}, NULL, {order})"
        )
    order = 0
    for zh, code in MOVEMENT_CODES.items():
        order += 1
        term_rows.append(
            f"({esc(new_id())}, 'movement_pattern', {esc(code)}, {esc(zh)}, NULL, {order})"
        )
    order = 0
    for zh, code in MUSCLE_CODES.items():
        order += 1
        parent = MUSCLE_PARENT.get(code)
        term_rows.append(
            f"({esc(new_id())}, 'muscle', {esc(code)}, {esc(zh)}, {esc(parent)}, {order})"
        )
    add(
        "INSERT INTO taxonomy_terms (id, dimension, code, name_zh, parent_code, sort_order) VALUES\n"
        + ",\n".join(term_rows)
        + ";"
    )

    # exercise taxonomy via temp table
    add(
        "CREATE TEMPORARY TABLE _exercise_taxonomy ("
        "slug VARCHAR(60) PRIMARY KEY, training_type_code VARCHAR(20), "
        "body_part_code VARCHAR(20), muscle_primary_code VARCHAR(30), "
        "muscle_secondary_codes JSON, movement_pattern_code VARCHAR(20), "
        "plan_eligible TINYINT(1));"
    )
    rows: list[str] = []
    for e in tax["exercises"]:
        tt = TRAINING_CODES.get(e.get("training_type") or "")
        bp = BODY_CODES.get(e.get("body_part") or "")
        mp = MUSCLE_CODES.get(e.get("muscle_primary") or "")
        ms = [
            MUSCLE_CODES[m]
            for m in (e.get("muscle_secondary") or [])
            if m in MUSCLE_CODES
        ]
        mv = MOVEMENT_CODES.get(e.get("movement_pattern") or "")
        plan = 1 if tt == "strength" else 0
        rows.append(
            "("
            + ", ".join(
                [
                    esc(e["slug"]),
                    esc(tt),
                    esc(bp),
                    esc(mp),
                    esc(json.dumps(ms, ensure_ascii=False)),
                    esc(mv),
                    str(plan),
                ]
            )
            + ")"
        )
    add(
        "INSERT INTO _exercise_taxonomy (slug, training_type_code, body_part_code, "
        "muscle_primary_code, muscle_secondary_codes, movement_pattern_code, plan_eligible) VALUES\n"
        + ",\n".join(rows)
        + ";"
    )
    add(
        "UPDATE exercises e JOIN _exercise_taxonomy t ON e.slug = t.slug "
        "SET e.training_type_code = t.training_type_code, "
        "e.body_part_code = t.body_part_code, "
        "e.muscle_primary_code = t.muscle_primary_code, "
        "e.muscle_secondary_codes = t.muscle_secondary_codes, "
        "e.movement_pattern_code = t.movement_pattern_code, "
        "e.plan_eligible = t.plan_eligible, "
        "e.content_version = 'v1';"
    )
    add("DROP TEMPORARY TABLE _exercise_taxonomy;")

    # equipment types
    add("DELETE FROM equipment_type_exercises;")
    add("DELETE FROM equipment_types;")
    type_rows: list[str] = []
    for e in catalog:
        type_rows.append(
            "("
            + ", ".join(
                [
                    esc(new_id()),
                    esc(e["slug"]),
                    esc(e["name_zh"]),
                    esc(e.get("name_en")),
                    esc(e.get("category") or "machine"),
                    esc(e.get("exercise_group") or e["slug"]),
                    "1" if e["slug"] in {
                        "bodyweight", "dumbbell", "barbell", "kettlebell", "band",
                        "pullup", "dip", "battle_rope", "medicine_ball", "sled",
                    } else "0",
                    esc(json.dumps(e.get("aliases") or [], ensure_ascii=False)),
                    str(e["recognition_class"]) if e.get("recognition_class") is not None else "NULL",
                ]
            )
            + ")"
        )
    add(
        "INSERT INTO equipment_types (id, slug, name_zh, name_en, category, "
        "exercise_group, universal, aliases, recognition_class) VALUES\n"
        + ",\n".join(type_rows)
        + ";"
    )

    # equipment type -> exercise
    map_rows: list[str] = []
    seen: set[tuple[str, str]] = set()
    for e in catalog:
        group = e.get("exercise_group") or e["slug"]
        groups = [group]
        if e["slug"] == "pullup_dip_station":
            groups = ["pullup", "dip"]
        for g in groups:
            for slug in mapping.get(g, []):
                key = (e["slug"], slug)
                if key in seen:
                    continue
                seen.add(key)
                map_rows.append(
                    f"({esc(e['slug'])}, {esc(slug)}, 1)"
                )
    add(
        "INSERT INTO equipment_type_exercises (equipment_type_slug, exercise_slug, is_primary) VALUES\n"
        + ",\n".join(map_rows)
        + ";"
    )

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    MIG.write_text(
        DDL.read_text(encoding="utf-8") + "\n" + "\n".join(lines) + "\n",
        encoding="utf-8",
    )
    print(
        f"terms={len(term_rows)} exercises={len(rows)} "
        f"types={len(type_rows)} mappings={len(map_rows)}"
    )
    print(f"wrote {OUT}")
    print(f"wrote {MIG}")


if __name__ == "__main__":
    main()
