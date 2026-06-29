-- Top 50 Beast Mode Leaderboard (Last 2 Weeks)
-- Players ranked by highest level reached at death in Beast Mode
-- Rolling 2-week window

WITH game_owners AS (
  SELECT DISTINCT
    bytearray_to_uint256(keys[4]) as game_id,
    CAST(keys[3] AS VARBINARY) as player_address
  FROM starknet.events
  WHERE from_address = 0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000
    AND cardinality(keys) >= 4
    AND block_time >= NOW() - INTERVAL '14' DAY
),

game_settings AS (
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
  SELECT
    bytearray_to_uint256(data[2]) as game_id,
    bytearray_to_uint256(data[4]) as action_count,
    bytearray_to_uint256(data[7]) as xp,
    FLOOR(SQRT(CAST(bytearray_to_uint256(data[7]) AS DOUBLE))) as level,
    bytearray_to_uint256(data[8]) as gold,
    bytearray_to_uint256(data[9]) as beast_health,
    ROW_NUMBER() OVER (PARTITION BY bytearray_to_uint256(data[2]) ORDER BY bytearray_to_uint256(data[4]) DESC) as rn
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND cardinality(data) = 35
    AND bytearray_to_uint256(data[5]) = 0
    AND block_time >= NOW() - INTERVAL '14' DAY
),

final_deaths AS (
  SELECT
    d.game_id,
    d.level,
    d.xp,
    d.gold,
    d.beast_health,
    g.player_address
  FROM all_death_events d
  INNER JOIN game_owners g ON d.game_id = g.game_id
  LEFT JOIN game_settings s ON d.game_id = s.game_id
  WHERE d.rn = 1
    AND (s.mode_flag = 0 OR s.mode_flag IS NULL)
),

ranked_deaths AS (
  SELECT
    player_address,
    level,
    xp,
    gold,
    CASE
      WHEN beast_health = 0 THEN 'Obstacle'
      WHEN beast_health > 0 THEN 'Beast'
      ELSE 'Unknown'
    END as death_cause,
    ROW_NUMBER() OVER (ORDER BY level DESC, xp DESC) as rank
  FROM final_deaths
)

SELECT
  rank AS "Rank",
  player_address AS "Player address",
  level AS "Level",
  xp AS "XP",
  gold AS "Gold",
  death_cause AS "Death cause"
FROM ranked_deaths
WHERE rank <= 50
ORDER BY rank
