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

You support a Kubernetes cluster with healthy workloads, stressed workloads, and broken workloads. Five monitors were intentionally created with realistic mistakes.

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

## Mission 1 - CPU Limits: Cluster Average

The monitor uses a cluster average. Which workload is hidden?

Starting points:

1. Open `[Day2] K8s CPU Limits - Cluster Average`.
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

## Mission 2 - Pod Restart Alert: Cumulative Restarts

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

## Mission 3 - Memory Limits: Watching Changes

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

## Mission 4 - Pod Count: Static Check

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

## Mission 5 - CrashLoop Silent Monitor

A broken pod should trigger a monitor, but the monitor stays quiet.

Starting points:

1. Inspect the monitor options.
2. Check whether each alert group has data for the full evaluation window.
3. Decide whether `require_full_window` helps or hides the issue.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Design a safer monitor for sparse or short-lived pod series.

Expert defense:

- Explain the difference between no data, incomplete window, and OK.

## Bonus Challenges

1. Create a node readiness monitor.
2. Create an HPA saturation monitor and explain the owner.
3. Create a composite monitor for restart burst plus memory pressure.
4. Expert: write a runbook snippet for the first responder.

## Cleanup

```bash
./monitors/create_monitors.sh --cleanup
chmod +x teardown.sh
./teardown.sh
```
