-- Game Transaction Fee Analysis - V2
--
-- Fees: Total transaction fees paid daily in native tokens (STRK or ETH) for all game
-- activity, including both manual wallet and Cartridge controller transactions.
--
-- Fees in USD: Converts total fees to USD for universal cost comparison across different
-- fee tokens and time periods.
--
-- Avg In-Game Action Fee (USD): Average cost per game transaction in USD. This represents
-- the actual cost to execute actions like explore, attack, buy items, etc. Note: Cartridge
-- controller fees may be sponsored, so player out-of-pocket costs may be lower.
--
-- Avg L1 Gas Price (gwei): Ethereum mainnet gas price, which influences Starknet transaction
-- costs. Higher L1 gas typically correlates with higher Starknet fees as data is settled
-- on Ethereum.
--
-- This analysis helps track protocol economics and the true cost of game operations over time.

WITH game_txs AS (
  SELECT
    DISTINCT transaction_hash AS tx
  FROM starknet.calls
  WHERE contract_address = 0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c
),

x AS (
  SELECT
    block_date,
    transaction_hash,
    actual_fee_amount/1e18 AS fee,
    CASE WHEN actual_fee_unit = 'FRI' THEN 'STRK' ELSE 'ETH' END AS x
  FROM starknet.transactions
  JOIN game_txs ON transaction_hash = tx
  WHERE block_time >= timestamp '2023-09-01'
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

l1 AS (
  SELECT
    block_date AS datex,
    AVG(gas_price/1e9) AS l1g
  FROM ethereum.transactions
  WHERE block_time >= timestamp '2023-09-01'
  GROUP BY 1
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
  date,
  "fee token",
  SUM(fee) AS "fees",
  SUM("fee in USD") AS "fees in USD",
  SUM("fee in USD") / COUNT(DISTINCT transaction_hash) AS "avg in-game action fee (USD)",
  AVG(l1g) AS "Avg L1 gas price (gwei)"
FROM final
JOIN l1 ON date = datex
GROUP BY 1, 2
ORDER BY 1 DESC, 2
