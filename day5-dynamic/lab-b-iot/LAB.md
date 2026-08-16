# Day 5 - Lab B: Farm IoT Sensors

## Hard Mode Rules

This lab is a real-case simulation. The student guide does not contain the final diagnosis.

- Start with a hypothesis before editing a monitor.
- For each ticket, propose two possible fixes and choose one.
- Document one rejected hypothesis.
- Show evidence: query, graph, screenshot, or sample.
- Explain the trade-off: detection, noise, cardinality, routing, and customer clarity.

## Difficulty Ladder

- **Core path:** clarify the customer complaint, identify the affected zone or sensor, and fix one monitor.
- **Stretch challenge:** compare a static threshold, grouped monitor, outlier monitor, or forecast-style design.
- **Expert defense:** explain which design would still be noisy or blind in production and how you would validate it.

## Scenario

You support IoT sensors for a farm. Metrics are submitted through DogStatsD.

## Available Metrics

| Metric | Type | Tags |
|--------|------|------|
| `iot.sensor.temperature` | gauge | `sensor_id`, `zone` |
| `iot.sensor.humidity` | gauge | `sensor_id`, `zone` |
| `iot.sensor.battery` | gauge | `sensor_id`, `zone` |
| `iot.sensor.readings.count` | count | `sensor_id`, `zone` |
| `iot.sensor.signal_strength` | gauge | `sensor_id`, `zone` |

## Zones

| Zone | Normal behavior | What to think about |
|------|-----------------|---------------------|
| `greenhouse` | controlled temperature | local spikes can matter |
| `field` | wider environmental variation | peers may be more useful than one static threshold |
| `storage` | refrigerated and sensitive | missing data can be operationally important |

## Investigative Case

Several problems are happening. The monitors do not detect them correctly.

Your job is not to guess the issue. Your job is to investigate:

1. Start from the customer complaint.
2. Confirm whether the current monitor represents the operational risk.
3. Compare at least two ways to segment the signal.
4. Test whether the issue is metric type, query shape, monitor type, evaluation window, or message quality.
5. Defend one solution and explain why it is better than the alternative.

## Setup

```bash
cd day5-dynamic/lab-b-iot/
docker compose up -d --build
chmod +x monitors/create_monitors.sh
./monitors/create_monitors.sh
```

## Format: One Shared Org, One Slack Channel, One Complete Ticket

This lab runs as a single scenario for the whole group, not a set of small blind cards. If you played Support for Lab A, play Customer here, and vice versa.

- Only **one** member of the group runs the environment (`docker compose up` above), in their own org. Everyone else connects through that same org and the shared Slack channel.
- The Customer side gets the complete ticket text below, in full, right away, including a link to the specific broken monitor and a documentation link. The whole complaint is posted to the shared Slack channel at once, exactly like a real ticket.
- Support receives that same complete message in Slack and works the case from there: asking follow-up questions back in the channel, checking the real data in the shared org, testing hypotheses, and proposing a fix.
- There is exactly **one** monitor behind this whole scenario, with one complete, combined, real-world-shaped problem, not several small separate ones.

## Customer Role

Post this complete message into the shared Slack channel, filling in the monitor link from your shared org:

> Hey, the refrigeration team says they keep losing sensor data in the storage zone, sometimes for stretches at a time, but **[Day5-B] Storage Sensor Uptime** has never once fired the whole time this has been happening. Monitor: `[PASTE THE MONITOR URL FROM YOUR SHARED ORG HERE]`. Reference doc we found: https://docs.datadoghq.com/monitors/configuration/. Can someone take a look?

## Support Role

1. Ask clarifying questions back in the channel: which sensors, how often, for how long each time.
2. Investigate metrics grouped by `zone` and `sensor_id`, and the monitor's exact query and evaluation options.
3. Identify everything the current monitor gets wrong, there is more than one thing.
4. Propose a fix.
5. Explain the fix in simple customer language.

Before proposing a fix, deliver:

- everything the current monitor gets wrong, in your own words
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose one
- the final customer explanation

## Extra Investigation - Outliers

Use this reasoning if one sensor looks different from its peers:

- What is the correct peer group?
- Is the problem an absolute bad value or a source behaving differently from neighbors?
- Would a static threshold work without false positives?
- Which monitor type best captures "this member of the group is different"?

## Extra Investigation - Forecast

Use this reasoning if the problem is predictable before it becomes urgent:

- Does the metric have a stable enough trend?
- Does the team need reactive alerting, preventive alerting, or both?
- How much lead time is actionable?
- What evidence proves forecast is better than a simple threshold?
- What would you pair with forecast so the team still catches immediate failures?

## Cleanup

```bash
docker compose down -v
./monitors/create_monitors.sh --cleanup
```
