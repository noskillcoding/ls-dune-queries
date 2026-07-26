-- Dune query 6608266: LS2-daily dticket purchases
-- version 4 backed up 2026-07-26

WITH dticket_receipts AS (
  -- DTICKET transfers FROM intermediary TO users (purchases via Cartridge)
  SELECT
    transaction_hash,
    DATE_TRUNC('day', block_time) AS day,
    keys[3] AS buyer
  FROM starknet.events
  WHERE from_address = 0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136  -- DTICKET contract
    AND keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9  -- Transfer
    AND CARDINALITY(keys) >= 3
    AND keys[2] = 0x0199741822c2dc722f6f605204f35e56dbc23bceed54818168c4c49e4fb8737e  -- FROM Cartridge intermediary
    AND keys[3] != 0x0000000000000000000000000000000000000000000000000000000000000000  -- not to zero address
    AND block_time >= TIMESTAMP '2025-09-15 00:00:00'
),

payments_to_intermediary AS (
  -- Tokens sent TO the intermediary by the buyer
  SELECT
    e.transaction_hash,
    r.day,
    CASE e.from_address
      WHEN 0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d THEN 'STRK'
      WHEN 0x042dd777885ad2c116be96d4d634abc90a26a790ffb5871e037dd5ae7d2ec86b THEN 'SURVIVOR'
      WHEN 0x0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49 THEN 'LORDS'
      WHEN 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7 THEN 'ETH'
      WHEN 0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8 THEN 'USDC'
      WHEN 0x033068f6539f8e6e6b131e6b2b814e6c34a5224bc66947c47dab9dfee93b35fb THEN 'USDT'
      WHEN 0x0498edfaf50ca5855666a700c25dd629d577eb9afccdf3b5977aec79aee55ada THEN 'CASH'
      WHEN 0x04fcaf2a7b4a072fe57c59beee807322d34ed65000d78611c909a46fead07fb1 THEN 'DREAMS'
      WHEN 0x075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87 THEN 'EKUBO'
      ELSE 'OTHER'
    END AS payment_token
  FROM starknet.events e
  JOIN dticket_receipts r ON e.transaction_hash = r.transaction_hash
  WHERE e.keys[1] = 0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9  -- Transfer
    AND CARDINALITY(e.data) >= 1
    -- TO intermediary (check both formats: STRK has 1 key, others have 3+)
    AND (
      (CARDINALITY(e.keys) = 1 AND e.data[2] = 0x0199741822c2dc722f6f605204f35e56dbc23bceed54818168c4c49e4fb8737e)
      OR (CARDINALITY(e.keys) >= 3 AND e.keys[3] = 0x0199741822c2dc722f6f605204f35e56dbc23bceed54818168c4c49e4fb8737e)
    )
    -- FROM the buyer (not from intermediary or Ekubo)
    AND (
      (CARDINALITY(e.keys) = 1 AND e.data[1] = r.buyer)
      OR (CARDINALITY(e.keys) >= 3 AND e.keys[2] = r.buyer)
    )
)

SELECT
  day AS "Day",
  payment_token AS "Payment Token",
  COUNT(*) AS "Purchases"
FROM payments_to_intermediary
GROUP BY day, payment_token
ORDER BY day DESC, "Purchases" DESC
