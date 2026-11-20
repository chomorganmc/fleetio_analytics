with opportunities as (

    select * from {{ ref('stg_opportunities') }}

),

accounts as (

    select * from {{ ref('stg_accounts') }}

),

contacts as (

    select * from {{ ref('stg_contacts') }}

),

leads as (

    select * from {{ ref('stg_leads') }}

)

select
    opportunities.opportunity_id,
    opportunities.account_id,
    contacts.lead_id,
    opportunities.created_at,
    opportunities.closed_at,
    opportunities.is_closed,
    opportunities.is_won,
    opportunities.status,
    (opportunities.closed_at::date - opportunities.created_at::date) as days_to_close,
    leads.lead_source,
    leads.job_title,
    accounts.industry,
    accounts.fleet_size,
    accounts.company,
    opportunities.country,
    opportunities.state,
    opportunities.city
from opportunities
inner join accounts
    on opportunities.account_id = accounts.account_id
inner join contacts
    on accounts.account_id = contacts.account_id
inner join leads
    on contacts.lead_id = leads.lead_id