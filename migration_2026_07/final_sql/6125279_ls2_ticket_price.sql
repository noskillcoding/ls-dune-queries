-- Dune query 6125279: LS2-ticket price
-- https://dune.com/queries/6125279
-- version 10 as of 2026-07-26

-- Token Prices via Ekubo Oracle
-- Returns USD prices for all tracked tokens, routing through EKUBO.
--
-- 2026-07-26 FIX: the USD anchor used to be the single EKUBO/USDC pair
-- (0x053c9125...). That Ekubo pool went dry in early March 2026 (168 oracle
-- snapshots in Feb 2026 -> 9 in Mar -> 0 after), and because the final join was an
-- INNER JOIN on hour, *every* token price silently disappeared after 2026-03-02.
-- The anchor is now derived from ANY available USD-pegged stable/EKUBO pair and
-- forward-filled across hours, so one pool migrating can no longer blank the feed.
--
-- Output contract unchanged: day, token_symbol, token_address, avg_price_usd

WITH token_meta AS (
  SELECT * FROM (VALUES
    (X'075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87', 'EKUBO', 18, false),
    -- USD-pegged anchors (6 decimals). 0x033068f6 is the live one; the others are
    -- retained so historical hours still resolve.
    (X'033068f6539f8e6e6b131e6b2b814e6c34a5224bc66947c47dab9dfee93b35fb', 'USDC', 6, true),
    (X'053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8', 'USDC_old', 6, true),
    (X'068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8', 'USDT', 6, true),
    -- game / ecosystem tokens
    (X'035f581b050a39958b7188ab5c75daaa1f9d3571a0c032203038c898663f31f8', 'TICKET', 18, false),
    (X'0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136', 'DTICKET', 18, false),
    (X'042dd777885ad2c116be96d4d634abc90a26a790ffb5871e037dd5ae7d2ec86b', 'SURVIVOR', 18, false),
    (X'0124aeb495b947201f5fac96fd1138e326ad86195b98df6dec9009158a533b49', 'LORDS', 18, false),
    (X'04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d', 'STRK', 18, false),
    (X'049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7', 'ETH', 18, false),
    (X'0498edfaf50ca5855666a700c25dd629d577eb9afccdf3b5977aec79aee55ada', 'CASH', 18, false),
    (X'04fcaf2a7b4a072fe57c59beee807322d34ed65000d78611c909a46fead07fb1', 'DREAMS', 18, false)
  ) AS t(address, symbol, decimals, is_usd_anchor)
),

ekubo_addr AS (
  SELECT X'075afe6402ad5a5c20dd25e10ec3b3986acaa647b77e4ae24b0cbc9a54a27a87' AS a
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
    AND data[2] IN (SELECT address FROM token_meta)
),

deduped AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY token0, token1, ts_u64 ORDER BY block_time DESC) AS rn
  FROM oracle_snaps
),

diffs AS (
  SELECT
    token0, token1, block_time,
    tick_cum - LAG(tick_cum) OVER (PARTITION BY token0, token1 ORDER BY ts_u64) AS dTick,
    ts_u64  - LAG(ts_u64)  OVER (PARTITION BY token0, token1 ORDER BY ts_u64) AS dt
  FROM deduped
  WHERE rn = 1
),

ticks AS (
  SELECT token0, token1, block_time,
         CAST(dTick AS DOUBLE) / NULLIF(CAST(dt AS DOUBLE), 0) AS avg_tick
  FROM diffs
  -- dt lower bound raised 1s -> 60s: near-simultaneous oracle snapshots (dt of a
  -- couple of seconds) produce garbage average ticks. A real case on 2026-07-10
  -- 18:59:29 had dt=2s with a sign-flipped dTick, pricing LORDS at $21.42 instead
  -- of ~$0.0029 - which would have corrupted every LORDS revenue/buyback figure.
  WHERE dt BETWEEN 60 AND 86400
),

-- price_real = units of token1 per 1 token0, decimal adjusted
pair_prices AS (
  SELECT
    date_trunc('hour', t.block_time) AS hour,
    t.token0, t.token1,
    POWER(1.000001, t.avg_tick) * POWER(10, (tm0.decimals - tm1.decimals)) AS price_real
  FROM ticks t
  JOIN token_meta tm0 ON tm0.address = t.token0
  JOIN token_meta tm1 ON tm1.address = t.token1
),

-- USD price of EKUBO from every available stable pair, averaged per hour
ekubo_usd_raw AS (
  SELECT hour, AVG(usd_per_ekubo) AS usd_per_ekubo
  FROM (
    SELECT
      p.hour,
      CASE WHEN p.token0 = (SELECT a FROM ekubo_addr)
           THEN p.price_real ELSE 1 / NULLIF(p.price_real, 0) END AS usd_per_ekubo
    FROM pair_prices p
    JOIN token_meta anchor
      ON anchor.is_usd_anchor
     AND anchor.address = CASE WHEN p.token0 = (SELECT a FROM ekubo_addr)
                               THEN p.token1 ELSE p.token0 END
    WHERE (SELECT a FROM ekubo_addr) IN (p.token0, p.token1)
  ) z
  WHERE usd_per_ekubo IS NOT NULL AND usd_per_ekubo > 0
  GROUP BY 1
),

all_hours AS (SELECT DISTINCT hour FROM pair_prices),

-- forward-fill the anchor across hours
ekubo_usd AS (
  SELECT
    h.hour,
    LAST_VALUE(r.usd_per_ekubo) IGNORE NULLS
      OVER (ORDER BY h.hour ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS usd_per_ekubo
  FROM all_hours h
  LEFT JOIN ekubo_usd_raw r ON r.hour = h.hour
),

token_ekubo AS (
  SELECT
    hour,
    CASE WHEN token0 = (SELECT a FROM ekubo_addr) THEN token1 ELSE token0 END AS token_address,
    CASE WHEN token0 = (SELECT a FROM ekubo_addr)
         THEN 1 / NULLIF(price_real, 0) ELSE price_real END AS token_per_ekubo
  FROM pair_prices
  WHERE (SELECT a FROM ekubo_addr) IN (token0, token1)
),

token_usd AS (
  SELECT t.hour, t.token_address, t.token_per_ekubo * e.usd_per_ekubo AS usd_per_token
  FROM token_ekubo t
  JOIN ekubo_usd e ON t.hour = e.hour
  WHERE e.usd_per_ekubo IS NOT NULL
),

ekubo_self AS (
  SELECT hour, (SELECT a FROM ekubo_addr) AS token_address, usd_per_ekubo AS usd_per_token
  FROM ekubo_usd
  WHERE usd_per_ekubo IS NOT NULL
),

combined AS (
  SELECT * FROM token_usd
  UNION ALL
  SELECT * FROM ekubo_self
)

SELECT
  date_trunc('day', hour) AS day,
  m.symbol AS token_symbol,
  token_address,
  AVG(usd_per_token) AS avg_price_usd
FROM combined
JOIN token_meta m ON combined.token_address = m.address
WHERE usd_per_token IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY day DESC
