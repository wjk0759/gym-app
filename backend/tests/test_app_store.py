import hashlib
from datetime import datetime, timedelta, timezone

import pytest
from cryptography.hazmat.primitives.serialization import Encoding
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
