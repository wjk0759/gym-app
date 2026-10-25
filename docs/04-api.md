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

#### `POST /auth/dev-login`（仅开发）

```json
{"nickname": "小林"}
```

```json
{"user_id": "uuid", "access_token": "dev-token", "expires_in": 86400}
```

> 生产替换为 `POST /auth/apple`：客户端传 `identity_token`，服务端校验 Apple 公钥后签发 JWT。不存 Apple 密码。

#### `POST /auth/apple`（P1）

```json
{"identity_token": "...", "authorization_code": "...", "nickname": "小林"}
```

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
- `weekly_days` 3–5（P0 只支持 3/4/5）

#### `PUT /me/goal`

```json
{
  "type": "lose_fat",
  "target_weight_kg": 66,
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
  "equipment_slugs": ["lat_pulldown", "leg_press"]
}
```

- `force=false`：已有 active 计划则直接返回
- `force=true`：归档旧计划，生成新版本
- `equipment_slugs`：用户器械库中已录入的动作 slug；后端优先从这些动作 + 徒手动作里编排，数量不足时回退到档案器械类型

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

#### `GET /plans/current`

同结构；无计划返回 404 `NO_ACTIVE_PLAN`。

#### `PATCH /plans/{plan_id}/days/{day_id}`

替换某一天的动作列表（全量覆盖，简单可靠）：

```json
{
  "exercises": [
    {"slug": "pushup", "sets": 3, "reps": "12-15", "weight_kg": null, "rest_sec": 60, "rpe": 7}
  ]
}
```

服务端重新跑校验器；不合法返回 422。

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

返回 201 `{"id": "uuid"}`。客户端离线时先入本地队列，恢复网络后重放；用 `Idempotency-Key` 防重复。

#### `GET /workouts?from=2026-10-01&to=2026-10-31`

返回列表（不含每组明细）。

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

### 2.5 AI 教练

#### `POST /coach/chat`

```json
{"session_id": "uuid|null", "message": "深蹲膝盖内扣怎么办？"}
```

```json
{
  "session_id": "uuid",
  "reply": "先降低重量……如果伴随疼痛，建议停止训练并咨询医生。",
  "safety_flag": null,
  "citations": [
    {"type": "exercise", "slug": "goblet_squat", "name_zh": "高脚杯深蹲"}
  ]
}
```

`safety_flag` 取值：`medical_referral` / `self_harm` / `minor` / `null`。

#### `POST /coach/chat/stream`

`text/event-stream`：

```
event: delta
data: {"text": "先降低"}

event: done
data: {"session_id": "uuid", "safety_flag": null}
```

### 2.6 器械识别

#### `POST /equipment/scan`

`multipart/form-data`，字段 `file`（jpeg/png，≤8MB）。

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

`multipart/form-data`，字段 `file`（jpeg/png，≤8MB）。

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

- 原图不落盘、不入库，只返回本次分析结果
- 不做体脂率、体态诊断或医疗建议
- 客户端必须单独同意后才上传；远程模式需在隐私政策中说明
- 真实视觉模型上线前完成敏感个人信息单独同意与内容安全评估

### 2.8 饮食（P1 占位）

#### `POST /diet/plan`

```json
{"date": "2026-10-25"}
```

返回目标热量、宏量营养素与三餐建议（当前为公式 + 模板，不接 LLM）。

#### `GET /diet/meituan-link?keyword=轻食`

```json
{
  "deeplink": "imeituan://...",
  "h5_url": "https://...",
  "disclaimer": "链接由美团联盟生成，价格与营养信息以美团页面为准"
}
```

> 没有联盟资质时返回 501 `MEITUAN_NOT_CONFIGURED`，客户端隐藏入口。

## 3. 限流

| 接口 | 限制 |
|---|---|
| `/plans/generate` | 5 次/小时/用户 |
| `/coach/chat` | 60 次/天/用户 |
| `/equipment/scan` | 20 次/天/用户 |
| 其他 | 120 次/分钟/IP |

超限返回 429，带 `Retry-After`。
