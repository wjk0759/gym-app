# FitAI Web 预览

这是 FitAI 的界面与流程预览，用浏览器打开即可，不需要 iOS 模拟器。

> 它不是真正的 iOS App。真实 App 需要 macOS + Xcode 编译；Windows 无法运行 iOS Simulator。

## 启动

双击 `启动预览.cmd`，或者：

```powershell
cd E:\Projects\FitAI\preview
powershell -ExecutionPolicy Bypass -File .\serve.ps1
```

然后打开 <http://127.0.0.1:5173/>。

## 当前页面

- 登录：未勾选协议时弹确认框；确认后自动同意并继续手机号 / 微信 / QQ 登录
- 建档：身高、体重、体脂、围度（含臂围 / 大腿围）、器械、目标、每周 1–7 练、1/3/5 分化与单次 30–120 分钟
- 资料编辑：保存固定在吸顶页头右上角，长表单无需滚到底
- 身体打卡：体重、体脂、腰围；臂围 / 大腿围在资料编辑中维护；隐藏 / 关闭提醒使用独立操作按钮
- 首页：目标进度与目标日期、今日训练与饮食计划双主卡、本周完成、AI 复盘；休息日饮食计划优先
- 计划：月历、选中日期训练/饮食、独立周/月/年数据复盘报告（训练 + 饮食营养 + 体重/体脂）、训练日编辑、未来 4 周训练日期选择、女性经期区间与轻量/休息模式、补录训练
- 教练：对话、拍照问教练、快捷问题、疼痛 / 孕期安全兜底、教练主导的计划调整
- 资料编辑：保存后按新的目标 / 分化 / 频率 / 时长 / 经验 / 器械自动重排计划，训练日期页同步刷新
- 器械：动作库、拍照识别、动作详情、器械库、教学视频入口
- 我的：Pro 订阅页、Apple 健康、体型照片分析、器械库、提醒、训练偏好、数据导出、注销
- 饮食：按日期查看和记录、热量目标、食物库、拍照识别
- 训练：训练前编排、训练中调整、完成组、休息计时、训练记录编辑

## 直接打开某个页面

```text
http://127.0.0.1:5173/?tab=home
http://127.0.0.1:5173/?tab=plan
http://127.0.0.1:5173/?tab=coach
http://127.0.0.1:5173/?tab=equipment
http://127.0.0.1:5173/?tab=profile
http://127.0.0.1:5173/?screen=nutrition
http://127.0.0.1:5173/?screen=paywall
http://127.0.0.1:5173/?screen=bodyAnalysis
http://127.0.0.1:5173/?screen=equipmentLibrary
```

## 前端模块结构

预览没有构建步骤，`index.html` 按依赖顺序加载模块。**不要把页面逻辑重新写回入口文件。**

```text
preview/
├── index.html                 # 只负责加载顺序和缓存版本
├── css/
│   ├── base.css               # 令牌、外壳、通用组件、页面基础样式
│   ├── coach.css              # AI 教练对话与计划调整
│   ├── body-checkin.css       # 身体数据提醒 / 弹层
│   ├── equipment.css          # 器械详情 / 相机 / 选择器
│   ├── adaptive.css           # 全局自适应基础
│   ├── workout.css            # 训练编排、训练中调整
│   └── plan.css               # 计划日历
└── js/
    ├── app.js                 # 仅创建 window.app 动作命名空间
    ├── data.js                # 动作/食物数据、演示数据、计划生成
    ├── demo-food-history.js   # 演示饮食历史（周/月/年复盘）
    ├── period.js              # 女性经期区间与训练模式
    ├── state.js               # 状态结构、持久化、派生数据
    ├── router.js              # 路由栈、上一级返回、深链接 fallback
    ├── ui.js                  # tabbar、返回头等通用 UI
    ├── components/
    │   ├── camera.js          # 饮食 / 器械共用相机拍摄页
    │   ├── exercise-analytics.js # 动作容量 / 重量 / 1RM 趋势
    │   ├── number-picker.js   # 滚轮数字选择器与字段按钮
    │   └── drag-scroll.js     # 桌面预览拖拽滚动
    ├── onboarding.js
    ├── auth.js
    ├── home.js
    ├── plan.js
    ├── plan-review.js
    ├── plan-schedule.js
    ├── body-checkin.js
    ├── training-data.js
    ├── coach-adjustment.js
    ├── coach.js
    ├── equipment-picker.js
    ├── equipment-recognition.js
    ├── equipment-library.js
    ├── equipment-detail.js
    ├── body-analysis.js
    ├── equipment-interactions.js
    ├── profile.js
    ├── profile-edit.js
    ├── settings.js
    ├── nutrition.js
    ├── food-photo.js
    ├── food-log.js
    ├── paywall.js
    ├── workout-compose.js
    ├── workout-live.js
    ├── session-detail.js
    ├── history.js
    ├── runtime.js             # 路由 render、演示教练回复
    ├── timer.js
    ├── boot.js
    └── actions/               # 只做动作注册，按功能拆分
        ├── profile-auth.js
        ├── body-checkin.js
        ├── plan.js
        ├── plan-schedule.js
        ├── training-data.js
        ├── plan-adjustment.js
        ├── workout-live.js
        ├── session.js
        ├── workout-compose.js
        ├── coach-paywall.js
        ├── nutrition.js
        ├── equipment-picker.js
        ├── equipment.js
        └── general.js
```

### 新增页面 / 模块的规则

1. 页面渲染放 `js/<feature>.js`，动作放 `js/actions/<feature>.js`。
2. 共用交互放 `js/components/`，共用状态/派生数据放 `js/state.js` 或 `js/data.js`。
3. 新文件必须在 `index.html` 按依赖顺序加载；动作文件只通过
   `Object.assign(window.app, { ... })` 注册方法。
4. 每个文件保持单一职责；超过约 500 行优先继续拆分，而不是继续堆。
5. 共用卡片、相机、数字选择器、日期工具要先找现有组件，不复制一套。
6. 修改 `js/` 或 `css/` 后同步递增 `index.html` 的 `?v=` 缓存版本。

> 当前使用经典脚本加载（无 bundler），模块之间共享全局函数。新增符号名必须全局唯一；
> 如果后续引入打包器，再统一迁移为 ES Module。

每完成一次拆分或改动，运行：

```powershell
node scripts\check-preview.js
```

它会检查语法、`index.html` 引用、重复全局符号，并阻止把 `app.js` / `styles.css` 重新堆成单文件。

## 说明

- 数据保存在浏览器 `localStorage`，侧栏「重置演示数据」可清空。
- 订阅、HealthKit、美团、真实 AI 都是模拟交互，不会真的扣款或联网。
- 计划页的日历、补录训练、训练日编辑和未来 4 周训练日期选择共用模块；周/月/年报告是独立 `planReview` 页面，动作训练数据只从动作详情进入。
- 所有自由文本有长度限制：训练名 40 字、训练心得 300 字、搜索 60 字；长文本展示会截断/折行。
