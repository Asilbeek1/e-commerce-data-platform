
select
    payment_id,
    order_id,
    amount as payment_amount,
    payment_method,
    status as payment_status,
    paid_at,
    cast(paid_at as date) as payment_date
from {{ source('ecommerce', 'payments') }}

