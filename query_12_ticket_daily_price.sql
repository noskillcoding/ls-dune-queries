-- TICKET Token Daily Price - V2
--
-- Day: Date of the price data.
--
-- TICKET Price (USD): Average daily price of the TICKET token in USD, sourced from Ekubo DEX.
--
-- This chart tracks the daily market price of the TICKET token, which is used to enter Beast Mode
-- in Loot Survivor. TICKET is tradable on Ekubo DEX and represents the entry cost for Beast Mode gameplay.

SELECT
  day AS "Day",
  avg_price_usd AS "TICKET price (USD)"
FROM query_5959933
WHERE token_symbol = 'TICKET'
ORDER BY day DESC
