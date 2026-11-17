# Onboarding 可选体型/体脂步骤（恢复 3D 体型插画）

- 日期：2026-11-18
- 提出：macOS
- 执行：Windows
- 背景：`0bc6509` 把 onboarding 从 14 步压到 8 步时，移除了体型、体脂、训练重点、训练地点。体型/体脂后来没有补回入口，导致新用户看不到原来的 3D 体型插画。
- 决策：采用“可选步骤”方案，不恢复 14 步必填，不影响首版计划生成。

## 目标

在 8 个必填步骤之后、起点报告之前，增加 **1 个可跳过的“完善体型参考”步骤**：

- 展示并使用现有 3D 体型插画（`BodyFigure`）
- 可选体型和体脂参考
- 用户点“跳过”时，不写入体型/体脂，直接进入报告
- 用户选择后，报告和后续档案展示所选体型/体脂
- 计划生成、登录、已有账号恢复流程不受影响

## 当前代码状态

- `ios/FitAI/Features/Onboarding/CoachOnboardingView.swift`
  - `inputSteps = 8`
  - `bodyType`、`bodyFatID`、`focusAreas` 状态仍在
  - `save()` 仍会读取 `bodyFatID`、写 `storedBodyType`
- `ios/FitAI/Features/Onboarding/CoachOnboardingView+Layout.swift`
  - `stepContent` 只路由 1–8，`default: reportStep`
  - `bottomBar` 用 `step == inputSteps + 1` 判断报告页
- `ios/FitAI/Features/Onboarding/CoachOnboardingView+BodySteps.swift`
  - `bodyTypeStep`、`bodyFatStep` 仍存在，但已没有入口
- `ios/FitAI/Core/Design/BodySelectionViews.swift`
  - `BodyFigure`、`BodyTypeThumbnail`、`BodyFatCard` 仍完整
- `CoachOnboardingView+Report.swift`
  - `reportIdentityCard` 里有 `if let bodyType { BodyFigure(...) }`
  - 现在 `bodyType` 永远为 nil，所以报告也不显示插画

## 建议交互

### 步骤顺序

保持必填步骤 1–8 不变：

1. 称呼
2. 性别
3. 年龄/身高/体重
4. 目标
5. 伤病
6. 器械
7. 经验
8. 每周次数/单次时长
9. **可选：完善体型参考（新增）**
10. 起点报告

### 可选步骤页面

标题：

```text
可选：完善体型参考
选一个最接近的体型和体脂，教练会更懂你的训练重点。跳过也可以。
```

内容：

- 顶部 3D 体型大图（`BodyFigure`，建议高度 220–300）
- 体型横向缩略图（`BodyTypeThumbnail`）
- 体脂参考 2 列卡片（`BodyFatCard`）
- 底部：
  - 次要按钮：“跳过，使用默认参考”
  - 主按钮：“下一步”

行为：

- 进入页面时可以预览推荐体型，但 **不要在用户未选择时直接写入** `bodyType`
- 用户点“跳过”：
  - `bodyType = nil`
  - `bodyFatID = nil`
  - 不修改 `draft.bodyFatPCT`
  - 直接进入报告；报告不显示 3D 插画
- 用户选择体型/体脂后点“下一步”：
  - 写入 `bodyType` / `bodyFatID`
  - 更新 `draft.bodyFatPCT`（仅当选择了体脂）
  - 进入报告；报告显示 `BodyFigure` 和“体型 · 体脂”标签
- “上一步”返回第 8 步
- 报告页的“生成我的计划”逻辑不变

### 进度显示

- 必填阶段仍显示 `x / 8`
- 可选阶段显示 `可选`，不要出现 `9 / 8`

## 实现落点建议

- 保留 `inputSteps = 8`，新增 `optionalBodyStep` 或复用 `bodyTypeStep` + `bodyFatStep` 组合
- `stepContent` 增加可选步骤路由，`default` 仍为 `reportStep`
- `advance()` 第 8 步进入可选步骤；可选步骤“下一步”进入报告
- `bottomBar` 不要再用固定的 `inputSteps + 1` 判断报告页；用明确的 `reportStepIndex` 或 `isReportStep`
- 跳过按钮只出现在可选步骤
- 复用现有组件，不新增图片资源
- `reportIdentityCard` 继续用 `if let bodyType` 控制，跳过时自然不显示

## 验收

必须在 iPhone 17 与 iPhone SE 3 上验证：

1. 新用户走完 8 步后看到“可选：完善体型参考”，3D 插画可见。
2. 点“跳过” → 报告正常生成，不显示体型插画，计划生成不被阻塞。
3. 选择体型 + 体脂 → 报告显示对应 3D 插画和“体型 · 体脂”标签。
4. 保存后重新进入/查看档案，体型参考不丢失。
5. “上一步”从可选步骤回到第 8 步，无崩溃。
6. 已有账号登录仍直接进主界面，不重新 onboarding。
7. `FitAITests` 全绿，`FitAIUITests` 6/6 不回归。
8. 小屏上可选页面可滚动，底部“跳过/下一步”不被 Tab Bar 或安全区遮挡。

## 不要做

- 不要恢复 14 步必填 onboarding。
- 不要要求体型/体脂必选。
- 不要把体型/体脂重新做成阻塞计划生成的步骤。
- 不要重新加回必填的训练地点/重点部位步骤。
- 不要删除现有 3D 组件或报告里的 `if let bodyType` 分支。
