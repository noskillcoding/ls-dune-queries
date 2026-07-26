# Loot Survivor V2 — on-chain decode reference

Derived 2026-07-26 from the **deployed** contract ABI (`starknet_getClassAt` via
`https://rpc.starknet.lava.build`) and validated against live Dune data.
The GitHub `main` branch is **not** identical to what is deployed — trust this file.

## Contracts

| Role | Address |
|---|---|
| Game (V2) | `0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405` |
| Game Token (V2) | `0x04de0351ceab4ecd50be6ee09329b0dcb3b96a9da88cc158f453823a389722fa` |
| Beast Mode (V2) | `0x0539d24dfdaa2866d975fa93db501b971c08786f2c88e719800be39903e43bbc` |
| Greed dungeon | `0x046db77f066f1bec5ae53d2cf3686a262f308eb904e6b426251bcdf3a6bf34f0` |
| Lil Duckies dungeon | `0x04427c2cdd82bf2283deb39aa939e1ad61051ab932e0de714032fbe22ed0a419` |
| Yield dungeon | `0x0616042ee02abc8c73d7eb975d33ade3b53f8296005363d1ee56a1ccefd4f49f` |
| Denshokan (V2) | `0x00263cc540dac11334470a64759e03952ee2f84a290e99ba8cbc391245cd0bf9` |
| DTICKET | `0x0452810188c4cb3aebd63711a3b445755bc0d6c4f27b923fdd99b1a118858136` |

Cutover: V1 last real activity **2026-05-04**; V2 begins **2026-05-05**.

## ⚠️ There are TWO deployed V2 event layouts

The V2 game contract was upgraded repeatedly — **8 class-hash changes between 2026-04-07
and 2026-07-26** — and the `GameEvent` encoding changed mid-flight. Handling only the
current one silently drops **~4 weeks of May 2026 gameplay (7.16M events)**.

| | window | `cardinality(keys)` | adventurer_id | variant index | payload offset |
|---|---|---|---|---|---|
| **V2a** | 2026-04-15 → ~2026-06-11 | **1** | `data[1]` | `data[2]` | **+1** |
| **V2b** | ~2026-06-11 → now | **2** | `keys[2]` | `data[1]` | 0 |

So V2a's `adventurer_id` lives in `data`, not the keys, and every payload position shifts
by one. Normalise with an offset rather than branching everywhere:

```sql
CASE WHEN cardinality(keys) >= 2 THEN element_at(keys, 2) ELSE data[1] END AS adventurer_id,
CASE WHEN cardinality(keys) >= 2 THEN 0 ELSE 1 END AS off
-- then: variant = element_at(data, 1+off), health = 2+off, xp = 3+off, beast_health = 5+off
```

Validated V2a ranges (2026-05-18..24, variant 0): `health` ≤940, `xp` ≤2326,
`gold` ≤511, `beast_health` ≤1023, `stat_upgrades` ≤10 — matching V2b shifted by one.

Also note: the V2 contract emitted **1.34M events in April 2026**, before the public
cutover, while players were still on V1. That is dev/staging traffic — filter
`block_time >= TIMESTAMP '2026-05-05'` on the V2 half or you will double-count games.

## The GameEvent

Deployed ABI: `death_mountain::events::game_events::GameEvent`

```
#[key] adventurer_id : felt252     -> keys[2]   (V2b; see V2a above)
       details       : GameEventDetails   -> data[1..]
```

- `keys[1]` = `starknet_keccak("GameEvent")` =
  `0x03e037e958ba3b5c1cc99ac16aaf9896423eebd03183c41fbb26548a12336e5f`
- `keys[2]` = `adventurer_id`, a **felt252** (large packed value — do NOT assume a small u64)
- `cardinality(keys) = 2`
- **`data[1]` = the GameEventDetails variant index.** Filter on this, *not* on
  `cardinality(data)` — several variants share a length.

There is **no `action_count`** field in the deployed event (V1 had one). To pick a
game's final state, order by `block_number DESC, event_index DESC`.

### GameEventDetails variant index (deployed = 20 variants; `main` shows only 17)

| idx | variant | idx | variant |
|---|---|---|---|
| 0 | adventurer | 10 | drop |
| 1 | bag | 11 | level_up |
| 2 | beast | 12 | market_items |
| 3 | discovery | 13 | ambush |
| 4 | obstacle | 14 | attack |
| 5 | defeated_beast | 15 | beast_attack |
| 6 | fled_beast | 16 | flee |
| 7 | stat_upgrade | 17 | **randomness** |
| 8 | buy_items | 18 | **collectable** |
| 9 | equip | 19 | **collectable_stats** |

Variants 17–19 do not exist in the `main` branch — they are deployed-only.

### Variant 0 (`adventurer`) — 32 fields, fully validated

| pos | field | observed range | note |
|---|---|---|---|
| 1 | variant index | 0 | always 0 for this variant |
| 2 | `health` | 0–1015 | **`= 0` means death** (1.4% of rows) |
| 3 | `xp` | 0–2211 | `level = floor(sqrt(xp))` |
| 4 | `gold` | 0–511 | gold is capped at 511 |
| 5 | `beast_health` | 0–1023 | 76% zero = not in combat |
| 6 | `stat_upgrades_available` | 0–10 | |
| 7–13 | `stats` | str≤36 dex≤40 vit≤61 int≤19 wis≤20 cha≤26 luck≤136 | 7×u8 |
| 14–29 | `equipment` | 8 × (`item_id`, `item_xp`) | see slot ranges below |
| 30 | `item_specials_salt` | 0–16379 | u16 |
| 31 | `beast_salt` | 0–131069 | u32 |
| 32 | `level_salt` | 0–16383 | u16 |

Equipment slot order is `weapon, chest, head, waist, foot, hand, neck, ring`.
Observed max item_id per slot — a strong correctness signal that the offsets are right:
weapon ≤76, chest ≤81, head ≤86, waist ≤91, foot ≤96, hand ≤101, neck ≤3, ring ≤8.
`item_xp` ≤ 400 in every slot.

Other useful shapes: `Stats` = 7×u8; `Equipment` = 8×`Item`; `Bag` = 15×`Item` + `mutated: bool`.

## Entry point selectors (`starknet_keccak(fn_name)`)

Unchanged V1 → V2: `explore`, `attack`, `flee`, `equip`, `start_game`,
`buy_items`, `select_stat_upgrades`.

| function | selector | status |
|---|---|---|
| `explore` | `0x01f64d317ff277789ba74de95db50418ab0fa47c09241400b7379b50d6334c3a` | same |
| `attack` | `0x02d1af4265f4530c75b41282ed3b71617d3d435e96fe13b08848482173692f4f` | same |
| `flee` | `0x011a7c59c924cc874e20358db055478acbf359f83bbe68547e90cb94dae65a5c` | same |
| `equip` | `0x027f806b163e00b12dc7f2e54f3865ceba98cadef57cc65c6e10f64195ccd015` | same |
| `start_game` | `0x02214fe6a6e2545aebfe589b84884a2c528416482abec76605b7fdb1c31ce5b2` | same |
| `buy_items` | `0x021d241887a9e02da42301e9b400c220b595d67b103cec7112a7fdc44f4e12a5` | same |
| `select_stat_upgrades` | `0x02467ebac97effcc7cd81bb8e877a27039732a954c40231131e63a779b13d8cc` | same |
| `drop_items` | `0x0301787479143648c7731d011d462aa4684a81ef8a6645023116871b4c0c1f13` | **renamed** from `drop` |
| `surrender` | `0x007647db234d6e5c5db278611b6fd444f721d91d516ebe86a63f5bb9c183f0eb` | **new** |
| `buy_external_item` | `0x037768b9c251204d0e21d58deab72eefc602032f036dc4a646900e49cacd9f4c` | **new** |
| `set_dungeon_id` | `0x002ca574f72c6ec03bd054a37ac0b190261b92a5a4a707806befa212a971d63c` | **new** |

V1's `drop` (`0x03297c61…`) no longer exists — V2 uses `drop_items`.

> ### ⚠️ Pre-existing bug found in the V1 dashboard
> In `query_01_contract_activity_analysis.sql` (Dune query **5996309**, "LS2-daily",
> powering *"Popularity of each action"* and *"Game actions over time"*), the labels for
> **`buy items`** and **`select stat upgrades`** are **swapped**:
> - `0x02467eba…` is really `select_stat_upgrades`, but is labelled `'buy items'`
> - `0x021d2418…` is really `buy_items`, but is labelled `'select stat upgrades'`
>
> Verified by computing `starknet_keccak` for both names (the other 6 selectors in that
> query check out exactly). This has been mislabelling those two series for the whole
> life of the dashboard and should be fixed during the migration.

## V1 (for the union / historical half)

V1 read Dojo world events from **pgWorld** `0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a`:
- `keys[1] = 0x01c93f6e…` = `starknet_keccak("EventEmitted")`
- `keys[1] = 0x01a2f334…` = `starknet_keccak("StoreSetRecord")`
- `keys[2]` = Dojo **model selector**; game state carried `cardinality(data) = 35`,
  settings `cardinality(data) = 14`
- V1 field offsets used by the old queries: `data[2]`=game_id, `data[4]`=action_count,
  `data[5]`=health, `data[7]`=xp; settings event `data[2]`=game_id, `data[6]`=settings_id

That stream is dead after 2026-05-04 (0 rows in June).

## Tooling

- `scratchpad/dune.py` — Dune API client (meta / patch / run / run_sql)
- `scratchpad/sn_keccak.py` — dependency-free Keccak-256 + `starknet_keccak`,
  self-tested and validated against 6 known V1 selectors
