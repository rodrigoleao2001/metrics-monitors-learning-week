#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_docker

echo "=== Day 1 — APM setup ==="
compose_up "$ROOT_DIR/day1-apm/docker-compose.yml"
run_monitors "$ROOT_DIR/day1-apm/monitors/create_monitors.sh"

print_datadog_wait
print_monitor_link "learning-week:day1-apm"
echo "Screenshot targets:"
echo "  Metrics Summary: trace.flask.request or metric_types_demo.gauge"
echo "  APM Services: service:flask-store, env:learning-week"
