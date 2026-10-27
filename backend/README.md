# FitAI Backend

FastAPI + SQLAlchemy，纯 App 本地开发可用 SQLite；与 Spring 管理后台联调时连接同一 MySQL 8。

## 启动

```powershell
cd E:\Projects\FitAI\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
uvicorn app.main:app --reload
```

- API 文档：<http://127.0.0.1:8000/docs>
- 健康检查：<http://127.0.0.1:8000/health>
- 管理后台：已迁移到 Spring + Vue，见项目根目录 `README.md` 与 `admin-web/`

FastAPI 不再提供 `/admin` 或 `/api/v1/admin/*`。管理后台使用 `admin-server` 的 `/api/admin/v1`，由 Spring Security JWT/RBAC 和审计保护；视频媒体仍通过 FastAPI `/media` 与 Spring `/media` 共享目录。

首次启动会自动建表，并写入 27 个基础动作。MySQL 模式下 Schema 由 `admin-server` Flyway 管理，先启动 admin-server 或执行迁移。

## 接入真实模型

编辑 `.env`：

```ini
LLM_PROVIDER=deepseek
LLM_API_KEY=sk-...
LLM_BASE_URL=https://api.deepseek.com/v1
LLM_MODEL=deepseek-flash
LLM_REASONING_EFFORT=high
```

任何 OpenAI 兼容接口都可以（通义、豆包、DeepSeek）。没有 Key 时自动使用规则模板，不影响调试。

## 切 MySQL

与 Spring 管理后台共享 MySQL 8：

```powershell
cd deploy/admin
docker compose up -d mysql
```

`.env`：

```ini
DATABASE_URL=mysql+pymysql://fitai:change-me-strong-db-password@127.0.0.1:3307/fitai?charset=utf8mb4
```

MySQL Schema 由 `admin-server` Flyway 管理；旧 SQLite 数据可用 `tools/db/migrate_sqlite_to_mysql.py --replace` 迁移。

## 目录

```
app/
├── main.py              # 应用入口、CORS、启动 seed
├── config.py            # 环境变量
├── db.py                # 引擎与会话
├── models.py            # SQLAlchemy 模型
├── schemas.py           # Pydantic 入参
├── deps.py              # 鉴权与 DB 依赖
├── seed.py              # 动作库种子数据
├── routers/             # 接口
├── services/            # LLM、计划生成、校验、问答、识别
└── prompts/             # 系统提示词
```

## 测试

```powershell
pytest -q
python scripts\smoke.py
```

冒烟测试覆盖用户建档、计划、训练、教练安全拦截、器械识别、饮食照片和 Agent 动作审计。
