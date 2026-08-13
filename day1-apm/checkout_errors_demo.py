"""
Checkout Errors Demo. Simulates failed checkouts on `flask-store` and emits
one COUNT increment per failure.

Metric created:
    flask_store.checkout_errors   COUNT, tags: env:learning-week, day:1,
                                  service:flask-store, resource_name:checkout,
                                  session_id

Run inside the day1 environment:
    docker compose exec traffic-generator python /demo/checkout_errors_demo.py

Env vars, all optional:
    ERROR_INTERVAL_SECONDS  seconds between simulated checkout errors, default 5
    TOTAL_RUNTIME_SECONDS   how long the script runs, default 3600
"""

import time
import os
import random
import string
from datadog import initialize, statsd

initialize(
    statsd_host=os.getenv("DD_AGENT_HOST", "localhost"),
    statsd_port=int(os.getenv("DD_DOGSTATSD_PORT", "8125")),
)

COMMON_TAGS = ["env:learning-week", "day:1", "service:flask-store", "resource_name:checkout"]

ERROR_INTERVAL_SECONDS = int(os.getenv("ERROR_INTERVAL_SECONDS", "5"))
TOTAL_RUNTIME_SECONDS = int(os.getenv("TOTAL_RUNTIME_SECONDS", "3600"))


def random_session_id():
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=8))


def main():
    print("=" * 60)
    print("  Checkout Errors Demo")
    print(f"  Emitting flask_store.checkout_errors every {ERROR_INTERVAL_SECONDS}s")
    print("  Tags: env, day, service, resource_name:checkout, session_id")
    print("=" * 60)

    start = time.time()

    while time.time() - start < TOTAL_RUNTIME_SECONDS:
        session_id = random_session_id()
        statsd.increment(
            "flask_store.checkout_errors", 1,
            tags=COMMON_TAGS + [f"session_id:{session_id}"],
        )
        time.sleep(ERROR_INTERVAL_SECONDS)

    print("\nDone.")


if __name__ == "__main__":
    main()
