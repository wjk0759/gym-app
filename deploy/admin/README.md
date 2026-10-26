# FitAI 管理后台部署

## 一键启动（Docker Compose）

```bash
cd deploy/admin
cp .env.example .env
# 修改 .env 中的数据库密码、FITAI_JWT_SECRET 和初始管理员密码
docker compose up -d --build
```

访问 <http://localhost:8088/admin/>。

- 首次启动会通过 Flyway 创建 MySQL schema，并创建 `FITAI_BOOTSTRAP_USERNAME` 指定的初始管理员。
- 创建成功后，将 `FITAI_BOOTSTRAP_ENABLED=false`，然后滚动重启 admin-server。
- 生产环境必须启用 HTTPS，并把 `FITAI_COOKIE_SECURE=true`。
- `FITAI_JWT_SECRET` 至少 32 字节；建议使用 `openssl rand -base64 64` 生成。
- 视频/封面写入 `fitai-admin-media` 卷；生产建议替换为 OSS/COS + CDN。

## 本地开发

```bash
# 1. MySQL（可复用 docker compose 的 mysql 服务）
docker compose -f deploy/admin/docker-compose.yml up -d mysql

# 2. Spring Boot
cd admin-server
export FITAI_DB_URL='jdbc:mysql://127.0.0.1:3307/fitai?useUnicode=true&characterEncoding=utf8&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC'
export FITAI_DB_USERNAME=fitai
export FITAI_DB_PASSWORD=fitai
export FITAI_JWT_SECRET='dev-only-change-this-secret-at-least-32-bytes'
mvn spring-boot:run

# 3. Vue3
cd ../admin-web
npm install
npm run dev
```

开发地址：<http://127.0.0.1:5173/admin/>。Vite 会把 `/api` 与 `/media` 代理到 Spring Boot 的 8080 端口。

## 旧 SQLite 数据迁移

Flyway 建好 MySQL schema 后执行：

```bash
python tools/db/migrate_sqlite_to_mysql.py \
  --source backend/fitai.db \
  --target 'mysql+pymysql://fitai:fitai@127.0.0.1:3307/fitai?charset=utf8mb4' \
  --replace
```

`--replace` 只清空应用表，不会清空 `admin_users` 等后台身份表。建议先执行 `--dry-run` 核对行数。

## 与 FastAPI 的关系

FastAPI 仍负责 iOS/Web 的 App API；Spring Boot 只负责后台管理控制面。两者共享 MySQL：

- Spring Boot 通过 Flyway 管理 schema（阶段一过渡方案）。
- FastAPI 通过 `DATABASE_URL` 连接同一个 MySQL，启动时跳过 SQLite 兼容脚本。
- 后台对 App 表的写操作（用户停用、删除等）会立即影响 App 读取结果，因此必须经过 RBAC 和审计。
