"""
Traffic generator for the Flask store app.
Simulates realistic user behavior with weighted endpoint distribution.
"""

import random
import time
import requests
import threading

BASE_URL = "http://flask-app:5000"

ENDPOINTS = [
    ("GET", "/", 0.15),
    ("GET", "/search?q=Product", 0.30),
    ("GET", "/product/1", 0.10),
    ("GET", "/product/42", 0.05),
    ("GET", "/product/999", 0.03),
    ("GET", "/checkout", 0.15),
    ("GET", "/inventory", 0.10),
    ("GET", "/recommendations", 0.10),
    ("GET", "/health", 0.02),
]


def weighted_choice():
    r = random.random()
    cumulative = 0
    for method, path, weight in ENDPOINTS:
        cumulative += weight
        if r <= cumulative:
            return method, path
    return ENDPOINTS[0][0], ENDPOINTS[0][1]


def send_request():
    method, path = weighted_choice()
    url = f"{BASE_URL}{path}"
    try:
        if method == "POST":
            requests.post(url, json={"items": [1, 2, 3]}, timeout=15)
        else:
            requests.get(url, timeout=15)
    except requests.exceptions.RequestException:
        pass


def traffic_loop():
    while True:
        send_request()
        time.sleep(random.uniform(0.1, 0.5))


def burst_traffic():
    """Periodic bursts to create interesting patterns in metrics."""
    while True:
        time.sleep(random.uniform(60, 180))
        burst_size = random.randint(20, 50)
        for _ in range(burst_size):
            send_request()
            time.sleep(0.05)


if __name__ == "__main__":
    print("Starting traffic generator...")
    print(f"Target: {BASE_URL}")
    time.sleep(10)

    for _ in range(4):
        t = threading.Thread(target=traffic_loop, daemon=True)
        t.start()

    burst_thread = threading.Thread(target=burst_traffic, daemon=True)
    burst_thread.start()

    print("Traffic generator running. Press Ctrl+C to stop.")
    while True:
        time.sleep(60)
        print(f"Traffic generator alive — sending requests to {BASE_URL}")
