# 63 · 数据所有权与收敛清单

> 目标：同一份用户数据只有一个主来源；页面只读投影，不再各自维护副本。
>
> 原则：**先区分“业务必须的多形态”与“意外碎片”，不要为了统一而破坏离线/安全/审计需求。**

## 1. 分类

| 类型 | 含义 | 处理 |
|---|---|---|
| A. 单一事实 | 一份数据只能有一个主表和写入口 | 必须收敛 |
| B. 缓存/离线副本 | 服务端是事实，本地是可离线读写的副本 | 保留，但写入口和冲突规则必须明确 |
| C. 业务上不同的概念 | 名字像，但语义不同 | 不合并，只做统一展示快照 |
| D. 仅本地数据 | 目前没有服务端归属 | 先明确产品是否需要跨设备，再决定 |

## 2. 现有数据归属

| 数据 | 当前主来源 | 其他位置 | 类型 | 决定 |
|---|---|---|---|---|
| 体重/体脂/腰围/臂围/大腿围 | `BodyMetric` | `UserProfile` 同名字段、页面 fallback | A/B | `BodyMetric` 唯一事实；Profile 只做启动/离线缓存；所有写走 `appendBodyMetric` |
| 胸围/臀围 | `UserProfile` | 无 BodyMetric 字段 | A/D | 先保留在 Profile；若要做趋势，再加入 BodyMetric |
| 目标 | 服务端 `Goal`（设计） | `UserProfile.goalType/target*` | A | 服务端为权威；本地是缓存；手动编辑立即 push，后续补 pull |
| 营养目标 | 服务端 `/diet/targets` | 本地 `DietPlanner.targets` | A/B | 今日优先服务端缓存；本地只做离线 fallback |
| 训练计划结构 | `Program / ProgramDay / PlanExercise`（服务端） | 本地 `TrainingPlan` | B | 保留离线缓存，`planNeedsServerSync` 负责上传 |
| 训练日程/跳过 | `PlanDayState`（服务端） | 本地 `TrainingPlan.days.date/skippedAt` | B | 保留，按 `clientUpdatedAt` 合并 |
| 训练记录 | `WorkoutSession / SetLog`（服务端） | 本地 `sessions`、outbox | B | 保留缓存和待删队列 |
| 饮食记录 | `FoodLog`（服务端） | 本地 `foodLogs`、outbox | B | 保留缓存和待删/待改队列 |
| 计划餐 | `MealPlan`（服务端） | 本地 `dietWeekPlan`、`FoodLog.planMeal` | B | 保留；实际吃的是 FoodLog，计划餐是计划 |
| 器械类型 | `Profile.equipment` | 本地 `profile.equipment` | B | 保留，服务端为计划生成依据 |
| 自定义器械 | `EquipmentLibraryItem` | 本地 `equipmentLibrary` | B | 保留缓存 |
| 通用器械勾选 | `UserUniversalEquipment` | 本地 `selectedUniversalSlugs` | B | 保留缓存 |
| 提醒 | iOS 本地通知 | 服务端 `NotificationSchedule` 表未使用 | D | 暂定本地唯一来源；服务端表标记为未使用，别误接 |
| 自定义食物/收藏/不喜欢 | iOS 本地 | 无 | D | 产品决定是否跨设备；未决定前不强行上云 |
| 体型分析 | iOS 本地 | 无 | D | 同上 |
| 计划历史 | iOS 本地 | 服务端 Program 历史未拉取 | D/B | 先保留本地，后续补服务端历史 |
| 训练草稿 | iOS 本地 | 无 | D | 保留；跨设备恢复是后续需求 |
| 经期/周期 | `UserProfile` 本地 | 无 | D | 敏感数据，单独决策 |
| 会员 | 服务端 entitlement + StoreKit | 本地 `SubscriptionManager` | C | 不合并：StoreKit 是购买结果，服务端是权益权威 |
| 教练 pending/receipt | 服务端 | 本地 `coachPending/coachReceipt` | B | 本地是缓存；服务端权威 |

## 3. 这次已经收敛的

### P0 云端同步：自定义食物/收藏/不喜欢动作/设置

- 新增 `GET /sync` 和 `POST /sync`：快照式同步，服务端 upsert。
- 新增表：`user_preferences`、`user_custom_foods`、`user_food_favorites`、`user_exercise_dislikes`。
- iOS `FoodItem` 增加稳定 `clientID`，自定义食物跨设备按 `client_id` 合并。
- 收藏食物按 `custom:<client_id>` / `library:<name>` 同步；取消收藏写 tombstone。
- 不喜欢动作同步，并在本地移除时写 tombstone。
- 提醒/身体打卡/器械模式/远程 AI 作为 `user_preferences` 同步。
- iOS 同步入口 `AppStore.syncCloudExtras()`：拉快照 → 合并 → 推本地快照 → 清理 tombstone。
- 计划历史新增 `GET /plans/history`，客户端合并服务端 Program 历史。

> 注意：收藏/不喜欢动作目前是“全量快照 + deleted tombstone”，不是逐条增量 cursor；数据量小，先保证跨设备可用。

### 体重/身体数据读取

新增 `AppStore` 投影：

- `currentWeightKG`
- `currentBodyFatPCT`
- `currentWaistCM`
- `currentArmCM`
- `currentThighCM`
- `currentBMI`
- `currentBMILabel`

规则：

- 有 `latestBodyMetric` 时，所有页面读它
- 没有 BodyMetric 时，Profile 字段只作为 onboarding/老数据 fallback
- `ProfileView`、`BodyCheckInSheet` 已改为读投影
- HealthKit 同步从“只写 `profile.weightKG`”改为“写当天 BodyMetric 并同步”，避免 Progress/教练读不到

### 目标同步

- 手动 `updateProfile` 后立即 push `syncProfile` + `syncGoal`
- `profileSyncPending` 防止未上传的本地编辑被远端 pull 覆盖
- `.profile` 刷新现在会拉 `/me`，合并服务端 profile + 当前 Goal
- 体重/体脂/腰围只在本地还没有 BodyMetric 时才从 `/me` 的 profile 缓存回填

### 今日营养目标

- 新增 `AppStore.currentNutritionTargets`
- 今日优先服务端缓存，离线才回退本地 `DietPlanner`
- 首页、食物库目标卡改为读同一投影
- `PlanReviewView` / `PlanHomeView+SelectedDay` 仍按周期/日期使用本地估算，待日期级接口统一后再切

## 4. 明确不合并的

- 训练计划本地副本：离线训练必须保留。
- 饮食/训练 outbox：离线写入必须保留。
- 器械三种状态：器械类型、自定义器械、通用器械勾选语义不同，不能合成一个字段；后续可做统一只读快照。
- StoreKit 与服务器权益：购买状态和服务端权益职责不同，不能合并。
- 教练 pending 本地缓存：断网/重开需要恢复，但服务端仍是确认权威。

## 5. 后续优先级

1. 今日营养目标全页面统一；非今日日期继续用日期级接口
2. 器械统一只读快照（不合并底层三个状态）
3. 决定本地独有数据是否上云：自定义食物、收藏、体型分析、计划历史
4. 清理未使用的 `NotificationSchedule` 表，或正式接入
5. 让 `.profile` pull 覆盖更多网络恢复场景（登录、回前台、弱网重试）
