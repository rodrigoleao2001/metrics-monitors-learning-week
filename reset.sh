#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "  Learning Week — Full Reset"
echo "============================================"
echo ""
echo "This will:"
echo "  - Stop and remove all Docker containers and volumes"
echo "  - Delete the minikube cluster (Day 2)"
echo "  - Delete ALL monitors created by the Learning Week via API"
echo ""
read -p "Are you sure? (y/N) " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
errors=0

# --- Day 1: APM (Docker Compose) ---
echo "--- Day 1: APM ---"
if [ -f "$ROOT_DIR/day1-apm/docker-compose.yml" ]; then
    docker compose -f "$ROOT_DIR/day1-apm/docker-compose.yml" down -v 2>/dev/null && \
        echo "  Containers removed." || echo "  No containers running."
else
    echo "  Skipped (no docker-compose.yml found)."
fi

# --- Day 2: Containers (Kubernetes / minikube) ---
echo "--- Day 2: Containers ---"
if command -v minikube &>/dev/null; then
    if minikube status -p learning-week-k8s &>/dev/null; then
        kubectl delete -f "$ROOT_DIR/day2-containers/k8s/stress-app.yaml" --ignore-not-found 2>/dev/null || true
        kubectl delete -f "$ROOT_DIR/day2-containers/k8s/sample-app.yaml" --ignore-not-found 2>/dev/null || true
        helm uninstall datadog-agent -n datadog 2>/dev/null || true
        minikube delete -p learning-week-k8s 2>/dev/null || true
        echo "  Minikube cluster deleted."
    else
        echo "  No minikube cluster 'learning-week-k8s' running."
    fi
else
    echo "  Skipped (minikube not installed)."
fi

# --- Day 3: DBM (Docker Compose) ---
echo "--- Day 3: DBM ---"
if [ -f "$ROOT_DIR/day3-dbm/docker-compose.yml" ]; then
    docker compose -f "$ROOT_DIR/day3-dbm/docker-compose.yml" down -v 2>/dev/null && \
        echo "  Containers removed." || echo "  No containers running."
else
    echo "  Skipped (no docker-compose.yml found)."
fi

# --- Day 4: Logs (Docker Compose) ---
echo "--- Day 4: Logs ---"
if [ -f "$ROOT_DIR/day4-logs/docker-compose.yml" ]; then
    docker compose -f "$ROOT_DIR/day4-logs/docker-compose.yml" down -v 2>/dev/null && \
        echo "  Containers removed." || echo "  No containers running."
else
    echo "  Skipped (no docker-compose.yml found)."
fi

# --- Day 5: Dynamic — Lab A (Docker Compose) ---
echo "--- Day 5: Lab A (E-commerce) ---"
if [ -f "$ROOT_DIR/day5-dynamic/lab-a-ecommerce/docker-compose.yml" ]; then
    docker compose -f "$ROOT_DIR/day5-dynamic/lab-a-ecommerce/docker-compose.yml" down -v 2>/dev/null && \
        echo "  Containers removed." || echo "  No containers running."
else
    echo "  Skipped (no docker-compose.yml found)."
fi

# --- Day 5: Dynamic — Lab B (Docker Compose) ---
echo "--- Day 5: Lab B (IoT) ---"
if [ -f "$ROOT_DIR/day5-dynamic/lab-b-iot/docker-compose.yml" ]; then
    docker compose -f "$ROOT_DIR/day5-dynamic/lab-b-iot/docker-compose.yml" down -v 2>/dev/null && \
        echo "  Containers removed." || echo "  No containers running."
else
    echo "  Skipped (no docker-compose.yml found)."
fi

# --- Delete all monitors via Datadog API ---
echo ""
echo "--- Deleting monitors via Datadog API ---"

if [ -f "$ROOT_DIR/.env" ]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
else
    echo "  WARNING: .env file not found. Skipping monitor deletion."
    echo "  (Monitors created in Datadog will need to be deleted manually.)"
    errors=1
fi

if [ -n "${DD_API_KEY:-}" ] && [ -n "${DD_APP_KEY:-}" ]; then
    DD_SITE="${DD_SITE:-datadoghq.com}"
    API_BASE="https://api.${DD_SITE}/api/v1"

    TAGS=(
        "learning-week:day1-apm"
        "learning-week:day2-containers"
        "learning-week:day3-dbm"
        "learning-week:day4-logs"
        "learning-week:day5-ecommerce"
        "learning-week:day5-iot"
    )

    for tag in "${TAGS[@]}"; do
        echo "  Searching monitors with tag: $tag"
        response=$(curl -s -X GET "${API_BASE}/monitor/search?query=tag:${tag}" \
            -H "DD-API-KEY: ${DD_API_KEY}" \
            -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" 2>/dev/null)

        monitor_ids=$(echo "$response" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('monitors', []):
    print(m['id'])
" 2>/dev/null || true)

        if [ -z "$monitor_ids" ]; then
            echo "    No monitors found."
        else
            for mid in $monitor_ids; do
                curl -s -X DELETE "${API_BASE}/monitor/${mid}" \
                    -H "DD-API-KEY: ${DD_API_KEY}" \
                    -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" > /dev/null 2>&1
                echo "    Deleted monitor $mid"
            done
        fi
    done
else
    echo "  Skipping monitor deletion (no API keys configured)."
    errors=1
fi

# --- Summary ---
echo ""
echo "============================================"
if [ $errors -eq 0 ]; then
    echo "  Reset complete. Environment is clean."
else
    echo "  Reset complete with warnings (see above)."
fi
echo "============================================"
