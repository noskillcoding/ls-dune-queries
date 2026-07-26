-- Dune query 5996309: LS2-daily
-- https://dune.com/queries/5996309
-- version 10 as of 2026-07-26

-- StarkNet Contract Activity Analysis
--
-- Action Identification: Categorizes contract interactions (explore, attack, flee, buy items, etc.)
-- to understand player behavior and feature usage.
-- Transaction Count (txs): Measures the frequency of interactions, indicating player engagement.
-- Date: Tracks activity over time to identify trends and peak usage periods.
--
-- 2026-07-26 changes:
--  1. Spans the V1->V2 contract cutover (V1 dead after 2026-05-04, V2 live from 2026-05-05).
--  2. BUGFIX: 'buy items' and 'select stat upgrades' were SWAPPED. Verified via
--     starknet_keccak: 0x021d2418.. = buy_items, 0x02467eba.. = select_stat_upgrades.
--     The two series had been mislabelled for the life of the dashboard.
--  3. Added V2-only entry points: drop_items (renamed from V1 'drop'), surrender,
--     buy_external_item.
--  4. Restricted to actual player-facing entry points. V2 routes a large volume of
--     internal/system calls through the game contract (one selector alone had 1.6M calls
--     in July from a single caller), which would otherwise swamp the chart as 'other'.

SELECT
  CASE entry_point_selector
    WHEN 0x01f64d317ff277789ba74de95db50418ab0fa47c09241400b7379b50d6334c3a THEN 'explore'
    WHEN 0x02d1af4265f4530c75b41282ed3b71617d3d435e96fe13b08848482173692f4f THEN 'attack'
    WHEN 0x011a7c59c924cc874e20358db055478acbf359f83bbe68547e90cb94dae65a5c THEN 'flee'
    WHEN 0x021d241887a9e02da42301e9b400c220b595d67b103cec7112a7fdc44f4e12a5 THEN 'buy items'
    WHEN 0x02467ebac97effcc7cd81bb8e877a27039732a954c40231131e63a779b13d8cc THEN 'select stat upgrades'
    WHEN 0x02214fe6a6e2545aebfe589b84884a2c528416482abec76605b7fdb1c31ce5b2 THEN 'start game'
    WHEN 0x027f806b163e00b12dc7f2e54f3865ceba98cadef57cc65c6e10f64195ccd015 THEN 'equip'
    WHEN 0x03297c61b5c92ef107ffd30cd56affe5a273e841d202d87dff9baf0090116b99 THEN 'drop items'
    WHEN 0x0301787479143648c7731d011d462aa4684a81ef8a6645023116871b4c0c1f13 THEN 'drop items'
    WHEN 0x007647db234d6e5c5db278611b6fd444f721d91d516ebe86a63f5bb9c183f0eb THEN 'surrender'
    WHEN 0x037768b9c251204d0e21d58deab72eefc602032f036dc4a646900e49cacd9f4c THEN 'buy external item'
  END AS action,
  entry_point_selector,
  COUNT(DISTINCT transaction_hash) AS txs,
  DATE_TRUNC('day', block_time) AS date
FROM starknet.calls
WHERE contract_address IN (
    0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c,  -- game V1 (through 2026-05-04)
    0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405   -- game V2 (from 2026-05-05)
  )
  AND entry_point_selector IN (
    0x01f64d317ff277789ba74de95db50418ab0fa47c09241400b7379b50d6334c3a,  -- explore
    0x02d1af4265f4530c75b41282ed3b71617d3d435e96fe13b08848482173692f4f,  -- attack
    0x011a7c59c924cc874e20358db055478acbf359f83bbe68547e90cb94dae65a5c,  -- flee
    0x021d241887a9e02da42301e9b400c220b595d67b103cec7112a7fdc44f4e12a5,  -- buy_items
    0x02467ebac97effcc7cd81bb8e877a27039732a954c40231131e63a779b13d8cc,  -- select_stat_upgrades
    0x02214fe6a6e2545aebfe589b84884a2c528416482abec76605b7fdb1c31ce5b2,  -- start_game
    0x027f806b163e00b12dc7f2e54f3865ceba98cadef57cc65c6e10f64195ccd015,  -- equip
    0x03297c61b5c92ef107ffd30cd56affe5a273e841d202d87dff9baf0090116b99,  -- drop (V1)
    0x0301787479143648c7731d011d462aa4684a81ef8a6645023116871b4c0c1f13,  -- drop_items (V2)
    0x007647db234d6e5c5db278611b6fd444f721d91d516ebe86a63f5bb9c183f0eb,  -- surrender (V2)
    0x037768b9c251204d0e21d58deab72eefc602032f036dc4a646900e49cacd9f4c   -- buy_external_item (V2)
  )
GROUP BY 1, 2, 4
ORDER BY date DESC, txs DESC
