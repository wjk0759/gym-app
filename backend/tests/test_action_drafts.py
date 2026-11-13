from datetime import date

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import AgentActionDraft, ChatSession, Profile, User
from app.services.action_drafts import (
    answer_food_draft,
    cancel_draft,
    create_food_draft,
    get_active_draft,
)
from app.services.food_text import resolve_food_rules


@pytest.fixture()
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
    session = Session()
    session.add(User(id="user-1", phone="13800138000", status="active"))
    session.add(
        Profile(
            user_id="user-1",
            nickname="小林",
            sex="male",
            birth_date=date(1996, 1, 1),
            height_cm=178,
            weight_kg=72,
            weekly_days=3,
        )
    )
    session.add(ChatSession(id="session-1", user_id="user-1", title="测试"))
    session.commit()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


def test_food_draft_asks_for_implicit_drink_portion(db):
    resolution = resolve_food_rules("奶茶")
    assert resolution.missing_slots

    draft = create_food_draft(
        db,
        "user-1",
        "session-1",
        date="2026-11-13",
        meal="lunch",
        raw_text="奶茶",
        resolution=resolution.as_dict(),
    )
    assert draft is not None
    assert get_active_draft(db, "user-1", "session-1").id == draft.id

    result = answer_food_draft(
        db, "user-1", "session-1", "250ml"
    )

    assert result["ready"] is True
    assert result["items"][0]["grams"] == 250
    assert result["items"][0]["kcal"] == 175
    assert get_active_draft(db, "user-1", "session-1") is None


def test_food_draft_accepts_affirmative_and_cancels(db):
    resolution = resolve_food_rules("奶茶")
    create_food_draft(
        db,
        "user-1",
        "session-1",
        date="2026-11-13",
        meal="lunch",
        raw_text="奶茶",
        resolution=resolution.as_dict(),
    )

    result = answer_food_draft(db, "user-1", "session-1", "对")
    assert result["ready"] is True
    assert result["items"][0]["grams"] == 500

    second = create_food_draft(
        db,
        "user-1",
        "session-1",
        date="2026-11-13",
        meal="snack",
        raw_text="奶茶",
        resolution=resolve_food_rules("奶茶").as_dict(),
    )
    assert cancel_draft(db, "user-1", second.id) is True
    assert get_active_draft(db, "user-1", "session-1") is None
    assert db.query(AgentActionDraft).count() == 2
