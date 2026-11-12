"""饮食照片识别：调用配置的视觉模型，失败时回退确定性结果。

隐私原则：
- 原图不落盘、不入库
- 只返回食物与营养估算
- 过敏原、疾病饮食必须以包装/商家/医生为准
"""

from __future__ import annotations

import base64
import hashlib
import logging
from contextlib import suppress

from sqlalchemy.orm import Session

from ..config import settings
from . import llm
from .prompt_registry import prompt_version

logger = logging.getLogger(__name__)

DISCLAIMER = "估算值，份量与营养可能有偏差；过敏原以包装标签或商家确认为准。"

# 每 100g: (kcal, protein, carbs, fat)
FOODS = {
    "米饭": (116, 2.6, 25.9, 0.3),
    "糙米饭": (111, 2.6, 23.0, 0.9),
    "燕麦（干）": (367, 15.0, 61.0, 6.7),
    "全麦面包": (247, 13.0, 41.0, 3.4),
    "鸡胸肉": (133, 24.0, 0.0, 5.0),
    "鸡蛋": (143, 13.0, 1.0, 10.0),
    "三文鱼": (208, 20.0, 0.0, 13.0),
    "豆腐": (76, 8.0, 2.0, 5.0),
    "牛奶": (54, 3.0, 5.0, 3.0),
    "西兰花": (34, 2.8, 7.0, 0.4),
    "生菜": (15, 1.4, 2.9, 0.2),
    "番茄": (18, 0.9, 3.9, 0.2),
    "牛油果": (160, 2.0, 9.0, 15.0),
    "香蕉": (89, 1.1, 23.0, 0.3),
    "坚果": (600, 20.0, 20.0, 50.0),
    "螺蛳粉": (125, 5.5, 18.5, 3.5),
    "奶茶": (70, 1.0, 12.0, 2.3),
    "炸鸡": (280, 18.0, 10.0, 18.0),
    "可乐": (42, 0.0, 10.6, 0.0),
    "麻辣香锅": (180, 8.0, 10.0, 12.0),
    "火锅": (160, 9.0, 8.0, 10.0),
    "烧烤": (250, 18.0, 2.0, 19.0),
}

COMBOS = [
    [("米饭", 150), ("鸡胸肉", 150), ("西兰花", 150)],
    [("燕麦（干）", 60), ("鸡蛋", 100), ("牛奶", 250), ("香蕉", 100)],
    [("糙米饭", 150), ("三文鱼", 120), ("生菜", 100), ("番茄", 80)],
    [("全麦面包", 80), ("鸡蛋", 100), ("牛油果", 80)],
    [("米饭", 180), ("豆腐", 150), ("西兰花", 180)],
    [("螺蛳粉", 600), ("奶茶", 500)],
    [("炸鸡", 200), ("可乐", 500)],
    [("麻辣香锅", 400), ("米饭", 150)],
]


async def analyze(
    image_bytes: bytes,
    filename: str = "meal.jpg",
    *,
    db: Session | None = None,
    user_id: str | None = None,
) -> dict:
    if settings.use_mock_vision:
        return _mock_analyze(image_bytes, filename)
    usage: dict[str, int] = {}
    try:
        result = await llm.complete_vision_json(
            _SYSTEM_PROMPT,
            _USER_PROMPT,
            base64.b64encode(image_bytes).decode(),
            usage=usage,
            db=db,
            user_id=user_id,
            kind="food_vision",
            prompt_version=_PROMPT_VERSION,
        )
        return _normalize(result, filename)
    except Exception as exc:  # noqa: BLE001 - 识别失败回退本地估算，不让拍照功能崩溃
        logger.warning("food vision failed, fallback to mock: %s", exc)
        if db is not None:
            with suppress(Exception):
                llm.record_job(
                    db,
                    user_id,
                    kind="food_vision",
                    status="fallback",
                    model=settings.vision_model_name,
                    error=str(exc)[:500],
                    usage=usage,
                    prompt_version=_PROMPT_VERSION,
                )
        payload = _mock_analyze(image_bytes, filename)
        payload["warning"] = "视觉识别暂时不可用，已回退本地估算"
        return payload


_SYSTEM_PROMPT = (
    "你是严谨的饮食份量估算助手。先找画面中天然存在的参照物：盘子、碗、杯子、"
    "勺子、筷子、手、包装或饮料罐；再用参照物尺寸、食物覆盖面积、堆叠高度和"
    "食物密度估算份量。没有参照物时，按常见中式餐具和常见份量保守估算。"
    "不要假精确，必须给出克数区间和置信度。只输出一个 JSON 对象，不要解释。"
)
_PROMPT_VERSION = prompt_version("food_vision", _SYSTEM_PROMPT)

_USER_PROMPT = (
    '识别图片并输出 JSON：'
    '{"summary":"如实描述图片里有什么","is_food":true或false,'
    '"reference":{"type":"plate/bowl/utensil/hand/packaging/none",'
    '"estimated_cm":数字或null,"basis":"参照依据"},'
    '"items":[{"name":"食物名","grams":150,"grams_min":130,"grams_max":175,'
    '"portion_confidence":0.72,"portion_basis":"盘中覆盖约60%",'
    '"kcal":热量,"protein_g":蛋白质,"carbs_g":碳水,"fat_g":脂肪,"confidence":0.8}]}。'
    "规则：grams_min <= grams <= grams_max；区间必须覆盖真实份量。"
    "有明确参照物时范围约 ±15–20%；只有常见餐具/常见份量时约 ±20–30%；"
    "画面缺少参照物时约 ±30–40%，并降低 portion_confidence。"
    "参照物可用尺寸：普通餐盘 25–28cm，米饭碗 11–13cm/250–350ml，"
    "汤碗 15–18cm，一次性勺子约 15ml，易拉罐 330ml，鸡蛋约 50g。"
    "熟米饭密度约 0.75–0.85 g/ml，面条 0.55–0.70，肉类 0.85，"
    "蔬菜 0.30–0.50，汤/饮品 1.0。要扣除骨头、壳、果皮和盘底汤汁。"
    "按熟食状态估算；分不清生熟时在 summary 说明。"
    "如果是非食物（木头、手、空盘、桌面、文字等），is_food 为 false，"
    "items 输出空数组，summary 如实说明。重量与营养都是估算值，只输出 JSON。"
)


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _round_grams(value: float) -> int:
    return int(round(_clamp(value, 5.0, 2000.0) / 5.0) * 5)


def _normalize(data: dict, filename: str) -> dict:
    reference = data.get("reference")
    if not isinstance(reference, dict):
        reference = {}
    reference_type = str(reference.get("type") or "none").lower()
    has_reference = reference_type not in {"", "none", "unknown"}
    reference_basis = str(reference.get("basis") or "")[:80]
    default_delta = 0.20 if has_reference else 0.35

    items = []
    total_kcal = total_protein = total_carbs = total_fat = 0.0
    for raw in data.get("items") or []:
        if not isinstance(raw, dict):
            continue
        name = str(raw.get("name") or "食物")[:24]
        grams_raw = _clamp(float(raw.get("grams") or 100), 5.0, 2000.0)
        min_raw = raw.get("grams_min")
        max_raw = raw.get("grams_max")
        if min_raw is None or max_raw is None:
            min_raw = grams_raw * (1 - default_delta)
            max_raw = grams_raw * (1 + default_delta)
        min_grams = _round_grams(float(min_raw))
        max_grams = _round_grams(float(max_raw))
        grams = _round_grams(grams_raw)
        min_grams = min(min_grams, grams)
        max_grams = max(max_grams, grams)
        if max_grams - min_grams < 5:
            min_grams = max(5, grams - 5)
            max_grams = min(2000, grams + 5)

        kcal = float(raw.get("kcal") or 0)
        protein = _clamp(float(raw.get("protein_g") or 0), 0, 500)
        carbs = _clamp(float(raw.get("carbs_g") or 0), 0, 500)
        fat = _clamp(float(raw.get("fat_g") or 0), 0, 500)
        macro_kcal = protein * 4 + carbs * 4 + fat * 9
        if macro_kcal > 0 and (
            kcal <= 0 or abs(kcal - macro_kcal) / macro_kcal > 0.30
        ):
            kcal = macro_kcal
        kcal = _clamp(kcal, 0, 5000)

        portion_confidence = _clamp(
            float(raw.get("portion_confidence") or (0.6 if has_reference else 0.4)),
            0,
            1,
        )
        basis = str(
            raw.get("portion_basis")
            or reference_basis
            or ("按常见份量估算" if not has_reference else "按画面参照物估算")
        )[:80]

        items.append(
            {
                "name": name,
                "grams": grams,
                "grams_min": min_grams,
                "grams_max": max_grams,
                "portion_confidence": round(portion_confidence, 2),
                "portion_basis": basis,
                "kcal_per_100g": round(kcal / grams * 100),
                "protein_per_100g": round(protein / grams * 100, 1),
                "carbs_per_100g": round(carbs / grams * 100, 1),
                "fat_per_100g": round(fat / grams * 100, 1),
                "kcal": round(kcal),
                "protein_g": round(protein, 1),
                "carbs_g": round(carbs, 1),
                "fat_g": round(fat, 1),
                "confidence": round(
                    _clamp(float(raw.get("confidence") or 0.7), 0, 1), 2
                ),
            }
        )
        total_kcal += kcal
        total_protein += protein
        total_carbs += carbs
        total_fat += fat

    return {
        "summary": str(data.get("summary") or "")[:200],
        "is_food": bool(items),
        "reference": {
            "type": reference_type or "none",
            "basis": reference_basis,
        },
        "items": items,
        "total_kcal": round(total_kcal),
        "total_protein_g": round(total_protein, 1),
        "total_carbs_g": round(total_carbs, 1),
        "total_fat_g": round(total_fat, 1),
        "confidence": (
            round(sum(i["confidence"] for i in items) / len(items), 2) if items else 0.0
        ),
        "portion_confidence": (
            round(sum(i["portion_confidence"] for i in items) / len(items), 2)
            if items
            else 0.0
        ),
        "disclaimer": DISCLAIMER,
        "model": settings.vision_model_name,
        "image_name": filename,
    }


def _mock_analyze(image_bytes: bytes, filename: str = "meal.jpg") -> dict:
    digest = hashlib.sha256(image_bytes).digest()
    combo = COMBOS[digest[0] % len(COMBOS)]

    items = []
    total_kcal = total_protein = total_carbs = total_fat = 0.0
    for index, (name, grams) in enumerate(combo):
        per_100 = FOODS[name]
        factor = grams / 100
        kcal = round(per_100[0] * factor)
        protein = round(per_100[1] * factor, 1)
        carbs = round(per_100[2] * factor, 1)
        fat = round(per_100[3] * factor, 1)
        confidence = round(0.91 - index * 0.07, 2)

        items.append(
            {
                "name": name,
                "grams": grams,
                "grams_min": max(5, grams - max(5, round(grams * 0.2))),
                "grams_max": grams + max(5, round(grams * 0.2)),
                "portion_confidence": 0.6,
                "portion_basis": "常见份量估算",
                "kcal_per_100g": per_100[0],
                "protein_per_100g": per_100[1],
                "carbs_per_100g": per_100[2],
                "fat_per_100g": per_100[3],
                "kcal": kcal,
                "protein_g": protein,
                "carbs_g": carbs,
                "fat_g": fat,
                "confidence": confidence,
            }
        )
        total_kcal += kcal
        total_protein += protein
        total_carbs += carbs
        total_fat += fat

    return {
        "summary": "（本地估算样例，视觉识别未启用）",
        "is_food": True,
        "reference": {"type": "none", "basis": ""},
        "items": items,
        "total_kcal": round(total_kcal),
        "total_protein_g": round(total_protein, 1),
        "total_carbs_g": round(total_carbs, 1),
        "total_fat_g": round(total_fat, 1),
        "confidence": round(sum(item["confidence"] for item in items) / len(items), 2),
        "portion_confidence": round(
            sum(item["portion_confidence"] for item in items) / len(items), 2
        ),
        "disclaimer": DISCLAIMER,
        "model": "mock",
        "image_name": filename,
    }
