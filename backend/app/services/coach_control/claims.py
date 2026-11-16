"""Explicit precedence for capabilities whose language overlaps.

The runtime still keeps its legacy ordered resolvers for low-risk intents. These
claims are the guard for the pairs that repeatedly collided: exercise edits vs
equipment declarations, food dislikes vs exercise dislikes, and meal detail vs
plan generation.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

EXERCISE_WORDS = (
    r"卧推|深蹲|硬拉|划船|推举|飞鸟|弯举|下压|引体|夹胸|下拉|"
    r"腿举|腿弯举|动作"
)
EQUIPMENT_WORDS = (
    r"哑铃|杠铃|壶铃|弹力带|阻力带|龙门架|绳索|固定器械|综合器械|"
    r"史密斯|器械|设备|器材|徒手|自重"
)
FOOD_WORDS = r"吃|食物|菜|肉|鱼|蛋|奶|饭|面|果|豆|燕麦|西兰花|鸡胸"


@dataclass(frozen=True)
class Claim:
    capability_id: str
    positive: tuple[str, ...]
    negative: tuple[str, ...] = ()
    priority: int = 0

    def matches(self, message: str) -> bool:
        if any(re.search(pattern, message) for pattern in self.negative):
            return False
        return any(re.search(pattern, message) for pattern in self.positive)


CLAIMS = (
    Claim(
        "training.edit_day_exercise",
        (
            rf"(?:{EXERCISE_WORDS}).{{0,20}}(?:换成|改成|改为|替换)",
            rf"把.{{0,20}}(?:{EXERCISE_WORDS}).{{0,20}}(?:换|改)",
        ),
        priority=100,
    ),
    Claim(
        "profile.update_equipment",
        (
            rf"(?:{EQUIPMENT_WORDS}).{{0,20}}"
            rf"(?:我有|我的|买了|卖了|换成|只有|没有|去掉|移除|改成|档案)",
            rf"(?:我有|我的|买了|卖了|只有|没有|去掉|移除)"
            rf".{{0,20}}(?:{EQUIPMENT_WORDS})",
        ),
        negative=(EXERCISE_WORDS,),
        priority=90,
    ),
    Claim(
        "training.dislike_exercise",
        (
            rf"(?:不喜欢|讨厌|别安排|可以安排|恢复安排).{{0,20}}"
            rf"(?:{EXERCISE_WORDS})",
            rf"(?:{EXERCISE_WORDS}).{{0,10}}(?:不喜欢|讨厌|别安排)",
        ),
        priority=85,
    ),
    Claim(
        "diet.dislike_food",
        (
            rf"(?:不喜欢|讨厌|别安排|可以吃|恢复吃).{{0,20}}"
            rf"(?:{FOOD_WORDS})",
            rf"(?:{FOOD_WORDS}).{{0,10}}(?:不喜欢|讨厌|别安排)",
        ),
        negative=(EXERCISE_WORDS,),
        priority=85,
    ),
    Claim(
        "diet.meal_detail",
        (
            r"(?:早餐|早饭|午餐|午饭|晚餐|晚饭|加餐|今晚|今早)"
            r".{0,12}(?:吃什么|菜谱|怎么做|看看|有什么)",
            r"(?:看看|查看).{0,10}餐单",
        ),
        negative=(r"吃了|喝了|记录|生成|安排|做饭",),
        priority=70,
    ),
    Claim(
        "diet.generate_day",
        (
            r"(?:生成|安排|排一下|来一份|做一份).{0,12}(?:饮食|餐单|餐)",
            r"(?:今天|明天|后天)吃什么",
        ),
        priority=60,
    ),
)


def match_claim(message: str) -> str | None:
    for claim in sorted(CLAIMS, key=lambda item: item.priority, reverse=True):
        if claim.matches(message):
            return claim.capability_id
    return None


def claim_conflicts(message: str, capability_id: str) -> bool:
    claimed = match_claim(message)
    return claimed is not None and claimed != capability_id
