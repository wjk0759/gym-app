from contextlib import asynccontextmanager
from pathlib import Path
import logging

import anyio.to_thread
from fastapi import FastAPI, HTTPException, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from starlette.middleware.gzip import GZipMiddleware

from .config import settings
from .db import Base, SessionLocal, engine, ensure_schema
from .deps import DEMO_USER_ID
from .media import MEDIA_ROOT, ensure_media_dirs
from .middleware import RequestContextMiddleware
from .models import User
from .routers import (
    admin,
    agent,
    auth,
    body,
    coach,
    diet,
    equipment,
    plans,
    profile,
    videos,
    workouts,
)
from .seed import seed_exercises
from .services import llm

logger = logging.getLogger(__name__)

CODE_BY_STATUS = {
    400: "VALIDATION_ERROR",
    401: "UNAUTHORIZED",
    403: "FORBIDDEN",
    404: "NOT_FOUND",
    409: "CONFLICT",
    413: "PAYLOAD_TOO_LARGE",
    415: "UNSUPPORTED_MEDIA_TYPE",
    422: "VALIDATION_ERROR",
    429: "RATE_LIMITED",
    500: "INTERNAL_ERROR",
    501: "NOT_IMPLEMENTED",
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    # FastAPI runs synchronous routes in AnyIO's worker pool. Size it to the
    # database pool so bursts of CRUD requests do not queue behind 40 threads.
    try:
        anyio.to_thread.current_default_thread_limiter().total_tokens = max(
            16, settings.thread_pool_size
        )
    except Exception:  # pragma: no cover - older AnyIO fallback
        logger.warning("could not resize AnyIO thread limiter")
    logging.getLogger("fitai.access").setLevel(logging.INFO)
    ensure_schema()
    # MySQL schema is owned by admin-server Flyway. Only local SQLite/Postgres
    # development uses SQLAlchemy create_all to avoid two schema creators.
    if engine.dialect.name != "mysql":
        Base.metadata.create_all(bind=engine)
    ensure_schema()
    with SessionLocal() as db:
        seed_exercises(db)
        if db.get(User, DEMO_USER_ID) is None:
            db.add(User(id=DEMO_USER_ID))
            try:
                db.commit()
            except IntegrityError:
                # Multiple workers may race on the demo user during startup.
                db.rollback()
    try:
        yield
    finally:
        await llm.close_client()


app = FastAPI(
    title="FitAI API",
    description="AI 健身教练后端（中国大陆版）",
    version="0.1.0",
    lifespan=lifespan,
)

allowed_origins = settings.allowed_origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=allowed_origins != ["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Request-ID", "Server-Timing"],
)
# GZip 先加；RequestContext 最后加，保证 X-Request-ID/Server-Timing 覆盖所有响应。
app.add_middleware(GZipMiddleware, minimum_size=1024)
app.add_middleware(RequestContextMiddleware)


def _request_id(request: Request) -> str | None:
    return getattr(request.state, "request_id", None)


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    detail = exc.detail
    if isinstance(detail, dict):
        error = {
            "code": detail.get("code", CODE_BY_STATUS.get(exc.status_code, "ERROR")),
            "message": detail.get("message", ""),
            "details": detail.get("details"),
        }
    else:
        error = {
            "code": CODE_BY_STATUS.get(exc.status_code, "ERROR"),
            "message": str(detail),
        }
    request_id = _request_id(request)
    if request_id:
        error["request_id"] = request_id
    return JSONResponse(status_code=exc.status_code, content={"error": error})


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    error = {
        "code": "VALIDATION_ERROR",
        "message": "请求参数不合法",
        "details": jsonable_encoder(exc.errors()),
    }
    request_id = _request_id(request)
    if request_id:
        error["request_id"] = request_id
    return JSONResponse(status_code=422, content={"error": error})


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.exception(
        "Unhandled exception path=%s request_id=%s",
        request.url.path,
        _request_id(request),
    )
    error = {"code": "INTERNAL_ERROR", "message": "服务暂时不可用，请稍后重试"}
    request_id = _request_id(request)
    if request_id:
        error["request_id"] = request_id
    return JSONResponse(status_code=500, content={"error": error})


API_PREFIX = "/api/v1"
for module in (auth, profile, plans, workouts, coach, agent, equipment, diet, body, videos, admin):
    app.include_router(module.router, prefix=API_PREFIX)

ensure_media_dirs()
app.mount(
    "/media",
    StaticFiles(directory=str(MEDIA_ROOT)),
    name="media",
)

ADMIN_DIR = Path(__file__).resolve().parent / "admin"
if (ADMIN_DIR / "assets").is_dir():
    app.mount(
        "/admin/assets",
        StaticFiles(directory=str(ADMIN_DIR / "assets")),
        name="admin-assets",
    )


@app.get("/admin", include_in_schema=False)
def admin_console():
    page = ADMIN_DIR / "index.html"
    if not page.exists():
        raise HTTPException(status_code=404, detail="admin console not found")
    return FileResponse(page, headers={"Cache-Control": "no-store"})


@app.get("/")
def root():
    return {
        "name": "FitAI API",
        "version": "0.1.0",
        "docs": "/docs",
        "api": API_PREFIX,
        "admin": "/admin",
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "env": settings.app_env,
        "llm": "mock" if settings.use_mock_llm else settings.llm_model,
        "vision": "mock" if settings.use_mock_vision else settings.vision_model,
        "meituan": "configured" if settings.meituan_deeplink_base else "not_configured",
    }


@app.get("/health/ready")
def readiness():
    """Readiness probe: verifies the DB pool can serve a trivial query."""
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001 - readiness must be a clean 503
        raise HTTPException(status_code=503, detail="database unavailable") from exc
    return {"status": "ready"}
