# ls-dune-queries

A collection of SQL analytics queries for **Loot Survivor** (Death Mountain / Beast Mode) on
**Starknet**. These queries power dashboard charts, leaderboards, and economic metrics, running
against indexed on-chain data (Dune-style schema: `transactions`, `events`, token transfers, and
materialized views such as `ls_2_deaths`).

All identifiers referenced here — contract addresses, entry-point selectors, and event keys — are
public on-chain values. No credentials or secrets are included.

## Queries

| # | File | Description |
|---|------|-------------|
| 01 | [`query_01_contract_activity_analysis.sql`](query_01_contract_activity_analysis.sql) | Contract activity by action (explore, attack, flee, buy items, etc.) and transaction counts. |
| 02 | [`query_02_overall_engagement_metrics.sql`](query_02_overall_engagement_metrics.sql) | Overall engagement: unique users and total transactions against the game contract. |
| 03 | [`query_03_daily_player_breakdown.sql`](query_03_daily_player_breakdown.sql) | Daily players split into total / new / returning. |
| 04 | [`query_04_player_account_type_analysis.sql`](query_04_player_account_type_analysis.sql) | Daily active players segmented by account type (Cartridge Controller vs. manual wallet). |
| 05 | [`query_05_transaction_fee_analysis.sql`](query_05_transaction_fee_analysis.sql) | Daily transaction fees in native tokens (STRK/ETH) and USD. |
| 06 | [`query_06_total_fee_summary.sql`](query_06_total_fee_summary.sql) | Cumulative all-time transaction fees in USD. |
| 07 | [`query_07_dungeon_tickets_consumed.sql`](query_07_dungeon_tickets_consumed.sql) | Daily dungeon tickets burned to enter Beast Mode. |
| 08 | [`query_08_total_tickets_summary.sql`](query_08_total_tickets_summary.sql) | Cumulative Beast Mode tickets consumed, with USD valuation. |
| 09 | [`query_09_top200_active_players.sql`](query_09_top200_active_players.sql) | Top 200 active players by games initiated across all modes. |
| 10 | [`query_10_top50_beast_hunters.sql`](query_10_top50_beast_hunters.sql) | Top beast hunters (last 2 weeks) by tier-weighted hunting efficiency. |
| 11 | [`query_11_top200_fortune_hunters.sql`](query_11_top200_fortune_hunters.sql) | Top 200 fortune hunters by fortune-hunting efficiency score. |
| 12 | [`query_12_ticket_daily_price.sql`](query_12_ticket_daily_price.sql) | Daily TICKET token price (USD) sourced from Ekubo DEX. |
| 13 | [`query_13_ticket_daily_issuance.sql`](query_13_ticket_daily_issuance.sql) | Daily TICKET token issuance (mints). |
| 14 | [`query_14_deaths_by_level_pie.sql`](query_14_deaths_by_level_pie.sql) | Death distribution across levels 1–60 (Beast Mode, pie chart). |
| 15 | [`query_15_top50_level_hunters.sql`](query_15_top50_level_hunters.sql) | Top level hunters (last 2 weeks) by average level reached at death. |
| 16 | [`query_16_deaths_by_level_range.sql`](query_16_deaths_by_level_range.sql) | Death distribution across level ranges (uses `ls_2_deaths` view). |
| 17 | [`query_17_deaths_by_type.sql`](query_17_deaths_by_type.sql) | Death distribution by cause (beast vs. obstacle). |
| 18 | [`query_18_top200_deaths_leaderboard.sql`](query_18_top200_deaths_leaderboard.sql) | Top 200 deaths leaderboard by highest level reached at death. |
| 19 | [`query_19_deaths_by_day_and_mode.sql`](query_19_deaths_by_day_and_mode.sql) | Daily deaths broken down by game mode. |
| 20 | [`query_20_daily_beast_claims.sql`](query_20_daily_beast_claims.sql) | Daily beasts minted/claimed via `claim_beast` calls. |
| 21 | [`query_21_weekly_players_query.sql`](query_21_weekly_players_query.sql) | Weekly active players. |
| 22 | [`query_22_beast_claims_by_tier.sql`](query_22_beast_claims_by_tier.sql) | Total beast NFTs claimed grouped by tier (T1–T5). |
| 23 | [`query_23_daily_beast_claims_by_tier.sql`](query_23_daily_beast_claims_by_tier.sql) | Daily beast NFT claims per tier (T1–T5). |
| 24 | [`query_24_lords_distribution.sql`](query_24_lords_distribution.sql) | Daily LORDS revenue distribution from ticket sales (80% Treasury / 20% veLORDS). |
| 25 | [`query_25_survivor_buybacks.sql`](query_25_survivor_buybacks.sql) | Weekly SURVIVOR buybacks via TWAMM sent to governance. |
| 26 | [`query_26_revenue_totals.sql`](query_26_revenue_totals.sql) | All-time revenue & buyback totals for dashboard counters. |
| 27 | [`query_27_dticket_issuance_mode.sql`](query_27_dticket_issuance_mode.sql) | Current DTICKET issuance mode and emission rate. |
| 28 | [`query_28_base_game_tx_tracking.sql`](query_28_base_game_tx_tracking.sql) | Daily game transactions vs. total Starknet network transactions (incl. VRF-wrapped calls). |
| 29 | [`query_29_top50_beast_mode.sql`](query_29_top50_beast_mode.sql) | Top 50 Beast Mode leaderboard (rolling 2-week window). |
| 30 | [`query_30_dticket_purchases_by_token.sql`](query_30_dticket_purchases_by_token.sql) | DTICKET purchases broken down by payment token. |
| 31.1 | [`query_31.1_dont_die_tournament.sql`](query_31.1_dont_die_tournament.sql) | "Don't Die" tournament leaderboard (by XP). |
| 31.2 | [`query_31.2_dont_die_tournament_stats.sql`](query_31.2_dont_die_tournament_stats.sql) | "Don't Die" tournament per-player stats. |
| 32.1 | [`query_32.1_tournament_2_leaderboard.sql`](query_32.1_tournament_2_leaderboard.sql) | Tournament 2 leaderboard (Jan 27 – Feb 10, 2026). |
| 32.2 | [`query_32.2_tournament_2_stats.sql`](query_32.2_tournament_2_stats.sql) | Tournament 2 per-player stats. |
| 33.1 | [`query_33.1_tournament_3_leaderboard.sql`](query_33.1_tournament_3_leaderboard.sql) | Tournament 3 leaderboard (Jan 28 – Feb 4, 2026). |
| 33.2 | [`query_33.2_tournament_3_stats.sql`](query_33.2_tournament_3_stats.sql) | Tournament 3 per-player stats. |
| — | [`query_token_prices.sql`](query_token_prices.sql) | USD prices for all tracked tokens via the Ekubo oracle (EKUBO/USDC base pair). |

## License

Released into the public domain. Use freely.
