from datetime import date, timedelta

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import (
    AgentPendingAction,
    ChatSession,
    Profile,
    User,
    utcnow,
)
from app.routers.agent import agent_pending_state, report_action_result
from app.schemas import AgentActionResultIn
from app.services.action_drafts import create_food_draft
from app.services.agent_pending import (
    latest_pending_action,
    pending_action_payload,
    pending_food_action_context,
    resolve_pending_action,
    store_pending_actions,
    update_pending_action,
)
from app.services.coach_actions.executor import execute_action
from app.services.food_text import resolve_food_rules


def _food_action(action_id: str = "action-1") -> dict:
    return {
        "id": action_id,
        "type": "log_food",
        "title": "记录饮食",
        "summary": "约 420 kcal",
        "requires_confirmation": True,
        "payload": {
            "date": "2026-11-14",
            "meal": "lunch",
            "items": [
                {
                    "name": "肉肠",
                    "grams": 180,
                    "portion": "约180g",
                    "kcal": 420,
                    "protein_g": 24,
                    "carbs_g": 6,
                    "fat_g": 32,
                }
            ],
        },
    }


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


def test_new_turn_supersedes_previous_pending_card(db):
    first = store_pending_actions(
        db, "user-1", "session-1", None, [_food_action("action-1")]
    )
    second = store_pending_actions(
        db, "user-1", "session-1", None, [_food_action("action-2")]
    )

    assert first is not None
    assert second is not None
    assert first.status == "superseded"
    latest = latest_pending_action(db, "user-1", "session-1")
    assert latest is not None
    assert latest.actions[0]["id"] == "action-2"


def test_turn_without_actions_clears_pending_card(db):
    store_pending_actions(
        db, "user-1", "session-1", None, [_food_action("action-1")]
    )

    store_pending_actions(db, "user-1", "session-1", None, [])

    assert latest_pending_action(db, "user-1", "session-1") is None


def test_expired_pending_card_is_not_returned(db):
    row = store_pending_actions(
        db, "user-1", "session-1", None, [_food_action("action-1")]
    )
    assert row is not None
    row.expires_at = utcnow() - timedelta(minutes=1)
    db.commit()

    assert latest_pending_action(db, "user-1", "session-1") is None
    assert db.get(AgentPendingAction, row.id).status == "expired"


def test_resolving_each_action_consumes_the_card(db):
    store_pending_actions(
        db,
        "user-1",
        "session-1",
        None,
        [_food_action("action-1"), _food_action("action-2")],
    )

    assert resolve_pending_action(db, "user-1", "action-1") is True
    row = latest_pending_action(db, "user-1", "session-1")
    assert row is not None
    assert [item["id"] for item in row.actions] == ["action-2"]

    assert resolve_pending_action(db, "user-1", "action-2") is True
    assert latest_pending_action(db, "user-1", "session-1") is None
    assert db.execute(select(AgentPendingAction)).scalar_one().status == "consumed"


def test_server_pending_food_context_uses_the_last_log_food_action(db):
    store_pending_actions(
        db,
        "user-1",
        "session-1",
        None,
        [_food_action("action-1"), _food_action("action-2")],
    )

    context = pending_food_action_context(db, "user-1", "session-1")

    assert context is not None
    assert context["id"] == "action-2"
    assert context["payload"]["items"][0]["grams"] == 180


def test_pending_state_route_restores_card_and_draft(db):
    store_pending_actions(
        db, "user-1", "session-1", None, [_food_action("action-1")]
    )
    draft = create_food_draft(
        db,
        "user-1",
        "session-1",
        date="2026-11-14",
        meal="dinner",
        raw_text="奶茶",
        resolution=resolve_food_rules("奶茶").as_dict(),
    )
    assert draft is not None

    state = agent_pending_state("user-1", db)

    assert state["session_id"] == "session-1"
    assert state["pending_action"]["actions"][0]["id"] == "action-1"
    assert state["pending_draft"]["id"] == draft.id


def test_pending_state_route_is_empty_without_pending_work(db):
    state = agent_pending_state("user-1", db)

    assert state == {
        "session_id": None,
        "pending_action": None,
        "pending_draft": None,
    }


def test_pending_state_route_restores_a_draft_without_a_card(db):
    draft = create_food_draft(
        db,
        "user-1",
        "session-1",
        date="2026-11-14",
        meal="dinner",
        raw_text="奶茶",
        resolution=resolve_food_rules("奶茶").as_dict(),
    )
    assert draft is not None

    state = agent_pending_state("user-1", db)

    assert state["session_id"] == "session-1"
    assert state["pending_action"] is None
    assert state["pending_draft"]["id"] == draft.id


def test_executing_an_action_consumes_its_pending_card(db):
    store_pending_actions(
        db, "user-1", "session-1", None, [_food_action("action-run")]
    )

    execute_action(
        db,
        "user-1",
        "action-run",
        "log_food",
        _food_action("action-run")["payload"],
    )

    row = db.execute(select(AgentPendingAction)).scalar_one()
    assert row.status == "consumed"
    assert latest_pending_action(db, "user-1") is None


def test_card_edits_are_persisted_for_other_devices(db):
    store_pending_actions(
        db, "user-1", "session-1", None, [_food_action("action-edit")]
    )

    updated = update_pending_action(
        db,
        "user-1",
        "action-edit",
        {
            "date": "2026-11-14",
            "meal": "lunch",
            "items": [{"name": "肉肠", "grams": 230, "kcal": 536.7}],
        },
        summary="约 537 kcal",
    )

    assert updated["summary"] == "约 537 kcal"
    context = pending_food_action_context(db, "user-1", "session-1")
    assert context["payload"]["items"][0]["grams"] == 230

    with pytest.raises(LookupError):
        update_pending_action(db, "user-1", "missing", {}, summary=None)


def test_reporting_a_rejected_action_consumes_the_card(db):
    store_pending_actions(
        db, "user-1", "session-1", None, [_food_action("action-reject")]
    )

    report_action_result(
        "action-reject",
        AgentActionResultIn(
            action_type="log_food",
            status="rejected",
            message="用户取消",
        ),
        "user-1",
        db,
    )

    assert latest_pending_action(db, "user-1", "session-1") is None


def test_pending_action_payload_exposes_run_and_expiry(db):
    row = store_pending_actions(
        db, "user-1", "session-1", None, [_food_action("action-1")]
    )
    assert row is not None

    payload = pending_action_payload(row)

    assert payload["run_id"] is None
    assert payload["actions"][0]["type"] == "log_food"
    assert payload["expires_at"] is not None
