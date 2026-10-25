# 08 · iOS 上手指南（Mac）

> 你现在用的是 Windows，**无法编译 iOS**。需要一台 Mac（macOS 14+）或云 Mac，安装 Xcode 16 或更高版本。

## 1. 准备

| 项 | 要求 |
|---|---|
| macOS | 14 Sonoma 及以上 |
| Xcode | 16+（App Store 安装） |
| XcodeGen | `brew install xcodegen` |
| 开发者账号 | 免费账号可模拟器/真机调试；上架需 $99/年 |
| iPhone | iOS 17+，用于测试相机与通知 |

首次打开 Xcode 后执行：

```bash
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
```

## 2. 生成工程

```bash
cd /path/to/FitAI/ios
xcodegen generate
open FitAI.xcodeproj
```

`project.yml` 已经配置好：

- 部署目标 iOS 17.0
- Bundle ID `com.fitai.app`（自行修改）
- 源文件目录 `FitAI/`
- Info.plist 与资源

## 3. 签名

1. Xcode 左侧选中 `FitAI` target
2. `Signing & Capabilities` → 勾选 `Automatically manage signing`
3. Team 选择你的账号
4. 如果 Bundle ID 冲突，改成 `com.你的名字.fitai`

## 4. 运行

- 模拟器：选 iPhone 16 / 17，`Cmd + R`
- 真机：数据线连接，Trust 设备，选择设备后运行

**模拟器限制：**

- 没有相机，器械页只能用“相册”
- 本地通知可以触发，但锁屏行为与真机不同
- AlarmKit 需要 iOS 26 真机/模拟器

## 5. 连接本地后端

1. 电脑和 iPhone 在同一 Wi-Fi
2. 后端监听 `0.0.0.0`：

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

3. 查电脑局域网 IP：`ipconfig getifaddr en0`
4. 修改 `ios/FitAI/Core/Services/AppConfig.swift`：

```swift
static let apiBaseURL = URL(string: "http://192.168.1.20:8000/api/v1")!
static let useRemoteAI = true
```

5. Info.plist 已允许本地网络 HTTP（`NSAllowsLocalNetworking`）；上架前必须改成 HTTPS 并移除例外。

## 6. 当前的数据流

```
App 启动
  └─ AppStore.load() 读取 Documents/fitai-state.json
       ├─ 没有档案 → OnboardingView
       └─ 有档案   → MainTabView
            ├─ 首页 → 今日计划
            ├─ 计划 → PlanGenerator（本地规则）
            ├─ 教练 → Mock 回复 + 安全拦截
            ├─ 器械 → PhotosPicker / CameraPicker → Mock 识别
            └─ 我的 → 提醒设置 → UNUserNotificationCenter
```

切换真实后端时，把 `AppStore.generatePlan()` 与 `CoachService.reply()` 里的本地实现替换为 `APIClient` 调用即可，接口已经按 `docs/04-api.md` 写好。

## 7. 通知权限

首次进入“我的 → 提醒设置”时请求权限。如果用户拒绝：

- 设置页显示“去系统设置开启”
- 首页保留站内提醒卡片
- 不要反复弹窗

## 8. AlarmKit（iOS 26+）

当前工程只使用 `UNUserNotificationCenter`，保证 iOS 17 可编译。AlarmKit 需要：

1. Xcode 26 / iOS 26 SDK
2. `import AlarmKit`
3. 用户授权闹钟权限
4. 为闹钟配置 Live Activity（锁屏/灵动岛 UI）

建议做法：新增 `AlarmKitScheduler.swift`，用 `@available(iOS 26, *)` 包裹，失败时回退到现有 `NotificationScheduler`。不要删除回退路径。

参考：<https://developer.apple.com/documentation/alarmkit>

## 9. 常见问题

| 问题 | 解决 |
|---|---|
| `xcodegen: command not found` | `brew install xcodegen` |
| 签名报错 `No account for team` | 在 Xcode 登录 Apple ID，重新选 Team |
| 相机黑屏 | 用真机；模拟器没有相机 |
| 通知不触发 | 检查系统通知权限、专注模式、时间是否已过 |
| 连接后端失败 | 用局域网 IP 而非 `127.0.0.1`；确认防火墙放行 8000 |
| 中文乱码 | 确保文件 UTF-8；Xcode 默认支持 |
| 编译报 `AlarmKit` 不存在 | 当前代码未引用 AlarmKit；若新增，需 Xcode 26 |

## 10. 上架前检查

- [ ] Bundle ID、版本号、图标、启动图
- [ ] 真机测试通知、相机、深色模式、动态字体
- [ ] 隐私政策与用户协议 URL
- [ ] App Store 隐私标签
- [ ] 订阅配置（StoreKit）
- [ ] 移除本地 HTTP 例外
- [ ] 关闭调试日志与测试账号
