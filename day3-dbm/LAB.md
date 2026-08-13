# Day 3 - DBM: The Silent Database Killer

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

Learn how static thresholds, growth signals, aggregators, database segmentation, and alert messages affect database monitors.

## Concepts

- Absolute size vs growth
- Average vs max for short database bursts
- Database-level and state-level segmentation
- DBM Query Samples vs metric monitors
- Alert messages that start the investigation

## Scenario

You support a PostgreSQL-backed ecommerce application. Some database symptoms are real, some monitors are misleading, and the alert message quality is part of the problem.

## Setup

```bash
cd day3-dbm/
docker compose up -d --build
docker compose exec datadog-agent agent status | grep -A 10 "postgres"
docker compose exec postgres psql -U postgres -d learning_week -c "SELECT count(*) FROM orders;"
chmod +x monitors/create_monitors.sh
./monitors/create_monitors.sh
```

Check:

- DBM > Query Metrics
- DBM > Query Samples
- Metrics Explorer: `postgresql.*`
- Monitors > Manage: filter `tag:learning-week:day3-dbm`

---

## Mission 1 - DB Size: Always Alerting

The database size monitor is always red. Is size itself the incident?

Starting points:

1. Inspect the threshold.
2. Compare absolute size with recent growth.
3. Decide what question the monitor should ask.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Propose an absolute-capacity monitor and a growth monitor. Explain which one pages.

Expert defense:

- Explain how retention, maintenance, and expected growth affect thresholds.

---

## Mission 2 - DB Session Spikes: Connection Load

Average sessions look OK. Short bursts may still hurt the database.

Starting points:

1. Compare `avg` and `max` views.
2. Inspect the time window.
3. Look for short connection floods.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Create a monitor that catches bursts but avoids paging on harmless single samples.

Expert defense:

- Explain what you would inspect next in DBM Query Samples.

---

## Mission 3 - DB Row Volume: Query Volume

The aggregate volume looks OK. One database may own the load.

Starting points:

1. Plot the metric by `db`.
2. Compare system databases with the application database.
3. Decide whether `.as_rate()` or `.as_count()` fits the question.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Propose a database-level monitor and a query-level investigation path.

Expert defense:

- Explain why a monitor may not be the right place for query signature analysis.

---

## Mission 4 - DB Connections: Last Resort Alert

The monitor alerts too late, and the message does not help the on-call.

Starting points:

1. Inspect the critical threshold.
2. Compare active, idle, and idle-in-transaction sessions.
3. Read the monitor message as if it woke you up at 3 AM.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Write a better alert message with impact, evidence, next checks, and routing.

Expert defense:

- Explain how warning, critical, renotify, and recovery behavior should work together.

---

## Mission 5 - Orders Reconciliation: No Recent Activity

The monitor says reconciliation stopped in the last five minutes. Finance is worried, but nothing actually looks broken.

Starting points:

1. Open `[Day3] Orders Reconciliation - No Recent Activity`.
2. Plot `postgres_app.orders_reconciled_total` in Metrics Explorer for the last hour.
3. Compare the same graph at several different offsets from now and note where points land.
4. Decide whether reconciliation actually stopped, and name the evidence that settles it.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Propose two monitor designs that would hold up for this signal without simply making the window longer forever. Explain which one pages.

Expert defense:

- Explain how you would prove to Finance that reconciliation is or is not running, without relying on this monitor.

## Mission 6 - Idle-in-Transaction: The Hidden Lock Holder

Connection usage looks normal. Queries are completing. The application started hanging 10 minutes ago. One session has been idle-in-transaction for 25 minutes and nobody noticed.

Starting points:

1. Run `SELECT pid, state, now() - state_change AS duration, query FROM pg_stat_activity WHERE state = 'idle in transaction' ORDER BY duration DESC;` directly in the database.
2. Find the metric that exposes sessions by state. Compare `active`, `idle`, and `idle in transaction` counts separately.
3. Open `[Day3] DB Connections - Last Resort Alert` and check whether its threshold would have triggered on a single idle-in-transaction session.
4. Decide whether connection count alone is the right signal for lock-driven hangs.

Before building the monitor, deliver:

- why an idle-in-transaction session is more dangerous than an active session consuming the same slot
- one rejected signal you considered (e.g., total connections, active connections) and why it does not prove the problem
- two monitor designs: one that detects the state and one that detects the duration
- a customer-ready explanation of why the app appears hung when the database has free connections

Stretch challenge:

- Design a composite monitor that alerts when idle-in-transaction count is above zero AND active connection count is also above a baseline. Explain when each leg alone would fire and when the composite is the right signal.

Expert defense:

- Explain how connection poolers like PgBouncer change the visibility of idle-in-transaction sessions in pg_stat_activity. Would your monitor still work behind a pooler?

---

## Mission 7 - Query Plan Regression: The Slow Query That Appeared Overnight

A query that ran in 2ms last week now runs in 4 seconds. The database size did not change. The code did not change. The index still exists.

Starting points:

1. Open DBM > Query Metrics and sort by average latency descending.
2. Find the query whose latency increased significantly in the last 24 hours compared with its 7-day baseline.
3. Click into the query and compare the execution plan from recent samples with older samples using the Explain Plan tab.
4. Identify whether the plan changed (sequential scan vs index scan, nested loop vs hash join) and confirm the index referenced in the old plan still exists.

Before proposing a fix, deliver:

- the query signature and the execution plan change that proves regression (not just higher latency)
- one alternative explanation you ruled out (e.g., data volume, lock wait, vacuum bloat) and the evidence that rules it out
- two possible causes for a plan change without a schema change and the diagnostic step that distinguishes them
- a customer-ready explanation of why the query got slower without any code or schema change

Stretch challenge:

- Design a DBM-based metric monitor that would catch this regression automatically the next time it happens. Explain whether a static threshold or a change-based monitor is better for query latency.

Expert defense:

- Explain what `pg_stat_statements` resets mean for DBM historical data. If `pg_stat_statements` was reset at midnight, what does the DBM baseline show and how does it affect your regression detection?

---

## Mission 8 - The Overstated Alert: Datadog Says 30%, the DBA Says 3%

The monitor `[Day3] [as_count demo] Query Error Rate` is firing. The evaluated value shows an error rate above 20%. A DBA manually counts errors and total queries in the database for the last 5 minutes and gets 3%. The customer opens a ticket: "your tool is wrong."

Your job is not to pick a side. Your job is to prove that both numbers are correct, explain what question each one answers, and fix the monitor to answer the right question.

Starting points:

1. Open `[Day3] [as_count demo] Query Error Rate` and note the current evaluated value.
2. Plot `pg_app.queries.errors` and `pg_app.queries.total` separately in Metrics Explorer with a 1-minute rollup. Print or sketch the value at each point for the last 5 minutes.
3. Calculate the monitor's result by hand using the `as_rate` path: divide errors by total at each point, then average the five ratios. Compare your result with what the monitor shows.
4. Calculate the DBA's result by hand using the `as_count` path: sum all errors, sum all totals, divide once. Compare your result with the 3% the DBA reported.
5. Look at the traffic pattern. Identify at least one interval with very high query volume and near-zero errors, and at least one with low volume and high error rate.

Before changing the monitor, deliver:

- a written proof showing the arithmetic for both paths using real numbers from Metrics Explorer
- a precise statement of what business question the `as_rate` path answers and what question the `as_count` path answers
- which one the customer's SLA should use and why, given that errors are concentrated in low-traffic intervals
- a customer-ready explanation that does not use the words "as_rate", "as_count", or "evaluation path"

Stretch challenge:

- Find the exact traffic pattern that maximises the divergence between the two paths. What ratio of burst volume to base volume makes the monitor value most misleading? Write the formula.

Expert defense:

- Explain what happens to the `as_count` path when the denominator is zero in one interval (no queries at all during that minute). Does the monitor alert, stay OK, or go to no-data? Prove your answer by temporarily stopping the load generator and observing the monitor status. What threshold strategy handles a zero-denominator safely?

---

## Bonus Challenges

1. Use DBM Query Samples to find a slow query and explain the query plan.
2. Create a composite monitor for high connection usage plus lock pressure.
3. Write a customer-facing explanation for why an always-red database monitor is not useful.

## Cleanup

```bash
docker compose down -v
./monitors/create_monitors.sh --cleanup
```
