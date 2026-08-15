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

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day5-A] Payment Latency",
  "type": "metric alert",
  "query": "avg(last_5m):avg:ecommerce.payment.latency.avg{env:learning-week} > 5",
  "message": "Slow payment detected!\n\nBut which method? Which region? The global view still looks normal...\n\n@slack-payments",
  "tags": ["learning-week:day5-ecommerce"],
  "options": {
    "thresholds": {"critical": 5, "warning": 3},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day5-A] Order Volume",
  "type": "metric alert",
  "query": "sum(last_10m):sum:ecommerce.orders.count{env:learning-week}.as_count() < 5",
  "message": "Order volume dropped!\n\nBut wait... the total still looks OK. Did one specific region or payment method stop?\n\n@slack-business",
  "tags": ["learning-week:day5-ecommerce"],
  "options": {
    "thresholds": {"critical": 5, "warning": 15},
    "notify_no_data": true,
    "no_data_timeframe": 10,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day5-A] Cart Abandonment",
  "type": "metric alert",
  "query": "avg(last_10m):avg:ecommerce.cart.abandonment{env:learning-week} by {region} > 70",
  "message": "High cart abandonment in region {{region.name}}!\n\nThe threshold looks high... and are we mixing all devices together?\n\n@slack-product",
  "tags": ["learning-week:day5-ecommerce"],
  "options": {
    "thresholds": {"critical": 70, "warning": 50},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day5-A] Failed Payments",
  "type": "metric alert",
  "query": "sum(last_5m):sum:ecommerce.failed_payments{env:learning-week} > 50",
  "message": "Failed payments detected!\n\nBut the numbers seem very low... We know roughly 10% of payment attempts fail, but this monitor barely alerts.\nCompare with ecommerce.orders.count and check whether the ratio adds up.\n\n@slack-payments",
  "tags": ["learning-week:day5-ecommerce"],
  "options": {
    "thresholds": {"critical": 50, "warning": 20},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day5-A] Refunds Total",
  "type": "metric alert",
  "query": "avg(last_10m):avg:ecommerce.refunds_varied.gauge_demo{env:learning-week} > 300",
  "message": "Refund total looks high!\n\nBut Finance says this number does not match the refund volume on their dashboard. Which one is right?\n\n@slack-payments",
  "tags": ["learning-week:day5-ecommerce"],
  "options": {
    "thresholds": {"critical": 300, "warning": 150},
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
