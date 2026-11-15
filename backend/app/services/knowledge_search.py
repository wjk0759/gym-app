"""Lexical retrieval over the coach and equipment knowledge bases.

Food nutrition was deliberately removed: it is not used by the vision model and
its 2015 regional composition values did not survive answer-level evaluation.
The remaining domains are:

- ``coach``: exercise technique, posture, training principles, nutrition, safety
- ``equipment``: gym equipment, muscles and visual recognition cues

The lexical scorer is intentionally shared with ``exercise_search.py`` in
spirit, but the corpus is split by domain so a coach answer cannot outrank an
equipment explanation. When BGE-M3 or another embedding model is approved, it
can be added behind this interface without changing callers.
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
}


def _norm(value: str) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


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
    return {
        "id": item.get("id"),
        "domain": item.get("domain"),
        "title": item.get("title"),
        "kind": item.get("kind"),
        "aliases": (item.get("aliases") or [])[:8],
        "text": str(item.get("text") or "")[:MAX_TEXT],
        "source": item.get("source"),
        "source_url": item.get("source_url"),
        "license": item.get("license"),
    }


def search_knowledge(
    query: str,
    *,
    domain: str | None = None,
    limit: int = 3,
    include_exercises: bool = False,
) -> list[dict[str, Any]]:
    """Return the most relevant records for a query and optional domain.

    Exercise technique cards are excluded by default so ``lookup_exercise``
    remains the single source for movement steps. Set ``include_exercises`` for
    offline analysis that explicitly wants the raw coach corpus.
    """

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
            if (
                current == "coach"
                and not include_exercises
                and item.get("kind") == "exercise"
            ):
                continue
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
            "error": "没有找到匹配知识；请让用户补充动作、体态或器械名称。",
            "query": query,
            "domain": domain,
        }
    return {
        "ok": True,
        "query": query,
        "domain": domain,
        "results": results,
    }
