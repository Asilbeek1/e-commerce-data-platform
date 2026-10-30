-- Возврат не может быть больше суммы заказа.
-- Тест падает, если запрос вернёт хотя бы одну строку.
select
    order_id,
    order_amount,
    refund_amount
from {{ ref('fct_orders') }}
where refund_amount > order_amount
