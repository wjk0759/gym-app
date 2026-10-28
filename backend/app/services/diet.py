"""饮食：Mifflin-St Jeor 热量计算 + 规则模板 + AI 个性化计划。

注意：不提供疾病饮食处方；外卖链接只做跳转，不承诺营养匹配。
"""

from __future__ import annotations

import json
import logging
from contextlib import suppress
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import quote

from ..config import settings
from ..models import Profile
from . import llm

logger = logging.getLogger(__name__)

PROMPT_PATH = Path(__file__).resolve().parent.parent / "prompts" / "diet_plan.md"

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

DISCLAIMER = (
    "根据体重与目标估算；有疾病、孕期或特殊饮食需求请咨询医生或营养师。"
)


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
    note = "结果为估算区间，不构成医疗或疾病饮食建议。"

    bmi = weight / ((height / 100) ** 2) if height else 0
    # 安全底线：不给极端低热量，减脂也不建议低于基础需求太多。
    safe_floor = 1200 if profile.sex == "female" else 1500

    if goal_type == "lose_fat":
        if bmi and bmi < 18.5:
            kcal = tdee
            note = "当前 BMI 偏低，不建议继续减脂；已按维持热量估算，建议先咨询营养师。"
        else:
            kcal = max(safe_floor, tdee * 0.85)
        protein_per_kg = 1.8
    elif goal_type == "build_muscle":
        kcal = tdee * 1.10
        protein_per_kg = 2.0
    else:
        kcal = tdee
        protein_per_kg = 1.6

    kcal = max(safe_floor, kcal)
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
        "note": note,
    }


def build_plan(profile: Profile, goal_type: str, plan_date: date) -> dict:
    targets = calculate_targets(profile, goal_type)
    meals = [
        {
            "meal": template["meal"],
            "name": template["name"],
            "kcal": round(targets["target_kcal"] * template["ratio"]),
            "items": template["items"],
        }
        for template in MEAL_TEMPLATE
    ]
    return {
        "date": plan_date.isoformat(),
        "targets": targets,
        "meals": meals,
        "disclaimer": DISCLAIMER,
        "generated_by": "template",
    }


def _system_prompt() -> str:
    if PROMPT_PATH.exists():
        return PROMPT_PATH.read_text(encoding="utf-8")
    return "你是运动营养师。只输出 JSON，不做疾病饮食处方，不承诺快速减重。"


def _user_prompt(profile: Profile, goal_type: str, targets: dict) -> str:
    payload = {
        "user": {
            "sex": profile.sex,
            "age": profile.age,
            "height_cm": profile.height_cm,
            "weight_kg": profile.weight_kg,
            "body_fat_pct": profile.body_fat_pct,
            "waist_cm": profile.waist_cm,
            "hip_cm": profile.hip_cm,
            "experience": profile.experience,
            "weekly_days": profile.weekly_days,
            "injuries": profile.injuries or [],
            "goal_type": goal_type,
        },
        "targets": targets,
        "output_rules": {
            "meals": ["breakfast", "lunch", "dinner", "snack"],
            "kcal_tolerance": 0.10,
            "protein_tolerance_g": 15,
            "language": "zh-CN",
        },
    }
    return json.dumps(payload, ensure_ascii=False)


def _normalize_ai_plan(raw: dict, targets: dict, plan_date: date) -> dict:
    meals = []
    for item in raw.get("meals") or []:
        if not isinstance(item, dict):
            continue
        meal_key = str(item.get("meal") or "").strip()
        if meal_key not in {"breakfast", "lunch", "dinner", "snack"}:
            continue
        items = [str(x)[:80] for x in (item.get("items") or []) if str(x).strip()]
        if not items:
            continue
        meals.append(
            {
                "meal": meal_key,
                "name": str(item.get("name") or _meal_name(meal_key))[:20],
                "kcal": _to_int(item.get("kcal"), 0),
                "protein_g": _to_float(item.get("protein_g")),
                "carbs_g": _to_float(item.get("carbs_g")),
                "fat_g": _to_float(item.get("fat_g")),
                "items": items[:8],
            }
        )

    if not meals:
        raise ValueError("AI 饮食计划没有有效餐次")

    # 不足 4 餐时用模板补齐，保证页面结构完整。
    have = {meal["meal"] for meal in meals}
    meals.extend(
        {
            "meal": template["meal"],
            "name": template["name"],
            "kcal": round(targets["target_kcal"] * template["ratio"]),
            "items": template["items"],
        }
        for template in MEAL_TEMPLATE
        if template["meal"] not in have
    )

    meals.sort(key=lambda meal: _meal_order(meal["meal"]))

    tips = [str(x)[:120] for x in (raw.get("tips") or []) if str(x).strip()][:4]
    note = str(raw.get("note") or DISCLAIMER)[:300]

    total_kcal = sum(meal.get("kcal") or 0 for meal in meals)
    total_protein = round(sum(meal.get("protein_g") or 0 for meal in meals), 1)
    total_carbs = round(sum(meal.get("carbs_g") or 0 for meal in meals), 1)
    total_fat = round(sum(meal.get("fat_g") or 0 for meal in meals), 1)

    return {
        "date": plan_date.isoformat(),
        "targets": targets,
        "meals": meals,
        "total_kcal": total_kcal,
        "total_protein_g": total_protein,
        "total_carbs_g": total_carbs,
        "total_fat_g": total_fat,
        "tips": tips,
        "note": note,
        "disclaimer": DISCLAIMER,
        "generated_by": "ai",
        "model": settings.llm_model,
    }


def _meal_name(key: str) -> str:
    return {
        "breakfast": "早餐",
        "lunch": "午餐",
        "dinner": "晚餐",
        "snack": "加餐",
    }.get(key, key)


def _meal_order(key: str) -> int:
    return {"breakfast": 0, "lunch": 1, "dinner": 2, "snack": 3}.get(key, 9)


def _to_int(value, default: int) -> int:
    try:
        return round(float(value))
    except (TypeError, ValueError):
        return default


def _to_float(value) -> float:
    try:
        return round(float(value), 1)
    except (TypeError, ValueError):
        return 0.0


async def build_ai_plan(
    db,
    profile: Profile,
    goal_type: str,
    plan_date: date,
) -> dict:
    """AI 个性化饮食计划；失败时回退规则模板，保证页面始终有结果。"""
    targets = calculate_targets(profile, goal_type)
    if settings.use_mock_llm:
        return build_plan(profile, goal_type, plan_date)

    try:
        raw = await llm.complete_json(
            _system_prompt(),
            _user_prompt(profile, goal_type, targets),
        )
        result = _normalize_ai_plan(raw, targets, plan_date)
        llm.record_job(
            db,
            getattr(profile, "user_id", None),
            kind="diet_plan",
            status="ok",
            model=settings.llm_model,
        )
        return result
    except Exception as exc:  # noqa: BLE001 - 任何失败都回退模板
        logger.warning("AI diet plan failed, fallback to template: %s", exc)
        result = build_plan(profile, goal_type, plan_date)
        result["warning"] = "AI 生成失败，已使用规则模板"
        with suppress(Exception):
            llm.record_job(
                db,
                getattr(profile, "user_id", None),
                kind="diet_plan",
                status="fallback",
                model=settings.llm_model,
                error=str(exc)[:500],
            )
        return result


# ---------------------------------------------------------------------------
# Diet strategies: one registry, reused by the diet module and the coach
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class DietStrategy:
    id: str
    label: str
    description: str
    protein_mult: float = 1.0
    carb_mult: float = 1.0
    fat_mult: float = 1.0
    day_type_mode: str = "none"  # none | carb_cycle
    template: str = "balanced"
    caution: str = ""


DIET_STRATEGIES: dict[str, DietStrategy] = {
    "balanced": DietStrategy(
        id="balanced",
        label="均衡",
        description="三大营养素均衡，适合大多数人，也是最稳的默认方案。",
    ),
    "carb_cycle": DietStrategy(
        id="carb_cycle",
        label="碳循环",
        description="训练日高碳、休息日低碳，蛋白质每天固定，适合有训练规律的增肌/减脂。",
        day_type_mode="carb_cycle",
        template="cycle",
    ),
    "low_carb": DietStrategy(
        id="low_carb",
        label="低碳",
        description="碳水约 20–30%，脂肪略高，蛋白质充足；适合久坐、减脂期。",
        protein_mult=1.10,
        carb_mult=0.40,
        fat_mult=1.20,
        template="low_carb",
        caution="高强度训练、孕期、糖尿病或肾病人群不建议自行使用。",
    ),
    "high_protein": DietStrategy(
        id="high_protein",
        label="高蛋白",
        description="蛋白质约 2.0–2.2g/kg，适合增肌或减脂期保肌肉。",
        protein_mult=1.30,
        carb_mult=0.90,
        fat_mult=0.95,
        template="high_protein",
        caution="肾病或肾功能异常人群需先咨询医生。",
    ),
}

DEFAULT_TRAINING_DAYS = {
    1: [1],
    2: [2, 5],
    3: [1, 3, 5],
    4: [1, 2, 4, 5],
    5: [1, 2, 3, 5, 6],
    6: [1, 2, 3, 4, 5, 6],
    7: [1, 2, 3, 4, 5, 6, 7],
}
WEEKDAY_LABELS = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
DAY_TYPE_LABELS = {
    "high": "高碳日",
    "medium": "中碳日",
    "low": "低碳日",
    "balanced": "均衡日",
}

CYCLE_HIGH_TEMPLATE = [
    {
        "meal": "breakfast",
        "name": "早餐",
        "ratio": 0.25,
        "items": ["燕麦 60g", "香蕉 120g", "鸡蛋 2 个", "无糖酸奶 150g"],
    },
    {
        "meal": "lunch",
        "name": "午餐",
        "ratio": 0.35,
        "items": ["米饭 250g", "鸡胸肉 150g", "西兰花 200g", "橄榄油 5g"],
    },
    {
        "meal": "dinner",
        "name": "晚餐",
        "ratio": 0.30,
        "items": ["红薯 250g", "三文鱼/豆腐 150g", "混合蔬菜 250g", "橄榄油 5g"],
    },
    {
        "meal": "snack",
        "name": "加餐",
        "ratio": 0.10,
        "items": ["全麦面包 60g", "牛奶 250ml"],
    },
]

CYCLE_LOW_TEMPLATE = [
    {
        "meal": "breakfast",
        "name": "早餐",
        "ratio": 0.25,
        "items": ["鸡蛋 3 个", "牛油果 80g", "混合蔬菜 100g"],
    },
    {
        "meal": "lunch",
        "name": "午餐",
        "ratio": 0.35,
        "items": ["鸡胸肉 180g", "混合蔬菜 300g", "橄榄油 10g", "坚果 15g"],
    },
    {
        "meal": "dinner",
        "name": "晚餐",
        "ratio": 0.30,
        "items": ["三文鱼/牛排 180g", "西兰花 250g", "橄榄油 10g"],
    },
    {
        "meal": "snack",
        "name": "加餐",
        "ratio": 0.10,
        "items": ["希腊酸奶 150g", "坚果 20g"],
    },
]

LOW_CARB_TEMPLATE = [
    {
        "meal": "breakfast",
        "name": "早餐",
        "ratio": 0.25,
        "items": ["鸡蛋 3 个", "牛油果 80g", "混合蔬菜 150g"],
    },
    {
        "meal": "lunch",
        "name": "午餐",
        "ratio": 0.35,
        "items": ["鸡胸肉 180g", "混合蔬菜 300g", "橄榄油 10g", "坚果 15g"],
    },
    {
        "meal": "dinner",
        "name": "晚餐",
        "ratio": 0.30,
        "items": ["三文鱼/豆腐 180g", "西兰花 250g", "橄榄油 10g"],
    },
    {
        "meal": "snack",
        "name": "加餐",
        "ratio": 0.10,
        "items": ["希腊酸奶 150g", "坚果 20g"],
    },
]

HIGH_PROTEIN_TEMPLATE = [
    {
        "meal": "breakfast",
        "name": "早餐",
        "ratio": 0.25,
        "items": ["鸡蛋 3 个", "无糖酸奶 200g", "燕麦 40g", "蓝莓 80g"],
    },
    {
        "meal": "lunch",
        "name": "午餐",
        "ratio": 0.35,
        "items": ["鸡胸肉 200g", "糙米饭 150g", "西兰花 200g"],
    },
    {
        "meal": "dinner",
        "name": "晚餐",
        "ratio": 0.30,
        "items": ["三文鱼/瘦牛肉 180g", "红薯 150g", "混合蔬菜 250g"],
    },
    {
        "meal": "snack",
        "name": "加餐",
        "ratio": 0.10,
        "items": ["乳清蛋白/希腊酸奶 200g", "香蕉 100g"],
    },
]


def list_diet_strategies() -> list[dict]:
    return [
        {
            "id": item.id,
            "label": item.label,
            "description": item.description,
            "caution": item.caution,
        }
        for item in DIET_STRATEGIES.values()
    ]


def _strategy(strategy_id: str | None) -> DietStrategy:
    return DIET_STRATEGIES.get(strategy_id or "balanced", DIET_STRATEGIES["balanced"])


def _week_start(day: date) -> date:
    return day - timedelta(days=day.weekday())


def _training_days(profile: Profile, provided: list[int] | None) -> list[int]:
    cleaned = sorted({int(item) for item in (provided or []) if 1 <= int(item) <= 7})
    if cleaned:
        return cleaned
    return DEFAULT_TRAINING_DAYS.get(profile.weekly_days or 3, [1, 3, 5])


def _day_types(training_days: list[int]) -> dict[int, str]:
    training = set(training_days)
    result: dict[int, str] = {}
    for weekday in range(1, 8):
        if weekday in training:
            result[weekday] = "high"
        elif (weekday % 7) + 1 in training:
            result[weekday] = "medium"
        else:
            result[weekday] = "low"
    return result


def _targets_for(
    base: dict, strategy: DietStrategy, day_type: str
) -> dict:
    protein = base["protein_g"] * strategy.protein_mult
    carbs = base["carb_g"] * strategy.carb_mult
    fat = base["fat_g"] * strategy.fat_mult

    if strategy.day_type_mode == "carb_cycle":
        if day_type == "high":
            carbs *= 1.35
            fat *= 0.80
        elif day_type == "low":
            carbs *= 0.55
            fat *= 1.15

    protein = round(protein)
    carbs = round(carbs)
    fat = round(fat)
    kcal = round(protein * 4 + carbs * 4 + fat * 9)
    note = base.get("note", "")
    if strategy.caution:
        note = f"{note} {strategy.caution}".strip()
    return {
        "bmr_kcal": base["bmr_kcal"],
        "tdee_kcal": base["tdee_kcal"],
        "target_kcal": kcal,
        "protein_g": protein,
        "carb_g": carbs,
        "fat_g": fat,
        "note": note,
    }


def _template_for(strategy: DietStrategy, day_type: str) -> list[dict]:
    if strategy.id == "carb_cycle":
        if day_type == "high":
            return CYCLE_HIGH_TEMPLATE
        if day_type == "low":
            return CYCLE_LOW_TEMPLATE
        return MEAL_TEMPLATE
    if strategy.template == "low_carb":
        return LOW_CARB_TEMPLATE
    if strategy.template == "high_protein":
        return HIGH_PROTEIN_TEMPLATE
    return MEAL_TEMPLATE


def _meals_for(template: list[dict], target_kcal: int) -> list[dict]:
    return [
        {
            "meal": item["meal"],
            "name": item["name"],
            "kcal": round(target_kcal * item["ratio"]),
            "items": item["items"],
        }
        for item in template
    ]


def build_diet_week(
    profile: Profile,
    goal_type: str,
    strategy_id: str,
    week_start: date,
    training_days: list[int] | None = None,
) -> dict:
    """One week of the diet plan. Reuses meal_plans; no separate feature."""
    strategy = _strategy(strategy_id)
    base = calculate_targets(profile, goal_type)
    training = _training_days(profile, training_days)
    day_types = (
        _day_types(training)
        if strategy.day_type_mode == "carb_cycle"
        else {weekday: "balanced" for weekday in range(1, 8)}
    )

    days = []
    for offset in range(7):
        current = week_start + timedelta(days=offset)
        weekday = current.isoweekday()
        day_type = day_types.get(weekday, "balanced")
        targets = _targets_for(base, strategy, day_type)
        day_label = (
            DAY_TYPE_LABELS.get(day_type, day_type)
            if strategy.day_type_mode == "carb_cycle"
            else strategy.label
        )
        days.append(
            {
                "date": current.isoformat(),
                "weekday": weekday,
                "day_type": day_type,
                "day_type_label": day_label,
                "title": f"{WEEKDAY_LABELS[weekday - 1]} · {day_label}",
                "targets": targets,
                "meals": _meals_for(_template_for(strategy, day_type), targets["target_kcal"]),
            }
        )

    return {
        "week_start": week_start.isoformat(),
        "strategy": {
            "id": strategy.id,
            "label": strategy.label,
            "description": strategy.description,
            "caution": strategy.caution,
        },
        "training_days": training,
        "days": days,
        "disclaimer": DISCLAIMER,
        "generated_by": "template",
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
