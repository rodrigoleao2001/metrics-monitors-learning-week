#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_docker

echo "=== Day 3 — DBM check ==="
compose_status "$ROOT_DIR/day3-dbm/docker-compose.yml"
docker exec postgres-dbm pg_isready -U postgres -d learning_week
check_metric_query "Postgres database size" "avg:postgresql.database_size{env:learning-week}"
check_metric_query "Postgres sessions" "avg:postgresql.sessions.count{env:learning-week}"
check_metric_query "Postgres orders reconciled" "sum:postgres_app.orders_reconciled_total{env:learning-week}.as_count()"
check_metric_query "App query total (DogStatsD)" "sum:pg_app.queries.total{env:learning-week}.as_count()"
check_metric_query "App query errors (DogStatsD)" "sum:pg_app.queries.errors{env:learning-week}.as_count()"
