"""
Orders Reconciliation Demo. Emits a custom count metric for an order
reconciliation batch job, submitted through the Datadog Metrics API.

Metric emitted:
    postgres_app.orders_reconciled_total   count, one point per send interval.
                                           The value is the number of orders
                                           reconciled during that interval, not
                                           a running total.

Run:
    The reconciliation-demo service starts automatically with the rest of the
    day 3 environment, so there is nothing to launch by hand. To watch what it
    submits:
        docker compose logs -f reconciliation-demo

Required env vars:
    DD_API_KEY              Datadog API key used to submit the metric

Optional env vars:
    DD_SITE                 Datadog site, default datadoghq.com
    LAG_SECONDS             point timestamp offset in seconds, default 720
    SEND_INTERVAL_SECONDS   seconds between submissions, default 60
    TOTAL_RUNTIME_SECONDS   how long the script runs, default 3600
"""

import time
import os
import requests

DD_API_KEY = os.getenv("DD_API_KEY", "").strip()
DD_SITE = os.getenv("DD_SITE", "datadoghq.com")

LAG_SECONDS = int(os.getenv("LAG_SECONDS", "720"))
SEND_INTERVAL_SECONDS = int(os.getenv("SEND_INTERVAL_SECONDS", "60"))
TOTAL_RUNTIME_SECONDS = int(os.getenv("TOTAL_RUNTIME_SECONDS", "3600"))

METRIC_NAME = "postgres_app.orders_reconciled_total"
METRIC_TYPE_COUNT = 1
ORDERS_PER_INTERVAL = 1
TAGS = ["env:learning-week", "day:3", "demo:reconciliation"]


def submit_point(timestamp, value):
    payload = {
        "series": [
            {
                "metric": METRIC_NAME,
                "type": METRIC_TYPE_COUNT,
                "points": [{"timestamp": timestamp, "value": value}],
                "tags": TAGS,
            }
        ]
    }
    response = requests.post(
        f"https://api.{DD_SITE}/api/v2/series",
        json=payload,
        headers={"DD-API-KEY": DD_API_KEY, "Content-Type": "application/json"},
        timeout=10,
    )
    if not 200 <= response.status_code < 300:
        raise RuntimeError(
            f"Metric submission to api.{DD_SITE} failed with HTTP "
            f"{response.status_code}: {response.text.strip()}"
        )
    return response.status_code


def main():
    if not DD_API_KEY:
        raise SystemExit(
            "ERROR: DD_API_KEY is empty or unset, so no metric can be submitted.\n"
            "Set DD_API_KEY in the Learning Week .env file, then restart the day 3 "
            "environment with: docker compose up -d"
        )

    print("=" * 60)
    print("  Orders Reconciliation Demo")
    print(f"  Metric: {METRIC_NAME}")
    print(f"  Send interval: {SEND_INTERVAL_SECONDS}s")
    print("=" * 60)

    start = time.time()
    total_reconciled = 0

    while time.time() - start < TOTAL_RUNTIME_SECONDS:
        now = int(time.time())
        point_timestamp = now - LAG_SECONDS
        reconciled_this_interval = ORDERS_PER_INTERVAL
        total_reconciled += reconciled_this_interval

        status = submit_point(point_timestamp, reconciled_this_interval)
        print(
            f"  Submitted {reconciled_this_interval} at timestamp {point_timestamp}, "
            f"status {status}, running total {total_reconciled}"
        )

        time.sleep(SEND_INTERVAL_SECONDS)

    print("\nDone.")


if __name__ == "__main__":
    main()
