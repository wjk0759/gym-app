"""Request observability middleware.

Adds a stable request id and server timing without buffering the response body.
The implementation is pure ASGI so it stays cheap on high-traffic read routes.
"""

from __future__ import annotations

import logging
import time
import uuid

from starlette.datastructures import MutableHeaders

logger = logging.getLogger("fitai.access")


class RequestContextMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request_id = (scope.get("headers") and _request_id(scope)) or uuid.uuid4().hex
        scope.setdefault("state", {})["request_id"] = request_id
        started = time.perf_counter()
        status_code = 500

        async def send_wrapper(message):
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
                headers = MutableHeaders(scope=message)
                headers["X-Request-ID"] = request_id
                headers["Server-Timing"] = (
                    f"app;dur={(time.perf_counter() - started) * 1000:.1f}"
                )
                headers.setdefault("X-Content-Type-Options", "nosniff")
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        finally:
            elapsed_ms = (time.perf_counter() - started) * 1000
            level = (
                logging.WARNING
                if status_code >= 400 or elapsed_ms >= 500
                else logging.DEBUG
            )
            logger.log(
                level,
                "%s %s %s %.1fms request_id=%s",
                scope.get("method", ""),
                scope.get("path", ""),
                status_code,
                elapsed_ms,
                request_id,
            )


def _request_id(scope) -> str | None:
    for name, value in scope.get("headers", []):
        if name.lower() == b"x-request-id":
            text = value.decode("latin-1").strip()
            if 8 <= len(text) <= 64 and all(
                ch.isalnum() or ch in "-_." for ch in text
            ):
                return text
    return None
