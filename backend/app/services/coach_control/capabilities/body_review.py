"""Deterministic body-trend review.

Reads the last 12 weeks of body metrics, compares the latest values with the
window start, and reports progress toward the active weight goal. This is a
read-only insight used by the coach instead of asking the model to do math.
"""

from __future__ import annotations

from datetime import timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ....models import BodyMetric, Profile, utcnow
from ...queries import active_goal
from ..registry import Capability, register

CAPABILITY = register(
    Capability(
        id="body.review_trend",
        domain="body",
        kind="read",
        title="身体趋势",
        description="汇总 12 周体重、体脂和腰围变化，并对照当前目标",
        requires_confirmation=False,
        undo=False,
        events=("BodyTrendReviewed",),
    )
)


def _fmt(value: float) -> str:
    return f"{value:.1f}"


def _as_utc(value):
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def resolve(db: Session, user_id: str) -> dict:
    profile = db.get(Profile, user_id)
    metrics = (
        db.execute(
            select(BodyMetric)
            .where(
                BodyMetric.user_id == user_id,
                BodyMetric.measured_at >= utcnow() - timedelta(weeks=12),
            )
            .order_by(BodyMetric.measured_at.asc())
        )
        .scalars()
        .all()
    )
    weights = [
        (item.measured_at, float(item.weight_kg))
        for item in metrics
        if item.weight_kg is not None
    ]
    fats = [
        (item.measured_at, float(item.body_fat_pct))
        for item in metrics
        if item.body_fat_pct is not None
    ]
    waists = [
        (item.measured_at, float(item.waist_cm))
        for item in metrics
        if item.waist_cm is not None
    ]
    goal = active_goal(db, user_id)

    if not weights:
        fallback = (
            f"档案体重 {_fmt(float(profile.weight_kg))} kg。"
            if profile is not None and profile.weight_kg is not None
            else ""
        )
        return {
            "ready": True,
            "payload": {
                "summary": (
                    "最近 12 周还没有体重记录。"
                    + fallback
                    + "建议每周固定同一时间记录 1-2 次。"
                ),
                "wins": [],
                "watchouts": ["没有趋势数据时，训练和饮食调整只能按感觉判断。"],
                "actions": ["今天先记录一次体重。"],
                "generated_at": utcnow().isoformat(),
            },
        }

    start_date, start_weight = weights[0]
    end_date, end_weight = weights[-1]
    delta = end_weight - start_weight
    summary = (
        f"最近 12 周体重从 {_fmt(start_weight)} kg 到 {_fmt(end_weight)} kg"
        f"（{'+' if delta >= 0 else ''}{_fmt(delta)} kg）。"
    )
    wins = [
        f"体重 {_fmt(end_weight)} kg",
    ]
    if len(weights) >= 2:
        wins.append(f"记录跨度 {max(1, (end_date - start_date).days)} 天")

    if fats:
        fat_delta = fats[-1][1] - fats[0][1]
        if len(fats) >= 2:
            wins.append(
                f"体脂 {_fmt(fats[-1][1])}%（{'+' if fat_delta >= 0 else ''}"
                f"{_fmt(fat_delta)}）"
            )
    if waists:
        waist_delta = waists[-1][1] - waists[0][1]
        if len(waists) >= 2:
            wins.append(
                f"腰围 {_fmt(waists[-1][1])} cm（{'+' if waist_delta >= 0 else ''}"
                f"{_fmt(waist_delta)}）"
            )

    watchouts: list[str] = []
    if goal is not None and goal.target_weight_kg is not None:
        target = float(goal.target_weight_kg)
        remaining = end_weight - target
        direction = "还差" if remaining > 0 else "已低于目标"
        summary += (
            f"目标 {_fmt(target)} kg，"
            f"{direction} {_fmt(abs(remaining))} kg。"
        )
        if start_weight != target:
            if target < start_weight:
                progress = (start_weight - end_weight) / (start_weight - target)
            else:
                progress = (end_weight - start_weight) / (target - start_weight)
            progress = max(0.0, min(1.0, progress))
            wins.append(f"目标进度 {round(progress * 100)}%")

    last_four_weeks = [
        weight
        for measured_at, weight in weights
        if (utcnow() - _as_utc(measured_at)).days <= 28
    ]
    if len(last_four_weeks) >= 2:
        recent_delta = last_four_weeks[-1] - last_four_weeks[0]
        summary += f"近 4 周 {('+' if recent_delta >= 0 else '')}{_fmt(recent_delta)} kg。"
        if recent_delta < -max(1.0, end_weight * 0.02):
            watchouts.append("近 4 周下降偏快，先确认是否吃得够、训练恢复是否正常。")
        elif recent_delta > max(1.0, end_weight * 0.02):
            watchouts.append("近 4 周上升偏快，先检查加餐、饮料和周末摄入。")

    if goal is not None and goal.type == "lose_fat" and delta > 0:
        watchouts.append("当前目标是减脂，但 12 周体重上升；先稳住每日摄入再谈加练。")
    if (utcnow() - _as_utc(end_date)).days > 14:
        watchouts.append("最近两周没有新体重记录，趋势判断可能滞后。")
    if not watchouts:
        watchouts.append("趋势平稳，继续保持每周固定时间记录。")

    return {
        "ready": True,
        "payload": {
            "summary": summary,
            "wins": wins,
            "watchouts": watchouts,
            "actions": [],
            "generated_at": utcnow().isoformat(),
        },
    }
