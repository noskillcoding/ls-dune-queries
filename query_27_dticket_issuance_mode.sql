-- DTICKET Issuance Mode Status
-- Shows current issuance mode and emission rate for dashboard counters
--
-- Low issuance mode: Activates when DTICKET price < $1 for 3+ days (50% reduction)
-- Default rate: ~2000 DTICKET/day (100M over 132 years)
-- Low issuance rate: ~1000 DTICKET/day (halved)
--
-- Tracks SUCCESSFUL mode changes via Transfer events (not function calls, which may revert)
-- Enable: Large transfer TO DTICKET contract (tokens returned from Ekubo)
-- Disable: Large transfer FROM DTICKET contract (tokens sent to Ekubo)
--
-- DTICKET contract: 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136

WITH mode_transfers AS (
  SELECT
    block_time,
    CASE
      WHEN keys[3] = 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136
      THEN 'enable'
      ELSE 'disable'
    END AS action,
    CAST(bytearray_to_uint256(data[1]) AS DOUBLE) / 1e18 AS amount
  FROM starknet.events
  WHERE
    from_address = 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9  -- Transfer
    AND (
      keys[2] = 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136  -- FROM contract (disable)
      OR keys[3] = 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136  -- TO contract (enable)
    )
    AND block_time >= TIMESTAMP '2025-11-12'
),

-- Filter for large transfers (mode changes involve millions of tokens)
mode_changes AS (
  SELECT block_time, action
  FROM mode_transfers
  WHERE amount > 1000000
),

latest_change AS (
  SELECT action, block_time AS mode_since
  FROM mode_changes
  ORDER BY block_time DESC
  LIMIT 1
)

SELECT
  CASE WHEN action = 'enable' THEN 'ON' ELSE 'OFF' END AS "Low issuance mode",
  CASE WHEN action = 'enable' THEN 1000 ELSE 2000 END AS "Daily emission rate",
  mode_since AS "Mode since"
FROM latest_change
