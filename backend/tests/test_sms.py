import json

import pytest

from app.config import settings
from app.services import sms


class _Body:
    def __init__(self, code: str = "OK", message: str = "OK") -> None:
        self.code = code
        self.message = message


class _Response:
    def __init__(self, code: str = "OK", message: str = "OK") -> None:
        self.body = _Body(code, message)


class _FakeClient:
    def __init__(self, response: _Response | None = None) -> None:
        self.request = None
        self.response = response or _Response()

    def send_sms_verify_code_with_options(self, request, runtime):
        self.request = request
        return self.response


def _configure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "aliyun_pnvs_access_key_id", "ak")
    monkeypatch.setattr(settings, "aliyun_pnvs_access_key_secret", "sk")
    monkeypatch.setattr(settings, "aliyun_pnvs_sign_name", "测试签名")
    monkeypatch.setattr(settings, "aliyun_pnvs_template_code", "100001")


def test_aliyun_pnvs_builds_request(monkeypatch: pytest.MonkeyPatch) -> None:
    _configure(monkeypatch)
    fake = _FakeClient()
    monkeypatch.setattr(sms, "_aliyun_client", lambda: fake)

    sms.send_aliyun_pnvs_code("13800138000", "123456")

    request = fake.request
    assert request.phone_number == "13800138000"
    assert request.sign_name == "测试签名"
    assert request.template_code == "100001"
    assert request.code_length == 6
    assert request.valid_time == 300
    assert json.loads(request.template_param) == {"code": "123456", "min": "5"}


def test_aliyun_pnvs_rejects_error(monkeypatch: pytest.MonkeyPatch) -> None:
    _configure(monkeypatch)
    fake = _FakeClient(_Response("isv.BUSINESS_LIMIT_CONTROL", "触发分钟级流控"))
    monkeypatch.setattr(sms, "_aliyun_client", lambda: fake)

    with pytest.raises(sms.SmsDeliveryError):
        sms.send_aliyun_pnvs_code("13800138000", "123456")


def test_aliyun_pnvs_requires_config(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "aliyun_pnvs_access_key_id", "")

    with pytest.raises(sms.SmsDeliveryError):
        sms.send_aliyun_pnvs_code("13800138000", "123456")
