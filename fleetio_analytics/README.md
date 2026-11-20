# Fleetio analytics assessment

dbt project on the lead / contact / account / opportunity csvs. 

I timeboxed this to a couple of hours so the warehouse layer is pretty thin: seeds, staging, and two fact models as the marts.

I used Postgres locally (dbt-postgres) since that was the adapter that was mentioned. I used the `dbt compile` command along with `dbt show` to look at the data.

## About

Seeds are the four csvs provided as-is.

Staging (`stg_leads`, `stg_contacts`, `stg_accounts`, `stg_opportunities`) is mostly renaming and casting. A few things I had to handle there:

- There wasn't an `is_converted` column, so I treated conversion as `converted_at` being filled in.
- `is_closed` and `is_won` came in as the strings TRUE / FALSE, so made distinct true columns for them.
- Blank timestamps looked like empty strings when I seeded, so I nullif'd them before casting.
- I renamed `source` to `lead_source` so it matches how the prompt talks about it.

Marts are the AE-facing piece:

- `fct_leads`: one row per lead, converted and not. This is the conversion model.
- `fct_opps`: one row per opportunity, with lead and account fields joined on. This acts as the closed/won model.

I didn't pre-aggregate day / week / month, since it felt easier to leave timestamps on the fact and let the user change the grain. I also left names and emails out of the marts.

In this extract, converted leads, contacts, accounts, and opportunities are the same count, so the joins looked 1:1. I probably wouldn't make this assumption and create testing around the unique identifiers and create deduping logic.

## Answering the questions

Foregoing a full analysis, I mostly grouped the two facts a few times to see if the models were usable. The queries I used are referenced at the bottom of this readme.

### Q1: How many leads were converted by day, week, and month?

I can utilize the `fct_leads` table and filter to `is_converted`, then plot a count of `lead_id` over `converted_at`. Same model can be used for day, week, or month.

I'd use `converted_at`, not `created_at`, because a lead created in March and converted in April belongs on April's conversion chart. It's important to anchor to the correct cohort method to ensure accurate reporting.

Approximatey half the leads converted in the coverage of a year (date range is: spring 2021 through spring 2022). In a production environment, I'd create a date spine, so days with zero conversions wouldn't disappear if aggregated.

### Q2: Which lead sources generated the most converted leads at those grains?

I'd utilize the same chart, and break it down by `lead_source`.

"Most converted" would be a count. Content Form had the most converted leads, and Spreadsheet Tool had the most leads overall.

### Q3: Possible drivers of lead conversion?

I can utilize the `fct_leads` table again. Conversion rate would be calculated as: converted / all leads, and can be sliced by `lead_source`, `job_title`, `industry`, `fleet_size`, and possibly `state` for geo-grain.

Summary: Conversion differences were small and I wouldn’t act on them yet; additional analysis needed to determine directional insights.

What stood out:

- Title: The biggest spread. IT Analysts converted most; Operations Managers, technicians, and drivers converted less. This may reflect who fills out the form more than who buys.
- Industry: Consumer/Business Services and Transportation & Logistics ran slightly above average. Energy and Rental & Leasing ran slightly below.
- Fleet size: The smallest bucket (<15) converted slightly more than the 100-499 bucket.

Caveats:

- No causal relationship was determined. The extract is small, I didn’t control for any relevant factors, and some patterns seemed synthetic (conversion events occurred the same day).
- Time to convert velocity was nearly identical across groups, so cannot de identified as a key driver.

Possible Next steps:

- I can check whether later cohorts just haven’t had as long to convert, which would be important to consider from a holistic funnel perspective.
- Test whether title and source interact, or are independent drivers.

### Q4: Possible drivers of closed/won opportunities?

Using `fct_opportunities`, I'd filter to closed rows before calculating a win rate. A chunk of opps are still open, and aren't considered losses yet. Among closed rows, most of them were won.

I joined the originating lead's source and title, plus the account's industry and fleet size.

- Source: Spreadsheet Tool looked a bit stronger once they got to an opp. Content Form converted the most leads but was a bit weaker on close. The source that fills the funnel isn't obviously the one that closes.
- Title: Operations Manager was a weaker converter and a stronger closer, which I'd want to sanity check. Manager was on the weaker side for wins. 
- Industry / fleet size flipped in a similar way. Some of the softer converting slices looked fine (or better) on closed/won.

Since there's no amount on the opportunity, we are looking at win rates rather than revenue, which would be a relevant factor for business outcomes.

## Q5: How I'd visualize this

A tableau or PowerBI dashboard can be utilized for visualizations.

- One conversion view on `fct_leads`: date grain control on `converted_at`, stacked or grouped bar by `lead_source`, with a conversion rate number next to volume. Filters for title / industry / fleet size.
- A simple funnel: leads created -> converted -> opp closed -> won. Counts can come from the two fact tbales, though I'd call out that this extract doesn't have multiple opps per account.
- A closed/won view on `fct_opportunities` with `status` defaulted to closed (or a toggle for open). Win rate by the same dimensions as conversion, maybe a days to close or velocity metric card.
- I wouldn't put person names or emails on a dashboard to protect PII. Company / industry / fleet size are the useful account attributes here and should be the anchor for business-level views.

## Queries I used to sanity-check the models

Previewing a model: `dbt show --select fct_leads --limit 20`

Converted volume by month and source:

```
dbt show --limit 100 --inline "
select
    date_trunc('month', converted_at) as converted_month,
    lead_source,
    count(*) as converted_leads
from {{ ref('fct_leads') }}
where is_converted
group by 1, 2
order by 1, 3 desc
"
```

Conversion rate by a dimension (swap `lead_source` for `job_title`, `industry`, or `fleet_size`):

```
dbt show --limit 20 --inline "
select
    lead_source,
    count(*) as leads,
    count(*) filter (where is_converted) as converted_leads,
    count(*) filter (where is_converted)::numeric / count(*) as conversion_rate
from {{ ref('fct_leads') }}
group by 1
order by 4 desc
"
```

Win rate among closed opps:

```
dbt show --limit 20 --inline "
select
    lead_source,
    count(*) as closed_opps,
    count(*) filter (where is_won) as won_opps,
    count(*) filter (where is_won)::numeric / count(*) as win_rate
from {{ ref('fct_opportunities') }}
where is_closed
group by 1
order by 4 desc
"
```

I used `is_closed` so open opps stay out of the denominator. Conversely `status` can be used. (`where status != 'open'`).

## Assumptions / leftover thoughts

- Conversion = `converted_at is not null`. Matches having a contact / account / opp in this file.
- Win rate = won / closed, not won / all opps.
- Country is all US, so I didn't model geography beyond state.
- `fleet_size` is ordered text and I didn't add a sort column. Charts will come out alphabetical unless the BI tool orders them.
- In production I'd test that leads don't fan out to multiple opps, and I'd want a revenue field if we cared about pipeline value.