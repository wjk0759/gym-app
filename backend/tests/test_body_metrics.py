from datetime import datetime, timezone

import pytest
from pydantic import ValidationError

from app.schemas import BodyMetricIn


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
