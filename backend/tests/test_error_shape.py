import asyncio
import json

from fastapi import HTTPException
from starlette.requests import Request

from app.main import http_exception_handler


def test_structured_error_keeps_rate_limit_details():
    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/api/v1/plans/generate",
            "headers": [],
            "state": {},
        }
    )
    response = asyncio.run(
        http_exception_handler(
            request,
            HTTPException(
                status_code=429,
                detail={
                    "code": "GENERATION_COOLDOWN",
                    "message": "刚刚生成过，请稍后再试",
                    "feature": "training_plan",
                    "retry_after": 42,
                },
            ),
        )
    )

    body = json.loads(response.body)
    assert body["error"]["code"] == "GENERATION_COOLDOWN"
    assert body["error"]["details"]["retry_after"] == 42
    assert body["error"]["details"]["feature"] == "training_plan"
