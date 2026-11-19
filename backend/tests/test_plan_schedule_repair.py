"""Regression tests for the plan schedule repair date math."""

from datetime import date
from types import SimpleNamespace

from scripts.repair_plan_schedule import _corrected_date


def _program(start: date):
    return SimpleNamespace(start_date=start)


def _day(week_index: int, weekday: int):
    return SimpleNamespace(week_index=week_index, weekday=weekday)


def test_week_one_rotates_around_midweek_start():
    program = _program(date(2026, 11, 17))

    assert _corrected_date(program, _day(1, 1)) == date(2026, 11, 23)
    assert _corrected_date(program, _day(1, 3)) == date(2026, 11, 18)
    assert _corrected_date(program, _day(1, 5)) == date(2026, 11, 20)


def test_monday_start_keeps_calendar_weeks():
    program = _program(date(2026, 11, 16))

    assert _corrected_date(program, _day(1, 1)) == date(2026, 11, 16)
    assert _corrected_date(program, _day(1, 3)) == date(2026, 11, 18)
    assert _corrected_date(program, _day(2, 1)) == date(2026, 11, 23)


def test_week_two_keeps_the_same_rotation():
    program = _program(date(2026, 11, 17))

    assert _corrected_date(program, _day(2, 1)) == date(2026, 11, 30)
    assert _corrected_date(program, _day(2, 3)) == date(2026, 11, 25)
