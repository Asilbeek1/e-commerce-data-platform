-- Факт-таблица заказов: одна строка на завершённый заказ
with orders as (
    select
        order_id,
        customer_id,
        order_date,
        amount
    from {{ ref('stg_orders') }}
),

order_items as (
    select
        order_id,
        count(*) as lines_count,
        sum(quantity) as items_count,
        sum(line_amount) as items_amount
    from {{ ref('stg_orders_items') }}
    group by order_id
),

payments as (
    select
        order_id,
        max(payment_method) as payment_method,
        sum(case when payment_status = 'paid' then payment_amount else 0 end) as paid_amount,
        max(payment_date) as payment_date
    from {{ ref('stg_payments') }}
    group by order_id
),

refunds as (
    select
        order_id,
        count(*) as refunds_count,
        sum(refund_amount) as refund_amount
    from {{ ref('stg_refunds') }}
    where refund_status = 'processed'
    group by order_id
)

select
    o.order_id,
    o.customer_id,
    o.order_date,
    o.amount as order_amount,
    coalesce(i.lines_count, 0) as lines_count,
    coalesce(i.items_count, 0) as items_count,
    p.payment_method,
    coalesce(p.paid_amount, 0) as paid_amount,
    p.payment_date,
    coalesce(p.paid_amount, 0) >= o.amount as is_paid,
    coalesce(r.refunds_count, 0) as refunds_count,
    coalesce(r.refund_amount, 0) as refund_amount,
    o.amount - coalesce(r.refund_amount, 0) as net_amount
from orders o
left join order_items i
    on o.order_id = i.order_id
left join payments p
    on o.order_id = p.order_id
left join refunds r
    on o.order_id = r.order_id
