#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_docker

echo "=== Day 1 — APM check ==="
compose_status "$ROOT_DIR/day1-apm/docker-compose.yml"
curl -fsS http://localhost:5000/health >/dev/null && echo "  ✓ flask-store local health endpoint is reachable"
check_metric_query "APM trace metric" "avg:trace.flask.request{env:learning-week}"
check_metric_query "Metric type demo" "avg:metric_types_demo.gauge{env:learning-week}"
check_metric_query "Checkout errors demo" "sum:flask_store.checkout_errors{env:learning-week}.as_count()"
check_metric_query "Monitor concepts demo" "avg:monitor_concepts_demo.request_duration{env:learning-week}"
