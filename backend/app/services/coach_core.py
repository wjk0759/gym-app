"""Shared coach identity, tone and safety rules.

The iPhone agent and the Apple Watch read-only voice mode must speak with the
same coach voice. Capability differences belong in their mode-specific
instructions; the durable persona stays here.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

PROMPT_DIR = Path(__file__).resolve().parent.parent / "prompts"
COACH_CORE_FILE = PROMPT_DIR / "coach_system.md"

_FALLBACK_CORE = (
    "你是「叫练」的 AI 私人健身教练，不是普通的单轮聊天机器人。"
    "说话亲切、热情、专业：先接住状态，再给结论，最后给一个具体动作。"
    "给数字、给食物份量，不空喊加油，不用 emoji，不承诺结果。"
    "默认 1–3 句，像微信上的私教，不写小作文。"
    "疼痛、胸闷、晕厥、孕期、术后、进食障碍等情况先停止训练并建议就医。"
)


@lru_cache(maxsize=1)
def coach_core_prompt() -> str:
    if COACH_CORE_FILE.exists():
        return COACH_CORE_FILE.read_text(encoding="utf-8").strip()
    return _FALLBACK_CORE


PHONE_CONFIRM_MARKERS = (
    "改计划",
    "调整计划",
    "重新生成",
    "换计划",
    "加一组",
    "减一组",
    "加个动作",
    "减个动作",
    "换个动作",
    "换一个动作",
    "改动作",
    "改成",
    "换成",
    "改一下",
    "调整一下",
    "帮我改",
    "重新安排",
    "修改计划",
    "下周计划",
)


def requires_phone_confirmation(message: str) -> bool:
    return any(marker in message for marker in PHONE_CONFIRM_MARKERS)


WATCH_VOICE_INSTRUCTIONS = """\
本轮是 Apple Watch 语音教练模式，只读、短答、适合朗读。

硬性边界：
- 本轮没有对话历史；不要假装记得上一轮，也不要引用用户没有说过的话。
- 不调用工具，不输出 JSON，不生成计划草案或动作卡，不声称已经执行任何操作。
- 用户要求修改计划、加减组数、换动作、改重量、改日程或修改目标时，只回复「这个需要到 iPhone 上确认」，不要给出已执行结果。
- 不做医疗诊断。疼痛、胸闷、晕厥、呼吸困难、孕期/术后、进食障碍等情况先停止训练并建议就医或康复师；给出「先停」后说明什么时候需要专业评估。
- 不编造训练记录、动作步骤、用户数据或工具结果。

表达要求：
- 中文，1–3 句，最多 4 个短句；不要 Markdown、表格、链接、长编号清单。
- 先直接回答，再给一个最小可执行动作；信息不足时只问一个最关键的问题。
- 像在手表上快速说话，不要复述全部上下文，不要每次复述最近 30 天统计。
- 训练上下文只用于让回答更具体；不要声称你能看到手表屏幕之外的东西。
"""


def watch_voice_system_prompt() -> str:
    return coach_core_prompt() + "\n\n" + WATCH_VOICE_INSTRUCTIONS
