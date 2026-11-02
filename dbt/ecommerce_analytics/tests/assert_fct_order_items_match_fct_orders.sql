-- Суммы по строкам заказа должны сходиться с fct_orders (с точностью до копейки):
-- иначе разбивки по категориям и итоговые KPI на дашборде будут расходиться.
-- Тест падает, если запрос вернёт хотя бы одну строку.
select
    o.order_id,
    o.net_revenue,
    sum(i.net_revenue) as items_net_revenue,
    o.gross_profit,
    sum(i.gross_profit) as items_gross_profit
from {{ ref('fct_orders') }} o
join {{ ref('fct_order_items') }} i
    on o.order_id = i.order_id
group by o.order_id, o.net_revenue, o.gross_profit
having abs(o.net_revenue - sum(i.net_revenue)) > 0.01
    or abs(o.gross_profit - sum(i.gross_profit)) > 0.01
