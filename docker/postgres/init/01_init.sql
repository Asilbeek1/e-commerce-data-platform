
CREATE SCHEMA IF NOT EXISTS raw;

-- 1. Orders
CREATE TABLE IF NOT EXISTS raw.orders (
    order_id    INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    amount      NUMERIC(12, 2) NOT NULL,
    status      TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL
);

-- 2. Customers
CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id   INTEGER PRIMARY KEY,
    full_name     TEXT NOT NULL,
    email         TEXT,
    registered_at TIMESTAMP NOT NULL
);

-- 3. Products
CREATE TABLE IF NOT EXISTS raw.products (
    product_id   INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    category     TEXT NOT NULL,
    list_price   NUMERIC(12, 2) NOT NULL
);

-- 4. Order items
CREATE TABLE IF NOT EXISTS raw.order_items (
    order_item_id INTEGER PRIMARY KEY,
    order_id      INTEGER NOT NULL,
    product_id    INTEGER NOT NULL,
    quantity      INTEGER NOT NULL,
    unit_price    NUMERIC(12, 2) NOT NULL
);

-- 5. Payments
CREATE TABLE IF NOT EXISTS raw.payments (
    payment_id     INTEGER PRIMARY KEY,
    order_id       INTEGER NOT NULL,
    amount         NUMERIC(12, 2) NOT NULL,
    payment_method TEXT NOT NULL,
    status         TEXT NOT NULL,
    paid_at        TIMESTAMP
);

-- 6. Refunds
CREATE TABLE IF NOT EXISTS raw.refunds (
    refund_id   INTEGER PRIMARY KEY,
    order_id    INTEGER NOT NULL,
    amount      NUMERIC(12, 2) NOT NULL,
    status      TEXT NOT NULL,
    refunded_at TIMESTAMP
);
