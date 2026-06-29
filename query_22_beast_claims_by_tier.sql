-- Beast Claims by Tier Distribution
--
-- Total Beasts Claimed: Total number of beast NFTs claimed across all players, grouped by tier
-- (T1-T5). Each tier contains exactly 15 beasts (20% of total), balanced across Magic, Hunter,
-- and Brute types. T1 beasts provide the highest rewards (5x gold), T5 provide lowest (1x gold).
--
-- Unique Collectors: Number of distinct wallet addresses that have claimed at least one beast
-- NFT from each tier. This indicates the breadth of player participation in collecting different
-- beast difficulty levels.
--
-- Beast Tier: Classification based on actual game logic from beast.cairo:
-- T1 (IDs 1-5, 26-30, 51-55) - Highest value, 15 beasts
-- T2 (IDs 6-10, 31-35, 56-60) - High value, 15 beasts
-- T3 (IDs 11-15, 36-40, 61-65) - Medium value, 15 beasts
-- T4 (IDs 16-20, 41-45, 66-70) - Low value, 15 beasts
-- T5 (IDs 21-25, 46-50, 71-75) - Lowest value, 15 beasts
--
-- This query uses temporal matching to link beast NFT Transfer events (claims) to their
-- corresponding beast encounter events (CollectableEntity with full stats), enabling accurate
-- tier classification of all claimed beasts across the game ecosystem.

WITH nft_claims AS (
  -- Get ALL beast NFT transfers (to any wallet)
  SELECT
    transaction_hash as claim_tx,
    block_time as claim_time,
    keys[3] as recipient_wallet
  FROM starknet.events
  WHERE from_address = 0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4
    AND CARDINALITY(keys) >= 5
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
    AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000  -- from = 0x0 (mints only)
    AND block_time >= CAST('2025-09-15' AS TIMESTAMP)
),
beast_encounters AS (
  -- Get all beast encounters with CORRECT tier classification
  -- Tier logic from contracts/src/models/beast.cairo
  SELECT
    block_time as encounter_time,
    CASE
      -- T1: IDs 1-5, 26-30, 51-55 (15 beasts - highest value)
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 1 AND 5)
        OR (bytearray_to_uint256(data[7]) BETWEEN 26 AND 30)
        OR (bytearray_to_uint256(data[7]) BETWEEN 51 AND 55) THEN 'T1'
      -- T2: IDs 6-10, 31-35, 56-60 (15 beasts)
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 6 AND 10)
        OR (bytearray_to_uint256(data[7]) BETWEEN 31 AND 35)
        OR (bytearray_to_uint256(data[7]) BETWEEN 56 AND 60) THEN 'T2'
      -- T3: IDs 11-15, 36-40, 61-65 (15 beasts)
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 11 AND 15)
        OR (bytearray_to_uint256(data[7]) BETWEEN 36 AND 40)
        OR (bytearray_to_uint256(data[7]) BETWEEN 61 AND 65) THEN 'T3'
      -- T4: IDs 16-20, 41-45, 66-70 (15 beasts)
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 16 AND 20)
        OR (bytearray_to_uint256(data[7]) BETWEEN 41 AND 45)
        OR (bytearray_to_uint256(data[7]) BETWEEN 66 AND 70) THEN 'T4'
      -- T5: IDs 21-25, 46-50, 71-75 (15 beasts - lowest value)
      WHEN (bytearray_to_uint256(data[7]) BETWEEN 21 AND 25)
        OR (bytearray_to_uint256(data[7]) BETWEEN 46 AND 50)
        OR (bytearray_to_uint256(data[7]) BETWEEN 71 AND 75) THEN 'T5'
      ELSE 'Unknown'
    END as beast_tier
  FROM starknet.events
  WHERE from_address = 0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a
    AND event_index = 1
    AND CARDINALITY(data) >= 13
    AND bytearray_to_uint256(data[1]) = 3
    AND bytearray_to_uint256(data[7]) BETWEEN 1 AND 75
    AND block_time >= CAST('2025-09-15' AS TIMESTAMP)
),
matched_claims AS (
  -- Link each NFT claim to the most recent beast encounter before it
  SELECT
    c.recipient_wallet,
    b.beast_tier,
    ROW_NUMBER() OVER (PARTITION BY c.claim_tx ORDER BY b.encounter_time DESC) as rn
  FROM nft_claims c
  LEFT JOIN beast_encounters b
    ON b.encounter_time < c.claim_time
)
SELECT
  beast_tier AS "Beast Tier",
  COUNT(*) as "Total Beasts Claimed",
  COUNT(DISTINCT recipient_wallet) as "Unique Collectors"
FROM matched_claims
WHERE rn = 1
  AND beast_tier IS NOT NULL
GROUP BY beast_tier
ORDER BY beast_tier
