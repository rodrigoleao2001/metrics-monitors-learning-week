#!/usr/bin/env python3
"""
Catalog Sync Demo. Emits a metric that is mostly continuous but drops out
briefly and repeatedly, the way a collector that misses an interval does.

    flask_store.batch_sync_records   GAUGE, tags: env, day, service, job

The shape is the point. The sync worker reports its throughput every
REPORT_INTERVAL seconds while it runs, then pauses for DROPOUT_SECONDS when it
rotates its database connection, then resumes. Nothing is broken during the
pause: this is what the signal looks like when the job is healthy.

That shape matters for monitors. An evaluation window that happens to fall
entirely inside a reporting stretch is complete; a window that overlaps a pause
is not. A monitor with require_full_window enabled therefore evaluates for some
windows and silently skips others, which looks nothing like a monitor that is
simply broken.

Environment:
    REPORT_INTERVAL        seconds between points while reporting, default 15
    CYCLE_SECONDS          seconds from one pause to the next, default 1200
    DROPOUT_SECONDS        length of each pause, default 60
    RECORDS_MIN/MAX        record count emitted per point
    TOTAL_RUNTIME_SECONDS  how long this process runs before exiting, default 3600
"""

import os
import random
import time

from datadog import DogStatsd

STATSD_HOST = os.getenv("DD_AGENT_HOST", "localhost")
COMMON_TAGS = [
    "env:learning-week",
    "day:1",
    "service:flask-store",
    "job:catalog-sync",
]

REPORT_INTERVAL = int(os.getenv("REPORT_INTERVAL", "15"))
CYCLE_SECONDS = int(os.getenv("CYCLE_SECONDS", "1200"))
DROPOUT_SECONDS = int(os.getenv("DROPOUT_SECONDS", "60"))
RECORDS_MIN = int(os.getenv("RECORDS_MIN", "800"))
RECORDS_MAX = int(os.getenv("RECORDS_MAX", "1200"))
TOTAL_RUNTIME_SECONDS = int(os.getenv("TOTAL_RUNTIME_SECONDS", "3600"))

statsd = DogStatsd(host=STATSD_HOST, port=8125)


def main():
    reporting = CYCLE_SECONDS - DROPOUT_SECONDS
    print("Catalog Sync Demo")
    print(f"  Agent: {STATSD_HOST}:8125")
    print(f"  Reports every {REPORT_INTERVAL}s for {reporting}s, "
          f"then pauses {DROPOUT_SECONDS}s")
    print(f"  Metric: flask_store.batch_sync_records")
    print(f"  Tags: {', '.join(COMMON_TAGS)}")
    print("")

    start = time.time()
    cycle = 0
    while time.time() - start < TOTAL_RUNTIME_SECONDS:
        cycle += 1
        stretch_start = time.time()
        points = 0
        while time.time() - stretch_start < reporting:
            if time.time() - start >= TOTAL_RUNTIME_SECONDS:
                break
            statsd.gauge("flask_store.batch_sync_records",
                         random.randint(RECORDS_MIN, RECORDS_MAX),
                         tags=COMMON_TAGS)
            points += 1
            time.sleep(REPORT_INTERVAL)

        remaining = TOTAL_RUNTIME_SECONDS - (time.time() - start)
        if remaining <= 0:
            break
        print(f"  cycle {cycle}: sent {points} points, "
              f"pausing {DROPOUT_SECONDS}s for connection rotation")
        time.sleep(min(DROPOUT_SECONDS, remaining))


if __name__ == "__main__":
    main()
