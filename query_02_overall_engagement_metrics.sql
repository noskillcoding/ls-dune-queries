-- Game Transactions Analysis - V2
--
-- Unique Users (u): Measures the total number of distinct players who have interacted
-- with the game contract, indicating overall user reach.
--
-- Total Transactions (tx): Counts the total interactions, reflecting overall activity
-- and usage volume.
--
-- Transactions per User (utx): Evaluates user engagement by showing the average number
-- of transactions per player across their lifetime.
--
-- Average Unique Users Rate (tday): Total unique players divided by number of active days.
-- This is a lifetime distribution metric.
--
-- Average Daily Transactions (uday): Tracks average transaction volume per day, indicating
-- the game's typical daily activity level.
--
-- Average Daily Active Players (avg_daily_players): True daily active users metric -
-- calculates unique players for each day, then averages across all days. This reflects
-- actual daily engagement patterns.
--
-- Average Weekly Active Players (avg_weekly_players): Weekly active users metric -
-- calculates unique players for each week, then averages across all weeks.
--
-- Average New Players Per Week (avg_new_players_per_week): Player acquisition metric -
-- counts first-time players per week, then averages to show typical weekly growth rate.

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
  WHERE a.contract_address = 0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c
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
