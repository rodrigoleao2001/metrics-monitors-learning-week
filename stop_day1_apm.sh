#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

require_docker
echo "=== Day 1 — stopping local containers ==="
compose_stop "$ROOT_DIR/day1-apm/docker-compose.yml"
echo "Day 1 local services stopped. Datadog monitors/data were kept."
