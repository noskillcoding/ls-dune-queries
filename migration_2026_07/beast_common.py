import v2_blocks as B
BEASTS="0x046da8955829adf2bda310099a0063451923f02e648cf25a1203aac6335cf0e4"
TRANSFER="0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9"
ZERO="0x0000000000000000000000000000000000000000000000000000000000000000"

def tier(expr):
    return f"""CASE
      WHEN ({expr} BETWEEN 1 AND 5)   OR ({expr} BETWEEN 26 AND 30) OR ({expr} BETWEEN 51 AND 55) THEN 'T1'
      WHEN ({expr} BETWEEN 6 AND 10)  OR ({expr} BETWEEN 31 AND 35) OR ({expr} BETWEEN 56 AND 60) THEN 'T2'
      WHEN ({expr} BETWEEN 11 AND 15) OR ({expr} BETWEEN 36 AND 40) OR ({expr} BETWEEN 61 AND 65) THEN 'T3'
      WHEN ({expr} BETWEEN 16 AND 20) OR ({expr} BETWEEN 41 AND 45) OR ({expr} BETWEEN 66 AND 70) THEN 'T4'
      WHEN ({expr} BETWEEN 21 AND 25) OR ({expr} BETWEEN 46 AND 50) OR ({expr} BETWEEN 71 AND 75) THEN 'T5'
      ELSE 'Unknown'
    END"""

HDR = """-- 2026-07-26: spans the Loot Survivor V1 -> V2 cutover.
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
"""

def encounters_cte():
    return f"""v1_encounters AS (
  SELECT block_time AS encounter_time,
         {tier('bytearray_to_uint256(data[7])')} AS beast_tier
  FROM starknet.events
  WHERE from_address = {B.PGWORLD}
    AND event_index = 1
    AND CARDINALITY(data) >= 13
    AND bytearray_to_uint256(data[1]) = 3
    AND bytearray_to_uint256(data[7]) BETWEEN 1 AND 75
    AND block_time >= CAST('2025-09-15' AS TIMESTAMP)
),

v2_ev_raw AS (
  SELECT CASE WHEN cardinality(keys) >= 2 THEN 0 ELSE 1 END AS off, data, block_time
  FROM starknet.events
  WHERE from_address = {B.GAME2}
    AND keys[1] = {B.GAMEEVENT}
    AND cardinality(data) >= 2
    AND block_time >= {B.V2_START}
),

v2_encounters AS (
  SELECT encounter_time, {tier('beast_id')} AS beast_tier
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
)"""
