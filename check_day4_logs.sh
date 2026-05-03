#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_docker

echo "=== Day 4 — Logs check ==="
compose_status "$ROOT_DIR/day4-logs/docker-compose.yml"
curl -fsS http://localhost:8080/api/health >/dev/null && echo "  ✓ nginx local health endpoint is reachable"
check_logs_query "payment-service errors" "service:payment-service"
check_logs_query "nginx-proxy logs" "service:nginx-proxy"
check_logs_query "retry-service logs" "service:retry-service"
