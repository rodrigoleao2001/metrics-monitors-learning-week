#!/usr/bin/env bash
# Shared helpers for the Learning Week daily student scripts.

set -euo pipefail

lw_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

ROOT_DIR="$(lw_root)"

load_learning_week_env() {
    if [ -f "$ROOT_DIR/.env" ]; then
        set -a
        source "$ROOT_DIR/.env"
        set +a
    else
        echo "ERROR: .env not found at $ROOT_DIR/.env"
        echo "Copy .env.example to .env and add your Datadog API and APP keys."
        exit 1
    fi

    : "${DD_API_KEY:?ERROR: DD_API_KEY not set in .env}"
    : "${DD_APP_KEY:?ERROR: DD_APP_KEY not set in .env}"
    : "${DD_SITE:=datadoghq.com}"
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd is not installed or not in PATH."
        exit 1
    fi
}

require_docker() {
    require_command docker
    if ! docker info >/dev/null 2>&1; then
        echo "ERROR: Docker is not running. Start Docker Desktop, then run this script again."
        exit 1
    fi
}

require_kubernetes_tools() {
    require_command docker
    require_command minikube
    require_command kubectl
    require_command helm
}

compose_up() {
    local compose_file="$1"
    docker compose -f "$compose_file" up -d --build
}

compose_stop() {
    local compose_file="$1"
    if [ -f "$compose_file" ]; then
        docker compose -f "$compose_file" stop
    fi
}

compose_cleanup() {
    local compose_file="$1"
    if [ -f "$compose_file" ]; then
        docker compose -f "$compose_file" down -v
    fi
}

compose_status() {
    local compose_file="$1"
    docker compose -f "$compose_file" ps
}

run_monitors() {
    local monitor_script="$1"
    bash "$monitor_script"
}

cleanup_monitors() {
    local monitor_script="$1"
    bash "$monitor_script" --cleanup
}

print_datadog_wait() {
    echo ""
    echo "Wait 3-5 minutes for fresh data to appear in Datadog."
}

print_monitor_link() {
    local tag="$1"
    echo "Monitors: https://app.${DD_SITE}/monitors/manage?q=tag:${tag}"
}

check_metric_query() {
    local label="$1"
    local query="$2"
    python3 - "$label" "$query" <<'PY'
import json
import os
import sys
import time
import urllib.parse
import urllib.request

label, query = sys.argv[1], sys.argv[2]
site = os.environ.get("DD_SITE", "datadoghq.com")
headers = {
    "DD-API-KEY": os.environ["DD_API_KEY"],
    "DD-APPLICATION-KEY": os.environ["DD_APP_KEY"],
}
now = int(time.time())
params = urllib.parse.urlencode({"from": now - 1800, "to": now, "query": query})
url = f"https://api.{site}/api/v1/query?{params}"
try:
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=20) as resp:
        data = json.loads(resp.read().decode())
    series = data.get("series") or []
    points = sum(len(s.get("pointlist") or []) for s in series)
    if series and points:
        print(f"  ✓ {label}: data found ({len(series)} series, {points} points)")
    else:
        print(f"  ! {label}: no data yet. Wait a few minutes and retry.")
except Exception as exc:
    print(f"  ! {label}: Datadog query failed: {exc}")
PY
}

check_logs_query() {
    local label="$1"
    local query="$2"
    python3 - "$label" "$query" <<'PY'
import json
import os
import sys
import urllib.request

label, query = sys.argv[1], sys.argv[2]
site = os.environ.get("DD_SITE", "datadoghq.com")
headers = {
    "DD-API-KEY": os.environ["DD_API_KEY"],
    "DD-APPLICATION-KEY": os.environ["DD_APP_KEY"],
    "Content-Type": "application/json",
}
body = {
    "filter": {"from": "now-30m", "to": "now", "query": query},
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
