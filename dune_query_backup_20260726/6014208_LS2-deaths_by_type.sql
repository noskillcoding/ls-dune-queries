-- Dune query 6014208: LS2-deaths by type
-- version 3 backed up 2026-07-26

WITH game_settings AS (
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
  SELECT
    bytearray_to_uint256(data[2]) as game_id,
    bytearray_to_uint256(data[4]) as action_count,
    bytearray_to_uint256(data[9]) as beast_health,
    ROW_NUMBER() OVER (PARTITION BY bytearray_to_uint256(data[2]) ORDER BY bytearray_to_uint256(data[4]) DESC) as rn
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND cardinality(data) = 35
    AND bytearray_to_uint256(data[5]) = 0
    AND block_time >= TIMESTAMP '2024-09-01'
),

final_deaths AS (
  SELECT
    d.game_id,
    d.beast_health,
    COALESCE(s.settings_id, 1) as settings_id
  FROM all_death_events d
  LEFT JOIN game_settings s ON d.game_id = s.game_id
  WHERE d.rn = 1
    AND COALESCE(s.settings_id, 1) = 1
),

death_types AS (
  SELECT
    CASE
      WHEN beast_health = 0 THEN 'Obstacle'
      WHEN beast_health > 0 THEN 'Beast'
      ELSE 'Unknown'
    END as death_type,
    CASE
      WHEN beast_health = 0 THEN 1
      WHEN beast_health > 0 THEN 2
      ELSE 3
    END as sort_order
  FROM final_deaths
),

total_deaths AS (
  SELECT COUNT(*) as total
  FROM death_types
)

SELECT
  dt.death_type AS "Death type",
  COUNT(*) AS "Deaths",
  ROUND(COUNT(*) * 100.0 / t.total, 2) AS "Percentage"
FROM death_types dt
CROSS JOIN total_deaths t
GROUP BY dt.death_type, dt.sort_order, t.total
ORDER BY dt.sort_order
