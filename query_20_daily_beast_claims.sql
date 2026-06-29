-- Daily Beast Claims Bar Chart
--
-- This query tracks the daily number of beasts minted (claimed) in Beast Mode
-- by analyzing claim_beast function calls on the Beast Mode contract.
--
-- Date: The calendar date of the claim
-- Beasts Claimed: Total number of beasts successfully claimed that day
--
-- Contract: Beast Mode (0x00a67ef20b61a9846e1c82b411175e6ab167ea9f8632bd6c2091823c3629ec42)
-- Function: claim_beast (selector: 0x037e4324eee07408cd4367ed1663988a4c2491174a5f1fd448e3c9a243e9cfe6)

SELECT
  DATE(b.block_time) AS "Date",
  COUNT(*) AS "Beasts Claimed"
FROM starknet.calls a
JOIN starknet.transactions b ON a.transaction_hash = b.transaction_hash
WHERE a.contract_address = 0x00a67ef20b61a9846e1c82b411175e6ab167ea9f8632bd6c2091823c3629ec42
  AND a.entry_point_selector = 0x037e4324eee07408cd4367ed1663988a4c2491174a5f1fd448e3c9a243e9cfe6
  AND b.block_time >= TIMESTAMP '2025-09-15'
GROUP BY DATE(b.block_time)
ORDER BY DATE(b.block_time)
