# Coach Agent 运行时与数据库设计

> 第一阶段：可审计的教练 Agent。模型可以读取上下文、生成计划草案、记录偏好，但不能直接修改正式计划。

## 1. 原则

```text
LLM 负责理解意图和选择工具
Python 负责数据访问、规则校验、事务和权限
用户负责确认是否应用新计划
```

Agent 不允许直接 `UPDATE programs`。所有计划变更必须先成为 `agent_plan_proposals` 中的草案，再通过用户确认接口写入。

## 2. 数据流

```text
POST /api/v1/agent/chat
  → agent_runs
  → agent_steps (decision / tool / observation)
  → get_context
  → get_recent_training
  → propose_plan
      → 规则模板 + validate_plan
      → agent_plan_proposals (draft)
  → reply + proposal
  ↓ 用户确认
POST /api/v1/agent/proposals/{id}/apply
  → 校验草案未过期、基础计划版本未变化
  → save_plan 写入 programs / program_days / plan_exercises
  → proposal.status = applied
```

## 3. 数据库表

### `agent_runs`

一次 Agent 请求的运行记录。

| 字段 | 说明 |
|---|---|
| `id` | UUID |
| `user_id` | 用户，级联删除 |
| `session_id` | 对话，可空；对话删除时置空 |
| `intent` | `coach_chat` / `plan_change` |
| `status` | `running` / `needs_confirmation` / `completed` / `failed` |
| `model` | 本次使用的模型 |
| `input_text` / `output_text` | 输入与最终回复 |
| `step_count` | 已执行步骤数 |
| `error` | 失败原因 |
| `created_at` / `completed_at` | 时间 |

索引：`(user_id, created_at)`、`(status, created_at)`。

### `agent_steps`

Agent 的每一步，用于审计和回放。

| 字段 | 说明 |
|---|---|
| `run_id` | 所属运行 |
| `step_index` | 从 1 开始，`(run_id, step_index)` 唯一 |
| `step_type` | `decision` / `tool` |
| `tool_name` | 例如 `get_context`、`propose_plan` |
| `input_json` / `output_json` | 工具参数与结果 |
| `status` / `error` | 成功或失败 |
| `latency_ms` | 步骤耗时 |

### `agent_plan_proposals`

待确认计划草案。正式计划仍然在原有 `programs` 表中，不另建一套计划表。

| 字段 | 说明 |
|---|---|
| `run_id` | 产生草案的 Agent 运行 |
| `base_program_id` / `base_version` | 草案基于哪一版正式计划；应用时做乐观锁 |
| `status` | `draft` / `applied` / `superseded` / `expired` / `rejected` |
| `plan_data` | 已验证的完整计划 JSON |
| `diff_data` | 面向用户的变更摘要和前后对比 |
| `validation_data` | 校验警告 |
| `expires_at` | 默认 30 分钟过期 |
| `applied_at` | 正式写入时间 |

### `ai_memories`

长期记忆表，新增字段：

| 字段 | 说明 |
|---|---|
| `kind` | `preference` / `constraint` / `schedule` / `equipment` / `injury` / `goal` / `behavior` |
| `memory_key` | 稳定键，例如 `weekly_schedule`、`travel_equipment` |
| `content` | 一句精简事实 |
| `source` | `agent` / `coach` / `manual` |
| `confidence` | 提炼置信度 |
| `active` | 软删除标记 |
| `updated_at` / `last_used_at` | 更新和最近使用时间 |

Agent 每次对话后自动提炼最多 3 条稳定事实；同一 `memory_key` 的日程/器械/伤病/目标会更新而不是无限追加。默认保留最近 80 条活跃记忆，上下文读取最近 20 条。记忆提炼在用户回复完成后以后台任务执行，使用独立数据库 session，不把第二次 LLM 延迟算进聊天响应；失败只记日志，不影响主回复。

原始对话仍保存在 `chat_messages`，不会丢；但每次提示只带最近 10 条消息和记忆摘要，避免把完整历史塞进上下文。

Agent 循环在每次等待模型前提交并释放数据库连接；模型调用受 `LLM_MAX_CONCURRENCY` 信号量限制，避免长时间等待占满连接池或触发上游限流。


## 4. 工具

| 工具 | 作用 | 是否写库 |
|---|---|---|
| `get_context` | 档案、目标、当前计划、记忆 | 否 |
| `get_recent_training` | 最近训练、容量、RPE | 否 |
| `propose_plan` | 用规则模板构建并校验计划草案 | 写入 `agent_plan_proposals` |
| `remember` | 保存长期偏好/约束 | 写入 `ai_memories` |

`apply_plan` 不是模型可调用工具，只能由客户端用户确认后调用。

## 5. 安全约束

- 现有 `detect_safety` 在 Agent 入口优先执行，红旗症状直接返回就医提示。
- 计划草案只能使用动作库中的动作，并经过器械/伤病/频率校验。
- 应用前检查 `base_program_id/base_version`，防止覆盖用户刚刚手动改过的计划。
- 草案 30 分钟过期。
- 所有运行和工具步骤落库，便于后台审计和排查。
- 不把 API Key、完整 prompt、敏感原始图片写入 `agent_steps`。

## 6. API

```text
POST /api/v1/agent/chat
{
  "session_id": "可选",
  "message": "我每周二四六练，每次 30 分钟，帮我改计划"
}

POST /api/v1/agent/proposals/{proposal_id}/apply
GET  /api/v1/agent/proposals/{proposal_id}
POST /api/v1/agent/reviews/weekly
GET  /api/v1/agent/memories
DELETE /api/v1/agent/memories/{memory_id}
```

Agent 回复中的 `proposal` 只包含变更摘要和验证结果；应用接口返回正式计划。

记忆接口只返回当前账号的 `active` 记忆，删除是软删除，账号注销时随用户数据一起清理。

## 7. 后台可观测性

管理后台新增只读「Agent 运行」页，使用企业管理员的 `ai:read` 权限：

```text
GET /api/admin/v1/agent/runs?status=&intent=&q=&page=&size=
GET /api/admin/v1/agent/runs/{run_id}
```

列表展示用户、意图、运行状态、模型、步骤数、最近草案状态和时间；详情展示输入/最终回复、每一步工具参数与结果、错误、延迟，以及关联的计划草案和校验结果。后台不能直接应用草案，用户仍需在 iOS 端确认。

## 8. 主动周复盘

`POST /api/v1/agent/reviews/weekly` 会读取本周（周一至周日）和上周的训练、训练容量、RPE、饮食记录、当前计划与长期记忆，生成：

- 本周完成次数 / 计划次数、完成率
- 训练容量与平均 RPE 的风险提示
- 1–3 条做得好的地方、需要关注的地方和下周行动建议

复盘由确定性的 `weekly_review_rules_v1` 生成，不依赖模型 Key，因此训练完成后可以低成本自动刷新；每次复盘仍会落一条 `agent_runs`（`intent=review_week`、`model=review-rules-v1`）和工具步骤，后台可审计。iOS 会在训练创建/编辑/删除成功后强制刷新，并在同一周内缓存；训练上传成功且通知已开启时，会用本地通知提醒“AI 复盘已更新”。

**边界：** 目前是客户端前台触发的主动复盘，本地通知不需要 APNs；真正的服务端定时任务 + APNs 远程推送仍需 Apple 推送证书、设备 token 注册和定时调度，属于 Mac/Apple 外部配置。

记忆上下文被读取时同步更新 `last_used_at`；历史重复的 generic `preference` 可用 `backend/scripts/dedupe_memories.py --dry-run` 检查，再去掉 `--dry-run` 清理。

## 9. 后续演进

1. 服务端定时任务 + APNs 主动复盘
2. 训练中动态调整（根据 RPE 和剩余时间）
3. 饮食/身体数据全量同步后接入营养 Agent
4. 真实视觉模型接入器械和体型识别
5. Agent 评测集：工具选择正确率、计划合法率、安全兜底率、用户采纳率
