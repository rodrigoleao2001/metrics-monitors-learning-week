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

You support several microservices that generate realistic log patterns. Every log monitor in this lab was intentionally created with a common mistake.

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

- Logs > Search: filter `container_name:(log-generator-app OR nginx-proxy-day4 OR log-spammer-day4)`
- Logs > Analytics
- Monitors > Manage: filter `tag:learning-week:day4-logs`

---

## Mission 1 - Error Log Alert: Broad Match

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

## Mission 2 - Service Error Rate: Group Check

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

## Mission 4 - Log Volume: Baseline Check

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

---

## Mission 5 - Critical Error Watch: Evaluation Check

This monitor has never alerted. Logs Search shows that critical events did happen.

Starting points:

1. Open `[Day4] Critical Error Watch - Evaluation Check` and read its status history.
2. Search `status:critical` in Logs Search and confirm for yourself that the events exist.
3. Chart those events over time and describe the shape of the signal you get.
4. Reconcile the two facts: real critical events in the logs, no alert from the monitor.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Design a detection for this signal that pages on the first real event and stays quiet the rest of the time.

Expert defense:

- Explain how you would size an alerting condition for an event whose frequency you have not measured yet.

---

## Mission 6 - Payment Retry Storm: Notification Check

The monitor correctly detects a real payment gateway problem, but something about who gets paged does not add up.

Starting points:

1. Open `[Day4] Payment Retry Storm - Notification Check`.
2. Search the matching logs and identify which service and error type they belong to.
3. Inspect who the monitor message notifies.
4. Decide whether that audience can act on this specific failure.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Design a routing rule that pages the right team first and still keeps a secondary audience informed.

Expert defense:

- Explain how a correct detection with the wrong routing can be worse than no alert at all.

## Mission 7 - Scheduled Downtime: The Maintenance Window Problem

Every Sunday at 02:00 the batch job runs and triggers four monitors simultaneously. The on-call gets woken up every week. The fix is not to raise the thresholds.

Starting points:

1. Identify which of the Day 4 monitors would fire during a period of intentionally high log volume.
2. Design a scheduled downtime: pick the scope (which monitors, which tags), the start time, the duration, and the recurrence pattern.
3. Create the downtime in the Datadog UI under Monitors > Manage Downtime.
4. Read back the downtime configuration and verify the scope is exactly as narrow as you intended.

Before creating the downtime, deliver:

- the exact scope of the downtime and why anything broader creates risk
- one scenario where this downtime would silence a real incident and how you would detect it
- the difference between muting a monitor and scheduling a downtime, and when each is appropriate
- a customer-ready explanation of why the on-call should not raise the threshold as an alternative

Stretch challenge:

- Design a monitor that pages if no downtime exists for Sunday at 02:00 and the batch volume monitor is in Alert state. Explain the failure mode this covers.

Expert defense:

- Explain what happens to alert notifications that were already triggered before the downtime window starts. Does creating the downtime retroactively suppress those notifications? What is the operational consequence?

---

## Mission 8 - Exclusion Filter vs Monitor Coverage

The log volume from debug-level traffic represents 70% of the total ingested log volume and contributes nothing to any monitor. Excluding it would reduce cost significantly. The risk is losing signal.

Starting points:

1. Go to Logs > Configuration > Exclusion Filters and inspect any existing filters.
2. In Log Explorer, filter to `status:debug` and check which services are generating the volume and whether any of the Day 4 monitors depend on debug logs.
3. Propose an exclusion filter that targets debug logs from specific services only, not all debug logs globally.
4. Write the filter query and estimate what percentage of total volume it removes.

Before creating the filter, deliver:

- a list of every Day 4 monitor query that would be affected by the proposed exclusion
- one scenario where debug logs are the only evidence of an incident and would be lost
- two filter designs with different scope and the trade-off in cost savings vs signal coverage
- a customer-ready explanation of the difference between exclusion filters and log archive retention

Stretch challenge:

- Design an approach that excludes debug logs from billing but retains them in an archive for 15 days. Explain what products and configurations this requires.

Expert defense:

- Explain what happens to a log-based metric that counts debug logs if an exclusion filter removes those logs before they are indexed. Are the metric counts affected? Why or why not?

---

## Mission 9 - Log Pipeline Quality: When Parsing Breaks

Logs from the nginx proxy stopped being parsed correctly 30 minutes ago. Status is `info` on every log. No monitor fired. Errors are invisible.

Starting points:

1. Go to Logs > Search and filter to `service:nginx-proxy-day4`. Check the `status` field distribution.
2. Compare the `status` field value with the raw log content of several recent logs. Are the status values correct?
3. Inspect the log pipeline in Logs > Configuration > Pipelines and find the Grok parser or status remapper for this service.
4. Identify the parsing failure: a format change in the log output that the Grok pattern no longer matches.

Before proposing a fix, deliver:

- the exact mismatch between the current log format and the existing Grok pattern
- one rejected alternative explanation (e.g., the service stopped logging errors vs the parser broke)
- how you would detect this class of failure with a monitor before anyone notices manually
- a customer-ready explanation of why log-based monitors can miss real errors when the pipeline breaks

Stretch challenge:

- Design a monitor that detects pipeline degradation: a sudden drop in logs with `status:error` when error volume historically never goes to zero. Explain how you size the threshold without knowing the baseline.

Expert defense:

- Explain the difference between a Grok parser failure (log arrives with wrong status) and a log not arriving at all. Do both look the same in a log count monitor? How would you distinguish them?

---

## Mission 10 - Log-Based Metric SLO: Turning Logs into an SLO

The payment service has no SLO. The only signal is a log line: `payment processed successfully` or `payment failed`. Build an SLO from these logs without modifying the application.

Starting points:

1. Go to Logs > Configuration > Log-Based Metrics and create two metrics:
   - `payment.requests.total` counting all payment logs from the payment service
   - `payment.requests.errors` counting only logs that match a payment failure pattern
2. Wait 2-3 minutes and confirm the metrics appear in Metrics Explorer.
3. Create a request-based SLO using these two metrics as total and bad events.
4. Set a 99% target over 7 days and observe the current error budget.

Before presenting the SLO, deliver:

- why a log-based metric SLO and a monitor-based SLO for the same service would give different results
- one risk in using log volume as the denominator of an SLO (what happens if the app stops logging?)
- the minimum logging rate needed for this SLO to be statistically meaningful at a 1-hour burn rate window
- a customer-ready explanation of what the SLO means to a business stakeholder who does not know what a log is

Stretch challenge:

- Propose a composite signal: the SLO uses log-based metrics for normal traffic and falls back to APM trace metrics when log volume drops below a minimum. Explain the architecture.

Expert defense:

- Explain what happens to the SLO error budget when the log pipeline breaks and all logs are classified as `status:info` instead of `status:error`. Does the SLO become more or less accurate? How would you detect this SLO blindness?

---

## Bonus Challenges

1. Create a log pipeline that extracts `correlation_id` and normalizes duration.
2. Expert: write a monitor message that includes sample logs without overwhelming the on-call.

## Cleanup

```bash
docker compose down -v
./monitors/create_monitors.sh --cleanup
```
