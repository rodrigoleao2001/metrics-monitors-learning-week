"""
Monitor Concepts Demo. Sends a single gauge metric tagged by `sim_host`, a
fictitious host tag. A brand new host joins every HOST_INTERVAL_SECONDS, up to
MAX_HOSTS total. Once a host joins, it keeps sending for the rest of the run.

The tag is `sim_host` rather than `host`, because `host` is a reserved Datadog
tag that maps to real Infrastructure hosts, and a custom tag avoids creating
fake entries in Infrastructure and Fleet Automation.

This is a facilitator teaching aid rather than a lab mission. It backs the
monitor named `[Day1] DEMO - Monitor Evaluation Concepts`, which is grouped
`by {sim_host}` so a new alert group appears on a rolling basis while the
session runs.

Metric created:
    monitor_concepts_demo.request_duration   GAUGE, tags: sim_host

Run inside the day1 environment:
    docker compose exec traffic-generator python /demo/monitor_concepts_demo.py

Optional env vars:
    HOST_INTERVAL_SECONDS  seconds between each new fictitious host joining, default 30
    MAX_HOSTS              how many fictitious hosts to grow to before stopping, default 20
    TOTAL_RUNTIME_SECONDS  how long the script runs, default 3600
"""

import time
import os
from datadog import initialize, statsd

initialize(
    statsd_host=os.getenv("DD_AGENT_HOST", "localhost"),
    statsd_port=int(os.getenv("DD_DOGSTATSD_PORT", "8125")),
)

COMMON_TAGS = ["env:learning-week", "day:1", "demo:monitor-concepts"]

HOST_INTERVAL_SECONDS = int(os.getenv("HOST_INTERVAL_SECONDS", "30"))
MAX_HOSTS = int(os.getenv("MAX_HOSTS", "20"))
TOTAL_RUNTIME_SECONDS = int(os.getenv("TOTAL_RUNTIME_SECONDS", "3600"))
SEND_INTERVAL_SECONDS = 10

VALUE = 0.3  # stays under the monitor's warning/critical thresholds on purpose


def main():
    print("=" * 60)
    print("  Monitor Concepts Demo")
    print(f"  A new sim_host joins every {HOST_INTERVAL_SECONDS}s, up to {MAX_HOSTS} hosts")
    print("  Backs the monitor named [Day1] DEMO - Monitor Evaluation Concepts")
    print("=" * 60)

    start = time.time()
    active_hosts = 0

    while time.time() - start < TOTAL_RUNTIME_SECONDS:
        elapsed = time.time() - start

        expected_hosts = min(MAX_HOSTS, int(elapsed // HOST_INTERVAL_SECONDS) + 1)
        if expected_hosts > active_hosts:
            active_hosts = expected_hosts
            print(
                f"\n  sim_host:host-{active_hosts:02d} joined at {int(elapsed)}s, "
                f"total hosts now {active_hosts}\n"
            )

        for i in range(1, active_hosts + 1):
            statsd.gauge(
                "monitor_concepts_demo.request_duration", VALUE,
                tags=COMMON_TAGS + [f"sim_host:host-{i:02d}"],
            )

        time.sleep(SEND_INTERVAL_SECONDS)

    print("\nDone.")


if __name__ == "__main__":
    main()
