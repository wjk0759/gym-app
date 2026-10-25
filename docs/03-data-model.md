# 03 · 数据模型

完整的 DDL 见 `db/schema.sql`。本文解释设计意图与约定。

## 1. 约定

| 约定 | 说明 |
|---|---|
| 主键 | 业务实体用 UUID；动作库用可读 slug（如 `bench_press`） |
| 时间 | `timestamptz`，UTC 存储；客户端展示本地时间 |
| weekday | **1=周一 … 7=周日**（不是 `Calendar` 的 1=周日，转换在客户端做） |
| 重量 | `numeric(5,1)`，单位 kg |
| 次数 | `text`，支持 `"8-10"`、`"12"`、`"30s"`，兼容计时动作 |
| 计划版本 | 每次 AI 调整生成新 `programs` 行，旧版本 `archived`，不原地改 |
| 软删除 | 仅 `users.deleted_at`；注销后 15 天内可恢复，之后物理删除 |

## 2. 实体关系

```
users 1─1 profiles
users 1─n goals（同一时间仅 1 个 active）
users 1─n programs 1─n program_days 1─n plan_exercises n─1 exercises
users 1─n workout_sessions 1─n set_logs n─1 exercises
users 1─n notification_schedules
users 1─n chat_sessions 1─n chat_messages
users 1─n equipment_scans
users 1─n meal_plans / nutrition_logs / diet_links
users 1─n ai_jobs / ai_memories
```

## 3. 关键表说明

### profiles

- `equipment` 是用户可用器械的白名单，计划生成时用于过滤动作。
- `injuries` 是自由文本数组，除了给模型看，还要走关键词规则（膝、腰、肩、腕、踝、术后）。
- `weekly_days` 与 `session_minutes` 是计划编排的硬约束。

### goals

- 用部分唯一索引保证同一用户只有一个 active 目标。
- 目标值可空：增肌用户可能只设体重，减脂用户可能只设腰围。

### exercises

- `contraindications` 是动作禁忌标签（如 `knee_pain`、`lower_back`），与用户伤病做交集。
- `video_url` 必须对应已授权素材；`license` 字段记录授权来源，审核和维权时要用。
- `source` 区分 `self_produced` / `licensed` / `public_domain`。

### programs / program_days / plan_exercises

- `programs.status='active'` 每用户唯一（部分唯一索引）。
- `program_days` 以 `(program_id, week_index, weekday)` 唯一，支持 4 周渐进。
- 渐进超负荷当前落在 `plan_exercises.weight_kg` 与 `reps` 上；后续可加 `tempo`、`distance`。
- 若要做“同一天不同周不同动作”，直接把每周写成独立 `program_days` 即可。

### workout_sessions / set_logs

- 训练记录以“组”为最小单位，这是 AI 调整的唯一事实来源。
- `rpe` 允许空；空值不参与负荷调整，只统计完成率。
- `program_day_id` 允许为空：用户可能自由训练，不套计划。

### notification_schedules

- 客户端是提醒的真正执行者；这张表用于跨设备同步和服务端统计。
- 同一用户同一天只保留一条，修改即覆盖。

### ai_jobs / ai_memories

- `ai_jobs` 用于成本、延迟、失败率观测；不存完整 prompt（隐私）。
- `ai_memories.embedding` 维度 1024，对应通义 `text-embedding-v3` 或 BGE-M3。换模型需重建索引。
- 记忆分四类：`preference`（不喜欢/偏爱动作）、`injury`、`summary`（阶段总结）、`feedback`（用户对计划的反馈）。

## 4. 索引与性能

| 索引 | 用途 |
|---|---|
| `workout_sessions(user_id, started_at desc)` | 首页最近训练、周统计 |
| `set_logs(session_id)` | 训练详情 |
| `exercises(muscle_group, equipment)` | 换动作候选 |
| `chat_messages(session_id, created_at)` | 对话加载 |
| `ai_jobs(user_id, created_at desc)` | 成本排查 |
| `ai_memories` HNSW | 语义检索（数据量 >1 万再建） |

## 5. 数据保留

| 数据 | 保留策略 |
|---|---|
| 训练记录 | 用户主动删除前一直保留 |
| 聊天记录 | 默认 12 个月，可配置 |
| 器械图片 | 识别后 30 天删除原图，只留结果 |
| AI 调用日志 | 6 个月（合规审计） |
| 注销账号 | 15 天冷静期后物理删除，备份 30 天内清除 |

## 6. 迁移策略

当前后端用 SQLAlchemy `create_all` 快速起步。进入联调前引入 Alembic：

```bash
alembic init migrations
alembic revision --autogenerate -m "init"
alembic upgrade head
```

生产禁止 `create_all`。`db/schema.sql` 只作为初始基线，后续所有变更走 Alembic。
