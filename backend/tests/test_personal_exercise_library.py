from app.models import Exercise
from app.services.plan_generator import _allowed_exercises


class _FakeResult:
    def __init__(self, rows):
        self._rows = rows

    def scalars(self):
        return self

    def all(self):
        return self._rows


class _FakeDB:
    def __init__(self, rows):
        self._rows = rows

    def execute(self, _stmt):
        return _FakeResult(self._rows)


def _exercise(slug, equipment="dumbbell", contraindications=None):
    return Exercise(
        slug=slug,
        name_zh=slug,
        muscle_group="chest",
        equipment=equipment,
        is_compound=True,
        difficulty=1,
        contraindications=contraindications or [],
        is_active=True,
        plan_eligible=True,
    )


def test_plan_pool_wins_when_it_has_enough():
    rows = [_exercise(f"pool-{i}") for i in range(10)] + [_exercise("other-x")]
    picked = _allowed_exercises(
        _FakeDB(rows), ["machine"], [], None, [f"pool-{i}" for i in range(10)]
    )
    assert {e.slug for e in picked} == {f"pool-{i}" for i in range(10)}


def test_plan_pool_falls_back_when_too_small():
    rows = [_exercise(f"pool-{i}") for i in range(3)] + [
        _exercise("machine-1", "machine")
    ]
    picked = _allowed_exercises(
        _FakeDB(rows), ["machine"], [], None, [f"pool-{i}" for i in range(3)]
    )
    assert "machine-1" in {e.slug for e in picked}


def test_strict_equipment_keeps_small_pool_without_fallback():
    rows = [_exercise(f"pool-{i}") for i in range(3)] + [
        _exercise("machine-1", "machine")
    ]
    picked = _allowed_exercises(
        _FakeDB(rows),
        ["machine"],
        [],
        None,
        [f"pool-{i}" for i in range(3)],
        True,
    )
    assert {e.slug for e in picked} == {f"pool-{i}" for i in range(3)}


def test_plan_pool_respects_injuries():
    rows = [
        _exercise(f"pool-{i}", contraindications=(["knee_pain"] if i == 0 else []))
        for i in range(10)
    ]
    picked = _allowed_exercises(
        _FakeDB(rows), ["machine"], ["膝"], None, [f"pool-{i}" for i in range(10)]
    )
    assert "pool-0" not in {e.slug for e in picked}
    assert len(picked) == 9
