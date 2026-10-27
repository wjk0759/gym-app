# 27 · App Action Agent

> 2026-10-27 · 让教练 Agent 从“回答问题”升级为“理解需求并准备 App 内操作”。

## 1. 目标

用户用自然语言描述目标，例如：

- “我明天没空，把拉日顺延到最近空档”
- “今天只有 20 分钟，帮我开始今天的训练”
- “打开我的计划”
- “我想减脂，目标 70kg，每周练 4 天”

Agent 需要判断这是**操作**，不是知识问答，并生成结构化动作。iOS 负责展示、确认、执行，执行结果回到聊天。

## 2. 架构

```text
用户文字
  → DeepSeek V4.1 Flash 理解意图
  → propose_app_actions（受控 action schema）
  → iOS AgentActionCard（确认/忽略）
  → iOS 本地执行器（AppStore / HealthStore）
  → 更新 App 状态 + 聊天反馈
```

当前动作不跨 App，不执行付款、账号删除等高风险操作。

## 3. Action 类型

| type | 说明 | 需要确认 |
|---|---|---|
| `reschedule_training` | 把某次训练改到指定日期或最近空档 | 是 |
| `skip_training` | 明确跳过某次训练 | 是 |
| `start_training` | 打开今日/指定训练，开始记录 | 是 |
| `open_screen` | 打开今日、计划、教练、器械、我的或训练日期、饮食、身体打卡、档案、历史、记忆、经期页面 | 是 |
| `update_goal` | 修改目标体重、日期、每周天数、单次时长 | 是 |
| `log_body_metric` | 记录今天体重，可选体脂、腰围 | 是 |

远程模式下，训练、康复、营养三个 Skill 的所有自然语言输入都会先进入同一个 Agent 理解层；本地关键词规则只作为无网络/无 Pro 时的降级路径，不参与远程意图判断。

Action 结构：

```json
{
  "id": "uuid",
  "type": "reschedule_training",
  "title": "把明天的拉日顺延到最近空档",
  "summary": "保留拉日训练内容，仅调整日期",
  "requires_confirmation": true,
  "payload": {
    "day_id": "本地训练日 UUID",
    "target_date": "next_free"
  }
}
```

## 4. App Context

iOS 每次 Agent 请求会携带只读上下文：

```json
{
  "today": "2026-10-27",
  "selected_tab": 2,
  "plan": {
    "id": "uuid",
    "title": "4 周计划",
    "weekly_days": 5,
    "days": [
      {
        "id": "uuid",
        "title": "拉",
        "date": "2026-10-28",
        "week_index": 1,
        "completed": false,
        "skipped": false
      }
    ]
  },
  "today_day": {}
}
```

Agent 只能用 `app_context.plan.days` 中存在的 `day_id`，不能编造日期或训练日。

## 5. 安全边界

- 模型不能直接写 App 状态；只能生成 action。
- 所有 action 一律 `requires_confirmation=true`，包括页面跳转；用户先看到操作卡，点击后 iOS 才执行。
- 训练日、目标、计划变更和页面跳转均有明确预览。
- 当前不支持跨 App、支付、删除账号、修改密码。
- 服务端仍记录 Agent run 和工具步骤，后台可审计。

## 6. 执行结果审计

iOS 执行/取消操作后调用：

```http
POST /api/v1/agent/actions/{action_id}/result
{
  "run_id": "agent run id",
  "action_type": "log_body_metric",
  "status": "executed",   // executed | rejected | failed
  "message": "已记录体重 70.0 kg"
}
```

结果写入 `agent_action_events`（`user_id + action_id` 唯一），并提供 `GET /api/v1/agent/actions` 查询最近记录。这样服务端不只知道模型“建议了什么”，还知道用户最终“执行/取消/失败”了什么。

## 7. 当前限制

- 计划排期、跳过状态仍是 iOS 本地状态，服务端和其他设备还看不到。
- 动作类型是白名单，尚未覆盖饮食记录、器械库编辑等全部 App 操作。
- 计划变更仍走 `agent_plan_proposals`，用户确认后应用；这与本地 action 是两套确认链路，后续可统一。
- 动作撤销（undo）尚未实现；审计事件已具备，可为后续撤销提供依据。

## 8. 失败恢复

- 模型偶尔会在一个响应里输出多个 JSON 对象。后端会解析最后一个完整对象，而不是直接返回 500。
- LLM 网络错误、429/5xx 和 JSON 解析失败会做一次短重试。
- Agent 已生成回复/动作后，后续记忆提炼或审计失败不会覆盖已经生成的回复。
- 客户端收到 `status=failed` 时保留原始输入，显示「重试」卡片；不会只显示“暂时不可用”的死胡同。

## 9. 后续扩展

1. `log_food`：结构化记录饮食，带用户确认。
2. 深链到训练日期、饮食记录、身体打卡子页面。
3. `update_profile`：器械、伤病、经验、分化。
4. 动作撤销和审计历史页面。
5. 统一 Plan Proposal 和 App Action 为同一个 `AgentProposal` 模型。
6. 端到端评测：意图识别、动作选择、参数正确率、用户执行率、撤销率。
