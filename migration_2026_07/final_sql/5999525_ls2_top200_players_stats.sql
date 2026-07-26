-- Dune query 5999525: LS2-top200 players stats
-- https://dune.com/queries/5999525
-- version 29 as of 2026-07-26

-- Top 200 Active Players -- migrated across the Loot Survivor V1 -> V2 cutover, 2026-07-26.
--
-- Changes:
--  * in-game activity now spans both game contracts and both Beast Mode contracts
--    (the claim selector 0x037e4324.. is unchanged and live on the V2 dungeon).
--  * Beast Mode deaths are unioned from V1 (pgWorld Dojo events, keyed by game_id from
--    denshokan V1) and V2 (GameEvent variant 0, keyed by adventurer_id from denshokan V2,
--    whose token_id is a u256 split across keys[4] low / keys[5] high).
--  * the three rank inputs used to read materialized views under dune.lowskillcoding,
--    which was dropped when the account was banned. Dune has no API to re-enable
--    materialization, so they now read the producing queries directly as views.
-- See V2_EVENT_DECODE_REFERENCE.md.

WITH all_game_activity AS (
  SELECT
    a.transaction_hash, a.caller_address, b.sender_address, a.block_time,
    DATE_TRUNC('day', a.block_time) AS date,
    b.actual_fee_amount/1e18 AS fee,
    CASE WHEN b.actual_fee_unit = 'FRI' THEN 'STRK' ELSE 'ETH' END AS fee_token,
    CASE WHEN a.contract_address IN (0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c, 0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405)
          AND a.entry_point_selector = 0x02214fe6a6e2545aebfe589b84884a2c528416482abec76605b7fdb1c31ce5b2
         THEN 1 ELSE 0 END AS is_start_game,
    CASE WHEN a.contract_address IN (0x00a67ef20b61a9846e1c82b411175e6ab167ea9f8632bd6c2091823c3629ec42, 0x0539d24dfdaa2866d975fa93db501b971c08786f2c88e719800be39903e43bbc)
          AND a.entry_point_selector = 0x037e4324eee07408cd4367ed1663988a4c2491174a5f1fd448e3c9a243e9cfe6
         THEN 1 ELSE 0 END AS is_claim_beast
  FROM starknet.calls a
  JOIN starknet.transactions b ON a.transaction_hash = b.transaction_hash
  WHERE (
      a.contract_address IN (0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c, 0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405)
      OR (a.contract_address IN (0x00a67ef20b61a9846e1c82b411175e6ab167ea9f8632bd6c2091823c3629ec42, 0x0539d24dfdaa2866d975fa93db501b971c08786f2c88e719800be39903e43bbc) AND a.entry_point_selector = 0x037e4324eee07408cd4367ed1663988a4c2491174a5f1fd448e3c9a243e9cfe6)
    )
    AND b.block_time >= TIMESTAMP '2025-09-15'
),

-- ===================== V1 deaths =====================
v1_game_owners AS (
  SELECT DISTINCT
    bytearray_to_uint256(keys[4]) AS game_id,
    CAST(keys[3] AS VARBINARY) AS player_address
  FROM starknet.events
  WHERE from_address = 0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000
    AND cardinality(keys) >= 4
    AND block_time >= TIMESTAMP '2025-09-15'
),

v1_settings AS (
  SELECT DISTINCT bytearray_to_uint256(data[2]) AS game_id,
         bytearray_to_uint256(data[13]) AS mode_flag
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND cardinality(data) = 14 AND block_time >= TIMESTAMP '2025-09-15'
),

v1_death_events AS (
  SELECT bytearray_to_uint256(data[2]) AS game_id,
         FLOOR(SQRT(CAST(bytearray_to_uint256(data[7]) AS DOUBLE))) AS level,
         ROW_NUMBER() OVER (PARTITION BY bytearray_to_uint256(data[2])
                            ORDER BY bytearray_to_uint256(data[4]) DESC) AS rn
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a AND keys[1] = 0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd
    AND cardinality(data) = 35 AND bytearray_to_uint256(data[5]) = 0
    AND block_time >= TIMESTAMP '2025-09-15'
),

v1_final AS (
  SELECT g.player_address, d.level
  FROM v1_death_events d
  INNER JOIN v1_game_owners g ON g.game_id = d.game_id
  LEFT JOIN v1_settings s ON s.game_id = d.game_id
  WHERE d.rn = 1 AND (s.mode_flag = 0 OR s.mode_flag IS NULL)
),

-- ===================== V2 deaths =====================
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
    AND block_time >= TIMESTAMP '2026-05-05'
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
  SELECT adventurer_id, FLOOR(SQRT(CAST(xp AS DOUBLE))) AS level,
         ROW_NUMBER() OVER (PARTITION BY adventurer_id
                            ORDER BY block_number DESC, event_index DESC) AS rn
  FROM v2_ev WHERE variant = 0 AND health = 0
),

v2_final AS (
  SELECT o.player_address, d.level
  FROM v2_death_events d
  JOIN v2_game_owners o ON o.adventurer_id = d.adventurer_id
  JOIN v2_game_dungeon g ON g.adventurer_id = d.adventurer_id
  WHERE d.rn = 1 AND g.dungeon = 'Beast Mode'
),

final_deaths AS (
  SELECT * FROM v1_final UNION ALL SELECT * FROM v2_final
),

player_deaths AS (
  SELECT player_address, COUNT(*) AS total_deaths,
         ROUND(AVG(CAST(level AS DOUBLE)), 2) AS avg_level
  FROM final_deaths GROUP BY player_address
),

prices AS (
  SELECT DATE_TRUNC('day', minute) AS time, AVG(price) AS pr,
         CASE WHEN contract_address = 0xca14007eff0db1f8135f4c25b34de49ab0d42766
              THEN 'STRK' ELSE 'ETH' END AS tk
  FROM prices.usd
  WHERE blockchain = 'ethereum'
    AND contract_address IN (0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2,
                             0xca14007eff0db1f8135f4c25b34de49ab0d42766)
  GROUP BY 1, 3
),

player_stats AS (
  SELECT a.caller_address,
         COUNT(DISTINCT a.transaction_hash) AS total_txs,
         SUM(a.is_start_game) AS total_games,
         COALESCE(d.total_deaths, 0) AS total_deaths,
         COALESCE(d.avg_level, 0) AS avg_level,
         SUM(a.is_claim_beast) AS beasts_claimed,
         ROUND(SUM(a.fee * COALESCE(p.pr, 0))) AS total_fees_usd,
         COUNT(DISTINCT a.date) AS active_days
  FROM all_game_activity a
  LEFT JOIN prices p ON a.date = p.time AND a.fee_token = p.tk
  LEFT JOIN player_deaths d ON a.caller_address = d.player_address
  GROUP BY a.caller_address, d.total_deaths, d.avg_level
),

beast_hunters AS (
  SELECT CAST("Player address" AS VARCHAR) AS player_address, MIN("Rank") AS rank
  FROM query_6004055 GROUP BY CAST("Player address" AS VARCHAR)
),

beast_mode_ranks AS (
  SELECT CAST("Player address" AS VARCHAR) AS player_address, MIN("Rank") AS rank
  FROM query_6014300 GROUP BY CAST("Player address" AS VARCHAR)
),

level_hunters AS (
  SELECT CAST("Player address" AS VARCHAR) AS player_address, "Rank" AS rank
  FROM query_6013674
)

SELECT
  p.caller_address AS "Player address",
  p.total_games AS "Games",
  p.total_deaths AS "Deaths (Bmode)",
  COALESCE(CAST(bmr.rank AS VARCHAR), '-') AS "Rank (Bmode)",
  p.beasts_claimed AS "Beasts",
  COALESCE(CAST(bh.rank AS VARCHAR), '-') AS "BH rank",
  CASE WHEN p.avg_level > 0 THEN CAST(p.avg_level AS VARCHAR) ELSE '-' END AS "Avg lvl",
  COALESCE(CAST(lh.rank AS VARCHAR), '-') AS "LH rank",
  p.total_txs AS "Total in-game txs",
  p.total_fees_usd AS "Total paid fees (USD)",
  p.active_days AS "# of active days"
FROM player_stats p
LEFT JOIN beast_hunters bh ON CAST(p.caller_address AS VARCHAR) = bh.player_address
LEFT JOIN beast_mode_ranks bmr ON CAST(p.caller_address AS VARCHAR) = bmr.player_address
LEFT JOIN level_hunters lh ON CAST(p.caller_address AS VARCHAR) = lh.player_address
WHERE p.total_games > 0
ORDER BY p.total_games DESC
LIMIT 200
