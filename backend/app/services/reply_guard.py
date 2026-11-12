"""Deterministic post-generation safety review for coach replies.

``assess_safety`` protects the input side. This module protects the output
side: a model can still produce unsafe advice from a safe prompt, so every
assistant reply passes through these checks before it is persisted or shown.
The rules are intentionally narrow and deterministic; they only replace text
when the reply clearly recommends training through pain, extreme dieting or
drug/supplement dosing.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

_SAFE_MARKERS = (
    "不要",
    "别",
    "不能",
    "避免",
    "禁止",
    "不建议",
    "千万别",
    "无需",
    "不必",
    "不用",
    "不给",
    "不提供",
    "错误",
    "错的",
    "不对",
    "有害",
    "危险",
    "上肢",
    "上半身",
    "其他部位",
    "不痛",
)

_PAIN = r"(?:疼|痛|受伤|伤病|拉伤|扭伤|肿胀|麻木)"
_TRAIN_THROUGH = (
    r"(?:继续练|继续训练|接着练|照练|坚持练|带伤练|忍痛|硬练|"
    r"加重量|上重量|冲重量|加练|"
    r"别停|不用停|不能停|不能休息|不用休息)"
)

_PAIN_RE = re.compile(
    rf"{_PAIN}.{{0,12}}{_TRAIN_THROUGH}|{_TRAIN_THROUGH}.{{0,12}}{_PAIN}"
)
_EXTREME_DIET_RE = re.compile(
    r"(?:催吐|吃完就吐|泻药|"
    r"断食\s*\d+\s*天|\d+\s*天断食|"
    r"每天只吃(?:一顿|一餐|一丁点)|只吃(?:一顿|一餐)|"
    r"(?:低于|不到)\s*(?:800|1000|1200)\s*(?:大卡|千卡|kcal)|"
    r"(?:一周|两周|一个月|1\s*周|2\s*周).{0,8}(?:瘦|减)\s*\d+\s*(?:斤|公斤|kg))"
)
_SUPPLEMENT_DOSE_RE = re.compile(
    r"(?:"
    r"(?:肌酸|蛋白粉|咖啡因|氮泵|补剂|类固醇|sarms|睾酮)"
    r".{0,12}(?:\d+\s*(?:克|g|毫克|mg)|剂量|每天吃|怎么吃|cycle)"
    r"|(?:吃|服用|摄入).{0,8}\d+\s*(?:克|g|毫克|mg).{0,8}"
    r"(?:肌酸|蛋白粉|咖啡因|氮泵|补剂|类固醇|sarms|睾酮)"
    r")",
    re.IGNORECASE,
)
_MEDICAL_DISMISSAL_RE = re.compile(
    r"(?:不用|不需要|没必要|别|不必).{0,6}(?:看医生|就医|去医院|康复师)"
)
_DIAGNOSIS_RE = re.compile(
    r"(?:就是|肯定是|确诊为|属于).{0,8}"
    r"(?:骨折|韧带撕裂|跟腱断裂|半月板撕裂|抑郁症|厌食症)"
)

_PAIN_REPLY = (
    "疼的时候不要继续练同一个动作，也别用“忍一忍”顶过去。"
    "先停下来，确认有没有肿胀、卡住或无法承重；如果持续或加重，"
    "找医生或康复师评估。训练可以改成不痛的动作，但前提是先排除损伤。"
)

_DIET_REPLY = (
    "这个饮食方案太激进了，我不能给。极端断食、催吐或远低于基础代谢的热量，"
    "容易掉肌肉、反弹，也有低血糖和进食障碍风险。先按三餐规律吃，"
    "把蛋白和蔬菜补够；如果要减脂，我们用小缺口慢慢来。"
)

_SUPPLEMENT_REPLY = (
    "补剂剂量我不给具体数字，也不建议你自己加量。"
    "先看产品标签，或问医生/注册营养师；食物、睡眠和训练优先。"
)

_MEDICAL_REPLY = (
    "这个我不能替你判断要不要就医。胸痛、晕厥、明显肿胀、无法承重或持续加重，"
    "先停止训练并尽快就医；不要靠继续练来验证。"
)

_DIAGNOSIS_REPLY = (
    "我不能根据文字或照片给你确诊。先别按“骨折/韧带撕裂”自己练；"
    "如果疼痛、肿胀或活动受限明显，找医生或康复师做检查。"
)


def _window(text: str, match: re.Match[str]) -> str:
    before = text[max(0, match.start() - 8) : match.start()]
    inside = match.group(0)
    # Only look at the rest of this sentence after the match; a "不要" in the
    # next sentence must not excuse the unsafe directive.
    after = re.split(
        r"[。！？!?；;\n]",
        text[match.end() : match.end() + 10],
        maxsplit=1,
    )[0]
    return before + inside + after


def _negated_or_safe_context(text: str, match: re.Match[str]) -> bool:
    window = _window(text, match)
    # These are unsafe directives, not safe negations. Remove them before
    # looking for "不要/别/..." so "疼就继续练，不用停" still gets blocked.
    for phrase in ("不用停", "不能停", "别停", "不用休息", "不能休息"):
        window = window.replace(phrase, "")
    return any(word in window for word in _SAFE_MARKERS)


def _matches(
    text: str,
    pattern: re.Pattern[str],
    *,
    skip_negated: bool = True,
) -> list[re.Match[str]]:
    found = list(pattern.finditer(text))
    if not skip_negated:
        return found
    return [
        match
        for match in found
        if not _negated_or_safe_context(text, match)
    ]


@dataclass(frozen=True)
class ReplyReview:
    reply: str
    safety_flag: str | None = None
    rules: tuple[str, ...] = ()

    @property
    def blocked(self) -> bool:
        return self.safety_flag is not None


def review_reply(profile: Any | None, reply: str) -> ReplyReview:
    """Replace unsafe model output with a deterministic safe reply.

    Returns the original text unchanged when no rule matches. The first rule in
    severity order chooses the replacement; all matched rule names are kept for
    audit logs and agent steps.
    """
    text = (reply or "").strip()
    if not text:
        return ReplyReview(reply=reply)

    matched: list[str] = []
    flag: str | None = None
    safe_reply: str | None = None

    pain_hits = _matches(text, _PAIN_RE)
    if pain_hits:
        matched.append("train_through_pain")
        flag = "injury_guard"
        safe_reply = _PAIN_REPLY

    diet_hits = _matches(text, _EXTREME_DIET_RE)
    if diet_hits:
        matched.append("extreme_diet")
        age = getattr(profile, "age", None)
        if flag is None:
            flag = "minor_guard" if age is not None and age < 18 else "medical_referral"
            safe_reply = _DIET_REPLY

    supplement_hits = _matches(text, _SUPPLEMENT_DOSE_RE)
    if supplement_hits:
        matched.append("supplement_dose")
        if flag is None:
            flag = "supplement_guard"
            safe_reply = _SUPPLEMENT_REPLY

    medical_hits = _matches(
        text,
        _MEDICAL_DISMISSAL_RE,
        skip_negated=False,
    )
    if medical_hits:
        matched.append("medical_dismissal")
        if flag is None:
            flag = "medical_referral"
            safe_reply = _MEDICAL_REPLY

    diagnosis_hits = _matches(text, _DIAGNOSIS_RE)
    if diagnosis_hits:
        matched.append("diagnosis_claim")
        if flag is None:
            flag = "medical_referral"
            safe_reply = _DIAGNOSIS_REPLY

    if not matched:
        return ReplyReview(reply=reply)
    return ReplyReview(
        reply=safe_reply or _MEDICAL_REPLY,
        safety_flag=flag,
        rules=tuple(matched),
    )
