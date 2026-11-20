with source as (
    select * from {{ ref('contacts') }}
),
renamed as (
    select
        id as contact_id,
        account_id,
        lead_id,
        job_title,
        created_at
    from source
)

select * from renamed