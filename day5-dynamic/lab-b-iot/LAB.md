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

## Customer Role

The facilitator will give you a scenario card. Write a vague support ticket from that card.

Do not reveal the zone, sensor, failure pattern, or expected monitor type immediately. Reveal details only when the support engineer asks precise questions.

## Support Engineer Role

1. Clarify zone, sensor, timeframe, and impact.
2. Investigate metrics grouped by `zone` and `sensor_id`.
3. Identify what the current monitors miss.
4. Propose two monitor designs before choosing one.
5. Explain the fix in simple customer language.

Do not read the customer's scenario card.

Before changing any monitor, deliver:

- what the current monitor misses
- one rejected alternative hypothesis
- two possible fixes
- why you chose one fix
- the final customer explanation

## Mission 1 - Field Zone Temperature: Sensor Check

This mission is a direct technical exercise, not a customer role card.

The field zone monitor looks fine most of the time, but the operators keep reporting a problem in that zone that it never catches.

Starting points:

1. Open `[Day5-B] Field Zone Temperature - Sensor Check`.
2. Read the query and write down exactly which sensors it covers and what it does with their readings.
3. Plot `iot.sensor.temperature{zone:field}` in Metrics Explorer and break it down until you can see the sensors apart from each other.
4. Decide what the number the monitor evaluates is not telling you about that zone.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Stretch challenge:

- Propose a design that still gives the operators one zone-level view without letting any single source disappear inside it.

Expert defense:

- Explain how you would tell a genuinely hot sensor apart from a sensor sending invalid readings.

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
