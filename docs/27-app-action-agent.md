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

## 6. 当前限制

- action 执行结果目前只回到本地聊天，尚未回写 `agent_runs` 的执行结果表。
- 计划排期仍是 iOS 本地状态，服务端和其他设备还看不到。
- 动作类型是白名单，尚未覆盖饮食记录、体重录入、器械库编辑等全部 App 操作。
- 计划变更仍走 `agent_plan_proposals`，用户确认后应用；这与本地 action 是两套确认链路，后续可统一。

## 7. 后续扩展

1. `log_food` / `log_body_metric`：结构化记录，带用户确认。
2. `open_screen` 深链到训练日期、饮食记录、身体打卡子页面。
3. `update_profile`：器械、伤病、经验、分化。
4. 动作执行结果回传服务端，形成完整审计。
5. 统一 Plan Proposal 和 App Action 为同一个 `AgentProposal` 模型。
6. 端到端评测：意图识别、动作选择、参数正确率、用户执行率、撤销率。
