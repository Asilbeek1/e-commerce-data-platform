CREATE SCHEMA IF NOT EXISTS raw;

-- 1. Orders (Added channel: 'app' or 'website')
CREATE TABLE IF NOT EXISTS raw.orders (
    order_id      INTEGER PRIMARY KEY,
    customer_id   INTEGER NOT NULL,
    amount        NUMERIC(12, 2) NOT NULL,
    status        TEXT NOT NULL,
    channel       TEXT NOT NULL CHECK (channel IN ('app', 'website')), -- Channel origin
    created_at    TIMESTAMP NOT NULL
);

-- 2. Customers (Added region: user location / delivery region)
CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id   INTEGER PRIMARY KEY,
    full_name     TEXT NOT NULL,
    email         TEXT,
    region        TEXT NOT NULL, -- Region/City (e.g., Tashkent City, Samarkand, Fergana)
    registered_at TIMESTAMP NOT NULL
);

-- 3. Products (Added cost_price: Себестоимость)
CREATE TABLE IF NOT EXISTS raw.products (
    product_id     INTEGER PRIMARY KEY,
    product_name   TEXT NOT NULL,
    category       TEXT NOT NULL,
    list_price     NUMERIC(12, 2) NOT NULL, -- Selling list price
    cost_price     NUMERIC(12, 2) NOT NULL  -- Себестоимость (cost of goods sold)
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
    refund_id     INTEGER PRIMARY KEY,
    order_id      INTEGER NOT NULL,
    amount        NUMERIC(12, 2) NOT NULL,
    status        TEXT NOT NULL,
    refunded_at   TIMESTAMP
);
