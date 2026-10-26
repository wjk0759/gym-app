# 17 · 全局自适应与布局规范

这版把「响应式」从页面补丁升级为全局约束。页面骨架、间距和字号使用流体值；
固定尺寸只允许出现在图标、触控控件和媒体比例这类有语义的局部组件里。

## 原则

1. 页面不写固定宽度。内容宽度由父容器、`max-width` 和安全区共同决定。
2. 所有可滚动页面必须有 `min-width: 0`，避免 flex / grid 子项把页面撑宽。
3. 头部和底部操作条独立于滚动内容；短屏、横屏和键盘弹出时，主操作不能滑出屏幕。
4. 横向留白使用统一 gutter；底部留白叠加 `safe-area-inset-bottom`。
5. 大屏内容限制在可读宽度内，不把手机布局无限拉伸。
6. 触控目标至少 44pt；视觉图标可以更小，但点击区域不能缩小。
7. 原生字体优先使用语义字号，容器使用自适应布局修饰器，不靠屏幕宽度猜像素。

## Web 设计令牌

定义在 `preview/styles.css` 的 `:root`：

- `--app-gutter`：`clamp(16px, 5.1vw, 22px)`
- `--app-top`：状态栏 48px + 流体间距
- `--space-1...4`：连续间距阶梯
- `--radius-sm/md/lg`：流体圆角
- `--type-h1/h2/h3`：流体字号
- `--safe-top` / `--safe-bottom`：安全区
- `--tap-min`：44px 触控底线

应用骨架：

- `.app` 使用流体 gutter 和底部安全区
- `.page-header`、`.equipment-sticky-tools` 的负边距跟随 gutter
- `.card` 使用流体 padding 和圆角
- 大屏下 `.app > .stack` 限制为 760px 并居中
- 动作选择气泡使用 `min(330px, 100vw - gutter * 2)`，不再固定 330px

## 训练中页面

训练页使用独立应用壳：

```text
workout-screen
├── workout-topbar（固定）
├── workout-progress-strip（固定）
├── workout-scroll（唯一滚动区域）
│   └── workout-content
└── workout-action-bar（固定，含底部安全区）
```

- 主操作条不再依赖 `position: sticky`，因此不会被滚动内容顶出屏幕。
- 横屏低高度时操作条改为左右两栏，减少纵向占用。
- 训练数据异常时回退到“当前动作 + 暂时无法加载”的安全文案，不出现空白页。
- 内容区显式设置 `min-height: 0`，短屏可滚动。

## 原生

新增 `Core/Design/AppLayout.swift`：

- `readableMaxWidth = 720`
- compact / regular 两档页面 gutter
- `appPagePadding()`：随 horizontal size class 调整
- `appReadableContent()`：限制内容宽度并居中

已应用到：

- `WorkoutSessionView`：固定进度头和底部操作条，中间内容独立滚动
- `EquipmentSelectionPanelView`：移除固定 330pt 宽度，改用 260–380pt 自适应范围；
  横屏时缩短列表最大高度

## 验收矩阵

| 宽度 | 场景 |
| --- | --- |
| 280 | 极窄兜底 |
| 320 | iPhone SE / 小屏 |
| 375 | iPhone 标准 |
| 390 / 430 | 新款大屏 |
| 844 × 390 | 手机横屏 |

每个尺寸检查：

- `document scrollWidth <= viewport width`
- 训练页主按钮底部不超过视口
- 训练页内容可以滚动，且头部 / 进度 / 操作条始终可见
- 器械已选气泡不超出左右 gutter，也不压到状态栏
- 页面切换后没有横向位移或空白主内容
