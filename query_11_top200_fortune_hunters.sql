-- Top Fortune Hunters - V2
--
-- Rank: Position in the leaderboard based on fortune hunting efficiency score.
--
-- Player Address: Unique wallet address of each player.
--
-- Score: Fortune hunting efficiency score from 0-100, where 100 represents the best fortune hunter.
-- Calculated by normalizing each player's SURVIVOR-per-death ratio against the best ratio.
-- Higher score = more SURVIVOR tokens earned per death. The player with the highest SURVIVOR-per-death
-- ratio gets 100, and all others are scaled proportionally.
--
-- Total deaths: Total number of deaths in Beast Mode.
--
-- SURVIVOR Earned: Total SURVIVOR tokens earned as rewards from claiming beasts and other in-game activities.
--
-- This leaderboard highlights the most efficient fortune hunters - players who earn the most SURVIVOR
-- tokens per death, showing mastery of reward optimization in Beast Mode gameplay. Only includes
-- players with 10+ deaths.

WITH game_owners AS (
  SELECT DISTINCT
    bytearray_to_uint256(keys[4]) as game_id,
    CAST(keys[3] AS VARBINARY) as player_address
  FROM starknet.events
  WHERE from_address = 0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000
    AND cardinality(keys) >= 4
    AND block_time >= TIMESTAMP '2025-09-15'
),

game_settings AS (
  SELECT DISTINCT
    bytearray_to_uint256(data[2]) as game_id,
    bytearray_to_uint256(data[13]) as mode_flag
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND cardinality(data) = 14
    AND block_time >= TIMESTAMP '2025-09-15'
),

all_death_events AS (
  SELECT
    bytearray_to_uint256(data[2]) as game_id,
    bytearray_to_uint256(data[4]) as action_count,
    ROW_NUMBER() OVER (PARTITION BY bytearray_to_uint256(data[2]) ORDER BY bytearray_to_uint256(data[4]) DESC) as rn
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND cardinality(data) = 35
    AND bytearray_to_uint256(data[5]) = 0
    AND block_time >= TIMESTAMP '2025-09-15'
),

final_deaths AS (
  SELECT
    d.game_id,
    g.player_address
  FROM all_death_events d
  INNER JOIN game_owners g ON d.game_id = g.game_id
  LEFT JOIN game_settings s ON d.game_id = s.game_id
  WHERE d.rn = 1
    AND (s.mode_flag = 0 OR s.mode_flag IS NULL)
),

survivor_rewards AS (
  SELECT
    CAST(keys[3] AS VARBINARY) AS player_address,
    SUM(bytearray_to_uint256(data[1]) / 1e18) AS total_survivor_earned
  FROM starknet.events
  WHERE from_address = 0x042dd777885ad2c116be96d4d634abc90a26a790ffb5871e037dd5ae7d2ec86b
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[2] = 0x00a67ef20b61a9846e1c82b411175e6ab167ea9f8632bd6c2091823c3629ec42
    AND block_time >= TIMESTAMP '2025-09-15'
  GROUP BY 1
),

player_stats AS (
  SELECT
    f.player_address,
    COUNT(*) as total_deaths,
    COALESCE(r.total_survivor_earned, 0) AS survivor_earned,
    COALESCE(r.total_survivor_earned, 0) / CAST(COUNT(*) AS DOUBLE) AS ratio
  FROM final_deaths f
  LEFT JOIN survivor_rewards r ON f.player_address = r.player_address
  GROUP BY f.player_address, r.total_survivor_earned
  HAVING COUNT(*) >= 10 AND COALESCE(r.total_survivor_earned, 0) > 0
),

best_ratio AS (
  SELECT MAX(ratio) AS max_ratio
  FROM player_stats
),

ranked_hunters AS (
  SELECT
    p.player_address,
    ROUND((p.ratio / b.max_ratio) * 100, 2) AS score,
    p.total_deaths,
    p.survivor_earned,
    ROW_NUMBER() OVER (ORDER BY (p.ratio / b.max_ratio) DESC) AS rank
  FROM player_stats p
  CROSS JOIN best_ratio b
)

SELECT
  rank AS "Rank",
  player_address AS "Player address",
  score AS "Score",
  total_deaths AS "Total deaths",
  survivor_earned AS "SURVIVOR earned"
FROM ranked_hunters
ORDER BY rank
LIMIT 200
