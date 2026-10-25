# FitAI Backend

FastAPI + SQLAlchemy，默认 SQLite 零依赖启动，生产切 PostgreSQL。

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

首次启动会自动建表，并写入 27 个基础动作。

## 接入真实模型

编辑 `.env`：

```ini
LLM_PROVIDER=deepseek
LLM_API_KEY=sk-...
LLM_BASE_URL=https://api.deepseek.com/v1
LLM_MODEL=deepseek-chat
```

任何 OpenAI 兼容接口都可以（通义、豆包、DeepSeek）。没有 Key 时自动使用规则模板，不影响调试。

## 切 PostgreSQL

```powershell
docker compose up -d db
```

`.env`：

```ini
DATABASE_URL=postgresql+psycopg://fitai:fitai@localhost:5432/fitai
```

生产环境请用 `db/schema.sql` 初始化，并引入 Alembic 管理迁移。

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
```
