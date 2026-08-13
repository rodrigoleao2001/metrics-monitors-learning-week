#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_docker

echo "=== Day 5 — Dynamic labs check ==="
compose_status "$ROOT_DIR/day5-dynamic/lab-a-ecommerce/docker-compose.yml"
compose_status "$ROOT_DIR/day5-dynamic/lab-b-iot/docker-compose.yml"
check_metric_query "E-commerce latency" "avg:ecommerce.payment.latency.avg{env:learning-week}"
check_metric_query "E-commerce orders" "sum:ecommerce.orders.count{env:learning-week}.as_count()"
check_metric_query "E-commerce refunds gauge" "avg:ecommerce.refunds_varied.gauge_demo{env:learning-week}"
check_metric_query "E-commerce refunds count" "sum:ecommerce.refunds_varied.count_demo{env:learning-week}.as_count()"
check_metric_query "E-commerce refunds histogram" "avg:ecommerce.refunds_varied.histogram_demo.avg{env:learning-week}"
check_metric_query "IoT temperature" "avg:iot.sensor.temperature{env:learning-week}"
check_metric_query "IoT battery" "avg:iot.sensor.battery{env:learning-week}"
