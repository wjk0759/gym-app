"""Deterministic recovery / readiness snapshot.

The app does not sync sleep or HRV yet, so readiness is built from data the
server actually owns: session frequency, duration, RPE and volume. The acute
(7-day) load is compared with the chronic weekly average (28-day load / 4).
This is a training-load signal, not a medical diagnosis; the coach prompt must
present it as "恢复压力" and never as an injury or illness.
"""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta, timezone
from statistics import mean

from sqlalchemy import select
from sqlalchemy.orm import Session

from ...models import SetLog, WorkoutSession, utcnow
from ..food_text import DIET_TZ

ACUTE_DAYS = 7
CHRONIC_DAYS = 28
MIN_SESSIONS_FOR_ACWR = 6
DEFAULT_SESSION_MINUTES = 45.0
FALLBACK_RPE = 5.0


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _session_rows(
    db: Session,
    user_id: str,
    since: datetime,
) -> list[WorkoutSession]:
    return list(
        db.execute(
            select(WorkoutSession)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.started_at >= since,
            )
            .order_by(WorkoutSession.started_at.desc())
        )
        .scalars()
        .all()
    )


def _load_by_session(
    db: Session,
    sessions: list[WorkoutSession],
) -> tuple[dict[str, float], dict[str, float | None], dict[str, float]]:
    """Return session load, average RPE and completed volume.

    sRPE is duration × average set RPE when RPE exists, otherwise duration × 5.
    The fallback keeps cardio and older logs from disappearing from the load
    curve, while still rewarding users who record RPE.
    """
    if not sessions:
        return {}, {}, {}
    ids = [item.id for item in sessions]
    sets = list(
        db.execute(select(SetLog).where(SetLog.session_id.in_(ids)))
        .scalars()
        .all()
    )
    grouped: dict[str, list[SetLog]] = defaultdict(list)
    for item in sets:
        grouped[item.session_id].append(item)

    loads: dict[str, float] = {}
    rpes: dict[str, float | None] = {}
    volumes: dict[str, float] = {}
    for session in sessions:
        rows = grouped.get(session.id, [])
        completed = [item for item in rows if item.completed]
        rpe_values = [
            float(item.rpe)
            for item in completed
            if item.rpe is not None
        ]
        avg_rpe = round(mean(rpe_values), 1) if rpe_values else None
        duration = float(session.duration_min or DEFAULT_SESSION_MINUTES)
        loads[session.id] = duration * (
            avg_rpe if avg_rpe is not None else FALLBACK_RPE
        )
        rpes[session.id] = avg_rpe
        volumes[session.id] = sum(
            float(item.weight_kg or 0) * int(item.reps or 0)
            for item in completed
            if item.weight_kg is not None and item.reps is not None
        )
    return loads, rpes, volumes


def _status(
    *,
    sessions_28d: int,
    acwr: float | None,
    average_rpe_7d: float | None,
    days_since_last: int | None,
) -> str:
    if sessions_28d == 0:
        return "no_data"
    if sessions_28d < MIN_SESSIONS_FOR_ACWR:
        return "baseline"
    if acwr is not None and acwr >= 1.5:
        return "high_risk"
    if average_rpe_7d is not None and average_rpe_7d >= 8.5:
        return "high_risk"
    if acwr is not None and acwr >= 1.3:
        return "strained"
    if average_rpe_7d is not None and average_rpe_7d >= 8.0:
        return "strained"
    if (
        acwr is not None
        and acwr <= 0.8
        and days_since_last is not None
        and days_since_last >= 3
    ):
        return "fresh"
    return "balanced"


def _copy(status: str) -> tuple[str, list[str]]:
    if status == "no_data":
        return (
            "最近 28 天还没有训练记录，暂时没有负荷曲线可看。",
            ["先完成下一次训练并记录 RPE，连续两周后才有恢复趋势可判断。"],
        )
    if status == "baseline":
        return (
            "训练样本还少，ACWR 暂时不稳定；先用出勤和主观疲劳判断。",
            ["下一次训练后记录 RPE，保持每周至少 2 次记录。"],
        )
    if status == "high_risk":
        return (
            "近 7 天负荷明显高于前 3 周平均，恢复压力偏高。",
            [
                "本周先减载：主项降 1 组或降 5% 重量，下一次 RPE 控制在 7。",
                "连续两天疲劳、睡不好或动作发飘时，直接安排休息，不要硬顶。",
            ],
        )
    if status == "strained":
        return (
            "近期负荷偏高，恢复窗口偏紧。",
            [
                "下一次同动作降 1 组，先不加重量，把 RPE 压到 7–8。",
                "先把睡眠和蛋白质补上，再谈加量。",
            ],
        )
    if status == "fresh":
        return (
            "近 7 天负荷偏低，距上次训练有几天，恢复窗口充足。",
            [
                "下一次按计划训练；主项稳定时可以加 2.5% 重量或 +1 次。",
                "不要一次把之前缺的量全补回来。",
            ],
        )
    return (
        "近 7 天负荷和前 3 周平均接近，恢复状态比较平稳。",
        ["按计划训练，保持 RPE 7–8，下一周再根据完成率调整。"],
    )


def snapshot(
    db: Session,
    user_id: str,
    *,
    now: datetime | None = None,
) -> dict:
    """Build the readiness payload used by coach answers and weekly review."""
    moment = now or utcnow()
    moment_utc = _as_utc(moment)
    since = moment_utc - timedelta(days=CHRONIC_DAYS)
    sessions = _session_rows(db, user_id, since)
    loads, rpes, volumes = _load_by_session(db, sessions)

    acute_cutoff = moment_utc - timedelta(days=ACUTE_DAYS)
    acute = [
        item
        for item in sessions
        if _as_utc(item.started_at) >= acute_cutoff
    ]
    acute_load = sum(loads.get(item.id, 0.0) for item in acute)
    chronic_load = sum(loads.get(item.id, 0.0) for item in sessions)
    chronic_weekly = chronic_load / (CHRONIC_DAYS / 7)
    acwr = (
        acute_load / chronic_weekly
        if chronic_weekly > 0 and len(sessions) >= MIN_SESSIONS_FOR_ACWR
        else None
    )
    acute_rpes = [
        rpes[item.id]
        for item in acute
        if rpes.get(item.id) is not None
    ]
    average_rpe_7d = round(mean(acute_rpes), 1) if acute_rpes else None
    volume_7d = sum(volumes.get(item.id, 0.0) for item in acute)

    latest = sessions[0] if sessions else None
    days_since_last = None
    if latest is not None:
        latest_local = _as_utc(latest.started_at).astimezone(DIET_TZ).date()
        days_since_last = max(
            0,
            (moment_utc.astimezone(DIET_TZ).date() - latest_local).days,
        )

    status = _status(
        sessions_28d=len(sessions),
        acwr=acwr,
        average_rpe_7d=average_rpe_7d,
        days_since_last=days_since_last,
    )
    summary, actions = _copy(status)
    return {
        "status": status,
        "summary": summary,
        "actions": actions,
        "acwr": round(acwr, 2) if acwr is not None else None,
        "acute_load": round(acute_load),
        "chronic_weekly_load": round(chronic_weekly),
        "sessions_7d": len(acute),
        "sessions_28d": len(sessions),
        "average_rpe_7d": average_rpe_7d,
        "volume_7d_kg": round(volume_7d),
        "days_since_last": days_since_last,
    }
