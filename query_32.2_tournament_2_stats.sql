-- Tournament 2 Player Stats (Jan 27 - Feb 10, 2026)
--
-- Player Address: Wallet address of the tournament participant.
--
-- Entries: Number of games played in the tournament by this player.
--
-- Best XP: Highest XP achieved across all tournament entries.
--
-- Best Level: Highest level reached across all tournament entries.
--
-- Avg Level: Average level at death across all tournament entries.
--
-- This shows aggregated stats for each player in Tournament 2,
-- sorted by number of entries (most active players first).

WITH tournament_games AS (
  SELECT DISTINCT
    bytearray_to_uint256(data[2]) AS game_id
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND CARDINALITY(data) = 14
    AND bytearray_to_uint256(data[13]) = 1  -- Tournament mode
    AND bytearray_to_uint256(data[8]) = 1770750052  -- Tournament end time
),

game_owners AS (
  SELECT DISTINCT
    bytearray_to_uint256(keys[4]) AS game_id,
    keys[3] AS player_address
  FROM starknet.events
  WHERE from_address = 0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000
    AND CARDINALITY(keys) >= 4
    AND bytearray_to_uint256(keys[4]) IN (SELECT game_id FROM tournament_games)
),

game_deaths AS (
  SELECT
    bytearray_to_uint256(data[2]) AS game_id,
    bytearray_to_uint256(data[7]) AS xp,
    FLOOR(SQRT(CAST(bytearray_to_uint256(data[7]) AS DOUBLE))) AS level,
    ROW_NUMBER() OVER (PARTITION BY bytearray_to_uint256(data[2]) ORDER BY bytearray_to_uint256(data[4]) DESC) AS rn
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND CARDINALITY(data) = 35
    AND bytearray_to_uint256(data[5]) = 0
    AND bytearray_to_uint256(data[2]) IN (SELECT game_id FROM tournament_games)
)

SELECT
  o.player_address AS "Player Address",
  COUNT(*) AS "Entries",
  MAX(d.xp) AS "Best XP",
  MAX(d.level) AS "Best Level",
  ROUND(AVG(CAST(d.level AS DOUBLE)), 1) AS "Avg Level"
FROM game_owners o
JOIN game_deaths d ON o.game_id = d.game_id AND d.rn = 1
GROUP BY o.player_address
ORDER BY COUNT(*) DESC, MAX(d.xp) DESC
