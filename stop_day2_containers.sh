#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/student_day_utils.sh"

require_command minikube
echo "=== Day 2 — stopping minikube cluster ==="
minikube stop -p learning-week-k8s
echo "Day 2 Kubernetes cluster stopped. Datadog monitors/data were kept."
