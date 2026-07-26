-- Dune query 5999525: LS2-top200 players stats
-- version 28 backed up 2026-07-26

WITH all_game_activity AS (
  SELECT
    a.transaction_hash,
    a.caller_address,
    b.sender_address,
    a.block_time,
    DATE_TRUNC('day', a.block_time) AS date,
    b.actual_fee_amount/1e18 AS fee,
    CASE WHEN b.actual_fee_unit = 'FRI' THEN 'STRK' ELSE 'ETH' END AS fee_token,
    CASE
      WHEN a.contract_address = 0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c
        AND a.entry_point_selector = 0x02214fe6a6e2545aebfe589b84884a2c528416482abec76605b7fdb1c31ce5b2
      THEN 1 ELSE 0
    END AS is_start_game,
    CASE
      WHEN a.contract_address = 0x00a67ef20b61a9846e1c82b411175e6ab167ea9f8632bd6c2091823c3629ec42
        AND a.entry_point_selector = 0x037e4324eee07408cd4367ed1663988a4c2491174a5f1fd448e3c9a243e9cfe6
      THEN 1 ELSE 0
    END AS is_claim_beast
  FROM starknet.calls a
  JOIN starknet.transactions b ON a.transaction_hash = b.transaction_hash
  WHERE
    (a.contract_address = 0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c
     OR (a.contract_address = 0x00a67ef20b61a9846e1c82b411175e6ab167ea9f8632bd6c2091823c3629ec42
         AND a.entry_point_selector = 0x037e4324eee07408cd4367ed1663988a4c2491174a5f1fd448e3c9a243e9cfe6))
    AND b.block_time >= TIMESTAMP '2025-09-15'
),

game_owners AS (
  SELECT DISTINCT
    bytearray_to_uint256(keys[4]) as game_id,
    CAST(keys[3] AS VARBINARY) as player_address
  FROM starknet.events
  WHERE from_address = 0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000
    AND cardinality(keys) >= 4
    AND block_time >= TIMESTAMP '2025-09-15'
),

game_settings AS (
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
    bytearray_to_uint256(data[7]) as xp,
    FLOOR(SQRT(CAST(bytearray_to_uint256(data[7]) AS DOUBLE))) as level,
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
    d.level,
    g.player_address
  FROM all_death_events d
  INNER JOIN game_owners g ON d.game_id = g.game_id
  LEFT JOIN game_settings s ON d.game_id = s.game_id
  WHERE d.rn = 1
    AND (s.mode_flag = 0 OR s.mode_flag IS NULL)
),

player_deaths AS (
  SELECT
    player_address,
    COUNT(*) as total_deaths,
    ROUND(AVG(CAST(level AS DOUBLE)), 2) as avg_level
  FROM final_deaths
  GROUP BY player_address
),

prices AS (
  SELECT
    DATE_TRUNC('day', minute) AS time,
    AVG(price) AS pr,
    CASE WHEN contract_address = 0xca14007eff0db1f8135f4c25b34de49ab0d42766 THEN 'STRK' ELSE 'ETH' END AS tk
  FROM prices.usd
  WHERE blockchain = 'ethereum'
    AND contract_address IN (0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2, 0xca14007eff0db1f8135f4c25b34de49ab0d42766)
  GROUP BY 1, 3
),

player_stats AS (
  SELECT
    a.caller_address,
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
  SELECT
    CAST("Player address" AS VARCHAR) AS player_address,
    MIN("Rank") AS rank
  FROM dune.lowskillcoding.result_ls_2_top_200_beast_hunters
  GROUP BY CAST("Player address" AS VARCHAR)
),

beast_mode_ranks AS (
  SELECT
    CAST("Player address" AS VARCHAR) AS player_address,
    MIN("Rank") AS rank
  FROM dune.lowskillcoding.result_ls_2_top_200_beast_mode
  GROUP BY CAST("Player address" AS VARCHAR)
),

level_hunters AS (
  SELECT
    CAST("Player address" AS VARCHAR) AS player_address,
    "Rank" AS rank
  FROM dune.lowskillcoding.result_ls_2_top_200_level_hunters
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
