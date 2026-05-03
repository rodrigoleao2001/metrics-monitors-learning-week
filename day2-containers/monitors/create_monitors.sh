#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../shared/monitors_utils.sh"

DAY_TAG="learning-week:day2-containers"

if [ "${1:-}" = "--cleanup" ]; then
    delete_monitors_by_tag "$DAY_TAG"
    exit 0
fi

echo ""
echo "=== Day 2 — Containers: Creating Lab Monitors ==="
echo ""

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day2] K8s CPU Limits - Cluster Average",
  "type": "metric alert",
  "query": "avg(last_10m):avg:kubernetes.cpu.limits{kube_cluster_name:learning-week-k8s} > 0.5",
  "message": "Average CPU limit across all pods is high!\n\nBut is the CLUSTER average of CPU limits really meaningful?\nSome pods have 300m, others have 50m — the average hides this.\nHow would you fix this monitor to identify over/under-provisioned workloads?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers", "difficulty:beginner"],
  "options": {
    "thresholds": {"critical": 0.5, "warning": 0.2},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day2] Pod Restart Alert - Cumulative Restarts",
  "type": "metric alert",
  "query": "max(last_5m):max:kubernetes.containers.restarts{kube_cluster_name:learning-week-k8s} by {pod_name} > 3",
  "message": "Pod {{pod_name.name}} has restarted more than 3 times!\n\nThis monitor is stuck in ALERT for crashloop-app. Even if the pod stabilizes, the counter only goes UP.\nIs this really detecting an active problem, or just a historical one?\n\n@pagerduty-k8s",
  "tags": ["learning-week:day2-containers", "difficulty:intermediate"],
  "options": {
    "thresholds": {"critical": 3, "warning": 2},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day2] Container Memory Limits - Watching Changes",
  "type": "metric alert",
  "query": "change(avg(last_5m),last_15m):avg:kubernetes.memory.limits{kube_cluster_name:learning-week-k8s} by {pod_name} > 10000000",
  "message": "Memory limit changed by more than 10MB for pod {{pod_name.name}}!\n\nThis monitor uses change() on memory LIMITS. But limits are static values defined in the pod spec.\nDoes change() make sense here? Will this monitor ever fire?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers", "difficulty:intermediate"],
  "options": {
    "thresholds": {"critical": 10000000, "warning": 5000000},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day2] K8s Pod Count - Static Check",
  "type": "metric alert",
  "query": "min(last_10m):sum:kubernetes.pods.running{kube_cluster_name:learning-week-k8s} < 3",
  "message": "Less than 3 pods running in the cluster!\n\nIs counting total pods really the best way to ensure deployments are healthy?\nWhat about CrashLoopBackOff pods that keep restarting?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers", "difficulty:advanced"],
  "options": {
    "thresholds": {"critical": 3, "warning": 5},
    "notify_no_data": true,
    "no_data_timeframe": 10,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 5
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day2] CrashLoop CPU Limits - Silent Monitor",
  "type": "metric alert",
  "query": "avg(last_5m):avg:kubernetes.cpu.limits{kube_cluster_name:learning-week-k8s,kube_deployment:crashloop-app} by {pod_name} > 0.01",
  "message": "CrashLoop pod {{pod_name.name}} has CPU limits set!\n\nThis pod crashes every ~15s. Each new pod has a 50m CPU limit (well above 0.01 threshold).\nBut this monitor NEVER fires. Why is it silent?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers", "difficulty:advanced"],
  "options": {
    "thresholds": {"critical": 0.01, "warning": 0.005},
    "notify_no_data": false,
    "require_full_window": true,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

echo ""
echo "=== Day 2 monitors created! ==="
echo "Check them at: https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day2-containers"
echo ""
