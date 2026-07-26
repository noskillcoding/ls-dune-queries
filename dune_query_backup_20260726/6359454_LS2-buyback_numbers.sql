-- Dune query 6359454: LS2-buyback numbers
-- version 7 backed up 2026-07-26

WITH lords_prices AS (
  SELECT day, avg_price_usd
  FROM query_6125279
  WHERE token_symbol = 'LORDS'
),

survivor_prices AS (
  SELECT day, avg_price_usd
  FROM query_6125279
  WHERE token_symbol = 'SURVIVOR'
),

lords_distribution AS (
  -- Old TICKET contract (before Nov 12, 2025)
  SELECT
    DATE_TRUNC('day', block_time) AS day,
    data[2] AS to_address,
    CAST(bytearray_to_uint256(data[3]) AS DOUBLE) / 1e18 AS amount
  FROM starknet.events
  WHERE
    from_address = 0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND data[1] = 0x035f581b050a39958b7188ab5c75daaa1f9d3571a0c032203038c898663f31f8
    AND block_time < TIMESTAMP '2025-11-12'

  UNION ALL

  -- New DTICKET contract (from Nov 12, 2025 onwards)
  SELECT
    DATE_TRUNC('day', block_time) AS day,
    data[2] AS to_address,
    CAST(bytearray_to_uint256(data[3]) AS DOUBLE) / 1e18 AS amount
  FROM starknet.events
  WHERE
    from_address = 0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND data[1] = 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136
    AND block_time >= TIMESTAMP '2025-11-12'
),

lords_totals AS (
  SELECT
    SUM(ld.amount) AS total_lords,
    SUM(ld.amount * COALESCE(lp.avg_price_usd, 0)) AS total_lords_usd,
    SUM(CASE WHEN ld.to_address = 0x02e0af29598b407c8716b17f6d2795eca1b471413fa03fb145a5e33722184067 THEN ld.amount ELSE 0 END) AS treasury_lords,
    SUM(CASE WHEN ld.to_address = 0x02e0af29598b407c8716b17f6d2795eca1b471413fa03fb145a5e33722184067 THEN ld.amount * COALESCE(lp.avg_price_usd, 0) ELSE 0 END) AS treasury_lords_usd,
    SUM(CASE WHEN ld.to_address = 0x045c587318c9ebcf2fbe21febf288ee2e3597a21cd48676005a5770a50d433c5 THEN ld.amount ELSE 0 END) AS velords_lords,
    SUM(CASE WHEN ld.to_address = 0x045c587318c9ebcf2fbe21febf288ee2e3597a21cd48676005a5770a50d433c5 THEN ld.amount * COALESCE(lp.avg_price_usd, 0) ELSE 0 END) AS velords_lords_usd
  FROM lords_distribution ld
  LEFT JOIN lords_prices lp ON ld.day = lp.day
),

-- TWAMM transactions (to filter only actual buyback claims)
twamm_transactions AS (
  SELECT DISTINCT transaction_hash
  FROM starknet.events
  WHERE from_address = 0x043e4f09c32d13d43a880e85f69f7de93ceda62d6cf2581a582c6db635548fdc
),

survivor_buybacks AS (
  SELECT
    DATE_TRUNC('day', e.block_time) AS day,
    CAST(bytearray_to_uint256(e.data[1]) AS DOUBLE) / 1e18 AS amount
  FROM starknet.events e
  INNER JOIN twamm_transactions t ON e.transaction_hash = t.transaction_hash
  WHERE
    e.from_address = 0x042dd777885ad2c116be96d4d634abc90a26a790ffb5871e037dd5ae7d2ec86b
    AND e.keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND cardinality(e.keys) >= 3
    AND e.keys[2] = 0x00000005dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b
    AND e.keys[3] = 0x041bb7729efa185f2cab327de0a668886302f1d4969e3edf504c4741648f858b
),

survivor_totals AS (
  SELECT
    SUM(sb.amount) AS total_survivor,
    SUM(sb.amount) * (
      SELECT avg_price_usd
      FROM survivor_prices
      ORDER BY day DESC
      LIMIT 1
    ) AS total_survivor_usd
  FROM survivor_buybacks sb
)

SELECT
  -- LORDS Revenue
  l.total_lords AS "Total LORDS revenue",
  l.total_lords_usd AS "Total LORDS revenue (USD)",

  -- Treasury (80%)
  l.treasury_lords AS "Treasury LORDS (80%)",
  l.treasury_lords_usd AS "Treasury LORDS (USD)",

  -- veLORDS (20%)
  l.velords_lords AS "veLORDS LORDS (20%)",
  l.velords_lords_usd AS "veLORDS LORDS (USD)",

  -- SURVIVOR Buybacks
  s.total_survivor AS "Total SURVIVOR bought back",
  s.total_survivor_usd AS "Total SURVIVOR (USD)"

FROM lords_totals l
CROSS JOIN survivor_totals s
