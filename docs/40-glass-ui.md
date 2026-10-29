# 玻璃质感 UI 与首页信息层级

## 视觉方向

整体走克制的 Apple 风格玻璃质感，但不把每个列表行都做成实时 blur。

- 导航栏、Tab Bar：系统原生 `systemUltraThinMaterial`。
- 教练输入框：真实 `.ultraThinMaterial`，因为页面背景是静态的，blur 成本可控。
- 主训练卡和普通卡片：半透明 tint + 顶部高光 + 细边框，不给每张卡加 shadow，保持玻璃观感但不增加逐卡合成成本。
- 背景只保留静态色场和渐变，给玻璃表面提供可折射的层次。
- 所有玻璃表面保留高对比文字和明确边界，浅色/深色模式都要可读。

实现位置：

- `ios/FitAI/Core/Design/GlassSurface.swift`
- `ios/FitAI/Core/Design/Theme.swift`
- `ios/FitAI/App/FitAIApp.swift`
- `ios/FitAI/Features/Coach/CoachChatView.swift`

## 首页排序

按“今天要做什么”优先，而不是按功能堆叠：

1. 问候 + 天气
2. 天气提醒（有才显示）
3. AI 私人教练主卡
4. 今日训练 / 训练草稿 / 休息 / 生成中
5. 今日饮食
6. 漏练提醒（有才显示）
7. 目标与身体打卡
8. 本周完成
9. AI 复盘

训练和教练入口排在目标和统计之前，减少用户打开 App 后还要往下找今天训练的情况。

## 教练输入框

- 底部悬浮玻璃面板，而不是整条不透明底栏。
- 输入框内部使用半透明内层，不再叠一层 Material。
- 聚焦时只改变边框和阴影，不改变尺寸，避免键盘弹起时布局跳动。
- 发送/停止按钮保持 42pt 触控区，加号入口保持 40×42pt。
- 图片/视频草稿栏只在有附件时出现，并使用轻量玻璃背景。

## 性能底线

- 不为消息气泡、列表行、每个卡片创建独立 blur 或 shadow。
- 不运行逐帧 Canvas/TimelineView 背景；天气只影响静态颜色。
- 输入框使用一个 Material，不嵌套 Material。
- Tab Bar 的模糊只由 `UITabBarAppearance` 负责，不再叠加 SwiftUI Material。
- 页面滚动主要依赖预先合成的半透明表面，避免滚动时反复创建模糊层。
