# 47 · TestFlight / 上线前检查

> 这份是 2026-11-04 的当前状态，不是最终法律或审核意见。每次发版前逐项核对。

## 1. 代码侧状态

- [x] App 内 Logo / 桌面 AppIcon 已统一为 `logo.png`
- [x] 性别页使用最新透明卡通素材
- [x] 教学视频入口暂时隐藏：`AppConfig.exerciseVideosEnabled = false`
  - 播放器代码保留在 `EquipmentDetailView+Media.swift`，不要删除
- [x] 视觉识别接 DeepSeek Flash：`VISION_MODEL` 留空时复用 `LLM_MODEL`
- [x] 计划生成默认 AI + 规则校验 + 模板回退
- [x] Sign in with Apple entitlement 已补
- [x] PrivacyInfo.xcprivacy 已补 Device ID / Purchase History / Product Interaction
- [x] 视频文件大小检查改用 `URL.resourceValues(forKeys: [.fileSizeKey])`
- [x] 器械库 JSON 缺失/重复不再触发 `assertionFailure` 崩溃
- [ ] Release API 域名仍是 `https://api.invalid/api/v1` 占位
  - 必须在 `ios/project.yml` 的 `settings.base.FITAI_API_BASE_URL` 填入生产 HTTPS 域名
  - 不改会连不上后端，这是故意的防误连保护

## 2. 生产环境变量

`backend/.env` 不能直接用于生产。生产至少需要：

```env
APP_ENV=production
ALLOW_DEV_USER_HEADER=false
PUBLIC_BASE_URL=https://api.example.com
JWT_SECRET=<强随机值>
APPLE_CLIENT_ID=com.wjk.fitai
APP_STORE_BUNDLE_ID=com.wjk.fitai
STOREKIT_PRODUCT_IDS=com.fitai.app.pro.monthly,com.fitai.app.pro.yearly
STOREKIT_ALLOWED_ENVIRONMENTS=Production,Sandbox
APP_STORE_API_KEY_ID=
APP_STORE_API_ISSUER_ID=
APP_STORE_API_PRIVATE_KEY_PATH=
APP_STORE_API_ENVIRONMENT=sandbox
APP_STORE_RECONCILE_TOKEN=
LLM_PROVIDER=deepseek
LLM_API_KEY=
LLM_PLAN_ENABLED=true
LLM_PLAN_REASONING_EFFORT=low
VISION_MODEL=deepseek-flash
SMS_PROVIDER=webhook
SMS_WEBHOOK_URL=
SMS_WEBHOOK_TOKEN=
```

`APP_ENV=production` 时，后端启动会检查 `JWT_SECRET`、`PUBLIC_BASE_URL`、`APPLE_CLIENT_ID`、`APP_STORE_BUNDLE_ID`、`STOREKIT_PRODUCT_IDS`、`LLM_API_KEY`；缺项会直接启动失败。

## 3. 数据库

- [ ] 预发/生产 MySQL 执行 admin-server Flyway V14–V21
- [ ] 核对 `feature_trials` 和历史 onboarded / meal week 回填
- [ ] FastAPI 的 `DATABASE_URL` 指向生产 MySQL，不是本机 3307

## 4. App Store Connect

- [ ] App 记录已创建，Bundle ID 为 `com.wjk.fitai`
- [ ] 订阅商品：
  - `com.fitai.app.pro.monthly`
  - `com.fitai.app.pro.yearly`
- [ ] 订阅组、价格、中文/英文本地化、审核截图完成
- [ ] Paid Apps 协议、税务、收款账号已生效
- [ ] App Store Server API Key ID / Issuer ID / p8 已配置
- [ ] Notifications V2 URL 指向 `https://<域名>/api/v1/iap/app-store/notifications`
- [ ] Sandbox 测试账号已创建
- [ ] 隐私政策 URL、支持 URL 已可公网访问
- [ ] 外部 TestFlight 的 Beta App Review 信息、测试账号、What to Test 已填写

## 5. 隐私标签对照

| Apple 类别 | 数据 | Linked | Tracking | 用途 |
|---|---|---|---|---|
| Health | 体重、体脂、训练数据 | 是 | 否 | App Functionality |
| Fitness | 训练记录、容量、动作 | 是 | 否 | App Functionality |
| Name | 昵称、Apple 姓名 | 是 | 否 | App Functionality |
| Phone Number | 手机号 | 是 | 否 | App Functionality |
| Photos or Videos | 体型/饮食/器械照片、视频关键帧 | 是 | 否 | App Functionality |
| Other User Content | 教练对话、备注 | 是 | 否 | App Functionality |
| Coarse Location | 城市天气 | 否 | 否 | App Functionality |
| User ID | 账号 UUID | 是 | 否 | App Functionality |
| Device ID | 随机安装 ID、设备会话 | 是 | 否 | App Functionality |
| Purchase History | StoreKit 交易/订阅台账 | 是 | 否 | App Functionality |
| Product Interaction | 功能使用次数、AI Job | 是 | 否 | App Functionality |
| Other Diagnostic Data | 服务端错误/性能诊断 | 是 | 否 | App Functionality |

`NSPrivacyTracking=false`，当前不接广告/统计/崩溃 SDK。

## 6. 构建与上传

```bash
cd ios
xcodegen generate
xcodebuild -project FitAI.xcodeproj -scheme FitAI \
  -configuration Release -destination "generic/platform=iOS" archive
```

- [ ] `CURRENT_PROJECT_VERSION` 用未使用过的 build number
- [ ] Mac 已登录 Apple Developer、具备 App Store 分发证书
- [ ] Apple Developer 后台开启 HealthKit 与 Sign in with Apple capability
- [ ] 真机验证登录、建档、计划、教练、拍照、订阅、恢复、注销
- [ ] 先内部 TestFlight；外部再提交 Beta App Review

## 7. 当前仍阻塞

- 生产 API 域名/服务器
- 生产 MySQL 迁移
- 短信服务商或密码测试账号
- App Store Connect 订阅商品/协议/沙盒
- App Store Server API Key/p8 + Notifications URL
- 公网隐私政策 URL
- Mac 签名与上传
