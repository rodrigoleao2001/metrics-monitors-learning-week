#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_docker

echo "=== Day 4 — Logs setup ==="
compose_up "$ROOT_DIR/day4-logs/docker-compose.yml"
run_monitors "$ROOT_DIR/day4-logs/monitors/create_monitors.sh"

print_datadog_wait
print_monitor_link "learning-week:day4-logs"
echo "Screenshot targets:"
echo "  Logs Explorer: service:payment-service status:error"
echo "  Logs Explorer: service:nginx-proxy"
