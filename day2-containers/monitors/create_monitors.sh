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
  "name": "[Day2] K8s CPU Limits - Fleet Overview",
  "type": "metric alert",
  "query": "avg(last_10m):avg:kubernetes.cpu.limits{kube_cluster_name:learning-week-k8s} > 0.5",
  "message": "Average CPU limit across all pods is high!\n\nBut is the CLUSTER average of CPU limits really meaningful?\nSome pods have 300m and others have 50m.\nHow would you fix this monitor to identify over/under-provisioned workloads?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers"],
  "options": {
    "thresholds": {"critical": 0.5, "warning": 0.2},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 2 — Mission 2: Pod Restart Alert - Restart Tracking
# Flaw: kubernetes.containers.restarts is a lifetime cumulative counter, so
# once a pod crosses the threshold once it can never fall back below it, even
# long after the pod stopped restarting.
# Recommended fix, verified live on 2026-08-14, see PRESENTER_GUIDE.md for the
# full note: sum(last_10m):monotonic_diff(avg:kubernetes.containers.restarts
# {kube_cluster_name:learning-week-k8s} by {pod_name}) > 0. Do not point
# students at change(), that function is already the flaw being taught in
# Mission 3.
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day2] Pod Restart Alert - Restart Tracking",
  "type": "metric alert",
  "query": "max(last_5m):max:kubernetes.containers.restarts{kube_cluster_name:learning-week-k8s} by {pod_name} > 3",
  "message": "Pod {{pod_name.name}} has restarted more than 3 times!\n\nThis monitor is stuck in ALERT.\nIs this really detecting an active problem, or just a historical one?\n\n@pagerduty-k8s",
  "tags": ["learning-week:day2-containers"],
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
  "name": "[Day2] Container Memory Limits - Configuration Watch",
  "type": "metric alert",
  "query": "change(avg(last_5m),last_15m):avg:kubernetes.memory.limits{kube_cluster_name:learning-week-k8s} by {pod_name} > 10000000",
  "message": "Memory limit changed by more than 10MB for pod {{pod_name.name}}!\n\nThis monitor uses change() on memory LIMITS. But limits are static values defined in the pod spec.\nDoes change() make sense here? Will this monitor ever fire?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers"],
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
  "name": "[Day2] K8s Pod Count - Capacity Check",
  "type": "metric alert",
  "query": "min(last_10m):sum:kubernetes.pods.running{kube_cluster_name:learning-week-k8s} < 3",
  "message": "Less than 3 pods running in the cluster!\n\nIs counting total pods really the best way to ensure deployments are healthy?\nWhat about CrashLoopBackOff pods that keep restarting?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers"],
  "options": {
    "thresholds": {"critical": 3, "warning": 5},
    "notify_no_data": true,
    "no_data_timeframe": 10,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 5 — Mission 5: CrashLoop CPU Limits - Always Alerting
# Flaw: kubernetes.cpu.limits is a static configuration value. crashloop-app's
# pod spec sets its CPU limit to 50m; the threshold here is 10m. Since 50m is
# always greater than 10m, this monitor has been continuously in Alert since
# creation and can never return to OK, whether the pod is calmly running or
# crash-looping. See day2-containers/PRESENTER_GUIDE.md for the full note on
# why this mission was reframed away from its original require_full_window
# premise, which did not reproduce in this environment.
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day2] CrashLoop CPU Limits - Always Alerting",
  "type": "metric alert",
  "query": "avg(last_5m):avg:kubernetes.cpu.limits{kube_cluster_name:learning-week-k8s,kube_deployment:crashloop-app} by {pod_name} > 0.01",
  "message": "CrashLoop workload has CPU limits set!\n\nThis monitor has been in Alert nonstop since the pod was created, whether the container is calmly running or crash-looping every 15 seconds.\nWhat is this metric actually measuring, and could it ever land on the other side of that threshold?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers"],
  "options": {
    "thresholds": {"critical": 0.01, "warning": 0.005},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 6
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day2] K8s CPU Usage - Workload Check",
  "type": "metric alert",
  "query": "avg(last_10m):avg:container.cpu.usage{kube_cluster_name:learning-week-k8s,!kube_namespace:datadog} by {kube_deployment} > 50000000",
  "message": "CPU usage for deployment {{kube_deployment.name}} is high!\n\nOne workload in this cluster is burning CPU but never produces an alert group here.\nWhich workload is it, and why does this monitor not account for it?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers"],
  "options": {
    "thresholds": {"critical": 50000000, "warning": 25000000},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 7 — Mission 7: HPA Saturation Watch
# Flaw: monitors current replica count against a static threshold.
# It does not compare desired replicas vs max replicas, so it never detects
# when the autoscaler has hit its ceiling and cannot scale further.
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day2] K8s HPA - Saturation Watch",
  "type": "metric alert",
  "query": "avg(last_5m):avg:kubernetes_state.hpa.current_replicas{kube_cluster_name:learning-week-k8s} by {horizontalpodautoscaler} > 5",
  "message": "HPA {{horizontalpodautoscaler.name}} has more than 5 replicas!\n\nThe threshold is 5 but the HPA maximum is 2.\nThis monitor can never fire on this cluster.\nIs current replica count the right signal for autoscaler saturation?\nWhat would you compare instead?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers"],
  "options": {
    "thresholds": {"critical": 5, "warning": 4},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 8 — Mission 8: Node Scheduling Pressure
# Flaw: monitors pod count per node instead of CPU requests vs allocatable.
# Total pod count looks normal even when the node is at 100% requested CPU
# and new pods would be rejected by the scheduler.
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day2] K8s Node CPU - Scheduling Pressure",
  "type": "metric alert",
  "query": "avg(last_10m):sum:kubernetes.pods.running{kube_cluster_name:learning-week-k8s} by {host} > 50",
  "message": "More than 50 pods on node {{host.name}}!\n\nPod count per node does not prove the node can accept new pods.\nA node at 100% requested CPU will reject new pods even with only 5 pods running.\nWhat metric would actually show the scheduler cannot place new workloads?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers"],
  "options": {
    "thresholds": {"critical": 50, "warning": 40},
    "notify_no_data": false,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

# Monitor 9 — Mission 9: Deployment Rollout Stall
# Flaw: monitors total running pods, which looks healthy.
# The rollout-stall deployment has pods that are Running but never Ready,
# so replicas_updated is non-zero but replicas_available is 0.
# The monitor never fires because running pods = expected.
P=$(new_payload)
cat > "$P" <<'JSON'
{
  "name": "[Day2] K8s Deployment - Rollout Stall",
  "type": "metric alert",
  "query": "min(last_10m):sum:kubernetes.pods.running{kube_cluster_name:learning-week-k8s,kube_deployment:rollout-stall} < 1",
  "message": "rollout-stall has no running pods!\n\nThis monitor watches running pods and stays green.\nBut the deployment has been rolling for 20 minutes and nothing is ready.\nWhat is the difference between a pod that is Running and a pod that is Available?\nWhich kubernetes_state metric would catch a stalled rollout?\n\n@slack-infra",
  "tags": ["learning-week:day2-containers"],
  "options": {
    "thresholds": {"critical": 1},
    "notify_no_data": true,
    "no_data_timeframe": 10,
    "renotify_interval": 0
  }
}
JSON
create_monitor_from_file "$P"

echo ""
echo "=== Day 2 monitors created! ==="
echo "Check them at: https://app.${DD_SITE}/monitors/manage?q=tag:learning-week:day2-containers"
echo ""
