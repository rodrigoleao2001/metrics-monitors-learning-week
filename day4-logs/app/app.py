"""
Log-generating application for Day 4 — Logs Lab.
Generates structured JSON logs with various patterns:
- Normal operation logs (INFO)
- Retry storms (ERROR bursts from a specific service)
- Slow queries (WARN)
- Authentication failures (ERROR with specific pattern)
- Periodic DEBUG spam
"""

import json
import random
import sys
import time
import logging

SERVICES = ["auth-service", "payment-service", "order-service", "notification-service", "inventory-service"]
REGIONS = ["br-south", "br-southeast", "br-northeast"]
ENVIRONMENTS = ["production"]


def structured_log(level, message, service, **extra):
    log_entry = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S.000Z", time.gmtime()),
        "level": level,
        "service": service,
        "region": random.choice(REGIONS),
        "env": "production",
        "message": message,
        "host": f"app-{random.randint(1, 5):02d}",
    }
    log_entry.update(extra)
    print(json.dumps(log_entry), flush=True)


def normal_operation():
    """Regular INFO/DEBUG logs from all services."""
    messages = [
        ("INFO", "Request processed successfully", {"duration_ms": random.randint(5, 200), "status_code": 200}),
        ("INFO", "Cache hit", {"cache_key": f"product:{random.randint(1, 100)}", "ttl_remaining": random.randint(10, 300)}),
        ("INFO", "Database query completed", {"query_time_ms": random.randint(1, 50), "rows_returned": random.randint(1, 100)}),
        ("DEBUG", "Health check passed", {"uptime_seconds": random.randint(1000, 86400)}),
        ("DEBUG", "Connection pool stats", {"active": random.randint(1, 10), "idle": random.randint(0, 5), "max": 20}),
    ]
    level, msg, extra = random.choice(messages)
    structured_log(level, msg, random.choice(SERVICES), **extra)


def retry_storm():
    """
    Simulates a retry storm from payment-service.
    When a downstream service times out, the client retries aggressively,
    generating a burst of ERROR logs.
    """
    retry_count = random.randint(5, 15)
    correlation_id = f"txn-{random.randint(10000, 99999)}"
    for attempt in range(1, retry_count + 1):
        structured_log(
            "ERROR",
            f"Payment gateway timeout - retry attempt {attempt}/{retry_count}",
            "payment-service",
            error_type="TimeoutError",
            correlation_id=correlation_id,
            retry_attempt=attempt,
            max_retries=retry_count,
            gateway="stripe-br",
            duration_ms=random.randint(5000, 30000),
        )
        time.sleep(random.uniform(0.1, 0.3))


def auth_failures():
    """Burst of authentication failures — could be a brute force attack or misconfigured service."""
    user_ids = [f"user-{random.randint(1, 50)}" for _ in range(random.randint(3, 10))]
    for uid in user_ids:
        structured_log(
            "ERROR",
            "Authentication failed - invalid credentials",
            "auth-service",
            error_type="AuthenticationError",
            user_id=uid,
            ip_address=f"192.168.{random.randint(1, 254)}.{random.randint(1, 254)}",
            status_code=401,
        )
        time.sleep(random.uniform(0.05, 0.15))


def slow_query_warnings():
    """Warnings about slow database queries."""
    tables = ["orders", "customers", "products", "inventory_log"]
    operations = ["SELECT", "UPDATE", "INSERT"]
    structured_log(
        "WARN",
        f"Slow query detected: {random.choice(operations)} on {random.choice(tables)}",
        random.choice(["order-service", "inventory-service"]),
        query_time_ms=random.randint(500, 5000),
        table=random.choice(tables),
        rows_affected=random.randint(1, 10000),
    )


def debug_spam():
    """Excessive DEBUG logs that add volume without value."""
    for _ in range(random.randint(10, 30)):
        structured_log(
            "DEBUG",
            f"Metric checkpoint: memory_usage={random.randint(50, 95)}% cpu={random.uniform(0.1, 2.0):.2f}",
            random.choice(SERVICES),
            metric_type="internal",
        )
        time.sleep(0.02)


def critical_errors():
    """Rare but critical errors that should always be caught."""
    errors = [
        ("Database connection lost", "ConnectionError", "order-service"),
        ("Out of memory in worker process", "MemoryError", "inventory-service"),
        ("SSL certificate expired for downstream service", "SSLError", "payment-service"),
    ]
    msg, err_type, svc = random.choice(errors)
    structured_log(
        "CRITICAL",
        msg,
        svc,
        error_type=err_type,
        stack_trace="...(truncated)...",
    )


if __name__ == "__main__":
    print(json.dumps({"level": "INFO", "message": "Log generator started", "service": "log-generator"}), flush=True)
    time.sleep(5)

    while True:
        r = random.random()
        if r < 0.50:
            normal_operation()
        elif r < 0.60:
            retry_storm()
        elif r < 0.70:
            auth_failures()
        elif r < 0.80:
            slow_query_warnings()
        elif r < 0.90:
            debug_spam()
        elif r < 0.95:
            critical_errors()
        else:
            normal_operation()

        time.sleep(random.uniform(0.5, 2.0))
