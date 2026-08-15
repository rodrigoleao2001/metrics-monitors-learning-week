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
- Judging whether an alert is legitimate before you touch it
- Monitor evaluation semantics: a monitor that cannot evaluate is not the same thing as a monitor that evaluated and found nothing wrong

## APM Metrics Used

| Metric | Type | Why it matters |
|--------|------|----------------|
| `trace.flask.request` | DISTRIBUTION | Latency; supports percentiles such as p95 and p99 |
| `trace.flask.request.hits` | COUNT | Request volume |
| `trace.flask.request.errors` | COUNT | Error volume |
| `trace.flask.request.duration` | legacy GAUGE | Avoid for this lab; it loses distribution detail |

## Scenario

You support `flask-store`, an online store with several endpoints. Tickets keep
arriving even though several monitors look green. Some of those monitors are
lying to you. At least one of them is not.

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

A customer writes: "Shoppers are abandoning checkout because the store feels
slow, but Datadog says everything is fine." `[Day1] APM Latency` has read OK
throughout.

Checkout has promised shoppers a completed purchase in under 3 seconds;
product's own cart-abandonment data shows drop-off climbing sharply past that
mark, and slow-checkout tickets keep arriving even with this monitor green.

Starting points:

1. Before opening the monitor, plot `trace.flask.request` for the checkout
   endpoint in Metrics Explorer and describe its shape in your own words: is it
   steady, spiky, bimodal? Do this before you read a single monitor setting.
2. Open `[Day1] APM Latency`.
3. Compare the monitor query with APM endpoint latency.
4. Inspect average, p95, and p99 for the checkout endpoint.
5. Decide which statistic maps to user pain.

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

A customer writes: "We had a payment slowdown for maybe thirty seconds around
lunch. Nobody got paged." `[Day1] APM Spike Detector` exists specifically to
catch this kind of event.

The payment processor's own status page promises checkout resumes within a
minute of any slowdown. Support has agreed that anything shorter is a normal
retry; anything lasting a minute or more is treated as an outage that must
page.

Starting points:

1. Before opening the monitor, plot `trace.flask.request` for checkout over the
   last hour with the shortest rollup Metrics Explorer offers. Describe what a
   thirty-second slowdown looks like at that resolution, in your own words.
2. Open `[Day1] APM Spike Detector`.
3. Inspect any explicit rollup in the query.
4. Plot the same metric in Metrics Explorer with a short and long rollup.
5. Compare `avg` rollup with `max` rollup.

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

A customer writes: "One of our shoppers hit an error during checkout, but the
error dashboard barely moved." `[Day1] APM Error Surge` watches the whole
service.

Checkout is the one endpoint support has a standing commitment on: its failure
rate may not exceed 1% of attempts in any 10-minute period. No such commitment
exists for any other endpoint.

Starting points:

1. Before opening the monitor, plot `trace.flask.request.errors` for the whole
   service and then broken down `by {resource_name}`. Describe, in your own
   words, whether the two views tell the same story.
2. Open `[Day1] APM Error Surge`.
3. Identify whether the query groups by endpoint.
4. Compare total errors with errors by `resource_name`.
5. Decide what dimension owns the action.

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

A customer writes: "We got paged at 3 AM for low traffic. Nothing was actually
wrong." `[Day1] APM Throughput Alert` fired anyway.

Store ops has measured that overnight traffic, local midnight to 6 AM,
naturally runs 5 to 8 requests per five minutes; during business hours, 9 AM to
9 PM, anything under 30 requests in five minutes has always coincided with a
real outage, never with a normal quiet period.

Starting points:

1. Before opening the monitor, plot `trace.flask.request.hits` for the service
   over the last 24 hours. Describe the daily shape you see, in your own
   words, before you read a single monitor setting.
2. Open `[Day1] APM Throughput Alert`.
3. Inspect the threshold and time window.
4. Compare current traffic with expected daily traffic shape.
5. Decide whether the monitor should detect absolute low volume or abnormal drop.

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

## Mission 5 - APM Inventory Latency: Second Opinion

`[Day1] APM Inventory Latency` moved from OK to Alert twenty minutes ago and is
still alerting. The on-call engineer who inherited it has watched four
monitors turn out to be wrong today and wants to raise the threshold and move
on. Before anyone touches it, decide whether that assumption is justified.

Starting points:

1. Open `[Day1] APM Inventory Latency`. Read the query exactly as written:
   statistic, window, group-by, threshold.
2. Compare this query against the fix you argued for in Mission 1. Note
   anything it is already doing right.
3. Plot `trace.flask.request` p95 for the inventory endpoint in Metrics
   Explorer over the last hour and compare it with the monitor's evaluated
   value.
4. Pull individual inventory traces in APM and look for a downstream span that
   only appears on some requests, not all of them.

Discussion questions:

- What evidence would prove this monitor is a false positive?
- What evidence would prove it is a true positive?
- Why is "the query looks fine" not enough evidence either way?

Before deciding, deliver:

- the current monitor configuration in one sentence, stating whether it
  follows the same practice you argued for in Mission 1
- one hypothesis that would make this a false positive, and the specific
  evidence that would confirm or kill it
- one hypothesis that would make this a true positive, and the specific
  evidence that would confirm or kill it
- the trace-level evidence, not just the aggregate graph, that settles which
  hypothesis is correct
- a customer-ready explanation of what is actually happening on their
  inventory checks

Stretch challenge:

- Quantify how often the slow path occurs, as a percentage of inventory
  requests over a fixed window, and argue whether that rate justifies a page
  or a lower-urgency notification instead.

Expert defense:

- This monitor is correctly configured today. Describe one future change to
  traffic volume or to the dependency itself that would make this exact query
  start producing false positives, and how you would catch that drift before
  the team stops trusting the alert.

---

## Mission 6 - Checkout Errors: Alert Volume Check

A customer writes: "Our on-call channel is unusable. We're getting paged
constantly for what looks like the same issue, over and over."
`[Day1] Checkout Errors` is the monitor behind it.

Starting points:

1. Before opening the monitor, plot `flask_store.checkout_errors` in Metrics
   Explorer without any group-by. Then add a group-by and watch how many
   series appear. Describe what you see in your own words before reading the
   monitor's configuration.
2. Open `[Day1] Checkout Errors`.
3. Inspect which dimension the query groups by.
4. Estimate how many distinct values that dimension can take.
5. Decide which dimension actually maps to someone who can act on the alert.

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

## Mission 7 - Composite Monitor: Both Bad at the Same Time

A customer writes: "We get paged separately for slow checkout and for checkout
errors, but neither page alone tells us whether shoppers are actually
affected." On-call wants one signal that means real impact.

The checkout team has told support that latency up to 5 seconds during the
nightly batch job is expected, and an error rate up to 2% during an active
deploy is also expected. Anything past both numbers at once, batch or no
batch, deploy or no deploy, is a real incident.

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

## Mission 8 - SLO and Burn Rate: When Is the Budget Gone?

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

## Mission 9 - Catalog Sync: The Monitor That Stopped Answering

`[Day1] Catalog Sync` reads OK. It has read OK all week.

The sync it watches stops for several minutes at a time, and during those
stretches the metric sends nothing at all. The monitor keeps reading OK straight
through them. Finance found a failed sync themselves, two days later, while this
monitor sat green.

Starting points:

1. Open the monitor and note its current state.
2. Plot `flask_store.batch_sync_records` in Metrics Explorer over the last hour
   with a one minute rollup. Find the stretches where there are no points at all,
   and write down the clock times.
3. Go back to the monitor and compare its state during those exact stretches
   against what the metric was doing.
4. Build the same query in a notebook or a scratch monitor, change one evaluation
   setting, and watch what the state does during the next gap.

Discussion questions:

- If a monitor cannot evaluate, what should it report?
- What is the difference between a monitor that says OK and a monitor that has
  not been asked the question recently?
- Which of those two is more dangerous on a dashboard?

Before changing the monitor, deliver:

- what the monitor reports while its metric is sending nothing, and the single
  setting responsible, named exactly
- the evidence that isolates that setting, not a description of what you think it
  does. One changed setting, everything else identical, and the two behaviours
  side by side
- one rejected alternative hypothesis, for example that the metric never stopped,
  or that the notification settings are suppressing something, and what kills it
- two possible fixes and the trade-off between them
- a customer-ready explanation of how a green monitor can be reporting nothing at
  all

Stretch challenge:

- The sync is genuinely idle for part of every cycle. Design a monitor that stays
  quiet during a normal idle stretch but does alert when the sync stops for longer
  than it ever legitimately does. Explain which setting carries that distinction.

Expert defense:

- Explain what `require_full_window` is genuinely for, and name one signal where
  leaving it on is the right call. Then explain how you would detect, across a
  whole account, monitors that have quietly stopped evaluating, given that they
  look identical to healthy ones from the monitor list.

## Facilitator demo - monitor evaluation concepts

`[Day1] DEMO` is not a mission and there is nothing in it for you to diagnose. The facilitator uses it live during the session to demonstrate Evaluation Window, Require Full Window, and New Group Delay.

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
