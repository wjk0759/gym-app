# FitAI iOS 工程

SwiftUI 原生 App，部署目标 iOS 17.0，使用 XcodeGen 生成工程。

> **Windows 不能编译 iOS。** 需要 macOS 14+ 和 Xcode 16+。Windows 上可以继续改代码和跑后端，但验证必须回到 Mac。

## 生成并运行

```bash
brew install xcodegen
cd ios
xcodegen generate
open FitAI.xcodeproj
```

1. 选择 `FitAI` target → Signing & Capabilities → 选择 Team
2. 选 iPhone 模拟器或真机
3. `Cmd + R`

单元测试：

```bash
xcodebuild test \
  -project FitAI.xcodeproj \
  -scheme FitAI \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

CI 会生成工程并做模拟器编译。单元测试目前建议在 Mac 本地运行：

```bash
xcodebuild test \
  -project FitAI.xcodeproj \
  -scheme FitAI \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

首次运行会进入建档流程。所有数据保存在 App 的 Documents 目录，不需要后端。

## 目录

```
ios/
├── project.yml                     # XcodeGen 配置
├── FitAITests/                     # 计划生成 / 热量计算单测
└── FitAI/
    ├── App/
    │   ├── FitAIApp.swift          # 入口、AppStore 注入
    │   ├── RootView.swift          # 建档 / 主界面切换
    │   └── MainTabView.swift       # 5 个 Tab
    ├── Core/
    │   ├── Design/Theme.swift      # 颜色、卡片、按钮、标签
    │   ├── Models/Models.swift     # 领域模型
    │   ├── Data/ExerciseLibrary.swift  # 27 个动作
    │   └── Services/
    │       ├── AppStore.swift      # 单一状态源 + 本地持久化
    │       ├── PlanGenerator.swift # 规则计划生成 + 调整
    │       ├── NotificationScheduler.swift
    │       ├── CoachService.swift  # 本地教练回复 + 安全拦截
    │       ├── EquipmentService.swift
    │       ├── APIClient.swift     # 预留真实后端
    │       └── AppConfig.swift     # API 地址、开关
    ├── Features/
    │   ├── Onboarding/             # 建档、目标、器械、安全提示
    │   ├── Home/                   # 今日训练、周进度、AI 复盘
    │   ├── Plan/                   # 周视图、计划编辑、换动作
    │   ├── Workout/                # 逐组记录、休息计时、训练总结
    │   ├── Coach/                  # 对话、快捷问题、安全气泡
    │   ├── Equipment/              # 拍照/相册、识别候选、动作详情
    │   └── Profile/                # 档案、提醒、合规、清除数据
    └── Resources/
        ├── Info.plist
        └── Assets.xcassets
```

## 当前是 Mock 的地方

| 模块 | 实现 | 接真实服务 |
|---|---|---|
| 计划生成 | `PlanGenerator` 规则引擎 | 调 `APIClient.generatePlan()` 或后端 |
| 教练回复 | 关键词 + 安全规则 | 调 `APIClient.sendChat()` / SSE |
| 器械识别 | 按图片哈希从动作库取候选 | 上传到 `POST /equipment/scan` |
| 登录 | 固定 demo 用户 | Sign in with Apple + JWT |
| 支付 | 无 | StoreKit 2 |
| 教学视频 | 占位 | 自建/授权 HLS |

## 切换真实后端

1. 启动后端（Windows 上即可）：

```powershell
cd ..\backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

2. App 内打开：**我的 → AI 服务 → 使用远程 AI**，点「测试连接」确认。

3. 真机需要和电脑同一 Wi-Fi；如果 IP 不是本机，修改 `FitAI/Core/Services/AppConfig.swift`：

```swift
static let apiBaseURL = URL(string: "http://192.168.1.20:8000/api/v1")!
```

打开远程模式后：

- 生成计划前会自动同步档案和目标到后端
- 计划、教练对话、器械识别都走真实接口
- 任何请求失败都会回退到本地规则，不会卡住核心流程
- Info.plist 已允许本地 HTTP；上架前必须换成 HTTPS

## 下一步改哪里

- **想改计划逻辑**：`Core/Services/PlanGenerator.swift`（本地兜底）或后端 `app/services/plan_generator.py`
- **想改页面视觉**：`Core/Design/Theme.swift` + 各 Feature
- **想换模型**：改 `backend/.env` 的 `LLM_PROVIDER / LLM_MODEL`；iOS 端不用改
- **远程链路**：`AppStore.generatePlan() / sendChat()` 已接 `APIClient`，失败会回退本地
- **想加通知闹钟样式**：新增 `AlarmKitScheduler.swift`，用 `@available(iOS 26, *)` 包裹，失败回退现有调度器
- **Apple 健康**：`HealthKitService` 已接；需要 Xcode 里开启 HealthKit capability 并做真机授权

## 注意

- 相机在模拟器不可用，会回退到相册。
- 通知在模拟器上的锁屏行为与真机不同。
- 上架前移除 `NSAllowsLocalNetworking`，改用 HTTPS。
