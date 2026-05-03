#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

require_docker
echo "=== Day 5 — stopping dynamic lab containers ==="
compose_stop "$ROOT_DIR/day5-dynamic/lab-a-ecommerce/docker-compose.yml"
compose_stop "$ROOT_DIR/day5-dynamic/lab-b-iot/docker-compose.yml"
echo "Day 5 local services stopped. Datadog monitors/data were kept."
