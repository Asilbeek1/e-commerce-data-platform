-- Сводка по клиентам
with customer_orders as (
    select
        customer_id,
        count(*) as orders_count,
        sum(amount) as total_spent,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date
    from {{ ref('stg_orders') }}
    group by customer_id
)

select
    c.customer_id,
    c.customer_name,
    c.email,
    c.registration_date,
    coalesce(co.orders_count, 0) as orders_count,
    coalesce(co.total_spent, 0) as total_spent,
    co.first_order_date,
    co.last_order_date
from {{ ref('stg_customers') }} c
left join customer_orders co
    on c.customer_id = co.customer_id
