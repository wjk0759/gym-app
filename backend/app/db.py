from collections.abc import Generator

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import settings

connect_args = {}
if settings.database_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    settings.database_url,
    echo=False,
    future=True,
    pool_pre_ping=True,
    connect_args=connect_args,
)

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


# 轻量迁移：create_all 不会给已有表补列。开发期 SQLite 和早期 Postgres
# 都需要这些新增认证字段，因此启动时按列检测补齐。
_USER_AUTH_COLUMNS = {
    "username": "VARCHAR(50)",
    "password_hash": "VARCHAR(255)",
    "wechat_openid": "VARCHAR(128)",
    "wechat_unionid": "VARCHAR(128)",
    "qq_openid": "VARCHAR(128)",
    "avatar_url": "TEXT",
    "status": "VARCHAR(20) DEFAULT 'active'",
    "last_login_at": "TIMESTAMP",
}


def ensure_schema() -> None:
    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("users")}
    with engine.begin() as connection:
        for name, ddl in _USER_AUTH_COLUMNS.items():
            if name not in columns:
                connection.execute(text(f"ALTER TABLE users ADD COLUMN {name} {ddl}"))
        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_username "
                "ON users(username) WHERE username IS NOT NULL"
            )
        )
        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_wechat_openid "
                "ON users(wechat_openid) WHERE wechat_openid IS NOT NULL"
            )
        )
        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_wechat_unionid "
                "ON users(wechat_unionid) WHERE wechat_unionid IS NOT NULL"
            )
        )
        connection.execute(
            text(
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_qq_openid "
                "ON users(qq_openid) WHERE qq_openid IS NOT NULL"
            )
        )


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
