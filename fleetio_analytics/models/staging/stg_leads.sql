with source as (
    select * from {{ ref('leads') }}
),

renamed as (
    select
        -- id is a reserved word, so we need to rename it
        id as lead_id,
        job_title,
        company,
        -- source is a reserved word, so we need to rename it
        source as lead_source,
        country,
        state,
        city,
        industry,
        fleet_size,
        created_at,
        converted_at
    from source
)
select
    *,
    --note: is_converted doesnt exist as a flag field in the seed load, so we need to create it here
    converted_at is not null as is_converted
from renamed