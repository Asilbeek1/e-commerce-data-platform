
select
    product_id,
    trim(product_name) as product_name,
    trim(category) as category,
    list_price
from {{ source('ecommerce', 'products') }}

