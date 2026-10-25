"""AI 教练：安全拦截优先，其次 RAG/LLM，最后确定性回复。"""

from __future__ import annotations

from pathlib import Path

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import ChatMessage, Exercise, Profile, Program
from . import llm

PROMPT_PATH = Path(__file__).resolve().parent.parent / "prompts" / "coach_system.md"

SAFETY_RULES: list[tuple[tuple[str, ...], str, str]] = [
    (
        ("胸痛", "胸闷", "呼吸困难", "喘不上气", "晕厥", "昏倒"),
        "medical_referral",
        "你描述的可能是需要立即处理的情况。请马上停止训练，坐下休息；如果症状持续或加重，请立即就医或拨打 120。"
        "我可以帮你把今天的训练改成休息，但不要继续做任何高强度动作。",
    ),
    (
        ("剧痛", "刺痛", "肿胀", "麻木", "无法承重", "骨折", "扭伤"),
        "medical_referral",
        "关节剧痛、肿胀或麻木不适合继续训练。请先停止相关动作，冰敷并尽快找医生或康复师评估。"
        "在明确诊断前，我不会给你继续加练的建议。",
    ),
    (
        ("怀孕", "孕期", "产后", "术后", "手术"),
        "medical_referral",
        "孕期、产后恢复期和术后训练需要专业评估。建议先咨询产科医生或康复师，再决定训练内容。"
        "我可以帮你记录当前状态，但不提供这类训练处方。",
    ),
    (
        ("厌食", "暴食", "催吐", "不想吃饭", "绝食"),
        "medical_referral",
        "你提到的饮食状态需要专业支持。建议联系营养科或心理医生；我不会给你极端热量或断食方案。",
    ),
]

DEFAULT_SAFETY_REPLY = (
    "这个话题涉及医疗判断，我不能替代医生。建议你咨询专业人士；"
    "如果你愿意，我可以帮你把训练调整为低强度恢复内容。"
)


def detect_safety(message: str) -> tuple[str | None, str | None]:
    text = message.lower()
    for keywords, flag, reply in SAFETY_RULES:
        if any(keyword in text for keyword in keywords):
            return flag, reply
    return None, None


def _system_prompt() -> str:
    if PROMPT_PATH.exists():
        return PROMPT_PATH.read_text(encoding="utf-8")
    return "你是严谨的健身教练，不做医疗诊断。回答简洁、可执行，涉及疼痛时建议就医。"


def _context(profile: Profile, program: Program | None) -> str:
    parts = [
        f"用户：{profile.nickname or '用户'}，{profile.sex}，{profile.age or '?'} 岁，"
        f"{profile.height_cm or '?'}cm，{profile.weight_kg or '?'}kg，"
        f"训练经验 {profile.experience}。",
        f"伤病：{'、'.join(profile.injuries or []) or '无'}。",
        f"目标：{program.goal_type if program else '未设置'}。",
    ]
    if program:
        first_day = next(
            (day for day in program.days if day.week_index == 1), None
        )
        if first_day:
            names = "、".join(
                item.exercise.name_zh for item in first_day.exercises if item.exercise
            )
            parts.append(f"计划示例（第 1 周 {first_day.title}）：{names}。")
    return "\n".join(parts)


def _mock_reply(message: str, profile: Profile, program: Program | None, db: Session) -> tuple[str, list[dict]]:
    text = message.strip()
    citations: list[dict] = []

    if any(word in text for word in ("今天练", "练什么", "计划")):
        if program:
            day = next((d for d in program.days if d.week_index == 1), None)
            if day:
                lines = [
                    f"今天建议练「{day.title}」，共 {len(day.exercises)} 个动作："
                ]
                for item in day.exercises:
                    name = item.exercise.name_zh if item.exercise else item.exercise_slug
                    lines.append(f"· {name} {item.sets} 组 × {item.reps}，休息 {item.rest_sec}s")
                    if item.exercise:
                        citations.append(
                            {
                                "type": "exercise",
                                "slug": item.exercise_slug,
                                "name_zh": name,
                            }
                        )
                lines.append("如果今天状态一般，把最后一组去掉，优先保证动作质量。")
                return "\n".join(lines), citations[:4]
        return "你还没有生成计划。先在「计划」页生成一份，我再按你的器械和时间帮你安排。", []

    if any(word in text for word in ("替代", "没有器械", "换动作", "器械")):
        muscle = "chest"
        for key, value in {
            "胸": "chest",
            "背": "back",
            "腿": "legs",
            "肩": "shoulders",
            "臀": "glutes",
            "核心": "core",
            "腹": "core",
        }.items():
            if key in text:
                muscle = value
                break
        rows = (
            db.execute(
                select(Exercise)
                .where(Exercise.muscle_group == muscle)
                .limit(4)
            )
            .scalars()
            .all()
        )
        if rows:
            lines = [f"如果是{text[:12]}，可以试试这些替代动作："]
            for item in rows:
                lines.append(f"· {item.name_zh}（{item.equipment}）")
                citations.append(
                    {"type": "exercise", "slug": item.slug, "name_zh": item.name_zh}
                )
            lines.append("选择你能稳定完成 8–12 次的重量，动作变形就降重量。")
            return "\n".join(lines), citations[:4]

    if any(word in text for word in ("吃", "蛋白", "热量", "饮食")):
        weight = profile.weight_kg or 70
        protein = round(weight * 1.8)
        return (
            f"按你的体重，每天蛋白质建议在 {protein}g 左右，分 3–4 餐摄入；"
            "训练后 1–2 小时内吃到 20–30g 蛋白质即可，不必卡精确时间。"
            "如果目标是减脂，先保证蛋白质和蔬菜，再控制主食分量。"
            "需要疾病相关饮食方案的话，请咨询营养科医生。",
            [],
        )

    if any(word in text for word in ("酸", "疼", "痛")):
        return (
            "训练后的延迟性酸痛通常 24–72 小时缓解。可以做低强度活动、拉伸和充足睡眠。"
            "但如果是关节刺痛、肿胀或影响走路，先停止训练并找医生评估。",
            [],
        )

    if program:
        return (
            "我记住了。你可以具体问：今天练什么、某个动作怎么替代、"
            "或者把训练感受告诉我，我会在下周计划里调整组数和重量。",
            [],
        )
    return "先完成建档并生成计划，我就能结合你的器械、目标和历史记录给出更具体的建议。", []


async def coach_reply(
    db: Session,
    profile: Profile,
    program: Program | None,
    history: list[ChatMessage],
    message: str,
) -> dict:
    flag, safety_reply = detect_safety(message)
    if safety_reply:
        return {"reply": safety_reply, "safety_flag": flag, "citations": []}

    citations: list[dict] = []
    if not settings.use_mock_llm:
        messages = [
            {"role": "system", "content": _system_prompt()},
            {"role": "system", "content": _context(profile, program)},
        ]
        for item in history[-6:]:
            if item.role in {"user", "assistant"}:
                messages.append({"role": item.role, "content": item.content})
        messages.append({"role": "user", "content": message})
        try:
            reply = await llm.complete_text(messages)
            return {"reply": reply, "safety_flag": None, "citations": []}
        except llm.LLMError:
            pass

    reply, citations = _mock_reply(message, profile, program, db)
    return {"reply": reply, "safety_flag": None, "citations": citations}
