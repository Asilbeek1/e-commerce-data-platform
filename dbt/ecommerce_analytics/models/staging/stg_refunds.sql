
select
    refund_id,
    order_id,
    amount as refund_amount,
    status as refund_status,
    refunded_at,
    cast(refunded_at as date) as refund_date
from {{ source('ecommerce', 'refunds') }}

