import pytest

from app.config import settings


@pytest.fixture(autouse=True)
def force_mock_llm(monkeypatch):
    """Keep adversarial routing cases deterministic and offline.

    The cases call the runtime directly through repeated ``asyncio.run``
    invocations. A real provider client is bound to the first event loop, so a
    later test would fail with "Event loop is closed" instead of exercising the
    routing rule under test.
    """
    monkeypatch.setattr(settings, "llm_provider", "mock")
