#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../shared/monitors_utils.sh"

DAY_TAG="learning-week:day5-ecommerce"

if [ "${1:-}" = "--cleanup" ]; then
    delete_monitors_by_tag "$DAY_TAG"
    exit 0
fi

echo ""
echo "=== Day 5 — Lab A (E-commerce): Creating Lab Monitors ==="
echo ""

# Monitor — the single big role-play scenario for Lab A. Four combined,
# verified-live flaws in one monitor, not four separate ones:
#   1. Wrong metric type: ecommerce.failed_payments is submitted as a GAUGE
#      (statsd.gauge(..., 1, ...)), so it structurally cannot count discrete
#      events. Verified live: a plain avg reads a flat 1.00 no matter how many
#      failures actually happened in the window.
#   2. Wrong tags: no group-by region/payment_method, so even the undercounted
#      signal is blended across the whole platform.
#   3. Wrong aggregation: avg instead of sum compounds the undercount further.
#   4. Broken config: the threshold (50) is sized for a properly-counted
#      scale that this metric, averaged, can never reach. Verified live over a
#      30 min window: real order volume was 252 with the code's flat 10%
#      failure chance per order (~25 real failures expected), while the plain
#      avg query read 1.00 and an ungrouped sum read only 4-10.
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day5-A] Payment Failure Watch",
  "type": "metric alert",
  "query": "avg(last_10m):avg:ecommerce.failed_payments{env:learning-week} > 50",
  "message": "Payment failure volume looks normal.\n\nCS keeps escalating failed-payment complaints and this monitor has barely moved all week.\n\n@slack-payments",
  "tags": ["learning-week:day5-ecommerce"],
  "options": {
    "thresholds": {"critical": 50, "warning": 20},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

echo ""
echo "=== Lab A monitors created! ==="
echo "Check them at: https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day5-ecommerce"
echo ""
