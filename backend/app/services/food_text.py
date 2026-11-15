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
from functools import lru_cache
from zoneinfo import ZoneInfo

from ..config import settings
from . import llm
from .food_vision import FOODS
from .knowledge_search import food_names, lookup_food
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


MEAL_PATTERNS = [
    ("breakfast", r"早餐|早饭|早上|清晨"),
    ("lunch", r"午餐|午饭|中饭|中午|晌午"),
    ("snack", r"加餐|夜宵|宵夜|零食|下午茶|小吃"),
    ("dinner", r"晚餐|晚饭|晚上|傍晚|昨晚|夜里"),
]
MEAL_LABELS = {
    "breakfast": "早饭",
    "lunch": "午饭",
    "dinner": "晚饭",
    "snack": "加餐",
}


def parse_meal_mentions(text: str) -> list[str]:
    value = text.strip()
    found: list[tuple[int, str]] = []
    for meal, pattern in MEAL_PATTERNS:
        match = re.search(pattern, value)
        if match is not None:
            found.append((match.start(), meal))
    ordered: list[str] = []
    for _, meal in sorted(found, key=lambda item: item[0]):
        if meal not in ordered:
            ordered.append(meal)
    return ordered


def parse_meal(text: str) -> str | None:
    mentions = parse_meal_mentions(text)
    if not mentions:
        return None
    # "这是我今天的晚饭，中午吃了..." must stay dinner: the first meal
    # mention is the user's framing, not whichever enum we checked first.
    return mentions[0]


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
    "牛肉": "牛肉",
    "干蒸牛肉": "牛肉",
    "腊肠": "腊肠",
    "燕麦": "燕麦（干）",
    "燕麦片": "燕麦（干）",
    "冰美式": "美式咖啡",
    "美式": "美式咖啡",
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

# A "cup" of milk/coffee is not the same as a 500ml bubble tea cup. Keep the
# generic unit for drinks where a large cup is common, override the staples.
CUP_GRAMS = {
    "牛奶": 250.0,
    "豆浆": 250.0,
    "酸奶": 200.0,
    "美式咖啡": 350.0,
    "拿铁": 300.0,
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
    "燕麦（干）": 60.0,
    "鸡蛋": 50.0,
    "鸡胸肉": 150.0,
    "牛肉": 120.0,
    "腊肠": 80.0,
    "美式咖啡": 350.0,
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
    "只输出 meal 这一餐的食物；用户提到其他餐时不要为其他餐生成 items 或 questions，"
    "系统会单独提醒用户稍后记录。"
    "主餐食物可以从 history 中取；当前句子只提到其他餐时，不要拿其他餐的食物充数。"
    "用户说‘这是我的晚饭/就刚刚说的/和刚才一样’时，如果 history 里已经有这餐的食物和份量，直接复用，不要留空。"
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
        r"(杯|份|碗|个|片|勺|盒|瓶|(?<!k)g|克|ml|毫升)",
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
        r"(\d+(?:\.\d+)?)\s*((?<!k)g|克|ml|毫升)",
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
        r"(杯|份|碗|个|片|勺|盒|瓶|(?<!k)g|克|ml|毫升)",
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
            r"(杯|份|碗|个|片|勺|盒|瓶|(?<!k)g|克|ml|毫升)",
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
    for name in _known_food_names():
        index = segment.find(name)
        if index < 0:
            continue
        after = segment[index + len(name) :]
        if after and after[0] in _PRODUCT_CHARS:
            combined = name + after[:2]
            if combined not in _known_food_set():
                # "牛筋" + "肉肠" is a different food, not 80g of beef tendon.
                continue
        return name, name
    return None


@lru_cache(maxsize=1)
def _known_food_names() -> tuple[str, ...]:
    return tuple(
        sorted(set(FOODS) | set(food_names()), key=lambda name: (-len(name), name))
    )


@lru_cache(maxsize=1)
def _known_food_set() -> set[str]:
    return set(_known_food_names())


_PRODUCT_CHARS = set("肠肉丸饼排脯干酱汁粉面饭汤包饺糕酥条片丝丁块串")


def _macros(base: str, grams: float) -> dict:
    per_100 = FOODS.get(base)
    if per_100 is None:
        item = lookup_food(base)
        if item is None:
            per_100 = (0.0, 0.0, 0.0, 0.0)
        else:
            per_100 = (
                item.get("kcal") or 0.0,
                item.get("protein_g") or 0.0,
                item.get("carbs_g") or 0.0,
                item.get("fat_g") or 0.0,
            )
    factor = grams / 100.0
    return {
        "kcal": round(per_100[0] * factor, 1),
        "protein_g": round(per_100[1] * factor, 1),
        "carbs_g": round(per_100[2] * factor, 1),
        "fat_g": round(per_100[3] * factor, 1),
    }


_PORTION_PATTERN = (
    r"(\d+(?:\.\d+)?|半|一|两|二|三|四|五|六|七|八|九|十)\s*"
    r"(杯|份|碗|个|片|勺|盒|瓶|(?<!k)g|克|ml|毫升)"
)


def _has_portion(segment: str) -> bool:
    return bool(re.search(_PORTION_PATTERN, segment, flags=re.IGNORECASE))


_DISCOURSE_ONLY = re.compile(
    r"我|刚刚|刚才|就|说|的|这|那|是|今天|昨天|前天|早上|中午|晚上|"
    r"早餐|午餐|晚餐|加餐|夜宵|零食|吃|喝|了|和|跟|一样|上面|照片|里|"
    r"顿|餐|饭|菜|还有|另外|帮我|记|一下|记录|补|到|去|吧|呢|啊|呀|哦|嗯|好|"
    r"大概|大约|左右|差不多|晚|早"
)


def _is_pure_discourse(segment: str) -> bool:
    value = _DISCOURSE_ONLY.sub("", segment).strip(" ，,、。;；!！?？+")
    return not value


def _is_food_segment(segment: str) -> bool:
    """Only ask about segments that actually mention food or a portion.

    Before this guard, "这是我今天的晚饭" and "就我刚刚说的" became unknown
    foods, so the coach asked the same nonsense question on every retry.
    """
    if _is_pure_discourse(segment):
        return False
    if _match_food(segment) is not None:
        return True
    if _has_portion(segment):
        return True
    return bool(
        re.search(
            r"鸡|牛|猪|鱼|虾|蛋|奶|饭|面|肠|肉|菜|果|豆|薯|饼|粥|汤|"
            r"咖啡|茶|酒|水|汁|粉|包|饺|燕麦|美式|腊肠|干蒸|食|物",
            segment,
        )
    )


def _food_segments(text: str) -> list[str]:
    segments: list[str] = []
    for chunk in re.split(r"[，,、;；。！!？?\n+＋]+", text):
        for part in re.split(r"(?:和|跟|还有|以及|外加)", chunk):
            part = part.strip()
            if not part:
                continue
            # "两个鸡蛋一杯牛奶" has no punctuation. Split before a second
            # portion when both sides resolve to a food, so the first portion
            # is not paired with the second food.
            matches = list(re.finditer(_PORTION_PATTERN, part, flags=re.IGNORECASE))
            if len(matches) <= 1:
                segments.append(part)
                continue
            start = 0
            for match in matches[1:]:
                left = part[start : match.start()].strip()
                right = part[match.start() :].strip()
                if left and right and _match_food(left) and _match_food(right):
                    segments.append(left)
                    start = match.start()
            segments.append(part[start:].strip())
    return [segment for segment in segments if segment]


def meal_analysis(text: str) -> dict:
    """Return the meal with actual food plus every meal mentioned.

    "这是我今天的晚饭，中午吃了300g燕麦" mentions dinner first but only the
    lunch clause contains food. Logging the oats as dinner would be silently
    wrong, so explicit food wins over the first mention.
    """
    mentions = parse_meal_mentions(text)
    explicit: list[str] = []
    for clause in re.split(r"[，,。；;\n]+", text):
        meal = parse_meal(clause)
        if meal is None:
            continue
        if (
            any(_is_food_segment(segment) for segment in _food_segments(clause))
            and meal not in explicit
        ):
            explicit.append(meal)
    return {
        "meal": mentions[0] if mentions else None,
        "mentions": mentions,
        "explicit": explicit,
    }


def resolve_food_rules(text: str) -> FoodResolution:
    """Rule-only resolution, also used by tests without an LLM."""
    segments = _food_segments(text)
    items: list[dict] = []
    questions: list[str] = []
    missing_slots: list[dict] = []

    for segment in segments:
        if not _is_food_segment(segment):
            continue
        matched = _match_food(segment)
        if matched is None:
            questions.append(_unknown_food_question(segment))
            continue
        display_name, base = matched
        grams, portion_text = _portion(segment)
        explicit_portion = grams is not None
        if grams is None:
            grams = DEFAULT_GRAMS.get(base)
            if grams is None:
                item = lookup_food(base)
                grams = (
                    float(item["serving_g"])
                    if item and item.get("serving_g")
                    else 200.0
                )
        elif portion_text and "杯" in portion_text and base in CUP_GRAMS:
            grams = CUP_GRAMS[base] * (grams / PORTION_UNITS["杯"])
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
                "explicit_portion": bool(portion_text),
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
        _canonical_food_name(item.get("name") or ""): index
        for index, item in enumerate(items)
    }
    for item in rules.items:
        key = _canonical_food_name(item.get("name") or "")
        if key and key in indexes:
            existing = items[indexes[key]]
            implicit = str(item.get("portion") or "").startswith("约")
            rule_grams = float(item.get("grams") or 0)
            llm_grams = float(existing.get("grams") or 0)
            if not implicit:
                # Explicit grams in the current text are deterministic.
                items[indexes[key]] = dict(item)
            elif rule_grams > 0 and llm_grams > 0 and abs(llm_grams - rule_grams) > 1:
                # The rule table has accurate macros but only a default
                # portion. Let the model's context-aware grams win and scale
                # the table macros to it.
                scaled = dict(item)
                ratio = llm_grams / rule_grams
                scaled["grams"] = round(llm_grams)
                scaled["portion"] = existing.get("portion") or f"约{round(llm_grams)}g"
                for macro in (
                    "kcal",
                    "protein_g",
                    "carbs_g",
                    "fat_g",
                    "fiber_g",
                ):
                    if scaled.get(macro) is not None:
                        scaled[macro] = round(float(scaled[macro]) * ratio, 1)
                scaled["confidence"] = max(
                    float(item.get("confidence") or 0),
                    float(existing.get("confidence") or 0),
                )
                items[indexes[key]] = scaled
            else:
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
    missing_slots = [dict(slot) for slot in llm_result.missing_slots]
    missing_names = {
        str(items[int(slot.get("item_index") or 0)].get("name") or "").strip().lower()
        for slot in missing_slots
        if 0 <= int(slot.get("item_index") or 0) < len(items)
    }
    for index, rule_item in enumerate(rules.items):
        name = str(rule_item.get("name") or "").strip().lower()
        if not name or name in missing_names:
            continue
        merged = next(
            (
                candidate
                for candidate in items
                if str(candidate.get("name") or "").strip().lower() == name
            ),
            None,
        )
        if merged is None:
            continue
        # A rule default ("约500g") is not a real answer. Keep asking unless
        # the current turn supplied an explicit portion or the model's
        # context-aware grams clearly differ from the default.
        explicit = bool(merged.get("explicit_portion"))
        grams_changed = abs(
            float(merged.get("grams") or 0) - float(rule_item.get("grams") or 0)
        ) > 1
        if explicit or grams_changed:
            continue
        for slot in rules.missing_slots:
            if int(slot.get("item_index") or 0) == index:
                missing_slots.append(dict(slot))
                missing_names.add(name)
                break
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


def rule_resolution_by_meal(text: str) -> dict[str, FoodResolution]:
    """Associate deterministic food matches with the meal they belong to.

    Commas are clause boundaries, but a clause without its own meal label
    inherits the previous one ("晚饭吃了米饭，鸡胸肉").
    """
    groups: dict[str, FoodResolution] = {}
    current_meal: str | None = None
    for clause in re.split(r"[，,。；;\n]+", text):
        clause = clause.strip()
        if not clause:
            continue
        meal = parse_meal(clause)
        if meal is not None:
            current_meal = meal
        if current_meal is None:
            continue
        resolution = resolve_food_rules(clause)
        if not resolution.items and not resolution.questions:
            continue
        existing = groups.get(current_meal)
        if existing is None:
            groups[current_meal] = resolution
            continue
        existing.items.extend(resolution.items)
        existing.questions.extend(resolution.questions)
        existing.missing_slots.extend(resolution.missing_slots)
    return groups


def _canonical_food_name(name: str) -> str:
    value = str(name or "").strip().lower()
    if not value:
        return ""
    for alias in sorted(ALIASES, key=len, reverse=True):
        if value == alias or alias in value:
            return ALIASES[alias].lower()
    for base in sorted(FOODS, key=len, reverse=True):
        if value == base or base in value or value in base:
            return base.lower()
    for base in food_names():
        if value == base or base in value or value in base:
            return base.lower()
    return value


def _draft_item_map(draft: dict | None) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for item in (draft or {}).get("items") or []:
        if not isinstance(item, dict):
            continue
        name = _canonical_food_name(item.get("name") or "")
        if name:
            result[name] = dict(item)
    return result


def _is_amount_only(text: str) -> bool:
    value = text.strip()
    if re.fullmatch(r"\d+(?:\.\d+)?", value):
        return True
    stripped = re.sub(
        r"(\d+(?:\.\d+)?|半|一|两|二|三|四|五|六|七|八|九|十)\s*"
        r"(杯|份|碗|个|片|勺|盒|瓶|(?<!k)g|克|ml|毫升)",
        "",
        value,
        flags=re.IGNORECASE,
    )
    return not _DISCOURSE_ONLY.sub("", stripped).strip(" ，,、。;；!！?？+")


def _apply_draft_amount(draft: dict | None, text: str) -> FoodResolution | None:
    items = [dict(item) for item in (draft or {}).get("items") or [] if isinstance(item, dict)]
    if not items:
        return None
    amount = parse_amount_grams(text)
    if amount is None:
        return None
    missing = [
        dict(item)
        for item in (draft or {}).get("missing_slots") or []
        if isinstance(item, dict)
    ]
    target_index = None
    if missing:
        target_index = int(missing[0].get("item_index") or 0)
    if target_index is None or target_index >= len(items):
        target_index = len(items) - 1
    item = items[target_index]
    old_grams = float(item.get("grams") or 0)
    ratio = amount / old_grams if old_grams > 0 else 1.0
    item["grams"] = round(amount)
    item["portion"] = f"{round(amount)}g"
    for macro_field in ("kcal", "protein_g", "carbs_g", "fat_g", "fiber_g"):
        if item.get(macro_field) is not None:
            item[macro_field] = round(float(item[macro_field]) * ratio, 1)
    missing = [slot for slot in missing if int(slot.get("item_index") or 0) != target_index]
    questions = [str(slot.get("question")) for slot in missing if slot.get("question")]
    return FoodResolution(
        items=items,
        questions=questions,
        missing_slots=missing,
        source="draft",
        confidence=0.8,
    )


def _merge_draft(
    result: FoodResolution,
    draft: dict | None,
) -> FoodResolution:
    items = [dict(item) for item in result.items]
    known = {_canonical_food_name(item.get("name") or "") for item in items}
    for name, item in _draft_item_map(draft).items():
        if name not in known:
            items.append(item)
            known.add(name)
    draft_missing = [
        dict(slot)
        for slot in (draft or {}).get("missing_slots") or []
        if isinstance(slot, dict)
    ]
    item_names = {
        _canonical_food_name(item.get("name") or "")
        for item in items
    }
    current_items = {
        _canonical_food_name(item.get("name") or "")
        for item in result.items
    }
    missing = [dict(slot) for slot in result.missing_slots]
    for slot in draft_missing:
        index = int(slot.get("item_index") or 0)
        draft_items = list((draft or {}).get("items") or [])
        name = (
            str(draft_items[index].get("name") or "").strip().lower()
            if 0 <= index < len(draft_items)
            else ""
        )
        # If the current turn produced a fresh estimate for that item, the
        # old missing-slot question is stale.
        if name and name in current_items:
            continue
        if name and name not in item_names:
            continue
        missing.append(slot)
    questions = list(result.questions)
    for slot in missing:
        question = str(slot.get("question") or "")
        if question and question not in questions:
            questions.append(question)
    if not items and not questions and draft:
        return FoodResolution(
            items=list((draft or {}).get("items") or []),
            questions=[],
            missing_slots=[],
            source="draft",
            confidence=float((draft or {}).get("confidence") or 0.6),
        )
    confidence = (
        round(sum(float(item.get("confidence") or 0) for item in items) / len(items), 2)
        if items
        else 0.0
    )
    return FoodResolution(
        items=items,
        questions=questions,
        missing_slots=missing,
        source=result.source,
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
    history_context: str | None = None,
    draft: dict | None = None,
    rule_resolution: FoodResolution | None = None,
    blocked_names: list[str] | None = None,
) -> dict:
    draft = draft or {}
    draft_items = [
        dict(item) for item in draft.get("items") or [] if isinstance(item, dict)
    ]
    if draft_items and _is_amount_only(text):
        applied = _apply_draft_amount(draft, text)
        if applied is not None:
            return applied.as_dict()

    rules = (
        rule_resolution
        if rule_resolution is not None
        else resolve_food_rules(text)
    )
    if (
        rules.items
        and not rules.questions
        and not rules.missing_slots
        and not history_context
        and not draft_items
    ):
        return rules.as_dict()
    if not rules.items and not rules.questions and rule_resolution is not None:
        rules = FoodResolution(
            questions=[f"{MEAL_LABELS.get(meal, meal)}吃了什么？"],
        )
    blocked = {
        _canonical_food_name(name)
        for name in (blocked_names or [])
        if _canonical_food_name(name)
    }
    if settings.use_mock_llm:
        return _merge_draft(rules, draft).as_dict()

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
                    "history": (history_context or "")[:5000],
                    "draft": {
                        "meal": draft.get("meal"),
                        "items": draft_items[:20],
                        "missing_slots": draft.get("missing_slots") or [],
                    },
                    "rules": [
                        "只输出用户说出的食物",
                        "每项给 grams、kcal、protein_g、carbs_g、fat_g",
                        "份量不确定时放进 questions，不要猜成很精确",
                        "用户说‘刚刚说的/上面那个/和刚才一样’时，从 history 中取食物和份量",
                        "用户说‘这是我的晚饭’时，从 history 中找这餐的食物，直接复用，不要留空",
                        "不要把‘这是我今天的晚饭/就我刚刚说的’当成食物名",
                        "只解析 meal 这一餐；其他餐不要放进 items 或 questions",
                        "已经有克数的食物只补缺失项，不要重复提问",
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
        if blocked:
            result.items = [
                item
                for item in result.items
                if _canonical_food_name(item.get("name") or "") not in blocked
            ]
        if not result.items and rule_resolution is not None:
            result.questions = [
                question
                for question in result.questions
                if "这道菜我还没有估算出来" not in question
            ]
        if not result.items and result.questions:
            rules.questions = result.questions + rules.questions
        if result.items:
            merged = _merge_resolutions(
                rules,
                result,
                keep_rule_questions=not prefer_llm,
            )
            return _merge_draft(merged, draft).as_dict()
    except Exception:  # noqa: BLE001 - resolution must degrade to a question
        pass
    return _merge_draft(rules, draft).as_dict()
