from datetime import datetime, timezone

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import BodyMetric, Profile, User
from app.schemas import BodyMetricIn
from app.services.body_metrics import (
    delete_metric,
    recompute_profile_cache,
    upsert_metric,
)


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    session = Session(engine)
    session.add(User(id="u1", phone="13800138000", status="active"))
    session.flush()
    session.add(
        Profile(
            user_id="u1",
            nickname="测试",
            sex="male",
            height_cm=175,
            weight_kg=72,
            body_fat_pct=20,
            waist_cm=82,
            experience="beginner",
            injuries=[],
            equipment=["bodyweight"],
            weekly_days=3,
            session_minutes=45,
        )
    )
    session.commit()
    return session


def test_body_metric_allows_partial_measurements():
    payload = BodyMetricIn(
        client_id="metric-1",
        measured_at=datetime.now(timezone.utc),
        weight_kg=72.4,
    )
    assert payload.weight_kg == 72.4
    assert payload.body_fat_pct is None
    assert payload.waist_cm is None


def test_body_metric_requires_at_least_one_measurement():
    with pytest.raises(ValidationError):
        BodyMetricIn(
            client_id="metric-2",
            measured_at=datetime.now(timezone.utc),
        )


def test_partial_metric_updates_only_provided_profile_cache():
    db = _session()
    metric = upsert_metric(
        db,
        "u1",
        BodyMetricIn(
            client_id="metric-3",
            measured_at=datetime.now(timezone.utc),
            weight_kg=70.5,
        ),
    )
    profile = db.get(Profile, "u1")
    assert metric.weight_kg == 70.5
    assert metric.body_fat_pct is None
    assert profile.weight_kg == 70.5
    assert profile.body_fat_pct == 20  # unchanged, not overwritten with None
    assert profile.waist_cm == 82

    db.add(
        BodyMetric(
            user_id="u1",
            client_id="metric-4",
            measured_at=datetime.now(timezone.utc),
            body_fat_pct=18.5,
        )
    )
    db.commit()
    recompute_profile_cache(db, "u1")
    db.commit()
    profile = db.get(Profile, "u1")
    assert profile.body_fat_pct == 18.5
    assert profile.weight_kg == 70.5


def test_delete_latest_metric_recomputes_cache():
    db = _session()
    upsert_metric(
        db,
        "u1",
        BodyMetricIn(
            client_id="old",
            measured_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
            weight_kg=75,
        ),
    )
    upsert_metric(
        db,
        "u1",
        BodyMetricIn(
            client_id="new",
            measured_at=datetime(2026, 2, 1, tzinfo=timezone.utc),
            weight_kg=70,
        ),
    )
    assert db.get(Profile, "u1").weight_kg == 70

    assert delete_metric(db, "u1", "new") is True
    assert db.get(Profile, "u1").weight_kg == 75
