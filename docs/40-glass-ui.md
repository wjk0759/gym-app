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
- `ios/FitAI/Core/Design/AmbientBackdrop.swift`
- `ios/FitAI/Core/Design/GrainTexture.swift`
- `ios/FitAI/Core/Design/Typography.swift`
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

## 2026-10 视觉系统升级

- **色彩**：深色模式改为冷调深蓝黑底，主色为薄荷绿，青/紫作为环境点缀；浅色模式改为暖纸底 + 实白卡片 + 深色 hairline 边框，避免白卡片在白底上看不到边界。新增 `Theme.accentSecondary`、`Theme.accentTertiary`、`Theme.accentWarm` 和 `Theme.accentGradient` / `Theme.buttonGradient`。
- **背景**：`AmbientBackdrop` 使用静态 mesh 式色场（3 个径向渐变 + 渐变主光 + vignette + grain），不引入 Canvas/TimelineView；浅色模式使用暖金光晕，深色模式才使用紫/青 mesh。
- **玻璃态**：`GlassSurface` 增强顶部高光、底部暗边和半透明 tint；普通卡片不加逐卡 shadow。
- **新拟态**：`SoftSurface` 用双色渐变填充 + 上亮下暗的 hairline 模拟软质控件，用于 Secondary 按钮、Tag、分段选择、加减控件和输入框。
- **排版**：`AppType` 统一 display/title/headline/body/caption/micro/button 字号；RootView 全局 `fontDesign(.rounded)`；section 标题带 accent 短线。
- **间距**：`AppLayout` 统一 card padding 20、section spacing 18、control radius 14，圆形/卡片圆角保持连续圆角。
- **微交互**：主按钮保留轻微缩放和透明度反馈，移除 brightness 和动态阴影；Haptics 复用生成器。
- **氛围**：`GrainTexture` 生成一次 64pt 可平铺噪点纹理；不使用实时 blur 或逐帧噪声。
- **性能约束**：mesh、grain、glass 都是静态合成层；hero/输入框等少量悬浮元素才有独立 shadow。
