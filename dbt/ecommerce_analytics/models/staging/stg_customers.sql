select
    customer_id,
    trim(full_name) as customer_name,
    lower(trim(email)) as email,
    registered_at,
    cast(registered_at as date) as registration_date
from {{ source('ecommerce', 'customers') }}

