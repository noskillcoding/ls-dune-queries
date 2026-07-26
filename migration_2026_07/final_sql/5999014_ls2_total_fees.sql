-- Dune query 5999014: LS2-total fees
-- https://dune.com/queries/5999014
-- version 7 as of 2026-07-26

-- 2026-07-26: migrated to span the Loot Survivor V1->V2 contract cutover.
-- The V1 game contract went dead after 2026-05-04; V2 took over 2026-05-05.
-- Both are now included so the series stays continuous.
WITH game_txs AS (
  SELECT
    DISTINCT transaction_hash AS tx
  FROM starknet.calls
  WHERE contract_address IN (
      0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c,  -- game V1 (through 2026-05-04)
      0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405   -- game V2 (from 2026-05-05)
    )
),

x AS (
  SELECT
    block_date,
    transaction_hash,
    actual_fee_amount/1e18 AS fee,
    CASE WHEN actual_fee_unit = 'FRI' THEN 'STRK' ELSE 'ETH' END AS x
  FROM starknet.transactions
  JOIN game_txs ON transaction_hash = tx
  WHERE block_time >= timestamp '2025-09-15'
),

prices AS (
  SELECT
    DATE_TRUNC('day', minute) AS time,
    AVG(price) AS pr,
    CASE WHEN contract_address = 0xca14007eff0db1f8135f4c25b34de49ab0d42766 THEN 'STRK' ELSE 'ETH' END AS tk
  FROM prices.usd
  WHERE blockchain = 'ethereum'
    AND contract_address IN (0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2, 0xca14007eff0db1f8135f4c25b34de49ab0d42766)
  GROUP BY 1, 3
),

final AS (
  SELECT
    DATE_TRUNC('day', block_date) AS date,
    transaction_hash,
    fee,
    fee*pr AS "fee in USD",
    tk AS "fee token"
  FROM x
  JOIN prices ON block_date = time AND x = tk
)

SELECT
  SUM("fee in USD") AS "fees in USD",
  ROUND(SUM("fee in USD") / COUNT(DISTINCT transaction_hash), 5) AS "avg in-game action fee (USD)"
FROM final
