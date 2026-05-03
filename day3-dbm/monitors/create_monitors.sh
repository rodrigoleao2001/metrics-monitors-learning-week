#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/monitors_utils.sh"

DAY_TAG="learning-week:day3-dbm"

if [ "${1:-}" = "--cleanup" ]; then
    delete_monitors_by_tag "$DAY_TAG"
    exit 0
fi

echo ""
echo "=== Day 3 — DBM: Creating Lab Monitors ==="
echo ""

# Monitor 1
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day3] DB Size - Always Alerting",
  "type": "metric alert",
  "query": "avg(last_5m):avg:postgresql.database_size{env:learning-week} > 1000000",
  "message": "Database size exceeds 1MB!\n\nThis monitor ALWAYS fires. Is any database ever smaller than 1MB?\nWhat does a static size threshold actually tell you? Is growth the real concern?\n\n@slack-dba",
  "tags": ["learning-week:day3-dbm", "difficulty:beginner"],
  "options": {
    "thresholds": {"critical": 1000000, "warning": 500000},
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
  "name": "[Day3] DB Session Spikes - Smoothed Out",
  "type": "metric alert",
  "query": "avg(last_10m):avg:postgresql.sessions.count{env:learning-week} > 20",
  "message": "Average session count exceeded 20!\n\nPlease inspect the database before changing this threshold.\n\n@slack-dba",
  "tags": ["learning-week:day3-dbm", "difficulty:intermediate"],
  "options": {
    "thresholds": {"critical": 20, "warning": 15},
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
  "name": "[Day3] DB Row Volume - All DBs Combined",
  "type": "metric alert",
  "query": "avg(last_10m):avg:postgresql.rows_returned{env:learning-week} > 700000",
  "message": "Total rows returned is high!\n\nPlease review whether this alert points to an owner.\n\n@slack-dba",
  "tags": ["learning-week:day3-dbm", "difficulty:intermediate"],
  "options": {
    "thresholds": {"critical": 700000, "warning": 400000},
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
  "name": "[Day3] DB Connections - Last Resort Alert",
  "type": "metric alert",
  "query": "avg(last_5m):avg:postgresql.percent_usage_connections{env:learning-week} > 0.90",
  "message": "Too many connections!\n\n@slack-dba",
  "tags": ["learning-week:day3-dbm", "difficulty:advanced"],
  "options": {
    "thresholds": {"critical": 0.90, "warning": 0.85},
    "notify_no_data": false,
    "renotify_interval": 0,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

echo ""
echo "=== Day 3 monitors created! ==="
echo "Check them at: https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day3-dbm"
echo ""
