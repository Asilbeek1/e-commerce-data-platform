-- Продажи по категориям и дням (проданные заказы: completed и refunded)
select
    o.order_date,
    p.category,
    count(distinct o.order_id) as orders_count,
    sum(i.quantity) as items_sold,
    sum(i.line_amount) as revenue
from {{ ref('stg_orders_items') }} i
join {{ ref('stg_orders') }} o
    on i.order_id = o.order_id
join {{ ref('stg_products') }} p
    on i.product_id = p.product_id
where o.status in ('completed', 'refunded')
group by o.order_date, p.category
