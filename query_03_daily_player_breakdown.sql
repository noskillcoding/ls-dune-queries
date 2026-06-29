-- Daily Player Breakdown - V2
--
-- Tracks daily player activity broken down by:
-- - Total players: All distinct active players on that day
-- - New players: Players who played for the first time on that day
-- - Existing players: Returning players (Total - New)
--
-- This query provides insight into player acquisition and retention patterns over time.

WITH all_txs AS (
  SELECT
    DISTINCT caller_address,
    sender_address,
    CASE WHEN caller_address != sender_address
      THEN 'Cartridge controller'
      ELSE 'Manual'
    END AS "Account type",
    a.transaction_hash AS tx,
    DATE_TRUNC('day', a.block_time) AS tm
  FROM starknet.calls a
  JOIN starknet.transactions b
    ON a.transaction_hash = b.transaction_hash
  WHERE a.contract_address = 0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c
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
