#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_docker

echo "=== Day 5 — Dynamic labs cleanup ==="
compose_cleanup "$ROOT_DIR/day5-dynamic/lab-a-ecommerce/docker-compose.yml"
compose_cleanup "$ROOT_DIR/day5-dynamic/lab-b-iot/docker-compose.yml"
cleanup_monitors "$ROOT_DIR/day5-dynamic/lab-a-ecommerce/monitors/create_monitors.sh"
cleanup_monitors "$ROOT_DIR/day5-dynamic/lab-b-iot/monitors/create_monitors.sh"
echo "Day 5 local resources and monitors removed."
