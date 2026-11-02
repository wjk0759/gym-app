"""Reconcile StoreKit entitlements with App Store Server API.

Usage:
    python scripts/reconcile_storekit.py
    python scripts/reconcile_storekit.py 2000000000000001 --limit 50

Credentials come from APP_STORE_API_KEY_ID / APP_STORE_API_ISSUER_ID /
APP_STORE_API_PRIVATE_KEY(_PATH). Without them the command exits non-zero so a
cron job does not report a fake success.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from app.db import SessionLocal  # noqa: E402
from app.services import app_store_api  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("transaction_ids", nargs="*")
    parser.add_argument("--limit", type=int, default=200)
    args = parser.parse_args()

    if not app_store_api.is_configured():
        print(
            json.dumps(
                {
                    "ok": False,
                    "code": "APP_STORE_API_NOT_CONFIGURED",
                    "message": "App Store Server API 凭据未配置",
                },
                ensure_ascii=False,
            )
        )
        return 1

    try:
        with SessionLocal() as db:
            if args.transaction_ids:
                checked = []
                errors = []
                for transaction_id in args.transaction_ids:
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
                result = {"checked": checked, "errors": errors}
            else:
                result = app_store_api.reconcile_tracked(
                    db, limit=args.limit
                )
    except app_store_api.AppStoreAPIConfigurationError as exc:
        print(
            json.dumps(
                {
                    "ok": False,
                    "code": "APP_STORE_API_NOT_CONFIGURED",
                    "message": str(exc),
                },
                ensure_ascii=False,
            )
        )
        return 1
    except app_store_api.AppStoreAPIError as exc:
        print(
            json.dumps(
                {
                    "ok": False,
                    "code": "APP_STORE_API_ERROR",
                    "message": str(exc),
                },
                ensure_ascii=False,
            )
        )
        return 2

    print(json.dumps({"ok": True, **result}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
