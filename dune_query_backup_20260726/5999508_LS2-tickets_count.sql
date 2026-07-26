-- Dune query 5999508: LS2-tickets count
-- version 13 backed up 2026-07-26

with
daily_tickets as ( -- Old TICKET contract (before Nov 12 2025)
        select
    DATE_TRUNC('day', block_time) as date
    , COUNT(*) as tickets_consumed
        from starknet.events
        where from_address = 0x035f581b050a39958b7188ab5c75daaa1f9d3571a0c032203038c898663f31f8
   and keys [1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
   and keys [3] = 0x0000000000000000000000000000000000000000000000000000000000000000
   and block_time < TIMESTAMP '2025-11-12'
        group by
    1
union all -- New DTICKET contract (from Nov 12 2025 onwards)
        select
    DATE_TRUNC('day', block_time) as date
    , COUNT(*) as tickets_consumed
        from starknet.events
        where from_address = 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136
   and keys [1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
   and keys [3] = 0x0000000000000000000000000000000000000000000000000000000000000000
   and block_time >= TIMESTAMP '2025-11-12'
        group by
    1
)
, raw_prices as ( -- Old TICKET price (before Nov 12)
        select
    day
    , avg_price_usd
        from query_6125279
        where token_symbol = 'TICKET'
   and day < TIMESTAMP '2025-11-12'
union all -- New DTICKET price (from Nov 12 onwards)
        select
    day
    , avg_price_usd
        from query_6125279
        where token_symbol = 'DTICKET'
   and day >= TIMESTAMP '2025-11-12'
)
, ticket_prices as ( -- Forward-fill: use last known price when no price available
        select
    d.date as day
    , COALESCE(
                p.avg_price_usd
        , LAG(p.avg_price_usd) ignore nulls over (
                    order by
    d.date
)
        , LEAD(p.avg_price_usd) ignore nulls over (
                    order by
    d.date
)
) as avg_price_usd
        from daily_tickets d
            left join raw_prices p on d.date = p.day
)
        , daily_with_prices as (
        select
        d.date
        , d.tickets_consumed
        , case
when p.avg_price_usd is not null
    then d.tickets_consumed * p.avg_price_usd
else
    0
end as tickets_usd
        , case
when p.avg_price_usd is not null
    then 1
else
    0
end as has_price
        from daily_tickets d
            left join ticket_prices p on d.date = p.day
)
select
    SUM(tickets_consumed) as "Total tickets consumed"
    , SUM(tickets_usd) as "Total tickets consumed (USD)"
    , SUM(tickets_consumed) / COUNT(distinct date) as "Avg tickets consumed per day"
    , SUM(tickets_usd) / NULLIF(SUM(has_price)
    , 0) as "Avg daily tickets value (USD)"
from daily_with_prices