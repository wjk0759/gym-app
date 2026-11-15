"""Small durable user-data sync for settings and reusable food/exercise prefs.

The payload is deliberately a full snapshot for now: the collections are small
and this keeps the first cross-device implementation easy to reason about.
Photos, body analyses, cycle data and workout drafts will get dedicated
endpoints instead of being packed into this JSON.
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..models import (
    UserCustomFood,
    UserExerciseDislike,
    UserFoodFavorite,
    UserPreference,
    utcnow,
)
from ..schemas import SyncIn
from .locking import lock_user


def ensure_preferences(db: Session, user_id: str) -> UserPreference:
    item = db.get(UserPreference, user_id)
    if item is None:
        item = UserPreference(user_id=user_id)
        db.add(item)
        db.flush()
    return item


def preferences_dict(item: UserPreference) -> dict:
    return {
        "strict_equipment_mode": item.strict_equipment_mode,
        "use_remote_ai": item.use_remote_ai,
        "reminder_hour": item.reminder_hour,
        "reminder_minute": item.reminder_minute,
        "notifications_enabled": item.notifications_enabled,
        "body_checkin_frequency": item.body_checkin_frequency,
        "body_checkin_weekday": item.body_checkin_weekday,
        "body_checkin_day": item.body_checkin_day,
        "updated_at": item.updated_at.isoformat(),
    }


def _custom_food_dict(item: UserCustomFood) -> dict:
    return {
        "client_id": item.client_id,
        "name": item.name,
        "category": item.category,
        "kcal": item.kcal,
        "protein": item.protein,
        "carbs": item.carbs,
        "fat": item.fat,
        "fiber": item.fiber,
        "default_grams": item.default_grams,
        "updated_at": item.updated_at.isoformat(),
    }


def _favorite_dict(item: UserFoodFavorite) -> dict:
    return {
        "food_key": item.food_key,
        "name": item.name,
        "updated_at": item.updated_at.isoformat(),
    }


def _dislike_dict(item: UserExerciseDislike) -> dict:
    return {
        "slug": item.slug,
        "updated_at": item.updated_at.isoformat(),
    }


def sync_snapshot(db: Session, user_id: str) -> dict:
    preferences = ensure_preferences(db, user_id)
    custom_foods = (
        db.execute(
            select(UserCustomFood)
            .where(
                UserCustomFood.user_id == user_id,
                UserCustomFood.deleted_at.is_(None),
            )
            .order_by(UserCustomFood.updated_at.desc())
        )
        .scalars()
        .all()
    )
    favorites = (
        db.execute(
            select(UserFoodFavorite)
            .where(
                UserFoodFavorite.user_id == user_id,
                UserFoodFavorite.deleted_at.is_(None),
            )
            .order_by(UserFoodFavorite.updated_at.desc())
        )
        .scalars()
        .all()
    )
    dislikes = (
        db.execute(
            select(UserExerciseDislike)
            .where(
                UserExerciseDislike.user_id == user_id,
                UserExerciseDislike.deleted_at.is_(None),
            )
            .order_by(UserExerciseDislike.updated_at.desc())
        )
        .scalars()
        .all()
    )
    return {
        "server_time": datetime.now(timezone.utc).isoformat(),
        "preferences": preferences_dict(preferences),
        "custom_foods": [_custom_food_dict(item) for item in custom_foods],
        "favorites": [_favorite_dict(item) for item in favorites],
        "disliked_exercises": [_dislike_dict(item) for item in dislikes],
    }


def _apply_preferences(db: Session, user_id: str, payload) -> None:
    item = ensure_preferences(db, user_id)
    for field in (
        "strict_equipment_mode",
        "use_remote_ai",
        "reminder_hour",
        "reminder_minute",
        "notifications_enabled",
        "body_checkin_frequency",
        "body_checkin_weekday",
        "body_checkin_day",
    ):
        value = getattr(payload, field)
        if value is not None:
            setattr(item, field, value)
    item.updated_at = utcnow()


def _apply_custom_foods(db: Session, user_id: str, items) -> None:
    for payload in items:
        item = db.execute(
            select(UserCustomFood).where(
                UserCustomFood.user_id == user_id,
                UserCustomFood.client_id == payload.client_id,
            )
        ).scalar_one_or_none()
        if item is None:
            item = UserCustomFood(
                user_id=user_id,
                client_id=payload.client_id,
                name=payload.name,
            )
            db.add(item)
        if payload.deleted:
            item.deleted_at = utcnow()
            continue
        item.name = payload.name
        item.category = payload.category
        item.kcal = payload.kcal
        item.protein = payload.protein
        item.carbs = payload.carbs
        item.fat = payload.fat
        item.fiber = payload.fiber
        item.default_grams = payload.default_grams
        item.deleted_at = None
        item.updated_at = utcnow()


def _apply_favorites(db: Session, user_id: str, items) -> None:
    for payload in items:
        item = db.execute(
            select(UserFoodFavorite).where(
                UserFoodFavorite.user_id == user_id,
                UserFoodFavorite.food_key == payload.food_key,
            )
        ).scalar_one_or_none()
        if item is None:
            item = UserFoodFavorite(
                user_id=user_id,
                food_key=payload.food_key,
                name=payload.name,
            )
            db.add(item)
        if payload.deleted:
            item.deleted_at = utcnow()
            continue
        item.name = payload.name
        item.deleted_at = None
        item.updated_at = utcnow()


def _apply_dislikes(db: Session, user_id: str, items) -> None:
    for payload in items:
        item = db.execute(
            select(UserExerciseDislike).where(
                UserExerciseDislike.user_id == user_id,
                UserExerciseDislike.slug == payload.slug,
            )
        ).scalar_one_or_none()
        if item is None:
            item = UserExerciseDislike(user_id=user_id, slug=payload.slug)
            db.add(item)
        if payload.deleted:
            item.deleted_at = utcnow()
            continue
        item.deleted_at = None
        item.updated_at = utcnow()


def apply_sync(db: Session, user_id: str, payload: SyncIn) -> dict:
    # A client snapshot can contain the same key twice if local merging or a
    # retry went wrong. The last value wins; never insert two rows and let the
    # unique constraint turn the whole sync into a 500.
    custom_foods = list(
        {item.client_id: item for item in payload.custom_foods}.values()
    )
    favorites = list(
        {item.food_key: item for item in payload.favorites}.values()
    )
    dislikes = list(
        {item.slug: item for item in payload.disliked_exercises}.values()
    )
    lock_user(db, user_id)
    if payload.preferences is not None:
        _apply_preferences(db, user_id, payload.preferences)
    _apply_custom_foods(db, user_id, custom_foods)
    _apply_favorites(db, user_id, favorites)
    _apply_dislikes(db, user_id, dislikes)
    db.commit()
    return sync_snapshot(db, user_id)
