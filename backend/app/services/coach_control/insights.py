"""Read-only ledger facts for the coach answer prompt.

The coach model is good at explaining and asking follow-ups, but it must not
invent counts, totals or recent records. These helpers read the user's
training, nutrition, body and plan rows and return a compact fact block for
``coach_answer``. Nothing in this module writes or mutates data.

The functions are intentionally deterministic: numbers, dates and exercise
names come from the database, while the LLM only turns them into natural
language. This keeps the "ask my data" path cheap and auditable.
"""

from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import (
    Exercise,
    FoodLog,
    Profile,
    Program,
    SetLog,
    WorkoutSession,
)
from ..lexicon import EQUIPMENT_LABELS
from ..queries import active_goal
from .progression import build_plan as build_progression_plan
from .progression import format_facts as format_progression_facts
from .readiness import snapshot as readiness_snapshot


def _as_utc(value: datetime) -> datetime:
    """Normalize SQLite's naive datetimes before formatting or comparing."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _as_local(value: datetime) -> datetime:
    """Render stored UTC timestamps in the user's China local time."""
    return _as_utc(value).astimezone(CHINA_TZ)


CHINA_TZ = timezone(timedelta(hours=8))


@dataclass(frozen=True)
class _Window:
    """A half-open local-time window; labels are safe to show to the user."""

    start: datetime
    end: datetime
    label: str


def _window_for(message: str, default_days: int) -> _Window:
    """Resolve "上周 / 本周 / 上个月 / 本月" as calendar windows.

    Treating 上周 as the last seven days silently changes the answer when the
    user asks on a Monday or after a skipped week. Calendar boundaries match
    what a Chinese user means by those words.
    """
    now = datetime.now(CHINA_TZ)
    monday = (now - timedelta(days=now.weekday())).replace(
        hour=0,
        minute=0,
        second=0,
        microsecond=0,
    )
    if "上周" in message:
        return _Window(monday - timedelta(days=7), monday, "上周")
    if any(word in message for word in ("本周", "这周")):
        return _Window(monday, now, "本周")
    if "上个月" in message:
        month_start = now.replace(
            day=1,
            hour=0,
            minute=0,
            second=0,
            microsecond=0,
        )
        previous_start = (month_start - timedelta(days=1)).replace(
            day=1,
            hour=0,
            minute=0,
            second=0,
            microsecond=0,
        )
        return _Window(previous_start, month_start, "上个月")
    if any(word in message for word in ("本月", "这个月")):
        month_start = now.replace(
            day=1,
            hour=0,
            minute=0,
            second=0,
            microsecond=0,
        )
        return _Window(month_start, now, "本月")
    days = default_days
    if any(word in message for word in ("三个月", "90天", "3个月")):
        days = 90
    elif "半年" in message:
        days = 180
    return _Window(now - timedelta(days=days), now, f"最近 {days} 天")


def _fmt_kg(value: float | None) -> str:
    return "—" if value is None else f"{value:.1f} kg"


def _exercise_name_map(db: Session, slugs: set[str]) -> dict[str, str]:
    """Resolve slugs to Chinese names; fall back to the slug when missing."""
    if not slugs:
        return {}
    rows = db.execute(
        select(Exercise.slug, Exercise.name_zh).where(Exercise.slug.in_(slugs))
    ).all()
    return {slug: name or slug for slug, name in rows}


def _matching_exercise(db: Session, message: str) -> tuple[str, str] | None:
    """Return the longest exercise name mentioned in the message.

    Exercise names overlap (深蹲 / 杠铃深蹲), so the longest match is the least
    surprising interpretation. The catalogue is small enough for this scan.
    """
    matches: list[tuple[str, str]] = []
    for slug, name in db.execute(select(Exercise.slug, Exercise.name_zh)).all():
        if name and name in message:
            matches.append((slug, name))
    if not matches:
        return None
    return max(matches, key=lambda item: len(item[1]))


def _training_summary(db: Session, user_id: str, message: str) -> str:
    """Summarize recent sessions, volume and an optional exercise focus."""
    window = _window_for(message, 28)
    start = window.start.astimezone(timezone.utc)
    end = window.end.astimezone(timezone.utc)
    sessions = (
        db.execute(
            select(WorkoutSession)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.started_at >= start,
                WorkoutSession.started_at < end,
            )
            .order_by(WorkoutSession.started_at.desc())
        )
        .scalars()
        .all()
    )
    if not sessions:
        return f"训练（{window.label}）：没有训练记录。"

    session_ids = [item.id for item in sessions]
    sets = (
        db.execute(select(SetLog).where(SetLog.session_id.in_(session_ids)))
        .scalars()
        .all()
    )
    completed = [item for item in sets if item.completed]
    volume = sum(
        float(item.weight_kg or 0) * int(item.reps or 0)
        for item in completed
        if item.weight_kg is not None and item.reps is not None
    )
    sets_by_session = Counter(item.session_id for item in sets)
    recent = "；".join(
        f"{_as_local(item.started_at).strftime('%m/%d')} "
        f"{item.duration_min or '—'} 分钟 "
        f"{sets_by_session.get(item.id, 0)} 组"
        for item in sessions[:3]
    )
    lines = [
        f"训练（{window.label}）：{len(sessions)} 次，"
        f"{len(completed)} 组，总容量 {volume:.0f} kg。",
        f"最近训练：{recent}。",
    ]

    match = _matching_exercise(db, message)
    if match is not None:
        slug, name = match
        focused = [item for item in completed if item.exercise_slug == slug]
        if focused:
            focused_volume = sum(
                float(item.weight_kg or 0) * int(item.reps or 0)
                for item in focused
                if item.weight_kg is not None and item.reps is not None
            )
            best = max(
                (float(item.weight_kg) for item in focused if item.weight_kg is not None),
                default=None,
            )
            lines.append(
                f"{name}：{len(focused)} 组，最大重量 {_fmt_kg(best)}，"
                f"总容量 {focused_volume:.0f} kg。"
            )
        else:
            lines.append(f"{name}：这个窗口没有训练记录。")

    top_slugs = [slug for slug, _ in Counter(
        item.exercise_slug for item in completed
    ).most_common(3)]
    names = _exercise_name_map(db, set(top_slugs))
    if top_slugs:
        lines.append("练得最多：" + "、".join(names.get(slug, slug) for slug in top_slugs) + "。")
    return "\n".join(lines)


def _nutrition_summary(db: Session, user_id: str, message: str) -> str:
    """Summarize food-log totals; never estimate missing macros here."""
    window = _window_for(message, 7)
    start = window.start.astimezone(timezone.utc)
    end = window.end.astimezone(timezone.utc)
    logs = (
        db.execute(
            select(FoodLog)
            .where(
                FoodLog.user_id == user_id,
                FoodLog.logged_at >= start,
                FoodLog.logged_at < end,
            )
            .order_by(FoodLog.logged_at.desc())
        )
        .scalars()
        .all()
    )
    if not logs:
        return f"饮食（{window.label}）：没有饮食记录。"

    total_kcal = sum(float(item.kcal or 0) for item in logs)
    total_protein = sum(float(item.protein or 0) for item in logs)
    total_carbs = sum(float(item.carbs or 0) for item in logs)
    total_fat = sum(float(item.fat or 0) for item in logs)
    logged_days = len({_as_local(item.logged_at).date() for item in logs})
    recent = "、".join(
        f"{_as_local(item.logged_at).strftime('%m/%d')} {item.food_name}"
        for item in logs[:3]
    )
    return (
        f"饮食（{window.label}）：记录 {logged_days} 天 / {len(logs)} 条，"
        f"热量 {total_kcal:.0f} kcal，蛋白质 {total_protein:.0f} g，"
        f"碳水 {total_carbs:.0f} g，脂肪 {total_fat:.0f} g。"
        f"\n最近记录：{recent}。"
    )


def _plan_summary(program: Program | None) -> str:
    """Describe the active plan structure so the model can explain it truthfully."""
    if program is None:
        return "计划：当前没有生效中的训练计划。"
    days = sorted(
        program.days,
        key=lambda item: (item.week_index, item.weekday),
    )
    first_week = [item for item in days if item.week_index == 1]
    if not first_week:
        return f"计划：{program.title}；没有第 1 周训练日明细。"
    day_lines = []
    for item in first_week:
        weekday = "一二三四五六日"[max(0, min(6, item.weekday - 1))]
        exercises = sorted(item.exercises, key=lambda row: row.order_index)
        names = "、".join(
            (row.exercise.name_zh if row.exercise else row.exercise_slug)
            for row in exercises[:5]
        )
        # Focus codes are internal taxonomy values (``chest``/``glutes``). They
        # leak English into the prompt and invite the model to over-explain, so
        # only the day title and real exercise names are exposed.
        day_lines.append(
            f"周{weekday} {item.title}"
            + f"，{len(item.exercises)} 个动作"
            + (f"：{names}" if names else "")
        )
    template_days = "、".join(
        f"周{'一二三四五六日'[max(0, min(6, item.weekday - 1))]}" for item in first_week
    )
    return (
        f"计划：{program.title}；{program.weeks} 周，"
        f"每周 {len(first_week)} 练；开始日期 {program.start_date}。"
        f"\n训练日模板：{template_days}。"
        f"\n第 1 周：{'；'.join(day_lines)}。"
        # Reschedules live on the client board, not in the program rows. Telling
        # the model this prevents it from presenting the template weekdays as
        # the user's actual training dates.
        "\n说明：以上是计划模板的周几；用户可能在 App 里改期，实际日期以 App 日程为准。"
    )


def _body_summary(db: Session, user_id: str) -> str:
    """Reuse the deterministic body review instead of asking the model to do math."""
    # Imported lazily: importing the capabilities package from module scope
    # would circle back through coach_answer and insights.
    from .capabilities.body_review import resolve as resolve_body_review

    payload = resolve_body_review(db, user_id).get("payload") or {}
    summary = str(payload.get("summary") or "").strip()
    wins = [str(item) for item in payload.get("wins") or []]
    watchouts = [str(item) for item in payload.get("watchouts") or []]
    lines = [f"身体趋势：{summary}"] if summary else []
    if wins:
        lines.append("数据点：" + "、".join(wins) + "。")
    if watchouts:
        lines.append("注意：" + "、".join(watchouts) + "。")
    return "\n".join(lines) or "身体趋势：暂时没有可用数据。"


def _profile_summary(db: Session, profile: Profile) -> str:
    """List missing onboarding fields without treating optional data as required.

    Equipment and schedule preferences are part of the onboarding snapshot, so
    they are stated explicitly. Otherwise a model asked "what is missing" tends
    to invent gaps such as equipment or sleep when the real profile is complete.
    """
    missing: list[str] = []
    if profile.birth_date is None:
        missing.append("出生日期")
    if profile.height_cm is None:
        missing.append("身高")
    if profile.weight_kg is None:
        missing.append("体重")
    if not profile.onboarded_at:
        missing.append("完成建档")
    goal = active_goal(db, profile.user_id)
    if goal is None:
        missing.append("训练目标")
    injuries = [str(item) for item in (profile.injuries or []) if str(item).strip()]
    injury_line = "伤病记录：" + ("、".join(injuries) if injuries else "无")
    equipment = [str(item) for item in (profile.equipment or []) if str(item).strip()]
    equipment_line = "已填器械：" + (
        "、".join(EQUIPMENT_LABELS.get(item, item) for item in equipment)
        if equipment
        else "未填"
    )
    schedule_line = (
        f"每周训练 {profile.weekly_days} 天，每次 {profile.session_minutes} 分钟"
    )
    if not missing:
        return (
            "档案：基础档案已完整，没有缺失项。\n"
            + equipment_line
            + "\n"
            + schedule_line
            + "\n"
            + injury_line
        )
    return (
        "档案：还缺 " + "、".join(missing) + "。\n"
        + equipment_line
        + "\n"
        + schedule_line
        + "\n"
        + injury_line
    )


def _recovery_summary(db: Session, user_id: str) -> str:
    """Describe training-load readiness with deterministic numbers.

    Only session frequency/duration/RPE/volume are available today. Sleep and
    HRV are not synced, so the copy must stay at "恢复压力", not medical advice.
    """
    payload = readiness_snapshot(db, user_id)
    metrics = [
        f"近 7 天 {payload['sessions_7d']} 次",
        f"近 28 天 {payload['sessions_28d']} 次",
    ]
    if payload.get("acwr") is not None:
        metrics.append(f"ACWR {payload['acwr']:.2f}")
    if payload.get("average_rpe_7d") is not None:
        metrics.append(f"平均 RPE {payload['average_rpe_7d']}")
    if payload.get("days_since_last") is not None:
        metrics.append(f"距上次训练 {payload['days_since_last']} 天")
    lines = [
        f"恢复状态：{payload['summary']}",
        "负荷指标：" + "，".join(metrics) + "。",
    ]
    actions = [str(item) for item in payload.get("actions") or []]
    if actions:
        lines.append("建议：" + "；".join(actions))
    return "\n".join(lines)


def _progression_summary(
    db: Session,
    user_id: str,
    program: Program | None,
) -> str:
    """Per-exercise next-week targets, grounded in last-session RPE/reps."""
    plan = build_progression_plan(db, user_id, program)
    return format_progression_facts(plan)


def build_readonly_context(
    db: Session,
    user_id: str,
    message: str,
    program: Program | None = None,
) -> str | None:
    """Return a fact block for the coach prompt, or None when not relevant.

    The caller is the free-form answer capability. Keeping this gate narrow
    avoids injecting large ledger summaries into ordinary coaching advice.
    """
    text = message.strip()
    if not text:
        return None

    # Do not turn a failed write action into a data summary. The answer
    # capability is also the fallback for action gaps, so only inject ledger
    # facts when the user is actually asking about existing data.
    action_only = re.search(
        r"记录一下|记一下|帮我记|改成|改为|删除|删掉|添加|开始|跳过|生成|调整|换|设置|取消",
        text,
    )
    question = re.search(r"多少|几次|怎么样|为什么|吗|呢|？|\?", text)
    if action_only and not question:
        return None

    sections: list[str] = []
    if any(word in text for word in ("建档", "档案", "资料", "还缺", "完善")):
        profile = db.get(Profile, user_id)
        if profile is not None:
            sections.append(_profile_summary(db, profile))
    if any(
        word in text
        for word in ("训练", "练了", "练过", "次数", "进步", "重量", "容量", "深蹲", "卧推", "硬拉", "跑步", "有氧")
    ):
        sections.append(_training_summary(db, user_id, text))
    if any(word in text for word in ("饮食", "吃", "热量", "蛋白", "碳水", "脂肪", "餐")):
        sections.append(_nutrition_summary(db, user_id, text))
    if any(word in text for word in ("体重", "体脂", "腰围", "围度", "身体", "变化", "减脂", "增肌")):
        sections.append(_body_summary(db, user_id))
    if any(
        word in text
        for word in (
            "恢复",
            "疲劳",
            "太累",
            "酸痛",
            "睡不好",
            "没精神",
            "readiness",
            "减载",
            "能练吗",
            "要不要休息",
            "训练状态",
            "身体状态",
        )
    ):
        sections.append(_recovery_summary(db, user_id))
    if any(
        word in text
        for word in (
            "加多少",
            "加重",
            "加重量",
            "进阶",
            "目标重量",
            "要不要加",
            "怎么加",
        )
    ) or (
        "下周" in text
        and any(
            word in text
            for word in ("卧推", "深蹲", "硬拉", "推举", "划船")
        )
    ):
        sections.append(_progression_summary(db, user_id, program))
    if any(word in text for word in ("计划", "安排", "为什么", "分化", "频率", "训练日")):
        sections.append(_plan_summary(program))

    if not sections:
        return None
    return (
        "以下是服务端实时查询到的事实，只能基于这些事实回答，不要编造；"
        "事实里没有的伤病、疼痛、体态或动作理由不要推断，"
        "不要使用“治疗/矫正/康复”等医疗结论。"
        "恢复事实只基于训练负荷，不是医学诊断；不要编造睡眠、HRV 或伤病数据。"
        "问档案时只列事实里写出的缺失项；事实说已完整就回答完整，"
        "不要把已填项或未列出的项（如睡眠、饮食）说成缺失。"
        "解释计划时只依据给出的模板周几、每日主题和动作，"
        "不要把两个不同的训练日说成同一天，也不要猜用户实际哪天练；"
        "不要声称用户以前说过或偏好某事，除非对话历史、记忆或这些事实里明确有。\n"
        + "\n".join(sections)
    )
