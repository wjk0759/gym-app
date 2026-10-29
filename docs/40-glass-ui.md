# iOS 26 原生界面规范

## 原则

- 一级栏目使用原生 `TabView` + `tabItem` + SF Symbols。
- 每个 Tab 使用 `NavigationStack`；二级页、详情页、设置页、编辑页使用系统导航栏、系统返回按钮和侧滑返回。
- 顶部操作使用 `ToolbarItem`，不手写假 navigation bar，不隐藏系统返回。
- 弹层优先使用系统 `.sheet` / `.fullScreenCover` / `confirmationDialog` / `alert`；任务型全屏流程才使用 `fullScreenCover`。
- 列表、表单、详情页优先使用系统布局与系统控件，不模拟 Android/Web 风格。
- 视觉层级使用系统 semantic colors、`systemGroupedBackground`、`secondarySystemGroupedBackground`、`regularMaterial` 和系统分隔线。
- 不覆盖 `UINavigationBarAppearance` / `UITabBarAppearance`，让 iOS 26 原生 Liquid Glass 生效。
- 不隐藏系统滚动条，不使用自定义悬浮 Tab Bar、mesh 背景、grain 纹理或逐卡阴影。

## 控件映射

| 场景 | 原生实现 |
|---|---|
| 一级导航 | `TabView` + `Tab` / `.tabItem` |
| 页面导航 | `NavigationStack` + `NavigationLink` / `navigationDestination` |
| 顶部操作 | `.toolbar` + `ToolbarItem` |
| 菜单 | `Menu` |
| 二选一/分段 | `Picker` + `.pickerStyle(.segmented)` |
| 选项列表 | `Picker` + `.pickerStyle(.menu)` |
| 开关 | `Toggle` |
| 数值调整 | `Stepper` / `DatePicker` |
| 空状态 | `ContentUnavailableView` |
| 卡片 | `secondarySystemGroupedBackground` + 16pt continuous corner |
| 悬浮表面 | `.regularMaterial` |
| 主按钮 | system tint fill，语义化 `ButtonRole` |
| 次按钮 | `secondarySystemFill` |
| 销毁操作 | `Button(role: .destructive)` |

## 设计 Token

- `Theme` 直接映射系统语义色：`label`、`secondaryLabel`、`tertiaryLabel`、`separator`、`systemGroupedBackground`、`secondarySystemGroupedBackground`、`secondarySystemFill`、`tertiarySystemFill`、`accentColor`。
- `AppType` 使用 `Font.largeTitle/title/title2/headline/body/callout/caption/caption2`，自动支持 Dynamic Type；不再使用固定字号或全局圆体字。
- `AppLayout` 使用 16pt 页面边距、16pt 卡片圆角、16pt 分区间距、10pt 控件圆角。
- `GlassSurface` 仅作为系统 grouped surface 的轻量封装；`material: true` 才使用 `.regularMaterial`。
- `EmptyStateView` 统一使用 `ContentUnavailableView`。

## 性能底线

- 不运行 `Canvas` / `TimelineView` / 逐帧背景。
- 普通卡片不加 shadow；不创建逐卡 blur。
- 不叠加 SwiftUI Material 与 UIKit blur。
- 系统导航栏、Tab Bar、Sheet 的玻璃材质交给系统管理。
- 转场和弹层不依赖自定义缩放、stagger 或 glow 动画。

## 检查清单

- [ ] 一级 Tab 使用系统 Tab Bar，选中态和图标由系统管理。
- [ ] 所有二级页保留系统返回按钮和侧滑返回。
- [ ] 顶部操作都在 toolbar 中。
- [ ] 分段、开关、步进、日期、菜单使用原生控件。
- [ ] 空状态使用 `ContentUnavailableView`。
- [ ] 浅色/深色模式只使用系统语义色。
- [ ] 没有自定义 navigation bar、悬浮 tab bar、mesh/grain 背景。
- [ ] 没有逐卡 shadow 或逐帧绘制层。
