import base64
import hashlib
import json
from datetime import datetime, timedelta, timezone

import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.serialization import Encoding
from cryptography.x509.oid import NameOID
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db import Base
from app.models import User, UserEntitlement
from app.services import app_store


def _session() -> Session:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    db = Session(engine)
    db.add(User(id="iap-user", phone="13800138009", status="active"))
    db.commit()
    return db


def _transaction() -> app_store.VerifiedTransaction:
    now = datetime.now(timezone.utc)
    return app_store.VerifiedTransaction(
        transaction_id="2000000000000001",
        original_transaction_id="2000000000000001",
        product_id="com.fitai.app.pro.monthly",
        purchase_date=now,
        expires_date=now + timedelta(days=30),
        environment="Sandbox",
        raw={"transactionId": "2000000000000001"},
    )


def test_storekit_entitlement_is_idempotent():
    db = _session()
    transaction = _transaction()

    app_store.record_entitlement(db, "iap-user", transaction)
    app_store.record_entitlement(db, "iap-user", transaction)

    rows = db.query(UserEntitlement).all()
    assert len(rows) == 1
    assert rows[0].source == "storekit"
    assert rows[0].source_ref == transaction.transaction_id
    assert rows[0].metadata_json["environment"] == "Sandbox"


def test_transaction_account_token_is_normalized():
    transaction = _transaction()
    assert app_store.transaction_account_token(transaction) is None

    transaction = app_store.VerifiedTransaction(
        transaction_id="2",
        original_transaction_id="2",
        product_id=transaction.product_id,
        purchase_date=transaction.purchase_date,
        expires_date=transaction.expires_date,
        environment="Sandbox",
        raw={"appAccountToken": "ABC-DEF"},
    )
    assert app_store.transaction_account_token(transaction) == "abc-def"


def test_malformed_storekit_jws_is_rejected():
    with pytest.raises(app_store.StoreKitError):
        app_store.verify_signed_transaction("not-a-jws")


def test_bundled_apple_root_matches_pinned_fingerprint():
    root = app_store._apple_root()
    fingerprint = hashlib.sha256(root.public_bytes(Encoding.DER)).hexdigest()
    assert fingerprint == app_store.APPLE_ROOT_CA_G3_SHA256


def test_refund_notification_revokes_entitlement_once():
    db = _session()
    transaction = _transaction()
    app_store.record_entitlement(db, "iap-user", transaction)

    notification = {
        "notificationType": "REFUND",
        "data": {"transactionId": transaction.transaction_id},
    }
    first = app_store.apply_notification(db, notification)
    second = app_store.apply_notification(db, notification)

    assert first == {"handled": "REFUND", "revoked": True}
    assert second == {"handled": "REFUND", "revoked": False}
    row = db.query(UserEntitlement).one()
    assert row.revoked_at is not None


def _certificate(
    subject: x509.Name,
    issuer: x509.Name,
    public_key,
    issuer_key,
    *,
    ca: bool,
):
    now = datetime.now(timezone.utc)
    builder = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(public_key)
        .serial_number(x509.random_serial_number())
        .not_valid_before(now - timedelta(days=1))
        .not_valid_after(now + timedelta(days=365))
        .add_extension(x509.BasicConstraints(ca=ca, path_length=None), critical=True)
    )
    return builder.sign(issuer_key, hashes.SHA256())


def _signed_jws(payload: dict) -> str:
    root_key = ec.generate_private_key(ec.SECP256R1())
    root_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Test Root")])
    root = _certificate(root_name, root_name, root_key.public_key(), root_key, ca=True)

    intermediate_key = ec.generate_private_key(ec.SECP256R1())
    intermediate_name = x509.Name(
        [x509.NameAttribute(NameOID.COMMON_NAME, "Test Intermediate")]
    )
    intermediate = _certificate(
        intermediate_name,
        root_name,
        intermediate_key.public_key(),
        root_key,
        ca=True,
    )

    leaf_key = ec.generate_private_key(ec.SECP256R1())
    leaf_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Test Leaf")])
    leaf = _certificate(
        leaf_name,
        intermediate_name,
        leaf_key.public_key(),
        intermediate_key,
        ca=False,
    )

    x5c = [
        base64.b64encode(cert.public_bytes(Encoding.DER)).decode()
        for cert in (leaf, intermediate)
    ]
    header = {"alg": "ES256", "x5c": x5c}
    header_segment = base64.urlsafe_b64encode(
        json.dumps(header).encode()
    ).decode().rstrip("=")
    payload_segment = base64.urlsafe_b64encode(
        json.dumps(payload).encode()
    ).decode().rstrip("=")
    signature = leaf_key.sign(
        f"{header_segment}.{payload_segment}".encode(),
        ec.ECDSA(hashes.SHA256()),
    )
    signature_segment = base64.urlsafe_b64encode(signature).decode().rstrip("=")
    return f"{header_segment}.{payload_segment}.{signature_segment}", root


def _payload(**overrides) -> dict:
    now = datetime.now(timezone.utc)
    payload = {
        "bundleId": "com.wjk.fitai",
        "productId": "com.fitai.app.pro.monthly",
        "type": "Auto-Renewable Subscription",
        "transactionId": "2000000000000002",
        "originalTransactionId": "2000000000000002",
        "purchaseDate": int(now.timestamp() * 1000),
        "expiresDate": int((now + timedelta(days=30)).timestamp() * 1000),
        "environment": "Sandbox",
    }
    payload.update(overrides)
    return payload


def test_valid_signed_transaction_is_verified(monkeypatch):
    jws, root = _signed_jws(_payload())
    monkeypatch.setattr(app_store, "_apple_root", lambda: root)

    transaction = app_store.verify_signed_transaction(jws)

    assert transaction.transaction_id == "2000000000000002"
    assert transaction.product_id == "com.fitai.app.pro.monthly"


def test_expired_or_revoked_transaction_is_rejected(monkeypatch):
    now = datetime.now(timezone.utc)
    jws, root = _signed_jws(
        _payload(
            expiresDate=int((now - timedelta(days=1)).timestamp() * 1000),
        )
    )
    monkeypatch.setattr(app_store, "_apple_root", lambda: root)
    with pytest.raises(app_store.StoreKitError):
        app_store.verify_signed_transaction(jws)

    jws, root = _signed_jws(
        _payload(
            revocationDate=int(now.timestamp() * 1000),
        )
    )
    monkeypatch.setattr(app_store, "_apple_root", lambda: root)
    with pytest.raises(app_store.StoreKitError):
        app_store.verify_signed_transaction(jws)


def test_subscription_notification_uses_app_account_token(monkeypatch):
    db = _session()
    jws, root = _signed_jws(_payload(appAccountToken="iap-user"))
    monkeypatch.setattr(app_store, "_apple_root", lambda: root)

    result = app_store.apply_notification(
        db,
        {
            "notificationType": "SUBSCRIBED",
            "data": {"signedTransactionInfo": jws},
        },
    )

    assert result == {"handled": "SUBSCRIBED", "recorded": True}
    row = db.query(UserEntitlement).one()
    assert row.user_id == "iap-user"
