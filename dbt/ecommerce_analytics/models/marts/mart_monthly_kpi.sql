-- KPI владельца по месяцам со сравнением с прошлым месяцем.
-- Сравнения посчитаны здесь, а не в BI: их можно проверить тестами,
-- и фильтр периода на дашборде их не ломает (прошлый месяц уже в строке).

with monthly as (
    select
        cast(date_trunc('month', order_date) as date) as month,
        count(*) as all_orders,
        count(case when is_sold then 1 end) as sold_orders,
        count(case when is_cancelled then 1 end) as cancelled_orders,
        count(case when is_cancelled and had_failed_payment then 1 end) as cancelled_after_failed_payment,
        sum(gross_revenue) as gross_revenue,
        sum(refund_amount) as refund_amount,
        sum(net_revenue) as net_revenue,
        sum(cost_amount) as cost_amount,
        sum(gross_profit) as gross_profit,
        sum(cancelled_amount) as cancelled_amount,
        count(distinct case when customer_type = 'new' then customer_id end) as new_customers
    from {{ ref('fct_orders') }}
    group by 1
),

with_ratios as (
    select
        *,
        gross_revenue / nullif(sold_orders, 0) as avg_order_value,
        gross_profit / nullif(net_revenue, 0) as margin,
        cancelled_orders * 1.0 / nullif(all_orders, 0) as cancel_rate,
        -- доля отмен, которым предшествовала неуспешная оплата
        cancelled_after_failed_payment * 1.0 / nullif(cancelled_orders, 0) as failed_payment_cancel_share,
        refund_amount / nullif(gross_revenue, 0) as refund_rate
    from monthly
),

with_previous as (
    select
        *,
        lag(net_revenue) over (order by month) as net_revenue_prev,
        lag(sold_orders) over (order by month) as sold_orders_prev,
        lag(avg_order_value) over (order by month) as avg_order_value_prev,
        lag(margin) over (order by month) as margin_prev,
        lag(cancel_rate) over (order by month) as cancel_rate_prev,
        lag(new_customers) over (order by month) as new_customers_prev
    from with_ratios
)

select
    *,
    -- рост в долях: 0.29 = +29% к прошлому месяцу
    net_revenue / nullif(net_revenue_prev, 0) - 1 as net_revenue_growth,
    sold_orders * 1.0 / nullif(sold_orders_prev, 0) - 1 as sold_orders_growth,
    avg_order_value / nullif(avg_order_value_prev, 0) - 1 as avg_order_value_growth,
    new_customers * 1.0 / nullif(new_customers_prev, 0) - 1 as new_customers_growth,
    -- для долей считаем изменение в процентных пунктах: 0.003 = +0.3 п.п.
    margin - margin_prev as margin_change,
    cancel_rate - cancel_rate_prev as cancel_rate_change
from with_previous
