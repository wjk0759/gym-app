"""First-party client telemetry.

The app batches a small number of funnel events and uploads them when the
network and auth token are available. Events are stored as domain events so
they share the existing audit pipeline and need no schema migration.
"""

from __future__ import annotations

import json
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from ..deps import CurrentUser, DBSession
from ..services.coach_control.events import emit_event
from ..services.rate_limit import enforce as enforce_rate_limit

router = APIRouter(prefix="/telemetry", tags=["telemetry"])


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
    enforce_rate_limit(db, "client_events", user_id, 60, 60)
    for item in payload.events:
        properties = item.properties or {}
        if len(json.dumps(properties, ensure_ascii=False)) > 4000:
            raise HTTPException(status_code=413, detail="事件属性过大")
        emit_event(
            db,
            user_id,
            "ClientEvent",
            entity_type="ios",
            payload={"name": item.name, "properties": properties},
        )
    db.commit()
    return {"ok": True, "accepted": len(payload.events)}
