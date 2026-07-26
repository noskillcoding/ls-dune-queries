-- Dune query 5996449: LS2-total
-- https://dune.com/queries/5996449
-- version 15 as of 2026-07-26

-- 2026-07-26: migrated to span the Loot Survivor V1->V2 contract cutover.
-- The V1 game contract went dead after 2026-05-04; V2 took over 2026-05-05.
-- Both are now included so the series stays continuous.
WITH
game_txs AS (
  SELECT
    DISTINCT caller_address,
    sender_address,
    CASE WHEN caller_address != sender_address
      THEN 'Cartridge controller'
      ELSE 'Manual'
    END AS "Account type",
    a.transaction_hash AS txx,
    DATE_TRUNC('day', a.block_time) AS date,
    DATE_TRUNC('week', a.block_time) AS week
  FROM starknet.calls a
  JOIN starknet.transactions b
    ON a.transaction_hash = b.transaction_hash
  WHERE a.contract_address IN (
      0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c,  -- game V1 (through 2026-05-04)
      0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405   -- game V2 (from 2026-05-05)
    )
),
daily_stats AS (
  SELECT
    date,
    COUNT(DISTINCT caller_address) AS daily_players
  FROM game_txs
  GROUP BY date
),
weekly_stats AS (
  SELECT
    week,
    COUNT(DISTINCT caller_address) AS weekly_players
  FROM game_txs
  GROUP BY week
),
first_play AS (
  SELECT
    caller_address,
    MIN(week) AS first_week
  FROM game_txs
  GROUP BY caller_address
),
weekly_new_players AS (
  SELECT
    first_week,
    COUNT(DISTINCT caller_address) AS new_players
  FROM first_play
  GROUP BY first_week
)

SELECT
  (SELECT COUNT(DISTINCT caller_address) FROM game_txs) AS u,
  (SELECT COUNT(DISTINCT txx) FROM game_txs) AS tx,
  (SELECT COUNT(DISTINCT txx) FROM game_txs) / (SELECT COUNT(DISTINCT caller_address) FROM game_txs) AS utx,
  (SELECT COUNT(DISTINCT caller_address) FROM game_txs) / (SELECT COUNT(DISTINCT date) FROM game_txs) AS tday,
  (SELECT COUNT(DISTINCT txx) FROM game_txs) / (SELECT COUNT(DISTINCT date) FROM game_txs) AS uday,
  (SELECT AVG(daily_players) FROM daily_stats) AS avg_daily_players,
  (SELECT AVG(weekly_players) FROM weekly_stats) AS avg_weekly_players,
  (SELECT AVG(new_players) FROM weekly_new_players) AS avg_new_players_per_week
