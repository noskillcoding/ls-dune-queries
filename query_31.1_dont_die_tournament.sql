-- "Don't Die" Tournament Leaderboard
--
-- Rank: Position on the leaderboard based on XP.
--
-- Player Address: Wallet address of the tournament participant.
--
-- Level: The level reached by the player at death (calculated as floor of sqrt of XP).
--
-- XP: Total experience points accumulated before death.
--
-- This leaderboard shows all participants in the "Don't Die" tournament (end time: 1769763600),
-- ranked by XP in descending order. The tournament runs Jan 22 - Jan 30, 2026.
-- Higher XP/Level indicates better performance in the tournament.

WITH tournament_games AS (
  -- Find all games in this tournament (by end_time)
  SELECT DISTINCT
    bytearray_to_uint256(data[2]) AS game_id
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND CARDINALITY(data) = 14
    AND bytearray_to_uint256(data[13]) = 1  -- Tournament mode
    AND bytearray_to_uint256(data[8]) = 1769763600  -- Tournament end time
),

game_owners AS (
  -- Get owner (player) for each game
  SELECT DISTINCT
    bytearray_to_uint256(keys[4]) AS game_id,
    keys[3] AS player_address
  FROM starknet.events
  WHERE from_address = 0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd  -- Game NFT
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9  -- Transfer
    AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000  -- FROM zero (mint)
    AND CARDINALITY(keys) >= 4
    AND bytearray_to_uint256(keys[4]) IN (SELECT game_id FROM tournament_games)
),

game_deaths AS (
  -- Get final death for each game
  SELECT
    bytearray_to_uint256(data[2]) AS game_id,
    bytearray_to_uint256(data[7]) AS xp,
    FLOOR(SQRT(CAST(bytearray_to_uint256(data[7]) AS DOUBLE))) AS level,
    ROW_NUMBER() OVER (PARTITION BY bytearray_to_uint256(data[2]) ORDER BY bytearray_to_uint256(data[4]) DESC) AS rn
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND CARDINALITY(data) = 35
    AND bytearray_to_uint256(data[5]) = 0  -- death event
    AND bytearray_to_uint256(data[2]) IN (SELECT game_id FROM tournament_games)
)

SELECT
  ROW_NUMBER() OVER (ORDER BY d.xp DESC, d.level DESC) AS "Rank",
  o.player_address AS "Player Address",
  d.level AS "Level",
  d.xp AS "XP"
FROM game_owners o
JOIN game_deaths d ON o.game_id = d.game_id AND d.rn = 1
ORDER BY d.xp DESC, d.level DESC
