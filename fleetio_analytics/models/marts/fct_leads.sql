
with leads as (
    select * from {{ ref('stg_leads') }}
)
select
    lead_id,
    created_at,
    converted_at,
    is_converted,
    lead_source,
    job_title,
    industry,
    fleet_size,
    company,
    country,
    state,
    city
from leads