# iOS 预览连不上后端

iOS 提示：

> 无法连接服务端：请确认后端已启动，并在 Debug 构建中填写正确的局域网 API 地址。

这不是 iOS 网络权限的问题，绝大多数情况是下面三种之一：

1. FastAPI 没有启动；
2. iOS 模拟器/真机指向的地址不对；
3. 后端只监听了 `127.0.0.1`，手机或另一台电脑访问不到。

## 先判断后端在哪里运行

| 场景 | iOS 里应填的地址 |
|---|---|
| 后端跑在 Mac 本机，iOS Simulator | `http://127.0.0.1:8000/api/v1` |
| 后端跑在 Mac 本机，真机 iPhone | `http://<Mac 局域网 IP>:8000/api/v1` |
| 后端跑在 Windows/另一台电脑，iOS Simulator 或真机 | `http://<那台电脑局域网 IP>:8000/api/v1` |

注意地址必须带 `/api/v1`，例如：

```text
http://192.168.1.4:8000/api/v1
```

## 方案 A：在 Mac 本机启动后端（推荐先用这个）

在 Mac 的仓库根目录执行：

```bash
bash backend/run_ios_preview.sh
```

这个脚本会：

- 创建 `backend/.venv`；
- 安装后端依赖；
- 使用 SQLite，不要求 Mac 上安装 MySQL；
- 监听 `0.0.0.0:8000`，真机也能访问。

看到 `Uvicorn running on http://0.0.0.0:8000` 后，在 Mac 浏览器打开：

<http://127.0.0.1:8000/health>

应返回类似：

```json
{"status":"ok","env":"dev","llm":"mock","vision":"mock","meituan":"not_configured"}
```

然后：

- iOS Simulator：登录页默认 `http://127.0.0.1:8000/api/v1`，直接登录；
- iPhone 真机：点登录页底部「开发服务器」，填写 Mac 的局域网地址。

Mac 局域网 IP：

```bash
ipconfig getifaddr en0
# 或
ipconfig getifaddr en1
```

## 方案 B：后端在 Windows，Mac 访问

Windows 上运行：

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
$env:DATABASE_URL="sqlite:///./fitai.db"
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

然后用 Windows 的局域网 IP（例如 `192.168.1.4`）：

```text
http://192.168.1.4:8000/api/v1
```

需要确认：

1. Mac 和 Windows 在同一个 Wi-Fi/局域网；
2. Windows 防火墙允许 Python 或 TCP 8000 入站；
3. 后端监听的是 `0.0.0.0`，不是默认的 `127.0.0.1`。

先在 Mac 浏览器打开 `http://192.168.1.4:8000/health` 验证，再填到 iOS。

## 修改 iOS 的后端地址

必须是 **Debug 构建**。登录页底部有「开发服务器」入口：

```text
开发服务器: http://127.0.0.1:8000/api/v1
```

点进去填写，例如：

```text
http://192.168.1.4:8000/api/v1
```

点保存后重新登录。若之前填错过，可以点「恢复默认」再重新填写。

## 不要使用 MySQL 配置启动 iOS 预览

仓库的 `backend/.env.example` 是给「后台 MySQL 联调」用的：

```env
DATABASE_URL=mysql+pymysql://fitai:fitai@127.0.0.1:3306/fitai?charset=utf8mb4
```

如果 Mac 没有 MySQL，复制这个 `.env.example` 后启动会直接失败，表面看起来就是「服务器没启动」。iOS 预览只需要 SQLite：

```env
DATABASE_URL=sqlite:///./fitai.db
```

或者直接使用上面的 `run_ios_preview.sh`，它已经把 SQLite 设置好了。

## 还是连不上时按顺序排查

```bash
# 1. 后端进程和端口
lsof -nP -iTCP:8000 -sTCP:LISTEN

# 2. 本机健康检查
curl http://127.0.0.1:8000/health

# 3. 局域网健康检查（替换成实际 IP）
curl http://192.168.1.4:8000/health

# 4. 看后端启动日志
bash backend/run_ios_preview.sh
```

如果第 2 步成功、第 3 步失败，问题在监听地址或防火墙；如果两步都失败，先解决后端启动。

## 与 MySQL 后台的关系

- `backend/run_ios_preview.sh` 只启动 App API，使用 SQLite；
- `admin-server` + MySQL 是后台管理控制面，和 iOS 预览不是同一条启动链路；
- 需要同时验证后台时，再按 `deploy/admin/README.md` 启动 MySQL 和 admin-server。
