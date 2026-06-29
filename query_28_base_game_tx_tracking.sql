-- Base Game Transaction Tracking
-- Daily breakdown of game transactions vs total Starknet network transactions
-- Tracks direct calls and VRF-wrapped calls to game contracts
--
-- Game Contracts (function selectors):
-- 0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c
-- 0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4
-- 0x058f888ba5897efa811eca5e5818540d35b664f4281660cd839cd5a4b0bf4582
-- 0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd
-- 0x0224a29aE7eB8914B434AaB687e0FC89AA96B188C4F0837E1C7892afE2284782
-- 0x075d886f3c53ff8f9ef413d88d9e0c8ee56216fed8c32d64b767b9fa271aa0dd
--
-- Output: Stacked chart data showing Game vs Other Starknet transactions per day

WITH base_tx AS (
  SELECT
    t.block_date,
    t.transaction_hash,
    t.actual_fee_amount / 1e18 AS fee,
    CASE
      -- Direct call
      WHEN CARDINALITY(t.calldata) > 23
           AND t.calldata[11] IN (
             0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c,
             0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4,
             0x058f888ba5897efa811eca5e5818540d35b664f4281660cd839cd5a4b0bf4582,
             0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd,
             0x0224a29aE7eB8914B434AaB687e0FC89AA96B188C4F0837E1C7892afE2284782,
             0x075d886f3c53ff8f9ef413d88d9e0c8ee56216fed8c32d64b767b9fa271aa0dd
           )
        THEN t.calldata[2]
      -- VRF wrapped call
      WHEN CARDINALITY(t.calldata) > 23
           AND t.calldata[23] IN (
             0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c,
             0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4,
             0x058f888ba5897efa811eca5e5818540d35b664f4281660cd839cd5a4b0bf4582,
             0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd,
             0x0224a29aE7eB8914B434AaB687e0FC89AA96B188C4F0837E1C7892afE2284782,
             0x075d886f3c53ff8f9ef413d88d9e0c8ee56216fed8c32d64b767b9fa271aa0dd
           )
        THEN t.calldata[11]
      ELSE NULL
    END AS matched_user,
    CASE
      WHEN CARDINALITY(t.calldata) > 23
           AND t.calldata[11] IN (
             0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c,
             0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4,
             0x058f888ba5897efa811eca5e5818540d35b664f4281660cd839cd5a4b0bf4582,
             0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd,
             0x0224a29aE7eB8914B434AaB687e0FC89AA96B188C4F0837E1C7892afE2284782,
             0x075d886f3c53ff8f9ef413d88d9e0c8ee56216fed8c32d64b767b9fa271aa0dd
           )
        THEN t.calldata[12]
      WHEN CARDINALITY(t.calldata) > 23
           AND t.calldata[23] IN (
             0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c,
             0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4,
             0x058f888ba5897efa811eca5e5818540d35b664f4281660cd839cd5a4b0bf4582,
             0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd,
             0x0224a29aE7eB8914B434AaB687e0FC89AA96B188C4F0837E1C7892afE2284782,
             0x075d886f3c53ff8f9ef413d88d9e0c8ee56216fed8c32d64b767b9fa271aa0dd
           )
        THEN t.calldata[24]
      ELSE NULL
    END AS adventurer_id
  FROM starknet.transactions t
  WHERE
    t.block_time >= TIMESTAMP '2025-09-16 16:30:00'
    AND CARDINALITY(t.calldata) > 23
    AND (
      t.calldata[11] IN (
         0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c,
         0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4,
         0x058f888ba5897efa811eca5e5818540d35b664f4281660cd839cd5a4b0bf4582,
         0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd,
         0x0224a29aE7eB8914B434AaB687e0FC89AA96B188C4F0837E1C7892afE2284782,
         0x075d886f3c53ff8f9ef413d88d9e0c8ee56216fed8c32d64b767b9fa271aa0dd
      )
      OR t.calldata[23] IN (
         0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c,
         0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4,
         0x058f888ba5897efa811eca5e5818540d35b664f4281660cd839cd5a4b0bf4582,
         0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd,
         0x0224a29aE7eB8914B434AaB687e0FC89AA96B188C4F0837E1C7892afE2284782,
         0x075d886f3c53ff8f9ef413d88d9e0c8ee56216fed8c32d64b767b9fa271aa0dd
      )
    )
),

-- Price data for STRK (kept for consistency, though unused)
prices AS (
  SELECT
    DATE_TRUNC('day', minute) AS time,
    AVG(price) AS price
  FROM prices.usd
  WHERE blockchain = 'ethereum'
    AND contract_address = 0xca14007eff01f8135f4c25b34de49ab0d42766
  GROUP BY 1
),

-- Total Starknet TXs per day
total_starknet_txs AS (
  SELECT
    DATE_TRUNC('day', block_time) AS day,
    COUNT(*) AS total_txs
  FROM starknet.transactions
  WHERE block_time >= TIMESTAMP '2025-09-16 16:30:00'
  GROUP BY 1
),

-- Count daily game TXs
daily_stats AS (
  SELECT
    DATE_TRUNC('day', block_date) AS day,
    COUNT(DISTINCT transaction_hash) AS daily_game_txs
  FROM base_tx
  GROUP BY 1
),

-- Compare with total network TXs
combined AS (
  SELECT
    d.day,
    d.daily_game_txs,
    (t.total_txs - d.daily_game_txs) AS other_txs,
    t.total_txs
  FROM daily_stats d
  LEFT JOIN total_starknet_txs t ON t.day = d.day
),

-- Reshape into long format for stacked chart
stacked AS (
  SELECT day, 'Game Transactions' AS category, daily_game_txs AS tx_count FROM combined
  UNION ALL
  SELECT day, 'Other Starknet Transactions' AS category, other_txs AS tx_count FROM combined
),

-- Total game TXs overall
totals AS (
  SELECT
    'tions' AS category,
    SUM(daily_game_txs) AS total_game_txs
  FROM combined
)

-- Final Output: daily breakdown + total summary row
SELECT
  s.day,
  s.category,
  s.tx_count,
  NULL AS total_game_txs
FROM stacked s

UNION ALL

SELECT
  NULL AS day,
  t.category,
  NULL AS tx_count,
  t.total_game_txs
FROM totals t

ORDER BY day NULLS LAST;
