"""Deterministic safety and profile guardrails for the AI coach.

This module runs before any model call. It owns hard safety boundaries so a
model upgrade, prompt change or outage cannot silently remove them.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

# Message-only rules are ordered by urgency. Keep replies short and actionable.
SAFETY_RULES: list[tuple[tuple[str, ...], str, str]] = [
    (
        (
            "自杀",
            "不想活",
            "自残",
            "伤害自己",
            "活着没意义",
            "结束生命",
            "轻生",
            "想死",
            "kill myself",
            "suicide",
            "self-harm",
            "self harm",
            "hurt myself",
            "end my life",
            "want to die",
        ),
        "crisis",
        "我很在意你现在的安全。请先联系身边可信任的人，或拨打当地急救/心理援助热线"
        "（如 120，或北京心理危机干预中心 010-82951332）。训练的事先放一放，"
        "等你安全了我们再聊。",
    ),
    (
        (
            "胸痛",
            "胸闷",
            "呼吸困难",
            "喘不上气",
            "晕厥",
            "昏倒",
            "意识丧失",
            "chest pain",
            "can't breathe",
            "cannot breathe",
            "shortness of breath",
            "fainted",
            "passed out",
        ),
        "medical_referral",
        "你描述的可能是需要立即处理的情况。请马上停止训练，坐下休息；如果症状持续或加重，"
        "请立即就医或拨打 120。不要继续做任何高强度动作。",
    ),
    (
        (
            "剧痛",
            "刺痛",
            "肿胀",
            "麻木",
            "无法承重",
            "骨折",
            "扭伤",
            "关节卡住",
            "变形",
            "can't bear weight",
            "cannot bear weight",
            "fracture",
            "swollen",
            "numbness",
        ),
        "medical_referral",
        "关节剧痛、肿胀或麻木不适合继续训练。请先停止相关动作，冰敷并尽快找医生或康复师评估。"
        "在明确诊断前，我不给继续加练的建议。",
    ),
    (
        (
            "怀孕",
            "孕期",
            "产后",
            "术后",
            "手术",
            "pregnant",
            "pregnancy",
            "postpartum",
            "surgery",
        ),
        "medical_referral",
        "孕期、产后恢复期和术后训练需要专业评估。建议先咨询产科医生或康复师，再决定训练内容。"
        "我可以帮你记录当前状态，但不提供这类训练处方。",
    ),
    (
        (
            "三天没吃",
            "3天没吃",
            "几天没吃",
            "几天没吃东西",
            "两天没吃",
            "2天没吃",
            "haven't eaten",
            "days without food",
        ),
        "medical_referral",
        "先别训练，也别做有氧。几天没吃东西可能有低血糖和晕倒风险；先少量喝水、吃点能入口的食物，"
        "尽快联系医生或当地急救。",
    ),
    (
        (
            "厌食",
            "暴食",
            "催吐",
            "不想吃饭",
            "绝食",
            "进食障碍",
            "吃完就吐",
            "吃完催吐",
            "eating disorder",
            "anorexia",
            "bulimia",
            "binge",
            "purge",
            "throw up after eating",
        ),
        "medical_referral",
        "你提到的饮食状态需要专业支持。建议联系营养科或心理医生；我不会给你极端热量、断食或催吐方案。",
    ),
]

MINOR_RISK = (
    "类固醇",
    "sarms",
    "steroid",
    "打药",
    "增肌粉",
    "肌酸",
    "补剂",
    "剂量",
    "减肥药",
    "泻药",
    "断食",
    "禁食",
    "不吃晚饭",
    "每天只吃",
    "只吃一顿",
    "节食",
    "三天没吃",
    "3天没吃",
    "催吐",
    "吃完就吐",
    "暴食",
    "两周瘦",
    "两周减",
    "一周瘦",
    "一周减",
    "10公斤",
    "10斤",
    "20斤",
    "快速瘦",
    "暴瘦",
    "500个",
    "1000个",
)

MINOR_WEIGHT_BLOCK = (
    "减肥",
    "减脂",
    "瘦身",
    "减重",
    "降低体重",
    "掉秤",
)

MINOR_WEIGHT_WORDS = (
    "减肥",
    "减脂",
    "瘦",
    "体重",
    "腹肌",
    "增肌",
    "补剂",
    "肌酸",
    "类固醇",
)

FALL_WORDS = (
    "摔倒",
    "跌倒",
    "摔过",
    "平衡",
    "头晕",
    "眩晕",
    "站不稳",
    "走路不稳",
    "晕倒",
    "骨密度",
    "骨质疏松",
    "骨折",
)

CONDITION_WORDS = (
    "糖尿病",
    "血糖",
    "高血压",
    "血压",
    "心脏病",
    "冠心病",
    "心律失常",
    "肾病",
    "肾功能",
    "痛风",
    "哮喘",
    "慢阻肺",
    "癫痫",
    "骨质疏松",
    "椎间盘",
    "甲状腺",
    "贫血",
    "癌症",
    "化疗",
)

MEDICATION_WORDS = (
    "华法林",
    "抗凝",
    "阿司匹林",
    "氯吡格雷",
    "胰岛素",
    "降压药",
    "降糖药",
    "甲状腺药",
    "激素",
    "免疫抑制剂",
    "抗抑郁药",
    "吃药",
    "用药",
)

HIGH_IMPACT = (
    "跑步",
    "跳绳",
    "跳跃",
    "HIIT",
    "hiit",
    "冲刺",
    "马拉松",
    "大重量",
    "极限",
    "冲重量",
    "1RM",
    "1rm",
    "200kg",
    "100kg",
    "硬拉",
    "深蹲",
    "卧推",
)

INJURY_WORDS = (
    "膝盖疼",
    "膝痛",
    "腰疼",
    "腰痛",
    "肩痛",
    "肩疼",
    "肩膀疼",
    "关节痛",
    "关节疼",
    "手腕疼",
    "肘疼",
    "脚踝疼",
    "疼痛",
    "受伤",
    "拉伤",
    "扭伤",
    "不舒服",
    "疼",
    "痛",
    "knee pain",
    "shoulder pain",
    "back pain",
    "joint pain",
)

PED_WORDS = (
    "类固醇",
    "sarms",
    "steroid",
    "群勃龙",
    "睾酮",
    "打药",
    "药物剂量",
)

SUPPLEMENT_WORDS = (
    "肌酸",
    "咖啡因",
    "氮泵",
    "减肥药",
    "补剂",
    "蛋白粉",
    "维生素",
)

DOSE_WORDS = (
    "多少克",
    "多少毫克",
    "剂量",
    "每天多少",
    "几克",
    "怎么吃",
    "吃多少",
)

CONDITION_RISK = HIGH_IMPACT + (
    "断食",
    "禁食",
    "7天断食",
    "断食7天",
    "每天只吃",
    "只吃一顿",
    "1200大卡",
    "800大卡",
    "脱水",
    "桑拿",
    "减肥药",
    "补剂",
    "类固醇",
    "剂量",
)

MINOR_REPLY = (
    "这个先按未成年人的安全边界来：减重、补剂或极端训练我不给具体方案。"
    "先和爸妈或监护人一起找儿科/运动医学医生评估；现在先把三餐、睡眠和基础动作做稳。"
)

FALL_REPLY = (
    "这个强度先别上。你这个年龄加上跌倒/平衡/骨密度风险，先做跌倒风险和骨密度评估，"
    "再决定跑跳和负重；现在可以先从扶椅坐站、快走和单腿站立开始。"
)

CONDITION_REPLY = (
    "这个不能按普通训练方案处理。你提到的慢性病/用药，和断食、大重量或 HIIT 可能有冲突；"
    "先让医生确认风险和用药时间。我可以帮你把训练降到低强度，但不替代医嘱。"
)

MEDICATION_REPLY = (
    "你正在用药，这个训练/饮食方案先不能直接给。"
    "先让医生确认药物、运动强度和出血/低血糖等风险；我可以帮你安排低强度恢复内容，但不替代医嘱。"
)

INJURY_REPLY = (
    "有疼痛还上大重量或高冲击，先别做。先停相关动作，确认有没有肿胀、卡住或无法承重；"
    "需要的话找医生或康复师评估，再决定什么时候恢复。"
)

PED_REPLY = (
    "类固醇/SARMs 这类药物我不提供剂量或 cycle 方案，风险必须由医生评估。"
    "训练和饮食我可以帮你把基础打牢。"
)

SUPPLEMENT_REPLY = (
    "补剂剂量我不给具体数字。先看产品标签，或问医生/注册营养师；"
    "食物、睡眠和训练优先，别靠补剂解决基础问题。"
)


@dataclass(frozen=True)
class SafetyDecision:
    flag: str | None = None
    reply: str | None = None
    caution: str | None = None
    reason: str = ""


def _has_any(text: str, words: tuple[str, ...]) -> str | None:
    for word in words:
        if word.lower() in text:
            return word
    return None


def detect_safety(message: str) -> tuple[str | None, str | None]:
    """Message-only safety rules. Kept as a public compatibility helper."""
    text = (message or "").lower()
    for keywords, flag, reply in SAFETY_RULES:
        if any(keyword.lower() in text for keyword in keywords):
            return flag, reply
    return None, None


def assess_safety(profile: Any | None, message: str) -> SafetyDecision:
    """Return a hard block or a soft caution before the model is called."""
    text = (message or "").lower()
    flag, reply = detect_safety(text)
    if reply:
        return SafetyDecision(flag=flag, reply=reply, reason="message_rule")

    age = getattr(profile, "age", None)
    injuries = getattr(profile, "injuries", None) or []
    fall: str | None = None
    injury = _has_any(text, INJURY_WORDS)
    ped = _has_any(text, PED_WORDS)
    supplement = _has_any(text, SUPPLEMENT_WORDS)
    dose = _has_any(text, DOSE_WORDS)
    impact = _has_any(text, HIGH_IMPACT)

    if age is not None and age < 18:
        hit = _has_any(text, MINOR_RISK) or _has_any(text, MINOR_WEIGHT_BLOCK)
        if hit:
            return SafetyDecision(
                flag="minor_guard",
                reply=MINOR_REPLY,
                reason=f"minor_guard:{hit}",
            )

    if age is not None and age >= 65:
        fall = _has_any(text, FALL_WORDS)
        if fall and impact:
            return SafetyDecision(
                flag="fall_guard",
                reply=FALL_REPLY,
                reason=f"fall_guard:{fall}+{impact}",
            )

    if ped:
        return SafetyDecision(
            flag="ped_guard",
            reply=PED_REPLY,
            reason=f"ped_guard:{ped}",
        )
    if injury and impact:
        return SafetyDecision(
            flag="injury_guard",
            reply=INJURY_REPLY,
            reason=f"injury_guard:{injury}+{impact}",
        )
    if supplement and dose:
        return SafetyDecision(
            flag="supplement_guard",
            reply=SUPPLEMENT_REPLY,
            reason=f"supplement_guard:{supplement}+{dose}",
        )

    condition = _has_any(text, CONDITION_WORDS)
    medication = _has_any(text, MEDICATION_WORDS)
    risky = _has_any(text, CONDITION_RISK)
    if condition and risky:
        return SafetyDecision(
            flag="condition_guard",
            reply=CONDITION_REPLY,
            reason=f"condition_guard:{condition}+{risky}",
        )
    if medication and risky:
        return SafetyDecision(
            flag="medication_guard",
            reply=MEDICATION_REPLY,
            reason=f"medication_guard:{medication}+{risky}",
        )

    cautions: list[str] = []
    if age is not None and age < 18 and _has_any(text, MINOR_WEIGHT_WORDS):
        cautions.append("用户未成年；训练和饮食建议要保守，减重或补剂问题要求家长/儿科医生参与。")
    if fall and age is not None and age >= 65:
        cautions.append("用户年龄较大且有跌倒/平衡风险；避免跑跳、高冲击和大重量，优先安全评估。")
    elif fall:
        cautions.append("用户提到跌倒/平衡风险；训练建议先做安全评估。")
    elif age is not None and age >= 65 and impact:
        cautions.append("用户年龄较大且想做高冲击/大重量动作；先评估平衡、骨密度和心肺，再逐步增加。")
    if condition:
        cautions.append(
            f"用户提到慢性病（{condition}）；避免极端饮食、大重量或 HIIT，必要时建议医生评估。"
        )
    if medication:
        cautions.append(
            f"用户正在用药（{medication}）；避免断食、大重量或 HIIT 等可能影响用药安全的建议。"
        )
    if injury:
        cautions.append("用户提到疼痛或伤病；涉及负重或高冲击时先评估，不要硬顶。")
    if ped:
        cautions.append("用户询问类固醇/SARMs；不提供剂量和 cycle，先建议医生评估。")
    if injuries:
        cautions.append("用户档案里有伤病；涉及相关部位时先降负荷并询问疼痛和肿胀情况。")

    return SafetyDecision(
        flag=None,
        reply=None,
        caution=" ".join(cautions) or None,
        reason="caution" if cautions else "",
    )
