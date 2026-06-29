-- Deaths by Day and Mode
--
-- Date: The day when deaths occurred.
--
-- Total deaths: Total number of deaths across all game modes on that day.
--
-- Deaths in Beast Mode: Number of deaths in Beast Mode games on that day. Beast Mode games
-- are identified by having mode_flag = 0 in game settings (data[13] = 0).
-- In Beast Mode, players start immediately in battle with a beast.
--
-- Deaths in Other Modes: Number of deaths in tournament/non-Beast Mode games on that day.
-- These games are identified by having mode_flag = 1 in game settings (data[13] = 1).
-- This includes competitive tournaments (like "budokan") and other game modes.

WITH game_settings AS (
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
    DATE_TRUNC('day', block_time) as death_date,
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
    d.death_date,
    s.mode_flag
  FROM all_death_events d
  LEFT JOIN game_settings s ON d.game_id = s.game_id
  WHERE d.rn = 1
)

SELECT
  death_date AS "Date",
  COUNT(*) AS "Total deaths",
  SUM(CASE WHEN mode_flag = 0 OR mode_flag IS NULL THEN 1 ELSE 0 END) AS "Deaths in Beast Mode",
  SUM(CASE WHEN mode_flag = 1 THEN 1 ELSE 0 END) AS "Deaths in Other Modes"
FROM final_deaths
GROUP BY death_date
ORDER BY death_date
