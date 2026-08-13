#!/usr/bin/env bash
# Learning Week — Day 4 Logs: Full bootstrap
# Installs every dependency and brings up the lab. Safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR"
COMPOSE_FILE="$ROOT_DIR/day4-logs/docker-compose.yml"

_TOTAL_STEPS=12
source "$ROOT_DIR/shared/bootstrap.sh"

echo -e "\n${BOLD}Learning Week — Day 4 Logs Setup${NC}"
echo    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_bootstrap

# ── Step 10: Start containers ─────────────────────────────────────────────────
step "Starting Day 4 containers  (nginx + log-generator + retry-service spammer)"
docker compose -f "$COMPOSE_FILE" up -d --build
echo ""
docker compose -f "$COMPOSE_FILE" ps
ok "Containers started"

# ── Step 11: Wait for Agent ───────────────────────────────────────────────────
step "Waiting for Datadog Agent"
wait_for_compose_agent "$COMPOSE_FILE" "datadog-agent" 90

# ── Step 12: Create monitors ──────────────────────────────────────────────────
step "Creating Datadog monitors"
chmod +x "$ROOT_DIR/day4-logs/monitors/create_monitors.sh"
"$ROOT_DIR/day4-logs/monitors/create_monitors.sh"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  Day 4 — Logs lab is up!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Wait 3-5 min for first logs to appear in Datadog."
echo ""
echo "  nginx:      http://localhost:8080"
echo "  Logs:       https://app.${DD_SITE}/logs?query=env%3Alearning-week"
echo "  Monitors:   https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day4-logs"
echo ""
echo "  Useful log queries:"
echo "    service:nginx-proxy status:error"
echo "    service:retry-service"
echo "    service:log-generator"
echo ""
echo "  Lab guide:  $ROOT_DIR/day4-logs/LAB.md"
echo ""
echo "  To stop:"
echo "    docker compose -f day4-logs/docker-compose.yml down -v"
echo "    ./day4-logs/monitors/create_monitors.sh --cleanup"
echo ""
