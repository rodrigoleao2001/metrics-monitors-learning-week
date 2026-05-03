#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/monitors_utils.sh"

DAY_TAG="learning-week:day4-logs"

if [ "${1:-}" = "--cleanup" ]; then
    delete_monitors_by_tag "$DAY_TAG"
    exit 0
fi

echo ""
echo "=== Day 4 — Logs: Creating Lab Monitors ==="
echo ""

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day4] Error Log Alert - Catches Everything",
  "type": "log alert",
  "query": "logs(\"error\").index(\"*\").rollup(\"count\").last(\"5m\") > 5",
  "message": "Error logs detected!\n\nBut... is this catching actual problems or just noise?\nHow many different services are matching?\n\n@slack-oncall",
  "tags": ["learning-week:day4-logs", "difficulty:beginner"],
  "options": {
    "thresholds": {"critical": 5, "warning": 3},
    "notify_no_data": false,
    "renotify_interval": 0,
    "enable_logs_sample": true,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day4] Service Error Rate - Alert Storm",
  "type": "log alert",
  "query": "logs(\"status:error\").index(\"*\").rollup(\"count\").by(\"host,service,@region,@level\").last(\"10m\") > 2",
  "message": "Errors detected for {{host.name}} / {{service.name}} / {{region.name}}!\n\nYou're getting LOTS of these alerts. Is that helpful?\n\n@slack-oncall",
  "tags": ["learning-week:day4-logs", "difficulty:intermediate"],
  "options": {
    "thresholds": {"critical": 2, "warning": 1},
    "notify_no_data": false,
    "renotify_interval": 0,
    "enable_logs_sample": true,
    "groupby_simple_monitor": false,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day4] Critical Log Watch - Inbox Flood",
  "type": "log alert",
  "query": "logs(\"status:(error OR critical) service:payment-service\").index(\"*\").rollup(\"count\").last(\"5m\") > 3",
  "message": "Payment service has critical errors!\n\n@slack-oncall @pagerduty-payments @email-team-lead @email-vp-engineering",
  "tags": ["learning-week:day4-logs", "difficulty:intermediate"],
  "options": {
    "thresholds": {"critical": 3},
    "notify_no_data": false,
    "renotify_interval": 10,
    "renotify_statuses": ["alert"],
    "enable_logs_sample": true,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day4] Log Volume - Static Count",
  "type": "log alert",
  "query": "logs(\"*\").index(\"*\").rollup(\"count\").last(\"15m\") > 200",
  "message": "High log volume detected!\n\nIs ALL log volume a problem? Or just certain types?\nShould we count DEBUG logs the same as ERROR logs?\n\n@slack-platform",
  "tags": ["learning-week:day4-logs", "difficulty:advanced"],
  "options": {
    "thresholds": {"critical": 200, "warning": 100},
    "notify_no_data": false,
    "renotify_interval": 0,
    "enable_logs_sample": true,
    "evaluation_delay": 60
  }
}
JSON
create_monitor_from_file "$P"

echo ""
echo "=== Day 4 monitors created! ==="
echo "Check them at: https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day4-logs"
echo ""
