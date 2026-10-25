# FitAI（中文暂定名：练途）

面向中国大陆的 AI 健身教练 iOS App。核心闭环：**建档 → 定目标 → AI 生成计划 → 到点提醒 → 训练记录 → AI 复盘调整**。

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
- AI 教练对话（本地 Mock，含疼痛/伤病安全拦截）
- 器械拍照/选图 → 识别候选（Mock）→ 动作卡片
- 设置每周训练日与提醒时间 → 本地通知
- 档案与训练记录本地持久化

**明确还没做的：** 真实大模型调用、真实器械识别、教学视频、Apple 登录、订阅支付、HealthKit、Apple Watch、饮食计划、美团外卖跳转、备案材料。

---

## 目录结构

```
FitAI/
├── README.md
├── docs/                    # 产品、架构、合规、路线图
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

App 默认使用本地 Mock 数据，不依赖后端。要在真机上连本地后端，把 `ios/FitAI/Core/Services/AppConfig.swift` 里的 `apiBaseURL` 改成电脑局域网 IP，并打开 `useRemoteAI`。

---

## Mock 与真实的边界

| 模块 | 现在 | 接真实服务要做什么 |
|---|---|---|
| 计划生成 | 本地规则引擎（按器械/目标/频率编排） | 后端 `POST /plans/generate` 接已备案大模型，输出 JSON 后过校验器 |
| AI 教练 | 关键词回复 + 安全话术 | 后端 RAG + 流式输出 + 输入输出审核 |
| 器械识别 | 从动作库随机返回候选 | 接多模态模型 + 自建器械库 + 低置信度转人工确认 |
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
