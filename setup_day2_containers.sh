#!/usr/bin/env bash
# Learning Week — Day 2 Containers (Kubernetes): Full bootstrap
# Installs every dependency and brings up the lab. Safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"

_TOTAL_STEPS=12
source "$ROOT_DIR/shared/bootstrap.sh"

echo -e "\n${BOLD}Learning Week — Day 2 Containers Setup${NC}"
echo    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_bootstrap

# ── Step 10: Start Kubernetes environment ─────────────────────────────────────
step "Starting Kubernetes environment  (minikube + Helm + sample apps)"
HELM_CACHE_HOME="${HELM_CACHE_HOME:-/tmp/learning-week-helm/cache}" \
HELM_CONFIG_HOME="${HELM_CONFIG_HOME:-/tmp/learning-week-helm/config}" \
HELM_DATA_HOME="${HELM_DATA_HOME:-/tmp/learning-week-helm/data}" \
    bash "$ROOT_DIR/day2-containers/setup.sh"

# ── Step 11: Wait for Datadog Agent pods ─────────────────────────────────────
step "Waiting for Datadog Agent pods"
wait_for_k8s_agent "datadog" "app=datadog-agent" 180

# ── Step 12: Create monitors ──────────────────────────────────────────────────
step "Creating Datadog monitors"
chmod +x "$ROOT_DIR/day2-containers/monitors/create_monitors.sh"
"$ROOT_DIR/day2-containers/monitors/create_monitors.sh"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  Day 2 — Containers lab is up!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Wait 3-5 min for first data to appear in Datadog."
echo ""
echo "  Pods:           kubectl get pods -A"
echo "  Node metrics:   kubectl top nodes"
echo "  Infrastructure: https://app.${DD_SITE}/infrastructure"
echo "  Monitors:       https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day2-containers"
echo ""
echo "  Note: crashloop-app and memory-hog are intentionally unhealthy."
echo ""
echo "  Lab guide:  $ROOT_DIR/day2-containers/LAB.md"
echo ""
echo "  To stop:"
echo "    bash day2-containers/teardown.sh"
echo "    ./day2-containers/monitors/create_monitors.sh --cleanup"
echo ""
