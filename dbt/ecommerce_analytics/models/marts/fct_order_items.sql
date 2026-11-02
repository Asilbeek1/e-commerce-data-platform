-- Строки заказов с признаками заказа: для разбивок по категориям, товарам,
-- регионам и каналам. Возврат заказа распределяется по его строкам
-- пропорционально сумме строки, поэтому суммы сходятся с fct_orders.

with lines as (

    select
        i.order_item_id,
        i.order_id,
        o.order_date,
        o.status,
        o.is_sold,
        o.channel,
        o.region,
        o.customer_type,
        p.product_id,
        p.product_name,
        p.category,
        i.quantity,
        i.unit_price,
        i.line_amount,
        case when o.is_sold then i.line_amount else 0 end as gross_revenue,
        case
            when o.is_sold then o.refund_amount * i.line_amount / o.order_amount
            else 0
        end as refund_amount,
        case when o.status = 'completed' then i.quantity * p.cost_price else 0 end as cost_amount
    from {{ ref('stg_orders_items') }} i
    join {{ ref('fct_orders') }} o
        on i.order_id = o.order_id
    join {{ ref('stg_products') }} p
        on i.product_id = p.product_id

)

select
    *,
    gross_revenue - refund_amount as net_revenue,
    gross_revenue - refund_amount - cost_amount as gross_profit
from lines
