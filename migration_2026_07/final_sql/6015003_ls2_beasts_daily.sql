-- Dune query 6015003: LS2-beasts daily
-- https://dune.com/queries/6015003
-- version 13 as of 2026-07-26

-- 2026-07-26: spans the Loot Survivor V1 -> V2 cutover.
--   V1 beast encounters came from pgWorld Dojo events (data[1]=3, beast_id=data[7]);
--       that stream is dead after 2026-05-04.
--   V2 encounters come from the game contract's GameEvent, variant 2 (`beast`), where
--       beast_id = data[2] (+1 in the V2a layout). Validated: ids span exactly 1..75.
--   Both V2 event layouts are handled -- see V2_EVENT_DECODE_REFERENCE.md.
-- The beasts NFT contract itself is unchanged and still minting.
--
-- Also replaced the original "most recent encounter before this claim" join (a
-- claims x encounters nested loop) with an equivalent ordered-timeline window. Same
-- semantics -- encounters sort before claims at equal timestamps, so the match is still
-- strictly-before -- but it is O(n log n) instead of O(n*m).

WITH nft_claims AS (
  SELECT
    transaction_hash AS claim_tx,
    block_time AS claim_time,
    keys[3] AS recipient_wallet
  FROM starknet.events
  WHERE from_address = 0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4
    AND CARDINALITY(keys) >= 5
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000          -- from = 0x0 (mints only)
    AND block_time >= CAST('2025-09-15' AS TIMESTAMP)
),

v1_encounters AS (
  SELECT block_time AS encounter_time,
         CASE
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 1 AND 5)   OR (bytearray_to_uint256(data[7]) BETWEEN 26 AND 30) OR (bytearray_to_uint256(data[7]) BETWEEN 51 AND 55) THEN 'T1'
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 6 AND 10)  OR (bytearray_to_uint256(data[7]) BETWEEN 31 AND 35) OR (bytearray_to_uint256(data[7]) BETWEEN 56 AND 60) THEN 'T2'
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 11 AND 15) OR (bytearray_to_uint256(data[7]) BETWEEN 36 AND 40) OR (bytearray_to_uint256(data[7]) BETWEEN 61 AND 65) THEN 'T3'
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 16 AND 20) OR (bytearray_to_uint256(data[7]) BETWEEN 41 AND 45) OR (bytearray_to_uint256(data[7]) BETWEEN 66 AND 70) THEN 'T4'
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 21 AND 25) OR (bytearray_to_uint256(data[7]) BETWEEN 46 AND 50) OR (bytearray_to_uint256(data[7]) BETWEEN 71 AND 75) THEN 'T5'
      ELSE 'Unknown'
    END AS beast_tier
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND event_index = 1
    AND CARDINALITY(data) >= 13
    AND bytearray_to_uint256(data[1]) = 3
    AND bytearray_to_uint256(data[7]) BETWEEN 1 AND 75
    AND block_time >= CAST('2025-09-15' AS TIMESTAMP)
),

v2_ev_raw AS (
  SELECT CASE WHEN cardinality(keys) >= 2 THEN 0 ELSE 1 END AS off, data, block_time
  FROM starknet.events
  WHERE from_address = 0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405
    AND keys[1] = 0x03e037e958ba3b5c1cc99ac16aaf9896423eebd03183c41fbb26548a12336e5f
    AND cardinality(data) >= 2
    AND block_time >= TIMESTAMP '2026-05-05'
),

v2_encounters AS (
  SELECT encounter_time, CASE
      WHEN (beast_id BETWEEN 1 AND 5)   OR (beast_id BETWEEN 26 AND 30) OR (beast_id BETWEEN 51 AND 55) THEN 'T1'
      WHEN (beast_id BETWEEN 6 AND 10)  OR (beast_id BETWEEN 31 AND 35) OR (beast_id BETWEEN 56 AND 60) THEN 'T2'
      WHEN (beast_id BETWEEN 11 AND 15) OR (beast_id BETWEEN 36 AND 40) OR (beast_id BETWEEN 61 AND 65) THEN 'T3'
      WHEN (beast_id BETWEEN 16 AND 20) OR (beast_id BETWEEN 41 AND 45) OR (beast_id BETWEEN 66 AND 70) THEN 'T4'
      WHEN (beast_id BETWEEN 21 AND 25) OR (beast_id BETWEEN 46 AND 50) OR (beast_id BETWEEN 71 AND 75) THEN 'T5'
      ELSE 'Unknown'
    END AS beast_tier
  FROM (
    SELECT block_time AS encounter_time,
           bytearray_to_uint256(element_at(data, 2 + off)) AS beast_id
    FROM v2_ev_raw
    WHERE bytearray_to_uint256(element_at(data, 1 + off)) = 2   -- variant 2 = beast
  ) z
  WHERE beast_id BETWEEN 1 AND 75
),

beast_encounters AS (
  SELECT * FROM v1_encounters
  UNION ALL
  SELECT * FROM v2_encounters
),

timeline AS (
  SELECT encounter_time AS ts, 0 AS is_claim,
         CAST(NULL AS varbinary) AS recipient_wallet, beast_tier
  FROM beast_encounters
  UNION ALL
  SELECT claim_time, 1, recipient_wallet, CAST(NULL AS varchar)
  FROM nft_claims
),

attached AS (
  SELECT
    ts, is_claim, recipient_wallet,
    LAST_VALUE(CASE WHEN is_claim = 0 THEN beast_tier END) IGNORE NULLS
      OVER (ORDER BY ts, is_claim ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS beast_tier
  FROM timeline
),

matched_claims AS (
  SELECT DATE_TRUNC('day', ts) AS claim_date, beast_tier
  FROM attached
  WHERE is_claim = 1 AND beast_tier IS NOT NULL AND beast_tier <> 'Unknown'
)

SELECT
  claim_date AS "Date",
  COUNT(CASE WHEN beast_tier = 'T1' THEN 1 END) AS "T1 Beasts Claimed",
  COUNT(CASE WHEN beast_tier = 'T2' THEN 1 END) AS "T2 Beasts Claimed",
  COUNT(CASE WHEN beast_tier = 'T3' THEN 1 END) AS "T3 Beasts Claimed",
  COUNT(CASE WHEN beast_tier = 'T4' THEN 1 END) AS "T4 Beasts Claimed",
  COUNT(CASE WHEN beast_tier = 'T5' THEN 1 END) AS "T5 Beasts Claimed"
FROM matched_claims
GROUP BY claim_date
ORDER BY claim_date DESC
