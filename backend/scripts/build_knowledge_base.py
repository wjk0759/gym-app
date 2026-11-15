"""Build the four coach knowledge bases from audited open sources.

The pipeline is intentionally boring and reproducible. It runs three rounds:

1. ingest + normalize: parse source rows, convert Traditional to Simplified
   Chinese, normalize names, coerce numbers, drop exact duplicates.
2. validate + filter: enforce nutrient ranges, flag macro/energy mismatches,
   drop unusable rows, collapse near-duplicates that have identical macros.
3. enrich + shape for RAG: add aliases, serving hints, category cards, search
   text and a quality score; write JSONL plus a manifest with source/licensing.

Outputs live in ``backend/data/knowledge`` and are committed so the API does
not need to rebuild them at boot. The only build-time dependency is
``opencc-python-reimplemented``; runtime search is standard-library only.
"""

from __future__ import annotations

import csv
import json
import re
import sys
import unicodedata
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

BACKEND_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = BACKEND_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
OUT_DIR = DATA_DIR / "knowledge"

FOOD_CSV = RAW_DIR / "tw_food_2015.csv"
SEED_JSON = RAW_DIR / "knowledge_seed.json"
EXERCISES_JSONL = DATA_DIR / "exercises_rag.jsonl"

FOOD_SOURCE = "Taiwan FDA Food Nutrition Database (2015)"
FOOD_SOURCE_URL = "https://consumer.fda.gov.tw/Food/TFND.aspx?nodeID=178"
FOOD_LICENSE = "OGDL 1.0 (Taiwan government open data license)"
EXERCISE_SOURCE = "hasaneyldrm/exercises-dataset"
EXERCISE_SOURCE_URL = "https://github.com/hasaneyldrm/exercises-dataset"
EXERCISE_LICENSE = "MIT (text); media excluded"

DEFAULT_SERVING_G = {
    "谷物类": 150,
    "豆类": 100,
    "蔬菜类": 150,
    "水果类": 150,
    "肉类": 100,
    "鱼贝类": 100,
    "蛋类": 50,
    "乳品类": 250,
    "菇类": 100,
    "藻类": 50,
    "坚果及种子类": 25,
    "油脂类": 10,
    "淀粉类": 100,
    "糖类": 10,
    "调味料及香辛料类": 10,
    "加工调理食品类": 100,
    "糕饼点心类": 80,
    "嗜好性饮料类": 350,
}

# Round 2 bounds are deliberately wide: the source is a composition table, not
# a diet plan, so pure oils and salt are valid. Anything outside is a parse bug.
NUTRIENT_RANGES = {
    "kcal": (0.0, 950.0),
    "protein_g": (0.0, 100.0),
    "fat_g": (0.0, 100.0),
    "carbs_g": (0.0, 100.0),
    "fiber_g": (0.0, 100.0),
    "sugar_g": (0.0, 100.0),
    "sodium_mg": (0.0, 50000.0),
    "potassium_mg": (0.0, 10000.0),
    "calcium_mg": (0.0, 5000.0),
    "iron_mg": (0.0, 200.0),
    "cholesterol_mg": (0.0, 5000.0),
    "vitamin_c_mg": (0.0, 5000.0),
}

TRACE_VALUES = {"", "—", "-", "–", "tr", "trace", "nd", "n/a", "na", "..."}


def _opencc():
    try:
        from opencc import OpenCC
    except ImportError as exc:  # pragma: no cover - build environment only
        raise SystemExit(
            "build_knowledge_base.py needs opencc-python-reimplemented: "
            "pip install opencc-python-reimplemented"
        ) from exc
    return OpenCC("t2s")


def _norm_space(value: str) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def _norm_key(value: str) -> str:
    text = unicodedata.normalize("NFKC", _norm_space(value)).lower()
    text = re.sub(r"[（(].*?[）)]", "", text)
    text = re.sub(r"[^0-9a-z\u4e00-\u9fff]+", "", text)
    return text


def _exact_key(value: str) -> str:
    text = unicodedata.normalize("NFKC", _norm_space(value)).lower()
    return re.sub(r"\s+", "", text)


def _num(value: Any) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace(",", "")
    if text.lower() in TRACE_VALUES:
        return None
    match = re.search(r"-?\d+(?:\.\d+)?", text)
    if match is None:
        return None
    try:
        return float(match.group(0))
    except ValueError:
        return None


def _round(value: float | None, digits: int = 1) -> float | None:
    return None if value is None else round(value, digits)


def _read_json(path: Path) -> Any:
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


def _aliases_for_food(name: str, synonyms: dict[str, list[str]]) -> list[str]:
    candidates: list[str] = [name]
    without_note = re.sub(r"[（(].*?[）)]", "", name).strip()
    if without_note and without_note != name:
        candidates.append(without_note)
    base = without_note or name
    without_average = re.sub(r"(平均值|平均|代表值)$", "", base).strip()
    if without_average and without_average != name:
        candidates.append(without_average)
    for part in re.split(r"[、,，/]", name):
        part = part.strip()
        if part and part != name:
            candidates.append(part)
    processed = any(
        token in name
        for token in (
            "松",
            "罐头",
            "罐頭",
            "干制",
            "乾製",
            "风干",
            "風乾",
            "晒干",
            "曬乾",
            "酱",
            "醬",
            "丸",
            "饼",
            "餅",
            "汤",
            "湯",
            "粉",
            "调味",
            "調味",
            "浓缩",
            "濃縮",
            "腌",
            "醃",
            "熏",
            "燻",
            "蜜饯",
            "蜜餞",
            "果酱",
            "果醬",
            "饮料",
            "飲料",
        )
    )
    if not processed:
        for key, values in synonyms.items():
            if key and key in name:
                candidates.extend(values)
    # "鸡胸肉（去皮）" -> "去皮鸡胸肉" is ambiguous; prefer the short form.
    aliases: list[str] = []
    seen = {name}
    for item in candidates:
        item = _norm_space(item)
        if len(item) < 2 or item in seen:
            continue
        if len(item) > 30:
            continue
        seen.add(item)
        aliases.append(item)
    return aliases[:12]


def round1_food(csv_path: Path) -> tuple[list[dict], dict]:
    cc = _opencc()
    stats = {"input_rows": 0, "parsed_rows": 0, "empty_name": 0, "exact_dup": 0}
    rows: list[dict] = []
    seen: set[tuple[str, str]] = set()
    with csv_path.open(encoding="utf-8-sig", newline="") as handle:
        for raw in csv.DictReader(handle):
            stats["input_rows"] += 1
            name_tw = _norm_space(raw.get("樣品名稱") or "")
            if not name_tw:
                stats["empty_name"] += 1
                continue
            name = cc.convert(name_tw)
            category = cc.convert(_norm_space(raw.get("食品分類") or "未分类"))
            key = (_exact_key(name), category)
            if key in seen:
                stats["exact_dup"] += 1
                continue
            seen.add(key)
            sodium = _num(raw.get("鈉-成分值(mg)"))
            rows.append(
                {
                    "id": "food-tw-" + _norm_space(raw.get("整合編號") or "").lower(),
                    "domain": "food",
                    "name_zh": name,
                    "name_tw": name_tw,
                    "category": category,
                    "kcal": _num(raw.get("修正熱量-成分值(kcal)"))
                    or _num(raw.get("熱量-成分值(kcal)")),
                    "protein_g": _num(raw.get("粗蛋白-成分值(g)")),
                    "fat_g": _num(raw.get("粗脂肪-成分值(g)")),
                    "carbs_g": _num(raw.get("總碳水化合物-成分值(g)")),
                    "fiber_g": _num(raw.get("膳食纖維-成分值(g)")),
                    "sugar_g": _num(raw.get("糖質總量-成分值(g)")),
                    "sodium_mg": sodium,
                    "potassium_mg": _num(raw.get("鉀-成分值(mg)")),
                    "calcium_mg": _num(raw.get("鈣-成分值(mg)")),
                    "iron_mg": _num(raw.get("鐵-成分值(mg)")),
                    "cholesterol_mg": _num(raw.get("膽固醇-成分值(mg)")),
                    "vitamin_c_mg": _num(raw.get("維生素C-成分值(mg)")),
                    "source": FOOD_SOURCE,
                    "source_url": FOOD_SOURCE_URL,
                    "license": FOOD_LICENSE,
                }
            )
            stats["parsed_rows"] += 1
    return rows, stats


def round2_food(rows: list[dict]) -> tuple[list[dict], dict]:
    stats = {
        "input_rows": len(rows),
        "dropped_missing_energy": 0,
        "dropped_out_of_range": 0,
        "partial_macros": 0,
        "macro_mismatch_flagged": 0,
        "near_dup_dropped": 0,
    }
    cleaned: list[dict] = []
    for row in rows:
        if row.get("kcal") is None:
            stats["dropped_missing_energy"] += 1
            continue
        invalid = False
        for field, (low, high) in NUTRIENT_RANGES.items():
            value = row.get(field)
            if value is None:
                continue
            if not (low <= value <= high):
                invalid = True
                break
        if invalid:
            stats["dropped_out_of_range"] += 1
            continue

        flags: list[str] = []
        # Composition tables often leave "0" blank for pure macro categories.
        # Fill only when the category makes the value unambiguous.
        category = row.get("category") or ""
        if (
            row.get("carbs_g") is None
            and row.get("protein_g") is not None
            and row.get("fat_g") is not None
            and category in {"肉类", "鱼贝类", "蛋类"}
        ):
            row["carbs_g"] = 0.0
            flags.append("carbs_zero_filled")
        if (
            row.get("fat_g") is None
            and row.get("protein_g") is not None
            and row.get("carbs_g") is not None
            and category in {"谷物类", "水果类", "蔬菜类", "豆类"}
        ):
            row["fat_g"] = 0.0
            flags.append("fat_zero_filled")
        if (
            row.get("protein_g") is None
            and row.get("fat_g") is not None
            and row.get("carbs_g") is not None
            and category in {"油脂类", "糖类"}
        ):
            row["protein_g"] = 0.0
            flags.append("protein_zero_filled")

        macros = [row.get("protein_g"), row.get("fat_g"), row.get("carbs_g")]
        if any(value is None for value in macros):
            stats["partial_macros"] += 1
            flags.append("partial_macros")
        else:
            estimate = (
                4 * float(row["protein_g"])
                + 4 * float(row["carbs_g"])
                + 9 * float(row["fat_g"])
            )
            if abs(estimate - float(row["kcal"])) > max(
                150.0, float(row["kcal"]) * 0.35
            ):
                stats["macro_mismatch_flagged"] += 1
                flags.append("macro_mismatch")
        row["flags"] = flags

        # Keep preparation variants, but collapse rows whose normalized name and
        # rounded macros are identical (common OCR duplicates across categories).
        macro_key = (
            round(float(row.get("kcal") or 0) / 5),
            round(float(row.get("protein_g") or 0) / 2),
            round(float(row.get("fat_g") or 0) / 2),
            round(float(row.get("carbs_g") or 0) / 2),
        )
        row["_dup_key"] = (_norm_key(row["name_zh"]), macro_key)
        cleaned.append(row)

    deduped: list[dict] = []
    best: dict[tuple, dict] = {}
    for row in cleaned:
        key = row["_dup_key"]
        current = best.get(key)
        if current is None:
            best[key] = row
            deduped.append(row)
            continue
        # Prefer the record with complete macros and the shorter display name.
        current_score = (len(current.get("flags") or []), len(current["name_zh"]))
        row_score = (len(row.get("flags") or []), len(row["name_zh"]))
        if row_score < current_score:
            index = deduped.index(current)
            deduped[index] = row
            best[key] = row
            stats["near_dup_dropped"] += 1
        else:
            stats["near_dup_dropped"] += 1

    for row in deduped:
        row.pop("_dup_key", None)
    return deduped, stats


def round3_food(
    rows: list[dict],
    seed: dict,
) -> tuple[list[dict], dict]:
    synonyms = seed.get("food_synonyms") or {}
    stats = {"aliases_added": 0, "quality_high": 0, "quality_partial": 0}
    output: list[dict] = []
    for row in rows:
        aliases = _aliases_for_food(row["name_zh"], synonyms)
        stats["aliases_added"] += len(aliases)
        serving = DEFAULT_SERVING_G.get(row["category"], 100)
        flags = list(row.get("flags") or [])
        if "partial_macros" in flags or "macro_mismatch" in flags:
            quality = 0.6
            stats["quality_partial"] += 1
        else:
            quality = 1.0
            stats["quality_high"] += 1
        search_text = " ".join(
            [
                row["name_zh"],
                " ".join(aliases),
                row["category"],
            ]
        )
        output.append(
            {
                "id": row["id"],
                "domain": "food",
                "title": row["name_zh"],
                "name_zh": row["name_zh"],
                "name_tw": row["name_tw"],
                "aliases": aliases,
                "category": row["category"],
                "kcal": _round(row.get("kcal")),
                "protein_g": _round(row.get("protein_g")),
                "fat_g": _round(row.get("fat_g")),
                "carbs_g": _round(row.get("carbs_g")),
                "fiber_g": _round(row.get("fiber_g")),
                "sugar_g": _round(row.get("sugar_g")),
                "sodium_mg": _round(row.get("sodium_mg")),
                "potassium_mg": _round(row.get("potassium_mg")),
                "calcium_mg": _round(row.get("calcium_mg")),
                "iron_mg": _round(row.get("iron_mg")),
                "cholesterol_mg": _round(row.get("cholesterol_mg")),
                "vitamin_c_mg": _round(row.get("vitamin_c_mg")),
                "serving_g": serving,
                "serving_label": f"每 100g；默认份量约 {serving}g",
                "flags": flags,
                "quality": quality,
                "search_text": search_text,
                "source": row["source"],
                "source_url": row["source_url"],
                "license": row["license"],
            }
        )

    return output, stats



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
                        [name, str(item.get("name_en") or ""), " ".join(aliases), body_part, equipment, target]
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
    if not FOOD_CSV.exists():
        raise SystemExit(f"missing raw food CSV: {FOOD_CSV}")
    if not SEED_JSON.exists():
        raise SystemExit(f"missing seed: {SEED_JSON}")
    seed = _read_json(SEED_JSON)

    food_r1, r1_stats = round1_food(FOOD_CSV)
    food_r2, r2_stats = round2_food(food_r1)
    food, r3_stats = round3_food(food_r2, seed)
    coach, coach_stats = build_coach(seed)
    equipment, equipment_stats = build_equipment(seed)

    _write_jsonl(OUT_DIR / "food_nutrition.jsonl", food)
    _write_jsonl(OUT_DIR / "coach_knowledge.jsonl", coach)
    _write_jsonl(OUT_DIR / "equipment_knowledge.jsonl", equipment)

    manifest = {
        "version": 1,
        "generated_at": datetime.now(timezone.utc).date().isoformat(),
        "build_date": date.today().isoformat(),
        "sources": [
            {
                "name": FOOD_SOURCE,
                "url": FOOD_SOURCE_URL,
                "license": FOOD_LICENSE,
                "raw_file": "tw_food_2015.csv",
                "note": "2015 edition; Traditional Chinese converted to Simplified.",
            },
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
            "round1_ingest_normalize": r1_stats,
            "round2_validate_filter": r2_stats,
            "round3_enrich_shape": {
                **r3_stats,
                **coach_stats,
                **equipment_stats,
                "food_final": len(food),
                "coach_final": len(coach),
                "equipment_final": len(equipment),
            },
        },
        "counts": {
            "food_nutrition": len(food),
            "coach_knowledge": len(coach),
            "equipment_knowledge": len(equipment),
            "coach_exercises": coach_stats["exercise_rows"],
            "coach_curated_cards": coach_stats["curated_cards"],
        },
        "files": {
            "food_nutrition.jsonl": len(food),
            "coach_knowledge.jsonl": len(coach),
            "equipment_knowledge.jsonl": len(equipment),
        },
        "quality_rules": {
            "food_energy_range": list(NUTRIENT_RANGES["kcal"]),
            "macro_mismatch_tolerance": "max(150 kcal, 35%)",
            "near_duplicate": "same normalized name + same 5 kcal/2 g macro bucket",
            "safety": "coach cards are educational summaries, not medical advice",
        },
    }
    _write_json(OUT_DIR / "manifest.json", manifest)

    print(json.dumps(manifest["counts"], ensure_ascii=False, indent=2))
    print(json.dumps(manifest["rounds"], ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
