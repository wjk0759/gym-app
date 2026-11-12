import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import ChatMessage, ChatSession, CoachFeedback, User
from app.services.coach_feedback import save_feedback


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
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture()
def seeded(db):
    db.add_all([User(id="user-1"), User(id="user-2")])
    db.add(ChatSession(id="session-1", user_id="user-1"))
    db.add(
        ChatMessage(
            id="assistant-1",
            session_id="session-1",
            role="assistant",
            content="今天练腿。",
        )
    )
    db.add(
        ChatMessage(
            id="user-1-message",
            session_id="session-1",
            role="user",
            content="练什么？",
        )
    )
    db.commit()


def test_feedback_is_created_and_updated(db, seeded):
    first = save_feedback(
        db,
        "user-1",
        message_id="assistant-1",
        rating="up",
    )
    assert first.rating == "up"
    assert first.reason is None

    second = save_feedback(
        db,
        "user-1",
        message_id="assistant-1",
        rating="down",
        reason="inaccurate",
        comment="重量不对",
    )
    assert second.id == first.id
    assert second.rating == "down"
    assert second.reason == "inaccurate"

    rows = db.execute(select(CoachFeedback)).scalars().all()
    assert len(rows) == 1


def test_feedback_rejects_other_users_and_user_messages(db, seeded):
    with pytest.raises(LookupError):
        save_feedback(
            db,
            "user-2",
            message_id="assistant-1",
            rating="up",
        )
    with pytest.raises(LookupError):
        save_feedback(
            db,
            "user-1",
            message_id="user-1-message",
            rating="up",
        )


def test_feedback_rejects_unknown_reason(db, seeded):
    with pytest.raises(ValueError):
        save_feedback(
            db,
            "user-1",
            message_id="assistant-1",
            rating="down",
            reason="because",
        )
