
with source as (

    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price
    from {{ source('ecommerce', 'order_items') }}

),

cleaned as (

    select
        order_item_id,
        order_id,
        product_id,
        quantity,
        unit_price,
        quantity * unit_price as line_amount
    from source
    where order_id is not null
      and quantity > 0
      and unit_price >= 0

),

valid_orders as (

    select order_id
    from {{ ref('stg_orders') }}

)

select c.*
from cleaned c
inner join valid_orders o
    on c.order_id = o.order_id

