from datetime import datetime, timedelta, timezone

import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.config import settings
from app.db import Base
from app.models import User, UserEntitlement
from app.routers import iap
from app.schemas import StoreKitReconcileIn
from app.services import app_store, app_store_api
from tests.test_app_store import _payload, _signed_jws


def _configure(monkeypatch) -> ec.EllipticCurvePrivateKey:
    key = ec.generate_private_key(ec.SECP256R1())
    pem = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()
    monkeypatch.setattr(settings, "app_store_api_key_id", "TESTKEY")
    monkeypatch.setattr(settings, "app_store_api_issuer_id", "issuer-123")
    monkeypatch.setattr(settings, "app_store_api_private_key", pem)
    monkeypatch.setattr(settings, "app_store_api_private_key_path", "")
    monkeypatch.setattr(settings, "app_store_api_environment", "sandbox")
    return key


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    db = Session(engine)
    db.add(User(id="iap-user", phone="13800138012", status="active"))
    db.commit()
    return db


def _snapshot(
    *,
    status: int = 1,
    transaction_id: str = "2000000000000009",
    app_account_token: str | None = "iap-user",
    revoked: bool = False,
) -> app_store_api.SubscriptionSnapshot:
    now = datetime.now(timezone.utc)
    raw = {"transactionId": transaction_id}
    if app_account_token:
        raw["appAccountToken"] = app_account_token
    if revoked:
        raw["revocationDate"] = int(now.timestamp() * 1000)
    return app_store_api.SubscriptionSnapshot(
        transaction=app_store.VerifiedTransaction(
            transaction_id=transaction_id,
            original_transaction_id=transaction_id,
            product_id="com.fitai.app.pro.monthly",
            purchase_date=now - timedelta(days=1),
            expires_date=now + timedelta(days=29),
            environment="Sandbox",
            raw=raw,
        ),
        status=status,
    )


def test_missing_credentials_raise_configuration_error(monkeypatch):
    monkeypatch.setattr(settings, "app_store_api_key_id", "")
    monkeypatch.setattr(settings, "app_store_api_issuer_id", "")
    monkeypatch.setattr(settings, "app_store_api_private_key", "")
    monkeypatch.setattr(settings, "app_store_api_private_key_path", "")

    assert app_store_api.is_configured() is False
    with pytest.raises(app_store_api.AppStoreAPIConfigurationError):
        app_store_api.client_assertion()


def test_client_assertion_has_apple_claims(monkeypatch):
    key = _configure(monkeypatch)

    token = app_store_api.client_assertion()
    header = jwt.get_unverified_header(token)
    claims = jwt.decode(
        token,
        key.public_key(),
        algorithms=["ES256"],
        audience="appstoreconnect-v1",
    )

    assert header["kid"] == "TESTKEY"
    assert claims["iss"] == "issuer-123"
    assert claims["bid"] == settings.app_store_bundle_id
    assert 0 < claims["exp"] - claims["iat"] <= 3600


def test_lookup_verifies_signed_transactions(monkeypatch):
    _configure(monkeypatch)
    jws, root = _signed_jws(_payload())
    monkeypatch.setattr(app_store, "_apple_root", lambda: root)
    monkeypatch.setattr(
        app_store_api,
        "_get_json",
        lambda path, client=None: {
            "data": [
                {
                    "lastTransactions": [
                        {"status": 1, "signedTransactionInfo": jws}
                    ]
                }
            ]
        },
    )

    snapshots = app_store_api.lookup_subscription("2000000000000002")

    assert len(snapshots) == 1
    assert snapshots[0].transaction.transaction_id == "2000000000000002"
    assert snapshots[0].status == 1


def test_lookup_rejects_payload_without_snapshots(monkeypatch):
    _configure(monkeypatch)
    monkeypatch.setattr(
        app_store_api,
        "_get_json",
        lambda path, client=None: {"data": []},
    )

    with pytest.raises(app_store_api.AppStoreAPIError):
        app_store_api.lookup_subscription("2000000000000002")


def test_reconcile_active_snapshot_records_entitlement(monkeypatch):
    db = _session()
    monkeypatch.setattr(
        app_store_api,
        "lookup_subscription",
        lambda transaction_id, client=None: [_snapshot()],
    )

    result = app_store_api.reconcile_transaction(db, "2000000000000009")

    assert result["results"][0]["state"] == "active"
    row = db.query(UserEntitlement).one()
    assert row.user_id == "iap-user"
    assert row.source == "storekit"


def test_reconcile_revoked_snapshot_revokes_entitlement(monkeypatch):
    db = _session()
    snapshot = _snapshot()
    app_store.record_entitlement(db, "iap-user", snapshot.transaction)
    monkeypatch.setattr(
        app_store_api,
        "lookup_subscription",
        lambda transaction_id, client=None: [
            _snapshot(status=5, revoked=True)
        ],
    )

    result = app_store_api.reconcile_transaction(db, "2000000000000009")

    assert result["results"][0]["state"] == "revoked"
    assert db.query(UserEntitlement).one().revoked_at is not None


def test_reconcile_endpoint_requires_configuration_and_token(monkeypatch):
    db = _session()
    monkeypatch.setattr(settings, "app_store_reconcile_token", "")
    with pytest.raises(HTTPException) as exc:
        iap.reconcile_storekit_subscriptions(
            StoreKitReconcileIn(), db, x_admin_token=None
        )
    assert exc.value.status_code == 503

    monkeypatch.setattr(settings, "app_store_reconcile_token", "secret")
    with pytest.raises(HTTPException) as exc:
        iap.reconcile_storekit_subscriptions(
            StoreKitReconcileIn(), db, x_admin_token="wrong"
        )
    assert exc.value.status_code == 401
