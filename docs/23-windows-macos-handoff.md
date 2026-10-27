# Windows 已完成 / Mac 与外部资源待办

> 2026-10-27 · 用于把可以在这台 Windows 上完成的工作，和必须去 Mac/Apple/外部后台完成的工作分开。

## 一、Windows 已完成

### iOS 代码

- 计划：1/3/5 分化、每周 1–7 练、30/45/60/90/120 分钟
- 计划动作严格按已选器械生成
- 4 周训练日期调整
- 独立数据复盘页
- 女性经期区间与轻量/休息模式
- 首页目标卡、身体打卡、训练/饮食双卡
- 身体指标时间线
- 资料保存后自动重排计划
- 教练拍照与照片消息
- 教练结合经期和实际排期回答
- 膳食纤维目标、食物记录和复盘
- 训练记录自动上报 FastAPI，支持编辑、删除墓碑、跨设备拉取与离线重试
- 训练完成后生成服务端周复盘，首页展示结论与行动建议；通知开启时发本地提醒
- 账号注销入口
- Sign in with Apple 客户端/后端代码链路
- 修复修改开发服务器地址后 `APIClient` 仍使用旧地址的问题
- Debug 专用「跳过 Pro 限制」开关，方便预览 DeepSeek

### 后端

- 远程计划接口接收 `split`，模板和 LLM 都使用用户选择的分化
- Apple identity token 校验接口 `/api/v1/auth/apple/login`
- 注销账号时撤销全部 refresh session
- SQLite 自动补 `apple_sub` 字段
- 16 个后端测试通过；API 冒烟覆盖训练记录创建、编辑、拉取与删除
- iOS Build CI 通过

## 二、Mac / Apple 后台才能完成

### Apple 登录

- [ ] 在 Apple Developer 为 `com.fitai.app` 开启 Sign in with Apple
- [ ] 在 Xcode 选择正确 Team，确认 `FitAI.entitlements` 生效
- [ ] 真机验证 Apple 登录、首次姓名/邮箱授权
- [ ] 正式环境确认 `APPLE_CLIENT_ID` 与 Bundle ID / Service ID 一致

### StoreKit 与会员

- [ ] App Store Connect 创建 `com.fitai.app.pro.monthly` / `yearly`
- [ ] 添加 StoreKit 本地测试配置
- [ ] 真机验证购买、恢复、退款、续订
- [ ] 实现 Apple App Store Server API 收据校验
- [ ] 服务端保存 Pro 权益与到期时间
- [ ] 接入 App Store Server Notifications V2

### 真机验收

- [ ] 在 iPhone 上连接局域网后端，允许本地网络权限
- [ ] 相机、相册、通知、HealthKit 权限
- [ ] 锁屏训练提醒
- [ ] APNs 远程推送、设备 token 注册与服务端定时复盘
- [ ] Apple 健康写入与读取
- [ ] StoreKit 商品购买/恢复
- [ ] 离线完成训练后恢复网络自动补传
- [ ] 低电量、后台切换、网络切换测试

## 三、外部服务与内容

- [x] DeepSeek `LLM_API_KEY`：已写入 `backend/.env`，健康检查显示 `llm: deepseek-chat`
- [ ] 真实视觉模型 Key 与供应商（器械/体型/饮食）
- [ ] 真实短信网关
- [ ] 微信开放平台 AppID/Secret
- [ ] QQ 互联 AppID/Secret
- [ ] 美团联盟资质与推广位
- [ ] 30 个动作的授权教学视频和封面
- [ ] 真实计划评测集：100 组计划、红旗症状、识别 Top-3
- [ ] App 备案、ICP、生成式 AI 登记、隐私政策正式 URL
- [ ] 内容审核、未成年人限制、数据导出/删除审计

## 四、仍未完成的代码项

- [x] 饮食记录服务器同步
- [x] 身体围度/体成分历史服务器同步
- [x] 器械库服务器同步
- [x] 训练记录更新/删除的服务端同步
- [x] 训练记录跨设备拉取与离线删除墓碑
- [x] 注销账号 15 天冷静期后的定时清除任务
- [x] 训练后主动周复盘（客户端前台触发 + 本地通知）
- [ ] APNs 远程推送与生产定时调度
- [ ] 历史重复 generic preference 记忆清理脚本（本地 SQLite 已执行，生产需运行）
- [ ] 服务端 Pro 收据校验与权益强制
- [ ] 远程教练真实视觉分析
- [ ] MySQL 生产数据迁移与后台 Docker 部署验收
