-- Dune query 6011955: LS2-deaths
-- https://dune.com/queries/6011955
-- version 53 as of 2026-07-26

-- 2026-07-26: rewritten to span the Loot Survivor V1 -> V2 cutover (V1 dead after
-- 2026-05-04, V2 live from 2026-05-05). V2 emits a completely different `GameEvent`
-- from the game contract, in TWO layouts (the contract was upgraded mid-flight):
--   V2a to ~2026-06-11: 1 key,  adventurer_id = data[1], variant = data[2]  (+1 shift)
--   V2b from ~2026-06-11: 2 keys, adventurer_id = keys[2], variant = data[1]
-- Handling only V2b silently dropped ~4 weeks of May gameplay (7.16M events).
-- V2 has no settings_id, so the dungeon is recovered by transaction correlation.
-- Full decode: V2_EVENT_DECODE_REFERENCE.md

WITH
v1_settings AS (
  SELECT DISTINCT
    bytearray_to_uint256(data[2]) AS game_id,
    bytearray_to_uint256(data[6]) AS settings_id,
    bytearray_to_uint256(data[13]) AS mode_flag
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND cardinality(data) = 14
    AND block_time >= TIMESTAMP '2024-09-01'
),

v1_death_events AS (
  SELECT
    bytearray_to_uint256(data[2]) AS game_id,
    block_time,
    bytearray_to_uint256(data[7]) AS xp,
    bytearray_to_uint256(data[9]) AS beast_health,
    ROW_NUMBER() OVER (
      PARTITION BY bytearray_to_uint256(data[2])
      ORDER BY bytearray_to_uint256(data[4]) DESC
    ) AS rn
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND cardinality(data) = 35
    AND bytearray_to_uint256(data[5]) = 0   -- health = 0 (death)
    AND block_time >= TIMESTAMP '2024-09-01'
),

v1_final AS (
  SELECT FLOOR(SQRT(CAST(d.xp AS DOUBLE))) AS level
  FROM v1_death_events d
  LEFT JOIN v1_settings s ON s.game_id = d.game_id
  WHERE d.rn = 1 AND COALESCE(s.settings_id, 1) = 1     -- Beast Mode only
),

v2_ev_raw AS (
  SELECT
    CASE WHEN cardinality(keys) >= 2 THEN element_at(keys, 2) ELSE data[1] END AS adventurer_id,
    CASE WHEN cardinality(keys) >= 2 THEN 0 ELSE 1 END AS off,
    data, block_number, event_index, block_time, transaction_hash, block_date
  FROM starknet.events
  WHERE from_address = 0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405
    AND keys[1] = 0x03e037e958ba3b5c1cc99ac16aaf9896423eebd03183c41fbb26548a12336e5f
    AND cardinality(data) >= 2
    AND block_time >= TIMESTAMP '2026-05-05'
),

v2_ev AS (
  SELECT
    adventurer_id, block_number, event_index, block_time, transaction_hash, block_date,
    bytearray_to_uint256(element_at(data, 1 + off)) AS variant,
    bytearray_to_uint256(element_at(data, 2 + off)) AS health,
    bytearray_to_uint256(element_at(data, 3 + off)) AS xp,
    bytearray_to_uint256(element_at(data, 5 + off)) AS beast_health
  FROM v2_ev_raw
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
  SELECT
    adventurer_id, block_time, xp, beast_health,
    ROW_NUMBER() OVER (
      PARTITION BY adventurer_id ORDER BY block_number DESC, event_index DESC
    ) AS rn
  FROM v2_ev
  WHERE variant = 0    -- adventurer state
    AND health = 0     -- death
),

v2_final AS (
  SELECT FLOOR(SQRT(CAST(d.xp AS DOUBLE))) AS level
  FROM v2_death_events d
  JOIN v2_game_dungeon g ON g.adventurer_id = d.adventurer_id
  WHERE d.rn = 1 AND g.dungeon = 'Beast Mode'
),

all_deaths AS (
  SELECT level FROM v1_final UNION ALL SELECT level FROM v2_final
)

SELECT level AS "Level", COUNT(*) AS "Deaths"
FROM all_deaths
WHERE level BETWEEN 1 AND 60
GROUP BY level
ORDER BY level
