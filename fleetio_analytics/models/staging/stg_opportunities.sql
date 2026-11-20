with source as (
    select * from {{ ref('opportunities') }}
),
renamed as (
    select
        id as opportunity_id,
        account_id,
        country,
        state,
        city,
        created_at,
        closed_at,
        -- note: is_closed and is_won are not explicit fields in the seed load, so we need to create them here
        is_closed = 'TRUE' as is_closed,
        is_won = 'TRUE' as is_won
    from source
)
select
    *,
    -- the individual statuses aren't explicit, so we need to create a new field to represent the overall status
    case
        when is_closed and is_won then 'closed_won'
        when is_closed then 'closed_lost'
        else 'open'
    end as status
from renamed