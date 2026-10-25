import pytest
from fastapi import HTTPException

from app.services.auth import (
    decode_oauth_state,
    hash_password,
    normalize_account,
    normalize_phone,
    oauth_state,
    verify_password,
)


def test_phone_normalization():
    assert normalize_phone("+86 138-0013-8000") == "13800138000"
    with pytest.raises(HTTPException):
        normalize_phone("12345")


def test_password_hash_round_trip():
    encoded = hash_password("Test12345")
    assert encoded.startswith("scrypt$")
    assert verify_password("Test12345", encoded)
    assert not verify_password("Wrong12345", encoded)


def test_weak_password_rejected():
    with pytest.raises(HTTPException):
        hash_password("12345678")
    with pytest.raises(HTTPException):
        hash_password("abcdefgh")


def test_account_types():
    assert normalize_account("13800138000") == ("phone", "13800138000")
    assert normalize_account("Smoke_User") == ("username", "smoke_user")


def test_oauth_state_round_trip():
    state = oauth_state("wechat", "fitai://auth/callback")
    payload = decode_oauth_state(state)
    assert payload["provider"] == "wechat"
    assert payload["redirect"] == "fitai://auth/callback"
