
with source as (

    select
        payment_id,
        order_id,
        amount,
        payment_method,
        status,
        paid_at
    from {{ source('ecommerce', 'payments') }}

),

cleaned as (

    select
        payment_id,
        order_id,
        amount as payment_amount,
        payment_method,
        status as payment_status,
        paid_at,
        cast(paid_at as date) as payment_date
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

