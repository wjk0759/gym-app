# 20 · UI 自查、信息架构与前端模块边界

## 这轮自查发现的问题

1. 滚动页面时，内容会从状态栏和吸顶返回头之间露出一条卡片，看起来像顶部多了一块空白模块。
2. 单个训练心得没有上限，一段长文本可以把训练详情撑到几千像素。
3. 首页仍在展示「最近训练」，计划和训练数据页也能看到训练记录，入口和职责重复。
4. 日历选中休息日时只能看，不能补录这天的训练。
5. 饮食拍照和器械拍照各自维护一套相机 UI，交互和失败回退不一致。
6. 首页日期、问候语、周次和累计容量有硬编码，和真实状态不一致。
7. 计划生成的次数还是 `8-10` 区间，与「次数只保留单个数字」的规则冲突。
8. Web 预览所有页面、组件、状态和动作都堆在 `preview/app.js`，难定位、难复用。

## 处理结果

### 顶部与滚动

- `.status-scrim` 覆盖到页面内容起点，使用不透明背景，不再让滚动内容从状态栏下方透出。
- 页面返回头继续吸顶；长列表滚动时头部不跳、不露出后方卡片。
- 相机页单独使用全屏模式，不参与普通页面状态栏遮罩。
- 280 / 320 / 390 / 430 / 844 × 390 均已检查无横向溢出。

### 文本与输入

- 训练名称上限 40 字；训练心得上限 300 字，编辑页显示实时计数。
- 训练详情的心得最多显示 6 行，超出截断；旧数据超长也不会撑爆页面。
- 聊天、资料昵称、伤病描述、食物名称、搜索词、器械名称和备注均设置合理上限。
- 全局正文允许断长单词；聊天气泡和心得预览显式 `overflow-wrap: anywhere`。

### 信息架构

- 首页只保留：今日训练、AI 复盘、本周进度、今日饮食。
- 计划 Tab：训练数据快照 → 月历 → 选中日期 → 训练数据 / 最近训练 → 计划摘要。
- 最近训练从首页迁入计划 Tab 的训练数据卡，点击直接打开训练详情。
- 日历支持今天 / 过去日期补录训练；未来日期只编辑计划。
- 补录训练复用训练详情编辑器和动作库选择器，不新建第二套表单。

### 相机与媒体

- Web：`js/components/camera.js` 统一饮食和器械拍摄页；`js/components/exercise-analytics.js` 统一动作训练数据。
- iOS：`Core/Media/PhotoCaptureView.swift` 统一饮食、器械、体型照片和器械库添加照片。
- 删除旧 `CameraPicker`，只保留一套相机权限、失败回退和相册入口。

### 数据正确性

- 首页日期使用真实日期；问候语按当前时段生成。
- 周次按计划起始周计算；本周完成和本周容量按真实 session 日期计算。
- 累计容量按 sessions 聚合，不再写死 `18,400`。
- 计划次数生成和旧计划读取都规范为单个数字。
- 训练记录补录写入真实 `timestamp`，月历、训练数据、最近训练同步更新。

## Web 代码边界

```text
index.html              加载顺序 / 缓存版本
css/base.css            令牌、外壳、通用组件、页面基础
css/coach.css           AI 教练对话与调整方案
css/equipment.css       器械详情 / 相机 / 选择器
css/adaptive.css        自适应基础
css/workout.css         编排与训练中调整
css/plan.css            计划日历 / 动作训练数据
js/data.js              静态数据、演示数据、计划生成
js/state.js             状态、持久化、派生数据
js/ui.js                通用外壳
js/components/*.js      共用相机、数字选择器、拖拽滚动、动作训练数据
js/coach-adjustment.js  教练主导的计划调整逻辑
js/training-data.js     计划页动作训练数据页
js/<page>.js            页面渲染
js/actions/<feature>.js 页面动作，按功能注册到 window.app
js/runtime.js           路由 render
js/boot.js              启动
scripts/check-preview.js 模块检查
```

规则：

- 页面渲染和动作分离。
- 共用组件先提取到 `components/`，不在页面文件复制第二份。
- 单文件过大优先继续拆，不继续往后追加。
- 新文件必须加入 `index.html` 的明确加载顺序。
- `node scripts/check-preview.js` 阻止重复全局符号和单文件回退。

## iOS 代码边界

- 页面按 Feature 拆分：`Features/Home`、`Plan`、`Workout`、`Equipment`、`Coach`、`Profile`。
- 通用组件：`Core/Design/MetricControls`、`Core/Design/AppLayout`、`Core/Media/PhotoCaptureView`。
- 训练编排：`Features/Workout/CustomWorkoutBuilderView`，今日训练、自选训练、计划训练日共用。
- 训练记录：`WorkoutDetailView` 同时负责查看、编辑和从日历新建；新建通过 `isNew` 参数复用同一套字段和动作库。
- 器械选择：`EquipmentPickerView(onSelect:)` 同时服务训练记录编辑和计划训练日编辑。
- 相机：饮食、器械、体型、器械库添加照片共用 `PhotoCaptureView`，旧的 `CameraPicker` 已删除。
- 计划调整：`PlanAdjustmentCoach` 扩展 + `CoachChatView` 阶段 UI；首页 / 计划页先跳教练，不直接改计划。
- Tab 切换：`MainTabView` 绑定 `AppStore.selectedTab`，调整请求可以从首页 / 计划定向到教练。

## 验收清单

- 训练详情长列表滚动时顶部无空白卡片。
- 训练心得超 300 字被限制；旧超长记录在详情页最多 6 行。
- 首页不再出现「最近训练」卡片。
- 计划 Tab 有训练数据、最近训练和日历补录入口。
- 动作详情不再有 06 训练数据；数据集中到计划页「动作训练数据」。
- 饮食 / 器械 / 体型照片使用同一套拍摄页。
- 调整计划先进入 AI 教练对话，方案确认后才修改计划。
- 计划次数显示单个数字。
- 首页日期、问候、周次、容量随数据变化。
- Web 预览由多个 JS / CSS 模块组成，旧 `app.js` / `styles.css` 单文件已删除。
