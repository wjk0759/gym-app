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

- `develop` 代码 HEAD：`c79df35`；本文件的最新同步提交见 `git log -1`
- Windows 已完成：免费教练额度、54 张体型/体脂图、性别页卡通插画（透明素材）、体型/体脂选择器（体脂卡只显示躯干）、训练重点卡片网格、欢迎打字减速、App 内/桌面新 Logo、欢迎文案更新
- macOS 最近完成：品牌改名「叫练」；历史 iOS 构建/SwiftLint/29 个单测通过
- 最新后端验证：**174 passed**，Ruff 通过
- Mac 待办：`git pull` → `cd ios && xcodegen generate` → build/test → 浅色/深色真机检查
- 仍 BLOCKED：App Store Server API Key/Issuer/p8、Notifications V2 URL、TestFlight 沙盒、真机签名、预发/生产 Flyway

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
- 远端 `develop`：代码 `c79df35`；文档提交在其后，见 `git log -1`
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
- AI 教练 3 条/周；安全/医疗回复不占额度、不弹付费墙
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
