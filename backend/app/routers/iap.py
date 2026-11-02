import secrets

from fastapi import APIRouter, Header, HTTPException

from ..config import settings
from ..deps import DBSession
from ..schemas import StoreKitNotificationIn, StoreKitReconcileIn
from ..services import app_store, app_store_api

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


@router.post("/app-store/reconcile")
def reconcile_storekit_subscriptions(
    payload: StoreKitReconcileIn,
    db: DBSession,
    x_admin_token: str | None = Header(default=None, alias="X-Admin-Token"),
):
    """Reconcile subscription ledger rows with App Store Server API.

    Triggered by the admin server or a scheduled job. Missing credentials or
    tokens return 503; Apple-side failures are surfaced instead of pretending
    the ledger is up to date.
    """
    expected = settings.app_store_reconcile_token.strip()
    if not expected:
        raise HTTPException(
            status_code=503,
            detail={
                "code": "APP_STORE_RECONCILE_NOT_CONFIGURED",
                "message": "未配置对账访问令牌",
            },
        )
    if not x_admin_token or not secrets.compare_digest(
        x_admin_token, expected
    ):
        raise HTTPException(
            status_code=401,
            detail={
                "code": "UNAUTHORIZED",
                "message": "对账令牌不正确",
            },
        )
    if not app_store_api.is_configured():
        raise HTTPException(
            status_code=503,
            detail={
                "code": "APP_STORE_API_NOT_CONFIGURED",
                "message": "App Store Server API 凭据未配置",
            },
        )

    try:
        if payload.transaction_ids:
            checked = []
            errors = []
            for transaction_id in payload.transaction_ids:
                try:
                    checked.append(
                        app_store_api.reconcile_transaction(
                            db, transaction_id
                        )
                    )
                except app_store_api.AppStoreAPIError as exc:
                    errors.append(
                        {
                            "transaction_id": transaction_id,
                            "message": str(exc),
                        }
                    )
            return {"checked": checked, "errors": errors}
        return app_store_api.reconcile_tracked(db, limit=payload.limit)
    except app_store_api.AppStoreAPIConfigurationError as exc:
        raise HTTPException(
            status_code=503,
            detail={
                "code": "APP_STORE_API_NOT_CONFIGURED",
                "message": str(exc),
            },
        ) from exc
    except app_store_api.AppStoreAPIError as exc:
        raise HTTPException(
            status_code=502,
            detail={
                "code": "APP_STORE_API_ERROR",
                "message": str(exc),
            },
        ) from exc
