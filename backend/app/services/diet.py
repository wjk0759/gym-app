"""饮食：Mifflin-St Jeor 热量计算 + 三餐模板。

注意：不提供疾病饮食处方；外卖链接只做跳转，不承诺营养匹配。
"""

from __future__ import annotations

from datetime import date

from ..config import settings
from ..models import Profile
from urllib.parse import quote

MEAL_TEMPLATE = [
    {
        "meal": "breakfast",
        "name": "早餐",
        "ratio": 0.25,
        "items": ["燕麦 50g", "鸡蛋 2 个", "无糖酸奶 150g", "蓝莓 80g"],
    },
    {
        "meal": "lunch",
        "name": "午餐",
        "ratio": 0.35,
        "items": ["糙米饭 150g", "鸡胸肉 150g", "西兰花 200g", "橄榄油 5g"],
    },
    {
        "meal": "dinner",
        "name": "晚餐",
        "ratio": 0.30,
        "items": ["红薯 150g", "三文鱼/豆腐 150g", "混合蔬菜 250g"],
    },
    {
        "meal": "snack",
        "name": "加餐",
        "ratio": 0.10,
        "items": ["牛奶 200ml", "坚果 15g"],
    },
]


def calculate_targets(profile: Profile, goal_type: str) -> dict:
    weight = profile.weight_kg or 70
    height = profile.height_cm or 170
    age = profile.age or 30

    if profile.sex == "female":
        bmr = 10 * weight + 6.25 * height - 5 * age - 161
    else:
        bmr = 10 * weight + 6.25 * height - 5 * age + 5

    weekly_days = profile.weekly_days or 3
    if weekly_days <= 2:
        activity = 1.375
    elif weekly_days <= 4:
        activity = 1.55
    else:
        activity = 1.725

    tdee = bmr * activity
    if goal_type == "lose_fat":
        kcal = tdee * 0.85
        protein_per_kg = 1.8
    elif goal_type == "build_muscle":
        kcal = tdee * 1.10
        protein_per_kg = 2.0
    else:
        kcal = tdee
        protein_per_kg = 1.6

    protein = weight * protein_per_kg
    fat = weight * 0.9
    carbs = max(0.0, (kcal - protein * 4 - fat * 9) / 4)

    return {
        "bmr_kcal": round(bmr),
        "tdee_kcal": round(tdee),
        "target_kcal": round(kcal),
        "protein_g": round(protein),
        "carb_g": round(carbs),
        "fat_g": round(fat),
        "note": "结果为估算区间，不构成医疗或疾病饮食建议。",
    }


def build_plan(profile: Profile, goal_type: str, plan_date: date) -> dict:
    targets = calculate_targets(profile, goal_type)
    meals = []
    for template in MEAL_TEMPLATE:
        meals.append(
            {
                "meal": template["meal"],
                "name": template["name"],
                "kcal": round(targets["target_kcal"] * template["ratio"]),
                "items": template["items"],
            }
        )
    return {
        "date": plan_date.isoformat(),
        "targets": targets,
        "meals": meals,
        "disclaimer": "根据体重与目标估算；有疾病、孕期或特殊饮食需求请咨询医生或营养师。",
    }


def meituan_link(keyword: str) -> dict | None:
    if not settings.meituan_deeplink_base:
        return None
    encoded = quote(keyword)
    deeplink = settings.meituan_deeplink_base.format(keyword=encoded)
    h5_url = (
        settings.meituan_h5_base.format(keyword=encoded)
        if settings.meituan_h5_base
        else None
    )
    return {
        "deeplink": deeplink,
        "h5_url": h5_url,
        "keyword": keyword,
        "disclaimer": "链接由美团联盟生成；价格、菜品与营养信息以美团页面为准。",
    }
