#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/monitors_utils.sh"

DAY_TAG="learning-week:day1-apm"

if [ "${1:-}" = "--cleanup" ]; then
    delete_monitors_by_tag "$DAY_TAG"
    exit 0
fi

echo ""
echo "=== Day 1 — APM: Creating Lab Monitors ==="
echo ""

# Monitor 1
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day1] APM Latency - All Good",
  "type": "metric alert",
  "query": "avg(last_5m):avg:trace.flask.request{service:flask-store,env:learning-week} > 1",
  "message": "Average latency is above 1s.\n\nThis monitor looks healthy... but is it really?\n\n@slack-alerts",
  "tags": ["learning-week:day1-apm", "difficulty:beginner"],
  "options": {
    "thresholds": {"critical": 1, "warning": 0.5},
    "notify_no_data": false,
    "renotify_interval": 0,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 2
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day1] APM Spike Detector",
  "type": "metric alert",
  "query": "avg(last_15m):p95:trace.flask.request{service:flask-store,env:learning-week}.rollup(avg, 600) > 2",
  "message": "P95 latency spike detected!\n\nBut wait... are we really catching spikes with this configuration?\n\n@slack-alerts",
  "tags": ["learning-week:day1-apm", "difficulty:intermediate"],
  "options": {
    "thresholds": {"critical": 2, "warning": 1.5},
    "notify_no_data": false,
    "renotify_interval": 0,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 3
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day1] APM Error Surge",
  "type": "metric alert",
  "query": "sum(last_10m):sum:trace.flask.request.errors{service:flask-store,env:learning-week}.as_count() > 100",
  "message": "High error count across the service!\n\nIs this the best way to detect which endpoint is failing?\n\n@slack-alerts",
  "tags": ["learning-week:day1-apm", "difficulty:intermediate"],
  "options": {
    "thresholds": {"critical": 100, "warning": 50},
    "notify_no_data": false,
    "renotify_interval": 0,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 4
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day1] APM Throughput Alert",
  "type": "metric alert",
  "query": "sum(last_5m):sum:trace.flask.request.hits{service:flask-store,env:learning-week}.as_count() < 10",
  "message": "Throughput dropped below threshold!\n\nIs a static threshold the right approach for traffic volume?\n\n@pagerduty-critical",
  "tags": ["learning-week:day1-apm", "difficulty:advanced"],
  "options": {
    "thresholds": {"critical": 10, "warning": 50},
    "notify_no_data": true,
    "no_data_timeframe": 5,
    "renotify_interval": 0,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

echo ""
echo "=== Day 1 monitors created! ==="
echo "Check them at: https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day1-apm"
echo ""
