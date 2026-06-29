-- StarkNet Contract Activity Analysis - V2
--
-- Action Identification: Categorizes contract interactions (explore, attack, flee, buy items, etc.)
-- to understand player behavior and feature usage.
-- Transaction Count (txs): Measures the frequency of interactions, indicating player engagement
-- and contract popularity.
-- Date: Tracks activity over time to identify trends and peak usage periods.

SELECT
CASE
 WHEN entry_point_selector = 0x01f64d317ff277789ba74de95db50418ab0fa47c09241400b7379b50d6334c3a THEN 'explore'
 WHEN entry_point_selector = 0x02467ebac97effcc7cd81bb8e877a27039732a954c40231131e63a779b13d8cc THEN 'buy items'
 WHEN entry_point_selector = 0x02214fe6a6e2545aebfe589b84884a2c528416482abec76605b7fdb1c31ce5b2 THEN 'start game'
 WHEN entry_point_selector = 0x021d241887a9e02da42301e9b400c220b595d67b103cec7112a7fdc44f4e12a5 THEN 'select stat upgrades'
 WHEN entry_point_selector = 0x02d1af4265f4530c75b41282ed3b71617d3d435e96fe13b08848482173692f4f THEN 'attack'
 WHEN entry_point_selector = 0x011a7c59c924cc874e20358db055478acbf359f83bbe68547e90cb94dae65a5c THEN 'flee'
 WHEN entry_point_selector = 0x027f806b163e00b12dc7f2e54f3865ceba98cadef57cc65c6e10f64195ccd015 THEN 'equip'
 WHEN entry_point_selector = 0x03297c61b5c92ef107ffd30cd56affe5a273e841d202d87dff9baf0090116b99 THEN 'drop'
 ELSE 'other'
END AS action,
entry_point_selector,
COUNT(DISTINCT transaction_hash) AS txs,
DATE_TRUNC('day', block_time) AS date
FROM starknet.calls
WHERE contract_address = 0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c
GROUP BY 1, 2, 4
ORDER BY date DESC, txs DESC
