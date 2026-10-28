"""饮食照片识别：当前为可替换的 Mock。

隐私原则：
- 原图不落盘、不入库
- 只返回食物与营养估算
- 过敏原、疾病饮食必须以包装/商家/医生为准
"""

from __future__ import annotations

import base64
import hashlib
import logging

from ..config import settings
from . import llm

logger = logging.getLogger(__name__)

DISCLAIMER = (
    "识别结果为估算，热量与营养素可能有偏差。这里不评价食物好坏；"
    "过敏原、疾病饮食与特殊人群需求请以包装标签、商家信息或医生/营养师意见为准。"
)

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


async def analyze(image_bytes: bytes, filename: str = "meal.jpg") -> dict:
    if settings.use_mock_vision:
        return _mock_analyze(image_bytes, filename)
    try:
        result = await llm.complete_vision_json(
            _SYSTEM_PROMPT, _USER_PROMPT, base64.b64encode(image_bytes).decode()
        )
        return _normalize(result, filename)
    except Exception as exc:  # noqa: BLE001 - 识别失败回退本地估算，不让拍照功能崩溃
        logger.warning("food vision failed, fallback to mock: %s", exc)
        payload = _mock_analyze(image_bytes, filename)
        payload["warning"] = f"视觉识别失败，已回退本地估算：{str(exc)[:200]}"
        return payload


_SYSTEM_PROMPT = (
    "你是严谨的饮食记录助手。识别图片中的内容并如实描述。"
    "如果是食物，逐项估算名称、重量(克)、热量(千卡)与蛋白质/碳水/脂肪(克)。"
    "如果不是食物，如实说明拍到的是什么，不要硬猜成食物。只输出一个 JSON 对象，不要解释。"
)

_USER_PROMPT = (
    '识别图片里的内容，输出 JSON：'
    '{"summary":"如实描述图片里有什么","is_food":true或false,'
    '"items":[{"name":"食物名","grams":重量,"kcal":热量,'
    '"protein_g":蛋白质,"carbs_g":碳水,"fat_g":脂肪}]}。'
    '如果图片里没有食物（比如是一块木头、一只手、空盘、桌面、文字），'
    'is_food 为 false，items 输出空数组，summary 必须如实写清楚这是什么、为什么不是食物。'
    '重量与营养是估算值。只输出 JSON。'
)


def _normalize(data: dict, filename: str) -> dict:
    items = []
    total_kcal = total_protein = total_carbs = total_fat = 0.0
    for raw in data.get("items") or []:
        if not isinstance(raw, dict):
            continue
        name = str(raw.get("name") or "食物")[:24]
        grams = max(1.0, float(raw.get("grams") or 100))
        kcal = float(raw.get("kcal") or 0)
        protein = float(raw.get("protein_g") or 0)
        carbs = float(raw.get("carbs_g") or 0)
        fat = float(raw.get("fat_g") or 0)
        if not kcal and (protein or carbs or fat):
            kcal = protein * 4 + carbs * 4 + fat * 9
        items.append(
            {
                "name": name,
                "grams": round(grams),
                "kcal_per_100g": round(kcal / grams * 100),
                "protein_per_100g": round(protein / grams * 100, 1),
                "carbs_per_100g": round(carbs / grams * 100, 1),
                "fat_per_100g": round(fat / grams * 100, 1),
                "kcal": round(kcal),
                "protein_g": round(protein, 1),
                "carbs_g": round(carbs, 1),
                "fat_g": round(fat, 1),
                "confidence": round(float(raw.get("confidence") or 0.7), 2),
            }
        )
        total_kcal += kcal
        total_protein += protein
        total_carbs += carbs
        total_fat += fat

    return {
        "summary": str(data.get("summary") or "")[:200],
        "is_food": bool(items),
        "items": items,
        "total_kcal": round(total_kcal),
        "total_protein_g": round(total_protein, 1),
        "total_carbs_g": round(total_carbs, 1),
        "total_fat_g": round(total_fat, 1),
        "confidence": (
            round(sum(i["confidence"] for i in items) / len(items), 2) if items else 0.0
        ),
        "disclaimer": DISCLAIMER,
        "model": settings.vision_model,
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
        "items": items,
        "total_kcal": round(total_kcal),
        "total_protein_g": round(total_protein, 1),
        "total_carbs_g": round(total_carbs, 1),
        "total_fat_g": round(total_fat, 1),
        "confidence": round(sum(item["confidence"] for item in items) / len(items), 2),
        "disclaimer": DISCLAIMER,
        "model": "mock",
        "image_name": filename,
    }
