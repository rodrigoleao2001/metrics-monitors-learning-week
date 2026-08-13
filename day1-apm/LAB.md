# Day 1 - APM: The Latency Lie

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

Learn how metric type, statistic choice, rollup, and tag segmentation can hide or reveal real user pain in APM latency and error monitors.

## Concepts

- Average vs p95/p99 for user experience
- Time aggregation vs space aggregation
- Rollup intervals and spike preservation
- Trace metrics: `trace.<SPAN_NAME>`, `.hits`, and `.errors`
- Static thresholds vs anomaly-style thinking
- Monitor messages as part of troubleshooting

## APM Metrics Used

| Metric | Type | Why it matters |
|--------|------|----------------|
| `trace.flask.request` | DISTRIBUTION | Latency; supports percentiles such as p95 and p99 |
| `trace.flask.request.hits` | COUNT | Request volume |
| `trace.flask.request.errors` | COUNT | Error volume |
| `trace.flask.request.duration` | legacy GAUGE | Avoid for this lab; it loses distribution detail |

## Scenario

You support `flask-store`, an online store with several endpoints. Some users are unhappy, but several monitors look green. The lab monitors were intentionally created with realistic mistakes.

## Setup

```bash
cd day1-apm/
docker compose up -d --build
docker compose exec datadog-agent agent status | head -30
chmod +x monitors/create_monitors.sh
./monitors/create_monitors.sh
```

Check:

- APM > Services: find `flask-store`
- Monitors > Manage: filter `tag:learning-week:day1-apm`

---

## Mission 1 - APM Latency: All Good

The monitor says latency is OK. Users still report slow checkout.

Starting points:

1. Open `[Day1] APM Latency - All Good`.
2. Compare the monitor query with APM endpoint latency.
3. Inspect average, p95, and p99 for the checkout endpoint.
4. Decide which statistic maps to user pain.

Discussion questions:

- What does average hide here?
- When would average still be useful?
- What does the metric type allow you to calculate?

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Propose one endpoint-specific fix and one multi-alert fix.
- Explain which one creates better ownership.

Expert defense:

- Explain how your monitor would behave during a global latency increase versus one broken endpoint.

---

## Mission 2 - APM Spike Detector

The monitor is supposed to detect short latency spikes, but it stays quiet.

Starting points:

1. Open `[Day1] APM Spike Detector`.
2. Inspect any explicit rollup in the query.
3. Plot the same metric in Metrics Explorer with a short and long rollup.
4. Compare `avg` rollup with `max` rollup.

Discussion questions:

- What happens to a 30-second spike inside a 10-minute average?
- What is the trade-off between sensitivity and noise?
- Which rollup method preserves the evidence?

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Build a monitor that catches spikes but does not page on one bad sample.

Expert defense:

- Explain how you would validate this monitor during a real incident replay.

---

## Mission 3 - APM Error Surge

The total error count looks small. One endpoint may still be broken.

Starting points:

1. Open `[Day1] APM Error Surge`.
2. Identify whether the query groups by endpoint.
3. Compare total errors with errors by `resource_name`.
4. Decide what dimension owns the action.

Discussion questions:

- When does grouping create clarity?
- When can grouping create alert storms?
- What is the difference between finding a bad service and finding a bad endpoint?

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Add a design that prevents one endpoint from hiding behind overall service health.

Expert defense:

- Explain when you would notify by endpoint and when you would notify only by service.

---

## Mission 4 - APM Throughput Alert

The monitor alerts when traffic is low. Is low traffic always a problem?

Starting points:

1. Open `[Day1] APM Throughput Alert`.
2. Inspect the threshold and time window.
3. Compare current traffic with expected daily traffic shape.
4. Decide whether the monitor should detect absolute low volume or abnormal drop.

Discussion questions:

- What is normal low traffic?
- What should happen during off-hours?
- When would `notify_no_data` help, and when would it create noise?

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Propose a static-threshold design and an anomaly/change-style design.

Expert defense:

- Explain what you would change for Black Friday or another planned traffic shift.

---

## Mission 5 - Checkout Errors: Alert Volume Check

The monitor is supposed to catch checkout errors, but it creates a new alert group for almost every single failure.

Starting points:

1. Open `[Day1] Checkout Errors - Alert Volume Check`.
2. Inspect which dimension the query groups by.
3. Estimate how many distinct values that dimension can take.
4. Decide which dimension actually maps to someone who can act on the alert.

Discussion questions:

- What makes a good group-by dimension versus a bad one?
- What happens to alert volume as the number of distinct values in the group-by dimension grows?
- Which dimension would let one person own the fix for this failure?

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Propose a design that still lets you drill into a specific session without paging on every one of them.

Expert defense:

- Explain how this same mistake could show up on a custom metric tagged by user ID, order ID, or request ID.

---

## Mission 6 - Composite Monitor: Both Bad at the Same Time

The on-call team receives separate alerts for latency and for errors, but neither one alone proves an incident. High latency during a batch job is expected. Errors during a deploy are expected. Both at the same time means real user impact.

Starting points:

1. Plot `trace.flask.request` p95 for the checkout endpoint over the last hour.
2. Plot `trace.flask.request.errors` rate for the same endpoint over the same window.
3. Find a period where both are elevated simultaneously and a period where only one is.
4. Decide whether a single metric can represent both conditions, or whether you need a composite.

Before building the monitor, deliver:

- why a composite is needed instead of just lowering the latency threshold
- one scenario where a composite would produce a false negative
- the exact trigger conditions for each constituent monitor (what threshold, what window, what group-by)
- a customer-ready explanation of what "both bad at the same time" means operationally

Stretch challenge:

- Identify a third condition (throughput drop) that would make this composite more precise. Explain when adding a third leg hurts more than it helps.

Expert defense:

- Explain how a composite monitor behaves when one constituent is in no-data state. Show where this is configured and what the operational risk is.

---

## Mission 7 - SLO and Burn Rate: When Is the Budget Gone?

A checkout SLO is set at 99% availability over a 30-day rolling window. The SLO is green right now. The burn rate is not.

Starting points:

1. Create a request-based SLO using `trace.flask.request.hits` as the total and `trace.flask.request.errors` as bad events for the checkout endpoint.
2. Set the target at 99% over 30 days.
3. Open the burn rate alert options and inspect the fast-burn and slow-burn windows.
4. Find the burn rate value at which the 30-day error budget is consumed in 1 hour.

Before setting the burn rate alert, deliver:

- what an error budget of 1% over 30 days means in minutes of downtime per month
- the burn rate threshold that signals the budget will be gone in under 1 hour
- the burn rate threshold that signals the budget will be gone in under 24 hours
- one scenario where burn rate alerts earlier than a simple error-rate threshold, and one where it does not

Stretch challenge:

- Compare a request-based SLO with a monitor-based SLO for the same checkout service. Explain which one is more accurate and when the two would give different results.

Expert defense:

- Explain what happens to the burn rate calculation when traffic drops to zero. Is the SLO safe? How would you prevent a false-safe reading?

---

## Facilitator demo - monitor evaluation concepts

`[Day1] DEMO - Monitor Evaluation Concepts` is not a mission and there is nothing in it for you to diagnose. The facilitator uses it live during the session to demonstrate Evaluation Window, Require Full Window, and New Group Delay.

## Bonus Challenges

1. Create a composite monitor that only alerts when checkout p95 latency and checkout error rate are both bad.
2. Create an SLO for `flask-store` and explain what burn rate tells the on-call.
3. Build a dashboard that shows latency percentiles, error rate, throughput, and a latency heatmap.
4. Expert: write a customer-facing explanation that does not mention internal query syntax.

## Cleanup

```bash
docker compose down -v
./monitors/create_monitors.sh --cleanup
```
