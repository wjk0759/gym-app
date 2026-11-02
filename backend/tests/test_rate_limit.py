import pytest
from fastapi import HTTPException

from app.services.rate_limit import enforce


def test_rate_limit_rejects_burst():
    key = "test-feature"
    user = "rate-limit-user"
    enforce(key, user, 2, 60)
    enforce(key, user, 2, 60)
    with pytest.raises(HTTPException) as exc:
        enforce(key, user, 2, 60)
    assert exc.value.status_code == 429
    assert exc.value.detail["code"] == "RATE_LIMITED"
