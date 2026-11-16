import sys
from pathlib import Path

import pytest

from app.config import settings

# 让 `pytest` 和 `python -m pytest` 都能从 backend 根目录导入 app 包
BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))


@pytest.fixture(autouse=True)
def _mock_llm_by_default(monkeypatch):
    """Never let the unit suite call a real model provider.

    A developer `.env` may contain a real key. Without this fixture, action
    tests that reach the free-chat fallback make live HTTP calls and cache an
    httpx client bound to a closed event loop, which then fails unrelated
    tests. Tests that need a non-mock config override these fields locally.
    """
    monkeypatch.setattr(settings, "llm_api_key", "")
    monkeypatch.setattr(settings, "vision_api_key", "")
