"""App Store Server API subscription lookup and entitlement reconciliation.

The client-sync path only sees transactions the app forwards. This module asks
Apple directly so refunds, revocations and renewals still reconcile when the
app is closed or a notification was missed. It is intentionally disabled until
Key ID / Issuer ID / p8 credentials are configured: missing credentials must
fail with a clear 503 instead of pretending reconciliation succeeded.

No HTTP call is made inside a database transaction. Each snapshot is written
with the existing idempotent StoreKit ledger helpers.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from urllib.parse import quote

import httpx
import jwt
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import User, UserEntitlement, utcnow
from . import app_store

PRODUCTION_BASE_URL = "https://api.storekit.itunes.apple.com"
SANDBOX_BASE_URL = "https://api.storekit-sandbox.itunes.apple.com"
CLIENT_ASSERTION_LIFETIME_SECONDS = 300
HTTP_TIMEOUT_SECONDS = 20.0
ACTIVE_STATUSES = frozenset({1, 3, 4})
REVOKED_STATUS = 5


class AppStoreAPIConfigurationError(RuntimeError):
    """Raised when App Store Server API credentials are missing."""


class AppStoreAPIError(RuntimeError):
    """Raised when Apple rejects or fails a subscription lookup."""


@dataclass(frozen=True)
class SubscriptionSnapshot:
    transaction: app_store.VerifiedTransaction
    status: int

    @property
    def revoked(self) -> bool:
        return self.status == REVOKED_STATUS or bool(
            self.transaction.raw.get("revocationDate")
        )


def _private_key() -> bytes:
    inline = settings.app_store_api_private_key.strip()
    if inline:
        return inline.replace("\\n", "\n").encode()
    path = settings.app_store_api_private_key_path.strip()
    if not path:
        raise AppStoreAPIConfigurationError(
            "未配置 App Store Server API 私钥（p8）"
        )
    try:
        return Path(path).read_bytes()
    except OSError as exc:
        raise AppStoreAPIConfigurationError(
            f"无法读取 App Store Server API 私钥：{exc}"
        ) from exc


def is_configured() -> bool:
    return bool(
        settings.app_store_api_key_id.strip()
        and settings.app_store_api_issuer_id.strip()
        and (
            settings.app_store_api_private_key.strip()
            or settings.app_store_api_private_key_path.strip()
        )
    )


def _require_configured() -> None:
    if not is_configured():
        raise AppStoreAPIConfigurationError(
            "App Store Server API 未配置 Key ID / Issuer ID / p8 私钥"
        )


def client_assertion(*, now: datetime | None = None) -> str:
    _require_configured()
    current = now or utcnow()
    issued_at = int(current.timestamp())
    claims = {
        "iss": settings.app_store_api_issuer_id,
        "iat": issued_at,
        "exp": issued_at + CLIENT_ASSERTION_LIFETIME_SECONDS,
        "aud": "appstoreconnect-v1",
        "bid": settings.app_store_bundle_id,
    }
    return jwt.encode(
        claims,
        _private_key(),
        algorithm="ES256",
        headers={"kid": settings.app_store_api_key_id},
    )


def _base_url() -> str:
    override = settings.app_store_api_base_url.strip()
    if override:
        return override.rstrip("/")
    if settings.app_store_api_environment.strip().lower() == "sandbox":
        return SANDBOX_BASE_URL
    return PRODUCTION_BASE_URL


def _get_json(path: str, *, client: httpx.Client | None = None) -> dict:
    _require_configured()
    headers = {"Authorization": f"Bearer {client_assertion()}"}
    owns_client = client is None
    active_client = client or httpx.Client(timeout=HTTP_TIMEOUT_SECONDS)
    try:
        response = active_client.get(_base_url() + path, headers=headers)
    except httpx.HTTPError as exc:
        raise AppStoreAPIError(f"App Store Server API 请求失败：{exc}") from exc
    finally:
        if owns_client:
            active_client.close()

    if response.status_code in {401, 403}:
        raise AppStoreAPIError("App Store Server API 鉴权失败，请检查 Key/Issuer/p8")
    if response.status_code == 404:
        raise AppStoreAPIError("App Store 未找到该订阅交易")
    if response.status_code == 429:
        raise AppStoreAPIError("App Store Server API 限流，请稍后重试")
    if response.status_code >= 400:
        raise AppStoreAPIError(
            f"App Store Server API 返回 {response.status_code}"
        )
    try:
        payload = response.json()
    except ValueError as exc:
        raise AppStoreAPIError("App Store Server API 返回了非 JSON 响应") from exc
    if not isinstance(payload, dict):
        raise AppStoreAPIError("App Store Server API 响应结构不正确")
    return payload


def _snapshots_from_payload(payload: dict) -> list[SubscriptionSnapshot]:
    groups = payload.get("data")
    if not isinstance(groups, list):
        raise AppStoreAPIError("App Store Server API 响应缺少 data")

    snapshots: list[SubscriptionSnapshot] = []
    for group in groups:
        if not isinstance(group, dict):
            continue
        transactions = group.get("lastTransactions")
        if not isinstance(transactions, list):
            continue
        for item in transactions:
            if not isinstance(item, dict):
                continue
            signed = item.get("signedTransactionInfo")
            if not isinstance(signed, str):
                continue
            try:
                transaction = app_store.verify_signed_transaction(
                    signed,
                    allow_revoked=True,
                    require_active=False,
                )
            except app_store.StoreKitError as exc:
                raise AppStoreAPIError(
                    f"Apple 返回的订阅交易校验失败：{exc}"
                ) from exc
            snapshots.append(
                SubscriptionSnapshot(
                    transaction=transaction,
                    status=int(item.get("status") or 0),
                )
            )
    if not snapshots:
        raise AppStoreAPIError("App Store 未返回可校验的订阅交易")
    snapshots.sort(key=lambda item: item.transaction.expires_date, reverse=True)
    return snapshots


def lookup_subscription(
    transaction_id: str,
    *,
    client: httpx.Client | None = None,
) -> list[SubscriptionSnapshot]:
    _require_configured()
    cleaned = transaction_id.strip()
    if not cleaned:
        raise AppStoreAPIError("缺少 transactionId")
    payload = _get_json(
        f"/inApps/v1/subscriptions/{quote(cleaned, safe='')}",
        client=client,
    )
    return _snapshots_from_payload(payload)


def _user_for_transaction(
    db: Session,
    transaction: app_store.VerifiedTransaction,
) -> str | None:
    token = app_store.transaction_account_token(transaction)
    if token is not None and db.get(User, token) is not None:
        return token
    row = db.execute(
        select(UserEntitlement.user_id).where(
            UserEntitlement.source == "storekit",
            UserEntitlement.source_ref.in_(
                [
                    transaction.transaction_id,
                    transaction.original_transaction_id,
                ]
            ),
        )
        .limit(1)
    ).scalar_one_or_none()
    return row


def _apply_snapshot(
    db: Session,
    snapshot: SubscriptionSnapshot,
) -> dict:
    transaction = snapshot.transaction
    user_id = _user_for_transaction(db, transaction)
    if user_id is None:
        return {
            "transaction_id": transaction.transaction_id,
            "state": "unbound",
        }
    if snapshot.revoked:
        revoked = app_store.revoke_transaction(db, transaction.transaction_id)
        return {
            "transaction_id": transaction.transaction_id,
            "state": "revoked" if revoked else "already_revoked",
            "user_id": user_id,
        }
    if (
        snapshot.status in ACTIVE_STATUSES
        and transaction.expires_date > utcnow()
    ):
        app_store.record_entitlement(db, user_id, transaction)
        return {
            "transaction_id": transaction.transaction_id,
            "state": "active",
            "user_id": user_id,
        }
    return {
        "transaction_id": transaction.transaction_id,
        "state": "expired",
        "user_id": user_id,
    }


def reconcile_transaction(
    db: Session,
    transaction_id: str,
    *,
    client: httpx.Client | None = None,
) -> dict:
    snapshots = lookup_subscription(transaction_id, client=client)
    results = [_apply_snapshot(db, snapshot) for snapshot in snapshots]
    return {
        "transaction_id": transaction_id,
        "checked_at": utcnow().isoformat(),
        "snapshots": len(snapshots),
        "results": results,
    }


def tracked_transaction_ids(db: Session, *, limit: int = 200) -> list[str]:
    rows = (
        db.execute(
            select(UserEntitlement.source_ref)
            .where(UserEntitlement.source == "storekit")
            .order_by(UserEntitlement.expires_at.desc())
            .limit(max(1, limit))
        )
        .scalars()
        .all()
    )
    return sorted({row for row in rows if row})


def reconcile_tracked(
    db: Session,
    *,
    limit: int = 200,
    client: httpx.Client | None = None,
) -> dict:
    checked: list[dict] = []
    errors: list[dict] = []
    for transaction_id in tracked_transaction_ids(db, limit=limit):
        try:
            checked.append(
                reconcile_transaction(db, transaction_id, client=client)
            )
        except AppStoreAPIError as exc:
            # One bad transaction must not stop the rest of the nightly sweep.
            errors.append(
                {"transaction_id": transaction_id, "message": str(exc)}
            )
    return {"checked": checked, "errors": errors}
