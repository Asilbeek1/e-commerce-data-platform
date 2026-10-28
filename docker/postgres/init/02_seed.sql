-- Тестовые данные (учебные, сгенерированные)
INSERT INTO raw.customers
SELECT g, 'Customer ' || g, CASE WHEN g % 17 = 0 THEN NULL ELSE 'User' || g || '@Example.com' END,
       timestamp '2025-01-01' + (g * interval '2 days')
FROM generate_series(1, 200) g;

INSERT INTO raw.products
SELECT g, 'Product ' || g,
       (ARRAY['Electronics','Clothing','Home','Books','Sports'])[1 + g % 5],
       round((10 + random()*490)::numeric, 2)
FROM generate_series(1, 50) g;

INSERT INTO raw.orders
SELECT g, 1 + (random()*199)::int, 0,
       (ARRAY['completed','completed','completed','cancelled','pending'])[1 + (random()*4)::int],
       timestamp '2025-06-01' + (random()*400) * interval '1 day'
FROM generate_series(1, 2000) g;

INSERT INTO raw.order_items
SELECT row_number() over (), o.order_id, 1 + (random()*49)::int, 1 + (random()*3)::int, 0
FROM raw.orders o, generate_series(1, 1 + (o.order_id % 3)) s;

UPDATE raw.order_items oi SET unit_price = p.list_price FROM raw.products p WHERE p.product_id = oi.product_id;
UPDATE raw.orders o SET amount = s.total FROM (SELECT order_id, sum(quantity*unit_price) total FROM raw.order_items GROUP BY 1) s WHERE s.order_id = o.order_id;

INSERT INTO raw.payments
SELECT order_id, order_id, amount, (ARRAY['card','paypal','bank_transfer'])[1 + order_id % 3],
       CASE status WHEN 'completed' THEN 'paid' WHEN 'pending' THEN 'pending' ELSE 'failed' END,
       CASE status WHEN 'completed' THEN created_at + interval '5 minutes' END
FROM raw.orders;

INSERT INTO raw.refunds
SELECT row_number() over (), order_id, round(amount/2, 2), 'processed', created_at + interval '10 days'
FROM raw.orders WHERE status = 'completed' AND order_id % 13 = 0;
