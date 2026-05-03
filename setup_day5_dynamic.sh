#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_docker

echo "=== Day 5 — Dynamic labs setup ==="
compose_up "$ROOT_DIR/day5-dynamic/lab-a-ecommerce/docker-compose.yml"
compose_up "$ROOT_DIR/day5-dynamic/lab-b-iot/docker-compose.yml"
run_monitors "$ROOT_DIR/day5-dynamic/lab-a-ecommerce/monitors/create_monitors.sh"
run_monitors "$ROOT_DIR/day5-dynamic/lab-b-iot/monitors/create_monitors.sh"

print_datadog_wait
print_monitor_link "learning-week:day5-ecommerce"
print_monitor_link "learning-week:day5-iot"
echo "Screenshot targets:"
echo "  Metrics Explorer: ecommerce.payment.latency.avg"
echo "  Metrics Explorer: iot.sensor.temperature"
