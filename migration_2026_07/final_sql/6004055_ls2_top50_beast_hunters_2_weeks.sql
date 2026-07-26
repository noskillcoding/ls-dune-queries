-- Dune query 6004055: LS2-top50 beast hunters (2 weeks)
-- https://dune.com/queries/6004055
-- version 23 as of 2026-07-26

-- 2026-07-26: migrated to Loot Survivor V2. This board is a rolling 14-day window,
-- so the V1 half (dead after 2026-05-04) is permanently out of range and is omitted.
-- V2 mapping: denshokan V2 token_id is a u256 split across keys[4] (low) / keys[5]
-- (high); recombined as bytes it equals the GameEvent adventurer_id (99.3% match).
-- Game state is GameEvent variant 0 in two layouts -- see V2_EVENT_DECODE_REFERENCE.md.
--
-- Scoring note: V1 called the encounter field `beast_level` but it is really the beast's
-- HEALTH (V1 data[9] ranged 11..1023, avg 259 -- matching V2's data[3], not V2's true
-- level field which ranges 1..172). The V2 half uses the health-equivalent slot so scores
-- stay comparable with the V1 era rather than silently changing scale.

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

nft_claims AS (
  SELECT transaction_hash AS claim_tx, block_time AS claim_time, keys[3] AS recipient_wallet
  FROM starknet.events
  WHERE from_address = 0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4 AND CARDINALITY(keys) >= 5
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9 AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000
    AND block_time >= NOW() - INTERVAL '14' DAY
),

beast_encounters AS (
  SELECT block_time AS encounter_time, CASE
      WHEN (beast_id BETWEEN 1 AND 5)   OR (beast_id BETWEEN 26 AND 30) OR (beast_id BETWEEN 51 AND 55) THEN 5
      WHEN (beast_id BETWEEN 6 AND 10)  OR (beast_id BETWEEN 31 AND 35) OR (beast_id BETWEEN 56 AND 60) THEN 4
      WHEN (beast_id BETWEEN 11 AND 15) OR (beast_id BETWEEN 36 AND 40) OR (beast_id BETWEEN 61 AND 65) THEN 3
      WHEN (beast_id BETWEEN 16 AND 20) OR (beast_id BETWEEN 41 AND 45) OR (beast_id BETWEEN 66 AND 70) THEN 2
      ELSE 1
    END AS tier_multiplier, beast_stat
  FROM v2_ev
  WHERE variant = 2 AND beast_id BETWEEN 1 AND 75
),

timeline AS (
  SELECT encounter_time AS ts, 0 AS is_claim, CAST(NULL AS varbinary) AS recipient_wallet,
         tier_multiplier, beast_stat
  FROM beast_encounters
  UNION ALL
  SELECT claim_time, 1, recipient_wallet, CAST(NULL AS bigint), CAST(NULL AS uint256)
  FROM nft_claims
),

attached AS (
  SELECT ts, is_claim, recipient_wallet,
    LAST_VALUE(CASE WHEN is_claim = 0 THEN tier_multiplier END) IGNORE NULLS
      OVER (ORDER BY ts, is_claim ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS tier_multiplier,
    LAST_VALUE(CASE WHEN is_claim = 0 THEN beast_stat END) IGNORE NULLS
      OVER (ORDER BY ts, is_claim ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS beast_stat
  FROM timeline
),

beast_claims AS (
  SELECT recipient_wallet AS player_address,
         COUNT(*) AS beasts_claimed,
         SUM(tier_multiplier * beast_stat) AS raw_score
  FROM attached
  WHERE is_claim = 1 AND tier_multiplier IS NOT NULL AND beast_stat IS NOT NULL
  GROUP BY recipient_wallet
),

player_stats AS (
  SELECT f.player_address,
         COUNT(*) AS total_deaths,
         COALESCE(b.beasts_claimed, 0) AS beasts_claimed,
         COALESCE(b.raw_score, 0) AS raw_score,
         CAST(COALESCE(b.raw_score, 0) AS DOUBLE) / CAST(COUNT(*) AS DOUBLE) AS efficiency
  FROM final_deaths f
  LEFT JOIN beast_claims b ON f.player_address = b.player_address
  GROUP BY f.player_address, b.beasts_claimed, b.raw_score
  HAVING COUNT(*) >= 10 AND COALESCE(b.beasts_claimed, 0) > 0
),

efficiency_range AS (
  SELECT MIN(efficiency) AS min_efficiency, MAX(efficiency) AS max_efficiency FROM player_stats
),

ranked_collectors AS (
  SELECT p.player_address,
    CASE WHEN r.max_efficiency = r.min_efficiency THEN 100.0
         ELSE ROUND(((p.efficiency - r.min_efficiency) / (r.max_efficiency - r.min_efficiency)) * 100, 2)
    END AS score,
    p.raw_score, p.total_deaths, p.beasts_claimed,
    ROW_NUMBER() OVER (ORDER BY p.efficiency DESC) AS rank
  FROM player_stats p CROSS JOIN efficiency_range r
)

SELECT rank AS "Rank", player_address AS "Player address", score AS "Score",
       raw_score AS "Raw Score", total_deaths AS "Total deaths", beasts_claimed AS "Beasts claimed"
FROM ranked_collectors ORDER BY rank LIMIT 50
