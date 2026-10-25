# 02 · 技术架构

## 1. 总览

```
┌──────────────────────────── iOS App（SwiftUI） ────────────────────────────┐
│  Features: Onboarding / Home / Plan / Workout / Coach / Equipment / Profile │
│  Core: AppStore(@Observable) · APIClient · NotificationScheduler · Theme     │
│  本地持久化：JSON（当前）→ SwiftData（后续）                                  │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │ HTTPS / JSON / SSE
┌───────────────────────────────────▼─────────────────────────────────────────┐
│                         API Gateway / FastAPI                                │
│  auth · profile · plans · workouts · coach · equipment · diet                │
├──────────────────────────────────────────────────────────────────────────────┤
│  AI Orchestrator                                                             │
│  ├─ 模型网关（DeepSeek / 通义 / 豆包，OpenAI 兼容协议）                       │
│  ├─ Prompt 版本管理 + JSON Schema 结构化输出                                  │
│  ├─ 计划校验器（动作库 / 器械 / 伤病 / 负荷）                                 │
│  ├─ RAG（动作库 + 运动解剖 + FAQ，pgvector）                                  │
│  ├─ 内容安全（输入 + 输出双向）                                               │
│  └─ 缓存 / 限流 / 成本统计                                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│  PostgreSQL（业务 + pgvector） · Redis（缓存/队列） · OSS（图片/视频）        │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │
                         APNs（提醒） · 短信/邮件（可选）
```

## 2. 客户端分层

| 层 | 职责 | 当前实现 |
|---|---|---|
| App | 入口、环境注入、Tab 结构 | `FitAIApp` / `RootView` / `MainTabView` |
| Features | 页面与交互 | 7 个 Feature 目录 |
| Core/Models | 领域模型（Codable） | `Models.swift` |
| Core/Data | 动作库静态数据 | `ExerciseLibrary.swift` |
| Core/Services | 计划生成、通知、API、配置 | 本地规则引擎 + Mock |
| Core/Design | 颜色、卡片、按钮样式 | `Theme.swift` |

**状态管理**：`@Observable AppStore` 作为单一状态源，通过 `.environment()` 注入。所有写操作后调用 `persist()`，状态编码为 JSON 写入 Documents。

> 为什么不用 SwiftData：P0 阶段模型变化频繁，JSON 更容易迭代。等模型稳定、需要复杂查询时再迁移，迁移成本可控。

## 3. 后端模块

| 模块 | 职责 |
|---|---|
| `routers/auth.py` | 开发期登录；后续替换为 Sign in with Apple + JWT |
| `routers/profile.py` | 档案与目标读写 |
| `routers/plans.py` | 生成计划、获取当前计划、保存编辑 |
| `routers/workouts.py` | 训练记录上报与查询 |
| `routers/coach.py` | 问答（普通 + SSE 流式） |
| `routers/equipment.py` | 图片上传与器械识别 |
| `routers/diet.py` | 热量计算、饮食计划占位、外卖链接占位 |
| `services/llm.py` | 模型网关，OpenAI 兼容协议，Mock 兜底 |
| `services/plan_generator.py` | Prompt 组装 → LLM → 解析 → 校验 → 降级 |
| `services/plan_validator.py` | 动作、器械、伤病、负荷、结构校验 |
| `services/coach.py` | 上下文组装、安全拦截、Mock 回复 |
| `services/equipment.py` | 视觉识别占位，返回候选与置信度 |

## 4. AI 编排原则

1. **模型只做编排，规则负责安全。** 动作合法性、器械匹配、伤病禁忌、负荷上限全部由后端校验，不信任模型输出。
2. **结构化输出。** 计划用 JSON Schema 约束；解析失败自动重试 1 次，再失败降级到模板。
3. **可追溯。** 每次 AI 调用写 `ai_jobs`（模型、prompt 版本、耗时、token、状态），每次计划版本记录 `generated_by`。
4. **成本分级。**
   - 意图分类 / 标签：小模型或端上模型
   - 计划生成：中档模型 + 严格 schema
   - 器械识别：视觉模型 + 自建分类器兜底
   - 闲聊：小模型
5. **降级不报错。** 用户永远能拿到一份可执行的计划，哪怕来自规则模板。

## 5. 通知架构

| 系统 | 方案 |
|---|---|
| iOS 17–25 | `UNUserNotificationCenter`，每个训练日一条每周重复通知，最多 7 条 |
| iOS 26+ | `AlarmKit` 系统级闹钟（需用户授权），失败回退本地通知 |
| 服务端 | APNs 推送用于计划调整、周报、召回；不作为训练提醒的主通道 |
| 时区 | 客户端计算本地时间；`NotificationSchedule.timezone` 仅用于服务端统计 |

**已知限制：**

- 本地通知在静音/专注模式下可能不响，不能承诺“系统闹钟级”。
- Critical Alerts 需要 Apple 特批，健身类基本拿不到。
- 若改为一次性通知，iOS 单 App 最多保留 64 条，必须滚动续排。当前采用每周重复，不触发该限制。
- 用户修改训练日后，必须调用 `reschedule` 清除旧通知，否则会重复提醒。

## 6. 部署（中国大陆）

```
用户 → 阿里云/腾讯云 SLB → FastAPI（2 实例）→ RDS PostgreSQL / Redis
                                   ├─ OSS + CDN（图片、视频，防盗链）
                                   └─ 百炼/火山/DeepSeek API（境内）
```

- 域名需 ICP 备案；App 需工信部 App 备案。
- 生产数据库开启自动备份与 PITR。
- 图片上传走服务端签名直传 OSS，不经过应用服务器。
- 视频用 HLS + 签名 URL + Referer 防盗链。

## 7. 安全与隐私

| 风险 | 措施 |
|---|---|
| API Key 泄露 | 只放后端环境变量，客户端永不持有 |
| 越权 | JWT + 资源归属校验（所有查询带 user_id） |
| 健康数据泄露 | 传输 TLS 1.2+；数据库字段级加密；日志脱敏 |
| 图片滥用 | 上传大小/格式限制、病毒扫描、EXIF 清除 |
| Prompt 注入 | 系统提示词隔离、输入长度限制、输出审核 |
| 刷接口 | 按用户 + IP 限流；AI 接口单独配额 |
| 内容违规 | 输入输出双向审核，保留审计日志 6 个月 |

## 8. 关键失败模式

| 失败 | 表现 | 处理 |
|---|---|---|
| LLM 超时 | 计划生成 >8s | 15s 超时 → 模板降级 |
| JSON 不合法 | 解析失败 | 重试 1 次 → 模板降级 |
| 模型编造动作 | 动作不在库 | 校验器剔除，不足则补位 |
| 识别置信度低 | 结果不可靠 | 不自动选定，转手动搜索 |
| 通知权限被拒 | 提醒不触发 | 站内红点 + 引导去设置 |
| 离线 | 无法同步 | 本地队列，联网后重放 |
