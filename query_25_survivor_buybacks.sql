-- SURVIVOR Buybacks Tracking
-- Weekly view of SURVIVOR tokens bought back via TWAMM and sent to governance
--
-- Buyback Flow:
-- 1. Treasury sends LORDS to Ekubo TWAMM
-- 2. TWAMM gradually sells LORDS for SURVIVOR
-- 3. Claimed SURVIVOR is sent to Survivor Controller (governance)
--
-- Addresses:
-- Ekubo Core: 0x00000005dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b
-- Survivor Controller: 0x041bb7729efa185f2cab327de0a668886302f1d4969e3edf504c4741648f858b
-- SURVIVOR token: 0x042dd777885ad2c116be96d4d634abc90a26a790ffb5871e037dd5ae7d2ec86b
-- TWAMM Extension: 0x043e4f09c32d13d43a880e85f69f7de93ceda62d6cf2581a582c6db635548fdc

-- TWAMM transactions (to filter only actual buyback claims)
WITH twamm_transactions AS (
  SELECT DISTINCT transaction_hash
  FROM starknet.events
  WHERE from_address = 0x043e4f09c32d13d43a880e85f69f7de93ceda62d6cf2581a582c6db635548fdc
),

weekly_buybacks AS (
  SELECT
    DATE_TRUNC('week', e.block_time) AS week,
    COUNT(*) AS claim_count,
    SUM(CAST(bytearray_to_uint256(e.data[1]) AS DOUBLE) / 1e18) AS survivor_claimed
  FROM starknet.events e
  INNER JOIN twamm_transactions t ON e.transaction_hash = t.transaction_hash
  WHERE
    e.from_address = 0x042dd777885ad2c116be96d4d634abc90a26a790ffb5871e037dd5ae7d2ec86b  -- SURVIVOR token
    AND e.keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9  -- Transfer
    AND cardinality(e.keys) >= 3
    AND e.keys[2] = 0x00000005dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b  -- FROM Ekubo Core
    AND e.keys[3] = 0x041bb7729efa185f2cab327de0a668886302f1d4969e3edf504c4741648f858b  -- TO Survivor Controller
    AND e.block_time >= TIMESTAMP '2025-01-01'
  GROUP BY 1
),

survivor_prices AS (
  SELECT day, avg_price_usd
  FROM query_6125279
  WHERE token_symbol = 'SURVIVOR'
),

-- Get weekly average price
weekly_prices AS (
  SELECT
    DATE_TRUNC('week', day) AS week,
    AVG(avg_price_usd) AS avg_price_usd
  FROM survivor_prices
  GROUP BY 1
)

SELECT
  b.week,
  b.claim_count AS "Buyback claims",
  b.survivor_claimed AS "SURVIVOR claimed",
  b.survivor_claimed * COALESCE(p.avg_price_usd, 0) AS "SURVIVOR claimed (USD)",
  p.avg_price_usd AS "SURVIVOR price (USD)"
FROM weekly_buybacks b
LEFT JOIN weekly_prices p ON b.week = p.week
ORDER BY b.week DESC
