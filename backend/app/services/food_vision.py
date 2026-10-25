"""饮食照片识别：当前为可替换的 Mock。

隐私原则：
- 原图不落盘、不入库
- 只返回食物与营养估算
- 过敏原、疾病饮食必须以包装/商家/医生为准
"""

from __future__ import annotations

import hashlib

DISCLAIMER = (
    "识别结果为估算，热量与营养素可能有偏差。过敏原、疾病饮食与特殊人群需求"
    "请以包装标签、商家信息或医生/营养师意见为准。"
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
}

COMBOS = [
    [("米饭", 150), ("鸡胸肉", 150), ("西兰花", 150)],
    [("燕麦（干）", 60), ("鸡蛋", 100), ("牛奶", 250), ("香蕉", 100)],
    [("糙米饭", 150), ("三文鱼", 120), ("生菜", 100), ("番茄", 80)],
    [("全麦面包", 80), ("鸡蛋", 100), ("牛油果", 80)],
    [("米饭", 180), ("豆腐", 150), ("西兰花", 180)],
]


async def analyze(image_bytes: bytes, filename: str = "meal.jpg") -> dict:
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
