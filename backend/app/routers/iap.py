from fastapi import APIRouter, HTTPException

from ..deps import DBSession
from ..schemas import StoreKitNotificationIn
from ..services import app_store

router = APIRouter(prefix="/iap", tags=["iap"])


@router.post("/app-store/notifications")
def app_store_notifications(payload: StoreKitNotificationIn, db: DBSession):
    """App Store Server Notifications V2 webhook.

    Apple retries non-2xx responses, so malformed/unknown payloads return 400
    and processing failures return 500. The ledger update is idempotent.
    """
    try:
        notification = app_store.verify_notification(payload.signed_payload)
        return app_store.apply_notification(db, notification)
    except app_store.StoreKitError as exc:
        raise HTTPException(
            status_code=400,
            detail={
                "code": "INVALID_STOREKIT_NOTIFICATION",
                "message": str(exc),
            },
        ) from exc
