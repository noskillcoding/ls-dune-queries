-- Top Beast Hunters (Last 2 Weeks)
--
-- Rank: Position in the leaderboard based on tier-weighted hunting efficiency score.
--
-- Player Address: Unique wallet address of each player.
--
-- Score: Beast hunting efficiency score from 0-100, where 100 represents the most efficient hunter.
-- Calculated using tier-weighted efficiency: first, each claimed beast contributes points based on
-- (tier_multiplier × beast_level), where tier multipliers are T1=5x, T2=4x, T3=3x, T4=2x, T5=1x
-- (matching the game's gold reward system). Then efficiency = total_points / total_deaths.
-- Finally, efficiency values are normalized to 0-100 scale using min-max normalization.
-- This rewards players who claim high-tier, high-level beasts with fewer deaths.
--
-- Raw Score: Sum of (tier_multiplier × beast_level) for all claimed beasts. Shows absolute
-- achievement value based on the game's tier/level economy. Higher tier and higher level beasts
-- contribute more points.
--
-- Total Deaths: Total number of deaths in Beast Mode.
--
-- Beasts Claimed: Total number of beasts successfully claimed by the player.
--
-- Time window: Last 2 weeks only. Minimum 10 deaths required.

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
    g.player_address
  FROM all_death_events d
  INNER JOIN game_owners g ON d.game_id = g.game_id
  LEFT JOIN game_settings s ON d.game_id = s.game_id
  WHERE d.rn = 1
    AND (s.mode_flag = 0 OR s.mode_flag IS NULL)
),

nft_claims AS (
  SELECT
    transaction_hash as claim_tx,
    block_time as claim_time,
    keys[3] as recipient_wallet
  FROM starknet.events
  WHERE from_address = 0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4
    AND CARDINALITY(keys) >= 5
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000  -- from = 0x0 (mints only)
    AND block_time >= NOW() - INTERVAL '14' DAY
),

beast_encounters AS (
  SELECT
    block_time as encounter_time,
    bytearray_to_uint256(data[9]) as beast_level,
    CASE
      -- T1: IDs 1-5, 26-30, 51-55 (15 beasts - highest value, 5x multiplier)
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 1 AND 5)
        OR (bytearray_to_uint256(data[7]) BETWEEN 26 AND 30)
        OR (bytearray_to_uint256(data[7]) BETWEEN 51 AND 55) THEN 5
      -- T2: IDs 6-10, 31-35, 56-60 (15 beasts, 4x multiplier)
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 6 AND 10)
        OR (bytearray_to_uint256(data[7]) BETWEEN 31 AND 35)
        OR (bytearray_to_uint256(data[7]) BETWEEN 56 AND 60) THEN 4
      -- T3: IDs 11-15, 36-40, 61-65 (15 beasts, 3x multiplier)
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 11 AND 15)
        OR (bytearray_to_uint256(data[7]) BETWEEN 36 AND 40)
        OR (bytearray_to_uint256(data[7]) BETWEEN 61 AND 65) THEN 3
      -- T4: IDs 16-20, 41-45, 66-70 (15 beasts, 2x multiplier)
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 16 AND 20)
        OR (bytearray_to_uint256(data[7]) BETWEEN 41 AND 45)
        OR (bytearray_to_uint256(data[7]) BETWEEN 66 AND 70) THEN 2
      -- T5: IDs 21-25, 46-50, 71-75 (15 beasts, 1x multiplier)
      ELSE 1
    END as tier_multiplier
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND event_index = 1
    AND CARDINALITY(data) >= 13
    AND bytearray_to_uint256(data[1]) = 3
    AND bytearray_to_uint256(data[7]) BETWEEN 1 AND 75
    AND block_time >= NOW() - INTERVAL '14' DAY
),

matched_beast_claims AS (
  SELECT
    c.recipient_wallet,
    b.tier_multiplier,
    b.beast_level,
    ROW_NUMBER() OVER (PARTITION BY c.claim_tx ORDER BY b.encounter_time DESC) as rn
  FROM nft_claims c
  LEFT JOIN beast_encounters b
    ON b.encounter_time < c.claim_time
),

beast_claims AS (
  SELECT
    recipient_wallet as player_address,
    COUNT(*) as beasts_claimed,
    SUM(tier_multiplier * beast_level) as raw_score
  FROM matched_beast_claims
  WHERE rn = 1
    AND tier_multiplier IS NOT NULL
    AND beast_level IS NOT NULL
  GROUP BY recipient_wallet
),

player_stats AS (
  SELECT
    f.player_address,
    COUNT(*) as total_deaths,
    COALESCE(b.beasts_claimed, 0) AS beasts_claimed,
    COALESCE(b.raw_score, 0) AS raw_score,
    CAST(COALESCE(b.raw_score, 0) AS DOUBLE) / CAST(COUNT(*) AS DOUBLE) AS efficiency
  FROM final_deaths f
  LEFT JOIN beast_claims b ON f.player_address = b.player_address
  GROUP BY f.player_address, b.beasts_claimed, b.raw_score
  HAVING COUNT(*) >= 10 AND COALESCE(b.beasts_claimed, 0) > 0
),

efficiency_range AS (
  SELECT
    MIN(efficiency) AS min_efficiency,
    MAX(efficiency) AS max_efficiency
  FROM player_stats
),

ranked_collectors AS (
  SELECT
    p.player_address,
    CASE
      WHEN r.max_efficiency = r.min_efficiency THEN 100.0
      ELSE ROUND(((p.efficiency - r.min_efficiency) / (r.max_efficiency - r.min_efficiency)) * 100, 2)
    END AS score,
    p.raw_score,
    p.total_deaths,
    p.beasts_claimed,
    ROW_NUMBER() OVER (ORDER BY p.efficiency DESC) AS rank
  FROM player_stats p
  CROSS JOIN efficiency_range r
)

SELECT
  rank AS "Rank",
  player_address AS "Player address",
  score AS "Score",
  raw_score AS "Raw Score",
  total_deaths AS "Total deaths",
  beasts_claimed AS "Beasts claimed"
FROM ranked_collectors
ORDER BY rank
LIMIT 50
