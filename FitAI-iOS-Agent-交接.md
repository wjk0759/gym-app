# 叫练（原 FitAI）交接给 iOS / OpenCode Agent

> 目标：在 `develop` 的基础上继续完成 Pro、试用、付费墙、滑动会话、防滥用和模块化收尾。
>
> 原则：服务端是权限唯一来源；客户端只负责展示与交互。不要为了“做完”伪造外部验收，不要把新代码堆成屎山。

---

## 0. Agent 同步频道

> Windows / macOS 两个 agent 的唯一同步入口。每次完成任务后，**先更新这里，再结束回复**。
> 最新在上。写清楚：日期 / 端 / 提交 / 做了什么 / 验证结果 / 对方需要做什么 / 禁止恢复什么。
> macOS 拉取后在本节顶部新增一条 `### 日期 · macOS`，写 build/test 结果和失败点。

### 最新状态

- `develop` 代码 HEAD：`5855d90`；Watch 功能分支 `feature/watch-standalone-workout` HEAD `8814d88`；本文件的最新同步提交见 `git log -1`
- Windows 已完成：真实 DeepSeek 视觉、AI 计划默认开启、视频入口隐藏、隐私标签补充、Apple 登录 entitlement、器械详情崩溃加固、男性椭圆/梯形 16–20% 体型图更新、香港 TestFlight 后端上线、阿里云短信验证码接通、Release 隐藏测试入口、头像上传/移除、设置页清理与第三方署名移除、今日→记录日期联动、训练阶段与按动作负荷、免费教练额度 3 条/天、饮食份量区间、文案精简、切换 Tab 回根页面、重复点 Tab 回根、页面顶部留白统一、Watch 共享训练核心
- macOS 最近完成：品牌改名「叫练」；当前 iOS 构建/SwiftLint 通过，44 个单测 + UI 导航测试通过（本轮修复测试辅助）
- macOS 最新完成（2026-11-07）：独立 worktree 验证 `feature/watch-standalone-workout`；Xcode 27.2 构建通过，`FitAIWorkoutCore` 10/10 测试通过，Watch 训练页/Pro 锁定页/动作占位页已在 Apple Watch Ultra 4 模拟器截图确认；修复 XcodeGen 多平台配置和 Watch DEBUG 条件（`94f8afa`）
- Windows 最新完成（2026-11-07）：手表独立语音教练、watch 专用登录会话、媒体预载/本地缓存、离线 outbox/ack、手机 inbox 回灌、手机→手表指令、3 天 Pro 宽限与中途到期继续结束、HealthKit 保活/手机单写者、Watch AppIcon 恢复；CI `iOS Build` 在 `8814d88` **success**
- 最新后端验证：**206 passed**，Ruff app/tests 通过；`/watch/bootstrap`、`/watch/session`、`/coach/voice` 已接入测试；V22 `training_stage` 已迁移；`/me/access` 免费教练额度 `daily_limit=3`、`weekly_limit=3`、`remaining=3`，`reset_at` 为北京时间次日 00:00；`training_stage=beginner`
- 成本提醒：3 条/天 ≈ 21 条/周，是原 10 条/周的约 2.1 倍；上线后监控 DeepSeek 账单和异常调用
- Mac 待办：`git pull` → `xcodegen generate` → Release build/test → 验证计划生成/教练调整按动作读取历史重量、训练阶段显示、3 条/天额度文案；验证今日选日期→记录页自动选中、返回今日回到今天、编辑计划按钮明显；验证切换 Tab 和重复点当前 Tab 都回到各根页面；验证 Tab 栏普通点击/滑动未被 reselect observer 拦截；逐页确认顶部 16pt 留白没有 double padding；验证免费文字额度 >0 不弹订阅、拍照/视频/器械显示 Pro 标识；验证改手机时间不能刷新余额；用 `https://hk-api.jiaolianfit.cn/api/v1` 真机验证 Apple 登录、手机验证码、头像相册/拍照、建档、AI 计划、教练、拍照；确认 Release 无「开发服务器」「测试连接」「服务状态」、无 RepDB/RawPheasant 署名；确认男性椭圆/梯形 16–20% 新图；键盘问题已定位为 Xcode 调试环境，未改产品代码
- 仍 BLOCKED：IAP 商品与协议、App Store Server API Key/Issuer/p8、Notifications V2 URL、TestFlight 外部 Beta 审核、Mac Release 签名上传、Watch 3D 动作素材、真实 Watch App ID/HealthKit capability、V23 生产迁移与 `/watch/*` 部署

### 2026-11-07 · Windows / OpenCode（手表独立语音、媒体、离线同步、手机指令、HealthKit）

- 分支：`feature/watch-standalone-workout`
- 代码提交：`8814d88`（本条文档提交见 `git log -1`）
- CI：GitHub Actions `iOS Build` **success** @ `8814d88`；`Backend Tests` **success** @ `7f5a340`（后端自该提交后未再改）
- 本地验证：后端 `pytest` **206 passed**，Ruff app/tests 通过；`FitAIWorkoutCore` **13/13** 通过；Swift 语法树检查 95 个文件 0 error
- 做了什么：
  - 后端新增 `POST /watch/session`（手表独立 refresh token，避免轮换顶掉手机）、`DELETE /watch/session`（手机退出时撤销全部手表会话）、`POST /coach/voice`（Pro 只读语音回答，不写 ChatMessage、不触发长期记忆，改计划类问题要求回 iPhone 确认）
  - Watch 新增 Keychain 凭据、`WatchAPIClient`（直连 `/coach/voice`、`/me/access`、`/auth/refresh`）、`WatchVoiceView`（`TextFieldLink` 系统听写/手写、文字必显、静音默认、点按朗读、耳机自动朗读、安全提示、iPhone 确认提示）
  - Watch 媒体：手机从 `/watch/bootstrap` 拉当天动作和媒体清单，下载 watch 视频/海报后通过 `WCSession.transferFile` 预载；手表 `WatchMediaStore` 落 Application Support，动作页本地播放、按 loop_start/end 循环、无暂停控件；缺视频显示海报/文字
  - 离线：watch 持久化 outbox（每会话只保留最新快照，最多 20 条），手机按 revision 去重并持久化 inbox，收取后 ack；手机 App 启动/回前台/后台唤醒时回灌为本地训练记录，复用现有 `syncPendingWorkouts` 补传服务端
  - 手机→手表：watch 主导时手机完成组/撤销/跳动作/跳过休息/暂停/结束都发 `WorkoutCommand`；手表不可达时手机只读并提示，不制造第二份训练
  - 开始时机：预载不再开始计时/HealthKit，第一次用户动作才写 `startedAt` 并启动 `HKWorkoutSession`；Watch 只保活，iPhone 仍是 HealthKit 唯一写入方
  - Pro：3 天宽限用服务端验证时间；手机离线且无已验证券时不再用“免费”覆盖手表缓存；Pro 中途到期/退款但有已开始会话仍可练完；手机退出后手表强制锁定
  - 恢复 Watch `AppIcon`；只有已配对且已安装 Watch App 才自动预载，Watch App 安装/变为可用时重新预载；手表日 ID 统一小写，后端也做兼容
- 已验证：
  - iOS CI 编译通过（含 FitAIWatch、FitAIWorkoutCore、iOS App）
  - 后端单测、Ruff、共享核心单测通过
  - Swift 语法检查通过
- 未验证（必须 Mac/真机）：
  - 真实 WatchConnectivity 预载/文件传输/ack/手机指令
  - 真实 Apple Watch 上 `TextFieldLink` 听写/手写、TTS、耳机路由、手表直连网络
  - HealthKit 授权、`HKWorkoutSession` 保活、手表锁屏/后台、iPhone 单写者是否产生重复训练
  - 真实视频循环（目前无 `sample_loop.mp4`/3D 素材）、海报回退、流量/电量
  - Watch AppIcon 在真机/TestFlight 显示
  - 真机签名、Watch App ID、HealthKit capability
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate`
  - Release/Debug 真机安装 iPhone + Watch App；确认 iPhone 训练页打开后 Watch 收到真实动作和媒体
  - 免费账号：Watch 锁定；Pro 账号：解锁。退出登录后 Watch 强制锁定
  - 手表断网/离开手机：完成组、休息、暂停、结束，再连回手机，确认手机生成同一 `sessionID` 的训练记录，重启手机 App 不重复
  - 手机与手表同时在线：手机完成组/撤销/跳动作/结束，确认由手表执行并回传；手机断连时显示只读提示
  - 手表语音：听写/手写各问一次；默认不自动朗读；点“朗读”出声；连耳机后“耳机自动”模式自动读；说“帮我把下周改成四练”应返回“需要 iPhone 确认”；确认 iPhone 聊天记录和长期记忆没有新增
  - 修改设备时间/服务端验证时间验证 3 天宽限；Pro 中途到期仍能结束当前会话
  - HealthKit：首次动作才出现授权/训练会话；结束只在 iPhone 健康里出现一条训练，Watch 不单独保存
  - 有素材后验证 loop_start/loop_end、左右滑、动作页无暂停控件、训练页暂停
  - 检查 Watch AppIcon、Watch App ID、HealthKit capability 与 TestFlight 签名
- 上线前外部阻塞：
  - 3D 动作素材/VitalAnimations 采购与转码（`watch_url`/`poster_url`/loop 元数据）仍未提供
  - V23 迁移与 `/watch/*`、`/coach/voice` 尚未部署生产
  - App Store Connect 协议/IAP、Server API Key、外部 Beta 审核
  - `test_reviewer` 仍需生产 Pro 授权
- 不要恢复：
  - 不要 `import WatchKit`；watchOS 视频用 AVKit `VideoPlayer`
  - 不要回退 `SDKROOT`/`SUPPORTED_PLATFORMS`/`@rpath`/rpath/Watch DEBUG 条件
  - 不要把共享 framework 换成本地 package 链接
  - 不要让 watch 本地解锁 Pro，不要让 watch voice 写聊天/长期记忆
  - 不要在 watch 主导时让手机本地追加组数；手机离线必须只读
  - 不要把 auth token 写进 `watch-workout.json`（只放 Keychain）
  - 不要用手机本地未验证的自由权益覆盖手表缓存

### 2026-11-07 · Windows / OpenCode（手表真实计划预载 + snapshot 回传）

- 分支：`feature/watch-standalone-workout`
- 提交：`db8e09e`
- CI：GitHub Actions `iOS Build` **success**（含 framework/watch/app）
- 做了什么：
  - `FitAIWorkoutCore` 增加 `WatchBootstrap` / `WatchAccess` / `WatchMediaAsset` / `WatchSessionEnvelope`
  - iOS 新增 `WatchSyncManager`，在训练开始页把当天计划、Pro 权益、媒体清单发到手表
  - watch 新增 `WatchWorkoutStore`，本地持久化 bootstrap 和 snapshot，所有操作走共享引擎
  - watch 新增 `WatchSyncManager`，接收 bootstrap、回传 `WatchSessionEnvelope`
  - 训练页/动作页改为读取 `WatchWorkoutStore`，不再直接读 mock engine
  - 3 天离线宽限逻辑进入 `WatchAccess.canTrain`
- 验证：
  - iOS CI 构建通过
  - 未真机验证 WatchConnectivity、真实计划发送、snapshot 回传
  - iPhone 收到 snapshot 后还未合并到当前训练 UI/服务端
- Mac 需要做：
  - 真机或 Simulator 验证 iPhone 打开训练页后手表收到真实动作
  - 手表完成一组后检查 iPhone 是否收到 `WatchSessionEnvelope`（目前只存内存）
  - 继续验证左右滑、AVKit 占位、Pro 锁定
- 不要恢复：
  - 不要让 watch 直接读 iPhone 的 SwiftUI 状态
  - 不要绕过 `WorkoutSessionEngine`
  - 不要把 bootstrap 当成永久授权；手表必须检查 `pro_expires_at` 和 3 天宽限

### 2026-11-07 · macOS（watch 独立分支构建与模拟器验证）

- 分支：`feature/watch-standalone-workout`
- 提交：`94f8afa`（本条目为后续 docs 提交）
- 工作区：独立 worktree `/Users/jacobwu/Documents/gym-app-watch`；未切换、未合并 `develop`，主 `develop` 工作区保持原样
- 做了什么：
  - 拉取 `4508de2`，`cd ios && xcodegen generate`
  - `swift test --package-path FitAIWorkoutCore`：**10/10 通过**
  - Xcode 27.2 构建 FitAI scheme（iPhone 17 模拟器，Debug），watch target 作为依赖一起构建
  - 在 Apple Watch Ultra 4 模拟器安装并运行 watch App
  - 截图确认：训练页（哑铃卧推、1/3 组、8–10 次、60kg、下一个平板支撑、完成一组）、Pro 锁定页、动作占位页（动作演示 / 等待动作素材 / 右滑回到训练）
- 发现并修复：
  - **Watch Debug 缺少 `SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG`**：`#if DEBUG` 不成立，`isPro` 走 `false`，所以 Debug 一打开就是 Pro 锁定页。已在 `project.yml` 的 Watch Debug 配置补上；临时把 `isPro` 改 `false` 看锁定页、把默认页改 `.action` 看占位页，截图后均已还原。
  - **Xcode 27.2 + XcodeGen 2.46 下多平台 framework 生成异常**：
    - `FitAIWorkoutCore` 生成后 `SDKROOT=auto`、`SUPPORTED_PLATFORMS=""`、没有 Info.plist
    - App 生成后没有 `SDKROOT`，Xcode 只把 FitAI 识别成 macOS 目标，报 “no destination matching”
    - framework 安装名是 `/Library/Frameworks/...`，App 也没有 `@executable_path/Frameworks` rpath，运行时 `dyld: Library not loaded`
  - 已在 `project.yml` 修复（提交 `94f8afa`）：
    - 项目级 `SDKROOT: iphoneos`
    - FitAI：`SUPPORTED_PLATFORMS: "iphoneos iphonesimulator"` + `LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/Frameworks"`
    - FitAIWatch：`LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/Frameworks"`
    - FitAIWorkoutCore：`SUPPORTED_PLATFORMS: "iphoneos iphonesimulator watchos watchsimulator"`、`GENERATE_INFOPLIST_FILE: YES`、`DYLIB_INSTALL_NAME_BASE: "@rpath"`
    - FitAIWatch Debug：`SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG`
- 验证结果：
  - FitAI scheme build：**BUILD SUCCEEDED**
  - watch App 已嵌入：`FitAI.app/Watch/FitAIWatch.app`
  - Debug watch bundle：`com.wjk.fitai.dev.watchkitapp`，companion `com.wjk.fitai.dev`
  - `FitAIWorkoutCore` 测试覆盖完成组、暂停/恢复、撤销、跳过休息、幂等命令
  - 没有启动本地后端，watch 壳不依赖登录/Pro
- 没验证 / 不要用这个壳判断：
  - 左右滑的真实手势：没有触摸注入，代码和页面已确认，需人工在 Device Hub 拖动验证
  - AVKit 真实播放：`ios/FitAIWatch/sample_loop.mp4` 不存在，当前只显示占位；素材到位后再验
  - 真实计划同步、真实 Pro 权益、离线队列、HealthKit、语音教练、3D 动画
  - 真机签名、Watch App ID、HealthKit capability、配对设备
- Windows 需要做：
  - 确认 `94f8afa` 的 Xcode 27 兼容配置是否保留/上游；Xcode 16 CI 可能不需要，但不要回退
  - 保留 Watch Debug 的 DEBUG 编译条件，否则所有 Debug 构建都会落到 Pro 锁定页
  - 补 `sample_loop.mp4` 或 3D 素材后，重新 `xcodegen generate` 再验 AVKit
  - 不要把这个分支合并到 `develop`，也不要让 watch 壳依赖后端登录/Pro
- 不要恢复：
  - 不要删除 `SDKROOT` / `SUPPORTED_PLATFORMS` / `DYLIB_INSTALL_NAME_BASE` / `LD_RUNPATH_SEARCH_PATHS` / `GENERATE_INFOPLIST_FILE` 这组 Xcode 27 修复
  - 不要删除 Watch Debug 的 `SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG`
  - 不要改 Debug/Release watch bundle ID
  - 不要把 `FitAIWorkoutCore` 改回本地 package 依赖

### 2026-11-07 · Windows / OpenCode（Watch 壳 + 后端契约 + CI 绿）

- 分支：`feature/watch-standalone-workout`
- 提交：`082ced8`（上一核心提交 `ca5095e`）
- 已推送并 CI 通过：
  - GitHub Actions `iOS Build` **success**：shared framework、watchOS target、App target、package tests 全部构建通过
  - `swift test --package-path FitAIWorkoutCore` 通过
  - 后端 `200 passed`（Watch bootstrap/media/Pro gate/每日额度）
  - admin-server Maven verify 通过；admin-web typecheck 通过
- 做了什么：
  - 新增 watchOS target，嵌入 iOS App；Pro 锁定页、训练页、动作页、左右滑分页
  - 训练页使用 `WorkoutSessionEngine`：完成组、暂停/恢复、撤销、跳过休息、下一个动作
  - 动作页使用 AVKit `VideoPlayer` + 循环通知；watchOS 不支持 `WatchKit` 模块，已改 AVKit
  - 新增 `WatchMovieView`，静音、关闭 hit testing
  - 后端新增 `/watch/bootstrap`（Pro only），返回当天计划、access、media 和 server_time
  - 新增 `exercise_media_assets` 模型和 `V23__watch_training.sql`（auth/workout 字段 + 媒体表）
  - 媒体选择：按用户性别优先，unisex 次之，其他性别兜底；未发布媒体忽略
  - 新增 `watch_training` 权益 key；iOS `ProFeature.watchTraining`、`canTrain` 解码
  - 修复 `LoadProgression.estimateWeight` 缺参数标签的编译错误
  - admin server 教练用量从周改为日，admin-web 显示“今日 AI 教练”
- 验证：
  - Windows 未真机；未在 Apple Watch 上验证
  - 未验证：视频循环、左右滑、Pro 锁定、真实手表电量、HealthKit、语音
  - watch AppIcon 暂未完成，当前关闭 `ASSETCATALOG_COMPILER_APPICON_NAME`；TestFlight 前必须补
- Mac 需要做：
  - `git pull` → `git switch feature/watch-standalone-workout` → `cd ios && xcodegen generate`
  - 真机跑 watch target，确认嵌入、签名、info.plist、HealthKit entitlement
  - 验证训练页按钮、左右滑、暂停、完成组
  - 补 watch AppIcon（Icon Composer/Asset Catalog）
  - 检查 `FitAIWorkoutCore` framework 的 watchOS deployment target 和嵌入
- 不要恢复：
  - 不要 `import WatchKit`（watchOS SDK 当前没有该模块）
  - 不要把 `FitAIWorkoutCore` 改回本地 package 依赖；Xcode 构建使用 framework target
  - 不要删除 `V23` 或 `exercise_media_assets`
  - 不要关闭 `/watch/bootstrap` 的 Pro gate

### 2026-11-07 · Windows / OpenCode（Watch 共享训练核心）

- 分支：`feature/watch-standalone-workout`
- 提交：`ca5095e`
- 做了什么：
  - 新增 `ios/FitAIWorkoutCore` Swift Package，iOS 17 / watchOS 10 共用
  - 新增确定性 `WorkoutSessionEngine`：完成组、撤销、暂停/恢复、跳过休息、切换动作、结束
  - 所有命令带 `operationID`；`(exerciseID, setIndex)` 幂等；不读系统时钟，时间由命令携带
  - Codable/Hashable/Sendable snapshot，支持崩溃恢复和 WatchConnectivity 传输
  - 新增 `WorkoutCoreAdapter`，把现有 `PlanDay` / `PlanExercise` / `SetLog` 映射到共享模型
  - `AppConfig.watchWorkoutEnabled = false` 作为后续功能开关
  - iOS CI 增加 `swift test --package-path FitAIWorkoutCore`
- 验证：
  - tree-sitter 语法检查 0 error
  - 未在 Windows 编译 Swift；未跑 package 单测
  - GitHub Actions `iOS Build` 会在推送分支时执行 package 单测和 simulator build
- Mac 需要做：
  - `git pull` → `git switch feature/watch-standalone-workout`
  - `cd ios && xcodegen generate`
  - `swift test --package-path FitAIWorkoutCore`
  - `xcodebuild ... build`（已有 CI 也会跑）
  - 确认 XcodeGen 本地 package 依赖正常、FitAITests 能 import `FitAIWorkoutCore`
- 不要恢复：
  - 不要把训练状态直接写回 View 的 `@State`
  - 不要让命令依赖系统时间
  - 不要用 `(slug, setIndex)` 替代 `(exerciseID, setIndex)` 做去重（自定义动作可能同 slug）

### 2026-11-06 · Windows / OpenCode（免费教练改为每天 3 条 + 提前订阅弹窗修复）

- 提交：`ebf5752`；额度文案 `5855d90`
- 做了什么：
  - 免费教练额度从 10 条/周改为 3 条/天，不累计；按北京时间 00:00 在服务端刷新
  - `/me/access` 新增 `daily_limit=3`，保留 `weekly_limit=3` 兼容旧客户端
  - `FeatureUsage` 周期改为自然日；`reserve_coach_message` 支持传入 period，避免跨午夜判断不一致
  - 教练文案改为「今日免费 AI 教练剩余 X/Y 条」「北京时间每天 00:00 恢复 3 条」
  - 删除教练欢迎页「升级 Pro · AI 教练不限条数」大卡；0 条时才显示额度用完卡
  - 免费用户文字消息一律先走 Agent，不再因计划类关键词或计划调整阶段提前弹订阅
  - `sendAgentChat` 的 `PRO_REQUIRED` 增加防御：Pro 或额度 > 0 时不弹教练订阅页
  - 新增 `ProFeature.coachVision`（拍照问教练）；拍照/相册/动作点评改用它
  - 拍照/相册/视频/器械/动作点评对免费用户显示「Pro」标识；文案明确文字教练仍有每天免费额度
  - 免费用户欢迎文案不再邀请「发照片」
  - 更新 `FeaturePolicyTests`，新增 daily_limit 优先、旧 weekly_limit 兼容测试
- 验证：
  - 后端 **197 passed**，Ruff app/tests 通过
  - 生产已部署；`/health`、`/health/ready` 200
  - 生产 `/me/access`（test_reviewer）：`daily_limit=3`、`weekly_limit=3`、`remaining=3`、`reset_at=2026-11-06T16:00:00+00:00`（北京时间次日 00:00）
  - Windows 未编译 iOS；未真机验证每日刷新和订阅弹窗路径
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate` → build/test
  - 运行 `FeaturePolicyTests`（daily_limit 优先、weekly_limit 兼容）
  - 免费账号验证：每天 3 条；第 4 条显示「今天的免费 AI 教练额度已用完」；次日北京时间 00:00 后恢复 3 条
  - 改手机时间/时区后仍不能刷新余额（服务端时间）
  - 免费账号发文字：额度 >0 时不弹订阅；问计划问题也不提前弹
  - 确认欢迎页大升级卡已消失；0 条时额度用完卡正常
  - 免费账号点「拍照 · Pro / 相册 · Pro / 动作点评 · Pro」：弹「拍照问教练」订阅页，文案应说明文字教练仍有每天免费额度
  - 视频点评/器械识别显示「Pro」标识
  - 旧客户端兼容：旧包仍会读 `weekly_limit=3`，但文案可能显示「本周」，服务端实际按天
- 不要恢复：
  - 不要把免费教练额度改回 10 条/周
  - 不要删除 `daily_limit` 或把 `weekly_limit` 设回 10
  - 不要恢复欢迎页「升级 Pro · AI 教练不限条数」大卡
  - 不要用 `.coachAI` 作为拍照/相册/动作点评的 Paywall（会再次让人误以为额度用完）
  - 不要在免费用户文字发送前用 `isPlanScheduleRequest` / `planAdjustmentStage` 拦订阅
  - 不要用手机本地时间计算额度或重置

### 2026-11-06 · Windows / OpenCode（重复点 Tab 回根 + 顶部留白统一）

- 提交：`40f3027`
- 做了什么：
  - 新增 `TabBarReselectObserver`：在今日 Tab 的宿主层给底层 `UITabBar` 加非阻塞 tap 识别，重复点当前 Tab 时调用 `resetTabPaths()`
  - `cancelsTouchesInView = false` + 允许同时识别，普通切 Tab、Tab 栏点击和滑动不受影响
  - 切换 Tab 与重复点 Tab 共用同一套 path 重置逻辑
  - 新增 `AppLayout.pageTopPadding = 16` 和 `.appPageTopPadding()`
  - 所有标准页面滚动容器统一 16pt 顶部留白；修复今日饮食、训练重点等贴住导航栏的页面
  - 新增 UI 测试 `testTappingCurrentTabReturnsToSectionRoot`
- 验证：
  - tree-sitter 语法检查 35 个改动 Swift 文件，0 error
  - Windows 未编译 iOS；未真机验证 `UITabBar` 手势和 16pt 视觉效果
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate`（新增 `App/TabBarReselectObserver.swift`，必须重新生成工程）→ build/test
  - 运行 `testTappingCurrentTabReturnsToSectionRoot`、`testSwitchingTabsReturnsToSectionRoot`
  - 真机验证：我的 → 设置 → 再点我的 = 我的根
  - 真机验证：记录 → 训练记录 → 再点记录 = 记录根
  - 真机验证：今日 → 变化 → 再点今日 = 今日根
  - 确认普通切 Tab、Tab 栏点击和滑动没有被 observer 拦截
  - 逐页确认顶部留白：今日饮食、训练重点、设置、变化、训练历史、计划历史、器械识别、饮食记录、体型照片；不能出现 double padding
- 不要恢复：
  - 不要用 `.id()` 重建 Tab 根页面
  - 不要把 observer 改成 `cancelsTouchesInView = true` 或独占手势
  - 不要恢复各页面 2 / 8 / 10 / 12 / 14 的零散顶部 padding
  - 不要把 `.appPageTopPadding()` 套到 action bar / sticky footer

### 2026-11-06 · Windows / OpenCode（切换 Tab 回根页面）

- 提交：`03eb5ee`；UI 测试：`b6b0d75`
- 做了什么：
  - 新增 `AppTab` / `TabRoute` / `appTabDestinations()`，统一五个 Tab 的 tag 和根级 push 目的地
  - `MainTabView` 为今日 / 记录 / 发现 / 我的各持有一个 `NavigationPath`；切换 Tab 时清空全部 path，只弹掉二级页面，不重建根页面
  - 根级入口改为 `NavigationLink(value:)`：变化、训练记录、饮食、编辑档案、设置、动作教程、器械库
  - 设置仍从「我的」工具栏进入，改用 value 路由
  - 新增 UI 回归测试 `testSwitchingTabsReturnsToSectionRoot`：我的 → 设置 → 今日 → 我的，应回到我的根
- 验证：
  - tree-sitter Swift 语法检查 13 个文件，0 error
  - Windows 未编译 iOS，未在模拟器 / 真机验证
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate`（新增 `App/TabRoute.swift`，必须重新生成工程）→ build/test
  - 运行 `testSwitchingTabsReturnsToSectionRoot` 和现有 UI 导航测试
  - 验证：我的 → 设置 → 切今日 → 回我的 = 我的根
  - 验证：今日 → 变化 → 切记录 → 回今日 = 今日根
  - 验证：记录 → 训练记录 → 切今日 → 回记录 = 记录根
  - 验证：发现 → 动作教程 → 切今日 → 回发现 = 发现根
  - 确认切 Tab 后各根页面滚动位置、教练输入、记录页选中日期仍保留
  - 重复点当前 Tab 回根已在 `40f3027` 补上
- 不要恢复：
  - 不要用 `.id()` 重建 Tab 根页面
  - 不要恢复根级 `NavigationLink { destination }`（会绕过 path）
  - 不要在切 Tab 时清空教练输入或根页面状态

### 2026-11-06 · Windows / OpenCode（饮食份量区间 + 文案精简）

- 提交：见 `git log -1`
- 做了什么：
  - 饮食视觉 prompt 改为先找盘子/碗/勺子/手等自然参照物，再按覆盖面积、高度和密度估算
  - 输出 `grams_min` / `grams_max` / `portion_confidence` / `portion_basis`，不再只给一个假精确数字
  - 后端校验热量与宏量营养，偏差过大时按蛋白/碳水/脂肪反推
  - 免责声明压缩为一行；拍照提示、结果页重复的模型说明和重复免责声明删除
  - 教练欢迎卡删掉重复的剩余额度，只在输入框上方显示
  - 训练编排、编辑档案、组间提示、目标重量说明压缩
- 验证：
  - 后端 **196 passed**，Ruff 通过
  - 生产 `/health`、`/health/ready` 200
  - Windows 未编译 iOS；未用真实餐食照片做端到端验证
- Mac 需要做：
  - `git pull` → `xcodegen generate` → build/test
  - 用真实餐食照片检查份量区间、置信度、Stepper 修改后热量重算
  - 检查饮食拍照、教练、训练编排、编辑档案没有因删文案出现空洞或截断
  - 安全、过敏、隐私、支付、注销提示必须仍在
- 不要恢复：
  - 不要恢复「结果来自远程识别服务，照片未保存」等重复模型说明
  - 不要把饮食免责声明重复放在结果卡和页面底部
  - 不要把教练剩余额度同时放在欢迎卡和输入框

### 2026-11-06 · Windows / OpenCode（训练阶段 + 按动作负荷 + 额度 10）

- 提交：见 `git log -1`
- 做了什么：
  - V22 增加 `profiles.training_stage`，0–59 小白 / 60–119 有基础 / 120+ 进阶，按 Asia/Shanghai 完成训练日回填，只升不降
  - 新增 `training_history` / `load_progression`：读取最近 12 周每个动作的 SetLog，回退最近计划目标，最后才估算
  - 计划生成不再信任 AI 重量，服务端按动作覆盖 `weight_kg`；模板和本地兜底同一规则
  - 4 周渐进：小白周 2/4、有基础周 3、进阶周 4；上肢 2.5%、下肢 5%（进阶减半）
  - 每周 AI 调整改为按动作 RPE/完成情况逐动作乘系数，不再全局 ×1.025
  - iOS `LoadProgression`、`training_stage` 解码、阶段标签、`PlanAdjustmentCoach` 按动作权重
  - 免费教练额度 3 → 10；iOS 文案从服务端 `weekly_limit` 读取
- 验证：
  - 后端 **193 passed**，Ruff `app/tests` 通过
  - V22 Flyway `success=1`；生产 `/me/access` 返回 `weekly_limit=10`
  - `training_stage` 登录/`/auth/me` 返回 `beginner`
  - Windows 未编译 iOS；后端未做真实计划生成的端到端真机验证
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate` → build/test
  - 真机：有历史动作的计划生成应显示基于上次重量的目标；无历史动作显示保守估算
  - 教练「调整计划」按动作变化，不再所有动作同一个比例
  - 训练阶段显示在「我的」页；免费教练文案显示 10 条
- 不要恢复：
  - 不要恢复全局 `weightMultiplier` 的每周调整
  - 不要让 AI 输出直接覆盖服务端计算的历史重量
  - 不要把 `COACH_WEEKLY_LIMIT` 改回 3
  - 不要删除 V22 或 `training_stage` 回填

### 2026-11-06 · Windows / OpenCode（今日→记录日期联动 + 编辑按钮）

- 提交：见 `git log -1`
- 做了什么：
  - `AppStore.pendingRecordDate` + `openRecord(for:)`，跨 Tab 传日期
  - Today「查看这一天的计划」带上当前 `selectedDate`
  - 记录页接收后设置 `selectedDate` / `visibleMonth`，滚动到当天卡片
  - 返回 Today 时 Today 和记录页都重置到今天
  - 记录页「编辑」改为荧光绿实心胶囊「编辑计划」+ pencil 图标
- 验证：
  - Windows 未编译 iOS；只做代码修改和静态检查
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate` → build
  - Today 选 11/5 → 查看这一天的计划 → 记录页选中 11/5，日历在 11 月
  - 记录页看 11/7 → 点今日 → 再点记录 → 回到今天
  - Today 直接点记录 → 保留记录页上次日期
  - 编辑计划按钮明显可点，打开对应日期编辑器
- 不要恢复：
  - 不要把「查看这一天的计划」改回只 `selectedTab = 1`
  - 不要删除 `pendingRecordDate` 和 `onChange` 联动
  - 不要把编辑按钮改回微型文字

### 2026-11-06 · Windows / OpenCode（设置页清理 + 移除第三方署名）

- 提交：见 `git log -1`
- 做了什么：
  - 删除设置页 `动作图：Exercise data by RepDB (repdb.co)` 和 `体型人台：RawPheasant5745 · CC BY 4.0` 两条署名
  - `legacy_exercises.json` 中 `xj_0011` / `xj_0320` 的 `motion_start_url` / `motion_end_url` 置空，旧本地数据不再加载 RepDB 图
  - `FrameMotionBoard` 改为通用「双帧示意」，移除 RepDB 角标、链接和无障碍文案；代码保留给自有素材
  - `tools/db/import_xunji_movements.py` 清空 RepDB 样例，保留空 hook，避免重新导入
  - Release 隐藏「服务状态」整段；Debug 保留；Release 不再请求 `/health`
  - 隐私政策移除 RepDB 第三方提及
- 验证：
  - `legacy_exercises.json` 解析成功，1293 条；非空 motion URL 为 0
  - iOS 用户可见文案中已无 RepDB / RawPheasant 署名
  - 后端无改动
  - Windows 未编译 iOS
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate` → build/test
  - Release 设置页确认没有「服务状态」、没有两条署名
  - Debug 设置页确认「服务状态」仍在
  - 打开 `xj_0011` / `xj_0320` 动作详情，确认只显示占位轨迹，不加载 RepDB 图片
- 不要恢复：
  - 不要把 RepDB URL 写回 `legacy_exercises.json`
  - 不要把 RawPheasant / RepDB 署名加回设置页
  - 不要删除 `#if DEBUG` 里的服务状态代码

### 2026-11-06 · Windows / OpenCode（头像上传/移除）

- 提交：`c6e6eb4`（代码）；文档见本次提交
- 做了什么：
  - 复用 `users.avatar_url TEXT`，不新建表、不新增迁移
  - 新增 `POST /api/v1/me/avatar`、`DELETE /api/v1/me/avatar`
  - 服务端 Pillow 校验、中心裁剪 512×512、转 JPEG、去 EXIF，限制 8MB
  - `/auth/me`、`/me`、登录响应返回顶层 `avatar_url`
  - iOS `AvatarEditorButton`：相册 + 拍照、昵称首字占位、上传中 spinner、失败提示、移除头像
  - `AuthStore.avatarURL`、`APIClient+Avatar`、`AppConfig.resolveMediaURL` 支持相对媒体路径
  - 隐私政策补充头像上传与服务器存储说明
- 验证：
  - 后端 **184 passed**，Ruff `app/tests` 通过
  - 真实上传 200，下载 512×512 RGB；`/auth/me` 返回 `avatar_url`
  - 换头像后旧文件 404；移除后新文件 404、`avatar_url` 为空
  - 未登录上传 401；`text/plain` 上传 415
  - Windows 未编译 iOS
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate` → build/test
  - 真机验证：相册选图、拍照、上传、重启后头像保留、移除后回到昵称首字
  - 确认「我的」页头像 52×52，不挤压昵称和箭头布局
  - 确认 Release 仍然没有「开发服务器」「测试连接」
- 不要恢复：
  - 不要新增 `user_avatars` 历史表；当前头像只放 `users.avatar_url`
  - 不要把头像字段放进 `profiles` 表
  - 不要移除 Pillow/EXIF 清理/512 裁剪
  - 不要删除 `AvatarEditorButton` 或把上传逻辑塞回 `ProfileView`

### 2026-11-05 · Windows / OpenCode（Release 隐藏测试入口）

- 提交：`07e6936`
- 做了什么：
  - `ios/project.yml` 的 Release `FITAI_API_BASE_URL` 固定为 `https://hk-api.jiaolianfit.cn/api/v1`
  - 登录页「开发服务器」入口仅 Debug 显示
  - 设置页 API 地址 + 「测试连接」仅 Debug 显示
  - `AuthStore` / `APITransport` / `SubscriptionManager` 的 Debug 提示在 Release 改为普通用户提示
  - 测试代码全部保留，用 `#if DEBUG` + 注释标记，未删除
- 验证：
  - Windows 只做代码修改和静态检查，没有 Xcode，**未编译 iOS**
  - 后端仍在运行，Release API 地址已确认
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate`
  - Release build 确认 `FitAIAPIBaseURL` 是 `https://hk-api.jiaolianfit.cn/api/v1`
  - 确认 Release 登录页没有「开发服务器」、设置页没有「测试连接」/API 地址
  - 真机验证 Apple 登录、手机验证码、建档、AI 计划、教练对话、拍照上传
  - 如果编译报错，把报错原文发回
- 不要恢复：
  - 不要把测试入口重新暴露到 Release
  - 不要删除 `#if DEBUG` 里的开发服务器/测试连接/调试提示代码
  - 不要把 Release 地址改回 `https://api.invalid/api/v1`

### 2026-11-05 · Windows / OpenCode（香港 TestFlight 后端上线）

- 提交：`f8e085e`（后端上线）；隐私页与文档见本次提交
- 做了什么：
  - 香港 ECS：2 核 4G / Ubuntu 22.04.5 / Docker 29.9.3 / Compose v5.7.0
  - 域名 `hk-api.jiaolianfit.cn` → `8.218.205.149`，Caddy 自动申请 Let's Encrypt 证书
  - MySQL 8.4 容器，Flyway V1–V21 全部 `success=1`
  - FastAPI 2 worker + Caddy 反代；`fitai-db` / `fitai-api` / `fitai-caddy` 全部 healthy
  - `ios/project.yml` 的 Release `FITAI_API_BASE_URL` 改为 `https://hk-api.jiaolianfit.cn/api/v1`
  - 新增 `docs/48-hk-testflight-backend.md`（服务器、命令、备份、迁移说明）
  - 新增 `deploy/hk/`：Caddyfile、docker-compose、隐私政策/支持页
  - 隐私政策 `https://hk-api.jiaolianfit.cn/privacy`、支持页 `https://hk-api.jiaolianfit.cn/support`
  - 创建 App Review 测试账号 `test_reviewer`（`is_test=true`，密码只在 Windows 桌面文件，不入库）
  - 阿里云 PNVS 短信已接通：`SMS_PROVIDER=aliyun_pnvs`，赠送签名「恒创联众」，模板 100001；真实手机号发送成功
  - iOS Release 隐藏开发服务器、测试连接、Debug 网络错误提示；相关代码用 `#if DEBUG` 保留并加注释，未删除
- 验证：
  - `https://hk-api.jiaolianfit.cn/health` → `{"status":"ok","env":"production","llm":"deepseek-flash","vision":"deepseek-flash"}`
  - `https://hk-api.jiaolianfit.cn/health/ready` → `{"status":"ready"}`
  - `http://` → `308` 跳 HTTPS
  - DeepSeek `/chat/completions` 真实调用返回 200
  - 账号密码登录 → `/auth/me` → `/me/access` 全链路 200；免费教练额度 10 条/周
  - `/privacy`、`/support` 返回 200 `text/html`
  - MySQL 27 个动作已 seed；当前内存 API 175MB + DB 517MB + Caddy 11MB
  - 后端 **178 tests passed**，Ruff（改动文件）通过；`alibabacloud_dypnsapi20170525` 已安装进 API 镜像
  - `POST /auth/phone/send-code` 返回 200，`delivery=aliyun_pnvs`；用户已收到验证码
  - Windows 没有编译 iOS；Release 隐藏测试入口需 Mac 构建确认
- Mac 需要做：
  - `git pull` → `cd ios && xcodegen generate`
  - Release build 确认 `FitAIAPIBaseURL` 是 `https://hk-api.jiaolianfit.cn/api/v1`
  - 真机验证：Apple 登录、手机验证码、建档、AI 计划、教练对话、拍照上传、`/me/access`
  - 确认 Release 登录页没有「开发服务器」、设置页没有「测试连接」/API 地址
  - 手机验证码已可用；短信发送方显示「恒创联众」，内测帖需提前说明
- 不要恢复：
  - `ios/project.yml` 里的 `https://api.invalid/api/v1`
  - 不要把 `/opt/fitai/.env`、MySQL 密码、JWT、DeepSeek Key 提交到仓库
  - 不要对公网开放 3306 / 8000
- 仍 BLOCKED：IAP 商品与协议、App Store Server API Key/Issuer/p8、Notifications V2 URL、TestFlight 外部 Beta 审核、Mac Release 签名上传、Watch 3D 动作素材、真实 Watch App ID/HealthKit capability、V23 生产迁移与 `/watch/*` 部署

### 2026-11-05 · Windows / OpenCode（男性椭圆/梯形 16–20% 素材）

- 提交：`483508e`
- 做了什么：
  - 用新源图 `椭圆型16%-20%.png`、`梯型16%-20%.png` 替换：
    - `BodyFigureMaleOvalFat16To20`
    - `BodyFigureMaleTrapezoidFat16To20`
  - 新源图是 1440×2560、带浅灰纹理背景的 RGB 图，不是纯白底
  - 用“最大前景连通域 + 填洞 + 轻微边缘羽化”抠图，去掉纹理背景和零星噪点
  - 输出保持 400×667、14px 边距、透明背景；alpha bbox 与旧图一致 `(38, 14, 362, 653)`
  - 没有改 UI、枚举、资产名或测试
- 验证：深色/浅色合成预览干净，无白边/灰底残留；尺寸、四角透明、bbox 正确；
  Swift 文件未改；Windows 没有跑 iOS 构建
- Mac 需要做：`git pull` → `xcodegen generate` → build；在浅色/深色下看男性“椭圆型/梯形 + 16–20%”的体型页、体脂卡和报告组合图
- 不要恢复：旧的两张 16–20% 椭圆/梯形图；不要把新源图原图直接导入

### 2026-11-04 · macOS

- 提交：`9f138e8`（测试修复）、`a52ca9f`（上一条同步）均未推送；本轮 Debug 签名修复未提交；键盘排查未改产品代码
- 做了什么：
  - 拉取 `95e8e5c`，完成 iOS 构建、SwiftLint、单元测试、UI 导航测试和 backend 测试。
  - 修复 `BodyFigureAssetTests.alphaChannel` 的测试辅助 bug：`CGImage` 绘制到 bitmap context 后 row 0 已经是顶部，重复做垂直翻转会让 torso 探针读到画布下半区，造成 `testTorsoCropKeepsTheBodyOpaque` 假失败。只改测试，不改 UI/素材。
- 验证：
  - iOS build 成功；SwiftLint **0 violation**
  - iOS unit **44/44**；UI 导航测试通过
  - backend **175 passed** + Ruff 通过
- Debug 真机签名方案（已实现）：
  - Debug 使用独立 Bundle ID `com.wjk.fitai.dev` 和 `FitAI-Debug.entitlements`（保留 HealthKit，不含 applesignin）。
  - Debug 隐藏 Apple 登录入口；Keychain service 使用 `com.fitai.app.auth.debug`，不与 Release 共享登录态。
  - Release 继续使用 `com.wjk.fitai` + `FitAI.entitlements`，Apple 登录和正式 capability 不变。
  - Debug 真机构建 **成功**，已安装并启动 `com.wjk.fitai.dev`；模拟器 44 个单测 + UI 测试通过，SwiftLint 0 violation。
- 键盘首次加载专项（已完成定位，未改产品代码）：
  - `xctrace` 直接启动 / attach：0 个 >250ms 主线程 hang；主线程 CPU 分别约 3.15s / 2.34s，键盘相关约 0.99s / 0.83s。
  - Xcode `Start the active scheme`（带 LLDB/诊断）首次键盘：出现 539ms、725ms、1.64s 和 **2.27s/2.33s Severe Hang**。
  - 临时关闭 Debug executable + Main Thread Checker + Thread Performance Checker 后，用户实测不再卡顿。
  - 结论：是 Xcode 调试运行环境放大了首次键盘/CoreText 初始化成本，不是 App 业务逻辑或 UI 布局问题。
  - 诊断用的 scheme 临时改动已通过 `xcodegen generate` 恢复；临时 `TextInputPrewarm` 和键盘计时测试已移除。
- 仍待处理：
  - Release 真机/TestFlight 仍需支持 Sign in with Apple capability 的付费团队；`FITAI_API_BASE_URL` 仍是占位域名。
  - 如 Release 首次键盘仍复现，再继续查系统键盘进程。
- Windows 需要提供：
  - 生产 API 域名；Release 真机/TestFlight 的付费 Team/描述文件。
  - 键盘专项暂不需要 Windows 继续排查；如 Release 仍复现再回传。

### 2026-11-04 · Windows / OpenCode（真机键盘卡顿排查请求）

- 提交：暂无代码变更；当前代码 HEAD `a6de43d`
- 现象：
  - iPhone 14 Pro / iOS 18 真机
  - 所有输入框调起系统键盘都卡 5–10 秒，登录页最明显
  - 空账号也卡
  - 只用系统键盘，没有第三方输入法
- Windows 初步判断：
  - 基本排除第三方键盘
  - 空账号也卡，持久化 state 不是唯一原因
  - 优先怀疑 App 级主线程阻塞或 SwiftUI 键盘布局/全屏背景重绘
- 可能热点（按优先级）：
  1. `LoginView`：`GeometryReader` + `ScrollView` + `.scrollDismissesKeyboard(.interactively)` + 条件 `.safeAreaInset` 键盘完成栏，键盘出现时布局链较复杂
  2. `AppBackground` / `GrainTexture`：全屏渐变 + 平铺纹理，每次键盘 safe-area 变化都可能重绘
  3. `FitAIApp.task` 启动即 `await subscriptions.load()`：StoreKit 首次商品请求可能占用主线程
  4. `RootView.task` 的 `auth.restoreIfNeeded()`；`AppStore.load()` / `switchUser()` 同步 JSON 读盘解码
  5. 登录页 `.textContentType(.telephoneNumber/.oneTimeCode)` 触发 AutoFill
- Mac 需要做（按顺序，先取证再改）：
  1. `git pull`；分别用 Debug 和 Release 真机测试，确认是否只在 Debug 卡
  2. 删除 App 重装，不登录，点登录手机号框；仍卡则不是本地 state
  3. Xcode 控制台搜 `STRESS load`；下载 App container，查看 `Documents/fitai-state*.json` 大小
  4. Instruments Time Profiler 录 10 秒：启动 → 点手机号输入框；抓主线程最重栈（重点看 JSONDecoder、Data(contentsOf:)、StoreKit、SwiftUI layout、Text/Gradient 绘制）
  5. 逐项隔离（每项单独测，记录结果）：
     - 注释 `FitAIApp.task` 里的 `await subscriptions.load()`
     - 注释 `RootView.task` 里的 `auth.restoreIfNeeded()`
     - LoginView 临时把 `AppBackground()` 换成 `Theme.background`
     - 临时去掉 `.safeAreaInset` 的键盘完成栏
     - 临时去掉 `.scrollDismissesKeyboard(.interactively)`
     - 临时去掉外层 `GeometryReader`（用固定 compact 值）
  6. 做一个最小 SwiftUI TextField 页面，逐项加回背景/ScrollView/safeAreaInset/GeometryReader，确认哪一层触发
  7. 系统设置里关闭 AutoFill Passwords 再试；临时去掉登录页 `textContentType` 再试
  8. 对比 iOS 18 模拟器和另一台真机；排除系统键盘/AutoFill 问题
- 回传：
  - Debug/Release 结果
  - `STRESS load` 日志、state 文件大小
  - Time Profiler 截图/最重栈
  - 哪一项去掉后不卡
- 不要：
  - 不要先猜着提交“修复”
  - 不要删除键盘完成栏/背景组件
  - 不要用 `DispatchQueue.main.sync` 之类方式掩盖问题

### 2026-11-04 · Windows / OpenCode（真实视觉 / AI 计划 / 视频隐藏 / TestFlight 加固）

- 提交：`8b1d57a`、`c133d24`
- 做了什么：
  - 视觉默认复用 DeepSeek Flash：`VISION_MODEL` 留空时回退 `LLM_MODEL`，
    `VISION_BASE_URL`/`VISION_API_KEY` 留空时复用 `LLM_*`
  - 已用本地图片实测 `deepseek-flash` 的 image_url 输入返回 200，真实视觉可用
  - 计划生成默认 `LLM_PLAN_ENABLED=true`，reasoning 用 `low`；
    AI 失败/超时仍走规则模板；iOS 计划 toast 区分 AI / 模板
  - 首次建档计划也允许走远程 AI，失败再回退本地模板
  - 教学视频入口全部隐藏：`AppConfig.exerciseVideosEnabled=false`；
    播放器/占位代码保留在 `EquipmentDetailView+Media.swift`，不要删除
  - 器械详情加固：
    - 资源 JSON 缺失/重复不再 `assertionFailure` 崩溃
    - 图表过滤非有限值，避免 NaN 导致 Charts 异常
    - 视频请求在开关关闭时不再触发（生产 `PUBLIC_BASE_URL` 为空时该接口会 503）
  - 补 Sign in with Apple entitlement
  - Release API 改为从 `Info.plist`/`FITAI_API_BASE_URL` 读取，Debug 才允许 localhost；
    当前占位 `https://api.invalid/api/v1`，上 TestFlight 前必须替换
  - `PrivacyInfo.xcprivacy` 补 Device ID / Purchase History / Product Interaction；
    视频大小检查改用 `resourceValues(forKeys:)`，避开 File Timestamp required-reason API
  - 后端生产启动校验：缺 JWT/PUBLIC_BASE_URL/Apple/StoreKit/LLM 配置直接启动失败
  - 新增 `docs/47-testflight-checklist.md`
- 验证：backend **175 passed** + Ruff 通过；真实视觉调用成功；
  Swift 语法解析通过；Windows 没有跑 iOS 构建/单测
- Mac 需要做：`git pull` → 填 `FITAI_API_BASE_URL` → `xcodegen generate` → build/test；
  重点回归器械详情（之前报错）、计划生成、拍照识别、视频入口是否完全隐藏
- 如果器械详情仍报错：把 Xcode 控制台第一行或崩溃堆栈发给 Windows agent；
  本次已修掉最可能的资源初始化、Charts NaN、视频接口三条路径
- 不要恢复：旧的 Mock 视觉、视频入口、localhost Release API、JSON `assertionFailure`

### 2026-11-04 · Windows / OpenCode（桌面图标 / 欢迎文案 / 透明性别素材）

- 提交：`c2c71bc`、`c79df35`
- 做了什么：
  - 桌面 `AppIcon` 换成 `logo.png` 的 1024×1024 版本：RGB、无 alpha、不做圆角
  - 旧哑铃/L 标志全部清理：启动恢复页、登录页头部、器械详情教练卡都改用 `CoachMark`
  - 欢迎页第一段改成「您好，/ 我是叫练」，打字参数不变
  - 性别页换用 `性别女-卡通-透明.png` / `性别男-卡通-透明.png`：
    直接使用自带 alpha，重新生成 800×1422 全身和 250×250 头像
  - 透明背景、手臂空隙、背景采样测试继续通过
- 验证：性别页深/浅色预览干净；AppIcon 1024×1024 RGB 无 alpha；
  Swift 语法解析通过；backend **174 passed** + Ruff 通过；
  Windows 没有跑 iOS 构建和单测
- Mac 需要做：`git pull` → `xcodegen generate` → build/test；
  看桌面图标、启动恢复页、登录页、器械详情教练卡、欢迎文案，
  以及性别页全身/头像的浅色和深色显示
- 不要恢复：旧 AppIcon、旧哑铃/L 标志、旧欢迎文案、旧性别素材

### 2026-11-04 · Windows / OpenCode（App 内新 Logo）

- 提交：`b1407f6`
- 做了什么：
  - `CoachMark` 不再画圆底 + L，改用 `BrandLogo` 图片资产
  - 新增 `BrandLogo.imageset`：由 `logo.png` 缩到 512×512，保持黑底 + 荧光绿图形
  - 显示时裁成 iOS 风格圆角方形（圆角约 23.5%），加一圈自适应细边，
    深色模式下也能看出边界
  - 影响位置：首页右上、教练聊天头部、首页教练笔记、欢迎页、名字页提示
  - 桌面 AppIcon 未改，仍是旧的哑铃图标
  - 新增 `BrandAssetTests`，检查 `BrandLogo` 存在、是正方形且不小于 256
- 验证：76/58/38/34 四档深色/浅色预览目检通过；Swift 语法解析通过；
  backend **174 passed** + Ruff 通过；Windows 没有跑 iOS 构建和单测
- Mac 需要做：`git pull` → `xcodegen generate` → build/test；
  检查首页右上 38、欢迎页 76、聊天头部 58、教练笔记 34 的显示，
  深色模式下圆角边界和荧光绿是否清楚
- 不要恢复：旧的 SwiftUI 圆底 + L `CoachMark`；不要把 2048 原图直接塞进 assets

### 2026-11-04 · Windows / OpenCode（性别页卡通素材）

- 提交：`f9633fe`
- 做了什么：
  - 性别页大人台和双卡头像换成 `性别男-卡通.png` / `性别女-卡通.png`
  - 男性源图是棋盘格背景（已烤进像素，不是真透明），女性源图是纯白底；
    两者都重新抠成透明背景
  - 男性源图底部/右侧有 1px 黑色导出边框，处理前裁掉 2px
  - 保留女性白色腕带、短裤白色条纹；男性短裤白条也保留
  - 全身图 `800×1422`，头像 `250×250`；资产名不变，页面代码不变
  - 测试新增顶部左右两个背景采样点，防止棋盘格/白底残留
- 验证：深色/浅色合成预览目检通过，手臂/腿间无白条，腕带和白条纹保留；
  Swift 语法解析通过；backend **174 passed** + Ruff 通过；Windows 没有跑 iOS 构建和单测
- Mac 需要做：`git pull` → `xcodegen generate` → build/test；
  浅色/深色看性别页，重点看 52×52 小头像有没有裁到脸、
  大人台底部渐隐是否自然、头发边缘有没有白边
- 不要恢复：旧性别插画、棋盘格/白底版本；不要把 `性别男-卡通.png` 原图直接导入

### 2026-11-04 · Windows / OpenCode（体脂卡改躯干图）

- 提交：`5c906fb`
- 做了什么：
  - `BodyFigure` 新增 `crop` 参数：`.fullBody`（默认）/ `.torso`
  - 体脂卡改用 `.torso`：按 400×667 共享画布裁掉头、手和腿，
    只保留肩颈到胯部，胸腹腰的体脂差异更直观
  - 裁切矩形 `(0.215, 0.142, 0.570, 0.398)`，运行时按比例裁切，
    不新增 54 张图片，54 张组合图本身未改动
  - 去掉体脂卡图片的 shadow，避免沿裁切边缘出现横向阴影
  - 体型页大图/缩略图和最终报告仍显示全身
  - 新增测试：组合图必须都是 400×667、裁切矩形在画布内、
    代表图躯干中心不透明
- 验证：深色/浅色裁切预览目检通过；Swift 语法解析通过；
  backend **174 passed** + Ruff 通过；Windows 没有跑 iOS 构建和单测
- Mac 需要做：`git pull` → `xcodegen generate` → build/test；
  在浅色/深色下看体脂页，确认 6 张卡只显示躯干、没有头/手/腿，
  选中边框和标签高度不跳动
- 不要恢复：体脂卡全身图、体脂卡图片 shadow、`BodyFigureCrop` 之外的硬编码裁切

### 2026-11-04 · Windows / OpenCode（性别插画白底修复）

- 提交：`8c3ba77`
- 做了什么：
  - 重新处理 `性别男.png` / `性别女.png` 的透明通道：不再只从边缘泛洪，
    改为按连通区域删除封闭白块（手臂与躯干之间、双腿之间）
  - 覆盖 `GenderMale` / `GenderFemale` 的 `body-figure.png`
  - `GenderMalePortrait` / `GenderFemalePortrait` 头部裁切无封闭白块，文件未变
  - 新增 `BodyFigureAssetTests.testGenderAssetsHaveTransparentBackground`：
    检查四角透明、手臂空隙透明、躯干不透明
- 验证：深色/浅色合成图目检通过；Swift 语法解析通过；backend **174 passed** + Ruff 通过；
  Windows 没有跑 iOS 构建和单测
- Mac 需要做：`git pull` → `xcodegen generate` → build/test；
  在浅色和深色下看性别页，确认手臂/腿间没有白色竖条，腕带和短裤白条仍在
- 不要恢复：旧的整图泛洪抠图脚本；不要把白底图片重新导入 `GenderMale` / `GenderFemale`

### 2026-11-04 · Windows / OpenCode（欢迎打字速度）

- 提交：`420ea75`
- 做了什么：欢迎页打字速度第一段 42→90ms/字，第二段 30→70ms/字；
  标点停顿 160→280ms，新增换行 220ms；触感频率降到 5/7
- 验证：Swift 语法解析通过；Windows 没有跑 iOS 构建
- Mac 需要做：build 后看一遍欢迎页，确认能看清、不拖沓；点屏幕仍可立即显示全文
- 不要恢复：旧的 42/30ms 快速打字参数

### 2026-11-04 · Windows / OpenCode（性别 / 体型 / 体脂重做）

- 提交：`5707370`
- 做了什么：
  - 性别页改用 `性别男.png` / `性别女.png` 插画：完整图做大人台，头部裁切做双卡头像
  - 删除旧的 `BodyFigureMalePortrait` / `BodyFigureFemalePortrait`
  - 体型页改为「上方大图 + 下方横向缩略图」；默认用第三档体脂预览（女 19–22%，男 16–20%）
  - 删除体型卡上的「建议」标签和 `BodyTypeCard`
  - 体脂页改为 2×3 图片网格；选中卡深色边框 + 深色标签条；不再显示备注文案
  - 新增 `BodySelectionViews.swift`，体型/体脂卡从 `BodyShapes.swift` 拆出
- 验证：backend **174 passed** + Ruff 通过；Windows 只做 Swift 语法解析，**没有跑 iOS 构建**
- Mac 需要做：`xcodegen generate`；重点检查性别插画裁切、体型默认第三档、体脂 2×3 网格、浅色/深色选中态
- 不要恢复：`BodyTypeCard`、`BodyFigureMalePortrait`、`BodyFigureFemalePortrait`、体型卡「建议」标签
- BLOCKED：同上

### 2026-11-04 · Windows / OpenCode

- 提交：`a313cf7`（文档）、`7324577`（训练重点）、`f78cf1e`（性别页）、
  `2ce8ae1`（体型/体脂图）、`4fcf8c4`（免费教练额度）
- 做了什么：
  - 免费教练文本改走 `/agent/chat`；额度用尽不再本地回复，聊天页显示内联 Pro 卡
  - 接入 54 张体型/体脂组合图；onboarding 改为先体型后体脂；报告显示组合图
  - 性别页改为头像双卡 + 自适应大人台
  - 训练重点改为器械页同款卡片网格；「均衡练全身」为互斥卡；取消最多 2 个限制
  - 计划生成不再截断前 2 个重点；全选 7 个按均衡处理
  - 删除 `BodyFocusMap`、`BodySilhouette`、`BodyType.shoulder/waist/hip` 等旧人体图代码
- 验证：backend **174 passed** + Ruff 通过；Windows 只做 Swift 语法解析，**没有跑 iOS 构建**
- Mac 需要做：`xcodegen generate`；重点检查浅色/深色性别页、体型/体脂卡、训练重点 8 张卡、报告组合图
- 不要恢复：旧轮廓人体组件、`BodyFocusMap`、`BodySilhouette`、`BodyType` 比例参数
- BLOCKED：同上，外部 Apple/真机/预发环境仍未验证

### 2026-11-03 · macOS

- 品牌改名「叫练」：iOS 显示名、登录/付费墙、法律文档、AI 提示词、后台和文档
- 运营者：深圳市龙岗区叫练软件开发工作室；技术标识保持不变
- 验证：iOS 构建成功、SwiftLint 0 violation、29/29 单测、backend 171 + smoke
- 待 Windows 复核：品牌残留、法律主体、后台旧品牌

---

## 1. 当前工作区与状态

- Windows 仓库：`E:\Projects\FitAI`
- macOS 工作区：`/Users/jacobwu/gym-app`
- 当前分支：`feat/pro-access-followup-2026-11`，基于 `develop`
- 远端 `develop`：代码 `483508e`；文档提交在其后，见 `git log -1`
- 正式发布前仍需真实数据库、真机和 App Store Connect 配置

> **2026-11-03 macOS 进展：品牌已改名「叫练」。** 用户可见品牌、法律文档、
> AI 提示词、后台和文档均已同步；运营者为「深圳市龙岗区叫练软件开发工作室」。
> 技术标识保持不变：Bundle ID `com.wjk.fitai`、IAP `com.fitai.app.pro.*`、
> URL Scheme `fitai`、Keychain/UserDefaults/本地存储、Xcode target/module
> `FitAI`、Java 包名和数据库名。图标暂不改。
>
> 验证：iOS 构建成功，SwiftLint **0 violation**，单元测试 29/29，UI 导航测试通过；
> backend 171 个测试 + smoke 通过；全仓库 `练途` 已清零。
> 外部凭据/真机/预发库/App Store Connect 项仍标 BLOCKED。

历史 CI（改名提交后请以新 CI 结果为准；不要引用旧提交的绿色状态）：

- Backend Tests #102：✅ `afd4afc`
- iOS Build #224：✅ `314cd49`
- Admin CI #27：✅ `296b3eb`

当前运行中的开发环境：

- MySQL 8（Docker）：`127.0.0.1:3307`，健康
- FastAPI：`http://127.0.0.1:8000`
- Admin Server：`http://127.0.0.1:8080`
- 后台页面：`http://127.0.0.1:5173/admin/`
- 后台账号：`admin`，密码见 `deploy/admin/.env` 的 `FITAI_BOOTSTRAP_PASSWORD`
- 开发库已实际执行 Flyway V14–V20
- 回填核对：7 个已引导用户对应 7 个训练试用；4 个饮食周计划对应 4 个饮食试用

测试账号：

- 用户 ID：`05cdf2e3-eb7e-46ed-aef0-4378911b78d8`
- 已标记 `is_test=true`
- 已授予 30 天 Pro，当前到期约 `2026-12-02`
- 后台真实登录、授予、延长、撤销、审计已在本机验证过

---

## 2. 已经完成，不要重做

### 权益与收费
- `user_entitlements`、`feature_trials`、`feature_usage`
- 训练计划 onboarding 一次性试用；后续生成/调整/下周期 Pro
- 饮食周计划和单日计划共用一次免费体验；后续 Pro
- AI 教练 10 条/周；安全/医疗回复不占额度、不弹付费墙
- 饮食拍照、身材拍照、教练视觉/视频分析 Pro 直拦
- 高级周复盘 Pro
- 计划调整、Agent 草案应用、周复盘已补服务端 Pro 拦截
- 客户端统一 `FeaturePolicy` / `FeatureAccessStore` / `ProPaywallCoordinator`
- `AppStore.paywallFeature` 已移除

### StoreKit
- 客户端购买/恢复后把 Apple JWS 同步到 `POST /me/storekit/transactions`
- 服务端校验证书链、Apple Root CA G3 指纹、ES256、Bundle ID、商品、环境、有效期、退款/撤销
- 交易必须绑定当前账号的 `appAccountToken`
- `POST /iap/app-store/notifications` 已支持退款、撤销、续订，续订支持通过 `appAccountToken` 找回账号
- 已用合成 Apple 证书链补 JWS 验签、过期、撤销、续订绑定测试

### 防滥用
- `feature_generation_state`：服务端冷却、并发 1、幂等回放
- V20 支持按功能冷却：计划/饮食 60 秒，拍照/视觉 5 秒
- V18 `rate_limit_buckets`：数据库 token bucket，多 worker 共享
- 计划、饮食、拍照、教练文本、Agent 都有并发保护
- AI 全局日/月 token 预算，70/90% 告警，100% 自动降级
- V19 `ai_runtime_control`：后台暂停/恢复 AI，测试账号白名单
- 同设备重登撤销旧会话、单账号最多 5 个活跃设备、异常多账号/批量 IP 登录写 `auth_events`
- Refresh 复用/设备不匹配写告警和事件

### 客户端与后台
- AppStore 已拆 `AppStore+Sync`、`AppStore+Agent`、`FeatureAccessStore`
- PlanHistory、PlanHomeTrainingData、CoachChatActionCards 已拆出
- 教练输入栏显示每周额度
- 后台用户列表支持测试账号筛选
- 后台 AI 用量支持 token、运行开关、暂停原因
- 结构化错误 `PRO_REQUIRED` / `COACH_QUOTA_EXHAUSTED` / `RATE_LIMITED` / `GENERATION_*`
- iOS 已解析 `APIError.code`、`retry_after`，429 不再一律弹付费墙

---

### 品牌与工程收尾（2026-11-02/03，已完成，不要重做）

- **品牌改名「叫练」**：iOS 显示名、登录/付费墙/权限/水印、法律文档、AI 提示词、
  FastAPI 标题、admin-web/admin-server 品牌、README/docs/preview 用户可见文案均已更新。
- **App Store 名称**先用「叫练」；App Store Connect 名称/副标题/截图/隐私政策 URL 需手工更新。
- **运营者**：深圳市龙岗区叫练软件开发工作室；法律文档范围「叫练 iOS 内测版」，
  更新日期 2026-11-03；客服邮箱仍为 `wjk0759@163.com`。
- **App Store Server API**：`backend/app/services/app_store_api.py`、`POST /iap/app-store/reconcile`、
  `backend/scripts/reconcile_storekit.py` 和 mock 测试已完成；真实 Apple 请求因缺 Key/Issuer/p8 而 BLOCKED。
- **拍照幂等**：`feature_result_cache` V21 + `photo_cache`，覆盖体型/饮食/器械/教练视觉；
  只缓存脱敏 JSON，TTL 300 秒，写入时清理过期行；不落原图。
- **设备会话**：缺 `X-Device-ID` 兼容放行；刷新 401/403 清 token、发 `.fitaiSessionExpired`
  回登录页；客服文档见 `docs/46-device-session-support.md`。
- **模块化**：AppStore/Agent/Sync/Plan/Profile/Workouts/Settings/Export 拆分；
  PlanHome/CoachOnboarding/WorkoutSession/EquipmentDetail/HomeV2/Login/Settings/
  CoachChat/Nutrition/Progress/WorkoutHistory 等大 View 已拆；Models 与 APIClient 已分域；
  代码中已无 `swiftlint:disable file_length type_body_length`，SwiftLint 0 violation。
- **测试**：backend 171 个测试通过；iOS 单元测试 29/29；UI 导航性能测试通过。

---

## 3. 用户的质量要求

用户原话：

> 多用高级语法，尽量少用判断语句。

落实标准：

1. **Swift**
   - 优先 `guard`、`switch`、模式匹配、`Optional.map/flatMap`、`Set`、`async let`、`TaskGroup`、`@Observable`、值类型。
   - 少写多层 `if let ... { if ... { } }`；先提前返回，再处理主路径。
   - View 只做展示和交互，不直接调 `APIClient`，不写业务计算。
   - 新逻辑优先放 service/store/coordinator；依赖通过参数或 environment 注入。
   - 不要用 `try?` 吞掉用户能感知的错误；该提示就提示，该记录就记录。

2. **Python**
   - 用 early return、dataclass、context manager、推导式、`match`、依赖注入。
   - 不在事务里调用 LLM/短信/天气。
   - 新错误必须结构化；不要新增裸字符串业务错误。
   - 新 service 不要内部随手 `commit()`，事务边界放在 router 或明确的服务方法。

3. **通用**
   - 禁止重复序列化、重复查询、重复 UI 组件、重复常量。
   - 禁止 God object、超大函数、魔法数字、死代码。
   - 每完成一项都要自查：是否符合周边风格？是否能更简单？是否引入新耦合？
   - 注释只写“为什么”，不要写显而易见的“做了什么”。
   - 不提交 `.env`、密钥、`smoke.db`、媒体文件。

---

## 4. 待完成项（按优先级）

### P0 收费与外部验收

- [x] **App Store Server API 校验与定期订阅对账（本地实现完成；真实调用 BLOCKED）**
  - 已实现 `backend/app/services/app_store_api.py`、`POST /iap/app-store/reconcile`、
    `scripts/reconcile_storekit.py` 与 mock 测试。
  - 已实现 ES256 JWT、订阅查询、Apple JWS 二次校验、幂等台账写入；空/畸形响应会报错，
    不会伪造成功。
  - 真实 Apple 请求 BLOCKED：缺少 App Store Connect 的 Key ID、Issuer ID、p8 私钥。

- [ ] **BLOCKED · App Store Connect 配置 Notifications V2 URL**
  - 缺少 App Store Connect 权限和可公网访问的域名/隧道；本地 webhook 代码已存在并有验签测试。
  - URL：`https://<你的域名>/api/v1/iap/app-store/notifications`
  - 本地验证可用隧道；真实配置需要 App Store Connect。
  - 验证退款、撤销、续订、订阅成功事件都能更新台账。

- [ ] **BLOCKED · TestFlight / StoreKit 沙盒真实购买、恢复、退款**
  - 缺少真实 Apple 账号、App Store Connect 商品和 TestFlight 环境。
  - 购买后确认：
    - 客户端拿到 verified transaction
    - 服务端 `/me/access` 变 Pro
    - 退款/撤销后变免费
    - 恢复购买能重新同步
  - 需要真实 Apple 账号和 App Store Connect 商品配置，不能本地伪造。

- [ ] **BLOCKED · App Store Connect 名称与素材**
  - 代码/桌面显示名已用「叫练」；App Store Connect 名称需手工改为「叫练」，
    副标题待定。截图、隐私政策 URL、TestFlight 信息也需同步检查。
  - 名称可用性需在 App Store Connect 确认；如被占用需准备备选。

- [ ] **BLOCKED · 给测试账号 30 天 Pro 真机端到端验证**
  - 真机 `Wu-Tang` 已配对且 DDI 可用，但本机 Xcode 未登录 Apple ID、无开发证书，无法签名安装。
  - 测试账号已设置，见第 1 节。
  - 真机验证免费体验、付费墙、AI 额度、StoreKit 购买、恢复、退款。

- [ ] **BLOCKED · V14–V21 在预发/生产 MySQL 执行并核对回填**
  - 缺少预发/生产 MySQL 连接与 Flyway 权限；本次新增了 V21 `feature_result_cache`，未在任何 MySQL 执行。
  - 开发库 3307 已完成，不要重复改开发库。
  - 预发/生产只通过 Flyway 执行，不手工改表。
  - 核对 `feature_trials` 与历史 onboarded/meal week 数量。

### P1 iOS 收费体验

- [x] **拍照分析幂等键**
  - 已实现 `feature_result_cache` V21 + `photo_cache` 服务，覆盖体型、饮食、器械、教练视觉；只缓存脱敏 JSON 文本，TTL 300 秒，不落原图。
  - 客户端在体型/饮食/器械/教练视觉请求带 `Idempotency-Key`；免费用户仍先过 Pro 校验并返回 403。
  - 服务端已有同用户并发 1 和 5 秒冷却；同 key 重试会返回同一份结果。
  - 过期缓存会在写入新结果时清理；并发写入保留首个幂等结果，不覆盖。
  - 免费用户仍先过 Pro 校验；原图不落盘。

### P2 防滥用与成本

- [ ] **BLOCKED · App Attest / DeviceCheck**
  - 需要 Apple 团队配置、App Attest capability 和真机；未编写未经验证的声明式接口，避免假装上线。
  - 不要在未验证的情况下声称已上线。
  - 建议先设计 challenge/attestation 接口和开关，默认关闭。

- [ ] **BLOCKED · 重复提示词、批量注册的后台筛选与告警看板**
  - 风控看板尚未实现；本机仍缺 Java/Node/admin 测试数据库，无法本地运行 admin-server/admin-web 的 CI。
  - 检测而不是直接封禁；家庭共享设备/运营商 NAT 会误报。
  - 后台可按设备、IP、提示词 hash、时间窗筛选。
  - 所有处置必须写审计日志。

- [ ] **DEFERRED · Redis 可选后端（非阻塞）**
  - 按文档只有吞吐成为瓶颈时再接；当前数据库 token bucket 已支持多 worker，本次不引入新依赖。
  - 只有吞吐成为瓶颈时再接 Redis；不要让 Redis 成为单点依赖。

### P3 滑动会话

- [ ] **BLOCKED · 真机测试**：并发 401、断网、刷新响应丢失、旧 refresh token 复用、多设备同时在线。
  - 后端单元测试已覆盖刷新轮换宽限、旧 token 复用撤销、设备不匹配、最大设备数；真机需要可签名安装。
- [x] **设备 ID 缺失/变更的兼容策略与客服路径**
  - 新增 `docs/46-device-session-support.md`，写明兼容策略、`auth_events` 排查和客服撤销 SQL。
  - 旧客户端缺少 `X-Device-ID` 时兼容放行，并补了后端测试。
  - 客户端收到 401/403 刷新拒绝时清除 token、发出 `.fitaiSessionExpired` 并回到登录页，不静默丢本地数据。

### P4 模块化与大文件拆分

- [x] `AppStore` 剩余 Plan / Nutrition / Workout / Profile 子域拆分
  - 已抽出 `PlanGenerationService`、`WorkoutSyncService`、`NutritionService`；Profile/Plan/Workouts/Settings/Export 方法拆到 extension，主文件只保留状态、生命周期与持久化，已低于 lint 阈值。
  - 已拆：Sync、Agent、Access
  - 目标：AppStore 只做状态容器和协调，不继续长成 God object

- [x] 抽 `PlanGenerationService`：远程/本地生成已下沉到 `Core/Services/PlanGenerationService.swift`
- [x] 抽 `WorkoutSyncService`：API 调用与远端映射已下沉；合并策略仍留在 `AppStore+Sync`
- [x] 抽 `NutritionService`：饮食记录同步与远端映射已下沉到 `Core/Services/NutritionService.swift`
- [x] 拆 `PlanHomeView`
  - 已拆：History、TrainingData；Header、QuickActions、MonthCover、Calendar、SelectedDay、Plan/Empty、Data 拆到 7 个 extension 文件
- [x] 额外拆分 `WorkoutDetailView`：只读摘要/动作卡拆到 `WorkoutDetailCards.swift`，移除该文件 lint 豁免
- [x] 额外拆分 `EquipmentPickerView`：动作卡/选择控件/肌群图标拆到 `EquipmentPickerCards.swift`，移除该文件 lint 豁免
- [x] 额外拆分 `HomeV2View`、`SettingsView`、`LoginView`、`CoachChatView`、`NutritionView`、`ProgressOverviewView`、`WorkoutHistoryView`：按 extension 拆分，代码中已无 lint 豁免
- [x] 额外拆分 `AppStore`：Profile / Plan / Workouts / Settings / Export 方法拆到 extension；Agent 拆 Chat/Actions
- [x] 拆 `CoachOnboardingView`：已按 Layout / Steps / Report / Components / Derived 拆到 5 个 extension 文件
- [x] 拆 `WorkoutSessionView`：Header / 动作卡 / SetCard / Rest / ActionBar / Summary / 输入弹窗拆到 `WorkoutSessionComponents.swift`
- [x] 拆 `EquipmentDetailView`：Media / Points / Stats / Hero 拆到 4 个 extension 文件，Stats 类型独立
- [x] 拆 `Models.swift`：按 Profile / Training / Nutrition / Equipment 四个文件拆分
- [x] 按需拆 Nutrition / Settings / Progress / HomeV2 / EquipmentLibrary / Login
  - Settings/HomeV2/Login/Nutrition/Progress/EquipmentLibrary 等均已完成拆分；当前 SwiftLint 0 violation。
- [x] iOS 单元测试修复：`PRODUCT_NAME` 补到测试 target；`PlanGeneratorTests` 改为验证当前 `PlanGenerator.adjustment` API，29 个测试全部通过
- [x] SwiftLint：
  - `file_length` warning 600 / error 1000
  - `type_body_length` warning 400 / error 600
  - 已加 `.swiftlint.yml` 和 iOS CI 检查
  - 现有大文件已完成拆分，代码中不再有 `swiftlint:disable file_length type_body_length`；本地 lint **0 violations**
- [x] 新 View 禁止直接调用 `APIClient`；权益判断禁止写在 View
  - `ios/FitAI/Features` 下 `APIClient.shared` 调用已清零，体型/饮食/器械/设置/饮食计划等均走 service。
  - Pro 锁定 UI 仍统一走 `store.requirePro/requestPro`；服务端 gate 未改。
  - 不要为了“没 if”把逻辑藏进 View extension 里

### P5 验证与发布

- [ ] PARTIAL · iPhone SE / 16 / 16 Pro Max 全页面截图验收
  - 已在三类模拟器安装运行并截图首页/登录；逐页视觉验收仍需人工完成。
- [ ] 登录、表单、弹窗、键盘回归
- [ ] BLOCKED · 真机验证登录、免费体验、付费墙、AI 额度、滑动会话
- [ ] BLOCKED · TestFlight / StoreKit 沙盒购买与恢复
- [ ] PARTIAL · 防连点、并发、重装、换设备、批量注册测试
  - 本次补了拍照幂等、刷新设备不匹配、缺设备头兼容等后端测试；真机与批量注册仍需环境。
- [ ] PARTIAL · 最后做一次服务端 Pro 绕过审计，确认 LLM Key 只在服务端
  - 已确认 iOS 端没有模型 Key；完整服务端绕过审计仍需真实预发环境。

---

## 5. 已知陷阱

1. **跨文件 Swift extension 不能访问 `private`**
   - 已在 `PlanHomeTrainingData` 踩过：`trainingDataCard` 必须改成 internal。
   - 不要无脑把所有 `private` 删掉；优先用明确的 internal 接口或参数注入。

2. **AppStore 不是 `@MainActor`**
   - `FeatureAccessStore.refresh/consume` 标了 `@MainActor`。
   - 移动 AppStore 方法时注意 actor isolation，不要引入数据竞争。
   - 嵌套 Observable 的刷新依赖动态追踪，UI 改动后要真机/模拟器确认。

3. **生成状态表**
   - `feature_generation_state` 的幂等回放要求 `last_result_ref` 非空。
   - 不要为了回放塞假 ref；拍照结果如果没持久化就不能假装可回放。
   - 计划/饮食 60 秒，拍照 5 秒；改冷却用 `cooldown_seconds` 字段，不要再写全局常量。

4. **StoreKit**
   - 不要关闭证书链校验或 root 指纹校验。
   - 不要接受无 `appAccountToken` 的跨账号交易。
   - 退款/撤销必须走通知或 Server API，不能只靠客户端。
   - 合成证书测试在 `backend/tests/test_app_store.py`，不要删。

5. **安全与额度顺序**
   - 安全/医疗回复必须先于额度判断和付费墙。
   - 付费墙 UI 不是授权；服务端 gate 不能删。
   - 429 要区分 `GENERATION_COOLDOWN`、`GENERATION_IN_PROGRESS`、`RATE_LIMITED`、`COACH_QUOTA_EXHAUSTED`。

6. **MySQL / Flyway**
   - 后端启动不会自动跑迁移；Admin Server 启动时才跑 Flyway。
   - 改迁移后重启 Admin Server，确认 `flyway_schema_history`。
   - 开发库是 Docker 3307；不要连错到本机 3306。

7. **后台**
   - 页面 base path 是 `/admin/`。
   - 管理员密码在 `deploy/admin/.env`，不要打印到日志/提交。
   - 后台“延长 Pro”必须从当前到期时间往后加，不能从 now 重新算。

8. **Git/网络**
   - GitHub 网络偶尔不稳定；push 失败要重试，别把“本地提交成功”说成“CI 通过”。
   - 不要合并 `develop`，等真机和预发验收。
   - 不要动 `F:\FitAI-body-shapes` 备份目录。

---

## 6. 验证命令

### Backend

```powershell
cd E:\Projects\FitAI\backend
.\.venv\Scripts\python.exe -m ruff check app tests scripts
.\.venv\Scripts\python.exe -m pytest -q
$env:PYTHONIOENCODING='utf-8'
$env:ALLOW_DEV_USER_HEADER='true'
$env:GENERATION_COOLDOWN_SECONDS='0'
.\.venv\Scripts\python.exe scripts/smoke.py
```

### Admin

```powershell
cd E:\Projects\FitAI\admin-server
mvn -B -ntp verify

cd E:\Projects\FitAI\admin-web
npm run typecheck
npm test -- --run
npm run build
```

### iOS

- Windows 本地不能跑 Xcode；以 GitHub Actions `iOS Build` 为准。
- XcodeGen 工程：

```bash
cd ios
xcodegen generate
xcodebuild -project FitAI.xcodeproj -scheme FitAI \
  -sdk iphonesimulator -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

### 健康检查

```powershell
Invoke-WebRequest http://127.0.0.1:8000/health/ready
Invoke-WebRequest http://127.0.0.1:8080/actuator/health/readiness
Invoke-WebRequest http://127.0.0.1:5173/admin/
```

---

## 7. Git 与提交要求

- 从 `develop` 拉新分支再改，例如 `feat/pro-access-followup-2026-11`
- 小步提交，前缀：
  - `feat(api): ...`
  - `fix(ios): ...`
  - `refactor(ios): ...`
  - `test(...): ...`
  - `docs: ...`
- 每个提交前：
  - `git status`
  - `git diff --check`
  - 对应 lint/test
- 涉及数据流/权益/试用的改动，同步更新：
  - `docs/44-long-term-data-model.md`
  - `docs/45-engineering-standards.md`
  - 涉及隐私时更新 `docs/43-legal-docs.md` 和 `LegalDocuments.swift`
- 不提交：
  - `.env`
  - 密钥、p8、证书私钥
  - `smoke.db`
  - 媒体/上传文件
- 不合并 `develop`，不删除备份目录，不 force push。

---

## 8. 完成标准与汇报格式

每一项完成时按这个格式汇报：

```text
做了什么：
- ...

关键文件：
- ...

验证：
- 本地测试：
- CI：
- 真机/外部验证：

剩余风险：
- ...
```

只有满足验收标准才从清单删除。外部条件缺失时：

- 明确写出缺什么（Apple Key、Issuer、p8、真机、TestFlight、预发库）
- 写清已经验证了什么
- 不要写“应该可以”“理论上支持”当作完成

---

## 9. 最后提醒

这个项目最怕三件事：

1. **客户端假装权限**：所有 Pro/试用/额度最终必须服务端拒绝。
2. **重复扣费**：生成/拍照要有并发锁、冷却、必要的幂等；失败不能扣额度。
3. **大文件继续膨胀**：新功能不要继续塞进 `AppStore`、`PlanHomeView`、`CoachChatView`。先抽 service/子 View，再接 UI。

按这个标准做，不要只追求“能跑”。

## 10. Windows OpenCode 同步快照

- 先拉取最新 `develop`；当前改名提交在 `develop` 历史中；本地不要重命名目录。
- 最新 Windows 提交：`7324577`（训练重点卡片网格）；之前还有 `f78cf1e`（性别页）、
  `2ce8ae1`（体型/体脂图）、`4fcf8c4`（免费教练额度）。
- **不要恢复**：`BodyFocusMap`、`BodySilhouette`、`BodyType.shoulder/waist/hip`
  等旧轮廓人体组件；用户要求删除。
- **不要改**：`ios/FitAI/`、`FitAITests/`、`FitAIUITests/`、`FitAIApp.swift`、
  `FitAI.entitlements`、`FitAI.xcodeproj`、Bundle ID、IAP 商品 ID、URL Scheme、
  Keychain/UserDefaults key、Java 包名、数据库名。
- **只改用户可见品牌**：显示名、文案、法律文档、AI 提示词、后台品牌。
- V21 迁移必须通过 Flyway 执行；后台启动前确认 `feature_result_cache` 存在。
- App Store 名称/副标题/截图/隐私政策 URL 在 App Store Connect 手工处理，代码里没有 App Store 名称配置。
