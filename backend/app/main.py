from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.middleware.gzip import GZipMiddleware

from .config import settings
from .db import Base, SessionLocal, engine, ensure_schema
from .deps import DEMO_USER_ID
from .media import MEDIA_ROOT, ensure_media_dirs
from .models import User
from .routers import admin, auth, body, coach, diet, equipment, plans, profile, videos, workouts
from .seed import seed_exercises
from .services import llm

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
    ensure_schema()
    Base.metadata.create_all(bind=engine)
    ensure_schema()
    with SessionLocal() as db:
        seed_exercises(db)
        if db.get(User, DEMO_USER_ID) is None:
            db.add(User(id=DEMO_USER_ID))
            db.commit()
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
)
# 计划/后台列表 JSON 较大；压缩能明显减少移动网络传输时间。
app.add_middleware(GZipMiddleware, minimum_size=1024)


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
    return JSONResponse(status_code=exc.status_code, content={"error": error})


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content={
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "请求参数不合法",
                "details": jsonable_encoder(exc.errors()),
            }
        },
    )


API_PREFIX = "/api/v1"
for module in (auth, profile, plans, workouts, coach, equipment, diet, body, videos, admin):
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
