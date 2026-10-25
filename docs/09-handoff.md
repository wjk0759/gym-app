# 09 · 交付说明与下一步

## 1. 当前完成度

| 模块 | 状态 | 说明 |
|---|---|---|
| 产品文档 | 完成 | PRD、架构、数据模型、API、AI、合规、路线图 |
| 数据库 | 开发完成 | SQLite 开发；PostgreSQL/pgvector 建表脚本已有，生产迁移未上 Alembic |
| 后端 | 可运行 | FastAPI + 认证、计划、训练、教练、器械、视频、饮食、后台、AI 使用 |
| 后端测试 | 通过 | 14 个单测 + 端到端 smoke |
| iOS 工程 | 可编译 | CI macOS 模拟器编译通过；真机安装仍需签名和 Mac |
| iOS 编译 | 已验证 | GitHub Actions iOS Build 通过；未做真机 UI 自动化 |
| 登录 | 已完成基础闭环 | 手机验证码、账号密码、自动注册、忘记密码、修改密码、微信/QQ 模拟 OAuth |
| 真实 AI | 代码已接，未配 Key | 填 `LLM_API_KEY` 后走 DeepSeek；未配置时回退本地规则 |
| AI Skills | 已接 | 健身教练 / 康复师 / 营养师三种 Skill；Pro 会员才调用远程 AI |
| 教学视频 | 后台已完成 | 后台可上传、预览、发布、下架；App 只读已发布视频 |
| 会员 | 页面已完成，商品未配置 | StoreKit 2 UI 已接，`com.fitai.app.pro.*` 需在 App Store Connect 创建 |
| 饮食/外卖 | 基础版 | 热量、三餐、食物记录可用；美团联盟未配置 |
| 器械识别 | 基础版 | 本地 Mock 可用；真实视觉模型未接 |
| 体型分析 | 基础版 | 训练重点建议；真实视觉模型未接，不做医疗诊断 |
| 微信/QQ 登录 | 模拟链路可用 | 真实 AppID/Secret 与原生 SDK 未配置 |
| Apple 登录 | 未完成 | 提审前必须补；中国大陆也建议保留 |

### 1.1 为什么有些功能“像没做完”

1. **外部服务未配置**：DeepSeek Key、StoreKit 商品、微信/QQ AppID、美团联盟、教学视频素材、真实视觉模型。
2. **真机网络配置**：iOS 默认 API 是 `127.0.0.1`，真机必须改成电脑局域网 IP。设置页现在有「服务状态」自检。
3. **Web 预览只是模拟**：预览用于检查界面和流程，不发送真实短信、不调用真实支付/相机/服务端同步。
4. **确实未完成**：Apple 登录、真实视觉、服务端会员收据校验、完整本地数据同步、正式备案/法务材料。

## 2. 现在就能验证的

### Windows：后端

```powershell
cd E:\Projects\FitAI\backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload
```

打开 <http://127.0.0.1:8000/docs>，依次调用：

1. `POST /api/v1/auth/dev-login`
2. `PUT /api/v1/me/profile`
3. `PUT /api/v1/me/goal`
4. `POST /api/v1/plans/generate`
5. `POST /api/v1/coach/chat`，输入“今天练什么？”
6. `POST /api/v1/coach/chat`，输入“胸痛、喘不上气”，应返回 `safety_flag=medical_referral`
7. `POST /api/v1/equipment/scan` 上传一张图片
8. `POST /api/v1/diet/plan`

### Mac：iOS

```bash
brew install xcodegen
cd ios
xcodegen generate
open FitAI.xcodeproj
```

选 Team → 模拟器 → `Cmd + R`。

### GitHub：自动编译

把仓库推到 GitHub 后，`.github/workflows/ios-build.yml` 会自动在 macOS runner 上编译。第一次 push 就能看到真实编译错误，这比等 Mac 到手更快。

## 3. 接真实 DeepSeek

编辑 `backend/.env`：

```ini
LLM_PROVIDER=deepseek
LLM_API_KEY=sk-...
LLM_BASE_URL=https://api.deepseek.com/v1
LLM_MODEL=deepseek-chat
```

> 需要“深度思考/推理”时，把 `LLM_MODEL` 改成 `deepseek-reasoner`。注意：reasoner 更慢、更贵，且对 JSON 输出稳定性要求更高，建议先用 chat 跑通评测集。

重启后端后，`POST /plans/generate` 会走真实模型；失败会自动降级到规则模板，并记录 `ai_jobs.status=fallback`。

## 4. 第一批内容清单（建议 30 个动作）

优先级从高到低：

1. 深蹲、高脚杯深蹲、腿举、罗马尼亚硬拉、箭步蹲
2. 卧推、哑铃卧推、俯卧撑、绳索夹胸
3. 高位下拉、坐姿划船、杠铃划船、单臂哑铃划船、引体向上
4. 哑铃推举、侧平举、面拉
5. 臀推、臀桥
6. 弯举、绳索下压
7. 平板支撑、卷腹、悬垂举腿
8. 划船机、跑步机、波比跳

每个动作需要：

- 15–30 秒竖屏视频（正面 + 侧面）
- 3 张关键帧（起点、最低点、终点）
- 一句常见错误提示
- 授权文件（自制声明或采购合同）

## 5. 合规启动顺序

1. 注册公司主体
2. 注册 Apple Developer（公司账号要 D-U-N-S，预留 2 周）
3. 域名 + ICP 备案
4. App 备案（工信部）
5. 生成式 AI 应用/功能登记（属地网信办）
6. 隐私政策、用户协议、敏感个人信息单独同意
7. 教学视频授权链
8. 提审

详细清单：`docs/06-compliance-cn.md`。

## 6. 已知缺口（按优先级）

| 优先级 | 缺口 | 影响 |
|---|---|---|
| P0 | DeepSeek Key / 真实模型评测 | 当前无 Key 时只能本地规则，AI 使用后台看不到真实调用 |
| P0 | StoreKit 商品未配置 | 无法真实购买/恢复，Pro AI 无法解锁 |
| P0 | 会员权益仅客户端校验 | 直接调用后端可绕过；需 Apple 收据/Server Notification 校验 |
| P0 | Apple 登录未接 | 提供微信/QQ 登录时，App Store 提审通常要求 Sign in with Apple |
| P0 | 账号注销路径被移除 | 之前按产品要求去掉自助删除，但 App Store 5.1.1(v) 与个保法要求需补回人工/自助通道 |
| P0 | 本地数据与服务端未同步 | 饮食、体型分析、器械库后台看不到，跨设备不完整 |
| P1 | 真实视觉模型未接 | 器械、体型、饮食识别仍是 Mock |
| P1 | 教学视频素材/版权未完成 | 上传链路已完成，内容仍需授权素材 |
| P1 | 通知/HealthKit 未真机验证 | 需要签名、真机与权限测试 |
| P2 | 美团联盟未配置 | 不影响核心闭环 |
| P2 | 无 Apple Watch | 体验增强，非必须 |

## 7. 接下来 7 天建议

- Day 1：配置 `LLM_API_KEY`、StoreKit 商品，真机设置局域网 API 地址
- Day 2：在 Mac/云 Mac 上真机跑完整闭环并修交互问题
- Day 3：跑 100 组真实计划评测与 AI Skill 安全集
- Day 4：确认视频素材授权并上传首批 20–30 个动作
- Day 5：补 Apple 登录、服务端会员校验、账号注销通道
- Day 6：做本地数据与服务端同步，补齐后台可见性
- Day 7：找 5 个真实用户试用，锁定 v0.2 范围

## 8. 验收标准（v0.2）

- [x] iOS 在 GitHub Actions 上编译通过
- [ ] 真机完成一次建档 → 生成 → 训练 → 记录 → 调整
- [ ] 真机能连接后端（设置页「服务状态」显示已连接）
- [ ] 通知在锁屏状态按时触发
- [ ] 100 组计划生成 JSON 合法率 ≥95%，禁忌动作 0
- [ ] 40 条红旗症状 100% 触发安全兜底
- [ ] 器械识别 Top-3 命中率 ≥85%
- [ ] 隐私政策、免责声明、账号注销通道可用
- [ ] 至少 5 位真实用户完成首次训练
