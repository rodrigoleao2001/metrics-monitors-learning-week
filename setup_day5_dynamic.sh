#!/usr/bin/env bash
# Learning Week — Day 5 Dynamic: Full bootstrap
# Installs every dependency and brings up both labs. Safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
COMPOSE_A="$ROOT_DIR/day5-dynamic/lab-a-ecommerce/docker-compose.yml"
COMPOSE_B="$ROOT_DIR/day5-dynamic/lab-b-iot/docker-compose.yml"

_TOTAL_STEPS=13
source "$ROOT_DIR/shared/bootstrap.sh"

echo -e "\n${BOLD}Learning Week — Day 5 Dynamic Labs Setup${NC}"
echo    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_bootstrap

# ── Step 10: Start Lab A (E-commerce) ─────────────────────────────────────────
step "Starting Lab A — E-commerce"
docker compose -f "$COMPOSE_A" up -d --build
docker compose -f "$COMPOSE_A" ps
ok "Lab A containers started"

# ── Step 11: Start Lab B (IoT) ────────────────────────────────────────────────
step "Starting Lab B — IoT"
docker compose -f "$COMPOSE_B" up -d --build
docker compose -f "$COMPOSE_B" ps
ok "Lab B containers started"

# ── Step 12: Wait for both Agents ─────────────────────────────────────────────
step "Waiting for Datadog Agents  (Lab A + Lab B)"
echo "  Lab A:"
wait_for_compose_agent "$COMPOSE_A" "datadog-agent" 90
echo "  Lab B:"
wait_for_compose_agent "$COMPOSE_B" "datadog-agent" 90

# ── Step 13: Create monitors ──────────────────────────────────────────────────
step "Creating Datadog monitors"
chmod +x "$ROOT_DIR/day5-dynamic/lab-a-ecommerce/monitors/create_monitors.sh"
chmod +x "$ROOT_DIR/day5-dynamic/lab-b-iot/monitors/create_monitors.sh"
"$ROOT_DIR/day5-dynamic/lab-a-ecommerce/monitors/create_monitors.sh"
"$ROOT_DIR/day5-dynamic/lab-b-iot/monitors/create_monitors.sh"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  Day 5 — Dynamic labs are up!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Wait 3-5 min for first data to appear in Datadog."
echo ""
echo "  Metrics:          https://app.${DD_SITE}/metric/explorer"
echo "  Lab A monitors:   https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day5-ecommerce"
echo "  Lab B monitors:   https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day5-iot"
echo ""
echo "  Useful metric searches:"
echo "    ecommerce.payment.latency.avg"
echo "    iot.sensor.temperature"
echo ""
echo "  Lab A guide:  $ROOT_DIR/day5-dynamic/lab-a-ecommerce/LAB.md"
echo "  Lab B guide:  $ROOT_DIR/day5-dynamic/lab-b-iot/LAB.md"
echo ""
echo "  To stop:"
echo "    docker compose -f day5-dynamic/lab-a-ecommerce/docker-compose.yml down -v"
echo "    docker compose -f day5-dynamic/lab-b-iot/docker-compose.yml down -v"
echo "    ./day5-dynamic/lab-a-ecommerce/monitors/create_monitors.sh --cleanup"
echo "    ./day5-dynamic/lab-b-iot/monitors/create_monitors.sh --cleanup"
echo ""
