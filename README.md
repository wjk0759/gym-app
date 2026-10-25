# FitAI（中文暂定名：练途）

![iOS Build](https://github.com/wjk0759/gym-app/actions/workflows/ios-build.yml/badge.svg)
![Backend Tests](https://github.com/wjk0759/gym-app/actions/workflows/backend-tests.yml/badge.svg)

面向中国大陆的 AI 健身教练 iOS App。核心闭环：**建档 → 定目标 → AI 生成计划 → 到点提醒 → 训练记录 → AI 复盘调整**。

> **Windows 上先看效果：** 双击 `preview\启动预览.cmd`，浏览器打开 <http://127.0.0.1:5173/>。这是 Web 界面预览，不是 iOS 模拟器；真实模拟器需要 Mac + Xcode。

> 当前版本：`v0.1.0` 基础工程
> 市场：中国大陆优先
> 形态：SwiftUI 原生 iOS + FastAPI 后端 + PostgreSQL

---

## 这一版已经交付什么

| 交付物 | 位置 | 状态 |
|---|---|---|
| 产品需求文档（P0） | `docs/01-PRD.md` | 完成 |
| 技术架构 | `docs/02-architecture.md` | 完成 |
| 数据模型说明 | `docs/03-data-model.md` | 完成 |
| PostgreSQL 建表脚本 | `db/schema.sql` | 完成 |
| API 契约 | `docs/04-api.md` | 完成 |
| AI 设计（计划 / 记忆 / 识别 / 问答） | `docs/05-ai-design.md` | 完成 |
| 中国区合规清单 | `docs/06-compliance-cn.md` | 完成 |
| 12 周开发路线 | `docs/07-roadmap.md` | 完成 |
| iOS 上手指南（Mac） | `docs/08-ios-setup.md` | 完成 |
| 交付说明与下一步 | `docs/09-handoff.md` | 完成 |
| FastAPI 后端骨架 | `backend/` | 可启动，AI 默认 Mock |
| SwiftUI App 骨架 | `ios/` | 可运行，默认本地 Mock 数据 |

**已经能跑通的产品流程：**

- 首次进入 → 填写档案与目标 → 本地生成 4 周训练计划
- 首页查看今日训练 → 开始训练 → 逐组记录重量/次数 → 休息计时 → 完成
- 训练计划查看、换动作、改组数次数
- AI 教练对话（本地 Mock，含疼痛/伤病安全拦截；可切换远程 AI）
- 训练偏好记忆：删掉的动作会被记住，后续计划尽量避开；计划调整参考完成率与 RPE
- 体型照片分析：拍照获取训练重点，应用到计划；不做体脂/医疗诊断
- 饮食照片识别：拍照估算食物、热量与三大营养素，可改份量/勾选后加入今日饮食
- 器械 Tab：首先展示已添加器械；顶部「添加器械」进入搜索/拍照/相册识别，生成计划时优先使用
- 计划按周推进：首页和提醒进入当前计划周，4 周结束后可生成下一阶段
- 计划版本历史：重新生成或 AI 调整后保留旧版本，可查看和恢复
- 训练保护：0 组不落记录、支持撤销上一组、参考上次重量/次数
- 后台数据管理系统：用户、计划、训练、对话、识别、动作库与操作审计
- 企业级登录：手机验证码、账号密码、微信/QQ OAuth、自动注册、JWT + Refresh Token、会话撤销
- 器械拍照/选图 → 识别候选（本地 Mock / 远程视觉）→ 动作卡片与视频播放
- 饮食计划（本地热量与三餐模板 + 食物库记录）→ 美团跳转占位
- Apple 健康：读取体重、写入完成的训练
- FitAI Pro 订阅页（StoreKit 2，商品 ID 占位）
- 设置每周训练日与提醒时间 → 本地通知
- 档案与训练记录本地持久化

**明确还没做的：** 真实模型输出（需填 API Key）、真实视觉模型、教学视频素材（播放链路已接）、Apple 登录、App Store 订阅商品配置（订阅页已接）、Apple Watch、美团联盟接入、备案材料。

---

## 目录结构

```
FitAI/
├── README.md
├── docs/                    # 产品、架构、合规、路线图
├── preview/                 # Windows 可运行的 Web 界面预览
├── db/schema.sql            # PostgreSQL + pgvector 建表脚本
├── backend/                 # FastAPI 服务（Windows 可直接跑）
│   ├── app/
│   │   ├── main.py
│   │   ├── models.py
│   │   ├── routers/         # profile / plans / workouts / coach / equipment / diet
│   │   ├── services/        # LLM 网关、计划生成、校验、问答、识别
│   │   └── prompts/         # 系统提示词
│   ├── requirements.txt
│   ├── docker-compose.yml
│   └── .env.example
└── ios/                     # SwiftUI 工程
    ├── project.yml          # XcodeGen 配置
    └── FitAI/
        ├── App/
        ├── Core/            # 模型、数据、服务、设计系统
        ├── Features/        # Onboarding / Home / Plan / Workout / Coach / Equipment / Profile
        └── Resources/
```

CI：推送到 GitHub 后，`.github/workflows/ios-build.yml` 会在 macOS runner 上编译 iOS 工程，`.github/workflows/backend-tests.yml` 会跑后端测试。这样即使本地只有 Windows，也能先发现编译错误。

---

## 快速开始（Windows，先跑后端）

```powershell
cd E:\Projects\FitAI\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
uvicorn app.main:app --reload
```

打开 <http://127.0.0.1:8000/docs> 查看接口。

### 数据管理后台

Windows 直接双击项目根目录的：

```text
启动后台管理.cmd
```

或者手动启动后打开：

```text
http://127.0.0.1:8000/admin
```

本地开发默认口令：`dev-admin-token`。生产环境必须修改 `backend/.env` 中的 `ADMIN_TOKEN`，否则后台会按环境配置拒绝访问。

后台当前支持：

- 数据概览：用户、活跃、训练、计划、AI 对话、安全拦截、器械识别
- 用户管理：搜索、查看档案/目标/计划/训练/对话、软注销、恢复、彻底删除、导出 JSON
- 计划管理：查看完整训练日、归档、设为当前计划
- 训练记录：逐组详情、删除
- AI 对话：查看消息、安全拦截筛选、删除
- 器械识别：候选结果、置信度、删除
- 动作库：编辑动作说明、器械和禁忌症
- 教学视频：上传视频/封面、绑定动作、预览、编辑、发布/下架；发布后自动同步到 App 只读接口
- AI 使用：DeepSeek/模型配置、调用量、成功率、延迟、Token、失败原因和三种 Coach Skill 使用情况
- 操作日志：所有后台写操作审计

> 视频文件默认保存在 `backend/media/`，生产环境应配置 `MEDIA_ROOT` 指向数据盘，或替换为 OSS/COS + CDN。视频发布前需要确认版权/教练授权。

> 注意：饮食记录、体型照片分析和器械库目前主要存储在 iOS 本地，后台只能读取已经同步到服务端的数据。要做完整数据管理，下一步需要补这些模块的端到端同步。

### 登录配置

后端默认使用开发短信模式：`POST /auth/phone/send-code` 会返回 `dev_code`，登录页会自动填入。手机号首次验证会自动建号，账号密码首次登录也会自动注册。

`.env` 关键配置：

```ini
JWT_SECRET=请替换为强随机字符串
SMS_PROVIDER=dev
# 或接入短信网关：
# SMS_PROVIDER=webhook
# SMS_WEBHOOK_URL=https://your-sms-gateway.example.com/send

WECHAT_APP_ID=
WECHAT_APP_SECRET=
QQ_APP_ID=
QQ_APP_SECRET=
# 留空时自动使用当前请求域名；生产建议配置公开 HTTPS 域名
OAUTH_CALLBACK_BASE=
```

未配置微信/QQ 密钥时，开发环境会打开模拟授权页验证完整 OAuth 链路；生产环境不会伪造第三方登录。真实一键登录还需要在开放平台配置 AppID、Universal Links/回调，并在 iOS 侧接官方 SDK。

默认使用 SQLite，零依赖启动。要切换到 PostgreSQL：

```powershell
docker compose up -d db
# 修改 .env：DATABASE_URL=postgresql+psycopg://fitai:fitai@localhost:5432/fitai
```

> 首次启动会自动建表并写入动作库。`db/schema.sql` 是生产环境的规范建表脚本。

---

## 快速开始（Mac，跑 iOS）

**Windows 无法编译 iOS。** 需要一台 Mac（或云 Mac），安装 Xcode 16+。

```bash
brew install xcodegen
cd ios
xcodegen generate
open FitAI.xcodeproj
```

在 Xcode 的 Signing & Capabilities 里选择你的 Team，然后选模拟器运行。详细步骤见 `docs/08-ios-setup.md`。

App 默认使用本地 Mock 数据，不依赖后端。启动后端后，在 App 的「我的 → AI 服务」打开远程模式，即可切换为真实接口；请求失败会自动回退本地。要在真机上连本地后端，把 `ios/FitAI/Core/Services/AppConfig.swift` 里的 `apiBaseURL` 改成电脑局域网 IP。

---

## Mock 与真实的边界

| 模块 | 现在 | 接真实服务要做什么 |
|---|---|---|
| 计划生成 | 本地规则引擎（按器械/目标/频率编排） | 在「我的 → AI 服务」打开远程模式，或调后端 `POST /plans/generate` |
| AI 教练 | 关键词回复 + 安全话术 | 打开远程模式后走 `/coach/chat`，失败自动回退本地 |
| 器械识别 | 从动作库随机返回候选 | 打开远程模式后走 `/equipment/scan` 多模态识别 |
| 通知 | `UNUserNotificationCenter` 每周重复提醒 | iOS 26+ 接 AlarmKit 做系统级闹钟样式 |
| 登录 | 本地假登录 | Sign in with Apple + 后端 JWT |
| 支付 | 无 | StoreKit 2 订阅 |
| 饮食/外卖 | 占位接口 | 自建食物库；美团联盟 CPS 需企业资质 |

---

## 上架前必须补齐（中国区）

1. 公司主体、App 备案、ICP 备案
2. 生成式 AI 应用/功能登记（调用已备案模型也要登记），并在 App 内公示模型名称与备案号
3. 隐私政策、敏感个人信息单独同意、账号注销、数据导出
4. 教学视频版权授权链
5. 健康免责声明与安全边界
6. Apple 审核：HealthKit、IAP、医疗建议边界、权限文案

完整清单见 `docs/06-compliance-cn.md`。

---

## 建议的下一步

1. 在 Mac 上把工程跑起来，确认交互方向
2. 申请 DeepSeek / 通义 / 豆包任一 API，填到 `backend/.env`，把计划生成切到真实模型
3. 拍摄或采购第一批 30 个动作的教学视频
4. 注册公司主体，启动 App 备案与 AI 登记
5. 用 TestFlight 找 20 个真实用户验证“计划完成率”

---

## 说明

- 本项目是工程骨架，不是可直接上架的成品。AI 生成的代码需要在 Mac 上编译验证。
- 所有健康建议必须经过规则校验与免责声明，不能替代医生诊断。
- 美团外卖的菜单与营养数据没有公开接口，CPS 只能提供活动/跳转链接，详见 `docs/05-ai-design.md` 与 PRD 的“不做清单”。
