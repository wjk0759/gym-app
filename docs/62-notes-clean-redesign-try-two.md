# 62 · Notes-like clean redesign · try-two

> 分支：`try-two`，从 `develop` `a9ebaff` 起。
> 这是对 `try` 的修正：`try` 去掉了太多结构，看起来不像 App；`try-two` 保留 develop 的视觉密度，只削减文案和次要标签。
> 未合并、未部署、未修改后端。

## 方向

- 保留 develop 的视觉语言：lime 主色、深色卡片、editorial 卡边、快捷操作卡、饮食环、日历、月印章。
- 砍掉的是：标语、英文眉标、说明性长段落、重复状态、次要小标签。
- 一个页面仍然保留多个功能区块，但每个区块只表达一个意思。
- 所有后端能力、路由、Pro 门禁、教练动作都保留。

## 相对 `try` 的调整

- `AppType`、`editorialCard`、快捷卡片、饮食环、Discover 2×2 网格、Plan 月历/月印章全部保留。
- Try 把首页快捷入口压成 3 个纯图标、删掉目标/周报，导致不像 App；Try-two 保留 4 个快捷卡和「目标、周报和更多」。
- Try 把 Discover/Coach 变成纯列表；Try-two 保留 hero 卡、2×2 入口和教练品牌卡。
- Try 把 Home/Plan 改成系统 inline 标题；Try-two 首页使用自定义「今天」大标题，Plan 保留训练手账大标题和月印章。
- Try 删掉 onboarding 的视觉结构；Try-two 只简化欢迎文案，保留步骤布局。

## 具体变化

### 全局

- 去掉 `TODAY /`、`SESSION /`、`PLAN /`、`COACH /` 等英文眉标。
- `SectionTitle` / `EditorialHeader` 不再渲染副标题，但保留标题层级和装饰。
- 登录/Onboarding 去掉营销句，保留原有表单和步骤结构。

### 今日

- 自定义顶部：`今天` 大标题 + 日期 + 天气 + 教练入口。
- 保留周日期条。
- 训练卡去掉 `TODAY`、周次、状态眉标和说明段，保留标题、重点、指标、动作列表和主按钮。
- 保留 4 个快捷卡、饮食环、目标/周报折叠。
- 删除教练笔记。

### 记录

- 保留训练手账大标题、月印章、快捷操作卡、日历、选中日卡、月封面、训练数据、计划摘要。
- 删除 `TRAINING LOG` 眉标和「翻回去看…」文案。
- 保留日历图例和月历；这些是功能信息，不是标语。

### 教练

- 保留品牌欢迎卡、权益徽标、快速开始、本周状态、inbox。
- 删除「我是你的教练」和长说明/安全提示句。
- 快速开始改为 2×2 卡，避免 4 张大卡竖排。
- 标题改为「教练」，输入占位改为「给教练发消息」。

### 发现

- 保留器械 hero、2×2 入口、工具入口。
- hero 标题改为「我的器械库」，去掉「把器械变成计划」和两个 pill。
- 四个入口去掉副标题，保留图标/颜色/箭头。
- 工具卡去掉副标题。

### 我的

- 使用系统标题「我的」，删除 `PROFILE /` 和「训练、身体和目标…」。
- 保留账号、目标、身体数据、训练重点、体型分析、器械库。
- 删除 Pro 解锁说明、目标免责声明、体型分析说明和累计摘要。

### 饮食

- 保留热量环、模式切换、工具卡、宏量卡、餐卡。
- 去掉模式副标题、工具卡副标题、BMR/维持热量行、长免责声明、空记录提示。

### 登录 / Onboarding

- 登录页去掉「AI 健身教练」「训练 · 饮食 · 复盘」「同步计划…」和未注册提示。
- Onboarding 欢迎页改为 logo + 叫练 + 开始/恢复/退出；step 标题只留问题。

## 删除的死代码

- `HomeV2View+CoachNote.swift`
- `loadingPill`
- `TypewriterText`
- 未使用的 `secondaryText` weather helper
- 其他不再被引用的旧文案 helper

## 验证

- `FitAITests`：140/140
- `FitAIUITests`：7/7（iPhone 17）
- iPhone SE 3：UI 7/7
- clean `xcodegen generate` + `xcodebuild test` 通过
- 浅色/深色模拟器截图人工检查
- try-two Release 已安装并启动 Wu-Tang `com.wjk.fitai`，API 为 `https://hk-api.jiaolianfit.cn/api/v1`

## 未完成

- 根 Tab 仍用 inline title（Plan/Discover/Profile/Coach），首页用自定义大标题；large title 的全局问题未修。
- 设置、训练进行页、器械详情、进展等二级页仅做字重/卡片/英文眉标收敛，未逐页重排。
- 未用真实账号/真机做完整回归。
- 未合并 `develop`，未部署。

## 下一步建议

1. 在 `try-two` 验收首页、记录、教练、发现、我的五个根页面。
2. 确认视觉方向后，再逐页处理设置、训练进行页、器械详情、进展。
3. 最后修 global large title，或统一改成自定义大标题。
