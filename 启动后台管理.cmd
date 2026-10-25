@echo off
chcp 65001 >nul
title FitAI Admin Launcher
cd /d "%~dp0backend"

if not exist ".venv\Scripts\python.exe" (
  echo [FitAI] 正在创建 Python 虚拟环境...
  python -m venv .venv
  if errorlevel 1 goto :error
  ".venv\Scripts\python.exe" -m pip install -r requirements.txt
  if errorlevel 1 goto :error
)

if not exist ".env" (
  copy ".env.example" ".env" >nul
  echo [FitAI] 已从 .env.example 创建 .env
)

echo [FitAI] 正在启动后台 API 与数据管理页面...
start "FitAI Admin API" ".venv\Scripts\python.exe" -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
timeout /t 3 /nobreak >nul
start "" "http://127.0.0.1:8000/admin"
echo.
echo 数据后台: http://127.0.0.1:8000/admin
echo 默认开发口令: dev-admin-token
echo 生产环境请修改 backend\.env 中的 ADMIN_TOKEN。
echo.
exit /b

:error
echo.
echo 启动失败，请检查 Python、网络和 backend\.env。
pause
exit /b 1
