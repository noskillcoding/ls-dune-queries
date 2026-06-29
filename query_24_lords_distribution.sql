-- LORDS Revenue Distribution from Ticket Sales
-- Tracks daily LORDS distribution: 80% to Treasury (buybacks), 20% to veLORDS
--
-- Revenue Flow:
-- 1. Users buy TICKET/DTICKET with various tokens
-- 2. Protocol converts to LORDS
-- 3. 80% goes to Treasury for SURVIVOR buybacks
-- 4. 20% goes to veLORDS stakers
--
-- Note: Due to a bug, TICKET was replaced by DTICKET on Nov 12, 2025
--   - TICKET:  0x035f581b050a39958b7188ab5c75daaa1f9d3571a0c032203038c898663f31f8
--   - DTICKET: 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136
--
-- Addresses:
-- LORDS token: 0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49
-- Treasury (80%): 0x02e0af29598b407c8716b17f6d2795eca1b471413fa03fb145a5e33722184067
-- veLORDS (20%): 0x045c587318c9ebcf2fbe21febf288ee2e3597a21cd48676005a5770a50d433c5

WITH lords_transfers AS (
  -- Old TICKET contract (before Nov 12, 2025)
  SELECT
    DATE_TRUNC('day', block_time) AS date,
    data[2] AS to_address,
    CAST(bytearray_to_uint256(data[3]) AS DOUBLE) / 1e18 AS amount
  FROM starknet.events
  WHERE
    from_address = 0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49  -- LORDS token
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9  -- Transfer
    AND data[1] = 0x035f581b050a39958b7188ab5c75daaa1f9d3571a0c032203038c898663f31f8  -- from TICKET contract
    AND block_time < TIMESTAMP '2025-11-12'

  UNION ALL

  -- New DTICKET contract (from Nov 12, 2025 onwards)
  SELECT
    DATE_TRUNC('day', block_time) AS date,
    data[2] AS to_address,
    CAST(bytearray_to_uint256(data[3]) AS DOUBLE) / 1e18 AS amount
  FROM starknet.events
  WHERE
    from_address = 0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49  -- LORDS token
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9  -- Transfer
    AND data[1] = 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136  -- from DTICKET contract
    AND block_time >= TIMESTAMP '2025-11-12'
),

daily_distribution AS (
  SELECT
    date,
    SUM(amount) AS total_lords,
    SUM(CASE WHEN to_address = 0x02e0af29598b407c8716b17f6d2795eca1b471413fa03fb145a5e33722184067 THEN amount ELSE 0 END) AS treasury_lords,
    SUM(CASE WHEN to_address = 0x045c587318c9ebcf2fbe21febf288ee2e3597a21cd48676005a5770a50d433c5 THEN amount ELSE 0 END) AS velords_lords
  FROM lords_transfers
  GROUP BY 1
),

lords_prices AS (
  SELECT day, avg_price_usd
  FROM query_6125279
  WHERE token_symbol = 'LORDS'
),

-- Forward-fill prices for days without trading
daily_with_prices AS (
  SELECT
    d.date,
    d.total_lords,
    d.treasury_lords,
    d.velords_lords,
    COALESCE(
      p.avg_price_usd,
      LAG(p.avg_price_usd) IGNORE NULLS OVER (ORDER BY d.date),
      LEAD(p.avg_price_usd) IGNORE NULLS OVER (ORDER BY d.date)
    ) AS lords_price_usd
  FROM daily_distribution d
  LEFT JOIN lords_prices p ON d.date = p.day
)

SELECT
  date,
  total_lords AS "Total LORDS revenue",
  total_lords * COALESCE(lords_price_usd, 0) AS "Total revenue (USD)",
  treasury_lords AS "Treasury (80% - buybacks)",
  treasury_lords * COALESCE(lords_price_usd, 0) AS "Treasury (USD)",
  velords_lords AS "veLORDS (20% - stakers)",
  velords_lords * COALESCE(lords_price_usd, 0) AS "veLORDS (USD)",
  lords_price_usd AS "LORDS price (USD)"
FROM daily_with_prices
ORDER BY date DESC
