"""First-party client telemetry.

The app batches a small number of funnel events and uploads them when the
network and auth token are available. Events are stored as domain events so
they share the existing audit pipeline and need no schema migration.
"""

from __future__ import annotations

import json
from typing import Any

from fastapi import APIRouter
from pydantic import BaseModel, Field

from ..deps import CurrentUser, DBSession
from ..services.coach_control.events import emit_event
from ..services.rate_limit import enforce as enforce_rate_limit

router = APIRouter(prefix="/telemetry", tags=["telemetry"])

# Keep the accepted vocabulary small so an authenticated client cannot use the
# endpoint as arbitrary storage. Unknown names are skipped, not retried.
ALLOWED_EVENTS = frozenset(
    {
        "app_open",
        "onboarding_completed",
        "paywall_shown",
        "workout_started",
        "coach_turn_completed",
        "coach_turn_failed",
        "coach_safety_block",
        "coach_pending_confirmed",
        "coach_pending_cancelled",
        "coach_pending_confirm_failed",
        "coach_action_undone",
        "coach_action_undo_failed",
    }
)
MAX_PROPERTIES_JSON = 1500


class ClientEventIn(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    properties: dict[str, Any] | None = None


class ClientEventBatchIn(BaseModel):
    events: list[ClientEventIn] = Field(min_length=1, max_length=20)


@router.post("/events")
def ingest_client_events(
    payload: ClientEventBatchIn,
    user_id: CurrentUser,
    db: DBSession,
):
    enforce_rate_limit(db, "client_events", user_id, 30, 60)
    accepted = 0
    for item in payload.events:
        if item.name not in ALLOWED_EVENTS:
            continue
        properties = item.properties or {}
        if len(json.dumps(properties, ensure_ascii=False)) > MAX_PROPERTIES_JSON:
            continue
        emit_event(
            db,
            user_id,
            "ClientEvent",
            entity_type="ios",
            payload={"name": item.name, "properties": properties},
        )
        accepted += 1
    db.commit()
    return {"ok": True, "accepted": accepted}
