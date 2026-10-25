$port = 5173
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$listening = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue

if (-not $listening) {
    Start-Process -FilePath "python" `
        -ArgumentList "-m", "http.server", $port, "--bind", "127.0.0.1" `
        -WorkingDirectory $root `
        -WindowStyle Hidden
    Start-Sleep -Seconds 1
}

Start-Process "http://127.0.0.1:$port/"
