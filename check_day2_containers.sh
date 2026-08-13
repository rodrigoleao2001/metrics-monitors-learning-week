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
if kubectl get replicaset payments-worker -n default >/dev/null 2>&1; then
    echo "  ✓ payments-worker ReplicaSet exists"
else
    echo "  ! payments-worker ReplicaSet not found: re-run day2-containers/setup.sh"
fi
check_metric_query "Kubernetes CPU" "avg:container.cpu.usage{kube_cluster_name:learning-week-k8s}"
check_metric_query "Kubernetes restarts" "avg:kubernetes_state.container.restarts{kube_cluster_name:learning-week-k8s}"
check_metric_query "Kubernetes CPU by deployment" "avg:container.cpu.usage{kube_cluster_name:learning-week-k8s} by {kube_deployment}"
check_metric_query "HPA desired replicas" "avg:kubernetes_state.hpa.desired_replicas{kube_cluster_name:learning-week-k8s}"
check_metric_query "Node CPU requests" "avg:kubernetes.cpu.requests{kube_cluster_name:learning-week-k8s} by {host}"
check_metric_query "Deployment replicas available" "avg:kubernetes_state.deployment.replicas_available{kube_cluster_name:learning-week-k8s}"
check_metric_query "Deployment replicas updated" "avg:kubernetes_state.deployment.replicas_updated{kube_cluster_name:learning-week-k8s}"
if kubectl get hpa cpu-stress-hpa -n default >/dev/null 2>&1; then
    echo "  ✓ cpu-stress-hpa HPA exists"
else
    echo "  ! cpu-stress-hpa HPA not found: re-run day2-containers/setup.sh"
fi
if kubectl get deployment rollout-stall -n default >/dev/null 2>&1; then
    echo "  ✓ rollout-stall deployment exists"
else
    echo "  ! rollout-stall deployment not found: re-run day2-containers/setup.sh"
fi
