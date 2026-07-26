-- Dune query 6013674: LS2-top50 level hunters (2 weeks)
-- https://dune.com/queries/6013674
-- version 16 as of 2026-07-26

-- 2026-07-26: migrated to Loot Survivor V2. This board is a rolling 14-day window,
-- so the V1 half (dead after 2026-05-04) is permanently out of range and is omitted.
-- V2 mapping: denshokan V2 token_id is a u256 split across keys[4] (low) / keys[5]
-- (high); recombined as bytes it equals the GameEvent adventurer_id (99.3% match).
-- Game state is GameEvent variant 0 in two layouts -- see V2_EVENT_DECODE_REFERENCE.md.

WITH
v2_ev_raw AS (
  SELECT
    CASE WHEN cardinality(keys) >= 2 THEN element_at(keys, 2) ELSE data[1] END AS adventurer_id,
    CASE WHEN cardinality(keys) >= 2 THEN 0 ELSE 1 END AS off,
    data, block_number, event_index, block_time, transaction_hash, block_date
  FROM starknet.events
  WHERE from_address = 0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405
    AND keys[1] = 0x03e037e958ba3b5c1cc99ac16aaf9896423eebd03183c41fbb26548a12336e5f
    AND cardinality(data) >= 2
    AND block_time >= NOW() - INTERVAL '14' DAY
),

v2_ev AS (
  SELECT
    adventurer_id, block_number, event_index, block_time, transaction_hash, block_date,
    bytearray_to_uint256(element_at(data, 1 + off)) AS variant,
    bytearray_to_uint256(element_at(data, 2 + off)) AS health,
    bytearray_to_uint256(element_at(data, 3 + off)) AS xp,
    bytearray_to_uint256(element_at(data, 4 + off)) AS gold,
    bytearray_to_uint256(element_at(data, 5 + off)) AS beast_health,
    -- variant 2 (`beast`) reuses the same slots: 2=beast_id, 3=beast "level" (really the
    -- beast's health, matching V1's data[9]), 4=true beast level
    bytearray_to_uint256(element_at(data, 2 + off)) AS beast_id,
    bytearray_to_uint256(element_at(data, 3 + off)) AS beast_stat
  FROM v2_ev_raw
),

v2_game_owners AS (
  SELECT DISTINCT
    bytearray_concat(
      bytearray_substring(keys[5], 17, 16),
      bytearray_substring(keys[4], 17, 16)
    ) AS adventurer_id,
    CAST(keys[3] AS VARBINARY) AS player_address
  FROM starknet.events
  WHERE from_address = 0x00263cc540dac11334470a64759e03952ee2f84a290e99ba8cbc391245cd0bf9
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000
    AND cardinality(keys) >= 5
    AND block_time >= NOW() - INTERVAL '14' DAY
),

v2_dungeon_tx AS (
  SELECT DISTINCT
    sg.transaction_hash,
    sg.block_date,
    CASE dg.contract_address
           WHEN 0x0539d24dfdaa2866d975fa93db501b971c08786f2c88e719800be39903e43bbc THEN 'Beast Mode'
           WHEN 0x046db77f066f1bec5ae53d2cf3686a262f308eb904e6b426251bcdf3a6bf34f0 THEN 'Greed'
           WHEN 0x04427c2cdd82bf2283deb39aa939e1ad61051ab932e0de714032fbe22ed0a419 THEN 'Lil Duckies'
           WHEN 0x0616042ee02abc8c73d7eb975d33ade3b53f8296005363d1ee56a1ccefd4f49f THEN 'Yield'
           WHEN 0x065406785f89adb4c9f9b22d08358951ca78b2f952d7e5d0eab9e643872e9c8a THEN 'Dungeon 0x0654'
           WHEN 0x012ac35cf5112dd1bacd2f1e7342eb5951566262ab52c3c7dddd2b9a77840741 THEN 'Dungeon 0x012a'
    END AS dungeon
  FROM starknet.calls sg
  JOIN starknet.calls dg
    ON dg.transaction_hash = sg.transaction_hash
   AND dg.block_date = sg.block_date
  WHERE sg.contract_address = 0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405
    AND sg.entry_point_selector = 0x02214fe6a6e2545aebfe589b84884a2c528416482abec76605b7fdb1c31ce5b2
    AND dg.contract_address IN (
        0x0539d24dfdaa2866d975fa93db501b971c08786f2c88e719800be39903e43bbc,
        0x046db77f066f1bec5ae53d2cf3686a262f308eb904e6b426251bcdf3a6bf34f0,
        0x04427c2cdd82bf2283deb39aa939e1ad61051ab932e0de714032fbe22ed0a419,
        0x0616042ee02abc8c73d7eb975d33ade3b53f8296005363d1ee56a1ccefd4f49f,
        0x065406785f89adb4c9f9b22d08358951ca78b2f952d7e5d0eab9e643872e9c8a,
        0x012ac35cf5112dd1bacd2f1e7342eb5951566262ab52c3c7dddd2b9a77840741
      )
),

v2_game_dungeon AS (
  -- one dungeon per adventurer; min() breaks the tie if a tx touched more than one
  SELECT e.adventurer_id, MIN(t.dungeon) AS dungeon
  FROM v2_ev e
  JOIN v2_dungeon_tx t
    ON t.transaction_hash = e.transaction_hash
   AND t.block_date = e.block_date
  GROUP BY 1
),

v2_death_events AS (
  SELECT adventurer_id, xp, beast_health,
         FLOOR(SQRT(CAST(xp AS DOUBLE))) AS level,
         ROW_NUMBER() OVER (PARTITION BY adventurer_id
                            ORDER BY block_number DESC, event_index DESC) AS rn
  FROM v2_ev WHERE variant = 0 AND health = 0
),

final_deaths AS (
  SELECT o.player_address, d.level
  FROM v2_death_events d
  JOIN v2_game_owners o ON o.adventurer_id = d.adventurer_id
  JOIN v2_game_dungeon g ON g.adventurer_id = d.adventurer_id
  WHERE d.rn = 1 AND g.dungeon = 'Beast Mode'
),

player_stats AS (
  SELECT f.player_address,
         ROUND(AVG(CAST(f.level AS DOUBLE)), 2) AS avg_level,
         COUNT(*) AS total_deaths
  FROM final_deaths f
  GROUP BY f.player_address
  HAVING COUNT(*) >= 10
),

best_avg AS (SELECT MAX(avg_level) AS max_avg FROM player_stats),

ranked_hunters AS (
  SELECT p.player_address,
         ROUND((p.avg_level / b.max_avg) * 100, 2) AS score,
         p.total_deaths, p.avg_level,
         ROW_NUMBER() OVER (ORDER BY (p.avg_level / b.max_avg) DESC) AS rank
  FROM player_stats p CROSS JOIN best_avg b
)

SELECT rank AS "Rank", player_address AS "Player address", score AS "Score",
       total_deaths AS "Total deaths", avg_level AS "Avg level"
FROM ranked_hunters WHERE rank <= 50 ORDER BY rank
