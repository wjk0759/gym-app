[CmdletBinding()]
param(
    [string]$ListenHost = "0.0.0.0",
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$envPath = Join-Path $root ".env"

if (-not (Test-Path $envPath)) {
    throw "backend/.env not found. Create it from .env.example first."
}

$dbLine = Get-Content $envPath |
    Where-Object { $_ -match '^\s*DATABASE_URL\s*=' } |
    Select-Object -First 1

if (-not $dbLine) {
    throw "DATABASE_URL is missing from backend/.env."
}

if ($dbLine -notmatch ':3307/') {
    $safe = $dbLine -replace '://[^:]+:[^@]+@', '://***:***@'
    throw "DATABASE_URL must point to the dedicated MySQL on port 3307. Current: $safe"
}

if (-not (Test-NetConnection 127.0.0.1 -Port 3307 -InformationLevel Quiet)) {
    Write-Warning "MySQL 3307 is not listening. Run: cd deploy/admin; docker compose up -d mysql"
}

$python = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    throw "Python venv not found at backend/.venv."
}

Write-Host "FitAI backend listening on ${ListenHost}:${Port} (MySQL 3307)"
Write-Host "Local: http://127.0.0.1:${Port}"
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike '127.*' -and
        $_.IPAddress -notlike '169.254.*'
    } |
    ForEach-Object {
        Write-Host "LAN:   http://$($_.IPAddress):${Port}  ($($_.InterfaceAlias))"
        Write-Host "API:   http://$($_.IPAddress):${Port}/api/v1"
    }

Push-Location $root
try {
    & $python -m uvicorn app.main:app --host $ListenHost --port $Port
} finally {
    Pop-Location
}
