"""Lexical retrieval over the audited coach knowledge bases.

This is the first RAG baseline: no vector store, no network calls. Each module
can ask for its own domain and receive compact, source-attributed records:

- ``coach``: exercise technique, posture, training principles, nutrition, safety
- ``food``: per-100g Chinese food composition
- ``equipment``: gym equipment, muscles and visual recognition cues

The food-category taxonomy was deliberately removed: it is for a future
user-facing food picker, not for the vision model or coach RAG.

The lexical scorer is intentionally shared with ``exercise_search.py`` in
spirit, but the corpus is split by domain so a food query cannot outrank a
coach answer. When BGE-M3 or another embedding model is approved, it can be
added behind this interface without changing callers.
"""

from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path
from typing import Any

DATA_DIR = Path(__file__).resolve().parents[2] / "data" / "knowledge"
MAX_RESULTS = 5
MAX_TEXT = 900

DOMAIN_FILES = {
    "coach": "coach_knowledge.jsonl",
    "food": "food_nutrition.jsonl",
    "equipment": "equipment_knowledge.jsonl",
}
DOMAINS = tuple(DOMAIN_FILES)

STOP_TERMS = {
    "怎么",
    "如何",
    "什么",
    "多少",
    "可以",
    "需要",
    "一下",
    "这个",
    "那个",
    "请问",
    "帮我",
    "告诉",
    "一个",
    "保持",
    "注意",
    "区别",
    "辨认",
    "属于",
    "高吗",
    "怎么办",
    "么办",
    "的",
    "吗",
    "呢",
}

QUERY_SYNONYMS = {
    "肩膀疼": ("肩痛", "肩部"),
    "肩膀痛": ("肩痛", "肩部"),
    "膝盖疼": ("膝痛", "膝盖"),
    "膝盖痛": ("膝痛", "膝盖"),
    "腰背": ("腰痛", "背部"),
    "腰疼": ("腰痛",),
    "脖子疼": ("颈痛", "颈部"),
    "卡路里": ("热量", "kcal"),
    "蛋白质": ("蛋白",),
}


def _norm(value: str) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def _norm_key(value: str) -> str:
    text = _norm(value).lower()
    text = re.sub(r"[（(].*?[）)]", "", text)
    text = re.sub(r"[^0-9a-z\u4e00-\u9fff]+", "", text)
    return text


@lru_cache(maxsize=8)
def load_domain(domain: str) -> tuple[dict[str, Any], ...]:
    if domain not in DOMAIN_FILES:
        return ()
    path = DATA_DIR / DOMAIN_FILES[domain]
    if not path.exists():
        return ()
    rows: list[dict[str, Any]] = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(item, dict) and item.get("title"):
                rows.append(item)
    return tuple(rows)


def _terms(text: str) -> set[str]:
    terms: set[str] = set()
    for word in re.findall(r"[a-z0-9]+|[\u4e00-\u9fff]+", text.lower()):
        if re.fullmatch(r"[a-z0-9]+", word):
            if len(word) >= 2 and word not in STOP_TERMS:
                terms.add(word)
            continue
        for size in (2, 3, 4):
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
            str(item.get("title") or ""),
            " ".join(str(alias) for alias in aliases),
            str(item.get("category") or ""),
            str(item.get("search_text") or ""),
        ]
    ).lower()


def _compact(item: dict[str, Any]) -> dict[str, Any]:
    domain = item.get("domain")
    if domain == "food":
        parts = [
            f"{item['title']}（每 100g）",
            f"{item.get('kcal')} kcal",
            f"蛋白质 {item.get('protein_g')}g",
            f"脂肪 {item.get('fat_g')}g",
            f"碳水 {item.get('carbs_g')}g",
        ]
        if item.get("fiber_g") is not None:
            parts.append(f"膳食纤维 {item.get('fiber_g')}g")
        if item.get("sodium_mg") is not None:
            parts.append(f"钠 {item.get('sodium_mg')}mg")
        parts.append(f"默认份量约 {item.get('serving_g')}g")
        text = "，".join(parts)
    else:
        text = str(item.get("text") or "")
    return {
        "id": item.get("id"),
        "domain": domain,
        "title": item.get("title"),
        "kind": item.get("kind"),
        "aliases": (item.get("aliases") or [])[:8],
        "text": text[:MAX_TEXT],
        "source": item.get("source"),
        "source_url": item.get("source_url"),
        "license": item.get("license"),
    }


def search_knowledge(
    query: str,
    *,
    domain: str | None = None,
    limit: int = 3,
) -> list[dict[str, Any]]:
    """Return the most relevant records for a query and optional domain."""

    query = _norm(query)
    if not query:
        return []
    limit = max(1, min(MAX_RESULTS, int(limit)))
    expanded = query
    for phrase, synonyms in QUERY_SYNONYMS.items():
        if phrase in query:
            expanded += " " + " ".join(synonyms)
    terms = _terms(expanded)
    if not terms:
        return []
    normalized = query.lower()
    domains = [domain] if domain in DOMAIN_FILES else list(DOMAINS)

    scored: list[tuple[float, int, dict[str, Any]]] = []
    for current in domains:
        for item in load_domain(current):
            text = _search_text(item)
            score = sum(1 for term in terms if term in text)
            if not score:
                continue
            title = str(item.get("title") or "").lower()
            aliases = " ".join(str(alias) for alias in item.get("aliases") or []).lower()
            title_text = f"{title} {aliases}"
            # A term in the title or alias is much stronger evidence than the
            # same term buried in a long exercise description.
            score += sum(2 for term in terms if term in title_text)
            if normalized == title:
                score += 12
            elif normalized in title:
                score += 6
            if normalized in aliases:
                score += 4
            if current == "food":
                score += float(item.get("quality") or 0.5)
                if "平均值" in title or "取样" in title:
                    score -= 0.5
            if current == "coach" and item.get("kind") == "exercise":
                score += 0.3
            scored.append((score, len(str(item.get("title") or "")), item))

    scored.sort(key=lambda row: (-row[0], row[1]))
    results: list[dict[str, Any]] = []
    seen: set[str] = set()
    for _, _, item in scored:
        item_id = str(item.get("id") or item.get("title"))
        if item_id in seen:
            continue
        seen.add(item_id)
        results.append(_compact(item))
        if len(results) >= limit:
            break
    return results


def knowledge_payload(
    query: str,
    *,
    domain: str | None = None,
    limit: int = 3,
) -> dict[str, Any]:
    results = search_knowledge(query, domain=domain, limit=limit)
    if not results:
        return {
            "ok": False,
            "error": "没有找到匹配知识；请让用户补充食物、动作、体态或器械名称。",
            "query": query,
            "domain": domain,
        }
    return {
        "ok": True,
        "query": query,
        "domain": domain,
        "results": results,
    }


@lru_cache(maxsize=1)
def _food_index() -> dict[str, list[dict[str, Any]]]:
    index: dict[str, list[dict[str, Any]]] = {}
    for item in load_domain("food"):
        names = [str(item.get("title") or "")]
        names.extend(str(alias) for alias in item.get("aliases") or [])
        for name in names:
            key = _norm_key(name)
            if len(key) < 2:
                continue
            index.setdefault(key, []).append(item)
    return index


@lru_cache(maxsize=1)
def food_names() -> tuple[str, ...]:
    """All food names and aliases, longest first for deterministic matching."""

    names: set[str] = set()
    for item in load_domain("food"):
        for name in [item.get("title"), *(item.get("aliases") or [])]:
            name = _norm(name)
            if len(name) >= 2:
                names.add(name)
    return tuple(sorted(names, key=lambda name: (-len(name), name)))


def lookup_food(name: str) -> dict[str, Any] | None:
    """Resolve a food name to per-100g macros for deterministic diet logging."""

    key = _norm_key(name)
    if len(key) < 2:
        return None
    candidates = list(_food_index().get(key) or [])
    if not candidates:
        # Fall back to substring matching, longest name first, so "鸡胸肉"
        # resolves "去皮鸡胸肉(肉鸡)" when the exact label is absent. Reject
        # names that add a different food noun ("鸡腿" must not become "鸡腿菇").
        other_food_tokens = (
            "菇",
            "菜",
            "果",
            "汁",
            "酱",
            "餅",
            "饼",
            "糕",
            "面",
            "饭",
            "汤",
            "丸",
            "松",
            "零食",
            "饮料",
            "酒",
            "茶",
            "咖啡",
        )
        for candidate in food_names():
            candidate_key = _norm_key(candidate)
            if key not in candidate_key:
                continue
            if any(
                token in candidate_key and token not in key
                for token in other_food_tokens
            ):
                continue
            candidates.extend(_food_index().get(candidate_key) or [])
            # Keep scanning: two records can share a prefix ("去皮/带皮鸡胸肉");
            # ranking below decides which is the better default.
    if not candidates:
        return None

    unique: dict[str, dict[str, Any]] = {}
    for item in candidates:
        unique[str(item.get("id") or item.get("title"))] = item
    candidates = list(unique.values())

    def rank(item: dict[str, Any]) -> tuple:
        title = str(item.get("title") or "")
        exact = _norm_key(title) == key
        processed = any(
            token in title
            for token in (
                "松",
                "罐头",
                "罐頭",
                "酱",
                "醬",
                "丸",
                "饼",
                "餅",
                "汤",
                "湯",
                "粉",
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
        noisy = any(token in title for token in ("取样",))
        representative = any(token in title for token in ("平均值", "代表值"))
        wants_light = any(
            token in _norm(name).lower()
            for token in ("脱脂", "低脂", "稀释", "无糖", "低热量")
        )
        light = any(
            token in title for token in ("脱脂", "低脂", "稀释", "低热量")
        )
        skin = 1 if "带皮" in title and "带皮" not in _norm(name) else 0
        return (
            0 if exact else 1,
            1 if processed else 0,
            1 if noisy else 0,
            0 if representative else 1,
            0 if wants_light or not light else 1,
            skin,
            -(float(item.get("quality") or 0)),
            len(title),
        )

    item = sorted(candidates, key=rank)[0]
    return {
        "name_zh": item.get("title"),
        "aliases": item.get("aliases") or [],
        "kcal": item.get("kcal"),
        "protein_g": item.get("protein_g"),
        "fat_g": item.get("fat_g"),
        "carbs_g": item.get("carbs_g"),
        "fiber_g": item.get("fiber_g"),
        "serving_g": item.get("serving_g"),
        "quality": item.get("quality"),
        "source": item.get("source"),
        "license": item.get("license"),
    }
