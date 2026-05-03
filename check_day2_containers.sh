#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_kubernetes_tools

echo "=== Day 2 — Containers check ==="
minikube status -p learning-week-k8s
kubectl get pods -n datadog
kubectl get pods -n default
check_metric_query "Kubernetes CPU" "avg:container.cpu.usage{kube_cluster_name:learning-week-k8s}"
check_metric_query "Kubernetes restarts" "avg:kubernetes_state.container.restarts{kube_cluster_name:learning-week-k8s}"
