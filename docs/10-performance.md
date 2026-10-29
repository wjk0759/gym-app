# 10 · 性能优化记录

本轮优化覆盖后端查询、传输、iOS 本地持久化与网络链路，以及网页预览的本地存储写入。

## 1. 后端：消除 N+1 与减少重复查询

### 计划 / 训练 / 教练
- 计划查询统一使用 `selectinload(Program.days).selectinload(ProgramDay.exercises)`，避免序列化时逐天、逐动作触发查询。
- 计划保存、复制、编辑后统一重新加载完整计划，避免提交后懒加载。
- 训练列表、训练详情、训练总结批量加载 `sets`。
- 教练查询当前计划时预加载训练日与动作，避免构造上下文时 N+1。

### 后台
- 后台计划、训练、对话列表批量加载关联数据。
- 后台用户详情批量加载计划、训练、对话。
- 后台列表中的用户资料改为一次批量查询，不再逐条 `db.get(Profile, ...)`。
- 仪表盘最近用户、最近训练、最近安全事件改为批量查询/联表查询。

## 2. 索引与数据库连接

新增并通过 `ensure_schema()` 为已有开发库补齐以下索引：

- `workout_sessions(user_id, started_at)` 与 `started_at`
- `programs(user_id, status, version)` 与 `created_at`
- `chat_sessions(user_id, created_at)` 与 `created_at`
- `ai_jobs(created_at)`
- `exercise_videos(exercise_slug, status)`

SQLite 开启：

```sql
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA busy_timeout=5000;
PRAGMA foreign_keys=ON;
```

生产 PostgreSQL 仍建议用 Alembic 管理索引迁移。

## 3. 传输与外部调用

- 对 1KB 以上的 JSON 响应启用 GZip，计划和后台列表体积明显减小。
- DeepSeek/LLM 调用复用 `httpx.AsyncClient` 连接池，避免每次对话重新建立 TLS 连接。
- iOS 生成计划时并行同步 profile 与 goal，再发起计划生成，少一次串行等待。

## 4. iOS 本地性能

- `AppStore.persist()` 的 JSON 编码与原子写盘移到串行 utility 队列，不再阻塞主线程。
- 进入后台、切换账号、清空数据前调用 `flushPersistence()`，保证落盘顺序和数据安全。
- Keychain token 增加内存缓存，网络请求不再每次访问 Keychain。
- `APIClient` 复用 ISO8601/DateFormatter；每次解码使用独立 `JSONDecoder`，避免并发共享实例。
- 图片上传仍使用原图压缩，后续可在真机上继续做尺寸下采样。

## 5. 网页预览

- `localStorage` 写入改为 120ms 防抖，页面隐藏/关闭前强制 flush，减少频繁操作时的同步 JSON 序列化。
- 页面进入动画只在真正切页时播放，避免表单内选项切换触发整页重绘闪烁。

## 6. 本地基准

使用 `backend/scripts/perf_probe.py` 在内存压力较小的合成数据上测试：

- 60 条训练记录（每条 5 个动作）
- 25 个对话（每个 8 条消息）
- 1 个 4 周计划
- SQLite + Mock LLM

| 接口 | 优化前 SQL 次数 | 优化后 SQL 次数 |
|---|---:|---:|
| `GET /api/v1/workouts` | 51 | 2 |
| `GET /api/v1/workouts/summary` | 58 | 3 |
| `GET /api/v1/plans/current` | 14 | 3 |
| `GET /api/v1/admin/workouts`（已删除） | 53 | 4 |
| `GET /api/v1/admin/programs`（已删除） | 16 | 5 |
| `GET /api/v1/admin/chats`（已删除） | 28 | 4 |
| `GET /api/v1/admin/users/{id}`（已删除） | 97 | 13 |

SQL 次数比单次耗时更稳定。该表用于回归检查，不代表生产网络或真实 LLM 延迟。

复测：

```powershell
cd E:\Projects\FitAI\backend
.\.venv\Scripts\python.exe scripts\perf_probe.py
.\.venv\Scripts\python.exe scripts\bench_api.py --user-id <uuid> --requests 100 --concurrency 10
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe scripts\smoke.py
```

## 7. 2026-10 后端审计加固

这轮不只优化查询，还处理了并发写入、LLM 等待期间占用数据库连接、客户端重试重复写入和联动数据回归。

### 7.1 查询与响应

- 新增 `services/queries.py`、`services/locking.py`，计划/目标/用户行锁统一复用，避免各路由重复实现和 N+1。
- 训练列表不带 `include_sets` 时不再加载全部组记录，只按当前页做一次 `GROUP BY` 查 `set_count`；默认增加 `offset` / `has_more`。
- 训练汇总改为 SQL 聚合（按 session 汇总容量），不再把全部 `set_logs` 读进 Python。
- 用户导出一次性预加载计划日/动作和训练组，消除 `programs × days × exercises` 与 `sessions × set_logs` 的重复扫描。
- 周复盘、Agent 的饮食/训练上下文改为 SQL 聚合，避免把整周/整月明细全部加载。
- 后台 AI 概览改为聚合 SQL；后台统计的 14 个单表 count 合并为一条多 scalar subquery 查询。
- 新增聊天/训练/目标/器械扫描的复合索引；MySQL 迁移为 `V7__backend_performance.sql`。

`perf_probe.py` 复测的代表性 SQL 次数（其中 `/api/v1/admin/*` 为迁移前历史数据，接口已删除）：

| 接口 | 优化后 SQL 次数 |
|---|---:|
| `GET /api/v1/workouts` | 2 |
| `GET /api/v1/workouts/summary` | 2 |
| `GET /api/v1/plans/current` | 3 |
| `GET /api/v1/admin/stats`（已删除） | 13 |
| `GET /api/v1/admin/users/{id}`（已删除） | 15 |

### 7.2 并发与连接池

- 数据库连接池可配置：`DB_POOL_SIZE`、`DB_MAX_OVERFLOW`、`DB_POOL_TIMEOUT`、`DB_POOL_RECYCLE`；同步路由线程池由 `THREAD_POOL_SIZE` 控制。
- Agent、教练、计划生成在 `await` 模型前释放数据库连接/事务，避免一次 30–90 秒的 LLM 调用占住连接池。
- LLM 连接池和并发信号量可配置：`LLM_MAX_CONCURRENCY`、`LLM_TIMEOUT_SECONDS`，防止单进程把上游限流打满。
- Agent 的记忆提炼改为后台任务，不再把第二轮 LLM 调用算进用户回复延迟；后台任务使用独立 session。
- Docker 默认使用 `WEB_CONCURRENCY=4` 的 uvicorn worker；实际连接数应按 `worker 数 × DB_POOL_SIZE` 控制在 MySQL `max_connections` 内。
- 后台管理已迁移到 Spring Boot + Vue；FastAPI 不再挂载 `/admin`，也不再接受管理端令牌。管理 API、RBAC、审计和短期 JWT 全部由 Spring 控制面负责。

### 7.3 数据闭环与幂等

- 训练记录新增 `client_id`（客户端本地 UUID）和 `UNIQUE(user_id, client_id)`：离线同步重试不会再创建重复训练。
- 身体数据按测量时间维护 profile 聚合值：旧数据晚到不会覆盖新体重；删除最新记录会回退到上一条最新记录。
- 饮食计划增加 `(user_id, plan_date)` 唯一约束和并发冲突重试。
- 目标、计划、草案应用、refresh token 轮换增加行锁/唯一约束保护，减少并发重复 active 计划和重复应用草案。
- 饮食/身体/器械的 `client_id` 同步在唯一冲突时会重新读取并更新，而不是返回 500。
- 修复了身体/器械删除接口的错误提示乱码，以及 `date_to` 边界少一天的过滤问题。

### 7.4 可观测性

- 所有响应增加 `X-Request-ID` 和 `Server-Timing`；请求日志包含 method/path/status/耗时/request_id。
- 未捕获异常统一返回 `{"error":{"code":"INTERNAL_ERROR",...}}`，不再暴露堆栈；`/health/ready` 检查数据库可用性。

### 7.5 本地基准说明

同一台 Windows 开发机、SQLite、单 uvicorn 进程，单请求 p50（预热后 40 次）：

| 接口 | 优化前 | 优化后 |
|---|---:|---:|
| `GET /api/v1/me` | 7.4 ms | 4.4 ms |
| `GET /api/v1/workouts` | 8.5 ms | 5.3 ms |
| `GET /api/v1/workouts/summary` | 8.8 ms | 6.1 ms |
| `GET /api/v1/body/metrics` | 7.8 ms | 6.5 ms |
| `GET /api/v1/admin/stats`（已删除） | 13.8 ms | 13.4 ms |

并发压测（200 请求 / 20 并发）中，后台统计 p50 从约 1564 ms 降到 1296 ms，吞吐从约 69.5 RPS 提升到 84.9 RPS；其余读接口主要受单进程 GIL 和测试机负载影响，数字波动较大。Windows 单进程 SQLite 的并发数字不能直接当作生产容量。生产验收应在 MySQL + 4 worker 下重跑 `bench_api.py`，并观察连接池等待、MySQL slow query、LLM 429 率。

## 8. ProMotion / 高刷新率（2026-10）

- `Info.plist` 增加 `CADisableMinimumFrameDurationOnPhone = true`。
- 没有这个声明时，iPhone Pro/Pro Max 的 ProMotion 屏幕会被系统限制在 60Hz，表现为整个 App 的滚动、弹层、转场都像低刷新率。
- 仅在 ProMotion 机型上生效；非 Pro iPhone 的硬件上限仍是 60Hz。低电量模式也会主动限制高刷新率。
- 验证时不要用微信/普通屏幕录制判断帧率：本次收到的录屏是约 27.6fps 的 30fps 文件。需要在真机上用 Xcode Instruments（Core Animation / Time Profiler）或 DEBUG 帧率探针确认。
- 如果开启后仍有单个页面掉帧，再按页面查主线程阻塞、材质/阴影合成和 `TimelineView` 重绘，不要把所有问题都归因于刷新率。

## 9. 后续可继续做的优化

- 后台对话/训练列表用 SQL 聚合替代加载完整消息和训练组，进一步降低大数据量下的内存占用。
- iOS 图片上传前按 1600px 左右下采样，减少视觉模型上传时间。
- 真机上用 Instruments（Time Profiler / Allocations / Network）验证 SwiftUI 滚动与启动耗时。
- 配置真实 DeepSeek Key 后，单独统计首 token 延迟和完整回复延迟；当前流式接口已存在，iOS 端尚未消费流式回复。
- App Action 执行结果已回写 `agent_action_events`，Spring 后台已提供动作审计页；训练排期已支持跨设备同步，5 分钟本地撤销已实现。跨设备撤销仍未完成。
- 多实例部署时把登录/短信限流从进程内字典迁移到 Redis，并增加 AI 接口的用户级配额。
