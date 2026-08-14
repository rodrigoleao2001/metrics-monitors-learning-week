# Day 2 - Containers: The Kubernetes Resource Crisis

## Hard Mode Rules

This lab is a support case simulation, not a query-copying exercise.

- Start with a hypothesis before changing a monitor.
- Capture evidence: query, graph, screenshot, log sample, or monitor state.
- Write one plausible alternative hypothesis and explain why you rejected it.
- Propose two possible fixes before choosing one.
- Defend the trade-off: detection speed, noise, ownership, routing, and message clarity.
- The student guide does not contain final diagnoses. The facilitator owns the discussion guide.

## Evidence Log

Use this table for every mission.

| Field | What to capture |
|-------|-----------------|
| Customer symptom | What the user or alert claims is wrong |
| Signal tested | Metric, log query, monitor query, or UI view inspected |
| Hypothesis A | Most likely explanation |
| Hypothesis B | Plausible alternative you rejected |
| Evidence | What proves A over B |
| Fix option 1 | First possible monitor/query/message change |
| Fix option 2 | Second possible monitor/query/message change |
| Chosen fix | What you would deploy and why |
| Customer explanation | How you would explain it without dumping query syntax |

## Difficulty Ladder

- **Core path:** prove what is broken and make the monitor detect the real issue.
- **Stretch challenge:** compare at least two valid fixes and explain the trade-off.
- **Expert defense:** explain how your fix could still fail in production and how you would validate it after release.


## Goal

Learn how space aggregation, cumulative counters, Kubernetes state metrics, evaluation delay, and `require_full_window` affect container monitors.

## Concepts

- Cluster average vs workload-level ownership
- Cumulative counters and recent change
- Desired vs ready vs running
- `kubernetes.*` vs `kubernetes_state.*`
- Sparse data, crash loops, and silent monitor evaluations

## Scenario

You support a Kubernetes cluster with healthy workloads, stressed workloads, and broken workloads. Every monitor in this lab was intentionally created with a realistic mistake.

## Setup

```bash
cd day2-containers/
chmod +x setup.sh
./setup.sh
kubectl get pods -A
chmod +x monitors/create_monitors.sh
./monitors/create_monitors.sh
```

Check:

- Infrastructure > Kubernetes
- Monitors > Manage: filter `tag:learning-week:day2-containers`

---

## Mission 1 - CPU Limits: Fleet Overview

The monitor uses a cluster average. Which workload is hidden?

Starting points:

1. Open `[Day2] K8s CPU Limits - Fleet Overview`.
2. Plot the metric with and without `by {kube_deployment}`.
3. Decide whether the current number points to an owner.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Compare grouping by deployment, pod, and node. Choose the most actionable one.

Expert defense:

- Explain how this monitor would behave during a noisy neighbor issue.

---

## Mission 2 - Pod Restart Alert: Restart Tracking

The monitor is stuck in alert. Would it recover if the pod stopped crashing?

Starting points:

1. Inspect the restart metric.
2. Determine whether it represents total lifetime restarts or recent restarts.
3. Compare a raw cumulative value with a recent-change view.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Design a monitor that detects recent restart bursts without staying red forever.

Expert defense:

- Explain how pod recreation or tag changes can affect the evaluation.

---

## Mission 3 - Memory Limits: Configuration Watch

The monitor uses change logic on a mostly static configuration value.

Starting points:

1. Inspect the metric type and what it represents.
2. Compare configured memory limits with actual memory usage.
3. Decide whether the monitor should watch configuration, usage, or saturation.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Propose one configuration monitor and one runtime pressure monitor.

Expert defense:

- Explain which one should page and which one should be dashboard-only.

---

## Mission 4 - Pod Count: Capacity Check

The total pod count looks OK, but deployments may not be ready.

Starting points:

1. Compare running pods with ready replicas.
2. Inspect `kubectl get deployments`.
3. Decide whether total count proves service health.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Design a monitor that points to the deployment owner, not just the cluster.

Expert defense:

- Explain how rolling deploys should affect the threshold and evaluation window.

---

## Mission 5 - CrashLoop CPU Limits: Always Alerting

A customer writes: "This alert has been red for three weeks straight. Nobody on the team even
looks at it anymore." `[Day2] CrashLoop CPU Limits - Always Alerting` has never once returned to
OK since the day it was created, no matter what else is happening on the cluster.

Starting points:

1. Open the monitor and read exactly what metric the query pulls and what it compares that metric
   against.
2. Run `kubectl describe pod` for the crashloop-app workload and find its configured CPU limit in
   the pod spec.
3. Compare that configured number with the monitor's threshold.
4. Decide whether this metric could ever land on the other side of that threshold, under any
   circumstance at all.

Discussion questions:

- What is the difference between a configuration value and a live measurement?
- If a metric can only ever sit on one side of a threshold, what is the alert actually telling
  anyone?
- What would have to change about this monitor for it to carry real information?

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Design a monitor for this same workload that would actually read green while it is healthy and
  red while it is crash-looping.

Expert defense:

- Explain why comparing a static configuration value against a fixed threshold can only ever
  produce a monitor that is always right or always wrong, never one that is sometimes right, and
  how you would find this same pattern across an entire account before a customer does.

---

## Mission 6 - K8s CPU Usage: Workload Check

One workload never gets its own alert group in a monitor grouped by deployment, and no alert ever names it, even though it is clearly running and consuming CPU.

Starting points:

1. Open `[Day2] K8s CPU Usage - Workload Check`.
2. Run `kubectl get deployments`, `kubectl get replicasets`, and `kubectl get pods -o wide` and compare what each command shows.
3. Check which owner object each pod actually belongs to.
4. Decide whether every workload in this cluster is guaranteed to have a `kube_deployment` tag.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Propose a monitor design that still catches this workload without assuming every workload is owned by a Deployment.

Expert defense:

- Explain what any monitor that groups by an owner dimension assumes about the workloads it is watching, and when that assumption fails.

## Mission 7 - HPA Saturation: No More Headroom

The horizontal pod autoscaler is scaling, but the monitor does not warn when the autoscaler has reached its ceiling and cannot add more replicas.

Starting points:

1. Run `kubectl get hpa -A` and note the current and maximum replica count for any HPA in the cluster.
2. Find the Kubernetes state metric that exposes desired replicas and maximum allowed replicas for an HPA.
3. Open `[Day2] K8s HPA - Saturation Watch` and inspect what it compares.
4. Decide whether the monitor triggers early enough to allow action before the ceiling is reached.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- why reaching the HPA maximum is an actionable signal even if all pods are healthy
- two possible threshold strategies and the trade-off between them
- a customer-ready explanation of what "HPA ceiling" means without mentioning Kubernetes internals

Stretch challenge:

- Design a two-stage alert: warn when 80% of max replicas are in use, critical when desired equals max.

Expert defense:

- Explain what happens to this monitor during a cluster upgrade or node drain when pods are temporarily evicted and rescheduled. Would it produce false positives? How would you prevent it?

---

## Mission 8 - Node Scheduling Pressure: Pods Cannot Land

All pods are running. New pods cannot be scheduled. The current monitors do not detect this.

Starting points:

1. Run `kubectl describe nodes` and inspect `Allocatable` vs `Requests` for CPU and memory.
2. Find the Kubernetes metric that exposes allocatable CPU and the metric that exposes requested CPU by node.
3. Compare these two values as a ratio and decide at what threshold new pods would be rejected.
4. Open `[Day2] K8s Node CPU - Scheduling Pressure` and verify whether it actually catches the condition where the node is full but existing pods are not suffering.

Before changing the monitor, deliver:

- the difference between a pod suffering from CPU throttling and a node rejecting new pod placements
- one rejected alternative metric you considered using and why it does not prove the scheduling gap
- two monitor designs and the trade-off between detecting scheduling pressure early versus creating noise on bursty workloads
- a customer-ready explanation of why the cluster looks healthy on the infrastructure page but new deployments are stuck pending

Stretch challenge:

- Propose a composite monitor that detects both scheduling pressure on nodes and pending pods simultaneously.

Expert defense:

- Explain how taints, tolerations, and node affinity rules would make this monitor unreliable for heterogeneous clusters. What assumption does any node-level resource monitor make about scheduling eligibility?

---

## Mission 9 - Deployment Rollout Stall: Available vs Updated

A deployment was rolled out 20 minutes ago. The pod count looks correct. The rollout is silently stalled.

Starting points:

1. Run `kubectl rollout status deployment/<name>` for each deployment in the cluster.
2. Compare `kubernetes_state.deployment.replicas_updated` with `kubernetes_state.deployment.replicas_available` for each deployment.
3. Find a deployment where updated replicas and available replicas diverge.
4. Open `[Day2] K8s Deployment - Rollout Stall` and check whether it compares updated vs available, or just checks total running pods.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- why a total pod count monitor misses a stalled rolling update
- two possible signals that prove a rollout is stalled vs simply slow
- a customer-ready explanation that explains the risk of a stalled rollout without mentioning kubectl

Stretch challenge:

- Design a monitor with a time-based condition: the rollout has been in progress for more than 10 minutes with no increase in updated replicas.

Expert defense:

- Explain how `maxSurge` and `maxUnavailable` in the deployment strategy affect what "stalled" means and how you would account for intentionally slow rollouts.

---

## Bonus Challenges

1. Create a node readiness monitor.
2. Create a composite monitor for restart burst plus memory pressure.
3. Expert: write a runbook snippet for the first responder.

## Cleanup

```bash
./monitors/create_monitors.sh --cleanup
chmod +x teardown.sh
./teardown.sh
```
