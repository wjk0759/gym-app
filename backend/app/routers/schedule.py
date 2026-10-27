from fastapi import APIRouter, Query

from ..deps import CurrentUser, DBSession
from ..schemas import ScheduleSyncIn
from ..services.schedule import get_schedule, sync_schedule

router = APIRouter(prefix="/schedule", tags=["schedule"])


@router.get("")
def read_schedule(
    user_id: CurrentUser,
    db: DBSession,
    plan_id: str = Query(min_length=1, max_length=36),
):
    return get_schedule(db, user_id, plan_id)


@router.put("")
def write_schedule(
    payload: ScheduleSyncIn,
    user_id: CurrentUser,
    db: DBSession,
):
    return sync_schedule(db, user_id, payload)
