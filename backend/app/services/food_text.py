"""Text-to-food resolution for coach-authored diet logs.

Photo analysis already has a small nutrition table. This module adds deterministic
portion parsing first, then an LLM fallback for dishes the table cannot match. The
result is always an estimate that the user confirms before it becomes a FoodLog.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from ..config import settings
from . import llm
from .food_vision import FOODS
from .prompt_registry import prompt_version

DIET_TZ = ZoneInfo("Asia/Shanghai")


def _safe_float(value: object, default: float = 0.0) -> float:
    """Coerce model output such as ``"100g"`` or ``"1,000"`` without failing."""

    if isinstance(value, (int, float)):
        return float(value)
    if value is None:
        return default
    text = str(value).strip().replace(",", "")
    match = re.search(r"-?\d+(?:\.\d+)?", text)
    if match is None:
        return default
    try:
        return float(match.group(0))
    except ValueError:
        return default


def parse_meal(text: str) -> str | None:
    value = text.strip()
    if re.search(r"早餐|早饭|早上|清晨", value):
        return "breakfast"
    if re.search(r"午餐|午饭|中饭|中午|晌午", value):
        return "lunch"
    if re.search(r"加餐|夜宵|宵夜|零食|下午茶|小吃", value):
        return "snack"
    if re.search(r"晚餐|晚饭|晚上|傍晚|昨晚|夜里", value):
        return "dinner"
    return None


def _default_meal(now: datetime) -> str:
    hour = now.astimezone(DIET_TZ).hour
    if 5 <= hour < 11:
        return "breakfast"
    if 11 <= hour < 15:
        return "lunch"
    if 17 <= hour < 21:
        return "dinner"
    return "snack"


def parse_food_date(
    text: str,
    *,
    now: datetime | None = None,
) -> date | None:
    """Parse Chinese relative dates against the user's local day.

    ``date.today()`` on a UTC server is the previous day for a user at 01:39
    Beijing time, so every food write must use the profile timezone.
    """

    local = (now or datetime.now(DIET_TZ)).astimezone(DIET_TZ)
    today = local.date()
    value = text.strip()

    if re.search(r"前天", value):
        return today - timedelta(days=2)
    if re.search(r"昨天|昨日|昨晚", value):
        return today - timedelta(days=1)
    if re.search(r"明天|明日", value):
        return today + timedelta(days=1)
    if re.search(r"今天|今日|今晚", value):
        return today

    explicit = re.search(r"(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})", value)
    if explicit is not None:
        try:
            return date(
                int(explicit.group(1)),
                int(explicit.group(2)),
                int(explicit.group(3)),
            )
        except ValueError:
            return None

    month_day = re.search(r"(\d{1,2})月(\d{1,2})[日号]", value)
    if month_day is not None:
        try:
            return date(today.year, int(month_day.group(1)), int(month_day.group(2)))
        except ValueError:
            return None
    return None


def food_log_context(
    text: str,
    *,
    now: datetime | None = None,
) -> dict[str, str]:
    local = (now or datetime.now(DIET_TZ)).astimezone(DIET_TZ)
    parsed_date = parse_food_date(text, now=local) or local.date()
    parsed_meal = parse_meal(text) or _default_meal(local)
    return {"date": parsed_date.isoformat(), "meal": parsed_meal}


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

ASK_IMPLICIT_PORTION = {
    "奶茶",
    "可乐",
    "拿铁",
    "螺蛳粉",
    "麻辣香锅",
    "火锅",
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
    "只输出一个 JSON 对象，不要 Markdown、数组或解释。"
    "格式必须是："
    '{"items":[{"name":"食物名","grams":100,"kcal":200,'
    '"protein_g":10,"carbs_g":20,"fat_g":8,"confidence":0.7}],'
    '"questions":[]}。'
    "grams、kcal、protein_g、carbs_g、fat_g、confidence 必须是数字，不要带单位。"
    "饮料没有克数时用 volume_ml 表示毫升；不要省略份量。"
    "只有确实无法估算的食物才放进 questions，并说明缺少什么。"
)
_PROMPT_VERSION = prompt_version("food_text", _SYSTEM_PROMPT)


@dataclass
class FoodResolution:
    items: list[dict] = field(default_factory=list)
    questions: list[str] = field(default_factory=list)
    missing_slots: list[dict] = field(default_factory=list)
    source: str = "rules"
    confidence: float = 0.0

    def as_dict(self) -> dict:
        return {
            "items": self.items,
            "questions": self.questions,
            "missing_slots": self.missing_slots,
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


def parse_amount_grams(text: str) -> float | None:
    """Parse a short slot answer such as 250ml, 半杯 or just 250."""
    value = text.strip()
    match = re.search(
        r"(\d+(?:\.\d+)?)\s*(g|克|ml|毫升)",
        value,
        flags=re.IGNORECASE,
    )
    if match:
        return max(1.0, min(5000.0, float(match.group(1))))
    grams, _ = _portion(value)
    if grams is not None:
        return max(1.0, min(5000.0, grams))
    if re.fullmatch(r"\d+(?:\.\d+)?", value):
        return max(1.0, min(5000.0, float(value)))
    return None


def _unknown_food_name(segment: str) -> str:
    value = segment.strip()
    value = re.sub(
        r"^(我|刚刚|刚才|又|还|今天|昨天|前天|早上|中午|晚上|"
        r"早餐|午餐|晚餐|加餐|夜宵|零食|吃了|喝了|还有|另外|"
        r"帮我记到.*?去|帮我记|记录一下|记一下|补记)+",
        "",
        value,
    ).strip()
    value = re.sub(
        r"(\d+(?:\.\d+)?|半|一|两|二|三|四|五|六|七|八|九|十)\s*"
        r"(杯|份|碗|个|片|勺|盒|瓶|g|克|ml|毫升)",
        "",
        value,
        flags=re.IGNORECASE,
    ).strip(" ，,、。")
    return value or segment.strip()


def _unknown_food_question(segment: str) -> str:
    name = _unknown_food_name(segment)
    has_amount = bool(
        re.search(
            r"(\d+(?:\.\d+)?|半|一|两|二|三|四|五|六|七|八|九|十)\s*"
            r"(杯|份|碗|个|片|勺|盒|瓶|g|克|ml|毫升)",
            segment,
            flags=re.IGNORECASE,
        )
    )
    if name and has_amount:
        return (
            f"「{name}」我还不认识，能告诉我它的热量/蛋白质，"
            "或者说它像什么食物吗？"
        )
    return f"「{segment.strip()}」大概是什么食物、多少克？"


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
    missing_slots: list[dict] = []

    for segment in segments:
        matched = _match_food(segment)
        if matched is None:
            questions.append(_unknown_food_question(segment))
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
        if not explicit_portion and base in ASK_IMPLICIT_PORTION:
            missing_slots.append(
                {
                    "item_index": len(items) - 1,
                    "field": "grams",
                    "question": f"{display_name}大概多少量？",
                    "suggested_grams": round(grams),
                }
            )

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
        missing_slots=missing_slots,
        source="rules",
        confidence=confidence,
    )


def _normalize_llm_result(raw: dict | list) -> FoodResolution:
    if isinstance(raw, list):
        raw = {"items": raw}
    if not isinstance(raw, dict):
        raw = {}

    items = []
    raw_items = raw.get("items")
    if not isinstance(raw_items, list):
        raw_items = []
    for item in raw_items[:20]:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip()[:120]
        if not name:
            continue

        grams_value = item.get("grams")
        if grams_value is None:
            grams_value = item.get("volume_ml")
        grams = max(5.0, min(2000.0, _safe_float(grams_value, 0.0)))
        portion_text = str(item.get("portion") or "").strip()
        if grams <= 0:
            parsed_portion = parse_amount_grams(portion_text)
            grams = parsed_portion if parsed_portion is not None else 100.0
        grams = max(5.0, min(2000.0, grams))

        kcal = max(0.0, min(10000.0, _safe_float(item.get("kcal"), 0.0)))
        protein = max(0.0, min(1000.0, _safe_float(item.get("protein_g"), 0.0)))
        carbs = max(0.0, min(1000.0, _safe_float(item.get("carbs_g"), 0.0)))
        fat = max(0.0, min(1000.0, _safe_float(item.get("fat_g"), 0.0)))
        fiber = max(0.0, min(1000.0, _safe_float(item.get("fiber_g"), 0.0)))
        macro_kcal = protein * 4 + carbs * 4 + fat * 9
        if macro_kcal > 0 and (kcal <= 0 or abs(kcal - macro_kcal) / macro_kcal > 0.35):
            kcal = macro_kcal

        items.append(
            {
                "name": name,
                "portion": (portion_text or f"约{int(grams)}g")[:40],
                "grams": round(grams),
                "kcal": round(kcal, 1),
                "protein_g": round(protein, 1),
                "carbs_g": round(carbs, 1),
                "fat_g": round(fat, 1),
                "fiber_g": round(fiber, 1),
                "confidence": max(
                    0.0, min(1.0, _safe_float(item.get("confidence"), 0.55))
                ),
            }
        )

    questions = [
        str(value)[:120]
        for value in (raw.get("questions") or [])
        if str(value).strip()
    ][:3]
    missing_slots = [
        item
        for item in (raw.get("missing_slots") or [])
        if isinstance(item, dict)
    ]
    if not items and not questions:
        questions = ["这道菜我还没有估算出来，能告诉我它的份量和大概热量吗？"]
    confidence = (
        round(sum(item["confidence"] for item in items) / len(items), 2)
        if items
        else 0.0
    )
    return FoodResolution(
        items=items,
        questions=questions,
        missing_slots=missing_slots,
        source="llm",
        confidence=confidence,
    )


def _merge_resolutions(
    rules: FoodResolution,
    llm_result: FoodResolution,
    *,
    keep_rule_questions: bool = True,
) -> FoodResolution:
    """Keep deterministic matches and fill the unknown items with LLM estimates."""

    items = [dict(item) for item in llm_result.items]
    indexes = {
        str(item.get("name") or "").strip().lower(): index
        for index, item in enumerate(items)
    }
    for item in rules.items:
        key = str(item.get("name") or "").strip().lower()
        if key and key in indexes:
            # Keep the deterministic macro table for foods it already knows.
            items[indexes[key]] = dict(item)
        else:
            if key:
                indexes[key] = len(items)
            items.append(dict(item))
    # Keep the rule parser's questions only for foods the LLM did not cover.
    # This prevents a partial LLM answer from silently dropping an unknown
    # food, while allowing a complete 3-item answer to clear the draft.
    questions = list(llm_result.questions)

    def covered(name: str) -> bool:
        return any(
            name and item_name and (name in item_name or item_name in name)
            for item in items
            for item_name in [str(item.get("name") or "")]
        )

    if keep_rule_questions:
        for question in rules.questions:
            match = re.search(r"「([^」]+)」", question)
            target = _unknown_food_name(match.group(1)) if match else ""
            if target and not covered(target) and question not in questions:
                questions.append(question)
    missing_slots = llm_result.missing_slots
    confidence = (
        round(sum(float(item.get("confidence") or 0) for item in items) / len(items), 2)
        if items
        else 0.0
    )
    return FoodResolution(
        items=items,
        questions=questions,
        missing_slots=missing_slots,
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
    prefer_llm: bool = False,
) -> dict:
    rules = resolve_food_rules(text)
    if rules.items and not rules.questions and not rules.missing_slots:
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
                    "date": (
                        target_date or datetime.now(DIET_TZ).date()
                    ).isoformat(),
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
            return _merge_resolutions(
                rules,
                result,
                keep_rule_questions=not prefer_llm,
            ).as_dict()
    except Exception:  # noqa: BLE001 - resolution must degrade to a question
        pass
    return rules.as_dict()
