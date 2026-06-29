-- TICKET Token Daily Issuance - V2
--
-- Day: Date of the ticket issuance.
--
-- Tickets Issued: Total number of TICKET tokens minted on that day through the issuance mechanism.
--
-- Unique Recipients: Number of distinct addresses that received newly issued tickets.
--
-- This chart tracks the daily issuance of TICKET tokens from the protocol. The base issuance
-- rate is ~2,000 tickets per day, but can be adjusted based on market conditions. When TICKET
-- price falls below $1 for 3 consecutive days, the issuance rate halves automatically to reduce
-- supply pressure and maintain sustainable pricing.

SELECT
  DATE_TRUNC('day', block_time) AS "Day",
  SUM(bytearray_to_uint256(data[1]) / 1e18) AS "Tickets issued",
  COUNT(DISTINCT TRY_CAST(keys[3] AS VARCHAR)) AS "Unique recipients"
FROM starknet.events
WHERE from_address = 0x035f581b050a39958b7188ab5c75daaa1f9d3571a0c032203038c898663f31f8
  AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9
  AND keys[2] = 0x0000000000000000000000000000000000000000000000000000000000000000
  AND block_time >= TIMESTAMP '2025-09-15'
GROUP BY 1
ORDER BY 1 DESC
