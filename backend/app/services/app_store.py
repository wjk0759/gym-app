"""StoreKit 2 signed-transaction verification and entitlement sync.

The iOS client sends the JWS returned by StoreKit. We verify Apple's x5c
certificate chain, pin the Apple Root CA G3 fingerprint, validate the ES256
signature and then check bundle/product/expiry claims before writing the Pro
ledger. No payment logic trusts client-side booleans.

The same verifier also accepts App Store Server Notifications V2, so refunds,
revocations and renewals update the ledger even when the app is closed.
"""

from __future__ import annotations

import base64
import hashlib
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path

from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import Encoding
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..config import settings
from ..models import User, UserEntitlement, utcnow

APPLE_ROOT_CA_G3_SHA256 = (
    "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179"
)
APPLE_ROOT_CA_G3_PATH = (
    Path(__file__).resolve().parent.parent / "certs" / "AppleRootCA-G3.cer"
)
PRODUCT_TYPE_SUBSCRIPTION = "Auto-Renewable Subscription"
REVOKE_NOTIFICATIONS = frozenset({"REFUND", "REVOKE"})
RENEW_NOTIFICATIONS = frozenset(
    {"SUBSCRIBED", "DID_RENEW", "OFFER_REDEEMED", "ONE_TIME_CHARGE"}
)


class StoreKitError(ValueError):
    pass


@dataclass(frozen=True)
class VerifiedTransaction:
    transaction_id: str
    original_transaction_id: str
    product_id: str
    purchase_date: datetime
    expires_date: datetime
    environment: str
    raw: dict


def _b64url(segment: str) -> bytes:
    padded = segment + "=" * (-len(segment) % 4)
    try:
        return base64.urlsafe_b64decode(padded)
    except Exception as exc:  # noqa: BLE001 - malformed token must be a 400
        raise StoreKitError("交易签名格式不正确") from exc


def _json_segment(segment: str, label: str) -> dict:
    try:
        value = json.loads(_b64url(segment))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise StoreKitError(f"{label} 不是合法 JSON") from exc
    if not isinstance(value, dict):
        raise StoreKitError(f"{label} 结构不正确")
    return value


@lru_cache(maxsize=1)
def _apple_root() -> x509.Certificate:
    try:
        return x509.load_der_x509_certificate(APPLE_ROOT_CA_G3_PATH.read_bytes())
    except (OSError, ValueError) as exc:
        raise StoreKitError("Apple 根证书不可用") from exc


def _ensure_valid(certificate: x509.Certificate, label: str) -> None:
    now = utcnow()
    if not (
        certificate.not_valid_before_utc
        <= now
        <= certificate.not_valid_after_utc
    ):
        raise StoreKitError(f"{label} 证书不在有效期内")


def _verify_certificate(child: x509.Certificate, issuer: x509.Certificate) -> None:
    try:
        issuer.public_key().verify(
            child.signature,
            child.tbs_certificate_bytes,
            ec.ECDSA(child.signature_hash_algorithm),
        )
    except InvalidSignature as exc:
        raise StoreKitError("Apple 证书链校验失败") from exc


def _certificates(header: dict) -> list[x509.Certificate]:
    chain = header.get("x5c")
    if not isinstance(chain, list) or len(chain) < 2:
        raise StoreKitError("交易缺少 Apple 证书链")
    try:
        certificates = [
            x509.load_der_x509_certificate(_b64url(item)) for item in chain
        ]
    except (TypeError, ValueError) as exc:
        raise StoreKitError("Apple 证书链格式不正确") from exc
    if len(certificates) >= 3:
        fingerprint = hashlib.sha256(
            certificates[-1].public_bytes(encoding=Encoding.DER)
        ).hexdigest()
        if fingerprint != APPLE_ROOT_CA_G3_SHA256:
            raise StoreKitError("Apple 根证书指纹不匹配")
    return certificates


def _verify_jws_signature(
    signing_input: bytes,
    signature: bytes,
    certificate: x509.Certificate,
) -> None:
    try:
        certificate.public_key().verify(
            signature,
            signing_input,
            ec.ECDSA(hashes.SHA256()),
        )
    except (InvalidSignature, TypeError) as exc:
        raise StoreKitError("交易签名校验失败") from exc


def _verified_payload(signed_payload: str) -> dict:
    parts = signed_payload.split(".")
    if len(parts) != 3:
        raise StoreKitError("交易签名格式不正确")
    header_segment, payload_segment, signature_segment = parts
    header = _json_segment(header_segment, "交易头")
    payload = _json_segment(payload_segment, "交易内容")
    if header.get("alg") != "ES256":
        raise StoreKitError("交易签名算法不受支持")

    certificates = _certificates(header)
    leaf, intermediate = certificates[0], certificates[1]
    root = _apple_root()
    for certificate, label in (
        (leaf, "叶子"),
        (intermediate, "中间"),
        (root, "根"),
    ):
        _ensure_valid(certificate, label)
    _verify_certificate(leaf, intermediate)
    _verify_certificate(intermediate, root)
    _verify_jws_signature(
        f"{header_segment}.{payload_segment}".encode(),
        _b64url(signature_segment),
        leaf,
    )
    return payload


def _millis_to_datetime(value: object, label: str) -> datetime:
    if not isinstance(value, (int, float)):
        raise StoreKitError(f"{label} 缺失")
    try:
        return datetime.fromtimestamp(float(value) / 1000, tz=timezone.utc)
    except (OverflowError, OSError, ValueError) as exc:
        raise StoreKitError(f"{label} 时间不正确") from exc


def verify_signed_transaction(
    signed_transaction: str,
    *,
    allow_revoked: bool = False,
    require_active: bool = True,
) -> VerifiedTransaction:
    payload = _verified_payload(signed_transaction)
    if payload.get("bundleId") != settings.app_store_bundle_id:
        raise StoreKitError("交易 Bundle ID 不匹配")
    allowed_products = {
        item.strip()
        for item in settings.storekit_product_ids.split(",")
        if item.strip()
    }
    product_id = str(payload.get("productId") or "")
    if product_id not in allowed_products:
        raise StoreKitError("交易商品不在允许列表")
    if payload.get("type") != PRODUCT_TYPE_SUBSCRIPTION:
        raise StoreKitError("交易不是自动续期订阅")
    if payload.get("revocationDate") and not allow_revoked:
        raise StoreKitError("交易已退款或撤销")
    environment = str(payload.get("environment") or "")
    allowed_environments = {
        item.strip()
        for item in settings.storekit_allowed_environments.split(",")
        if item.strip()
    }
    if environment not in allowed_environments:
        raise StoreKitError("交易环境不受支持")

    transaction_id = str(payload.get("transactionId") or "")
    if not transaction_id:
        raise StoreKitError("交易缺少 transactionId")
    expires_date = _millis_to_datetime(payload.get("expiresDate"), "expiresDate")
    if require_active and expires_date <= utcnow():
        raise StoreKitError("订阅已过期")
    purchase_date = _millis_to_datetime(
        payload.get("purchaseDate") or payload.get("signedDate"),
        "purchaseDate",
    )
    return VerifiedTransaction(
        transaction_id=transaction_id,
        original_transaction_id=str(
            payload.get("originalTransactionId") or transaction_id
        ),
        product_id=product_id,
        purchase_date=purchase_date,
        expires_date=expires_date,
        environment=environment,
        raw=payload,
    )


def verify_notification(signed_payload: str) -> dict:
    payload = _verified_payload(signed_payload)
    data = payload.get("data")
    if not isinstance(data, dict):
        raise StoreKitError("通知缺少 data")
    if data.get("bundleId") != settings.app_store_bundle_id:
        raise StoreKitError("通知 Bundle ID 不匹配")
    return payload


def record_entitlement(
    db: Session,
    user_id: str,
    transaction: VerifiedTransaction,
) -> None:
    existing = db.execute(
        select(UserEntitlement.id).where(
            UserEntitlement.source == "storekit",
            UserEntitlement.source_ref == transaction.transaction_id,
        )
    ).scalar_one_or_none()
    if existing is not None:
        return
    db.add(
        UserEntitlement(
            user_id=user_id,
            plan_code="pro",
            source="storekit",
            source_ref=transaction.transaction_id,
            starts_at=transaction.purchase_date,
            expires_at=transaction.expires_date,
            reason="Apple IAP",
            metadata_json={
                "product_id": transaction.product_id,
                "environment": transaction.environment,
                "original_transaction_id": transaction.original_transaction_id,
            },
        )
    )
    try:
        db.commit()
    except IntegrityError:
        # A retried JWS or a notification race already recorded it.
        db.rollback()


def revoke_transaction(db: Session, transaction_id: str) -> bool:
    row = db.execute(
        select(UserEntitlement)
        .where(
            UserEntitlement.source == "storekit",
            UserEntitlement.source_ref == transaction_id,
            UserEntitlement.revoked_at.is_(None),
        )
        .with_for_update()
    ).scalar_one_or_none()
    if row is None:
        return False
    row.revoked_at = utcnow()
    db.commit()
    return True


def _notification_transaction_id(payload: dict) -> str | None:
    data = payload.get("data") or {}
    if isinstance(data.get("transactionId"), str):
        return data["transactionId"]
    signed_transaction = data.get("signedTransactionInfo")
    if not isinstance(signed_transaction, str):
        return None
    return verify_signed_transaction(
        signed_transaction,
        allow_revoked=True,
        require_active=False,
    ).transaction_id


def apply_notification(db: Session, payload: dict) -> dict:
    notification_type = str(payload.get("notificationType") or "")
    data = payload.get("data") or {}
    if notification_type in REVOKE_NOTIFICATIONS:
        transaction_id = _notification_transaction_id(payload)
        revoked = bool(transaction_id) and revoke_transaction(db, transaction_id)
        return {"handled": notification_type, "revoked": revoked}
    if notification_type in RENEW_NOTIFICATIONS:
        signed_transaction = data.get("signedTransactionInfo")
        if not isinstance(signed_transaction, str):
            raise StoreKitError("续订通知缺少交易信息")
        transaction = verify_signed_transaction(signed_transaction)
        user_id = db.execute(
            select(UserEntitlement.user_id).where(
                UserEntitlement.source == "storekit",
                UserEntitlement.source_ref
                == transaction.original_transaction_id,
            )
        ).scalar_one_or_none()
        if user_id is None:
            token = transaction.raw.get("appAccountToken")
            if isinstance(token, str):
                user_id = db.execute(
                    select(User.id).where(User.id == token)
                ).scalar_one_or_none()
        if user_id is None:
            raise StoreKitError("找不到订阅所属用户")
        record_entitlement(db, user_id, transaction)
        return {"handled": notification_type, "recorded": True}
    return {"handled": "ignored", "type": notification_type}
