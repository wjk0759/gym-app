# 长期数据模型：V12 变更

## 1. 精确数值

以下列从 `FLOAT` 改为 `DECIMAL`：

- `profiles.height_cm / weight_kg / body_fat_pct / chest_cm / waist_cm / hip_cm`
- `goals.target_weight_kg / target_body_fat_pct / target_waist_cm`
- `plan_exercises.weight_kg / rpe`
- `set_logs.weight_kg / rpe`
- `food_logs.grams / kcal / protein / carbs / fat / fiber`
- `body_metrics.weight_kg / body_fat_pct / waist_cm / arm_cm / thigh_cm`
- `meal_plans.target_protein_g / target_carb_g / target_fat_g`

SQLAlchemy 使用 `Numeric(..., asdecimal=False)`：数据库精确存储，Python 继续用 float 做估算和展示，避免大范围改动业务计算。

## 2. 身体数据：`body_metrics` 为事实来源

- `body_metrics` 允许只填体重、体脂、腰围、臂围、腿围中的任意一项，但不能全空。
- `backend/app/services/body_metrics.py` 统一处理：
  - 新增/更新 metric
  - 只把非空字段回写 `profiles` 缓存
  - 删除最新 metric 后重新计算缓存
- iOS `BodyMetric` 的 `weightKG / bodyFatPCT / waistCM` 改为可选；身体打卡允许留空，至少填一项。
- `profiles.weight_kg / body_fat_pct / waist_cm` 只作为读取缓存；计划生成和教练上下文在缓存缺失时回退。
- 档案编辑只在身体字段真正变化时写一条 metric，不再每次保存都复制全量快照。

后续可继续收紧：档案页的身体字段应只通过 `BodyMetricsService` 写入，而不是直接改 profile。

## 3. 器械：个人器械库为主

- 计划生成优先读取 `equipment_library.equipment` 类型。
- 器械库为空时才回退 `profiles.equipment`。
- `bodyweight` 永远可用。
- 新增/删除器械后，后端同步刷新 `profiles.equipment` 缓存。
- iOS 本地生成器也会把器械库 slug 对应的类型加入可用集合。

## 4. 完整性约束

V12 新增：

- `goals` / `programs` 每用户一个 active（虚拟生成列 + 唯一索引）
- `program_days(program_id, week_index, weekday)` 唯一
- `plan_exercises(program_day_id, order_index)` 唯一
- `set_logs(session_id, exercise_slug, set_index)` 唯一
- `notification_schedules(user_id, weekday)` 唯一（表保留，等以后接服务端提醒）
- `ai_memories(user_id, active_memory_key)` 唯一（只约束 active 记忆）
- `body_metrics` 至少一项测量的 CHECK
- `workout_sessions.client_id` 回填后改为 NOT NULL
- `chat_messages.created_at` 改为 `DATETIME(6)`
- `users` 的 Apple/微信/QQ 标识改为 `ascii_bin`
- 令牌/验证码哈希改为 `ascii_bin`

更新 `PATCH /workouts`、`PATCH /plans/.../days/...` 时先删除旧 sets/exercises 并 `flush()`，再插入新行，避免唯一约束冲突。

## 5. 搜索：不再使用 `%关键词%`

V12 增加中文 ngram 全文索引：

- `profiles.nickname`
- `exercises.name_zh, name_en`
- `equipment_library.name, notes`
- `chat_sessions.title`
- `programs.title`
- `exercise_videos.title`

后台查询改为：

- 手机号/用户名：前缀 `LIKE 'q%'`（走现有唯一索引）
- 昵称/标题/动作名/器械名/备注：`MATCH ... AGAINST` 全文索引
- 单字查询：前缀 `LIKE 'q%'` 兜底
- 精确 ID：主键

不再使用 `LOWER(COALESCE(...)) LIKE '%q%'`。注意：MySQL 在极小表上仍可能选择全表扫描；数据量上来后应定期用 `EXPLAIN ANALYZE` 复核，必要时把搜索改成“先查 ID 子查询，再按主键回表”。

## 6. 迁移与验证

- 迁移：`admin-server/src/main/resources/db/migration/V12__long_term_integrity.sql`
- 已在开发 MySQL 8.4 上通过 Flyway 应用，版本为 v12。
- 后端测试：112 passed。
- API smoke：通过。
- iOS Build：通过。
- Admin CI：通过。

## 7. 后续

1. 服务端提醒：实现 `notification_schedules` 的同步接口和定时任务。
2. 保留任务：`sms_codes`、`oauth_tickets`、`auth_sessions`、`ai_jobs`、`agent_runs`、`chat_sessions` 等仍无自动清理。
3. `meal_plans` 可补 `strategy / week_start / generated_by / model / updated_at`，减少解析 JSON 猜元数据。
4. 后台搜索在数据量增大后改为 ID 子查询 + 主键回表，确保不扫全表。
5. 档案页身体字段最终只通过 `BodyMetricsService` 写入。
