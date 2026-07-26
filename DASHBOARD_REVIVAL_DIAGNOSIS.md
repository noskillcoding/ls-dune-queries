# Loot Survivor 2 Dashboard — Revival Diagnosis

Investigated 2026-07-26. Dashboard: https://dune.com/lootsurvivor/loot-survivor-2
(team `lootsurvivor`, queries owned by user `lowskillcoding`).
Scope: 47 visualization widgets + 10 text widgets, backed by **25 distinct queries**.

## TL;DR — three *independent* root causes

| # | Root cause | Nature | Fixable by me via API? |
|---|---|---|---|
| 1 | **Game migrated V1 → V2 on 2026-05-04** | Upstream (real) | Yes — SQL rewrite |
| 2 | **5 queries still archived server-side** | Dune-side / ban fallout | **No** — needs UI or Dune support |
| 3 | **`dune.lowskillcoding` schema dropped** (4 materialized views gone) | Ban fallout | Yes, once #2 is unblocked |

Not a cause: Dune's Starknet data. It is complete and current (chain head = today,
zero missing days in `starknet.calls` / `starknet.events` / `starknet.transactions`).
Table schemas are unchanged. So this is **not** a Dune ingestion bug.

---

## Root cause 1 — Loot Survivor shipped Game V2 and abandoned the V1 contracts

The docs now carry an explicit **"Archive – Game V1"** section listing *exactly* the
contracts in this repo's `contracts.json`. Every query pointing at those addresses runs
fine but returns nothing after the cutover.

Old game contract `0x06f7c435…493a9c`, daily calls:

```
2026-05-01   86,889 calls / 71 players
2026-05-02   65,396 / 69
2026-05-03   57,981 / 62
2026-05-04   44,160 / 53     <-- last real day
2026-05-05 .. 2026-07-06   (nothing)
2026-07-07 onward          1–12 calls/day (stragglers)
```

Confirmed by following the players: the 123 wallets active on V1 in late April appear on
new contracts starting **exactly 2026-05-05**.

### V1 → V2 address mapping (from docs + confirmed on-chain)

| Role | V1 (dead) | V2 (live) |
|---|---|---|
| Game | `0x06f7c435…493a9c` | `0x023f86f5…edc405` |
| Game Token | `0x05e2dfbd…ba29863` | `0x04de0351…9722fa` |
| Beast Mode | `0x00a67ef2…29ec42` | `0x0539d24d…e43bbc` |
| Dungeon Ticket | `0x035f581b…63f31f8` (TICKET) | `0x04528101…858136` (DTICKET) |
| Denshokan | `0x036017e6…49d3cd` | `0x00263cc5…cd0bf9` |

V2 also splits game logic into new system contracts that did not exist in V1:
**Combat / Exploration / Market / Inventory / Stat Upgrades**, plus new dungeons
**Greed**, **Lil Duckies**, **Yield**. `beasts` NFT, `goldenToken`, SURVIVOR token and
governance contracts are **unchanged** and still live.

### The GameEvents stream also moved (and changed shape)

Deaths/levels were decoded from pgWorld events by positional index. That stream migrated:

```
source / data_len            2026-03   2026-04   2026-05   2026-06   2026-07
pgWorld  key 0x01c93f6e… 35  1446767   1634520    254426         -        31
V2 game  key 0x03e037e9… 32        -         -         -    750130    889679
```

So the 35-field GameEvent became a **32-field** event under a **new key**, emitted by the
**new game contract**. The 14-field settings event became 13/15-field. Consequence: the
death/level queries need a new `from_address`, new `keys[1]`, new `cardinality(data)`, and
**re-derived field offsets** (3 fields dropped, so `data[N]` positions shifted).
Offsets must be re-derived empirically — they cannot be assumed.

`entry_point_selector` values in the action-popularity query are V1 selectors and must be
re-derived against V2 as well.

---

## Root cause 2 — 5 queries are archived server-side (the UI unarchive did not stick)

These 404 on the API and cannot be read, executed, *or unarchived* by me:

| Query | Name | Role |
|---|---|---|
| 6011955 | LS2-deaths | produces `result_ls_2_deaths` |
| 6004055 | LS2-top50 beast hunters (2 weeks) | produces `result_ls_2_top_200_beast_hunters` |
| 6013674 | LS2-top50 level hunters (2 weeks) | produces `result_ls_2_top_200_level_hunters` |
| 6014300 | LS2-top200 beast mode | produces `result_ls_2_top_200_beast_mode` |
| 6125279 | (token prices view) | consumed by 5 revenue/ticket queries |

For **6125279** this is confirmed archived — Dune's own engine says so verbatim,
reproduced live today:

```
Cannot query Query 6125279, reason: query access error: the query is archived
```

`POST /api/v1/query/6125279/unarchive` → `404 Query not found`. There is no API path in.
This is a genuine Dune-side inconsistency (UI shows unarchived, backend disagrees).

**Caveat on the other four** (6004055, 6011955, 6013674, 6014300): they 404 on this API
key, but because the key is **team-scoped** (see "API key scope" below) a *private*
personal query is indistinguishable from an *archived* one — both 404. So these four are
"inaccessible to this key": archived, private, or both. Only 6125279 is proven archived.
Check their state in the UI to tell them apart.

## Root cause 3 — the materialized-view schema was dropped

`dune.lowskillcoding` **no longer exists**:

```
SELECT count(*) FROM dune.lowskillcoding.result_ls_2_deaths
  -> Schema 'lowskillcoding' does not exist
SELECT count(*) FROM dune.pg_team_6083.result_starknet_ekubo_prices
  -> 1164 rows   (a third party's matview is fine)
```

The 4 archived queries are precisely the 4 matview producers — archiving dropped their
output tables, which breaks downstream consumers. Unarchiving alone is not enough; each
producer must be **re-run with materialization enabled** to recreate its table.

---

## Per-query status (25 queries)

Legend: **ARCH** archived · **DEP** broken internal dependency · **V1** points at dead V1
contracts · **OK?** structurally fine, but check for fresh data

| Query | Name | Status |
|---|---|---|
| 6011955 | LS2-deaths | ARCH (matview producer) |
| 6004055 | LS2-top50 beast hunters (2w) | ARCH (matview producer) |
| 6013674 | LS2-top50 level hunters (2w) | ARCH (matview producer) |
| 6014300 | LS2-top200 beast mode | ARCH (matview producer) |
| 6125279 | token prices view | ARCH (feeds 5 queries) |
| 5999525 | LS2-top200 players stats | DEP ×3 matviews + V1 |
| 6014186 | LS2-deaths (range) | DEP `result_ls_2_deaths` |
| 5999424 | LS2-daily ticket volume | DEP 6125279 + V1 |
| 5999508 | LS2-tickets count | DEP 6125279 + V1 |
| 6359367 | LS2-lords revenue | DEP 6125279 + V1 |
| 6359411 | LS2-buybacks | DEP 6125279 |
| 6359454 | LS2-buyback numbers | DEP 6125279 + V1 |
| 5996309 | LS2-daily | V1 (+ V1 selectors) |
| 5996449 | LS2-total | V1 |
| 5998617 | LS2-daily players | V1 |
| 5998872 | LS2-daily fees | V1 |
| 5999014 | LS2-total fees | V1 |
| 6124973 | LS2-weekly players | V1 |
| 6472962 | LS2-LS Share of Starknet Txs | V1 |
| 6576384 | LS2-top50 players (2 weeks) | V1 (denshokan V1) |
| 6014208 | LS2-deaths by type | pgWorld stream dead → needs V2 event |
| 6014360 | LS2-daily deaths | pgWorld stream dead → needs V2 event |
| 6015003 | LS2-beasts daily | OK? (beasts NFT still live) |
| 6127103 | LS2-beasts claimed | OK? (beasts NFT still live) |
| 6358788 | LS2-low issuance mode | OK? (SURVIVOR token still live) |
| 6608266 | LS2-daily dticket purchases | OK? (DTICKET already V2) |

Roughly: **5 blocked on unarchive**, **7 with broken internal deps**, **14 needing V2
addresses**, **4 likely already fine**.

---

## What I can and cannot do

**Can do via API** (key is valid; `POST /api/v1/query/{id}` PATCH works on the 20 readable queries):
- Rewrite SQL for all 20 readable queries: V2 addresses, V2 event keys/cardinality,
  re-derived field offsets and entry-point selectors.
- Empirically re-derive the V2 GameEvent field layout on-chain (already demonstrated).
- Re-create the token-prices view as a new query from local `query_token_prices.sql`
  (its output contract — `day, token_symbol, avg_price_usd` — is known from consumers).
- Execute and validate every query end-to-end, and keep the local `.sql` files in sync.

**Cannot do — needs you or Dune support:**
- **Unarchive the 5 archived queries.** No API path; the UI unarchive is not sticking.
- **Re-point dashboard widgets.** There is no dashboard-write API on this plan, so if we
  replace an archived query with a *new* query ID, the affected widgets must be re-pointed
  in the UI (5 widgets: Deaths-by-level ×2, Top50 Beast Hunters, Top50 Level Hunters,
  Top200 Beast Mode).
- **Enable materialization.** That is a per-query UI toggle.
- Judge product intent: whether V1 history should be preserved alongside V2.

## Account limits (checked)

Undocumented endpoint `POST /api/v1/usage`:
- Credits: **239.7 / 4000** used; period ends 2026-07-29. This whole investigation cost ~3.
- `private_queries` allowance is **0** — creating private queries fails
  ("Max number of private queries reached"), so scratch queries must be public.
- Byte allowance 1 GB, 0 used.

## Footprint I left

Created one public scratch query **8113124** `ZZ-tmp-claude-freshness-probe` on the
account (needed because ad-hoc SQL requires a saved query, and private queries are not
allowed). Say the word and I'll remove it.

## Helper

`scratchpad/dune.py` — thin Dune API client (meta / patch / run / run_sql) used throughout.

---

# UPDATE 2026-07-26 — progress, plus a new hard blocker

## ⛔ API key scope: team, not personal (blocks bulk fixing)

The original API key is scoped to the **team `lootsurvivor`**, not the personal account
`lowskillcoding` that owns the queries.

| Query | owner | GET | PATCH |
|---|---|---|---|
| 8113496 (created by me) | `lootsurvivor` | 200 | **200 ✓** |
| 5999508 (yours) | `lowskillcoding` | 200 | **404 ✗** |
| 5996309 (yours) | `lowskillcoding` | 200 | **404 ✗** |

GET succeeds on your queries only because they are *public* — any valid key can read a
public query. Writing requires the key to own it. So with this key I **cannot edit any of
the 25 dashboard queries**. Nothing was changed on them; every write failed cleanly with
404, so the dashboard is exactly as it was.

**Unblock (best): create a personal-scope API key** under the `lowskillcoding` account
(Dune → Settings → API keys, select the personal account rather than the `lootsurvivor`
team). With that, the whole migration can be applied directly.

Alternatives if a personal key isn't possible:
- **B** — rebuild all 25 queries as team-owned copies (I can do that freely), then you
  re-point all 47 widgets in the UI. Large amount of manual UI work.
- **C** — I hand you corrected `.sql` files and you paste each into its query in the UI.
  21 pastes, no re-pointing needed.

## ✅ Delivered so far

**Token prices view rebuilt and live** — new query **8113496** `LS2-token prices`
(team-owned, so I *could* write it). Output contract preserved exactly:
`day, token_symbol, token_address, avg_price_usd`.

It also fixes a **second silent breakage that predates the ban**: the old view anchored USD
on the single `EKUBO/USDC (0x053c9125…)` pool, which went dry in early March 2026
(168 oracle snapshots in Feb → 9 in Mar → 0 after). Because the final join was an
INNER JOIN on `hour`, *every* token price vanished after **2026-03-02**. Prices now derive
from any available USD-pegged stable/EKUBO pair, forward-filled, so one pool migrating
cannot blank the feed. Validated: USDC = $1.00057, USDT = $0.99867 (peg holds),
ETH $1,870, EKUBO $0.436, and data runs to **2026-07-26**.

Also hardened the tick filter (`dt BETWEEN 1 AND 86400` → `60 AND 86400`). A snapshot on
2026-07-10 18:59:29 sat only 2 s after the prior one with a sign-flipped `dTick`, pricing
**LORDS at $21.42 instead of ~$0.0029** — a ~7000× error that would have corrupted every
LORDS revenue and buyback figure. LORDS now reads smoothly ($0.0028–0.0093).

The 5 consumers (5999424, 5999508, 6359367, 6359411, 6359454) still point at the dead
`query_6125279`; repointing them to `query_8113496` is a one-line change per query,
blocked only by the key scope above.

**Backups**: `dune_query_backup_20260726/` holds the current SQL + version number of all
21 readable queries, so any edit is revertible.

**V2 decode work is done** — see `V2_EVENT_DECODE_REFERENCE.md`. The GameEvent layout was
derived from the deployed ABI and validated against live data (equipment slot ID ranges
match Loot Survivor's item taxonomy exactly). Dungeon attribution is solved via
transaction correlation: of 12,727 July game starts — BeastMode 7,680, Greed 1,242, plus
two dungeons not yet in the docs (`0x065406785f…` 2,591 and `0x012ac35cf5…` 964).

## 🐞 Two pre-existing bugs found (independent of the ban and the migration)

1. **Swapped action labels** in 5996309 "LS2-daily" — `buy items` and
   `select stat upgrades` are reversed. See `V2_EVENT_DECODE_REFERENCE.md`.
2. **Dead USD anchor** in the token-prices view — all USD figures on the dashboard have
   been blank since 2026-03-02, two months *before* the V1→V2 cutover. Fixed in 8113496.

---

# FINAL 2026-07-26 — migration complete, all 26 queries live

A **personal-scope API key** unblocked everything. Working setup is a hybrid:
- **personal key** (`lowskillcoding`) → writes: PATCH / archive / unarchive. Costs no credits.
- **team key** (`lootsurvivor`, PAID) → all executions, so runs get the `medium`
  performance tier and draw on the 4000-credit pool. It can execute the personal queries
  because they are public. The personal free plan rejects an explicit performance tier
  (`Invalid performance tier`) — omit the field entirely if you ever run on it.

## Root causes, final status

| # | Root cause | Resolution |
|---|---|---|
| 1 | Game migrated V1 → V2 on 2026-05-04 | ✅ every query now unions V1 + V2 |
| 2 | 5 queries archived server-side | ✅ all 5 unarchived via the personal key |
| 3 | `dune.lowskillcoding` matviews dropped | ✅ consumers switched to query-as-view |

All five were genuinely `is_archived: true` (the earlier "private vs archived" caveat is
resolved — the personal key could read them and confirm). `POST /query/{id}/unarchive`
worked for all of them; the team key had returned 404 purely because it did not own them.

## Bugs found that had nothing to do with the ban or the migration

1. **Swapped action labels** (5996309) — `buy items` and `select stat upgrades` reversed.
   Confirmed via `starknet_keccak`. Mislabelled for the dashboard's entire life. Fixed.
2. **Dead USD anchor** (6125279) — the EKUBO/USDC pool went dry in early March 2026 and an
   INNER JOIN blanked **every USD figure from 2026-03-02**, two months before the cutover.
   Now anchored on any live stable/EKUBO pair with forward-fill. Fixed.
3. **LORDS priced at $21.42 instead of $0.0029** — a 2-second-apart oracle snapshot with a
   sign-flipped tick. A ~7000x error that fed the revenue and buyback counters. Fixed by
   raising the tick `dt` floor from 1s to 60s.
4. **Share-of-Starknet-txs undercounted ~2.4x even in V1** (6472962) — it matched a fixed
   calldata slot (`calldata[11]`/`[23]`), so a transaction only counted when the address
   happened to land in that exact position. Replaced with direct contract matching:
   46,097 vs 17,300 on the same V1 day, and 39,066 vs 1,639 on a V2 day.
5. **`beast_level` is really beast HEALTH** — V1's `data[9]` (11..1023, avg 259) matches
   V2's health slot, not V2's true level field (1..172). The V2 half deliberately uses the
   health-equivalent slot so leaderboard scores stay on the same scale as the V1 era.

## The subtle one worth remembering

The V2 game contract was upgraded **8 times** between April and July 2026 and the
`GameEvent` encoding changed mid-flight. A first rewrite that handled only the current
layout ran clean, returned plausible numbers, and **silently dropped all of May**
(7.16M events). It was caught only by explicitly checking for missing days. Deaths went
253,068 → **276,622** once May was recovered. Both layouts are documented in
`V2_EVENT_DECODE_REFERENCE.md`; always assert zero missing days after a change.

## ⚠️ Before you re-enable scheduled refreshes

~~Dune has no materialization API~~ — **CORRECTION, see the section below: there IS one.**
The four matviews have been recreated via the API and the consumers switched back.

**Scheduled refreshes bill the query owner — your personal FREE plan (2,500/month)**, not
the team's paid 4,000. A daily auto-refresh would be ~30,000/month and would fail.

Options, best first:
1. Re-enable **materialization** in the UI on 6011955 / 6004055 / 6013674 / 6014300, then
   point 5999525 and 6014186 back at `dune.lowskillcoding.result_*`. Biggest saving.
2. Refresh weekly rather than daily.
3. Move the queries to the `lootsurvivor` team so refreshes draw on the paid plan.

## Artifacts

- `migration_2026_07/final_sql/` — final SQL for all 26 queries + `manifest.json`
- `dune_query_backup_20260726/` — pre-migration SQL + version numbers (revert source)
- `migration_2026_07/v2_blocks.py` — reusable V2 CTE builders (both event layouts,
  dungeon attribution, denshokan owner mapping)
- `migration_2026_07/sn_keccak.py` — dependency-free `starknet_keccak`
- `V2_EVENT_DECODE_REFERENCE.md` — the decode contract

Scratch queries 8113124 and 8113496 were created during the work and have been archived.
Credits used: **1,151 / 4,000** on the team plan; personal plan untouched at 0.

---

# CORRECTION 2026-07-27 — materialized views ARE available via API

Earlier I concluded materialization was a UI-only toggle. **That was wrong.** I had probed
`/query/{id}/materialize`, `/materialization`, `/schedule` (all 404) and never tried the
separate endpoint family:

```
POST   https://api.dune.com/api/v1/materialized-views     # upsert
GET    https://api.dune.com/api/v1/materialized-views     # list
```

Body: `query_id`, `name` (must start with `result_`), `cron_expression` (5-field; min 15
minutes, max weekly), optional `is_private`, `expires_at`, `performance`.
Requires a **Read/Write** scope key.

**The key must be the one whose account should own the table.** The matview is created as
`dune.<key's account>.<name>`, so these had to be created with the **personal** key to land
in `dune.lowskillcoding.*` — the schema the consuming queries reference. Creating them with
the team key would have produced `dune.lootsurvivor.*` and matched nothing.

## What was done

All four recreated, refreshing **weekly, Mondays 06:00 UTC** (`0 6 * * 1` — the cheapest
cadence the API permits):

| materialized view | source query | size |
|---|---|---|
| `dune.lowskillcoding.result_ls_2_deaths` | 6011955 | 703 B |
| `dune.lowskillcoding.result_ls_2_top_200_beast_hunters` | 6004055 | 2,931 B |
| `dune.lowskillcoding.result_ls_2_top_200_beast_mode` | 6014300 | 5,713 B |
| `dune.lowskillcoding.result_ls_2_top_200_level_hunters` | 6013674 | 3,364 B |

Verified against the source queries before switching: 49 / 37 / 200 / 50 rows, ranks
topping out at 37 / 50 / 200, deaths summing to 276,633.

`6014186` and `5999525` were then switched from query-as-view back to the matviews:

| query | before | after |
|---|---|---|
| 6014186 LS2-deaths (range) | ~55 credits | **0.014** |
| 5999525 LS2-top200 players stats | ~61 credits | **31** (its own scan remains) |

Total storage 12.7 KB of the personal plan's 100 MB. Weekly refresh costs ~69 credits/week
(~276/month) against the personal plan's 2,500 — comfortable. Root cause 3 is now fully
resolved rather than worked around, and **no UI action is required**.

## Weekly buybacks (6359411) — sparse bars are correct, not a bug

The route is unchanged: SURVIVOR still moves Ekubo Core -> Survivor Controller. Buybacks
are *batch* operations that fire once enough LORDS revenue accumulates, and revenue is down
94% from the February peak, so they now fire once or twice a month instead of ~8x:

| month | LORDS revenue | buyback events | SURVIVOR bought |
|---|---|---|---|
| 2026-02 | 2,291,881 | 36 | 96,042 |
| 2026-03 | 1,298,020 | 23 | 51,927 |
| 2026-04 | 398,840 | 9 | 17,114 |
| 2026-05 | 193,219 | 9 | 27,546 |
| 2026-06 | 157,717 | 1 | 1,377 |
| 2026-07 | 130,686 | 2 | 7,568 |

Most weeks genuinely have zero buybacks. A **weekly** bucket is now the wrong resolution
for this metric — monthly, or a cumulative line, would show the trend instead of gaps.
Not changed, since it alters what the widget means.
