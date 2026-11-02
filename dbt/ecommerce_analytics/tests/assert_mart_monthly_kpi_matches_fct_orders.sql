-- Помесячные итоги должны сходиться с fct_orders за весь период.
-- Тест падает, если запрос вернёт строку.
select
    k.net_revenue as kpi_net_revenue,
    f.net_revenue as fct_net_revenue,
    k.sold_orders as kpi_sold_orders,
    f.sold_orders as fct_sold_orders
from (
    select sum(net_revenue) as net_revenue, sum(sold_orders) as sold_orders
    from {{ ref('mart_monthly_kpi') }}
) k
cross join (
    select sum(net_revenue) as net_revenue, count(case when is_sold then 1 end) as sold_orders
    from {{ ref('fct_orders') }}
) f
where abs(k.net_revenue - f.net_revenue) > 0.01
   or k.sold_orders <> f.sold_orders
