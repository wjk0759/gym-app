# FitAI 企业级管理后台架构

> 版本：1.1 · 2026-10-28
> 范围：后台管理控制面（Vue3 + Spring Boot + MySQL），不包含 iOS/Web App 的迁移。

## 1. 目标与边界

这次重构要解决的不是“把页面换个框架”，而是把后台从 FastAPI 内置脚本式管理页，升级成**可独立部署、可授权、可审计、可观测、可回归**的控制面。

边界：

- **App API 继续由 FastAPI 提供**：iOS/Web 的用户登录、计划、训练、教练、器械、饮食等接口不受影响。
- **后台控制面独立**：`admin-web` + `admin-server`，单独构建、部署、扩缩容和发布。
- **共享 MySQL 8**：Spring Boot 管理后台表，并读取/管理 FastAPI 的 App 数据。
- **明确过渡方案**：当前阶段由 admin-server 的 Flyway 管理完整 schema；这是为了避免两套 ORM 各自建表。后续若 App API 也迁移到 Spring Boot，再将 schema 管理权迁移到统一平台团队。
- **旧后台已迁移完成**：FastAPI 的 `/admin`、`/api/v1/admin/*`、静态管理资源和 `ADMIN_*` 配置已删除；Spring + Vue 是唯一正式后台。

不做过度设计：后台规模不需要微服务、Kafka、Redis 或独立搜索集群。当前采用**模块化单体**，按业务能力分包，保留拆分边界。

## 2. 总体架构

```text
                    HTTPS
                      │
              ┌───────▼────────┐
              │  Nginx / CDN   │
              │ /admin, /api   │
              └───┬────────┬───┘
                  │        │
      Vue3 SPA ───┘        └─── Spring Boot Admin
      (Element Plus)            (Java 21)
                                     │
                              Spring Security
                              JWT + Refresh
                              RBAC + Audit
                                     │
                                  MySQL 8
                                     ▲
                                     │
                              FastAPI App API
                              (iOS / Web App)
```

### 模块划分

```text
admin-server/src/main/java/com/fitai/admin
├── common
│   ├── api          统一 PageResponse / ApiException
│   ├── audit        审计写入
│   ├── persistence  JSON/Timestamp/SQL 工具
│   └── web          RequestId、RFC 9457 错误处理
├── config           JWT、CORS、OpenAPI、MVC、Security
├── security         AdminPrincipal、JWT、Refresh Token、RBAC、登录限流
├── dashboard        运营指标
├── users            用户与画像
├── plans            训练计划
├── schedule         跨设备排期状态
├── workouts         训练记录
├── chats            教练对话
├── scans            器械识别
├── exercises        动作库
├── videos           教学视频 + 媒体上传
├── ai               AI 调用与质量指标
├── agent            Agent 运行与 App 动作审计
├── audit            审计查询
└── media            媒体存储
```

每个业务模块按 `Controller → Service → Repository` 分层；Repository 使用 **Spring JDBC `JdbcClient` + 明确 SQL**，而不是让 JPA 自动生成复杂后台查询。理由：

- 后台以读模型和跨表聚合为主，SQL 可解释、可 explain、可加索引。
- 避免与 FastAPI 的 SQLAlchemy 模型产生两套 Entity 映射漂移。
- 写操作仍然走 Service + 事务 + 审计，不把业务逻辑塞进 Controller。

## 3. 认证与权限

### 登录链路

1. `POST /api/admin/v1/auth/login` 使用用户名/密码 + BCrypt(12)。
2. 成功后返回 15 分钟 Access Token（JWT，内存保存），并写入 7 天 Refresh Token 到 **HttpOnly + SameSite=Strict Cookie**。
3. Refresh Token 只存 SHA-256 哈希；每次刷新都会轮换并撤销旧 token。
4. 修改密码、重置他人密码、停用账号会撤销该账号的全部 Refresh Token。
5. 生产环境 `FITAI_COOKIE_SECURE=true`，配合 HTTPS。

Access Token 不落 `localStorage`，避免常见 XSS 直接窃取长期会话。Access Token 过期后由 Axios 单飞刷新逻辑自动续期。

### RBAC

种子角色：

| 角色 | 用途 |
|---|---|
| `SUPER_ADMIN` | 全部权限，包括后台账号管理 |
| `OPERATOR` | 日常运营、内容、用户与计划管理 |
| `AUDITOR` | 只读与审计 |

权限码示例：`user:read`、`user:write`、`plan:read`、`video:write`、`audit:read`、`settings:manage`。

前端：路由守卫 + `v-permission` 指令 + 菜单过滤。  
后端：`@PreAuthorize("hasAuthority('...')")`，前端权限不能替代后端校验。

### 初始管理员

开发环境：

```env
FITAI_BOOTSTRAP_USERNAME=admin
FITAI_BOOTSTRAP_PASSWORD=ChangeMe@123456
```

首次启动创建后立即设置 `FITAI_BOOTSTRAP_ENABLED=false`。生产环境不应把初始密码提交到 Git。

## 4. API 契约

- 基础路径：`/api/admin/v1`
- 分页：`page`（1-based）、`size`（最大 100）
- 列表响应：`{ items, page, size, total, totalPages }`
- 错误：RFC 9457 `application/problem+json`，包含 `code`、`requestId`、`errors`
- 请求关联：`X-Request-Id` 贯穿网关、日志和审计
- OpenAPI：`/swagger-ui.html`（生产关闭）
- 审计：所有写操作 + 登录/刷新/密码事件写入 `admin_audit_logs`

REST 风格示例：

```text
GET    /api/admin/v1/users?q=alice&status=active&page=1&size=20
GET    /api/admin/v1/users/{id}
PATCH  /api/admin/v1/users/{id}/status
DELETE /api/admin/v1/users/{id}
DELETE /api/admin/v1/users/{id}/purge
POST   /api/admin/v1/users/{id}/restore
GET    /api/admin/v1/schedule?planId=...
GET    /api/admin/v1/agent/actions?status=executed
GET    /api/admin/v1/videos
POST   /api/admin/v1/videos
POST   /api/admin/v1/videos/{id}/publish
POST   /api/admin/v1/videos/upload
```

## 5. 数据库与迁移

- MySQL 8（UTF-8 MB4，UTC）
- Flyway：
  - `V1__fitai_app_schema.sql`：App 表，来源 `backend/app/models.py`
  - `V2__admin_console.sql`：管理员、角色、权限、Refresh Token、审计索引
- SQLite → MySQL 迁移工具：`tools/db/migrate_sqlite_to_mysql.py`
  - 支持 `--dry-run`
  - `--replace` 仅清空 App 表，不覆盖 `admin_users`
  - 迁移后做源/目标行数校验

### 数据所有权（过渡期）

| 数据 | 主写方 | 后台权限 |
|---|---|---|
| 用户/档案/目标/计划/训练/对话/识别 | FastAPI | 读 + 受控管理操作 |
| 后台账号/角色/权限/Refresh Token | Spring Boot | 读写 |
| 动作库/教学视频 | 后台 + App 读取 | 读写 |
| 审计 | Spring Boot | 追加 + 审计只读 |

**风险**：过渡期两个服务都能写 App 表。控制措施：后台写操作必须通过 Service 层、RBAC 和审计；后续应把 App 的写操作也迁移到统一的领域 API，或把后台 App 写操作收敛为 FastAPI 内部命令接口。

## 6. 前端架构

```text
admin-web
├── api/          Axios 客户端、模块 API、类型定义、会话处理
├── stores/       Pinia auth store
├── router/       路由、权限守卫
├── layouts/      管理台壳布局、响应式侧栏、修改密码
├── components/   分页、指标卡、状态标签、趋势图、JSON 展示
├── views/        14 个业务模块 + 登录 / 403 / 404
├── directives/   v-permission
└── utils/        日期/状态/数值格式化
```

- Vue 3 `<script setup>` + TypeScript + Vite
- Element Plus 深色主题
- 路由懒加载、构建分包
- Access Token 只存在内存；刷新 Cookie 由浏览器管理
- 页面统一 loading、空态、错误提示、确认弹窗
- 窄屏 320/430、桌面、侧栏折叠均已适配

## 7. 可观测性与运维

- Spring Boot Actuator：`/actuator/health`、`/actuator/info`、`/actuator/prometheus`
- Micrometer 指标；生产只暴露 health + prometheus
- 请求 ID 写入 MDC，错误响应/审计可关联
- 慢 SQL / 数据库连接池日志可通过 profile 调整
- Docker 多阶段构建、非 root 运行、健康检查
- Nginx：安全响应头、gzip、SPA fallback、`/api` 与 `/media` 反代
- 生产必须由 TLS 入口终止 HTTPS，并设置 Cookie Secure

## 8. 测试策略

- 后端：
  - JWT 签发/解析/错误签名单元测试
  - SQL/分页工具单元测试
  - Testcontainers MySQL 集成测试：Flyway → 初始管理员 → 登录 → RBAC → Dashboard
  - 本地无 Docker 时集成测试自动跳过；CI 有 Docker 时执行
- 前端：
  - `vue-tsc` 严格类型检查
  - Vitest 单元测试
  - Vite production build
- CI：`.github/workflows/admin-ci.yml`

## 9. 发布与回滚

1. 先执行数据库迁移（Flyway 在应用启动时执行，建议先跑迁移 job）。
2. 部署 admin-server，检查 `/actuator/health/readiness`。
3. 部署 admin-web 静态资源。
4. 回滚应用镜像不会自动回滚数据库；Flyway 迁移遵循前向兼容，破坏性变更使用 expand/contract。
5. 数据迁移工具是一次性脚本，不在运行时执行。

## 10. 后续演进

优先级从高到低：

1. 为后台 App 写操作增加“操作理由”与二次确认/审批（用户删除、批量操作）。
2. 引入 Redis 做多实例登录限流、Refresh Token 黑名单和分布式锁。
3. 接入企业 SSO（OIDC）和 MFA；`admin_users` 增加 TOTP。
4. 将 App schema 的迁移所有权移交给独立迁移仓库，后台 Flyway 只管理 `admin_*` 表。
5. 若后台团队和 App 团队规模扩大，再考虑把 App API 逐步迁移到 Spring Boot 或内部命令服务；当前不为了“看起来企业级”而拆微服务。
