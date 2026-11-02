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

- 迁移：`admin-server/src/main/resources/db/migration/V12__long_term_integrity.sql`、`V13__meal_plan_metadata.sql`
- 已在开发 MySQL 8.4 上通过 Flyway 应用，当前 schema 版本 v13。
- 后端测试：116 passed。
- API smoke：通过。
- iOS Build：通过。
- Admin CI：通过。

## 7. 餐单来源与周元数据（V13）

- `meal_plans` 新增 `week_start / strategy / generated_by / model_name / updated_at`。
- 单日/整周保存统一走 `backend/app/services/meal_plans.py`，不再由 router 拼 SQL。
- 读取一周计划直接从列取来源，不再解析 `plan` JSON 猜 `generated_by`。
- V13 已在开发 MySQL 上应用，当前 schema 版本 v13。

## 8. 档案身体字段的单写入口

- `PUT /me/profile` 只在首次建档（`onboarded_at IS NULL`）时接受体重/体脂/腰围。
- 已建档用户的身体变化必须走 `/body/metrics`；profile 字段由 `BodyMetricsService` 维护。
- 这样避免档案表单和身体打卡各写一份、互相覆盖。

## 9. 保留清理任务

`admin-server` 新增 `RetentionService`：

- 默认在 dev 关闭，prod 开启。
- 每天 03:30 分批清理：短信码、OAuth ticket、过期会话、认证事件、AI job、过期计划草案、12 个月聊天、后台 refresh token、审计日志、器械识别、计划排期状态、停用记忆、一年前的 agent run。
- 每批 2,000 行，最多 50 批，避免长事务和大锁。
- 配置：`fitai.admin.retention.enabled / batch-size / cron`。

## 10. 后台搜索的 ID 子查询

- 用户类搜索先解析出 ID 集合（主键、手机号/用户名前缀、昵称 ngram），再用 `STRAIGHT_JOIN` 回表。
- 计划/聊天/器械/视频/动作把自身文本 ID 与用户 ID 合并后再回表。
- 这样 SQL 不再依赖 `LOWER(...) LIKE '%q%'` 的 OR 条件；数据量增大时优化器有明确的索引路径。
- 仍需在真实数据量上用 `EXPLAIN ANALYZE` 复核，尤其是聊天和计划表。

## 11. 清理的无引用代码

- 删除 `ios/FitAI/Features/Home/HomeView.swift`（旧首页，无引用）。
- 删除 `ios/FitAI/Features/Onboarding/OnboardingView.swift`（旧引导，无引用）。
- 删除 `NutritionView` 中 8 个未使用的旧卡片/函数，约 270 行。

## 12. 权益、试用与额度（V14–V19）

- `user_entitlements`：Pro 权益台账。来源 `admin / storekit / promo`，按 `starts_at / expires_at / revoked_at` 判断有效；不在 `users` 上存布尔值。
- `feature_trials`：一次性体验，唯一键 `(user_id, feature_key)`。训练计划来源 `onboarding`，饮食周计划来源 `first_generation`；老用户已在 V14 回填。
- `feature_usage`：按自然周（Asia/Shanghai）记录 AI 教练用量，免费用户每周 3 条；安全/医疗回复不计入。
- `feature_generation_state` V17：计划/饮食周计划的持久冷却、进行中锁和幂等回放。成功后才开始 60 秒冷却；相同 `Idempotency-Key` 在 10 分钟内返回已保存结果。
- `rate_limit_buckets` V18：按 `(feature, user)` 的分布式 token bucket，所有 worker 共享同一额度，避免进程内限流被多 worker 绕过。
- `ai_runtime_control` V19：全局 AI 开关。暂停时仅 `users.is_test` 白名单可用，其他请求降级到规则/Mock；后台变更写审计日志。
- `ai_jobs`：新增按调用记录 `input_tokens / output_tokens`，后台 AI 用量页和全局日/月预算共用这一份数据。
- `auth_sessions` V15/V16：`last_touched_at`、refresh 轮换宽限期、`device_id`。持续使用会滑动延长 30 天，异常复用撤销会话；同设备重登只保留最新会话，单账号最多 5 个活跃设备会话。
- 客户端只展示服务端快照，Pro / 体验 / 额度最终由 API 校验；付费墙和锁定 UI 不得替代服务端权限判断。

## 13. 后续

1. 服务端提醒：实现 `notification_schedules` 的同步接口和定时任务（当前只保留表与唯一约束）。
2. AppStore 拆分：`LocalStateStore`、`CoachRequestController`、同步服务，降低单文件复杂度。
3. 大 View 拆分：`PlanHomeView`、`EquipmentDetailView`、`CoachChatView`、`WorkoutSessionView`。
4. `agent_steps` 的 JSON 体积与保留策略继续优化。
5. 在 App Store Connect 隐私标签中逐项核对 `PrivacyInfo.xcprivacy`。
6. 后台搜索在真实数据量上用 `EXPLAIN ANALYZE` 复核，必要时继续收紧 ID 子查询。
