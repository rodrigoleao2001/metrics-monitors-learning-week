#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$ROOT_DIR/.env" ]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
fi

: "${DD_API_KEY:?ERROR: DD_API_KEY not set. Copy .env.example to .env and fill in your keys.}"
: "${DD_APP_KEY:?ERROR: DD_APP_KEY not set.}"
: "${DD_SITE:=datadoghq.com}"

CLUSTER_NAME="learning-week-k8s"

echo "=== Day 2 — Containers: Setting up Kubernetes Environment ==="
echo ""

# Step 1: Start minikube
echo "[1/5] Starting minikube cluster: ${CLUSTER_NAME}..."
if minikube status -p "$CLUSTER_NAME" &>/dev/null; then
    echo "  Cluster already running."
else
    minikube start -p "$CLUSTER_NAME" \
        --cpus=4 \
        --memory=4096 \
        --nodes=2 \
        --driver=docker \
        --kubernetes-version=v1.28.0
fi

minikube profile "$CLUSTER_NAME"
echo "  ✓ Minikube cluster ready"
echo ""

# Step 2: Add Datadog Helm repo
echo "[2/5] Adding Datadog Helm repository..."
helm repo add datadog https://helm.datadoghq.com 2>/dev/null || true
helm repo update
echo "  ✓ Helm repo ready"
echo ""

# Step 3: Create namespace and secrets
echo "[3/5] Creating namespace and secrets..."
kubectl create namespace datadog 2>/dev/null || true
kubectl create secret generic datadog-secret \
    --namespace datadog \
    --from-literal=api-key="$DD_API_KEY" \
    --from-literal=app-key="$DD_APP_KEY" \
    --dry-run=client -o yaml | kubectl apply -f -
echo "  ✓ Namespace and secrets created"
echo ""

# Step 4: Install Datadog Agent via Helm
echo "[4/5] Installing Datadog Agent via Helm..."
helm upgrade --install datadog-agent datadog/datadog \
    --namespace datadog \
    --values "${SCRIPT_DIR}/k8s/datadog-values.yaml" \
    --set datadog.site="$DD_SITE" \
    --timeout 10m
echo "  ✓ Datadog Agent installed (note: operator may take a few extra minutes to stabilize)"
echo ""

# Step 5: Deploy sample applications
echo "[5/5] Deploying sample applications..."
kubectl apply -f "${SCRIPT_DIR}/k8s/sample-app.yaml"
kubectl apply -f "${SCRIPT_DIR}/k8s/stress-app.yaml"
kubectl apply -f "${SCRIPT_DIR}/k8s/missing-tag-app.yaml"
kubectl apply -f "${SCRIPT_DIR}/k8s/advanced-app.yaml"

echo "  Waiting for deployments to be ready..."
kubectl wait --for=condition=available deployment/nginx-stable -n default --timeout=120s 2>/dev/null || true
kubectl wait --for=condition=available deployment/web-api -n default --timeout=120s 2>/dev/null || true
echo "  ✓ Applications deployed"
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Wait 3-5 minutes for metrics to appear in Datadog."
echo ""
echo "Useful commands:"
echo "  kubectl get pods -A                    # See all pods"
echo "  kubectl top nodes                      # Node resource usage"
echo "  kubectl top pods                       # Pod resource usage"
echo "  kubectl logs -n datadog -l app=datadog-agent --tail=20  # Agent logs"
echo ""
echo "Next step: Run ./monitors/create_monitors.sh to create the lab monitors."
