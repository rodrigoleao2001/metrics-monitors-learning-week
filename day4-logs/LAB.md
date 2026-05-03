# Day 4 - Logs: The Log Flood

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

Learn how log query precision, facets, grouping, renotification, routing, and log-based metrics affect alert quality.

## Concepts

- Text search vs structured facets
- Group-by strategy and alert storms
- Renotification and escalation
- Log monitors vs log-based metrics
- Alert message and routing quality

## Scenario

You support several microservices that generate realistic log patterns. Four log monitors were intentionally created with common mistakes.

## Setup

```bash
cd day4-logs/
docker compose up -d --build
docker compose exec datadog-agent agent status | grep -A 5 "Logs Agent"
docker compose logs log-generator-app --tail 10
chmod +x monitors/create_monitors.sh
./monitors/create_monitors.sh
```

Check:

- Logs > Search: filter `host:learning-week-logs`
- Logs > Analytics
- Monitors > Manage: filter `tag:learning-week:day4-logs`

---

## Mission 1 - Error Log Alert: Catches Everything

The monitor fires constantly. Are all matches real errors?

Starting points:

1. Compare text search with structured filters.
2. Inspect examples that matched the query.
3. Decide which attributes should be facets.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Build a precise query that detects one failure mode, not every line containing a word.

Expert defense:

- Explain how your query behaves if a debug log mentions the word "error".

---

## Mission 2 - Service Error Rate: Alert Storm

One monitor creates too many alert groups.

Starting points:

1. Inspect the group-by dimensions.
2. Estimate the number of possible groups.
3. Decide which group maps to first response ownership.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Compare grouping by service, host, region, and error type.

Expert defense:

- Explain when a second high-cardinality monitor would be useful as non-paging visibility.

---

## Mission 3 - Critical Log Watch: Inbox Flood

The alert routing and repeat behavior are not humane.

Starting points:

1. Inspect routing targets.
2. Inspect renotification and escalation settings.
3. Decide who needs the first page and who only needs escalation.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Design first notification, renotification, escalation, and recovery messages.

Expert defense:

- Explain how to avoid both silence and notification spam.

---

## Mission 4 - Log Volume: Static Count

The monitor alerts because there are many logs. Does volume equal impact?

Starting points:

1. Inspect what log levels and services are counted.
2. Compare absolute volume with baseline and error type diversity.
3. Decide whether a log monitor or log-based metric is better.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Propose one log monitor and one log-based metric design.

Expert defense:

- Explain the cost and retention trade-off.

## Bonus Challenges

1. Create a log pipeline that extracts `correlation_id` and normalizes duration.
2. Create a log-based metric for error count by service and region.
3. Design an exclusion filter and explain what cost it saves and what it does not save.
4. Expert: write a monitor message that includes sample logs without overwhelming the on-call.

## Cleanup

```bash
docker compose down -v
./monitors/create_monitors.sh --cleanup
```
