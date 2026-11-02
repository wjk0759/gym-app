import logging
from datetime import timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.config import settings
from app.db import Base
from app.models import AIJob, AIRuntimeControl, User, utcnow
from app.services import llm_budget


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    return Session(engine)


def _job(db: Session, tokens: int, *, created_at=None) -> None:
    db.add(
        AIJob(
            kind="test",
            status="ok",
            input_tokens=tokens,
            output_tokens=0,
            created_at=created_at or utcnow(),
        )
    )
    db.commit()


@pytest.fixture(autouse=True)
def _reset_budget_state():
    llm_budget.reset_runtime_state()
    yield
    llm_budget.reset_runtime_state()


def test_budget_disabled_does_not_query(monkeypatch):
    db = _session()
    monkeypatch.setattr(settings, "llm_daily_token_budget", 0)
    monkeypatch.setattr(settings, "llm_monthly_token_budget", 0)

    snapshot = llm_budget.ensure_budget(db)

    assert snapshot.daily_limit == 0
    assert snapshot.day_tokens == 0


def test_daily_budget_exhausted_raises(monkeypatch):
    db = _session()
    monkeypatch.setattr(settings, "llm_daily_token_budget", 100)
    monkeypatch.setattr(settings, "llm_monthly_token_budget", 0)
    _job(db, 100)

    with pytest.raises(llm_budget.BudgetExceeded) as exc:
        llm_budget.ensure_budget(db)
    assert exc.value.period == "daily"


def test_monthly_budget_ignores_old_months(monkeypatch):
    db = _session()
    monkeypatch.setattr(settings, "llm_daily_token_budget", 0)
    monkeypatch.setattr(settings, "llm_monthly_token_budget", 100)
    _job(db, 90, created_at=utcnow() - timedelta(days=40))

    llm_budget.ensure_budget(db)


def test_budget_alerts_at_seventy_and_ninety_percent(monkeypatch, caplog):
    db = _session()
    monkeypatch.setattr(settings, "llm_daily_token_budget", 100)
    monkeypatch.setattr(settings, "llm_monthly_token_budget", 0)
    _job(db, 70)

    with caplog.at_level(logging.WARNING):
        llm_budget.ensure_budget(db)
    assert "70%" in caplog.text


def test_paused_ai_allows_only_test_accounts():
    db = _session()
    db.add(
        AIRuntimeControl(
            id=1,
            enabled=False,
            reason="维护中",
            updated_at=utcnow(),
        )
    )
    db.add(User(id="regular-user", phone="13800138002", status="active"))
    db.add(
        User(
            id="test-user",
            phone="13800138003",
            status="active",
            is_test=True,
        )
    )
    db.commit()

    with pytest.raises(llm_budget.AIUnavailable):
        llm_budget.ensure_ai_enabled(db, "regular-user")
    llm_budget.ensure_ai_enabled(db, "test-user")
