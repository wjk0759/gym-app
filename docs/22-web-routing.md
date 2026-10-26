# 22 · Web 预览路由与返回栈

> 适用范围：`preview/` Web 预览。iOS 端使用系统 `NavigationStack`，返回由系统导航栈负责；本文件描述 Web 预览的页面路由。

## 1. 原则

1. **Tab 页是第一级路由**
   - `今日 / 计划 / 教练 / 器械 / 我的`
2. **进入子页面时压栈**，不是直接覆盖页面。
3. **所有页面级顶部返回按钮统一调用 `app.back()`**，弹出上一级路由。
   - 例外：训练记录正在编辑时，返回先退出编辑态，不离开当前训练详情；新建训练时则弹出到上一级。这个行为由 `app.sessionCancel()` 内部判断，不写死目标页面。
4. **Tab 切换清空路由栈**，因为 Tab 是新的根。
5. **相机、识别、开始训练等“流程替换”使用 replace，不产生无意义的重复返回页。**
6. **弹层不是路由**：法律条款、动作选择弹层、数字滚轮、训练中调整面板不进入路由栈。
7. 直接打开深链接、刷新页面导致路由栈为空时，按页面所属模块回退到合理的根页面。

## 2. 路由层级

层级不是按页面名固定写死，而是按实际访问路径计算。例如 `trainingData` 只从动作详情进入：

```text
tab/equipment (1)
  → equipmentLibrary (2)
    → equipmentItem (3)
      → trainingData (4)
```

## 3. 一级路由：Tab

| 路由 | 页面 | 入口 | 返回 |
| --- | --- | --- | --- |
| `tabs + tab=home` | 今日 | 底部 Tab / 登录完成 | 无 |
| `tabs + tab=plan` | 计划日历 | 底部 Tab | 无 |
| `tabs + tab=coach` | AI 教练 | 底部 Tab | 无 |
| `tabs + tab=equipment` | 动作库 | 底部 Tab | 无 |
| `tabs + tab=profile` | 我的 | 底部 Tab | 无 |

## 4. 二级及更深路由

| screen | 页面 | 典型父路由 | 返回结果 |
| --- | --- | --- | --- |
| `nutrition` | 饮食记录 | `tabs/home`、`tabs/plan` | 原 Tab |
| `foodAdd` | 记录食物 | `nutrition` | `nutrition` |
| `foodCustom` | 手动添加食物 | `foodAdd` | `foodAdd` |
| `foodPhotoCamera` | 饮食拍照 | `nutrition`、`foodPhoto` | 拍照 / 重拍来源 |
| `foodPhoto` | 识别结果 | 拍照完成后替换 `foodPhotoCamera` | `nutrition` |
| `paywall` | 练途 Pro | `tabs/profile`、`tabs/coach` | 原 Tab |
| `profileEdit` | 编辑资料 | `tabs/profile` | `tabs/profile` |
| `settings` | 设置 | `tabs/profile` | `tabs/profile` |
| `bodyAnalysis` | 体型照片分析 | `tabs/profile` | `tabs/profile` |
| `workoutCompose` | 训练编排 | `tabs/home`、`tabs/plan`、`tabs/equipment` | 原 Tab |
| `workout` | 训练中 | 开始训练时替换 `workoutCompose` | 原 Tab |
| `sessionDetail` | 训练记录详情 / 编辑 / 新建 | `tabs/plan`、`history` | 上一级页面 |
| `sessionExercisePicker` | 训练记录添加动作 | `sessionDetail` | `sessionDetail` |
| `history` | 训练记录列表 | `tabs/plan` | `tabs/plan` |
| `trainingData` | 动作训练数据 | 仅 `equipmentItem` | `equipmentItem` |
| `equipmentLibrary` | 器械库 | `tabs/equipment`、`tabs/profile` | 原 Tab |
| `equipmentItem` | 器械 / 动作详情 | `equipmentLibrary`、`tabs/equipment` | 上一级页面 |
| `equipmentCamera` | 器械拍照 | `tabs/equipment`、`equipmentRecognition` | 拍照来源 |
| `equipmentRecognition` | 器械识别 | 拍照完成后替换 `equipmentCamera` | `tabs/equipment` |
| `planExercisePicker` | 计划训练日添加动作 | `workoutCompose` | `workoutCompose` |
| `planSchedule` | 选择未来 4 周训练日期 | `tabs/plan` | `tabs/plan` |
| `planReview` | 周 / 月 / 年数据复盘报告 | `tabs/plan` | `tabs/plan` |
| `periodSchedule` | 女性经期日期选择 | `tabs/plan` | `tabs/plan` |

## 5. 典型面包屑

### 计划 → 调整训练日期

```text
tab/plan
  → planSchedule
```

### 计划 → 数据复盘报告

```text
tab/plan
  → planReview
```

> 计划页的「查看报告」进入独立 `planReview`；报告支持本周 / 本月 / 今年切换。动作训练数据只从动作详情进入。

### 计划 → 经期安排（女性）

```text
tab/plan
  → periodSchedule
```

### 计划 → 训练记录 → 添加动作

```text
tab/plan
  → sessionDetail
    → sessionExercisePicker
```

### 计划 → 历史 → 训练详情 → 添加动作

```text
tab/plan
  → history
    → sessionDetail
      → sessionExercisePicker
```

### 计划 → 饮食 → 添加食物 → 手动添加

```text
tab/plan
  → nutrition
    → foodAdd
      → foodCustom
```

### 计划 / 首页 → 饮食拍照

```text
tab/plan | tab/home
  → nutrition
    → foodPhotoCamera
      → foodPhoto（拍照后替换相机页）
```

从结果页重拍：

```text
foodPhoto
  → foodPhotoCamera
    → foodPhoto（拍照后回到结果页）
```

### 器械 Tab → 器械库 → 详情 → 动作数据

```text
tab/equipment
  → equipmentLibrary
    → equipmentItem
      → trainingData
```

### 器械 Tab → 动作预览 → 动作数据

```text
tab/equipment
  → equipmentItem
    → trainingData
```

### 器械 Tab → 拍照识别

```text
tab/equipment
  → equipmentCamera
    → equipmentRecognition（拍照后替换相机页）
```

从识别页重新拍照：

```text
equipmentRecognition
  → equipmentCamera
    → equipmentRecognition
```

### 首页 → 训练编排 → 训练中

```text
tab/home
  → workoutCompose
    → workout（开始训练时替换编排页）
```

训练中的 X 返回 `tab/home`，不会回到已经清空草稿的编排页。

### 我的 → 器械库

```text
tab/profile
  → equipmentLibrary
    → equipmentItem
      → trainingData
```

### 教练 / 我的 → 订阅页

```text
tab/coach | tab/profile
  → paywall
```

## 6. 非路由弹层

以下内容只覆盖在当前页面上，不进入路由栈：

- 用户协议 / 隐私政策弹层：`legalDoc`
- 器械库底部的已选动作弹层：`equipSelectionOpen`
- 数字滚轮选择器：`numberPicker`
- 训练中调整动作面板：`workoutAdjustOpen`
- 今日页身体数据提醒：`modal-layer` 内的 `bodyCheckInSheet`，不改变 `screen`

关闭这些弹层应使用各自的关闭 action，不能调用 `app.back()` 改变页面路由。

## 7. 路由栈实现

代码位置：`preview/js/router.js`

- `pushRoute(screen, context)`：记录当前路由快照，再进入下一级。
- `replaceRoute(screen, context)`：替换当前路由，不新增返回层级。
- `popRoute()`：恢复上一级路由快照；为空时走 fallback。
- `resetToTab(tab)`：清空路由栈，回到一级 Tab。
- `settleCameraRoute(target)`：处理相机 → 结果页的替换 / 回退。
- `app.back()`：所有 Header 返回按钮的统一入口。
- `state.routeStack`：持久化的路由快照栈。

快照会保存对应页面的上下文：

- 日历月份 / 选中日期
- 饮食日期和来源
- 训练记录 id、编辑 / 新建状态
- 器械详情 id / 动作 slug
- 动作数据 slug
- 器械库来源
- 相机来源

## 8. 深链接 fallback

路由栈为空时：

| 当前页 | 回退 |
| --- | --- |
| `foodAdd` / `foodCustom` / `foodPhoto` / `foodPhotoCamera` | `nutrition` |
| `sessionExercisePicker` | `sessionDetail` |
| `planExercisePicker` | `workoutCompose` |
| `trainingData` | 有器械上下文 → `equipmentItem`；否则 `tab/equipment` |
| `history` | `tab/plan` |
| `equipmentLibrary` | 来源为我的 → `tab/profile`；否则 `tab/equipment` |
| `equipmentItem` | 有器械 id → `equipmentLibrary`；否则 `tab/equipment` |
| `equipmentCamera` / `equipmentRecognition` | `tab/equipment` |
| `paywall` | `tab/profile` |
| `settings` / `profileEdit` / `bodyAnalysis` | `tab/profile` |
| `nutrition` | 按 `nutritionOrigin` 回今日 / 计划 |
| `sessionDetail` | 按 `sessionOrigin` 回今日 / 计划 |
| `workoutCompose` | 按草稿来源回首页 / 计划 / 器械 |
| `planSchedule` | `tab/plan` |
| `planReview` | `tab/plan` |
| `periodSchedule` | `tab/plan` |
| `workout` | `tab/home` |

## 9. 验收

- 器械 Tab → 器械库 → 详情 → 动作数据，连续返回能回到器械 Tab。
- 我的 → 器械库 → 详情，返回回到我的，而不是器械 Tab。
- 计划页不再出现「动作数据」入口；动作数据从动作详情返回时回到动作详情。
- 计划 → 调整训练日期 → 选择未来 4 周日期并保存，回到计划。
- 计划 → 查看报告 → 切换本周 / 本月 / 今年，返回计划。
- 计划 → 历史 → 训练详情，返回回历史。
- 首页 / 计划进入饮食，返回回原 Tab。
- 饮食 → 添加食物 → 手动添加，返回逐级回饮食。
- 识别结果页返回饮食；重拍后返回仍回饮食。
- 计划 / 首页进入训练编排，返回回原 Tab。
- 开始训练后 X 返回训练来源 Tab。
- 订阅页从教练进入就回教练，从我的进入就回我的。
- 切换 Tab 后路由栈清零。
- 直接打开深链接时，顶部返回按钮也能回到合理根页面。
