"""Single source of domain vocabulary shared by parsing and planning.

Keeping meal, body-part and equipment words here prevents the same list from
drifting between routing, reviewers, plan generation and UI labels.
"""

from __future__ import annotations

import re

MEAL_LABELS = {
    "breakfast": "早餐",
    "lunch": "午餐",
    "dinner": "晚餐",
    "snack": "加餐",
}
MEAL_ORDER = ("breakfast", "lunch", "dinner", "snack")
MEAL_ALIASES = {
    "breakfast": ("早餐", "早饭", "早上", "清晨", "今早", "早晨", "一早"),
    "lunch": ("午餐", "午饭", "中饭", "中午", "晌午"),
    "snack": ("加餐", "夜宵", "宵夜", "零食", "下午茶", "小吃"),
    "dinner": ("晚餐", "晚饭", "晚上", "傍晚", "昨晚", "夜里", "今晚"),
}
MEAL_PATTERNS = [
    (meal, "|".join(re.escape(alias) for alias in aliases))
    for meal, aliases in MEAL_ALIASES.items()
]


BODY_PART_ALIASES = {
    "膝": ("膝", "膝盖"),
    "腰": ("腰", "腰部"),
    "肩": ("肩", "肩膀"),
    "腕": ("腕", "手腕"),
    "踝": ("踝", "脚踝"),
    "肘": ("肘", "手肘"),
    "半月板": ("半月板",),
}


EQUIPMENT_LABELS = {
    "bodyweight": "徒手",
    "dumbbell": "哑铃",
    "barbell": "杠铃",
    "machine": "固定器械",
    "cable": "龙门架/绳索",
    "band": "弹力带",
    "kettlebell": "壶铃",
    "other": "其他器械",
}
EQUIPMENT_ALIASES = {
    "bodyweight": ("徒手", "自重", "无器械", "没器械", "没有器械", "不去健身房"),
    "dumbbell": ("哑铃",),
    "barbell": ("杠铃", "奥杆"),
    "machine": ("固定器械", "综合器械", "史密斯", "健身房器械"),
    "cable": ("龙门架", "绳索", "拉力器", "缆绳"),
    "band": ("弹力带", "阻力带", "弹力绳"),
    "kettlebell": ("壶铃",),
    "other": ("单杠", "双杠", "trx", "其他器械", "其他"),
}
