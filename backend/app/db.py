from collections.abc import Generator

from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker
from sqlalchemy.pool import StaticPool

from .config import settings

connect_args = {}
engine_kwargs = {
    "echo": False,
    "future": True,
    "pool_pre_ping": True,
    "pool_recycle": settings.db_pool_recycle,
    "pool_timeout": settings.db_pool_timeout,
    "pool_size": settings.db_pool_size,
    "max_overflow": settings.db_max_overflow,
    "pool_use_lifo": True,
}
if settings.database_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}
    if ":memory:" in settings.database_url:
        engine_kwargs = {
            "echo": False,
            "future": True,
            "connect_args": connect_args,
            "poolclass": StaticPool,
        }

engine = create_engine(
    settings.database_url,
    connect_args=connect_args,
    **engine_kwargs,
)

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
)

if settings.database_url.startswith("sqlite") and ":memory:" not in settings.database_url:
    @event.listens_for(engine, "connect")
    def _sqlite_pragmas(dbapi_connection, connection_record) -> None:
        # WAL 让读写并发更顺畅，NORMAL 同步在开发/单机部署下减少 fsync 等待。
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA synchronous=NORMAL")
        cursor.execute("PRAGMA busy_timeout=5000")
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()


class Base(DeclarativeBase):
    pass


# 轻量迁移：create_all 不会给已有表补列。开发期 SQLite 和早期 Postgres
# 都需要这些新增认证字段，因此启动时按列检测补齐。
_USER_AUTH_COLUMNS = {
    "apple_sub": "VARCHAR(255)",
    "username": "VARCHAR(50)",
    "password_hash": "VARCHAR(255)",
    "wechat_openid": "VARCHAR(128)",
    "wechat_unionid": "VARCHAR(128)",
    "qq_openid": "VARCHAR(128)",
    "avatar_url": "TEXT",
    "status": "VARCHAR(20) DEFAULT 'active'",
    "last_login_at": "TIMESTAMP",
}

_AI_MEMORY_COLUMNS = {
    "memory_key": "VARCHAR(80) DEFAULT 'general'",
    "source": "VARCHAR(40) DEFAULT 'agent'",
    "confidence": "FLOAT DEFAULT 1.0",
    "active": "BOOLEAN DEFAULT 1",
    "updated_at": "TIMESTAMP",
    "last_used_at": "TIMESTAMP",
}

# 开发期 SQLite 已有库不会自动补复合索引；启动时按表检测补齐。
# 这些索引对应列表/统计页的高频过滤与排序条件。
_PERFORMANCE_INDEXES = (
    (
        "workout_sessions",
        "CREATE INDEX IF NOT EXISTS ix_workout_sessions_user_started "
        "ON workout_sessions(user_id, started_at)",
    ),
    (
        "workout_sessions",
        "CREATE INDEX IF NOT EXISTS ix_workout_sessions_started_at "
        "ON workout_sessions(started_at)",
    ),
    (
        "programs",
        "CREATE INDEX IF NOT EXISTS ix_programs_user_status_version "
        "ON programs(user_id, status, version)",
    ),
    (
        "programs",
        "CREATE INDEX IF NOT EXISTS ix_programs_created_at "
        "ON programs(created_at)",
    ),
    (
        "chat_sessions",
        "CREATE INDEX IF NOT EXISTS ix_chat_sessions_user_created "
        "ON chat_sessions(user_id, created_at)",
    ),
    (
        "chat_sessions",
        "CREATE INDEX IF NOT EXISTS ix_chat_sessions_created_at "
        "ON chat_sessions(created_at)",
    ),
    (
        "ai_jobs",
        "CREATE INDEX IF NOT EXISTS ix_ai_jobs_created_at "
        "ON ai_jobs(created_at)",
    ),
    (
        "exercise_videos",
        "CREATE INDEX IF NOT EXISTS ix_exercise_videos_slug_status "
        "ON exercise_videos(exercise_slug, status)",
    ),
    (
        "workout_sessions",
        "CREATE INDEX IF NOT EXISTS ix_workout_sessions_program_day "
        "ON workout_sessions(program_day_id)",
    ),
    (
        "food_logs",
        "CREATE INDEX IF NOT EXISTS ix_food_logs_user_logged "
        "ON food_logs(user_id, logged_at)",
    ),
    (
        "body_metrics",
        "CREATE INDEX IF NOT EXISTS ix_body_metrics_user_measured "
        "ON body_metrics(user_id, measured_at)",
    ),
    (
        "equipment_scans",
        "CREATE INDEX IF NOT EXISTS ix_equipment_scans_user_created "
        "ON equipment_scans(user_id, created_at)",
    ),
    (
        "ai_jobs",
        "CREATE INDEX IF NOT EXISTS ix_ai_jobs_user_created "
        "ON ai_jobs(user_id, created_at)",
    ),
    (
        "ai_jobs",
        "CREATE INDEX IF NOT EXISTS ix_ai_jobs_kind_status_created "
        "ON ai_jobs(kind, status, created_at)",
    ),
    (
        "chat_messages",
        "CREATE INDEX IF NOT EXISTS ix_chat_messages_safety_created "
        "ON chat_messages(safety_flag, created_at)",
    ),
    (
        "chat_messages",
        "CREATE INDEX IF NOT EXISTS ix_chat_messages_session_created "
        "ON chat_messages(session_id, created_at)",
    ),
    (
        "goals",
        "CREATE INDEX IF NOT EXISTS ix_goals_user_status_created "
        "ON goals(user_id, status, created_at)",
    ),
    (
        "equipment_scans",
        "CREATE INDEX IF NOT EXISTS ix_equipment_scans_created_at "
        "ON equipment_scans(created_at)",
    ),
    (
        "set_logs",
        "CREATE INDEX IF NOT EXISTS ix_set_logs_session_completed "
        "ON set_logs(session_id, completed)",
    ),
)


def ensure_schema() -> None:
    # MySQL schema is owned by the admin service's Flyway migrations.
    # Skipping this SQLite/Postgres compatibility layer avoids database-specific
    # ALTER/partial-index syntax on MySQL.
    if engine.dialect.name == "mysql":
        return
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    if "users" not in tables:
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
                "CREATE UNIQUE INDEX IF NOT EXISTS ix_users_apple_sub "
                "ON users(apple_sub) WHERE apple_sub IS NOT NULL"
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
        if "ai_memories" in tables:
            memory_columns = {
                column["name"] for column in inspector.get_columns("ai_memories")
            }
            for name, ddl in _AI_MEMORY_COLUMNS.items():
                if name not in memory_columns:
                    connection.execute(
                        text(f"ALTER TABLE ai_memories ADD COLUMN {name} {ddl}")
                    )
            connection.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS ix_ai_memories_user_active_updated "
                    "ON ai_memories(user_id, active, updated_at)"
                )
            )
            connection.execute(
                text(
                    "CREATE INDEX IF NOT EXISTS ix_ai_memories_memory_key "
                    "ON ai_memories(memory_key)"
                )
            )
        if "workout_sessions" in tables:
            workout_columns = {
                column["name"]
                for column in inspector.get_columns("workout_sessions")
            }
            if "client_id" not in workout_columns:
                connection.execute(
                    text(
                        "ALTER TABLE workout_sessions "
                        "ADD COLUMN client_id VARCHAR(36)"
                    )
                )
            connection.execute(
                text(
                    "CREATE UNIQUE INDEX IF NOT EXISTS "
                    "uq_workout_sessions_user_client "
                    "ON workout_sessions(user_id, client_id)"
                )
            )
        if "meal_plans" in tables:
            # Keep the newest row for a user/day before adding the unique index.
            connection.execute(
                text(
                    "DELETE FROM meal_plans WHERE id NOT IN ("
                    "SELECT id FROM ("
                    "SELECT id, ROW_NUMBER() OVER ("
                    "PARTITION BY user_id, plan_date "
                    "ORDER BY created_at DESC, id DESC"
                    ") AS rn FROM meal_plans"
                    ") ranked WHERE rn = 1)"
                )
            )
            connection.execute(
                text(
                    "CREATE UNIQUE INDEX IF NOT EXISTS "
                    "uq_meal_plans_user_date "
                    "ON meal_plans(user_id, plan_date)"
                )
            )
        for table, ddl in _PERFORMANCE_INDEXES:
            if table in tables:
                connection.execute(text(ddl))


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
