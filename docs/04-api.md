# 04 · API 契约

- Base URL：`https://api.example.com/api/v1`（开发：`http://127.0.0.1:8000/api/v1`）
- 编码：JSON，UTF-8
- 鉴权：`Authorization: Bearer <jwt>`；开发期可用 `X-User-Id`
- 时间：ISO 8601（UTC），如 `2026-10-25T09:30:00Z`
- 分页：`?limit=20&cursor=...`，返回 `next_cursor`

## 1. 错误格式

```json
{
  "error": {
    "code": "PLAN_VALIDATION_FAILED",
    "message": "生成的动作不在动作库中",
    "details": {"invalid_slugs": ["cable_crunch_x"]}
  }
}
```

| HTTP | code | 场景 |
|---|---|---|
| 400 | `VALIDATION_ERROR` | 参数不合法 |
| 401 | `UNAUTHORIZED` | token 无效 |
| 403 | `FORBIDDEN` | 越权访问 |
| 404 | `NOT_FOUND` | 资源不存在 |
| 409 | `CONFLICT` | 重复提交 |
| 422 | `PLAN_VALIDATION_FAILED` | 计划校验失败（通常会降级，不直接返回） |
| 429 | `RATE_LIMITED` | 触发限流 |
| 500 | `INTERNAL_ERROR` | 服务异常 |

## 2. 接口清单

### 2.1 认证

认证方式：`Authorization: Bearer <access_token>`。Access Token 默认 30 分钟，Refresh Token 默认 30 天，刷新时轮换。

#### `POST /auth/phone/send-code`

```json
{"phone": "13800138000", "purpose": "login"}
```

`purpose` 支持 `login` / `set_password` / `reset_password`。开发环境 `SMS_PROVIDER=dev` 会返回 `dev_code`；生产配置 webhook 短信网关后不返回验证码。

#### `POST /auth/phone/login`

```json
{"phone": "13800138000", "code": "123456", "device_name": "iPhone", "agreed_terms": true}
```

未注册手机号会自动建号并静默登录。

#### `POST /auth/password/login`

```json
{"account": "13800138000", "password": "Test12345", "agreed_terms": true}
```

账号可以是手机号或用户名。未注册账号会按输入密码自动创建。

#### `POST /auth/password/reset`

```json
{"phone": "13800138000", "code": "123456", "password": "NewPass123"}
```

通过 `reset_password` 验证码重置密码；成功后该用户所有旧会话被撤销，需要重新登录。

#### `POST /auth/password/set`

需要 Bearer token。为当前已登录用户设置或修改登录密码。

#### `GET /auth/me`

返回当前用户、档案、目标、登录方式和是否需要完成建档。

#### `POST /auth/refresh`

```json
{"refresh_token": "..."}
```

成功返回新的 access/refresh token；旧 refresh token 立即失效。

#### `POST /auth/logout`

需要 Bearer Token，撤销当前会话。

#### 微信 / QQ OAuth

- `GET /auth/oauth/{provider}/start`：返回 `authorize_url`、`mode`、`callback_scheme`
- `GET /auth/oauth/{provider}/callback`：服务端换取第三方用户信息，302 到 App 的 `fitai://auth/callback?ticket=...`
- `POST /auth/oauth/exchange`：用一次性 ticket 换取 JWT
- `POST /auth/oauth/{provider}/login`：给原生微信/QQ SDK 直接传 code 的预留接口

未配置 `WECHAT_APP_ID` / `WECHAT_APP_SECRET` 或 QQ 对应密钥时，开发环境提供模拟授权页；生产环境返回未配置，不会伪造真实第三方登录。

#### 安全与审计

- 密码使用 scrypt 加盐哈希
- Refresh Token 只保存 SHA-256 哈希
- 验证码 5 分钟有效、60 秒重发限制、错误 5 次失效
- 登录失败、刷新、退出、设置密码写入 `auth_events`
- 开发环境可使用 `X-User-Id` 兼容旧客户端；生产环境必须使用 Bearer

#### `POST /auth/dev-login`（仅开发）

```json
{"nickname": "小林"}
```

```json
{"user_id": "uuid", "access_token": "dev-token", "expires_in": 86400}
```

> 生产环境还需要补 Sign in with Apple，以满足 App Store 对第三方登录的审核要求。

### 2.2 档案与目标

#### `GET /me`

```json
{
  "user_id": "uuid",
  "profile": {
    "nickname": "小林",
    "sex": "male",
    "birth_date": "1998-03-12",
    "height_cm": 175,
    "weight_kg": 72.5,
    "body_fat_pct": 19.5,
    "chest_cm": 96,
    "waist_cm": 82,
    "arm_cm": 34,
    "thigh_cm": 56,
    "hip_cm": 95,
    "experience": "beginner",
    "injuries": [],
    "equipment": ["bodyweight", "dumbbell"],
    "weekly_days": 3,
    "session_minutes": 45
  },
  "goal": {
    "type": "build_muscle",
    "target_weight_kg": 76,
    "target_waist_cm": 80,
    "target_body_fat_pct": 18,
    "target_date": "2027-02-01",
    "status": "active"
  }
}
```

#### `PUT /me/profile`

请求体同上 `profile`。返回 200 与更新后的档案。

服务端校验：

- `age` 由 `birth_date` 计算，14–70
- BMI < 18.5 且目标为 `lose_fat` → 400 `UNSAFE_GOAL`
- `weekly_days` 1–7；`session_minutes` 最高 120；训练分化为 1 / 3 / 5

#### `PUT /me/goal`

```json
{
  "type": "lose_fat",
  "target_weight_kg": 66,
  "target_body_fat_pct": 18,
  "target_date": "2027-01-01"
}
```

安全规则：减重 ≤0.5kg/周、增重 ≤0.25kg/周，否则返回建议日期：

```json
{
  "error": {
    "code": "UNREALISTIC_GOAL",
    "message": "按每周 0.5kg 计算，最早可达日期为 2027-03-10",
    "details": {"suggested_date": "2027-03-10", "weekly_rate_kg": 0.5}
  }
}
```

#### `GET /me/export`

返回用户全部数据（JSON），用于个人信息导出权。

#### `DELETE /me`

软删除，15 天冷静期。返回 202。

### 2.3 计划

#### `POST /plans/generate`

```json
{
  "force": false,
  "equipment_slugs": ["lat_pulldown", "leg_press"],
  "split": "3分化",
  "focus": ["glutes", "back"]
}
```

- `force=false`：已有 active 计划则直接返回
- `force=true`：归档旧计划，生成新版本
- `preview=true`：新计划先存为 `pending`，客户端预览确认后调用 `POST /plans/{plan_id}/activate` 才生效；旧客户端不传这个字段，保持原来的直接生效行为
- `equipment_slugs`：用户器械库中已录入的动作 slug；后端优先从这些动作 + 徒手动作里编排，数量不足时回退到档案器械类型
- `split`：可选训练分化；决定每天的训练日模板
- `focus`：可选重点部位，取值 `chest/back/legs/glutes/shoulders/arms/core`；最多取前两个，每天优先安排 1–2 个对应动作，但不会破坏 `split` 的骨架

返回 200：

```json
{
  "id": "uuid",
  "title": "4 周增肌计划 · 每周 3 练",
  "version": 2,
  "weeks": 4,
  "generated_by": "ai",
  "created_at": "2026-10-25T09:30:00Z",
  "days": [
    {
      "id": "uuid",
      "week_index": 1,
      "weekday": 1,
      "title": "全身 A",
      "focus": ["chest", "back", "legs"],
      "exercises": [
        {
          "id": "uuid",
          "slug": "goblet_squat",
          "name_zh": "高脚杯深蹲",
          "order_index": 1,
          "sets": 4,
          "reps": "8-10",
          "weight_kg": 12,
          "rest_sec": 90,
          "rpe": 7.5
        }
      ]
    }
  ],
  "warnings": []
}
```

#### `POST /plans/{plan_id}/activate`

把 onboarding 生成的 `pending` 计划设为 active，并归档当前 active 计划。返回完整计划。重复调用是幂等的。

#### `GET /plans/current`

同结构；无计划返回 404 `NO_ACTIVE_PLAN`。

#### `PATCH /plans/{plan_id}/days/{day_id}`

替换某一天的动作列表（全量覆盖，简单可靠）：

```json
{
  "expected_plan_version": 3,
  "exercises": [
    {"slug": "pushup", "sets": 3, "reps": "12-15", "weight_kg": null, "rest_sec": 60, "rpe": 7}
  ]
}
```

服务端重新跑校验器；不合法返回 422。版本不一致返回 409 `PLAN_VERSION_CONFLICT`，成功后计划内容版本 +1。

#### `PUT /plans/{plan_id}`

导入或替换一份完整计划，主要用于本地模板兜底、离线改课和恢复：

```json
{
  "title": "4 周增肌计划",
  "weeks": 4,
  "expected_plan_version": 3,
  "generated_by": "local",
  "days": [
    {
      "id": "uuid",
      "week_index": 1,
      "weekday": 1,
      "title": "全身 A",
      "focus": ["legs"],
      "exercises": [
        {"slug": "pushup", "sets": 3, "reps": "10", "rest_sec": 60}
      ]
    }
  ]
}
```

服务端会校验当前伤病、器械和频率；客户端提供的训练日 ID 会尽量保留，以保证排期状态不丢。

#### `POST /plans/{plan_id}/adjust`

AI 复盘并生成新版本：

```json
{"reason": "weekly_review"}
```

返回新计划 + `changes`：

```json
{
  "program": { "...": "..." },
  "changes": [
    {"type": "reduce_volume", "detail": "上周完成率 55%，本周每个动作减少 1 组"},
    {"type": "keep_load", "detail": "深蹲重量保持不变"}
  ]
}
```

### 2.4 训练记录

#### `POST /workouts`

```json
{
  "client_id": "客户端生成的 UUID，用于重试幂等",
  "program_day_id": "uuid",
  "started_at": "2026-10-25T10:00:00Z",
  "finished_at": "2026-10-25T10:47:00Z",
  "feeling": 4,
  "notes": "状态不错",
  "sets": [
    {"slug": "goblet_squat", "set_index": 1, "weight_kg": 12, "reps": 10, "rpe": 7, "completed": true}
  ]
}
```

返回 201 `{"id": "uuid", "client_id": "...", "duration_min": 47, "duplicate": false}`。
`client_id` 在 `(user_id, client_id)` 上唯一；同一 ID 重放返回原记录并带 `duplicate: true`，不会重复创建。

#### `GET /workouts?from=2026-10-01&to=2026-10-31&limit=20&offset=0`

返回列表（默认不含每组明细，带 `set_count`、`has_more`）。需要每组明细时传 `include_sets=true`。

#### `GET /workouts/{id}`

返回含 `sets` 的详情。

#### `GET /workouts/summary?weeks=4`

```json
{
  "sessions": 9,
  "completion_rate": 0.75,
  "total_volume_kg": 18400,
  "avg_duration_min": 46,
  "by_week": [{"week": "2026-W40", "sessions": 3, "volume_kg": 6200}]
}
```

#### `GET /schedule?plan_id=uuid`

返回该计划的跨设备排期状态：`day_id`、`assigned_date`、`skipped_at`、客户端/服务端更新时间。

#### `PUT /schedule`

```json
{
  "plan_id": "uuid",
  "plan_version": 3,
  "days": [
    {
      "day_id": "uuid",
      "assigned_date": "2026-10-29",
      "skipped_at": null,
      "client_updated_at": "2026-10-27T13:00:00Z"
    }
  ]
}
```

采用最后写入优先；更旧的客户端时间不会覆盖新状态。跳过状态不计入 missed。

### 2.5 AI 教练

#### 教练控制平面（新）

服务端 Session + Capability + Action Ledger 的入口。旧 `/coach/chat`、`/agent/chat` 继续兼容，新客户端优先使用这一组：

```text
GET  /coach/capabilities
POST /coach/turns
GET  /coach/sessions/{session_id}
POST /coach/pending/{pending_id}/confirm
POST /coach/pending/{pending_id}/cancel
POST /coach/actions/{action_id}/undo
GET  /coach/inbox
```

`POST /coach/turns`：

```json
{
  "message": "午餐吃了 100 克鸡胸肉",
  "session_id": "uuid|null",
  "app_context": {
    "plan": {
      "id": "uuid",
      "version": 3,
      "days": [
        {"id": "day-uuid", "date": "2026-11-14", "title": "上肢"}
      ]
    }
  }
}
```

响应：

```json
{
  "session": {
    "id": "uuid",
    "status": "waiting",
    "active_topic": "diet.log_food",
    "pending": {
      "id": "pending-uuid",
      "kind": "card",
      "capability_id": "diet.log_food",
      "payload": {
        "date": "2026-11-14",
        "meal": "lunch",
        "items": []
      },
      "action_id": "action-uuid"
    }
  },
  "turn_id": "uuid",
  "intent": "diet.log_food",
  "status": "completed",
  "reply": "已识别 1 种食物，约 165 kcal。确认后写入。",
  "pending": {}
}
```

确认后返回 `receipt`、`action_id` 和 `deep_link`；撤销走 `/coach/actions/{id}/undo`。卡片和草稿互斥，同一 session 最多一个 `pending`。

#### `POST /coach/chat`

```json
{"session_id": "uuid|null", "message": "深蹲膝盖内扣怎么办？", "skill": "trainer"}
```

`skill` 取值仍兼容 `trainer` / `rehab` / `nutrition`，但后端当前统一按 `trainer`（AI 私人健身教练）处理；新客户端只需传 `trainer` 或省略。

```json
{
  "session_id": "uuid",
  "reply": "先降低重量……如果伴随疼痛，建议停止训练并咨询医生。",
  "safety_flag": null,
  "citations": [
    {
      "type": "exercise",
      "slug": "goblet-squat",
      "name_zh": "高脚杯深蹲",
      "source": "current_plan"
    },
    {
      "type": "exercise",
      "slug": "bench-press",
      "name_zh": "杠铃卧推",
      "source": "hasaneyldrm/exercises-dataset",
      "license": "MIT (data/text); media © Gym visual"
    }
  ]
}
```

`safety_flag` 取值：`crisis` / `medical_referral` / `minor_guard` / `fall_guard` / `condition_guard` / `medication_guard` / `injury_guard` / `ped_guard` / `supplement_guard` / `null`。
只有 Pro 会员的 App 会调用远程 DeepSeek；未开通时客户端使用本地规则回复。

`citations` 由服务端根据回复文本、当前计划和服务端动作库校验后生成，不信任模型自己编造的来源；没有匹配到真实动作时返回空数组。

回复返回前还会执行输出安全护栏：如果模型建议“带伤继续练”、极端断食/催吐、补剂或药物剂量、替代就医或直接下诊断，服务端会替换为确定性的安全回复，并返回对应的 `safety_flag`。

#### `POST /coach/chat/stream`

`text/event-stream`：

```
event: delta
data: {"text": "先降低"}

event: done
data: {"session_id": "uuid", "safety_flag": null, "citations": []}
```

#### `POST /agent/reviews/weekly`

确定性周复盘，不调用大模型。复盘按**实际排期**统计计划日，而不是只看档案里的每周次数：

```json
{
  "period": "week",
  "week_start": "2026-11-09",
  "stats": {
    "sessions": 2,
    "planned": 3,
    "completion_rate": 0.67,
    "planned_days": 3,
    "completed_plan_days": 2,
    "skipped_plan_days": 1,
    "missed_plan_days": 0,
    "adherence_rate": 1.0,
    "volume_kg": 6200,
    "average_rpe": 7.8,
    "average_duration_min": 46,
    "previous_volume_kg": 5800,
    "nutrition_logged_days": 4,
    "diet_planned_meals": 18,
    "diet_logged_plan_meals": 11,
    "diet_adherence_rate": 0.61,
    "diet_planned_kcal": 10800,
    "diet_actual_kcal": 9600,
    "plan_title": "4 周增肌计划"
  },
  "summary": "本周计划 3 次，完成 2 次，计划完成率 100%；跳过 1 次，错过 0 次，总容量 6200 kg。",
  "wins": ["按计划完成了训练", "本周计划全部完成"],
  "watchouts": [],
  "actions": ["下周保持频率，主力动作在动作稳定时加 2.5% 重量或 +1 次"]
}
```

- 计划日以 `assigned_date` 为准；未排期的计划日按计划创建周与 `week_index/weekday` 回退。
- 只有关联训练记录覆盖了计划组数，才算完成该计划日；练了一半仍算错过。
- `skipped_plan_days` 不计入完成率分母。
- 计划未覆盖本期时，`planned` 与 `completion_rate` 回退到档案 `weekly_days`。

#### 多轮草稿 `pending_draft`

当教练需要补充份量时，`/agent/chat` 会返回：

```json
{
  "pending_draft": {
    "id": "uuid",
    "type": "log_food",
    "summary": "正在记录午餐",
    "questions": ["奶茶大概多少量？"],
    "missing_slots": [
      {
        "item_index": 0,
        "field": "grams",
        "question": "奶茶大概多少量？",
        "suggested_grams": 500
      }
    ]
  }
}
```

下一次用户只说“250ml”时，服务端会读取该 session 的草稿并补参数，生成完整的 `log_food` action。草稿 30 分钟过期，只允许同一用户同一 session 读取。

取消草稿：

```text
DELETE /agent/drafts/{draft_id}
```

#### `GET /agent/pending`

返回当前用户最近一张待确认卡和/或活跃草稿，用于换设备或重装后恢复：

```json
{
  "session_id": "uuid",
  "pending_action": {
    "id": "uuid",
    "run_id": "uuid",
    "actions": [{ "id": "action-id", "type": "log_food", "requires_confirmation": true }],
    "expires_at": "2026-11-14T12:30:00+00:00"
  },
  "pending_draft": null,
  "proposal": null
}
```

- 待确认卡 30 分钟过期；新一轮对话没有 actions 时会清掉旧卡。
- 执行或忽略 card 中的某个 action 后，服务端会从卡里移除；全部处理完后卡片变为 consumed。
- `proposal` 返回最近未过期的训练计划草案；新一轮对话没有新草案时旧草案会被 superseded，和其他设备看到的状态一致。
- 用户不说“记错了”但服务端保存了 `log_food` 卡时，`/agent/chat` 也会直接用服务端卡做确认前修正，不依赖客户端回传 `app_context.pending_action`。

#### `PATCH /agent/pending/actions/{action_id}`

客户端在确认前调整份量/日期/餐次后，把新的 payload 同步回服务端卡片：

```json
{
  "summary": "约 537 kcal",
  "payload": {
    "date": "2026-11-14",
    "meal": "lunch",
    "items": [{ "name": "肉肠", "grams": 230, "kcal": 536.7 }]
  }
}
```

只允许修改当前用户活跃卡片中的 action；卡片已执行/过期返回 404。

#### `POST /agent/actions/{action_id}/run`

统一执行教练产出的非训练改课动作。请求：

```json
{
  "type": "log_food",
  "payload": {
    "date": "2026-11-13",
    "meal": "lunch",
    "raw_text": "湿炒螺蛳粉一份，半杯奶茶",
    "items": [
      {
        "name": "湿炒螺蛳粉",
        "portion": "1份",
        "grams": 500,
        "kcal": 600,
        "protein_g": 22,
        "carbs_g": 80,
        "fat_g": 18,
        "confidence": 0.72
      }
    ]
  }
}
```

返回：

```json
{
  "status": "executed",
  "type": "log_food",
  "result": {
    "group_id": "uuid",
    "created_logs": [{"client_id": "uuid", "food_name": "湿炒螺蛳粉", "plan_date": null, "plan_meal": null}],
    "today_nutrition": {"logged": {"kcal": 600}, "remaining": {"kcal": 1600}}
  }
}
```

同一 `action_id` 重放直接返回第一次结果，不重复写入。当前支持：

```text
log_food
log_planned_meal
skip_planned_meal
restore_planned_meal
update_food_log
delete_food_log
log_workout
update_workout_log
delete_workout_log
```

`log_workout` 用于教练补录已完成的训练：

```json
{
  "type": "log_workout",
  "payload": {
    "date": "2026-11-12",
    "title": "跑步",
    "duration_minutes": 30,
    "kind": "cardio"
  }
}
```

力量训练可以带 `sets`，每项包含 `slug`、`weight_kg`、`reps`、`rpe`。不能记录未来日期；同一 action 重放不会创建第二次训练，`undo-run` 会删除该 action 创建的记录。

`update_workout_log` 用 `session_id` 修改日期、时长、备注或整组 sets；`delete_workout_log` 用 `session_id` 删除记录。`session_id` 来自 `recent_training.recent_sessions` 或训练详情。

`log_food` 必须先通过 `resolve_food` 得到结构化 items；`log_planned_meal` 会按当天计划餐复制热量和宏量，并写入 `plan_date` / `plan_meal`。

已确认记录的修正必须带真实 `client_id`：

```json
{
  "type": "update_food_log",
  "payload": {
    "client_id": "来自 today_nutrition.recent_logs 的 client_id",
    "grams": 230
  }
}
```

如果卡片还没确认，不要调用 `update_food_log`；应生成修正后的 `log_food` 卡。

`skip_planned_meal` 把某餐标记为主动跳过，写入计划 JSON 的 `skipped_meals`；跳过不计入饮食复盘缺失和完成率分母。已记录的餐不能跳过。`restore_planned_meal` 撤销跳过。

#### `POST /agent/actions/{action_id}/undo-run`

撤销同一 action 的整组饮食记录。只对 `log_food` / `log_planned_meal` 开放。

#### `resolve_food` Agent 工具

教练收到“吃了/喝了/帮我记一下”时，先调用此工具把自然语言转成结构化食物项：

```json
{"text": "湿炒螺蛳粉一份，半杯奶茶", "meal": "lunch", "date": "2026-11-13"}
```

返回 `items`、`totals`、`questions`、`confidence`。份量不明确时 `questions` 非空，教练必须先追问，不能直接写入。

### 2.6 器械识别

#### `POST /equipment/scan`

`multipart/form-data`，字段 `file`（jpeg/png，≤8MB）。可选请求头
`Idempotency-Key`：同一用户、同一图片的短时重试会返回首次扫描结果，
不会再次调用视觉模型，也不会创建新的 `equipment_scans` 记录。

```json
{
  "scan_id": "uuid",
  "candidates": [
    {"slug": "lat_pulldown", "name_zh": "高位下拉", "confidence": 0.91, "video_url": "https://..."},
    {"slug": "seated_row", "name_zh": "坐姿划船", "confidence": 0.62, "video_url": "https://..."}
  ],
  "needs_confirmation": false
}
```

规则：`confidence < 0.6` 的候选不自动选中；全部低于阈值时 `needs_confirmation=true`，客户端展示手动搜索。

#### `GET /exercises/search?q=下拉&equipment=machine`

返回动作列表，用于手动兜底。

### 2.7 体型照片分析

#### `POST /body/analyze`

`multipart/form-data`，字段 `file`（jpeg/png，≤8MB）。可选请求头
`Idempotency-Key`：5 分钟内同 key 重试返回同一份脱敏文本结果，不重复调用
视觉模型。Pro 校验始终先于缓存回放，免费用户仍返回 403 `PRO_REQUIRED`。

```json
{
  "summary": "整体比例比较均衡，建议把训练重点放在背部与臀部，配合核心稳定。",
  "focus_areas": ["back", "glutes", "core"],
  "recommendations": [
    "每周增加 1 次背部训练，优先高位下拉、坐姿划船",
    "臀部训练加入臀推或臀桥，每周 2 次"
  ],
  "confidence": 0.82,
  "disclaimer": "照片分析仅用于训练重点参考，不构成体脂率、体态诊断或医疗建议。",
  "model": "mock"
}
```

规则：

- 原图不落盘、不入库；只短暂缓存脱敏后的文本结果用于幂等重试
- 不做体脂率、体态诊断或医疗建议
- 客户端必须单独同意后才上传；远程模式需在隐私政策中说明
- 真实视觉模型上线前完成敏感个人信息单独同意与内容安全评估

### 2.8 饮食

#### `POST /diet/analyze`

`multipart/form-data`，字段 `file`（jpeg/png/webp/heic，≤8MB）。可选请求头
`Idempotency-Key`：5 分钟内同 key 重试返回同一份脱敏识别结果，不重复调用
视觉模型。Pro 校验始终先于缓存回放，免费用户仍返回 403 `PRO_REQUIRED`。

```json
{
  "items": [
    {
      "name": "米饭",
      "grams": 150,
      "kcal_per_100g": 116,
      "protein_per_100g": 2.6,
      "carbs_per_100g": 25.9,
      "fat_per_100g": 0.3,
      "kcal": 174,
      "protein_g": 3.9,
      "carbs_g": 38.9,
      "fat_g": 0.5,
      "confidence": 0.91
    }
  ],
  "total_kcal": 425,
  "total_protein_g": 44.4,
  "total_carbs_g": 49.4,
  "total_fat_g": 13.0,
  "confidence": 0.84,
  "disclaimer": "识别结果为估算……",
  "model": "mock"
}
```

规则：

- 原图不落盘、不入库，只返回本次识别结果
- 热量、份量和烹饪油都是估算；客户端允许用户修改克数、勾选实际吃下的食物
- 过敏原、疾病饮食与特殊人群需求必须提示以包装/商家/医生为准
- 视觉默认调用 DeepSeek Flash；模型失败/超时回退规则或 Mock；上线前仍需完成隐私政策、单独同意与内容安全评估

#### `POST /diet/plan`

```json
{"date": "2026-10-25"}
```

返回目标热量、宏量营养素与三餐建议。

#### `GET /diet/plan?date=YYYY-MM-DD`

读取已经保存的当天饮食计划。App 重新打开饮食页时使用这个接口，不再退回通用本地模板；没有保存计划返回 404。

#### `POST /diet/plan/week`

```json
{"week_start": "2026-11-09", "strategy": "mediterranean"}
```

生成并保存 7 天餐单。`strategy` 支持：

```text
balanced / carb_cycle / low_carb / high_protein
mediterranean / vegetarian / time_restricted_16_8
```

`time_restricted_16_8` 只生成午餐、晚餐和加餐，并返回进食窗口提示。每餐除 `kcal` 外还返回 `protein_g / carbs_g / fat_g`，供客户端一键记录整餐。

#### `GET /diet/plan/week?week_start=YYYY-MM-DD`

读取已保存的一周计划；不传日期时返回本周。

#### `POST /diet/plan/{date}/meals/{meal}/swap`

只替换某一餐，不重排整周：

```text
meal: breakfast / lunch / dinner / snack
```

优先使用同周其他日期同名餐次的菜品；没有同周数据时使用规则备选。返回当天完整计划，并保持原餐次的热量和蛋白质/碳水/脂肪不变，只换菜名、食材和做法。

```json
{
  "swapped_meal": {
    "meal": "lunch",
    "from": "周一鸡腿饭",
    "to": "周二牛肉饭"
  }
}
```

教练侧对应 App action：`swap_diet_meal`，payload 为 `{"date":"YYYY-MM-DD","meal":"lunch"}`。

#### `POST /diet/plan/{date}/meals/{meal}/undo-swap`

撤销最近一次该餐次的换餐，恢复换餐前的菜品。没有可撤销备份返回 404。响应包含完整当天计划和 `restored_meal`。

#### `POST /diet/plan/{date}/meals/{meal}/restore`

恢复被主动跳过的计划餐。返回完整当天计划，并在 `restored_meal` 中标出餐次。

#### `GET /diet/review?from=YYYY-MM-DD&to=YYYY-MM-DD`

确定性的饮食计划执行复盘，不调用大模型。只把带 `plan_date` / `plan_meal` 的记录算作“计划餐完成”；手动记录仍计入实际摄入，但不算计划餐完成。

```json
{
  "from": "2026-11-09",
  "to": "2026-11-15",
  "totals": {
    "planned_days": 5,
    "planned_meals": 20,
    "eligible_meals": 18,
    "skipped_meals": 2,
    "logged_plan_meals": 12,
    "adherence_rate": 0.67,
    "planned_kcal": 11000,
    "actual_kcal": 9800,
    "planned_protein_g": 750,
    "actual_protein_g": 620
  },
  "days": [
    {
      "date": "2026-11-09",
      "planned_meals": 4,
      "logged_plan_meals": 3,
      "planned_kcal": 2200,
      "actual_kcal": 2100,
      "planned_protein_g": 150,
      "actual_protein_g": 140,
      "status": "on_track"
    }
  ],
  "missing_meals": [
    {"date": "2026-11-09", "meal": "snack", "name": "加餐", "kcal": 220}
  ],
  "insight": "有 8 餐计划没有记录。先补看最常漏掉的那一餐，是时间不够还是餐单不合适。"
}
```

`status`：`on_track` / `under` / `over` / `no_log` / `no_plan`。默认范围最近 7 天，最长 366 天。

#### `GET /diet/targets?date=YYYY-MM-DD`

每日营养目标。优先返回该日已保存计划的目标（碳循环高/低碳日会不同），否则按档案重算：

```json
{
  "date": "2026-11-12",
  "targets": {
    "bmr_kcal": 1680,
    "tdee_kcal": 2600,
    "target_kcal": 2360,
    "protein_g": 150,
    "carb_g": 280,
    "fat_g": 62
  },
  "strategy": "carb_cycle",
  "source": "saved_day"
}
```

`source` 为 `saved_day` 或 `calculated`。

#### `POST /diet/logs`

```json
{
  "client_id": "uuid",
  "logged_at": "2026-11-12T04:30:00Z",
  "meal": "lunch",
  "food_name": "午餐（计划餐）",
  "grams": 0,
  "kcal": 620,
  "protein": 42,
  "carbs": 68,
  "fat": 18,
  "fiber": 8,
  "plan_date": "2026-11-12",
  "plan_meal": "lunch"
}
```

`plan_date` / `plan_meal` 是可选的软关联：用于一键记录计划餐、在记录里显示“计划餐”标记，不建立外键。计划重新生成后，历史饮食记录仍保留。

`GET /diet/logs` 返回同样字段；`DELETE /diet/logs/{client_id}` 删除记录。

### 2.8 教学视频（只读）

#### `GET /videos/{exercise_slug}`

返回该动作当前已发布的官方教学视频。App 不提供用户上传或编辑视频的入口。

```json
{
  "exercise_slug": "lat_pulldown",
  "exercise_name": "高位下拉",
  "video": {
    "id": "…",
    "title": "高位下拉标准动作示范",
    "description": "先沉肩，再下拉。",
    "video_url": "https://api.example.com/media/videos/….mp4",
    "poster_url": "https://api.example.com/media/posters/….jpg",
    "duration_seconds": 42,
    "source": "叫练动作库",
    "license_note": "叫练自制，已获教练授权",
    "version": 1,
    "updated_at": "2026-10-25T15:20:12+00:00"
  }
}
```

没有已发布视频时返回 `"video": null`，App 展示「教学视频准备中」。

### 2.9 订阅对账（内部）

#### `POST /iap/app-store/reconcile`

请求头：`X-Admin-Token: <APP_STORE_RECONCILE_TOKEN>`。

```json
{"transaction_ids": ["2000000000000001"], "limit": 200}
```

- `transaction_ids` 为空时，按 `user_entitlements` 中已记录的 StoreKit 交易批量对账，最多 `limit` 条。
- 服务端用 App Store Server API 查询订阅状态，并用 `app_store.verify_signed_transaction` 校验 Apple 返回的 JWS。
- 未配置 `APP_STORE_API_KEY_ID / APP_STORE_API_ISSUER_ID / p8` 时返回 503 `APP_STORE_API_NOT_CONFIGURED`。
- 未配置或填错 `APP_STORE_RECONCILE_TOKEN` 时返回 503 / 401。
- 也可运行 `python scripts/reconcile_storekit.py` 作为定时任务。

## 3. 管理后台

FastAPI 已不再提供管理页面或 `/api/v1/admin/*` 接口。唯一后台为：

- 页面：`admin-web/`，本地 <http://127.0.0.1:5173/admin/>
- API：`admin-server/`，前缀 `/api/admin/v1`
- 认证：管理员账号密码登录，短期 JWT + Refresh Cookie；按 RBAC 权限码校验
- 数据库：与 App API 共享 MySQL 8，Schema 由 admin-server Flyway 管理

主要接口：

| 接口 | 说明 |
|---|---|
| `POST /auth/login` | 管理员登录；Access Token 15 分钟 |
| `GET /dashboard/summary` | 用户、训练、计划、对话、AI、内容运营指标 |
| `GET /users` / `GET /users/{id}` | 用户列表、档案、目标、训练、对话、识别、饮食、AI 任务与统计 |
| `GET /users/{id}/export` | 导出该用户服务端数据 JSON |
| `DELETE /users/{id}` | 软删除 |
| `DELETE /users/{id}/purge` | 彻底删除用户及关联数据 |
| `POST /users/{id}/restore` | 恢复软删除用户 |
| `GET /plans` / `GET /plans/{id}` | 计划列表与完整训练日 |
| `POST /plans/{id}/archive` / `activate` | 归档 / 设为当前计划 |
| `GET /schedule` | 跨设备排期状态、跳过记录与最后写入时间 |
| `GET /workouts` / `GET /workouts/{id}` | 训练列表与逐组详情 |
| `GET /chats` / `GET /chats/{id}` | 教练对话列表与消息 |
| `GET /scans` / `GET /scans/{id}` | 器械识别记录 |
| `GET /exercises` / `PATCH /exercises/{slug}` | 动作库搜索与编辑 |
| `GET /videos` / `POST /videos/upload` | 教学视频列表、上传、发布与下架 |
| `GET /ai/overview` / `GET /ai/jobs` | AI 调用量、质量与明细 |
| `GET /agent/runs` / `GET /agent/runs/{id}` | Agent 意图、工具轨迹、计划草案 |
| `GET /agent/actions` | App 动作执行结果、撤销与失败审计 |
| `GET /audit` | 管理员操作审计日志 |

所有写操作都会记录到 `admin_audit_logs`。

## 4. 限流

| 接口 | 限制 |
|---|---|
| `/plans/generate` | 5 次/小时/用户 |
| `/coach/chat` | 60 次/天/用户 |
| `/equipment/scan` | 20 次/天/用户 |
| `/diet/analyze` | 30 次/天/用户 |
| 其他 | 120 次/分钟/IP |

超限返回 429，带 `Retry-After`。
