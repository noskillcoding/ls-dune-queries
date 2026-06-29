-- Token Prices via Ekubo Oracle
-- Returns USD prices for all tracked tokens using EKUBO/USDC as base pair

WITH token_meta AS (
  SELECT * FROM (VALUES
    (X'075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87', 'EKUBO', 18),
    (X'053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8', 'USDC', 6),
    (X'033068f6539f8e6e6b131e6b2b814e6c34a5224bc66947c47dab9dfee93b35fb', 'USDT', 6),
    (X'035f581b050a39958b7188ab5c75daaa1f9d3571a0c032203038c898663f31f8', 'TICKET', 18),
    (X'0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136', 'DTICKET', 18),
    (X'042dd777885ad2c116be96d4d634abc90a26a790ffb5871e037dd5ae7d2ec86b', 'SURVIVOR', 18),
    (X'0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49', 'LORDS', 18),
    (X'04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d', 'STRK', 18),
    (X'049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7', 'ETH', 18),
    (X'0498edfaf50ca5855666a700c25dd629d577eb9afccdf3b5977aec79aee55ada', 'CASH', 18),
    (X'04fcaf2a7b4a072fe57c59beee807322d34ed65000d78611c909a46fead07fb1', 'DREAMS', 18)
  ) AS t(address, symbol, decimals)
),

oracle_snaps AS (
  SELECT
    block_time,
    bytearray_to_uint256(data[4]) AS ts_u64,
    CASE
      WHEN bytearray_to_uint256(data[6]) = 1 THEN -CAST(bytearray_to_uint256(data[5]) AS DOUBLE)
      ELSE CAST(bytearray_to_uint256(data[5]) AS DOUBLE)
    END AS tick_cum,
    data[1] AS token0,
    data[2] AS token1
  FROM starknet.events
  WHERE
    from_address = X'005e470ff654d834983a46b8f29dfa99963d5044b993cb7b9c92243a69dab38f'
    AND keys[1] =  X'0385e1b60fdfb8aeee9212a69cdb72415cef7b24ec07a60cdd65b65d0582238b'
    AND block_time >= TIMESTAMP '2025-09-30 00:00:00'
    AND data[1] IN (SELECT address FROM token_meta)
),

deduped AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY token0, token1, ts_u64 ORDER BY block_time DESC) AS rn
  FROM oracle_snaps
),

diffs AS (
  SELECT
    token0,
    token1,
    block_time,
    tick_cum - LAG(tick_cum) OVER (PARTITION BY token0, token1 ORDER BY ts_u64) AS dTick,
    ts_u64  - LAG(ts_u64)  OVER (PARTITION BY token0, token1 ORDER BY ts_u64) AS dt
  FROM deduped
  WHERE rn = 1
),

ticks AS (
  SELECT
    token0,
    token1,
    block_time,
    CAST(dTick AS DOUBLE) / NULLIF(CAST(dt AS DOUBLE), 0) AS avg_tick
  FROM diffs
  WHERE dt BETWEEN 1 AND 86400
),

pair_prices AS (
  SELECT
    date_trunc('hour', t.block_time) AS hour,
    t.token0,
    t.token1,
    POWER(1.000001, t.avg_tick) * POWER(10, (tm0.decimals - tm1.decimals)) AS price_real
  FROM ticks t
  JOIN token_meta tm0 ON tm0.address = t.token0
  JOIN token_meta tm1 ON tm1.address = t.token1
),

ekubo_usd AS (
  SELECT
    hour,
    CASE
      WHEN token0 = X'075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87' THEN price_real
      ELSE 1 / price_real
    END AS usd_per_ekubo
  FROM pair_prices
  WHERE
    (token0 = X'075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87' AND token1 = X'053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8')
    OR
    (token1 = X'075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87' AND token0 = X'053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8')
),

token_ekubo AS (
  SELECT
    hour,
    CASE WHEN token0 = X'075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87' THEN token1 ELSE token0 END AS token_address,
    CASE WHEN token0 = X'075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87' THEN 1 / price_real ELSE price_real END AS token_per_ekubo
  FROM pair_prices
  WHERE token0 = X'075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87' OR token1 = X'075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87'
),

token_usd AS (
  SELECT
    t.hour,
    t.token_address,
    t.token_per_ekubo * e.usd_per_ekubo AS usd_per_token
  FROM token_ekubo t
  JOIN ekubo_usd e ON t.hour = e.hour
)

SELECT
  date_trunc('day', hour) AS day,
  m.symbol AS token_symbol,
  token_address,
  AVG(usd_per_token) AS avg_price_usd
FROM token_usd
JOIN token_meta m ON token_usd.token_address = m.address
GROUP BY 1, 2, 3
ORDER BY day DESC
