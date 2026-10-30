"""Compact lexical retrieval over the filtered exercise knowledge base.

The full data pack is far too large for a prompt. The coach calls this only
when the user asks about an exercise, substitution or equipment, and receives
the top 3-5 compact records.
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path
from typing import Any

DATA_PATH = Path(__file__).resolve().parents[2] / "data" / "exercises_rag.jsonl"
MAX_RESULTS = 5
MAX_STEPS = 6
STOP_TERMS = {
    "动作",
    "怎么",
    "如何",
    "替代",
    "训练",
    "健身",
    "一个",
    "这个",
    "那个",
    "器械",
    "做",
    "练",
    "的",
    "吗",
}


@lru_cache(maxsize=1)
def load_exercises() -> tuple[dict[str, Any], ...]:
    if not DATA_PATH.exists():
        return ()
    rows: list[dict[str, Any]] = []
    with DATA_PATH.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(item, dict) and item.get("name_zh"):
                rows.append(item)
    return tuple(rows)


def _terms(text: str) -> set[str]:
    terms: set[str] = set()
    for word in re.findall(r"[a-z0-9]+|[\u4e00-\u9fff]+", text.lower()):
        if re.fullmatch(r"[a-z0-9]+", word):
            if len(word) >= 2 and word not in STOP_TERMS:
                terms.add(word)
            continue
        # Chinese: bigrams and trigrams catch "弹力带划船" -> 弹力/力带/划船.
        for size in (2, 3):
            for index in range(0, max(0, len(word) - size + 1)):
                term = word[index : index + size]
                if term not in STOP_TERMS:
                    terms.add(term)
    return terms


def _search_text(item: dict) -> str:
    aliases = item.get("aliases") or []
    if not isinstance(aliases, list):
        aliases = [aliases]
    return " ".join(
        [
            str(item.get("name_zh") or ""),
            str(item.get("name_en") or ""),
            " ".join(str(alias) for alias in aliases),
            str(item.get("equipment_zh") or ""),
            str(item.get("body_part_zh") or ""),
            str(item.get("target_zh") or ""),
        ]
    ).lower()


def search_exercises(query: str, limit: int = 3) -> list[dict]:
    query = query.strip()
    if not query:
        return []
    limit = max(1, min(MAX_RESULTS, int(limit)))
    terms = _terms(query)
    if not terms:
        return []
    normalized = query.lower().strip()

    scored: list[tuple[float, dict]] = []
    for item in load_exercises():
        text = _search_text(item)
        score = sum(1 for term in terms if term in text)
        if not score:
            continue
        name_zh = str(item.get("name_zh") or "").lower()
        name_en = str(item.get("name_en") or "").lower()
        if normalized in name_zh or normalized in name_en:
            score += 6
        if query in str(item.get("aliases") or []):
            score += 4
        # Prefer common exercises when the match is otherwise tied.
        rank = item.get("common_rank")
        if isinstance(rank, int):
            score += max(0, 2 - rank / 20)
        scored.append((score, item))

    scored.sort(key=lambda pair: (-pair[0], pair[1].get("common_rank", 999)))
    results: list[dict] = []
    for _, item in scored[:limit]:
        steps = item.get("steps_zh") or []
        if not isinstance(steps, list):
            steps = [str(steps)]
        results.append(
            {
                "name_zh": item.get("name_zh"),
                "name_en": item.get("name_en"),
                "aliases": item.get("aliases") or [],
                "body_part_zh": item.get("body_part_zh"),
                "equipment_zh": item.get("equipment_zh"),
                "target_zh": item.get("target_zh"),
                "steps_zh": steps[:MAX_STEPS],
                "common_rank": item.get("common_rank"),
                "source": item.get("source"),
                "license": item.get("license"),
                "safety_note": item.get("safety_note"),
            }
        )
    return results


def search_exercise_payload(query: str, limit: int = 3) -> dict:
    results = search_exercises(query, limit)
    if not results:
        return {
            "ok": False,
            "error": "没有找到匹配动作；请让用户补充动作名称或器械。",
            "query": query,
        }
    return {"ok": True, "query": query, "exercises": results}
