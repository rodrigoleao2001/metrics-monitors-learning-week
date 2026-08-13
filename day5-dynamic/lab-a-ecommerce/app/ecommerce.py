"""
Lab A - Brazil Online Store
Custom metrics via DogStatsD simulating a Brazilian ecommerce platform.

Metrics:
- ecommerce.orders.count (count): Orders placed, by region and payment method
- ecommerce.payment.latency (histogram): Payment processing time, by method and region
- ecommerce.cart.abandonment (gauge): Cart abandonment rate, by region and device
- ecommerce.revenue.total (count): Revenue in BRL, by region and category
- ecommerce.inventory.stock_level (gauge): Stock level for popular products
"""

import random
import time
from datadog import initialize, statsd

initialize(statsd_host="datadog-agent", statsd_port=8125)

REGIONS = {
    "sp": {"weight": 0.40, "name": "Sao Paulo"},
    "rj": {"weight": 0.25, "name": "Rio de Janeiro"},
    "mg": {"weight": 0.15, "name": "Minas Gerais"},
    "ba": {"weight": 0.12, "name": "Bahia"},
    "rs": {"weight": 0.08, "name": "Rio Grande do Sul"},
}

PAYMENT_METHODS = ["pix", "credit_card", "boleto", "debit_card"]
CATEGORIES = ["electronics", "clothing", "food", "books", "home"]
DEVICES = ["mobile", "desktop", "tablet"]

RESOLUTION_BURST_INTERVAL = 10.0
_resolution_last_burst = {}


def weighted_region():
    r = random.random()
    cumulative = 0
    for region, config in REGIONS.items():
        cumulative += config["weight"]
        if r <= cumulative:
            return region
    return "sp"


def resolution_burst_due(name):
    """
    Returns True at most once every RESOLUTION_BURST_INTERVAL seconds per name.
    Returns False on every call in between.
    """
    now = time.monotonic()
    last = _resolution_last_burst.get(name)
    if last is not None and now - last < RESOLUTION_BURST_INTERVAL:
        return False
    _resolution_last_burst[name] = now
    return True


def emit_orders():
    region = weighted_region()
    payment = random.choice(PAYMENT_METHODS)
    category = random.choice(CATEGORIES)

    if payment == "boleto" and region == "ba":
        if random.random() < 0.95:
            return

    tags = [f"region:{region}", f"payment_method:{payment}", f"category:{category}", "env:learning-week", "day:5"]
    statsd.increment("ecommerce.orders.count", tags=tags)

    price = random.uniform(20, 800)
    if category == "electronics":
        if random.random() < 0.30:
            price = random.uniform(0.01, 2.00)

    statsd.increment("ecommerce.revenue.total", value=int(price * 100), tags=tags)


def emit_payment_latency():
    region = weighted_region()
    payment = random.choice(PAYMENT_METHODS)

    if payment == "pix" and region == "sp":
        latency = random.uniform(3.0, 15.0)
    elif payment == "pix":
        latency = random.uniform(0.1, 0.8)
    elif payment == "credit_card":
        latency = random.uniform(0.5, 2.0)
    elif payment == "boleto":
        latency = random.uniform(0.2, 1.0)
    else:
        latency = random.uniform(0.3, 1.5)

    tags = [f"region:{region}", f"payment_method:{payment}", "env:learning-week", "day:5"]
    statsd.histogram("ecommerce.payment.latency", latency, tags=tags)


def emit_cart_abandonment():
    for region in REGIONS:
        for device in DEVICES:
            if device == "mobile" and region == "rj":
                if random.random() < 0.40:
                    rate = random.uniform(60, 85)
                else:
                    rate = random.uniform(30, 45)
            elif device == "mobile":
                rate = random.uniform(25, 40)
            elif device == "desktop":
                rate = random.uniform(10, 25)
            else:
                rate = random.uniform(15, 30)

            tags = [f"region:{region}", f"device:{device}", "env:learning-week", "day:5"]
            statsd.gauge("ecommerce.cart.abandonment", rate, tags=tags)


def emit_failed_payments():
    region = weighted_region()
    payment = random.choice(PAYMENT_METHODS)

    if random.random() < 0.10:
        tags = [f"region:{region}", f"payment_method:{payment}", "env:learning-week", "day:5"]
        statsd.gauge("ecommerce.failed_payments", 1, tags=tags)


def emit_inventory():
    for product_id in range(1, 11):
        stock = max(0, random.randint(-5, 100))
        tags = [f"product_id:product_{product_id}", "env:learning-week", "day:5"]
        statsd.gauge("ecommerce.inventory.stock_level", stock, tags=tags)


def emit_resolution_demo():
    """
    Sends the same value using different DogStatsD submission types.
    Investigate the resulting metric series in Metrics Explorer.
    """
    if not resolution_burst_due("resolution"):
        return

    tags = ["env:learning-week", "day:5", "demo:resolution"]

    for _ in range(random.randint(3, 6)):
        statsd.gauge("ecommerce.refunds.gauge_demo", 100, tags=tags)
        statsd.increment("ecommerce.refunds.count_demo", 100, tags=tags)
        statsd.histogram("ecommerce.refunds.histogram_demo", 100, tags=tags)


def emit_resolution_varied():
    """
    Sends varied values using different DogStatsD submission types.
    """
    if not resolution_burst_due("resolution-varied"):
        return

    tags = ["env:learning-week", "day:5", "demo:resolution-varied"]
    values = [10, 50, 200, 500]

    for val in values:
        statsd.gauge("ecommerce.refunds_varied.gauge_demo", val, tags=tags)
        statsd.increment("ecommerce.refunds_varied.count_demo", val, tags=tags)
        statsd.histogram("ecommerce.refunds_varied.histogram_demo", val, tags=tags)


if __name__ == "__main__":
    print("Starting Brazil Online Store metrics generator...")
    time.sleep(10)

    cycle = 0
    while True:
        for _ in range(random.randint(3, 8)):
            emit_orders()

        for _ in range(random.randint(2, 5)):
            emit_payment_latency()

        emit_failed_payments()

        emit_resolution_demo()
        emit_resolution_varied()

        if cycle % 5 == 0:
            emit_cart_abandonment()

        if cycle % 30 == 0:
            emit_inventory()

        cycle += 1
        time.sleep(random.uniform(1, 3))
