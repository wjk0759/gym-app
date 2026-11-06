from __future__ import annotations

from fastapi import APIRouter, HTTPException

from ..deps import CurrentUser, DBSession
from ..models import utcnow
from ..services import access
from ..services.queries import active_program
from ..services.serializers import serialize_program_day
from ..services.watch import media_for_day

router = APIRouter(prefix="/watch", tags=["watch"])


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
