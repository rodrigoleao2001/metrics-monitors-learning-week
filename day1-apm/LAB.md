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

You support `flask-store`, an online store with several endpoints. Some users are unhappy, but several monitors look green. Four monitors were intentionally created with realistic mistakes.

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
