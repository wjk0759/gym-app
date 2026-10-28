# 教练上下文（CoachContext）

## 目标

教练回答事实问题前，不再让模型自己拼档案、计划、训练和饮食数据。服务端先构建一个版本化、JSON-ready 的上下文，Agent 和旧的教练对话共用同一份事实。

实现位置：`backend/app/services/coach_context.py`

## 上下文结构

`CoachContext` 当前版本为 `coach-context-v1`，主要字段：

| 字段 | 内容 |
|---|---|
| `profile` | 昵称、性别、年龄、身高体重、体脂、伤病、器械、训练频率和时长 |
| `goal` | 当前目标和目标日期 |
| `current_plan` | 当前计划、当前周、训练日、动作组数/次数/重量/RPE，以及已改期或跳过的状态 |
| `recent_training` | 最近 N 天训练次数、完成组数、总容量、平均 RPE 和最近训练摘要 |
| `body_metrics` | 最近 5 次体重、体脂、腰围 |
| `nutrition_7d` | 最近 7 天饮食记录天数、热量、蛋白质、碳水、脂肪、纤维 |
| `equipment_library` | 用户个人器械库 |
| `memories` | 长期记忆，读取时更新 `last_used_at` |
| `app_context` | iOS 传来的当前页面、本地计划日期和完成/跳过状态，以及最近一次图片的 `visual_context` |
| `today` | 服务端当前日期和星期 |

没有档案时返回 `needs_profile: true`，只保留记忆和 `app_context`，不伪造身体数据。

## 接入方式

- Agent：每次运行把 `build_coach_context(...)` 放进 `state.coach_context`；`get_context` 工具返回同一份上下文，并带上本轮 `app_context`。
- 旧教练接口：`coach.py` 使用 `context_as_text(...)` 渲染同一份上下文，避免两套口径。
- 提示词：Agent 规则要求优先引用 `state.coach_context`，不要自己重算日期、热量、体重或训练量。
- 后续 iOS 可以在教练页增加“教练看到了什么”折叠卡，直接展示这份上下文的摘要。

## 确定性边界

- 计划周次、训练统计、饮食汇总、器械和记忆都由 Python 计算。
- 模型只负责解释、比较、给建议和选择工具，不负责计算事实数字。
- `CoachContext` 不包含模型生成内容，不保存原始图片。

## Golden tests

```bash
cd backend
.venv/Scripts/python.exe -m pytest -q tests/test_coach_context.py tests/test_coach_golden.py
```

当前共 20 个用例：

- 6 个上下文用例：版本、当前计划、最近训练、饮食/身体、记忆/器械/页面、无档案降级。
- 5 个视觉意图用例：营养、训练、器械、体型、一般问题。
- 5 个安全用例：胸痛、孕期、进食障碍、自伤、普通训练。
- 4 个输入策略用例：过短、无关、药物、情绪。

后续新增教练能力时，先补 golden case，再改提示词或工具。
