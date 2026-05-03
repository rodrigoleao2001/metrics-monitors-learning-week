#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_kubernetes_tools
require_docker

echo "=== Day 2 — Containers setup ==="
HELM_CACHE_HOME="${HELM_CACHE_HOME:-/tmp/learning-week-helm/cache}" \
HELM_CONFIG_HOME="${HELM_CONFIG_HOME:-/tmp/learning-week-helm/config}" \
HELM_DATA_HOME="${HELM_DATA_HOME:-/tmp/learning-week-helm/data}" \
    bash "$ROOT_DIR/day2-containers/setup.sh"
run_monitors "$ROOT_DIR/day2-containers/monitors/create_monitors.sh"

print_datadog_wait
print_monitor_link "learning-week:day2-containers"
echo "Screenshot targets:"
echo "  Kubernetes / Orchestration: kube_cluster_name:learning-week-k8s"
echo "  Pods: crashloop-app and memory-hog are intentionally unhealthy."
