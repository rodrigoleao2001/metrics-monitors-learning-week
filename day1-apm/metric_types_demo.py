"""
Metric Types Demo — sends the SAME values using the 5 DogStatsD submission types
so you can compare them side-by-side in Metrics Explorer / Metrics Summary.

DogStatsD submission types -> In-app types:
    GAUGE       -> GAUGE          (last value in flush interval)
    COUNT       -> COUNT/RATE     (sum of increments; queryable as .as_rate())
    SET         -> GAUGE          (count of unique values)
    HISTOGRAM   -> GAUGE (avg/max/median/p95), RATE (count), GAUGE (p95/p99)
    DISTRIBUTION-> DISTRIBUTION   (server-side percentiles, globally accurate)

Note: RATE is NOT a DogStatsD submission type — it is a Datadog in-app concept.
A COUNT metric becomes a "rate" by applying .as_rate() in a monitor/notebook query.
There is no 'r' wire type in the DogStatsD protocol.

Run inside the day1 environment:
    docker compose exec traffic-generator python /demo/metric_types_demo.py

Or locally (requires datadog package, agent running on localhost:8125):
    pip install datadog && DD_AGENT_HOST=localhost python metric_types_demo.py

Metrics created:
    metric_types_demo.gauge          type:gauge
    metric_types_demo.count          type:count
    metric_types_demo.set            type:set
    metric_types_demo.histogram      type:histogram
    metric_types_demo.distribution   type:distribution
"""

import time
import os
from datadog import initialize, statsd

initialize(
    statsd_host=os.getenv("DD_AGENT_HOST", "localhost"),
    statsd_port=int(os.getenv("DD_DOGSTATSD_PORT", "8125")),
)

COMMON_TAGS = ["env:learning-week", "day:1", "demo:metric-types"]

VALUES = [10, 50, 200, 500]

ROUNDS = 6
INTERVAL_BETWEEN_ROUNDS = 15  # seconds


def send_round(round_num):
    print(f"\n--- Round {round_num} ---")
    for v in VALUES:
        # GAUGE — submission type 'g'
        statsd.gauge(
            "metric_types_demo.gauge", v,
            tags=COMMON_TAGS + ["type:gauge"],
        )

        # COUNT — submission type 'c'
        statsd.increment(
            "metric_types_demo.count", v,
            tags=COMMON_TAGS + ["type:count"],
        )

        # SET — submission type 's'
        statsd.set(
            "metric_types_demo.set", v,
            tags=COMMON_TAGS + ["type:set"],
        )

        # HISTOGRAM — submission type 'h'
        statsd.histogram(
            "metric_types_demo.histogram", v,
            tags=COMMON_TAGS + ["type:histogram"],
        )

        # DISTRIBUTION — submission type 'd'
        statsd.distribution(
            "metric_types_demo.distribution", v,
            tags=COMMON_TAGS + ["type:distribution"],
        )

        print(f"  Sent value={v} to all 5 submission types")
        time.sleep(0.5)

    print(
        f"\n  Within this flush interval (10s), all 5 types received: {VALUES}\n"
        "  Investigate the resulting series in Metrics Explorer before drawing conclusions.\n"
    )


if __name__ == "__main__":
    print("=" * 60)
    print("  Metric Types Demo")
    print("  Sending the same values using 5 DogStatsD submission types:")
    print("  GAUGE, COUNT, SET, HISTOGRAM, DISTRIBUTION")
    print("  (RATE is an in-app concept, not a DogStatsD wire type)")
    print(f"  Values per round: {VALUES}")
    print(f"  Rounds: {ROUNDS} (every {INTERVAL_BETWEEN_ROUNDS}s)")
    print("=" * 60)

    for r in range(1, ROUNDS + 1):
        send_round(r)
        if r < ROUNDS:
            print(f"  Waiting {INTERVAL_BETWEEN_ROUNDS}s for next round...")
            time.sleep(INTERVAL_BETWEEN_ROUNDS)

    print("\nDone! Check Metrics Explorer for:")
    print("  - metric_types_demo.gauge")
    print("  - metric_types_demo.count  (query with .as_rate() to see rate behavior)")
    print("  - metric_types_demo.set")
    print("  - metric_types_demo.histogram.* (avg, max, median, p95, count)")
    print("  - metric_types_demo.distribution")
    print("\nCompare in Metrics Summary to see submission type vs in-app type.")
