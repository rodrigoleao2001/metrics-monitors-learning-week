#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="learning-week-k8s"

echo "=== Day 2 — Teardown ==="

echo "Deleting sample apps..."
kubectl delete -f "$(dirname "$0")/k8s/missing-tag-app.yaml" --ignore-not-found 2>/dev/null || true
kubectl delete -f "$(dirname "$0")/k8s/stress-app.yaml" --ignore-not-found 2>/dev/null || true
kubectl delete -f "$(dirname "$0")/k8s/sample-app.yaml" --ignore-not-found 2>/dev/null || true

echo "Uninstalling Datadog Agent..."
helm uninstall datadog-agent -n datadog 2>/dev/null || true

echo "Deleting minikube cluster..."
minikube delete -p "$CLUSTER_NAME" 2>/dev/null || true

echo "✓ Cleanup complete"
