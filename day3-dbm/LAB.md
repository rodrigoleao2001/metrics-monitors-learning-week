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

## Mission 2 - DB Session Spikes: Smoothed Out

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

## Mission 3 - DB Row Volume: All DBs Combined

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

## Bonus Challenges

1. Use DBM Query Samples to find a slow query and explain the query plan.
2. Create a composite monitor for high connection usage plus lock pressure.
3. Write a customer-facing explanation for why an always-red database monitor is not useful.

## Cleanup

```bash
docker compose down -v
./monitors/create_monitors.sh --cleanup
```
