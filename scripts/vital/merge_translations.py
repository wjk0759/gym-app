from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


def norm(value: str) -> str:
    value = (value or "").lower().replace("&", " and ")
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def has_cjk(value: str) -> bool:
    return any("\u4e00" <= char <= "\u9fff" for char in value)


PART_MUSCLE = {
    "胸": "chest",
    "背": "back",
    "腿（股四头/腘绳）": "legs",
    "臀/髋": "glutes",
    "肩": "shoulders",
    "三头": "arms",
    "二头": "arms",
    "核心/腹/功能性": "core",
    "有氧/体能": "cardio",
    "小腿": "legs",
    "前臂": "arms",
    "颈部": "shoulders",
    "斜方肌": "back",
    "Tabata": "cardio",
    "灵活性/拉伸/放松": None,
}

MOVEMENT_TERMS = [
    "bench press", "push up", "pushup", "dip", "fly", "flye", "squat", "deadlift",
    "lunge", "leg press", "leg extension", "leg curl", "calf raise", "hip thrust",
    "glute bridge", "row", "pulldown", "pull down", "pull up", "pullup", "chin up",
    "curl", "press", "raise", "shrug", "crunch", "plank", "sit up", "leg raise",
    "stretch", "mobility", "run", "bike", "elliptical", "rower", "jump", "burpee",
    "thruster", "clean", "snatch", "swing", "carry", "sled", "bridge", "kickback",
    "abduction", "adduction", "good morning", "pushdown", "extension", "rotation",
    "twist", "march", "climber", "jack", "skip", "walk", "sprint",
]


def movement_keys(value: str) -> set[str]:
    text = (value or "").lower()
    return {term for term in MOVEMENT_TERMS if term in text}


def compatible_base(xunji_part: str, xunji_en: str, action: dict) -> bool:
    part_muscle = PART_MUSCLE.get(xunji_part, "unknown")
    if part_muscle not in ("unknown", None) and action["muscle_group"] != part_muscle:
        # Legs and glutes overlap heavily in Chinese gym taxonomy.
        if not {part_muscle, action["muscle_group"]} <= {"legs", "glutes"}:
            return False
    left = movement_keys(xunji_en)
    right = movement_keys(action["name_en"])
    if left and right and not (left & right):
        return False
    return True


def load_jsonl(path: Path):
    result = {}
    if not path.exists():
        return result
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            row = json.loads(line)
            result[row["i"]] = row
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, default=Path("data/vital"))
    parser.add_argument("--xunji", type=Path, default=Path(r"E:\训记动作库\xunji_movements_1213.json"))
    args = parser.parse_args()

    base = args.data
    actions = json.loads((base / "vital_actions_base.json").read_text(encoding="utf-8"))
    translations = load_jsonl(base / "name_translations.jsonl")
    xunji = json.loads(args.xunji.read_text(encoding="utf-8-sig"))
    xunji_rows = []
    for index, row in enumerate(xunji):
        values = list(row.values())
        xunji_rows.append(
            {
                "i": index,
                "zh": str(values[1]).strip(),
                "part": str(values[2]).strip(),
            }
        )

    strict = load_jsonl(base / "llm" / "xunji_llm_match.jsonl")
    base_match = load_jsonl(base / "llm" / "xunji_llm_base_match.jsonl")
    reviewed = load_jsonl(base / "llm" / "xunji_missing_review.jsonl")
    xunji_en = load_jsonl(base / "llm" / "xunji_translations.jsonl")
    instruction_zh = load_jsonl(base / "instruction_translations.jsonl")
    action_by_norm = {norm(action["name_en"]): action for action in actions}

    mapping_rows = []
    exact_names = {}
    candidates = defaultdict(list)
    for xrow in xunji_rows:
        chosen = None
        match_type = "none"
        confidence = 0.0
        for source, label, score in (
            (strict, "exact", 0.95),
            (base_match, "base", 0.8),
            (reviewed, "base", 0.75),
        ):
            row = source.get(xrow["i"])
            if not row or row.get("match") in (None, "", "NO"):
                continue
            action = action_by_norm.get(norm(row["match"]))
            if action:
                if label != "exact" and not compatible_base(
                    xrow["part"],
                    xunji_en.get(xrow["i"], {}).get("en", ""),
                    action,
                ):
                    continue
                chosen = action
                match_type = label
                confidence = score
                break

        if chosen:
            mapping_rows.append(
                {
                    "xunji_index": xrow["i"],
                    "xunji_name": xrow["zh"],
                    "part": xrow["part"],
                    "vital_slug": chosen["slug"],
                    "vital_name_en": chosen["name_en"],
                    "match_type": match_type,
                    "confidence": confidence,
                    "suggested_name_zh": xrow["zh"],
                    "needs_review": 0 if match_type == "exact" else 1,
                }
            )
            priority = 2 if match_type == "exact" else 1
            candidates[chosen["slug"]].append(
                {
                    "name_zh": xrow["zh"],
                    "match_type": match_type,
                    "priority": priority,
                    "confidence": confidence,
                    "xunji_index": xrow["i"],
                }
            )
            if match_type == "exact" and chosen["slug"] not in exact_names:
                exact_names[chosen["slug"]] = xrow["zh"]
        else:
            mapping_rows.append(
                {
                    "xunji_index": xrow["i"],
                    "xunji_name": xrow["zh"],
                    "part": xrow["part"],
                    "vital_slug": "",
                    "vital_name_en": "",
                    "match_type": "none",
                    "confidence": 0.0,
                    "suggested_name_zh": xrow["zh"],
                    "needs_review": 1,
                }
            )

    name_counts = Counter()
    for action in actions:
        action["name_zh_llm"] = translations.get(actions.index(action), {}).get("zh", "")
        # Only exact Xunji matches may supply the canonical Chinese name.
        # Base matches are candidates for review, never automatic names.
        if action["slug"] in exact_names:
            action["name_zh"] = exact_names[action["slug"]]
            action["name_zh_source"] = "xunji_exact"
            action["xunji_match_type"] = "exact"
        else:
            action["name_zh"] = action["name_zh_llm"]
            action["name_zh_source"] = "llm"
            action["xunji_match_type"] = "none"
        name_counts[action["name_zh"]] += 1
        translated_steps = instruction_zh.get(actions.index(action), {}).get("steps", [])
        action["instructions_zh"] = translated_steps
        action["instructions_zh_source"] = "llm" if translated_steps else ""
        action["instructions_needs_review"] = 1 if translated_steps else 1

    duplicates = {name for name, count in name_counts.items() if name and count > 1}
    for action in actions:
        cand = candidates.get(action["slug"], [])
        cand.sort(key=lambda item: (-item["priority"], -item["confidence"]))
        action["xunji_candidate"] = cand[0]["name_zh"] if cand else ""
        action["xunji_candidate_match_type"] = cand[0]["match_type"] if cand else ""
        review_priority = "low"
        if action["name_zh_source"] == "xunji_exact":
            review_priority = "low"
        elif action["xunji_candidate_match_type"] == "base":
            review_priority = "high"
        else:
            review_priority = "medium"
        if not has_cjk(action["name_zh"]) or action["name_zh"] in duplicates:
            review_priority = "high"
        action["review_priority"] = review_priority
        action["needs_review"] = 0 if review_priority == "low" else 1

    # Write mapping review.
    with (base / "xunji_vital_mapping.csv").open(
        "w", encoding="utf-8-sig", newline=""
    ) as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "xunji_index",
                "xunji_name",
                "part",
                "vital_slug",
                "vital_name_en",
                "match_type",
                "confidence",
                "suggested_name_zh",
                "needs_review",
            ],
        )
        writer.writeheader()
        writer.writerows(mapping_rows)

    # Write bilingual review.
    review_fields = [
        "slug",
        "name_en",
        "name_zh_draft",
        "name_zh_llm",
        "name_zh_source",
        "xunji_candidate",
        "xunji_candidate_match_type",
        "review_priority",
        "equipment",
        "muscle_group",
        "sex_variants",
        "media_count",
        "instructions_zh",
    ]
    def write_review(path, rows):
        with path.open("w", encoding="utf-8-sig", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(review_fields)
            for action in rows:
                writer.writerow(
                    [
                        action["slug"],
                        action["name_en"],
                        action["name_zh"],
                        action["name_zh_llm"],
                        action["name_zh_source"],
                        action.get("xunji_candidate", ""),
                        action.get("xunji_candidate_match_type", ""),
                        action["review_priority"],
                        action["equipment"],
                        action["muscle_group"],
                        "/".join(action["sex_variants"]),
                        len(action["media"]),
                        " / ".join(action.get("instructions_zh") or []),
                    ]
                )

    write_review(base / "vital_actions_review.csv", actions)
    write_review(
        base / "review_high.csv",
        [action for action in actions if action["review_priority"] == "high"],
    )
    write_review(
        base / "review_medium.csv",
        [action for action in actions if action["review_priority"] == "medium"],
    )
    write_review(
        base / "review_low.csv",
        [action for action in actions if action["review_priority"] == "low"],
    )

    # Write the draft catalog. It is intentionally not wired into the app yet.
    (base / "vital_actions_zh_draft.json").write_text(
        json.dumps(actions, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    with (base / "vital_actions_zh_draft.csv").open(
        "w", encoding="utf-8-sig", newline=""
    ) as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "slug",
                "name_zh",
                "name_en",
                "name_zh_source",
                "review_priority",
                "equipment",
                "muscle_group",
                "media_count",
                "instruction_count",
            ]
        )
        for action in actions:
            writer.writerow(
                [
                    action["slug"],
                    action["name_zh"],
                    action["name_en"],
                    action["name_zh_source"],
                    action["review_priority"],
                    action["equipment"],
                    action["muscle_group"],
                    len(action["media"]),
                    len(action.get("instructions_zh") or []),
                ]
            )

    mapping_counts = Counter(row["match_type"] for row in mapping_rows)
    source_counts = Counter(action["name_zh_source"] for action in actions)
    priority_counts = Counter(action["review_priority"] for action in actions)
    print("actions", len(actions), "media", sum(len(a["media"]) for a in actions))
    print("mapping", dict(mapping_counts))
    print("name_source", dict(source_counts))
    print("review_priority", dict(priority_counts))
    print("duplicate_chinese_names", len(duplicates))
    print("wrote", base / "xunji_vital_mapping.csv")
    print("wrote", base / "vital_actions_review.csv")
    print("wrote", base / "vital_actions_zh_draft.json")


if __name__ == "__main__":
    main()
