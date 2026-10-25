# 本地检查脚本（Windows）
# 用法：powershell -ExecutionPolicy Bypass -File scripts\check.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location (Join-Path $root "backend")

if (-not (Test-Path ".venv")) {
    Write-Host "Creating venv..."
    python -m venv .venv
    .\.venv\Scripts\python.exe -m pip install --quiet --upgrade pip
    .\.venv\Scripts\python.exe -m pip install --quiet -r requirements.txt
}

Write-Host "Compiling..."
.\.venv\Scripts\python.exe -m compileall -q app

Write-Host "Running tests..."
.\.venv\Scripts\python.exe -m pytest -q

Write-Host "Running smoke test..."
$env:PYTHONIOENCODING = "utf-8"
.\.venv\Scripts\python.exe scripts\smoke.py

Write-Host "All checks passed."
