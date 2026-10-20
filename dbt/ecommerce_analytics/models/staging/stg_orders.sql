select
    order_id,
    customer_id,
    amount,
    status,
    cast(created_at as date) as order_date
from {{ source('ecommerce', 'orders') }}
where status = 'completed'
  and amount > 0
