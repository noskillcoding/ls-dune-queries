# ls-dune-queries

A collection of SQL analytics queries for **Loot Survivor** (Death Mountain / Beast Mode) on
**Starknet**. These queries power dashboard charts, leaderboards, and economic metrics, running
against indexed on-chain data (Dune-style schema: `transactions`, `events`, token transfers, and
materialized views such as `ls_2_deaths`).

All identifiers referenced here — contract addresses, entry-point selectors, and event keys — are
public on-chain values. No credentials or secrets are included.


> ### ⚠️ Updated 2026-07-27 — migrated to Loot Survivor **Game V2**
>
> Loot Survivor moved to a new set of contracts on **2026-05-04/05**. Every query backing the
> live dashboard has been rewritten to span the cutover (V1 history **UNION** V2), and all 26
> are running again. Full write-up: [`DASHBOARD_REVIVAL_DIAGNOSIS.md`](DASHBOARD_REVIVAL_DIAGNOSIS.md).
> On-chain decode contract for V2: [`V2_EVENT_DECODE_REFERENCE.md`](V2_EVENT_DECODE_REFERENCE.md).
>
> **Not every file here is migrated.** Only the queries backing the live dashboard were.
> These are *not* on the dashboard and still reference now-dead V1 contracts — treat as
> historical until reworked:
> `query_04`, `query_11`, `query_13`, `query_20`, `query_31.1/.2`, `query_32.1/.2`, `query_33.1/.2`.

## Queries

| # | File | Description | Live Dune query |
|---|------|-------------|-----------------|
| 01 | [`query_01_contract_activity_analysis.sql`](query_01_contract_activity_analysis.sql) | Contract activity by action (explore, attack, flee, buy items, etc.) and transaction counts. | [5996309](https://dune.com/queries/5996309) |
| 02 | [`query_02_overall_engagement_metrics.sql`](query_02_overall_engagement_metrics.sql) | Overall engagement: unique users and total transactions against the game contract. | [5996449](https://dune.com/queries/5996449) |
| 03 | [`query_03_daily_player_breakdown.sql`](query_03_daily_player_breakdown.sql) | Daily players split into total / new / returning. | [5998617](https://dune.com/queries/5998617) |
| 04 | [`query_04_player_account_type_analysis.sql`](query_04_player_account_type_analysis.sql) | Daily active players segmented by account type (Cartridge Controller vs. manual wallet). | — |
| 05 | [`query_05_transaction_fee_analysis.sql`](query_05_transaction_fee_analysis.sql) | Daily transaction fees in native tokens (STRK/ETH) and USD. | [5998872](https://dune.com/queries/5998872) |
| 06 | [`query_06_total_fee_summary.sql`](query_06_total_fee_summary.sql) | Cumulative all-time transaction fees in USD. | [5999014](https://dune.com/queries/5999014) |
| 07 | [`query_07_dungeon_tickets_consumed.sql`](query_07_dungeon_tickets_consumed.sql) | Daily dungeon tickets burned to enter Beast Mode. | [5999424](https://dune.com/queries/5999424) |
| 08 | [`query_08_total_tickets_summary.sql`](query_08_total_tickets_summary.sql) | Cumulative Beast Mode tickets consumed, with USD valuation. | [5999508](https://dune.com/queries/5999508) |
| 09 | [`query_09_top200_active_players.sql`](query_09_top200_active_players.sql) | Top 200 active players by games initiated across all modes. | [5999525](https://dune.com/queries/5999525) |
| 10 | [`query_10_top50_beast_hunters.sql`](query_10_top50_beast_hunters.sql) | Top beast hunters (last 2 weeks) by tier-weighted hunting efficiency. | [6004055](https://dune.com/queries/6004055) |
| 11 | [`query_11_top200_fortune_hunters.sql`](query_11_top200_fortune_hunters.sql) | Top 200 fortune hunters by fortune-hunting efficiency score. | — |
| 12 | [`query_12_ticket_daily_price.sql`](query_12_ticket_daily_price.sql) | Daily TICKET token price (USD) sourced from Ekubo DEX. | — |
| 13 | [`query_13_ticket_daily_issuance.sql`](query_13_ticket_daily_issuance.sql) | Daily TICKET token issuance (mints). | — |
| 14 | [`query_14_deaths_by_level_pie.sql`](query_14_deaths_by_level_pie.sql) | Death distribution across levels 1–60 (Beast Mode, pie chart). | [6011955](https://dune.com/queries/6011955) |
| 15 | [`query_15_top50_level_hunters.sql`](query_15_top50_level_hunters.sql) | Top level hunters (last 2 weeks) by average level reached at death. | [6013674](https://dune.com/queries/6013674) |
| 16 | [`query_16_deaths_by_level_range.sql`](query_16_deaths_by_level_range.sql) | Death distribution across level ranges (uses `ls_2_deaths` view). | [6014186](https://dune.com/queries/6014186) |
| 17 | [`query_17_deaths_by_type.sql`](query_17_deaths_by_type.sql) | Death distribution by cause (beast vs. obstacle). | [6014208](https://dune.com/queries/6014208) |
| 18 | [`query_18_top200_deaths_leaderboard.sql`](query_18_top200_deaths_leaderboard.sql) | Top 200 deaths leaderboard by highest level reached at death. | [6014300](https://dune.com/queries/6014300) |
| 19 | [`query_19_deaths_by_day_and_mode.sql`](query_19_deaths_by_day_and_mode.sql) | Daily deaths broken down by game mode. | [6014360](https://dune.com/queries/6014360) |
| 20 | [`query_20_daily_beast_claims.sql`](query_20_daily_beast_claims.sql) | Daily beasts minted/claimed via `claim_beast` calls. | — |
| 21 | [`query_21_weekly_players_query.sql`](query_21_weekly_players_query.sql) | Weekly active players. | [6124973](https://dune.com/queries/6124973) |
| 22 | [`query_22_beast_claims_by_tier.sql`](query_22_beast_claims_by_tier.sql) | Total beast NFTs claimed grouped by tier (T1–T5). | [6127103](https://dune.com/queries/6127103) |
| 23 | [`query_23_daily_beast_claims_by_tier.sql`](query_23_daily_beast_claims_by_tier.sql) | Daily beast NFT claims per tier (T1–T5). | [6015003](https://dune.com/queries/6015003) |
| 24 | [`query_24_lords_distribution.sql`](query_24_lords_distribution.sql) | Daily LORDS revenue distribution from ticket sales (80% Treasury / 20% veLORDS). | [6359367](https://dune.com/queries/6359367) |
| 25 | [`query_25_survivor_buybacks.sql`](query_25_survivor_buybacks.sql) | Weekly SURVIVOR buybacks via TWAMM sent to governance. | [6359411](https://dune.com/queries/6359411) |
| 26 | [`query_26_revenue_totals.sql`](query_26_revenue_totals.sql) | All-time revenue & buyback totals for dashboard counters. | [6359454](https://dune.com/queries/6359454) |
| 27 | [`query_27_dticket_issuance_mode.sql`](query_27_dticket_issuance_mode.sql) | Current DTICKET issuance mode and emission rate. | [6358788](https://dune.com/queries/6358788) |
| 28 | [`query_28_base_game_tx_tracking.sql`](query_28_base_game_tx_tracking.sql) | Daily game transactions vs. total Starknet network transactions (incl. VRF-wrapped calls). | [6472962](https://dune.com/queries/6472962) |
| 29 | [`query_29_top50_beast_mode.sql`](query_29_top50_beast_mode.sql) | Top 50 Beast Mode leaderboard (rolling 2-week window). | [6576384](https://dune.com/queries/6576384) |
| 30 | [`query_30_dticket_purchases_by_token.sql`](query_30_dticket_purchases_by_token.sql) | DTICKET purchases broken down by payment token. | [6608266](https://dune.com/queries/6608266) |
| 31.1 | [`query_31.1_dont_die_tournament.sql`](query_31.1_dont_die_tournament.sql) | "Don't Die" tournament leaderboard (by XP). | — |
| 31.2 | [`query_31.2_dont_die_tournament_stats.sql`](query_31.2_dont_die_tournament_stats.sql) | "Don't Die" tournament per-player stats. | — |
| 32.1 | [`query_32.1_tournament_2_leaderboard.sql`](query_32.1_tournament_2_leaderboard.sql) | Tournament 2 leaderboard (Jan 27 – Feb 10, 2026). | — |
| 32.2 | [`query_32.2_tournament_2_stats.sql`](query_32.2_tournament_2_stats.sql) | Tournament 2 per-player stats. | — |
| 33.1 | [`query_33.1_tournament_3_leaderboard.sql`](query_33.1_tournament_3_leaderboard.sql) | Tournament 3 leaderboard (Jan 28 – Feb 4, 2026). | — |
| 33.2 | [`query_33.2_tournament_3_stats.sql`](query_33.2_tournament_3_stats.sql) | Tournament 3 per-player stats. | — |
| — | [`query_token_prices.sql`](query_token_prices.sql) | USD prices for all tracked tokens via the Ekubo oracle (EKUBO/USDC base pair). | [6125279](https://dune.com/queries/6125279) |

## Repo layout

| Path | What it is |
|---|---|
| `query_*.sql` | Individual queries. Those with a **Live Dune query** link are the migrated, running versions. |
| `migration_2026_07/final_sql/` | Authoritative export of all 26 live queries, named by Dune query ID (`manifest.json` has names + versions). |
| `migration_2026_07/*.py` | Tooling: `dune.py` (API client), `v2_blocks.py` (reusable V2 CTE builders), `beast_common.py`, `sn_keccak.py` (dependency-free `starknet_keccak`). |
| `migration_2026_07/ready_to_apply/` | Prepared variants kept for reference. |
| `dune_query_backup_20260726/` | Pre-migration SQL + version numbers — the revert source. |
| `DASHBOARD_REVIVAL_DIAGNOSIS.md` | Root-cause analysis, bugs found, credit/refresh notes. |
| `V2_EVENT_DECODE_REFERENCE.md` | Deployed-ABI decode: GameEvent layouts, variant indexes, selectors, dungeon attribution. |

## Using the tooling

No credentials are stored in this repo. Supply them via environment variables:

```bash
export DUNE_WRITE_KEY=...   # personal account key (owns the queries; used for writes)
export DUNE_EXEC_KEY=...    # team key on the paid plan (used for executions)

cd migration_2026_07
python3 -c "import dune; print(dune.meta(6011955)['name'])"
```

## License

Released into the public domain. Use freely.
