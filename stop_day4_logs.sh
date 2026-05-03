#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

require_docker
echo "=== Day 4 — stopping log containers ==="
compose_stop "$ROOT_DIR/day4-logs/docker-compose.yml"
echo "Day 4 local services stopped. Datadog monitors/data were kept."
