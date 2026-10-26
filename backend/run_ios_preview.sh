#!/usr/bin/env bash
set -euo pipefail

# Local FastAPI backend for iOS simulator / physical-device preview.
# This intentionally uses SQLite so iOS preview does not require MySQL.
# The enterprise admin stack can still run separately with MySQL.
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate

python -m pip install -q -r requirements.txt

export APP_ENV="${APP_ENV:-dev}"
export DATABASE_URL="${DATABASE_URL:-sqlite:///./fitai.db}"
export MEDIA_ROOT="${MEDIA_ROOT:-media}"

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"

echo "FitAI API: http://127.0.0.1:${PORT}/api/v1"
echo "Health:    http://127.0.0.1:${PORT}/health"
echo "LAN:       use http://<this-Mac-LAN-IP>:${PORT}/api/v1 in the iOS Debug server field"
exec python -m uvicorn app.main:app --host "$HOST" --port "$PORT" --reload
