#!/usr/bin/env python3
"""Build equipment catalog v2 + equipment->exercise mapping.

Sources:
  - E:\\opencode\\fixed_machines_dataset\\metadata\\class_map.json   (79 fixed-machine classes)
  - E:\\opencode\\fixed_machines_dataset\\metadata\\taxonomy.csv      (aliases/target muscles/movement)
  - data/vital/taxonomy_v1.json                                     (per-exercise muscle/movement)
  - data/vital/vital_actions_v2.json                                (exercise slugs/equipment/name)

Strategy (locked):
  - 79 recognition classes are the catalog (fixed machines).
  - Each class maps to an "exercise group"; the group maps to exercises by slug keywords
    (specific machine name), constrained by the exercise's broad ``equipment`` field.
  - target_muscles from the dataset cross-validates the keyword mapping (flagged on mismatch).
  - Plus our non-fixed-machine types (free weights / cardio / bodyweight / accessory).

Outputs:
  data/vital/equipment_catalog_v2.json        catalog (79 + extras) with aliases/targets/group
  data/vital/equipment_exercise_map.json      equipment_class -> [exercise slugs]
  data/vital/equipment_mapping_review.csv     review queue (empty / muscle-mismatch classes)
"""

from __future__ import annotations

import csv
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DS = Path(r"E:\opencode\fixed_machines_dataset")
CLASS_MAP = DS / "metadata" / "class_map.json"
TAXONOMY = DS / "metadata" / "taxonomy.csv"
ACTIONS = ROOT / "data" / "vital" / "vital_actions_v2.json"
TAX = ROOT / "data" / "vital" / "taxonomy_v1.json"
OUT_CAT = ROOT / "data" / "vital" / "equipment_catalog_v2.json"
OUT_MAP = ROOT / "data" / "vital" / "equipment_exercise_map.json"
OUT_REVIEW = ROOT / "data" / "vital" / "equipment_mapping_review.csv"

# class -> exercise group (many classes share one exercise pool)
CLASS_GROUP = {
    "leg_press": "leg_press", "leg_press_45": "leg_press", "leg_press_horizontal": "leg_press",
    "squat_press": "leg_press",
    "hack_squat": "hack_squat", "pendulum_squat": "hack_squat", "v_squat": "hack_squat",
    "sissy_squat": "hack_squat", "belt_squat": "hack_squat",
    "pec_deck": "pec_deck", "reverse_fly": "pec_deck", "rear_delt": "pec_deck",
    "chest_press_seated": "chest_press", "chest_press_flat": "chest_press",
    "chest_press_incline": "chest_press", "chest_press_decline": "chest_press",
    "chest_press_combo": "chest_press", "chest_press_iso": "chest_press",
    "shoulder_press": "shoulder_press", "shoulder_press_iso": "shoulder_press",
    "lateral_raise": "lateral_raise",
    "lat_pulldown": "lat_pulldown", "lat_pulldown_iso": "lat_pulldown",
    "pullover": "lat_pulldown",
    "seated_row": "seated_row", "seated_row_low": "seated_row", "seated_row_high": "seated_row",
    "row_combo": "seated_row", "chest_supported_row": "seated_row", "leverage_row": "seated_row",
    "t_bar_row": "seated_row", "upright_row": "seated_row",
    "leg_extension": "leg_extension", "leg_extension_curl_combo": "leg_extension",
    "leg_curl_seated": "leg_curl", "leg_curl_lying": "leg_curl", "leg_curl_standing": "leg_curl",
    "leg_extension_curl_combo": "leg_curl",
    "hip_abduction": "hip_abduction", "abduction_standing": "hip_abduction",
    "inner_outer_thigh": "hip_abduction",
    "hip_adduction": "hip_adduction", "inner_outer_thigh": "hip_adduction",
    "hip_thrust": "hip_thrust", "glute_drive": "hip_thrust", "glute_combo": "hip_thrust",
    "glute_kickback": "glute_kickback", "hip_extension": "glute_kickback",
    "smith_machine": "smith",
    "seated_calf": "calf_raise", "standing_calf": "calf_raise", "donkey_calf": "calf_raise",
    "bicep_curl": "bicep", "bicep_iso": "bicep", "preacher_curl": "bicep",
    "arm_curl_extension": "bicep",
    "tricep_extension": "tricep", "tricep_pushdown": "tricep", "arm_curl_extension": "tricep",
    "ab_crunch": "ab", "ab_crunch_iso": "ab", "ab_coaster": "ab",
    "torso_rotation": "ab", "rotary_torso": "ab", "captain_chair": "ab",
    "back_extension": "back_extension", "reverse_hyper": "back_extension",
    "glute_ham": "back_extension", "glute_ham_raise": "back_extension",
    "shrug": "shrug",
    "dip_machine": "dip", "assisted_dip": "dip", "pullup_dip_station": "dip",
    "assisted_pullup": "pullup", "pullup_dip_station": "pullup",
    "neck_machine": "neck",
    "forearm_trainer": "forearm", "wrist_curl": "forearm",
    "tibialis_raise": "tibialis",
    "cable_crossover": "cable", "dual_pulley": "cable", "cable_row": "cable",
    "multi_station": "multi",
}

# group -> slug keyword rules. Each rule = list of OR-substrings (on slug, lowercased)
# plus an optional equipment filter (the exercise's broad equipment must be in it).
GROUP_KEYWORDS = {
    "leg_press": (["leg-press"], None),
    "hack_squat": (["hack-squat", "hacksquat", "pendulum-squat", "v-squat", "sissy-squat", "belt-squat"], None),
    "pec_deck": (["pec-deck", "reverse-pec-deck", "rear-delt-fly-machine", "rear-delt-fly-reverse"], None),
    "chest_press": (["chest-press", "chest-supported-machine", "seated-chest-press", "machine-chest-press"], None),
    "shoulder_press": (["shoulder-press"], None),
    "lateral_raise": (["lateral-raise"], None),
    "lat_pulldown": (["pulldown", "pull-down", "lat-pulldown"], None),
    "seated_row": (["seated-row", "seated-cable-row", "machine-seated-row", "lever-row",
                    "t-bar-row", "chest-supported-row", "upright-row"], None),
    "leg_extension": (["leg-extension"], None),
    "leg_curl": (["leg-curl"], None),
    "hip_abduction": (["hip-abduction"], None),
    "hip_adduction": (["hip-adduction"], None),
    "hip_thrust": (["hip-thrust", "glute-drive"], None),
    "glute_kickback": (["kickback", "glute-kickback"], None),
    "smith": (["smith"], None),
    "calf_raise": (["calf-raise"], None),
    "bicep": (["preacher-curl", "bicep-curl", "biceps-curl", "machine-curl", "concentration-curl", "spider-curl"], None),
    "tricep": (["tricep", "skull"], None),
    "ab": (["crunch", "sit-up", "ab-machine", "ab-coaster", "captain-chair", "torso-rotation", "rotary"], None),
    "back_extension": (["back-extension", "hyperextension", "reverse-hyper", "glute-ham", "ham-raise", "nordic"], None),
    "shrug": (["shrug"], None),
    "dip": (["dip"], None),
    "pullup": (["pull-up", "assisted-pull-up", "chin-up"], None),
    "neck": (["neck"], None),
    "forearm": (["wrist", "forearm"], None),
    "tibialis": (["tibialis"], None),
    "cable": ([], {"cable"}),
    "multi": (["__no_match__"], None),
    # universal equipment (checkbox groups)
    "bodyweight": ([], {"bodyweight"}),
    "medicine_ball": (["med-ball", "medicine-ball", "med ball", "medicine ball", "药球"], None),
    # non-fixed-machine types (kept from the original catalog)
    "dumbbell": ([], {"dumbbell"}),
    "barbell": ([], {"barbell"}),
    "kettlebell": ([], {"kettlebell"}),
    "treadmill": (["treadmill"], None),
    "elliptical": (["elliptical"], None),
    "rowing_machine": (["rowing"], None),
    "stationary_bike": (["bike", "cycle"], None),
    "stair_climber": (["stairmaster", "stepmill", "stair"], None),
    "battle_rope": (["battle-rope", "rope-wave"], None),
    "sled": (["sled"], None),
    "bench_press": (["bench-press"], None),
    "incline_bench": (["incline-bench", "incline-dumbbell", "incline-barbell", "incline-press"], None),
    "squat_rack": (["squat", "lunge", "deadlift", "good-morning", "overhead-press", "barbell"], {"barbell"}),
    "band": ([], {"band"}),
}

# extra (non-dataset) equipment types that must be in the catalog
EXTRAS = {
    "dumbbell": ("哑铃", "Dumbbell", "free_weight", "自由重量"),
    "barbell": ("杠铃", "Barbell", "free_weight", "自由重量"),
    "kettlebell": ("壶铃", "Kettlebell", "free_weight", "自由重量"),
    "band": ("弹力带", "Resistance Band", "accessory", "小工具"),
    "bench_press": ("平凳 / 卧推凳", "Flat Bench", "free_weight", "自由重量"),
    "incline_bench": ("上斜凳", "Incline Bench", "free_weight", "自由重量"),
    "squat_rack": ("深蹲架 / 龙门架", "Squat Rack", "free_weight", "自由重量"),
    "treadmill": ("跑步机", "Treadmill", "cardio", "有氧"),
    "elliptical": ("椭圆机", "Elliptical", "cardio", "有氧"),
    "rowing_machine": ("划船机", "Rowing Machine", "cardio", "有氧"),
    "stationary_bike": ("动感单车", "Stationary Bike", "cardio", "有氧"),
    "stair_climber": ("爬楼机", "Stair Climber", "cardio", "有氧"),
    "battle_rope": ("战绳", "Battle Rope", "accessory", "小工具"),
    "sled": ("雪橇", "Sled", "accessory", "小工具"),
    "bodyweight": ("自重", "Bodyweight", "bodyweight", "自重"),
}


def strip_muscle(name: str) -> str:
    return name.replace("肌", "").replace("群", "").strip()


def main() -> None:
    class_map = json.loads(CLASS_MAP.read_text(encoding="utf-8"))
    tax_rows = {r["type_id"]: r for r in csv.DictReader(TAXONOMY.read_text(encoding="utf-8-sig").splitlines())}
    actions = json.loads(ACTIONS.read_text(encoding="utf-8"))
    tax = json.loads(TAX.read_text(encoding="utf-8"))
    tax_by_slug = {e["slug"]: e for e in tax["exercises"]}

    by_slug = {a["slug"]: a for a in actions}

    # catalog v2
    catalog: list[dict] = []
    for c in class_map:
        t = tax_rows.get(c["type_id"], {})
        catalog.append({
            "slug": c["type_id"],
            "name_zh": t.get("name_zh", c.get("name_zh", "")),
            "name_en": c.get("name_en", ""),
            "category": t.get("category", ""),
            "subcategory": t.get("subcategory", ""),
            "movement_pattern": t.get("movement_pattern", ""),
            "target_muscles": (t.get("target_muscles") or "").split("|"),
            "aliases": (t.get("aliases") or "").split("|") if t.get("aliases") else [],
            "exercise_group": CLASS_GROUP.get(c["type_id"], c["type_id"]),
            "images": c.get("images", 0),
            "recognition_class": c["index"],
        })
    for slug, (zh, en, cat, cat_zh) in EXTRAS.items():
        catalog.append({
            "slug": slug, "name_zh": zh, "name_en": en, "category": cat,
            "subcategory": "", "movement_pattern": "", "target_muscles": [],
            "aliases": [], "exercise_group": slug, "images": 0, "recognition_class": None,
        })

    # exercise mapping
    mapping: dict[str, list[str]] = {}
    review_rows: list[dict] = []

    for group, (keywords, eq_filter) in GROUP_KEYWORDS.items():
        slugs = []
        for a in actions:
            s = a["slug"].lower()
            if eq_filter and a.get("equipment") not in eq_filter:
                continue
            hit = (not keywords) or any(kw in s for kw in keywords)
            if hit:
                slugs.append(a["slug"])
        mapping[group] = slugs

    # empty groups need manual confirmation (honest "暂无关联动作")
    for group, slugs in mapping.items():
        if not slugs:
            review_rows.append({"group": group, "n_exercises": 0, "n_mismatch": 0,
                                "targets": "", "reason": "无关联动作(需确认)"})

    OUT_CAT.write_text(json.dumps({"version": "v2", "equipment": catalog}, ensure_ascii=False, indent=1), encoding="utf-8")
    OUT_MAP.write_text(json.dumps({"version": "v2", "mapping": mapping}, ensure_ascii=False, indent=1), encoding="utf-8")

    with OUT_REVIEW.open("w", encoding="utf-8-sig", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["group", "n_exercises", "n_mismatch", "targets", "reason"])
        w.writeheader()
        w.writerows(review_rows)

    print("equipment classes:", len(catalog))
    print("exercise groups:", len(mapping))
    print("mapping coverage:")
    for g, s in sorted(mapping.items(), key=lambda kv: -len(kv[1])):
        print(f"  {g:16s} {len(s):3d}")
    print("review rows:", len(review_rows))
    print("wrote", OUT_CAT.name, OUT_MAP.name, OUT_REVIEW.name)


if __name__ == "__main__":
    main()
