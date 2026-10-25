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
| `GET /api/v1/admin/workouts` | 53 | 4 |
| `GET /api/v1/admin/programs` | 16 | 5 |
| `GET /api/v1/admin/chats` | 28 | 4 |
| `GET /api/v1/admin/users/{id}` | 97 | 13 |

SQL 次数比单次耗时更稳定。该表用于回归检查，不代表生产网络或真实 LLM 延迟。

复测：

```powershell
cd E:\Projects\FitAI\backend
.\.venv\Scripts\python.exe scripts\perf_probe.py
.\.venv\Scripts\python.exe -m pytest -q
.\.venv\Scripts\python.exe scripts\smoke.py
```

## 7. 后续可继续做的优化

- 后台对话/训练列表用 SQL 聚合替代加载完整消息和训练组，进一步降低大数据量下的内存占用。
- iOS 图片上传前按 1600px 左右下采样，减少视觉模型上传时间。
- 真机上用 Instruments（Time Profiler / Allocations / Network）验证 SwiftUI 滚动与启动耗时。
- 配置真实 DeepSeek Key 后，单独统计首 token 延迟和完整回复延迟；当前流式接口已存在，iOS 端尚未消费流式回复。
