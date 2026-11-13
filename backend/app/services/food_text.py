"""Text-to-food resolution for coach-authored diet logs.

Photo analysis already has a small nutrition table. This module adds deterministic
portion parsing first, then an LLM fallback for dishes the table cannot match. The
result is always an estimate that the user confirms before it becomes a FoodLog.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from datetime import date

from ..config import settings
from . import llm
from .food_vision import FOODS
from .prompt_registry import prompt_version

# Common Chinese dish aliases. The key is what the user says; the value is the
# nutrition-table key used for per-100g macros.
ALIASES = {
    "湿炒螺蛳粉": "螺蛳粉",
    "炒螺蛳粉": "螺蛳粉",
    "螺蛳粉": "螺蛳粉",
    "桂林米粉": "螺蛳粉",
    "奶茶": "奶茶",
    "珍珠奶茶": "奶茶",
    "米饭": "米饭",
    "白米饭": "米饭",
    "糙米饭": "糙米饭",
    "鸡胸肉": "鸡胸肉",
    "鸡蛋": "鸡蛋",
    "水煮蛋": "鸡蛋",
    "煎蛋": "鸡蛋",
    "牛奶": "牛奶",
    "豆腐": "豆腐",
    "西兰花": "西兰花",
    "香蕉": "香蕉",
    "牛油果": "牛油果",
    "坚果": "坚果",
    "炸鸡": "炸鸡",
    "可乐": "可乐",
    "麻辣香锅": "麻辣香锅",
    "火锅": "火锅",
    "烧烤": "烧烤",
}

PORTION_UNITS = {
    "杯": 500.0,
    "份": 500.0,
    "碗": 350.0,
    "个": 50.0,
    "片": 30.0,
    "勺": 15.0,
    "盒": 250.0,
    "瓶": 500.0,
    "g": 1.0,
    "克": 1.0,
    "ml": 1.0,
    "毫升": 1.0,
}

NUMBER_WORDS = {
    "半": 0.5,
    "一": 1.0,
    "两": 2.0,
    "二": 2.0,
    "三": 3.0,
    "四": 4.0,
    "五": 5.0,
    "六": 6.0,
    "七": 7.0,
    "八": 8.0,
    "九": 9.0,
    "十": 10.0,
}

DEFAULT_GRAMS = {
    "螺蛳粉": 500.0,
    "奶茶": 500.0,
    "米饭": 150.0,
    "糙米饭": 150.0,
    "鸡蛋": 50.0,
    "鸡胸肉": 150.0,
    "牛奶": 250.0,
    "豆腐": 150.0,
    "西兰花": 200.0,
    "香蕉": 120.0,
    "牛油果": 80.0,
}

_SYSTEM_PROMPT = (
    "你是中文饮食记录解析器。只估算用户明确说出的食物和份量；"
    "不要把没提到的食物加进来。按熟食、常见中式份量估算。"
    "只输出一个 JSON 对象，不要 Markdown。"
)
_PROMPT_VERSION = prompt_version("food_text", _SYSTEM_PROMPT)


@dataclass
class FoodResolution:
    items: list[dict] = field(default_factory=list)
    questions: list[str] = field(default_factory=list)
    source: str = "rules"
    confidence: float = 0.0

    def as_dict(self) -> dict:
        return {
            "items": self.items,
            "questions": self.questions,
            "source": self.source,
            "confidence": round(self.confidence, 2),
        }


def _number(value: str) -> float | None:
    if value in NUMBER_WORDS:
        return NUMBER_WORDS[value]
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _portion(segment: str) -> tuple[float | None, str | None]:
    match = re.search(
        r"(\d+(?:\.\d+)?|半|一|两|二|三|四|五|六|七|八|九|十)\s*"
        r"(杯|份|碗|个|片|勺|盒|瓶|g|克|ml|毫升)",
        segment,
        flags=re.IGNORECASE,
    )
    if match is None:
        return None, None
    amount = _number(match.group(1))
    unit = match.group(2).lower()
    if amount is None or unit not in PORTION_UNITS:
        return None, None
    return amount * PORTION_UNITS[unit], match.group(0)


def _match_food(segment: str) -> tuple[str, str] | None:
    for alias in sorted(ALIASES, key=len, reverse=True):
        if alias in segment:
            return alias, ALIASES[alias]
    for name in sorted(FOODS, key=len, reverse=True):
        if name in segment:
            return name, name
    return None


def _macros(base: str, grams: float) -> dict:
    per_100 = FOODS[base]
    factor = grams / 100.0
    return {
        "kcal": round(per_100[0] * factor, 1),
        "protein_g": round(per_100[1] * factor, 1),
        "carbs_g": round(per_100[2] * factor, 1),
        "fat_g": round(per_100[3] * factor, 1),
    }


def resolve_food_rules(text: str) -> FoodResolution:
    """Rule-only resolution, also used by tests without an LLM."""
    segments = [
        segment.strip()
        for segment in re.split(r"[，,、;；。！!？?\n]+", text)
        if segment.strip()
    ]
    items: list[dict] = []
    questions: list[str] = []

    for segment in segments:
        matched = _match_food(segment)
        if matched is None:
            questions.append(f"「{segment}」大概是什么食物、多少克？")
            continue
        display_name, base = matched
        grams, portion_text = _portion(segment)
        explicit_portion = grams is not None
        if grams is None:
            grams = DEFAULT_GRAMS.get(base, 200.0)
        grams = max(5.0, min(2000.0, grams))
        item = {
            "name": display_name,
            "portion": portion_text or f"约{int(grams)}g",
            "grams": round(grams),
            **_macros(base, grams),
            "confidence": 0.72 if explicit_portion else 0.55,
        }
        items.append(item)

    if items and questions:
        # Keep partial matches; the app can confirm what it understood and ask
        # about the rest instead of blocking the whole log.
        pass
    confidence = (
        round(sum(item["confidence"] for item in items) / len(items), 2)
        if items
        else 0.0
    )
    return FoodResolution(
        items=items,
        questions=questions,
        source="rules",
        confidence=confidence,
    )


def _normalize_llm_result(raw: dict) -> FoodResolution:
    items = []
    for item in (raw.get("items") or [])[:20]:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip()[:120]
        if not name:
            continue
        grams = max(5.0, min(2000.0, float(item.get("grams") or 0)))
        kcal = max(0.0, min(10000.0, float(item.get("kcal") or 0)))
        protein = max(0.0, min(1000.0, float(item.get("protein_g") or 0)))
        carbs = max(0.0, min(1000.0, float(item.get("carbs_g") or 0)))
        fat = max(0.0, min(1000.0, float(item.get("fat_g") or 0)))
        macro_kcal = protein * 4 + carbs * 4 + fat * 9
        if macro_kcal > 0 and (kcal <= 0 or abs(kcal - macro_kcal) / macro_kcal > 0.35):
            kcal = macro_kcal
        items.append(
            {
                "name": name,
                "portion": str(item.get("portion") or f"约{int(grams)}g")[:40],
                "grams": round(grams),
                "kcal": round(kcal, 1),
                "protein_g": round(protein, 1),
                "carbs_g": round(carbs, 1),
                "fat_g": round(fat, 1),
                "confidence": max(
                    0.0, min(1.0, float(item.get("confidence") or 0.55))
                ),
            }
        )
    questions = [
        str(value)[:120]
        for value in (raw.get("questions") or [])
        if str(value).strip()
    ][:3]
    confidence = (
        round(sum(item["confidence"] for item in items) / len(items), 2)
        if items
        else 0.0
    )
    return FoodResolution(
        items=items,
        questions=questions,
        source="llm",
        confidence=confidence,
    )


async def resolve_food_text(
    db,
    user_id: str,
    text: str,
    *,
    meal: str = "lunch",
    target_date: date | None = None,
) -> dict:
    rules = resolve_food_rules(text)
    if rules.items:
        return rules.as_dict()
    if settings.use_mock_llm:
        return rules.as_dict()

    usage: dict[str, int] = {}
    try:
        raw = await llm.complete_json(
            _SYSTEM_PROMPT,
            json.dumps(
                {
                    "text": text,
                    "meal": meal,
                    "date": (target_date or date.today()).isoformat(),
                    "known_foods": sorted(FOODS),
                    "rules": [
                        "只输出用户说出的食物",
                        "每项给 grams、kcal、protein_g、carbs_g、fat_g",
                        "份量不确定时放进 questions，不要猜成很精确",
                    ],
                },
                ensure_ascii=False,
            ),
            reasoning_effort="low",
            usage=usage,
            db=db,
            user_id=user_id,
            kind="food_text",
            prompt_version=_PROMPT_VERSION,
        )
        result = _normalize_llm_result(raw)
        if result.items:
            return result.as_dict()
    except Exception:  # noqa: BLE001 - resolution must degrade to a question
        pass
    return rules.as_dict()
