-- Выручка и возвраты по дням
with orders_by_day as (
    select
        order_date,
        count(*) as orders_count,
        sum(amount) as revenue
    from {{ ref('stg_orders') }}
    group by order_date
),

refunds_by_day as (
    select
        refund_date,
        count(*) as refunds_count,
        sum(refund_amount) as refund_amount
    from {{ ref('stg_refunds') }}
    where refund_status = 'completed'
    group by refund_date
)

select
    coalesce(o.order_date, r.refund_date) as date,
    coalesce(o.orders_count, 0) as orders_count,
    coalesce(o.revenue, 0) as revenue,
    round(coalesce(o.revenue, 0) / nullif(o.orders_count, 0), 2) as avg_order_value,
    coalesce(r.refunds_count, 0) as refunds_count,
    coalesce(r.refund_amount, 0) as refund_amount,
    coalesce(o.revenue, 0) - coalesce(r.refund_amount, 0) as net_revenue
from orders_by_day o
full outer join refunds_by_day r
    on o.order_date = r.refund_date
