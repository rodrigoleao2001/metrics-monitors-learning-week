-- Enable pg_stat_statements for DBM
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create the Datadog user for DBM
CREATE USER datadog WITH PASSWORD 'datadog_password';
GRANT pg_monitor TO datadog;
GRANT SELECT ON pg_stat_activity TO datadog;

-- Schema: E-commerce database
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    region VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    category VARCHAR(50) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock INTEGER DEFAULT 0
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(id),
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    status VARCHAR(30) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE inventory_log (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    change_amount INTEGER NOT NULL,
    reason VARCHAR(100),
    logged_at TIMESTAMP DEFAULT NOW()
);

-- Seed data: 1000 customers
INSERT INTO customers (name, email, region)
SELECT
    'Customer ' || i,
    'customer' || i || '@example.com',
    CASE (i % 5)
        WHEN 0 THEN 'SP'
        WHEN 1 THEN 'RJ'
        WHEN 2 THEN 'MG'
        WHEN 3 THEN 'BA'
        WHEN 4 THEN 'RS'
    END
FROM generate_series(1, 1000) AS i;

-- Seed data: 200 products
INSERT INTO products (name, category, price, stock)
SELECT
    'Product ' || i,
    CASE (i % 4)
        WHEN 0 THEN 'electronics'
        WHEN 1 THEN 'clothing'
        WHEN 2 THEN 'food'
        WHEN 3 THEN 'books'
    END,
    (random() * 500 + 10)::DECIMAL(10,2),
    (random() * 100)::INTEGER
FROM generate_series(1, 200) AS i;

-- Seed data: 50000 orders (for realistic query times)
INSERT INTO orders (customer_id, product_id, quantity, total_price, status, created_at)
SELECT
    (random() * 999 + 1)::INTEGER,
    (random() * 199 + 1)::INTEGER,
    (random() * 5 + 1)::INTEGER,
    (random() * 1000 + 10)::DECIMAL(10,2),
    CASE (i % 5)
        WHEN 0 THEN 'pending'
        WHEN 1 THEN 'confirmed'
        WHEN 2 THEN 'shipped'
        WHEN 3 THEN 'delivered'
        WHEN 4 THEN 'cancelled'
    END,
    NOW() - (random() * INTERVAL '90 days')
FROM generate_series(1, 50000) AS i;

-- Seed inventory log
INSERT INTO inventory_log (product_id, change_amount, reason, logged_at)
SELECT
    (random() * 199 + 1)::INTEGER,
    CASE WHEN random() > 0.5 THEN (random() * 50)::INTEGER ELSE -(random() * 20)::INTEGER END,
    CASE (i % 3)
        WHEN 0 THEN 'restock'
        WHEN 1 THEN 'sale'
        WHEN 2 THEN 'adjustment'
    END,
    NOW() - (random() * INTERVAL '30 days')
FROM generate_series(1, 10000) AS i;

CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_customers_region ON customers(region);

-- Grant permissions to datadog user for DBM
GRANT SELECT ON ALL TABLES IN SCHEMA public TO datadog;

-- Analyze tables for query planner
ANALYZE;
