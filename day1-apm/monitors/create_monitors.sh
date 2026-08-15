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
  "name": "[Day1] APM Latency",
  "type": "metric alert",
  "query": "avg(last_5m):avg:trace.flask.request{service:flask-store,env:learning-week} > 1",
  "message": "Average latency is above 1s.\n\nThis monitor looks healthy... but is it really?\n\n@slack-alerts",
  "tags": ["learning-week:day1-apm"],
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
  "tags": ["learning-week:day1-apm"],
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
  "tags": ["learning-week:day1-apm"],
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
  "message": "Throughput dropped below threshold!\n\nWould you want to be paged for this, at this hour, for this reason?\n\n@pagerduty-critical",
  "tags": ["learning-week:day1-apm"],
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

# Monitor 5 — Mission 5: a monitor that is correctly configured
# No planted flaw. This is the "legitimate alert" case: p95, scoped to one
# resource_name, sane window and threshold, all the practice the earlier
# missions argue for. It alerts because /inventory genuinely has a 10% chance
# per request of an extra 1-3s delay (app.py, the inventory handler). The
# mission is to prove the alert is real with trace-level evidence, not to fix
# the monitor.
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day1] APM Inventory Latency",
  "type": "metric alert",
  "query": "avg(last_10m):p95:trace.flask.request{service:flask-store,env:learning-week,resource_name:get_/inventory} > 1",
  "message": "Inventory endpoint p95 latency is above 1s.\n\nCheck the underlying traces before deciding whether this needs a fix.\n\n@slack-alerts",
  "tags": ["learning-week:day1-apm"],
  "options": {
    "thresholds": {"critical": 1, "warning": 0.5},
    "notify_no_data": false,
    "renotify_interval": 0,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 6
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day1] DEMO",
  "type": "metric alert",
  "query": "avg(last_30m):avg:monitor_concepts_demo.request_duration{env:learning-week} by {sim_host} > 1",
  "message": "Host {{sim_host.name}} latency check.\n\nUse this monitor to demo Evaluation Window, Require Full Window, and New Group Delay: a new sim_host joins every 30s throughout the demo run, so you can watch new groups sit in No Data/pending until the configured New Group Delay elapses.\n\n@slack-alerts",
  "tags": ["learning-week:day1-apm"],
  "options": {
    "thresholds": {"critical": 1, "warning": 0.5},
    "notify_no_data": false,
    "renotify_interval": 0,
    "evaluation_delay": 60,
    "require_full_window": true,
    "new_group_delay": 300
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 7
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day1] Checkout Errors",
  "type": "metric alert",
  "query": "sum(last_5m):sum:flask_store.checkout_errors{service:flask-store,env:learning-week} by {session_id}.as_count() > 0",
  "message": "Checkout error detected for session {{session_id.name}}!\n\nHow many separate alert groups is this monitor producing right now, and does this notification tell the on call where the failure sits?\n\n@slack-alerts",
  "tags": ["learning-week:day1-apm"],
  "options": {
    "thresholds": {"critical": 0},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 7b / 7c — Mission 7 composite inputs. These two exist so the mission
# is entirely about building the Composite monitor itself, not about designing
# the component queries. Thresholds are set with headroom above checkout's real
# baseline, verified live on 2026-08-15: p95 latency for get_/checkout runs
# 4.3-5.3s chronically (the endpoint's own uneven delay distribution), and its
# error rate runs 2.8-5.7% chronically (a flat 5% failure chance baked into the
# app). A 5s / 2% split, framed as "normal vs a specific known event," does not
# reproduce against this generator, both signals are noisy all the time, not
# only during a batch job or a deploy, so both thresholds sit above that noise
# band instead so each component reads OK day to day, exactly like the
# "each condition alone should not page" half of the mission. Verified live:
# both queries validate and both currently read OK against real traffic.
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day1] Checkout Latency",
  "type": "metric alert",
  "query": "avg(last_5m):p95:trace.flask.request{service:flask-store,env:learning-week,resource_name:get_/checkout} > 6.5",
  "message": "Checkout p95 latency is above 6.5s, well past its normal 4-5s range.\n\nThis is one input to [Day1] Checkout Composite. It should not page by itself.\n\n@slack-alerts",
  "tags": ["learning-week:day1-apm"],
  "options": {
    "thresholds": {"critical": 6.5, "warning": 6},
    "notify_no_data": false,
    "renotify_interval": 0,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day1] Checkout Error Rate",
  "type": "metric alert",
  "query": "sum(last_10m):(sum:trace.flask.request.errors{service:flask-store,env:learning-week,resource_name:get_/checkout}.as_count() / sum:trace.flask.request.hits{service:flask-store,env:learning-week,resource_name:get_/checkout}.as_count()) * 100 > 15",
  "message": "Checkout error rate is above 15%, well past its normal 3-6% range.\n\nThis is one input to [Day1] Checkout Composite. It should not page by itself.\n\n@slack-alerts",
  "tags": ["learning-week:day1-apm"],
  "options": {
    "thresholds": {"critical": 15, "warning": 10},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 8 — Mission 9: a monitor frozen at its last state
# Flaw: require_full_window is true. When the window is not completely full the
# evaluation is skipped, and a skipped evaluation keeps the previous state rather
# than reporting No Data. The metric pauses 480s in every 1080s, which empties the
# 5 minute window entirely, and the monitor stays OK straight through. Verified by
# control: with require_full_window false the same query goes to No Data during the
# gap, regardless of notify_no_data.
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day1] Catalog Sync",
  "type": "metric alert",
  "query": "avg(last_5m):avg:flask_store.batch_sync_records{env:learning-week,service:flask-store} < 500",
  "message": "Catalog sync processed fewer records than expected.\n\nThe sync feeds product availability. Finance found a failed sync themselves, two days later, while this monitor was green.\n\nWhat is this monitor reporting while its metric is sending nothing?\n\n@slack-alerts",
  "tags": ["learning-week:day1-apm"],
  "options": {
    "thresholds": {"critical": 500},
    "notify_no_data": false,
    "require_full_window": true,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

echo ""
echo "=== Day 1 monitors created! ==="
echo "Check them at: https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day1-apm"
echo ""
