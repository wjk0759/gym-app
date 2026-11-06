import pytest
from pydantic import ValidationError

from app.schemas import WorkoutIn


def test_workout_source_defaults_to_phone():
    payload = WorkoutIn(started_at="2026-11-07T10:00:00+08:00")
    assert payload.source == "phone"


def test_workout_source_accepts_watch_and_rejects_unknown():
    payload = WorkoutIn(
        started_at="2026-11-07T10:00:00+08:00",
        source="watch",
    )
    assert payload.source == "watch"
    with pytest.raises(ValidationError):
        WorkoutIn(
            started_at="2026-11-07T10:00:00+08:00",
            source="tablet",
        )
