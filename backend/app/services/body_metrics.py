"""Body metric writes and the profile current-value cache.

`body_metrics` is the source of truth for weight, body-fat and circumferences.
`profiles.weight_kg`, `body_fat_pct` and `waist_cm` are a read cache used by
plan generation and legacy endpoints. Every write must go through this module
so the cache and history cannot drift.
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..models import BodyMetric, Profile
from ..schemas import BodyMetricIn


def body_metric_dict(item: BodyMetric) -> dict:
    return {
        "client_id": item.client_id,
        "measured_at": item.measured_at.isoformat(),
        "weight_kg": item.weight_kg,
        "body_fat_pct": item.body_fat_pct,
        "waist_cm": item.waist_cm,
        "arm_cm": item.arm_cm,
        "thigh_cm": item.thigh_cm,
    }


def _as_utc(value: datetime) -> datetime:
    return (
        value.replace(tzinfo=timezone.utc)
        if value.tzinfo is None
        else value.astimezone(timezone.utc)
    )


def _latest_other_measured_at(
    db: Session, user_id: str, client_id: str
) -> datetime | None:
    return db.scalar(
        select(func.max(BodyMetric.measured_at)).where(
            BodyMetric.user_id == user_id,
            BodyMetric.client_id != client_id,
        )
    )


def _apply_measurements(item: BodyMetric, payload: BodyMetricIn) -> None:
    item.measured_at = payload.measured_at
    item.weight_kg = payload.weight_kg
    item.body_fat_pct = payload.body_fat_pct
    item.waist_cm = payload.waist_cm
    item.arm_cm = payload.arm_cm
    item.thigh_cm = payload.thigh_cm


def _apply_profile_cache(db: Session, user_id: str, payload: BodyMetricIn) -> None:
    profile = db.get(Profile, user_id)
    if profile is None:
        return
    if payload.weight_kg is not None:
        profile.weight_kg = payload.weight_kg
    if payload.body_fat_pct is not None:
        profile.body_fat_pct = payload.body_fat_pct
    if payload.waist_cm is not None:
        profile.waist_cm = payload.waist_cm


def apply_metric(
    db: Session, user_id: str, item: BodyMetric, payload: BodyMetricIn
) -> None:
    _apply_measurements(item, payload)
    latest_at = _latest_other_measured_at(db, user_id, payload.client_id)
    # Older offline edits may sync after a newer measurement. Keep the
    # aggregate profile cache at the newest metric instead of regressing it.
    if latest_at is None or _as_utc(payload.measured_at) >= _as_utc(latest_at):
        _apply_profile_cache(db, user_id, payload)


def recompute_profile_cache(db: Session, user_id: str) -> None:
    profile = db.get(Profile, user_id)
    if profile is None:
        return
    latest = db.execute(
        select(BodyMetric)
        .where(BodyMetric.user_id == user_id)
        .order_by(BodyMetric.measured_at.desc(), BodyMetric.created_at.desc())
        .limit(1)
    ).scalar_one_or_none()
    if latest is None:
        return
    if latest.weight_kg is not None:
        profile.weight_kg = latest.weight_kg
    if latest.body_fat_pct is not None:
        profile.body_fat_pct = latest.body_fat_pct
    if latest.waist_cm is not None:
        profile.waist_cm = latest.waist_cm


def upsert_metric(db: Session, user_id: str, payload: BodyMetricIn) -> BodyMetric:
    item = db.execute(
        select(BodyMetric).where(
            BodyMetric.user_id == user_id,
            BodyMetric.client_id == payload.client_id,
        )
    ).scalar_one_or_none()
    if item is None:
        item = BodyMetric(user_id=user_id, client_id=payload.client_id)
        db.add(item)
    apply_metric(db, user_id, item, payload)
    try:
        db.commit()
    except IntegrityError:
        # A concurrent retry won the unique(user_id, client_id) race.
        db.rollback()
        item = db.execute(
            select(BodyMetric).where(
                BodyMetric.user_id == user_id,
                BodyMetric.client_id == payload.client_id,
            )
        ).scalar_one()
        apply_metric(db, user_id, item, payload)
        db.commit()
    return item


def delete_metric(db: Session, user_id: str, client_id: str) -> bool:
    item = db.execute(
        select(BodyMetric).where(
            BodyMetric.user_id == user_id,
            BodyMetric.client_id == client_id,
        )
    ).scalar_one_or_none()
    if item is None:
        return False
    db.delete(item)
    db.flush()
    recompute_profile_cache(db, user_id)
    db.commit()
    return True
