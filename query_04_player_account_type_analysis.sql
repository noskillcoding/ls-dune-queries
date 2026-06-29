-- Player Account Type Analysis - V2
--
-- Tracks daily active players segmented by account type:
--
-- Cartridge Controller: Players using Cartridge's account abstraction solution for
-- streamlined gameplay without manual transaction signing.
--
-- Manual: Players using traditional wallet connections, manually signing each transaction.
--
-- This breakdown helps understand wallet technology adoption and user experience preferences.
-- Higher Cartridge adoption typically indicates better UX accessibility and lower friction
-- for new players.

WITH all_txs AS (
  SELECT
    DISTINCT caller_address,
    sender_address,
    CASE WHEN caller_address != sender_address
      THEN 'Cartridge controller'
      ELSE 'Manual'
    END AS "Account type",
    a.transaction_hash AS tx,
    a.block_time AS tm
  FROM starknet.calls a
  JOIN starknet.transactions b
    ON a.transaction_hash = b.transaction_hash
  WHERE a.contract_address = 0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c
)

SELECT
  DATE_TRUNC('day', tm) AS date,
  "Account type",
  COUNT(DISTINCT caller_address) AS players
FROM all_txs
GROUP BY 1, 2
ORDER BY 1 DESC, 2
