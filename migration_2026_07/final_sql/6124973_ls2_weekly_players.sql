-- Dune query 6124973: LS2-weekly players
-- https://dune.com/queries/6124973
-- version 5 as of 2026-07-26

-- 2026-07-26: migrated to span the Loot Survivor V1->V2 contract cutover.
-- The V1 game contract went dead after 2026-05-04; V2 took over 2026-05-05.
-- Both are now included so the series stays continuous.
WITH all_txs AS (
  SELECT
    DISTINCT caller_address,
    sender_address,
    CASE WHEN caller_address != sender_address
      THEN 'Cartridge controller'
      ELSE 'Manual'
    END AS "Account type",
    a.transaction_hash AS tx,
    DATE_TRUNC('week', a.block_time) AS tm
  FROM starknet.calls a
  JOIN starknet.transactions b
    ON a.transaction_hash = b.transaction_hash
  WHERE a.contract_address IN (
      0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c,  -- game V1 (through 2026-05-04)
      0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405   -- game V2 (from 2026-05-05)
    )
),

f_txs AS (
  SELECT
    DISTINCT caller_address AS f_player,
    MIN(tm) AS f_date
  FROM all_txs
  GROUP BY 1
),

f_game AS (
  SELECT
    f_date,
    COUNT(DISTINCT f_player) AS "New players"
  FROM f_txs
  GROUP BY 1
),

all_txs2 AS (
  SELECT
    tm AS date,
    COUNT(DISTINCT caller_address) AS "Total players"
  FROM all_txs
  GROUP BY 1
)

SELECT
  date,
  "Total players",
  COALESCE("New players", 0) AS "New players",
  "Total players" - COALESCE("New players", 0) AS "Existing players"
FROM all_txs2
LEFT JOIN f_game ON date = f_date
ORDER BY date
