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
  "tags": ["learning-week:day3-dbm"],
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
  "name": "[Day3] DB Session Spikes - Connection Load",
  "type": "metric alert",
  "query": "avg(last_10m):avg:postgresql.sessions.count{env:learning-week} > 20",
  "message": "Average session count exceeded 20!\n\nPlease inspect the database before changing this threshold.\n\n@slack-dba",
  "tags": ["learning-week:day3-dbm"],
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
  "name": "[Day3] DB Row Volume - Query Volume",
  "type": "metric alert",
  "query": "avg(last_10m):avg:postgresql.rows_returned{env:learning-week} > 700000",
  "message": "Total rows returned is high!\n\nPlease review whether this alert points to an owner.\n\n@slack-dba",
  "tags": ["learning-week:day3-dbm"],
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
  "tags": ["learning-week:day3-dbm"],
  "options": {
    "thresholds": {"critical": 0.90, "warning": 0.85},
    "notify_no_data": false,
    "renotify_interval": 0,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 5
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day3] Orders Reconciliation - No Recent Activity",
  "type": "metric alert",
  "query": "sum(last_5m):sum:postgres_app.orders_reconciled_total{env:learning-week}.as_count() < 1",
  "message": "No orders reconciled in the last 5 minutes!\n\nThe reconciliation job is running and postgres_app.orders_reconciled_total is still reporting points.\nWhy does this monitor not see them?\n\n@slack-dba",
  "tags": ["learning-week:day3-dbm"],
  "options": {
    "thresholds": {"critical": 1},
    "notify_no_data": true,
    "no_data_timeframe": 10,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

# Demo — as_count vs as_rate live comparison
# Starts with as_rate (classic path). During the presentation, edit the query live:
#   1. Change avg -> sum aggregation
#   2. Change .as_rate() -> .as_count() on both metrics
# The monitor value will change on the same data, showing the two evaluation paths.
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day3] [as_count demo] Query Error Rate",
  "type": "metric alert",
  "query": "avg(last_5m):avg:pg_app.queries.errors{env:learning-week}.as_rate() / avg:pg_app.queries.total{env:learning-week}.as_rate() > 0.5",
  "message": "LIVE DEMO — as_rate vs as_count\n\nCurrent state: as_rate path (classic)\n\nWhat Datadog is doing right now:\n  At each timestamp: error_rate / total_rate\n  Then average all per-point results across the window\n  Result: inflated ratio — division happens before aggregation\n\nTo switch to as_count path, edit this monitor query to:\n  avg(last_5m):sum:pg_app.queries.errors{env:learning-week}.as_count() / sum:pg_app.queries.total{env:learning-week}.as_count()\n\nWhat changes:\n  - avg  ->  sum  (aggregator must match as_count)\n  - .as_rate()  ->  .as_count()  (on both metrics)\n\nWhat Datadog will do after the change:\n  Sum all error counts across the window\n  Sum all total counts across the window\n  Divide once at the end — correct error rate\n\nWatch the evaluated value change on the same underlying data.\n\nSee: https://docs.datadoghq.com/monitors/guide/as-count-in-monitor-evaluations/\n\n@slack-dba",
  "tags": ["learning-week:day3-dbm"],
  "options": {
    "thresholds": {"critical": 0.5, "warning": 0.2},
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
