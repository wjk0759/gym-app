# 工程规范

这份规范约束 FitAI 的长期维护方式。新代码优先遵守；改动旧代码时，至少不要扩大例外。

## 1. 分层

### iOS

- `Features/*`：页面、组件、交互状态。不要直接拼 SQL/HTTP 请求。
- `Core/Services`：API、持久化、同步、纯业务引擎。
- `Core/Models`：Codable 领域模型。
- `Core/Design`：颜色、字体、间距、通用组件。
- 复杂页面拆成 `View` + `@Observable` 状态对象 + 纯引擎。纯计算不要写在 `body` 里。
- 新页面优先复用 `AppScrollView`、`.card()`、`EditorialHeader`、`EmptyStateView`、`TagChip`、`APITransport`，不要另起一套。

### 后端

- `routers/*`：HTTP 参数、权限、状态码、事务边界。
- `services/*`：领域逻辑、序列化、查询、外部服务。
- `models.py`：SQLAlchemy 持久化模型。
- `schemas.py`：输入校验；后续补输出模型。
- 一个 service 只负责一个领域；不要在一个文件里同时做识别、器械库、计划生成。
- 路由不直接拼复杂 SQL；查询放进 `services/queries.py` 或对应领域 service。

### 后台

- `Repository` 只做 SQL/映射；业务规则放 `Service`。
- 所有列表必须分页，且排序带主键 tiebreaker。
- 搜索必须使用索引路径：全文索引、前缀索引或 ID 子查询，不允许新增 `LOWER(...) LIKE '%q%'`。

## 2. 命名

- 数据库：`snake_case`；表名复数；外键 `<entity>_id`；时间字段 `created_at / updated_at / deleted_at`。
- Python：`snake_case`；service 函数用动词开头（`save_`、`list_`、`apply_`）。
- Swift：类型 `UpperCamelCase`；属性/方法 `lowerCamelCase`；布尔值用 `is/has/can/should`。
- 迁移：`V<number>__<short_description>.sql`，只增不改。

## 3. 数据与事务

- 数值：金额、体重、围度、重量、宏量营养素用 `DECIMAL`；Python 侧用 `Numeric(..., asdecimal=False)` 保持计算简单。
- 身体数据：`body_metrics` 是事实来源；`profiles` 的身体字段是缓存，只允许 `BodyMetricsService` 写。
- 器械：`equipment_library` 是个人器械事实来源；`profiles.equipment` 是兼容缓存。
- 服务层不擅自 `commit()`；由用例/路由统一提交。需要 flush 时显式 `flush()`。
- 更新子集合（sets/exercises）必须先删除旧行并 `flush()`，再插入新行，避免唯一约束冲突。
- 所有外部调用（LLM、短信、天气）前后不要长时间持有数据库事务。

## 4. 数据库迁移

- 只通过 Flyway 迁移，不在应用启动时做破坏性 DDL/DML。
- 加唯一约束前先做去重预检。
- 大表改类型/加索引使用在线 DDL 或 gh-ost/pt-online-schema-change。
- 新表必须有主键、必要外键、`created_at`，可变数据加 `updated_at`。
- 新增索引必须对应真实查询；不要为了“可能有用”加索引。

## 5. 搜索与分页

- 中文文本用 `FULLTEXT ... WITH PARSER ngram`。
- 手机号/用户名用前缀 `LIKE 'q%'`，不要包 `%`。
- 精确 ID 用主键。
- 单字查询用前缀兜底。
- 列表统一 `limit/offset`，默认 20–50，最大 100；排序字段后加主键。
- 数据量增大后用 `EXPLAIN ANALYZE` 验证，不接受“碰巧能跑”的查询。

## 6. 错误与日志

- API 错误使用 `{code, message, details}`；不要只返回裸字符串。
- 对用户隐藏上游供应商错误；完整错误只进日志/任务表。
- 日志带 `request_id`；不要记录密码、令牌、完整手机号、图片内容。
- 外部调用失败必须降级或返回明确错误，不能静默吞掉。

## 7. 保留与删除

- 用户注销：15 天冷静期，期满删除或匿名化。
- 聊天/会话/任务日志有明确 TTL；`RetentionService` 分批清理。
- 删除用户时检查 `ON DELETE SET NULL` 留下的审计行。
- 本机数据、进展照片、系统备份要在 UI 文案中如实说明。

## 8. 测试

- 纯逻辑必须有单元测试：计划生成、目标计算、身体数据缓存、餐单元数据、安全拦截。
- 涉及金额/健康/删除的改动必须有回归测试。
- API smoke 覆盖登录、档案、计划、训练、饮食、身体数据、导出。
- iOS 纯引擎可放 `FitAITests`；UI 流程用真机/Maestro 另行验收。

## 9. Code Review 清单

- 是否新增了重复的序列化/查询/UI 组件？
- 是否绕过了 service 直接写数据库/状态？
- 是否引入 `%q%` 搜索、无分页列表、无 tiebreaker 排序？
- 是否在事务里调用 LLM/短信/天气？
- 是否新增 `FLOAT` 存业务数值？
- 是否有未使用代码、死文件、重复常量？
- 是否有迁移回滚/数据回填方案？
- 是否更新了 `docs/44-long-term-data-model.md` 和 `docs/43-legal-docs.md`（涉及数据流时）？

## 10. 当前例外（需要逐步消除）

- `AppStore` 仍是 God object；后续拆 `LocalStateStore`、`CoachRequestController`、同步服务。
- `PlanHomeView`、`EquipmentDetailView`、`CoachChatView` 等仍偏大；按页面拆组件。
- `PlanHomeView`/`WorkoutSessionView` 仍有部分业务计算在 View 内。
- 部分 service 仍有内部 `commit()`；新代码不要再增加。
- 后端部分错误仍是裸字符串；新代码必须用结构化错误。
