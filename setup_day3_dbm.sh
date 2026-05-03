#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_docker

echo "=== Day 3 — DBM setup ==="
compose_up "$ROOT_DIR/day3-dbm/docker-compose.yml"
run_monitors "$ROOT_DIR/day3-dbm/monitors/create_monitors.sh"

print_datadog_wait
print_monitor_link "learning-week:day3-dbm"
echo "Screenshot targets:"
echo "  DBM Queries/Samples: env:learning-week, db:learning_week"
echo "  Metrics Explorer: postgresql.database_size or postgresql.sessions.count"
