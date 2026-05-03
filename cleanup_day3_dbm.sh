#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_docker

echo "=== Day 3 — DBM cleanup ==="
compose_cleanup "$ROOT_DIR/day3-dbm/docker-compose.yml"
cleanup_monitors "$ROOT_DIR/day3-dbm/monitors/create_monitors.sh"
echo "Day 3 local resources and monitors removed."
