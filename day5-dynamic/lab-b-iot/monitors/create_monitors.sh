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

# Monitor — the single big role-play scenario for Lab B. Four combined,
# verified-live flaws in one monitor, not four separate ones:
#   1. Wrong metric: watches iot.sensor.signal_strength (a gauge), assuming a
#      sensor having trouble would show up as a bad signal value. It would
#      not: the storage-zone dropout is a submission that never happens at
#      all that cycle, so signal_strength is simply absent that cycle too, it
#      never reports a "bad" number to catch. The metric that actually proves
#      data loss is iot.sensor.readings.count, a real count of submissions.
#   2. Wrong tags: the query has no group-by sensor_id, so it watches the
#      whole storage zone as one signal.
#   3. Wrong aggregation/window: even grouped correctly, a long last_15m
#      window smooths a real per-sensor gap into "enough volume over the
#      window."
#   4. Broken config: the threshold (-100) sits below signal_strength's real
#      floor for this zone (random.randint(-95, -60) in the generator), so it
#      is structurally unreachable regardless of the other three fixes, and
#      notify_no_data is false, so even a genuine, correctly-detected gap
#      after the other three are fixed would not page anyone about it.
# Verified live: storage has two sensors, st-01 and st-02, each independently
# missing about 30% of cycles (code: `if zone == storage and random() < 0.30:
# continue`). Over a 30 min window, st-01 reported 11 of 17 possible
# intervals and st-02 reported 10 of 17, real per-sensor gaps, but the
# zone-wide summed total across the same hour never dropped below 1 (9 points,
# min 1, sum 21), the other sensor's volume covers the gap every time.
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day5-B] Storage Sensor Uptime",
  "type": "metric alert",
  "query": "avg(last_15m):avg:iot.sensor.signal_strength{env:learning-week,zone:storage} < -100",
  "message": "Storage zone signal strength looks fine.\n\nThe refrigeration team says they keep losing sensor data in storage, sometimes for stretches at a time, but this monitor has never once fired.\n\n@slack-iot",
  "tags": ["learning-week:day5-iot"],
  "options": {
    "thresholds": {"critical": -100},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

echo ""
echo "=== Lab B monitors created! ==="
echo "Check them at: https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day5-iot"
echo ""
