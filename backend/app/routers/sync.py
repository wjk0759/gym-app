"""Small durable user-data sync: preferences, custom foods, favorites, dislikes, cycle.

Full-snapshot last-write-wins for small collections; large/photo data has its
own endpoints. `apply_sync` merges client payload into server rows.
"""

from fastapi import APIRouter, HTTPException
from sqlalchemy.exc import IntegrityError

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
    try:
        return apply_sync(db, user_id, payload)
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail={
                "code": "SYNC_CONFLICT",
                "message": "同步数据存在重复键，请重试。",
            },
        ) from exc
