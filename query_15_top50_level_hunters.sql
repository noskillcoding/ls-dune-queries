-- Top Level Hunters (Last 2 Weeks)
--
-- Rank: Position in the leaderboard based on average level reached at death.
--
-- Player Address: Unique wallet address of each player.
--
-- Score: Level hunting efficiency score from 0-100, normalized against the best performer.
--
-- Total Deaths: Total number of deaths in Beast Mode.
--
-- Avg Level: Average level reached across all deaths.
--
-- Time window: Last 2 weeks only. Minimum 10 deaths required.

WITH game_owners AS (
  -- Map game NFT token IDs to player addresses via Transfer events (mint)
  -- Token ID is in keys[4], not data[3]
  SELECT DISTINCT
    bytearray_to_uint256(keys[4]) as game_id,
    CAST(keys[3] AS VARBINARY) as player_address
  FROM starknet.events
  WHERE from_address = 0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9  -- Transfer event
    AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000  -- from = 0 (mint)
    AND cardinality(keys) >= 4
    AND block_time >= NOW() - INTERVAL '14' DAY
),

game_settings AS (
  -- Extract mode flag from 14-field GameEvents
  SELECT DISTINCT
    bytearray_to_uint256(data[2]) as game_id,
    bytearray_to_uint256(data[13]) as mode_flag
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND cardinality(data) = 14
    AND block_time >= NOW() - INTERVAL '14' DAY
),

all_death_events AS (
  -- Get all death events (health=0) with their game state
  SELECT
    bytearray_to_uint256(data[2]) as game_id,
    bytearray_to_uint256(data[4]) as action_count,
    bytearray_to_uint256(data[7]) as xp,
    FLOOR(SQRT(CAST(bytearray_to_uint256(data[7]) AS DOUBLE))) as level,
    ROW_NUMBER() OVER (PARTITION BY bytearray_to_uint256(data[2]) ORDER BY bytearray_to_uint256(data[4]) DESC) as rn
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND cardinality(data) = 35
    AND bytearray_to_uint256(data[5]) = 0  -- health = 0 (death)
    AND block_time >= NOW() - INTERVAL '14' DAY
),

final_deaths AS (
  -- Keep only the final death state per game (highest action_count)
  SELECT
    d.game_id,
    d.level,
    g.player_address
  FROM all_death_events d
  INNER JOIN game_owners g ON d.game_id = g.game_id
  LEFT JOIN game_settings s ON d.game_id = s.game_id
  WHERE d.rn = 1  -- Only final death state
    AND (s.mode_flag = 0 OR s.mode_flag IS NULL)  -- Beast mode only
),

player_stats AS (
  SELECT
    f.player_address,
    -- Calculate average level across all deaths
    ROUND(AVG(CAST(f.level AS DOUBLE)), 2) as avg_level,
    COUNT(*) as total_deaths
  FROM final_deaths f
  GROUP BY f.player_address
  HAVING COUNT(*) >= 10  -- Minimum 10 deaths
),

best_avg AS (
  SELECT MAX(avg_level) AS max_avg
  FROM player_stats
),

ranked_hunters AS (
  SELECT
    p.player_address,
    ROUND((p.avg_level / b.max_avg) * 100, 2) AS score,
    p.total_deaths,
    p.avg_level,
    ROW_NUMBER() OVER (ORDER BY (p.avg_level / b.max_avg) DESC) AS rank
  FROM player_stats p
  CROSS JOIN best_avg b
)

SELECT
  rank AS "Rank",
  player_address AS "Player address",
  score AS "Score",
  total_deaths AS "Total deaths",
  avg_level AS "Avg level"
FROM ranked_hunters
WHERE rank <= 50
ORDER BY rank
