-- Все заказы с корректной суммой, в любом статусе.
-- Что считать продажей, решают витрины (см. is_sold в fct_orders).
select
    order_id,
    customer_id,
    amount,
    status,
    channel,
    created_at,
    cast(created_at as date) as order_date
from {{ source('ecommerce', 'orders') }}
where amount > 0
