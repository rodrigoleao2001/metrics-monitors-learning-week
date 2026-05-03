#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../shared/monitors_utils.sh"

DAY_TAG="learning-week:day5-iot"

if [ "${1:-}" = "--cleanup" ]; then
    delete_monitors_by_tag "$DAY_TAG"
    exit 0
fi

echo ""
echo "=== Day 5 — Lab B (IoT): Creating Lab Monitors ==="
echo ""

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day5-B] Farm Temperature - All Normal",
  "type": "metric alert",
  "query": "avg(last_5m):avg:iot.sensor.temperature{env:learning-week} > 40",
  "message": "Average farm temperature is above 40C!\n\nBut... are we averaging ALL zones together?\nWhat is the greenhouse reporting individually?\n\n@slack-operations",
  "tags": ["learning-week:day5-iot", "difficulty:intermediate"],
  "options": {
    "thresholds": {"critical": 40, "warning": 35},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day5-B] Sensor Battery - Will Alert Eventually",
  "type": "metric alert",
  "query": "min(last_10m):min:iot.sensor.battery{env:learning-week} by {sensor_id} < 5",
  "message": "Sensor {{sensor_id.name}} battery is below 5%!\n\nWhen this alert fires, the sensor may already be dead.\nCould we have predicted this earlier?\n\n@slack-iot",
  "tags": ["learning-week:day5-iot", "difficulty:advanced"],
  "options": {
    "thresholds": {"critical": 5, "warning": 10},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day5-B] Sensor Health - All Reporting",
  "type": "metric alert",
  "query": "sum(last_10m):sum:iot.sensor.readings.count{env:learning-week}.as_count() < 10",
  "message": "Low sensor reading volume!\n\nWe are counting total readings. What if one sensor stopped reporting and the others compensated?\n\n@slack-iot",
  "tags": ["learning-week:day5-iot", "difficulty:intermediate"],
  "options": {
    "thresholds": {"critical": 10, "warning": 20},
    "notify_no_data": true,
    "no_data_timeframe": 10,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

echo ""
echo "=== Lab B monitors created! ==="
echo "Check them at: https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day5-iot"
echo ""
