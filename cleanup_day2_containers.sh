#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

load_learning_week_env
require_kubernetes_tools

echo "=== Day 2 — Containers cleanup ==="
kubectl delete -f "$ROOT_DIR/day2-containers/k8s/missing-tag-app.yaml" --ignore-not-found || true
kubectl delete -f "$ROOT_DIR/day2-containers/k8s/stress-app.yaml" --ignore-not-found || true
kubectl delete -f "$ROOT_DIR/day2-containers/k8s/sample-app.yaml" --ignore-not-found || true
helm uninstall datadog-agent -n datadog 2>/dev/null || true
kubectl delete namespace datadog --ignore-not-found || true
minikube delete -p learning-week-k8s || true
cleanup_monitors "$ROOT_DIR/day2-containers/monitors/create_monitors.sh"
echo "Day 2 Kubernetes resources and monitors removed."
