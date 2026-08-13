import random
import time
import logging
from flask import Flask, jsonify, request

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

PRODUCTS = [
    {"id": i, "name": f"Product {i}", "price": round(random.uniform(10, 500), 2)}
    for i in range(1, 101)
]


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


@app.route("/")
def home():
    time.sleep(random.uniform(0.01, 0.05))
    return jsonify({"message": "Welcome to the Store", "products": len(PRODUCTS)})


@app.route("/search")
def search():
    query = request.args.get("q", "")
    time.sleep(random.uniform(0.02, 0.15))
    results = [p for p in PRODUCTS if query.lower() in p["name"].lower()]
    return jsonify({"query": query, "results": results[:10]})


@app.route("/product/<int:product_id>")
def get_product(product_id):
    time.sleep(random.uniform(0.01, 0.08))
    product = next((p for p in PRODUCTS if p["id"] == product_id), None)
    if not product:
        return jsonify({"error": "Product not found"}), 404
    return jsonify(product)


@app.route("/checkout", methods=["POST", "GET"])
def checkout():
    # Simulated payment gateway. Response time is deliberately uneven across requests.
    if random.random() < 0.20:
        delay = random.uniform(2.0, 6.0)
    elif random.random() < 0.10:
        delay = random.uniform(1.0, 2.0)
    else:
        delay = random.uniform(0.1, 0.3)

    time.sleep(delay)

    if random.random() < 0.05:
        return jsonify({"error": "Payment gateway timeout"}), 503

    return jsonify({
        "order_id": random.randint(10000, 99999),
        "status": "confirmed",
        "processing_time_ms": int(delay * 1000),
    })


@app.route("/inventory")
def inventory():
    time.sleep(random.uniform(0.05, 0.2))

    # Simulated dependency call with variable response time.
    if random.random() < 0.10:
        time.sleep(random.uniform(1.0, 3.0))

    return jsonify({"total_products": len(PRODUCTS), "in_stock": random.randint(50, 100)})


@app.route("/recommendations")
def recommendations():
    time.sleep(random.uniform(0.03, 0.12))
    sample = random.sample(PRODUCTS, min(5, len(PRODUCTS)))
    return jsonify({"recommendations": sample})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
