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

## Format: One Shared Org, One Slack Channel, One Complete Ticket

This lab runs as a single scenario for the whole group, not a set of small blind cards.

- Only **one** member of the group runs the environment (`docker compose up` above), in their own org. Everyone else connects through that same org and the shared Slack channel, they do not each run their own copy.
- Split into **Customer** and **Support**. The Customer side gets the complete ticket text below, in full, right away, including a link to the specific broken monitor and a documentation link. There is no vague-first-then-reveal step here, the whole complaint is posted to the shared Slack channel at once, exactly like a real ticket.
- Support receives that same complete message in Slack and works the case from there: asking follow-up questions back in the channel, checking the real data in the shared org, testing hypotheses, and proposing a fix. Support should not just read the query and announce the answer, the point is to work it the way a real ticket gets worked, evidence first.
- There is exactly **one** monitor behind this whole scenario, with one complete, combined, real-world-shaped problem, not several small separate ones.

## Customer Role

Post this complete message into the shared Slack channel, filling in the monitor link from your shared org:

> Hey team, CS keeps escalating payment failure complaints from customers, pretty steady all week across several regions and payment methods, but **[Day5-A] Payment Failure Watch** has barely moved the whole time. Monitor: `[PASTE THE MONITOR URL FROM YOUR SHARED ORG HERE]`. We think it might be about how we are tracking these failures, here is the docs page we were looking at: https://docs.datadoghq.com/metrics/types/. Can someone take a look?

## Support Role

Receive that complete ticket in Slack and:

1. Ask clarifying questions back in the channel: how often, which regions or payment methods, roughly how many real CS tickets versus what the monitor shows.
2. Investigate with Metrics Explorer, the monitor's exact query, and the metric's real DogStatsD submission type.
3. Identify everything the current monitor gets wrong, there is more than one thing.
4. Propose a fix, including anything that needs to change at the metric-submission level, not just the query.
5. Explain the fix in customer language.

Before proposing a fix, deliver:

- everything the current monitor gets wrong, in your own words
- one rejected alternative hypothesis
- two possible fixes and the trade-off between them
- the evidence that made you choose one
- the final customer explanation

## Role Swap

After this round, swap: whoever played Support here plays Customer for Lab B, and vice versa, so everyone works both sides once across the two labs.

## Cleanup

```bash
docker compose down -v
./monitors/create_monitors.sh --cleanup
```
