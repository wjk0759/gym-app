from fastapi import APIRouter

from ..deps import CurrentUser, DBSession
from ..schemas import SyncIn
from ..services.user_sync import apply_sync, sync_snapshot

router = APIRouter(prefix="/sync", tags=["sync"])


@router.get("")
def read_sync(user_id: CurrentUser, db: DBSession):
    snapshot = sync_snapshot(db, user_id)
    db.commit()
    return snapshot


@router.post("")
def write_sync(payload: SyncIn, user_id: CurrentUser, db: DBSession):
    return apply_sync(db, user_id, payload)
