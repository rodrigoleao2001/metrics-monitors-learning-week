#!/usr/bin/env bash
# Shared utilities for creating Datadog monitors via API

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$ROOT_DIR/.env" ]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
fi

: "${DD_API_KEY:?ERROR: DD_API_KEY not set. Copy .env.example to .env and fill in your keys.}"
: "${DD_APP_KEY:?ERROR: DD_APP_KEY not set. Copy .env.example to .env and fill in your keys.}"
: "${DD_SITE:=datadoghq.com}"

API_BASE="https://api.${DD_SITE}/api/v1"

find_existing_monitor_by_name() {
    local monitor_name="$1"
    local response
    response=$(curl -s -G "${API_BASE}/monitor/search" \
        --data-urlencode "query=${monitor_name}" \
        -H "DD-API-KEY: ${DD_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${DD_APP_KEY}")

    echo "$response" | python3 - "$monitor_name" <<'PY'
import json
import sys

target = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

for monitor in data.get("monitors", []):
    if monitor.get("name") == target:
        print(monitor.get("id", ""))
        break
PY
}

# Matching is by exact monitor name. A monitor that was renamed in the payload
# will not be found under its new name, so this function POSTs a new monitor and
# the old one survives alongside it. After renaming any monitor, run
# ./monitors/create_monitors.sh --cleanup once before creating again.
create_monitor_from_file() {
    local payload_file="$1"
    local name
    name=$(python3 -c "import sys,json; print(json.load(open(sys.argv[1])).get('name','unnamed'))" "$payload_file" 2>/dev/null || echo "unnamed")

    echo "Creating monitor: $name"
    existing_id=$(find_existing_monitor_by_name "$name")
    if [ -n "$existing_id" ]; then
        echo "  ↳ Already exists, skipping (ID: $existing_id)"
        rm -f "$payload_file"
        return
    fi

    response=$(curl -s -w "\n%{http_code}" -X POST "${API_BASE}/monitor" \
        -H "Content-Type: application/json" \
        -H "DD-API-KEY: ${DD_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
        -d @"$payload_file")

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        monitor_id=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id','unknown'))" 2>/dev/null || echo "unknown")
        echo "  ✓ Created (ID: $monitor_id)"
    elif echo "$body" | grep -q "Duplicate of an existing monitor_id"; then
        monitor_id=$(echo "$body" | sed -n 's/.*existing monitor_id:\([0-9]*\).*/\1/p' | head -1)
        if [ -n "$monitor_id" ]; then
            echo "  ↳ Already exists, skipping (ID: $monitor_id)"
        else
            echo "  ↳ Already exists, skipping"
        fi
    else
        echo "  ✗ Failed (HTTP $http_code)"
        echo "  $body" | head -3
    fi

    rm -f "$payload_file"
}

delete_monitors_by_tag() {
    local tag="$1"
    echo "Searching for monitors with tag: $tag"
    response=$(curl -s -X GET "${API_BASE}/monitor/search?query=tag:${tag}" \
        -H "DD-API-KEY: ${DD_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${DD_APP_KEY}")

    monitor_ids=$(echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
monitors = data.get('monitors', [])
for m in monitors:
    print(m['id'])
" 2>/dev/null || true)

    if [ -z "$monitor_ids" ]; then
        echo "  No monitors found with tag: $tag"
        return
    fi

    for mid in $monitor_ids; do
        echo "  Deleting monitor $mid..."
        curl -s -X DELETE "${API_BASE}/monitor/${mid}" \
            -H "DD-API-KEY: ${DD_API_KEY}" \
            -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" > /dev/null
        echo "  ✓ Deleted"
    done
}

new_payload() {
    mktemp /tmp/dd_monitor_XXXXXX
}

echo "Datadog API configured for: ${DD_SITE}"
