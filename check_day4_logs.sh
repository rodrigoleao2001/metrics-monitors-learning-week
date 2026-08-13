#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_docker

# Same output contract as check_logs_query, with a caller-supplied timeframe for
# signals that need a wider window than the shared helper's fixed 30 minutes.
check_logs_query_window() {
    local label="$1"
    local query="$2"
    local timeframe="$3"
    python3 - "$label" "$query" "$timeframe" <<'PY'
import json
import os
import sys
import urllib.request

label, query, timeframe = sys.argv[1], sys.argv[2], sys.argv[3]
site = os.environ.get("DD_SITE", "datadoghq.com")
headers = {
    "DD-API-KEY": os.environ["DD_API_KEY"],
    "DD-APPLICATION-KEY": os.environ["DD_APP_KEY"],
    "Content-Type": "application/json",
}
body = {
    "filter": {"from": timeframe, "to": "now", "query": query},
    "page": {"limit": 1},
}
url = f"https://api.{site}/api/v2/logs/events/search"
try:
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = json.loads(resp.read().decode())
    events = len(data.get("data") or [])
    if events:
        print(f"  ✓ {label}: logs found")
    else:
        print(f"  ! {label}: no logs yet. Wait a few minutes and retry.")
except Exception as exc:
    print(f"  ! {label}: Datadog log query failed: {exc}")
PY
}

echo "=== Day 4 — Logs check ==="
compose_status "$ROOT_DIR/day4-logs/docker-compose.yml"
curl -fsS http://localhost:8080/api/health >/dev/null && echo "  ✓ nginx local health endpoint is reachable"
check_logs_query "payment-service errors" "service:payment-service"
check_logs_query "nginx-proxy logs" "service:nginx-proxy"
check_logs_query "retry-service logs" "service:retry-service"
check_logs_query "payment gateway timeouts" "status:error service:payment-service @error_type:TimeoutError"
check_logs_query_window "critical log events" "status:critical container_name:log-generator-app" "now-4h"
