# Day 5 - Lab A: Brazil Ecommerce

## Hard Mode Rules

This lab is a real-case simulation. The student guide does not contain the final diagnosis.

- Start with a hypothesis before editing a monitor.
- For each ticket, propose two possible fixes and choose one.
- Document one rejected hypothesis.
- Show evidence: query, graph, screenshot, or sample.
- Explain the trade-off: detection, noise, cardinality, routing, and customer clarity.

## Difficulty Ladder

- **Core path:** clarify the customer complaint, identify the hidden segment, and fix one monitor.
- **Stretch challenge:** compare a segment-specific fix with a multi-alert fix.
- **Expert defense:** explain whether the underlying metric submission, query, monitor options, or message should change first.

## Scenario

You support a Brazilian ecommerce platform that submits custom metrics through DogStatsD.

## Available Metrics

| Metric | Type | Tags |
|--------|------|------|
| `ecommerce.orders.count` | count | `region`, `payment_method`, `category` |
| `ecommerce.payment.latency.*` | histogram | `region`, `payment_method` |
| `ecommerce.cart.abandonment` | gauge | `region`, `device` |
| `ecommerce.revenue.total` | count | `region`, `category` |
| `ecommerce.inventory.stock_level` | gauge | `product_id` |
| `ecommerce.failed_payments` | custom | `region`, `payment_method` |

## Investigative Case

Several problems are happening. The monitors do not detect them correctly.

Your job is not to guess the issue. Your job is to investigate:

1. Start from the customer complaint.
2. Confirm whether the current monitor represents the reported experience.
3. Compare at least two ways to segment the signal.
4. Test whether the problem is metric submission, query shape, monitor settings, or message quality.
5. Defend one solution and explain why it is better than the alternative.

## Setup

```bash
cd day5-dynamic/lab-a-ecommerce/
docker compose up -d --build
docker compose exec datadog-agent agent status | grep -A 5 "DogStatsD"
chmod +x monitors/create_monitors.sh
./monitors/create_monitors.sh
```

## Customer Role

The facilitator will give you a scenario card. Write a vague support ticket from that card.

Do not reveal the region, payment method, device, category, or metric type immediately. Reveal details only when the support engineer asks precise questions.

## Support Engineer Role

Receive the ticket and:

1. Clarify scope, timeframe, impact, and dimensions.
2. Investigate with Metrics Explorer, dashboards, and existing monitors.
3. Identify what the current monitor misses.
4. Propose two monitor or metric fixes.
5. Explain the chosen fix in customer language.

Do not read the customer's scenario card.

Before changing any monitor, deliver:

- what the current monitor misses
- one rejected alternative hypothesis
- two possible fixes
- why you chose one fix
- the final customer explanation

## Mission 1 - Refunds Total: Consistency Check

Finance says the refund numbers on the monitor do not match what they see on the business dashboard, even though the application always emits the same four values in every batch.

Starting points:

1. Open the monitor named `[Day5-A] Refunds Total`.
2. Compare `ecommerce.refunds_varied.gauge_demo`, `ecommerce.refunds_varied.count_demo`, and `ecommerce.refunds_varied.histogram_demo` in Metrics Explorer for the same time window.
3. Confirm that the application sends the same four values, 10, 50, 200, and 500, through all three submission types in every batch.
4. Decide which submission type and statistic actually answers the business question Finance is asking.

Before changing the monitor, deliver:

- the current monitor flaw in one sentence
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose the final fix
- a customer-ready explanation

Metrics to compare:

| Metric | DogStatsD type | Investigation question |
|--------|----------------|------------------------|
| `ecommerce.refunds_varied.gauge_demo` | gauge | Which value survives the flush? |
| `ecommerce.refunds_varied.count_demo` | count | Does the Agent sum events or keep the last value? |
| `ecommerce.refunds_varied.histogram_demo.avg` | histogram | Which statistic describes the center? |
| `ecommerce.refunds_varied.histogram_demo.max` | histogram | Which statistic preserves the worst value? |
| `ecommerce.refunds_varied.histogram_demo.count` | histogram | How do you prove how many samples entered the flush? |

Stretch challenge:

- Design a single dashboard widget that shows the real refund volume without anyone needing to know DogStatsD internals. Defend why gauge, count, or histogram is the right submission type for this specific business question.

Expert defense:

- Explain why the wrong submission type can make a monitor look correct while the business sees failures.
- Explain how you would validate the fix after changing the application code.

## Cleanup

```bash
docker compose down -v
./monitors/create_monitors.sh --cleanup
```
