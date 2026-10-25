# FitAI Web 预览

这是 FitAI 的**界面与流程预览**，用浏览器打开即可，不需要 iOS 模拟器。

> 它不是真正的 iOS App。真实 App 需要 macOS + Xcode 编译；Windows 无法运行 iOS Simulator。

## 启动

双击 `启动预览.cmd`，或：

```powershell
cd E:\Projects\FitAI\preview
powershell -ExecutionPolicy Bypass -File .\serve.ps1
```

然后打开 <http://127.0.0.1:5173/>。

## 可以看什么

- 建档：身高、体重、三围、器械、目标
- 首页：今日训练、本周完成、饮食入口、AI 复盘、最近训练
- 计划：4 周视图、训练日编辑、加减组数、删除动作
- 教练：对话、快捷问题、疼痛/孕期安全兜底
- 器械：模拟拍照、识别候选、动作详情
- 我的：Pro 订阅页、Apple 健康、提醒、训练偏好、数据导出、注销
- 饮食：热量目标、食物库、按克数计算、每日记录
- 训练：完成组、休息计时、训练总结

## 直接打开某个页面

```
http://127.0.0.1:5173/?tab=home
http://127.0.0.1:5173/?tab=plan
http://127.0.0.1:5173/?tab=coach
http://127.0.0.1:5173/?tab=equipment
http://127.0.0.1:5173/?tab=profile
http://127.0.0.1:5173/?screen=nutrition
http://127.0.0.1:5173/?screen=paywall
```

## 说明

- 数据保存在浏览器 `localStorage`，侧栏「重置演示数据」可清空。
- 订阅、HealthKit、美团、真实 AI 都是模拟交互，不会真的扣款或联网。
- 视觉与文案尽量贴近 iOS 工程，方便先确认产品方向。
