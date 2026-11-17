# Onboarding 可选体型/体脂步骤（恢复 3D 体型插画）

- 日期：2026-11-18
- 提出：macOS
- 执行：Windows
- 背景：`0bc6509` 把 onboarding 从 14 步压到 8 步时，移除了体型、体脂、训练重点、训练地点。体型/体脂后来没有补回入口，导致新用户看不到原来的 3D 体型插画。
- 决策：采用“可选步骤”方案，不恢复 14 步必填，不影响首版计划生成。

## 目标

在 8 个必填步骤之后、起点报告之前，**直接恢复旧的两步**（体型、体脂）作为可跳过步骤：

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

## 交互：直接恢复旧的两步代码

**原则：不要再写新页面、新组件。`0bc6509` 之前的 `bodyTypeStep` / `bodyFatStep` 代码还在 `CoachOnboardingView+BodySteps.swift`，只是没有路由；把这部分恢复成可选步骤，只加“跳过”和步骤判断即可。**

### 步骤顺序

保持必填步骤 1–8 不变，后面接回旧的两步：

1. 称呼
2. 性别
3. 年龄/身高/体重
4. 目标
5. 伤病
6. 器械
7. 经验
8. 每周次数/单次时长
9. **可选 1/2：体型**（直接复用旧 `bodyTypeStep`）
10. **可选 2/2：体脂**（直接复用旧 `bodyFatStep`）
11. 起点报告

### 第 9 步：体型

直接显示旧 `bodyTypeStep`：

- 3D `BodyFigure`
- `BodyTypeThumbnail` 横向选择
- 旧代码的 `onAppear` 推荐体型逻辑保留
- 底部：
  - 次要按钮：“跳过，使用默认参考”
  - 主按钮：“下一步”

行为：

- 点“跳过”：
  - `bodyType = nil`
  - `bodyFatID = nil`
  - 不修改 `draft.bodyFatPCT`
  - 直接跳到报告（第 11 步）
- 点“下一步”：
  - 保留/写入当前 `bodyType`
  - 进入第 10 步体脂
- “上一步”回到第 8 步

### 第 10 步：体脂

直接显示旧 `bodyFatStep`：

- 旧 `BodyFatCard` 2 列网格
- 底部：
  - 次要按钮：“跳过体脂”
  - 主按钮：“下一步”

行为：

- 点“跳过体脂”：
  - `bodyFatID = nil`
  - 不修改 `draft.bodyFatPCT`
  - 进入报告；报告显示体型、体脂为“待选”
- 选择体脂后点“下一步”：
  - 写入 `bodyFatID`，更新 `draft.bodyFatPCT`
  - 进入报告；报告显示 3D 插画和“体型 · 体脂”标签
- “上一步”回到第 9 步

### 进度显示

- 必填阶段仍显示 `x / 8`
- 可选阶段显示 `可选`，不要出现 `9 / 8` 或 `10 / 8`

## 实现落点（最小改动）

- 保留 `inputSteps = 8`。
- `stepContent`：
  - `case 9: bodyTypeStep`（旧代码）
  - `case 10: bodyFatStep`（旧代码）
  - `default: reportStep`
- `advance()`：
  - 第 8 步 → 第 9 步（原来直接进报告）
  - 第 9 步 → 第 10 步
  - 第 10 步 → 报告（第 11 步）
- `bottomBar`：
  - 用明确的 `reportStepIndex = 11` 或 `isReportStep` 判断，不再用 `inputSteps + 1`
  - 第 9/10 步显示“跳过”+“下一步”
  - 报告页仍显示“生成我的计划”
- 跳过按钮只做状态清理 + 跳报告：
  - 第 9 步跳过清 `bodyType/bodyFatID`
  - 第 10 步跳过只清 `bodyFatID`
- 不新增 `optionalBodyStep`、不复制旧页面、不新增素材。
- `save()`、`reportIdentityCard`、`BodyFigure` 逻辑保持原样。

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
- 不要新写 `optionalBodyStep`、复制旧页面或重画素材；直接恢复现有 `bodyTypeStep` / `bodyFatStep`。
- 不要要求体型/体脂必选。
- 不要把体型/体脂重新做成阻塞计划生成的步骤。
- 不要重新加回必填的训练地点/重点部位步骤。
- 不要删除现有 3D 组件或报告里的 `if let bodyType` 分支。
