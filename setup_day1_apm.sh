#!/usr/bin/env bash
# Learning Week — Day 1 APM: Full bootstrap
# Installs every dependency and brings up the lab. Safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
COMPOSE_FILE="$ROOT_DIR/day1-apm/docker-compose.yml"

_TOTAL_STEPS=12
source "$ROOT_DIR/shared/bootstrap.sh"

echo -e "\n${BOLD}Learning Week — Day 1 APM Setup${NC}"
echo    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_bootstrap

# ── Step 10: Start containers ─────────────────────────────────────────────────
step "Starting Day 1 containers"
docker compose -f "$COMPOSE_FILE" up -d --build
echo ""
docker compose -f "$COMPOSE_FILE" ps
ok "Containers started"

# ── Step 11: Wait for Agent ───────────────────────────────────────────────────
step "Waiting for Datadog Agent"
wait_for_compose_agent "$COMPOSE_FILE" "datadog-agent" 90

# ── Step 12: Create monitors ──────────────────────────────────────────────────
step "Creating Datadog monitors"
chmod +x "$ROOT_DIR/day1-apm/monitors/create_monitors.sh"
"$ROOT_DIR/day1-apm/monitors/create_monitors.sh"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  Day 1 — APM lab is up!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Wait 3-5 min for first data to appear in Datadog."
echo ""
echo "  Flask app:  http://localhost:5000/health"
echo "  APM:        https://app.${DD_SITE}/apm/services"
echo "  Monitors:   https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day1-apm"
echo "  Metrics:    https://app.${DD_SITE}/metric/explorer"
echo ""
echo "  Lab guide:  $ROOT_DIR/day1-apm/LAB.md"
echo ""
echo "  To stop:"
echo "    docker compose -f day1-apm/docker-compose.yml down -v"
echo "    ./day1-apm/monitors/create_monitors.sh --cleanup"
echo ""
