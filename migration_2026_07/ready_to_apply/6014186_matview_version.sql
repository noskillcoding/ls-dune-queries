-- READY TO APPLY once materialization is enabled in the Dune UI on
-- 6011955 / 6004055 / 6013674 / 6014300.
-- Do NOT apply before then: schema 'lowskillcoding' does not exist yet and both
-- queries would fail. Reverts query-as-view refs back to cheap matview table reads.

-- 2026-07-26: switched from the materialized view
-- dune.lowskillcoding.result_ls_2_deaths to a direct query-as-view reference
-- (dune.lowskillcoding.result_ls_2_deaths). The materialized view was dropped when the account was banned
-- (schema 'lowskillcoding' no longer exists) and there is no API to re-enable
-- materialization -- it is a UI-only toggle. Reading the producing query directly
-- removes that dependency entirely. If you later re-enable materialization on
-- 6011955 in the UI, this can be pointed back at the matview to save credits.
WITH level_data AS (
  -- Use results from the materialized deaths by level view
  SELECT
    "Level" as level,
    "Deaths" as deaths
  FROM dune.lowskillcoding.result_ls_2_deaths
),

level_ranges AS (
  SELECT
    deaths,
    CASE
      WHEN level >= 1 AND level <= 5 THEN 'Level 1 to 5'
      WHEN level >= 6 AND level <= 10 THEN 'Level 6 to 10'
      WHEN level >= 11 AND level <= 15 THEN 'Level 11 to 15'
      WHEN level >= 16 AND level <= 20 THEN 'Level 16 to 20'
      WHEN level >= 21 AND level <= 30 THEN 'Level 21 to 30'
      WHEN level >= 31 AND level <= 40 THEN 'Level 31 to 40'
      WHEN level >= 41 AND level <= 50 THEN 'Level 41 to 50'
      WHEN level > 50 THEN 'Level 50+'
    END as level_range,
    CASE
      WHEN level >= 1 AND level <= 5 THEN 1
      WHEN level >= 6 AND level <= 10 THEN 2
      WHEN level >= 11 AND level <= 15 THEN 3
      WHEN level >= 16 AND level <= 20 THEN 4
      WHEN level >= 21 AND level <= 30 THEN 5
      WHEN level >= 31 AND level <= 40 THEN 6
      WHEN level >= 41 AND level <= 50 THEN 7
      WHEN level > 50 THEN 8
    END as sort_order
  FROM level_data
),

total_deaths AS (
  SELECT SUM(deaths) as total
  FROM level_ranges
  WHERE level_range IS NOT NULL
)

SELECT
  level_range AS "Level range",
  SUM(deaths) AS "Deaths",
  ROUND(SUM(deaths) * 100.0 / t.total, 2) AS "Percentage"
FROM level_ranges
CROSS JOIN total_deaths t
WHERE level_range IS NOT NULL
GROUP BY level_range, sort_order, t.total
ORDER BY sort_order
