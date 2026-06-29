-- Total Beast Mode Tickets Summary with USD - V4
--
-- Total Tickets Consumed: Cumulative count of all dungeon tickets burned to enter Beast Mode
-- since launch. Counted by tracking ticket token burn events (transfers to zero address), providing
-- an accurate count regardless of which game contract function is called or controller used.
--
-- Note: Due to a bug in the original TICKET contract, a new DTICKET contract was deployed on
-- November 12, 2025. This query uses TICKET burns before Nov 12 and DTICKET burns from Nov 12 onwards.
--   - TICKET:  0x035f581b050a39958b7188ab5c75daaa1f9d3571a0c032203038c898663f31f8
--   - DTICKET: 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136
--
-- Total Tickets Consumed (USD): Total dollar value of all tickets consumed, calculated using
-- historical daily token prices from Ekubo DEX. Uses forward-fill to handle days without trading.
--
-- Avg Tickets Consumed Per Day: Average daily ticket consumption rate across all active days.
--
-- Avg Daily Tickets Value (USD): Average daily dollar value of tickets consumed, calculated only
-- for days when price data is available (including forward-filled prices).
--
-- These summary metrics provide a snapshot of overall Beast Mode engagement (volume) and economic
-- activity (USD value).

WITH daily_tickets AS (
  -- Old TICKET contract (before Nov 12, 2025)
  SELECT
    DATE_TRUNC('day', block_time) AS date,
    COUNT(*) AS tickets_consumed
  FROM starknet.events
  WHERE
    from_address = 0x035f581b050a39958b7188ab5c75daaa1f9d3571a0c032203038c898663f31f8
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[3] = 0x0000000000000000000000000000000000000000000000000000000000000000
    AND block_time < TIMESTAMP '2025-11-12'
  GROUP BY 1

  UNION ALL

  -- New DTICKET contract (from Nov 12, 2025 onwards)
  SELECT
    DATE_TRUNC('day', block_time) AS date,
    COUNT(*) AS tickets_consumed
  FROM starknet.events
  WHERE
    from_address = 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[3] = 0x0000000000000000000000000000000000000000000000000000000000000000
    AND block_time >= TIMESTAMP '2025-11-12'
  GROUP BY 1
),

raw_prices AS (
  -- Old TICKET price (before Nov 12)
  SELECT day, avg_price_usd
  FROM query_6125279
  WHERE token_symbol = 'TICKET'
    AND day < TIMESTAMP '2025-11-12'

  UNION ALL

  -- New DTICKET price (from Nov 12 onwards)
  SELECT day, avg_price_usd
  FROM query_6125279
  WHERE token_symbol = 'DTICKET'
    AND day >= TIMESTAMP '2025-11-12'
),

ticket_prices AS (
  -- Forward-fill: use last known price when no price available
  SELECT
    d.date AS day,
    COALESCE(
      p.avg_price_usd,
      LAG(p.avg_price_usd) IGNORE NULLS OVER (ORDER BY d.date),
      LEAD(p.avg_price_usd) IGNORE NULLS OVER (ORDER BY d.date)
    ) AS avg_price_usd
  FROM daily_tickets d
  LEFT JOIN raw_prices p ON d.date = p.day
),

daily_with_prices AS (
  SELECT
    d.date,
    d.tickets_consumed,
    CASE
      WHEN p.avg_price_usd IS NOT NULL
      THEN d.tickets_consumed * p.avg_price_usd
      ELSE 0
    END AS tickets_usd,
    CASE WHEN p.avg_price_usd IS NOT NULL THEN 1 ELSE 0 END AS has_price
  FROM daily_tickets d
  LEFT JOIN ticket_prices p ON d.date = p.day
)

SELECT
  SUM(tickets_consumed) AS "Total tickets consumed",
  SUM(tickets_usd) AS "Total tickets consumed (USD)",
  SUM(tickets_consumed) / COUNT(DISTINCT date) AS "Avg tickets consumed per day",
  SUM(tickets_usd) / NULLIF(SUM(has_price), 0) AS "Avg daily tickets value (USD)"
FROM daily_with_prices
