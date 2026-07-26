-- Dune query 6011955: LS2-deaths
-- version 51 backed up 2026-07-26 (was archived)

WITH game_settings AS (
  -- Extract Settings ID from 14-field GameEvents
  SELECT DISTINCT
    bytearray_to_uint256(data[2]) as game_id,
    bytearray_to_uint256(data[6]) as settings_id
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND cardinality(data) = 14
    AND block_time >= TIMESTAMP '2024-09-01'
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
    AND block_time >= TIMESTAMP '2024-09-01'
),

final_deaths AS (
  -- Keep only the final death state per game (highest action_count)
  SELECT
    d.game_id,
    d.level,
    COALESCE(s.settings_id, 1) as settings_id
  FROM all_death_events d
  LEFT JOIN game_settings s ON d.game_id = s.game_id
  WHERE d.rn = 1  -- Only final death state
    AND COALESCE(s.settings_id, 1) = 1  -- Beast mode only
)

SELECT
  level AS "Level",
  COUNT(*) AS "Deaths"
FROM final_deaths
WHERE level BETWEEN 1 AND 60
GROUP BY level
ORDER BY level
