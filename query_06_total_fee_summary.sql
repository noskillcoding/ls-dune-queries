-- Total Game Fee Summary - V2
--
-- Fees in USD: Cumulative total of all transaction fees paid (in USD) for game activity
-- since launch. This represents the total economic cost of all in-game actions including
-- explore, attack, buy items, stat upgrades, etc. Includes both manual wallet and Cartridge
-- controller transactions.
--
-- Avg In-Game Action Fee (USD): Average cost per game transaction across all time. This
-- metric shows the typical cost efficiency of playing the game. Note: Cartridge controller
-- fees may be sponsored, reducing actual player out-of-pocket costs.
--
-- These summary metrics provide a snapshot of the game's overall transaction economics
-- and player cost burden.

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
