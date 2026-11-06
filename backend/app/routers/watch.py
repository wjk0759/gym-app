from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request
from sqlalchemy import select

from ..deps import CurrentUser, DBSession
from ..models import AuthSession, utcnow
from ..schemas import WatchSessionIn
from ..services import access, auth
from ..services.queries import active_program
from ..services.serializers import serialize_program_day
from ..services.watch import media_for_day

router = APIRouter(prefix="/watch", tags=["watch"])


@router.post("/session")
def create_session(
    payload: WatchSessionIn,
    request: Request,
    user_id: CurrentUser,
    db: DBSession,
):
    """Exchange the phone login for a standalone watch session.

    The watch keeps its own refresh token so token rotation on either device
    cannot invalidate the other. The endpoint is Pro-gated; a free account can
    authenticate the watch shell but cannot start training through bootstrap.
    """
    access.require_feature(db, user_id, access.FEATURE_WATCH_TRAINING)
    meta = {
        "ip": request.client.host if request.client else None,
        "user_agent": request.headers.get("user-agent"),
        "device_id": payload.device_id.strip(),
        "device_name": payload.device_name,
    }
    return auth.issue_watch_session(
        db,
        user_id,
        payload.device_id,
        payload.device_name,
        meta,
    )


@router.delete("/session")
def revoke_watch_sessions(user_id: CurrentUser, db: DBSession):
    """Revoke every watch session for this account on phone logout."""
    rows = db.execute(
        select(AuthSession).where(
            AuthSession.user_id == user_id,
            AuthSession.client_type == "watch",
            AuthSession.revoked_at.is_(None),
        )
    ).scalars()
    now = utcnow()
    revoked = 0
    for row in rows:
        row.revoked_at = now
        revoked += 1
    db.commit()
    return {"ok": True, "revoked": revoked}


@router.get("/bootstrap")
def bootstrap(day_id: str, user_id: CurrentUser, db: DBSession):
    """Return the minimum snapshot a watch needs before leaving the phone.

    Media is intentionally resolved separately so a missing video never blocks
    the training session. The endpoint is Pro-gated even when the phone already
    cached the plan.
    """
    access.require_feature(db, user_id, access.FEATURE_WATCH_TRAINING)
    program = active_program(db, user_id)
    if program is None:
        raise HTTPException(status_code=404, detail="还没有训练计划")
    day = next((item for item in program.days if item.id == day_id), None)
    if day is None:
        raise HTTPException(status_code=404, detail="训练日不存在")
    return {
        "server_time": utcnow().isoformat(),
        "access": access.access_snapshot(db, user_id),
        "program_day": serialize_program_day(day),
        "media": media_for_day(db, user_id, day),
    }
