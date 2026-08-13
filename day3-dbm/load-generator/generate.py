"""
Database load generator for Day 3 — DBM Lab.
Generates a mix of fast queries, slow sequential scans, lock contention, and connection floods.
"""

import random
import time
import threading
import socket
import psycopg2
from psycopg2 import pool

STATSD_HOST = "datadog-agent"
STATSD_PORT = 8125
STATSD_TAGS = "env:learning-week,day:3"


def statsd_count(metric, value=1):
    msg = f"{metric}:{value}|c|#{STATSD_TAGS}"
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(msg.encode(), (STATSD_HOST, STATSD_PORT))
        sock.close()
    except Exception:
        pass

DB_CONFIG = {
    "host": "postgres",
    "port": 5432,
    "dbname": "learning_week",
    "user": "postgres",
    "password": "postgres_password",
}

connection_pool = None


def get_pool():
    global connection_pool
    if connection_pool is None:
        connection_pool = pool.ThreadedConnectionPool(2, 20, **DB_CONFIG)
    return connection_pool


def fast_queries():
    """Queries that use indexes and return quickly."""
    queries = [
        "SELECT * FROM products WHERE category = 'electronics' LIMIT 10",
        "SELECT * FROM customers WHERE region = 'SP' LIMIT 10",
        "SELECT COUNT(*) FROM products",
        "SELECT COUNT(*) FROM customers",
        "SELECT id, name, price FROM products ORDER BY price DESC LIMIT 5",
    ]
    while True:
        try:
            conn = get_pool().getconn()
            cur = conn.cursor()
            cur.execute(random.choice(queries))
            cur.fetchall()
            cur.close()
            get_pool().putconn(conn)
            statsd_count("pg_app.queries.total")
        except Exception:
            statsd_count("pg_app.queries.total")
            statsd_count("pg_app.queries.errors")
        time.sleep(random.uniform(0.1, 0.5))


def slow_queries():
    """Queries that do sequential scans (no index on orders columns)."""
    queries = [
        "SELECT o.*, c.name, c.region FROM orders o JOIN customers c ON o.customer_id = c.id WHERE o.status = 'pending' ORDER BY o.created_at DESC LIMIT 100",
        "SELECT customer_id, COUNT(*) as order_count, SUM(total_price) as total_spent FROM orders GROUP BY customer_id ORDER BY total_spent DESC LIMIT 20",
        "SELECT * FROM orders WHERE customer_id = %s AND created_at > NOW() - INTERVAL '30 days'",
        "SELECT o.status, COUNT(*), AVG(total_price), MAX(total_price) FROM orders o WHERE o.created_at > NOW() - INTERVAL '7 days' GROUP BY o.status",
        "SELECT p.category, COUNT(o.id), SUM(o.total_price) FROM orders o JOIN products p ON o.product_id = p.id GROUP BY p.category",
    ]
    while True:
        try:
            conn = get_pool().getconn()
            cur = conn.cursor()
            query = random.choice(queries)
            if "%s" in query:
                cur.execute(query, (random.randint(1, 1000),))
            else:
                cur.execute(query)
            cur.fetchall()
            cur.close()
            get_pool().putconn(conn)
            statsd_count("pg_app.queries.total")
        except Exception:
            statsd_count("pg_app.queries.total")
            statsd_count("pg_app.queries.errors")
        time.sleep(random.uniform(1, 3))


def lock_contention():
    """Creates lock contention by concurrent updates on the same rows."""
    while True:
        try:
            conn = get_pool().getconn()
            conn.autocommit = False
            cur = conn.cursor()

            product_id = random.randint(1, 50)
            cur.execute("UPDATE products SET stock = stock - 1 WHERE id = %s", (product_id,))

            time.sleep(random.uniform(0.5, 3.0))

            cur.execute("UPDATE inventory_log SET reason = 'sale_processed' WHERE product_id = %s AND reason = 'sale' LIMIT 1", (product_id,))
            conn.commit()
            cur.close()
            get_pool().putconn(conn)
        except Exception as e:
            try:
                conn.rollback()
                get_pool().putconn(conn)
            except Exception:
                pass
        time.sleep(random.uniform(0.5, 2))


def connection_flood():
    """Periodically opens many connections simultaneously."""
    while True:
        time.sleep(random.uniform(30, 90))
        connections = []
        try:
            for _ in range(random.randint(10, 30)):
                conn = psycopg2.connect(**DB_CONFIG)
                connections.append(conn)
                cur = conn.cursor()
                cur.execute("SELECT pg_sleep(0.1)")
                cur.close()
            time.sleep(random.uniform(2, 5))
        except Exception:
            pass
        finally:
            for conn in connections:
                try:
                    conn.close()
                except Exception:
                    pass


def batch_success_burst():
    """Every 30s emits 300 successful queries at once — creates high-volume low-error intervals.
    This is what makes as_rate diverge from as_count: as_rate weights each interval equally,
    so the low-volume high-error intervals inflate the average. as_count weights by volume,
    so the burst of successes dominates the denominator."""
    while True:
        time.sleep(30)
        statsd_count("pg_app.queries.total", 300)


def api_call_errors():
    """Simulates an external API with ~40% error rate — creates low-volume high-error intervals.
    Combined with batch_success_burst, this produces the temporal variance needed to show
    the difference between as_rate and as_count evaluation paths."""
    while True:
        statsd_count("pg_app.queries.total")
        if random.random() < 0.40:
            statsd_count("pg_app.queries.errors")
        time.sleep(random.uniform(1, 3))


if __name__ == "__main__":
    print("Starting database load generator...")
    time.sleep(15)

    threads = [
        threading.Thread(target=fast_queries, daemon=True, name="fast-queries-1"),
        threading.Thread(target=fast_queries, daemon=True, name="fast-queries-2"),
        threading.Thread(target=slow_queries, daemon=True, name="slow-queries-1"),
        threading.Thread(target=slow_queries, daemon=True, name="slow-queries-2"),
        threading.Thread(target=slow_queries, daemon=True, name="slow-queries-3"),
        threading.Thread(target=lock_contention, daemon=True, name="lock-contention-1"),
        threading.Thread(target=lock_contention, daemon=True, name="lock-contention-2"),
        threading.Thread(target=connection_flood, daemon=True, name="connection-flood"),
        threading.Thread(target=batch_success_burst, daemon=True, name="batch-success-burst"),
        threading.Thread(target=api_call_errors, daemon=True, name="api-call-errors"),
    ]

    for t in threads:
        t.start()
        print(f"  Started: {t.name}")

    print("Load generator running.")
    while True:
        time.sleep(60)
        print("Load generator alive — generating database traffic")
