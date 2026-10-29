
with source as (

    select
        refund_id,
        order_id,
        amount,
        status,
        refunded_at
    from {{ source('ecommerce', 'refunds') }}

),

cleaned as (

    select
        refund_id,
        order_id,
        amount as refund_amount,
        status as refund_status,
        refunded_at,
        cast(refunded_at as date) as refund_date
    from source
    where order_id is not null
      and amount >= 0

),

valid_orders as (

    select order_id
    from {{ ref('stg_orders') }}

)

select c.*
from cleaned c
inner join valid_orders o
    on c.order_id = o.order_id

