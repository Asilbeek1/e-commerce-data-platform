-- Факт-таблица заказов: одна строка на заказ в любом статусе.
--
-- Бизнес-правила:
--   продажа (is_sold)  = статус completed или refunded: заказ был оплачен и отгружен
--   выручка (gross)    = сумма проданных заказов
--   чистая выручка     = выручка - завершённые возвраты
--   себестоимость      = только по completed-заказам (при полном возврате товар вернулся)
--   валовая прибыль    = чистая выручка - себестоимость
--   отменённые и незавершённые заказы не дают выручки, но показывают потери

with orders as (
    select
        o.order_id,
        o.customer_id,
        c.region,
        o.channel,
        o.status,
        o.order_date,
        o.created_at,
        o.amount
    from {{ ref('stg_orders') }} o
    left join {{ ref('stg_customers') }} c
        on o.customer_id = c.customer_id
),

order_items as (
    select
        i.order_id,
        count(*) as lines_count,
        sum(i.quantity) as items_count,
        sum(i.quantity * p.cost_price) as items_cost
    from {{ ref('stg_orders_items') }} i
    join {{ ref('stg_products') }} p
        on i.product_id = p.product_id
    group by i.order_id
),

payments as (
    -- у части заказов сначала неуспешная попытка, потом успешная:
    -- способ оплаты берём из успешного платежа (paid, или refunded, если деньги вернули)
    select
        order_id,
        max(case when payment_status in ('paid', 'refunded') then payment_method end) as payment_method,
        sum(case when payment_status = 'paid' then payment_amount else 0 end) as paid_amount,
        max(case when payment_status = 'paid' then payment_date end) as payment_date,
        count(case when payment_status = 'failed' then 1 end) as failed_payments_count,
        max(case when payment_status = 'failed' then payment_method end) as failed_payment_method
    from {{ ref('stg_payments') }}
    group by order_id
),

refunds as (
    select
        order_id,
        sum(refund_amount) as refund_amount
    from {{ ref('stg_refunds') }}
    where refund_status = 'completed'
    group by order_id
),

customer_order_numbers as (
    -- порядковый номер покупки клиента: 1 = первая покупка (новый клиент)
    select
        order_id,
        row_number() over (partition by customer_id order by created_at, order_id) as customer_order_number
    from {{ ref('stg_orders') }}
    where status in ('completed', 'refunded')
),

joined as (
    select
        o.order_id,
        o.customer_id,
        o.region,
        o.channel,
        o.status,
        o.order_date,
        o.amount as order_amount,
        o.status in ('completed', 'refunded') as is_sold,
        o.status = 'cancelled' as is_cancelled,
        o.status in ('pending', 'processing') as is_in_progress,
        o.status = 'refunded' as is_fully_refunded,
        coalesce(i.lines_count, 0) as lines_count,
        coalesce(i.items_count, 0) as items_count,
        p.payment_method,
        coalesce(p.paid_amount, 0) as paid_amount,
        p.payment_date,
        coalesce(p.paid_amount, 0) >= o.amount as is_paid,
        coalesce(p.failed_payments_count, 0) as failed_payments_count,
        coalesce(p.failed_payments_count, 0) > 0 as had_failed_payment,
        p.failed_payment_method,
        coalesce(r.refund_amount, 0) as refund_amount,
        case when o.status = 'completed' then coalesce(i.items_cost, 0) else 0 end as cost_amount,
        case
            when n.customer_order_number = 1 then 'new'
            when n.customer_order_number > 1 then 'returning'
        end as customer_type
    from orders o
    left join order_items i on o.order_id = i.order_id
    left join payments p on o.order_id = p.order_id
    left join refunds r on o.order_id = r.order_id
    left join customer_order_numbers n on o.order_id = n.order_id
)

select
    *,
    case when is_sold then order_amount else 0 end as gross_revenue,
    case when is_sold then order_amount else 0 end - refund_amount as net_revenue,
    case when is_sold then order_amount else 0 end - refund_amount - cost_amount as gross_profit,
    case when is_cancelled then order_amount else 0 end as cancelled_amount
from joined
