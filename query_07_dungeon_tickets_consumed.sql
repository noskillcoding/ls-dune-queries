-- Beast Mode Entry Tracking - V6
--
-- Dungeon Tickets Consumed: Number of dungeon tickets burned daily to enter Beast Mode.
-- Counted by tracking ticket token burn events (transfers to zero address), providing an
-- accurate count regardless of which game contract function is called or controller used.
--
-- Note: Due to a bug in the original TICKET contract, a new DTICKET contract was deployed.
-- This query uses TICKET burns before Nov 12, 2025 and DTICKET burns from Nov 12 onwards.
--   - TICKET:  0x035f581b050a39958b7188ab5c75daaa1f9d3571a0c032203038c898663f31f8
--   - DTICKET: 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136
--
-- Tickets Consumed (USD): Dollar value of tickets consumed, calculated using daily token
-- prices from Ekubo DEX. Shows the economic value of Beast Mode entry activity.
-- Uses forward-fill to handle days with no trading activity (carries last known price).
--
-- Unique Players: Distinct players who burned tickets each day, identified from the burn
-- event's sender address.
--
-- TICKET Price (USD): Daily average ticket token price in USD from Ekubo DEX, useful for
-- visualizing price trends alongside consumption patterns.
--
-- Acquired from Ekubo: Total DTICKET received by users from Ekubo (Nov 12+ only). Combines
-- pool purchases (swapping LORDS for DTICKET) and TWAMM claims (gradual distribution).
--
-- Beast Mode is the primary game mode where players burn dungeon tickets to start new adventures.
-- This metric tracks both player engagement (count) and economic activity (USD value) around
-- ticket consumption by monitoring actual token burns on-chain.

WITH daily_tickets AS (
  -- Old TICKET contract (before Nov 12, 2025)
  SELECT
    DATE_TRUNC('day', block_time) AS date,
    COUNT(*) AS tickets_consumed,
    COUNT(DISTINCT keys[2]) AS unique_players
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
    COUNT(*) AS tickets_consumed,
    COUNT(DISTINCT keys[2]) AS unique_players
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

-- DTICKET acquired from Ekubo (pool buys + TWAMM claims)
dticket_acquired AS (
  SELECT
    DATE_TRUNC('day', block_time) AS date,
    SUM(CAST(bytearray_to_uint256(data[1]) AS DOUBLE) / 1e18) AS tokens_acquired
  FROM starknet.events
  WHERE
    from_address = 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136  -- DTICKET
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9  -- Transfer
    AND keys[2] IN (
      0x00000005dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b,  -- Ekubo Core
      0x04505a9f06f2bd639b6601f37a4dc0908bb70e8e0e0c34b1220827d64f4fc066,  -- AMM Pool
      0x0199741822c2dc722f6f605204f35e56dbc23bceed54818168c4c49e4fb8737e   -- TWAMM Distribution
    )
    AND keys[3] NOT IN (
      0x0000000000000000000000000000000000000000000000000000000000000000,  -- not to zero
      0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136,  -- not to DTICKET contract
      0x00000005dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b,  -- not to Ekubo Core
      0x04505a9f06f2bd639b6601f37a4dc0908bb70e8e0e0c34b1220827d64f4fc066,  -- not to AMM Pool
      0x0199741822c2dc722f6f605204f35e56dbc23bceed54818168c4c49e4fb8737e   -- not to TWAMM Distribution
    )
    AND block_time >= TIMESTAMP '2025-11-12'
  GROUP BY 1
)

SELECT
  d.date,
  d.tickets_consumed AS "Dungeon tickets consumed",
  d.tickets_consumed * COALESCE(p.avg_price_usd, 0) AS "Tickets consumed (USD)",
  d.unique_players AS "Unique players",
  p.avg_price_usd AS "TICKET price (USD)",
  COALESCE(a.tokens_acquired, 0) AS "Acquired from Ekubo"
FROM daily_tickets d
LEFT JOIN ticket_prices p ON d.date = p.day
LEFT JOIN dticket_acquired a ON d.date = a.date
ORDER BY d.date DESC
