"""Reusable SQL fragments for the Loot Survivor V1->V2 dashboard migration."""

GAME2 = "0x023f86f5b4702f6ba114b82fb73448c58aad8f37a28b508b80bf129ee1edc405"
GAME1 = "0x06f7c4350d6d5ee926b3ac4fa0c9c351055456e75c92227468d84232fc493a9c"
PGWORLD = "0x02ef591697f0fd9adc0ba9dbe0ca04dabad80cf95f08ba02e435d9cb6698a28a"
GAMEEVENT = "0x03e037e958ba3b5c1cc99ac16aaf9896423eebd03183c41fbb26548a12336e5f"
EVENTEMITTED = "0x01c93f6e4703ae90f75338f29bffbe9c1662200cee981f49afeec26e892debcd"
START_GAME = "0x02214fe6a6e2545aebfe589b84884a2c528416482abec76605b7fdb1c31ce5b2"

DUNGEONS = [
    ("0x0539d24dfdaa2866d975fa93db501b971c08786f2c88e719800be39903e43bbc", "Beast Mode"),
    ("0x046db77f066f1bec5ae53d2cf3686a262f308eb904e6b426251bcdf3a6bf34f0", "Greed"),
    ("0x04427c2cdd82bf2283deb39aa939e1ad61051ab932e0de714032fbe22ed0a419", "Lil Duckies"),
    ("0x0616042ee02abc8c73d7eb975d33ade3b53f8296005363d1ee56a1ccefd4f49f", "Yield"),
    # Seen on-chain driving start_game but not (yet) listed in the docs.
    ("0x065406785f89adb4c9f9b22d08358951ca78b2f952d7e5d0eab9e643872e9c8a", "Dungeon 0x0654"),
    ("0x012ac35cf5112dd1bacd2f1e7342eb5951566262ab52c3c7dddd2b9a77840741", "Dungeon 0x012a"),
]


V2_START = "TIMESTAMP '2026-05-05'"  # public cutover; V2 activity before this is dev/staging


def v2_events_cte(name="v2_ev"):
    """Base CTE over V2 GameEvent rows, handling BOTH deployed event layouts.

    The V2 game contract was upgraded repeatedly (8 class-hash changes Apr-Jul 2026) and
    the GameEvent shape changed mid-flight:

      V2a (2026-04-15 .. ~2026-06-11): cardinality(keys)=1. adventurer_id is data[1] and
          the GameEventDetails variant index is data[2] -- every payload position is
          shifted by +1.
      V2b (~2026-06-11 onward):        cardinality(keys)=2. keys[2]=adventurer_id and the
          variant index is data[1].

    Missing V2a cost a full ~4 weeks of May gameplay (7.16M events) when only V2b was
    handled, so both are normalised here via an `off`set.

    Validated field ranges (V2b positions; add `off` for V2a): health<=1015,
    xp<=2326, gold<=511 (the in-game gold cap), beast_health<=1023.
    """
    return f"""{name}_raw AS (
  SELECT
    CASE WHEN cardinality(keys) >= 2 THEN element_at(keys, 2) ELSE data[1] END AS adventurer_id,
    CASE WHEN cardinality(keys) >= 2 THEN 0 ELSE 1 END AS off,
    data, block_number, event_index, block_time, transaction_hash, block_date
  FROM starknet.events
  WHERE from_address = {GAME2}
    AND keys[1] = {GAMEEVENT}
    AND cardinality(data) >= 2
    AND block_time >= {V2_START}
),

{name} AS (
  SELECT
    adventurer_id, block_number, event_index, block_time, transaction_hash, block_date,
    bytearray_to_uint256(element_at(data, 1 + off)) AS variant,
    bytearray_to_uint256(element_at(data, 2 + off)) AS health,
    bytearray_to_uint256(element_at(data, 3 + off)) AS xp,
    bytearray_to_uint256(element_at(data, 4 + off)) AS gold,
    bytearray_to_uint256(element_at(data, 5 + off)) AS beast_health,
    -- variant 2 (`beast`) reuses the same slots: 2=beast_id, 3=beast "level" (really the
    -- beast's health, matching V1's data[9]), 4=true beast level
    bytearray_to_uint256(element_at(data, 2 + off)) AS beast_id,
    bytearray_to_uint256(element_at(data, 3 + off)) AS beast_stat
  FROM {name}_raw
)"""


def v2_dungeon_map_cte(ev="v2_ev"):
    """adventurer_id -> dungeon name, via start_game/dungeon co-occurrence in one tx.

    V2 dropped the settings_id field that V1 carried in its 14-field settings event, so
    the dungeon a game belongs to is recovered by transaction correlation instead.
    """
    whens = "\n".join(
        f"           WHEN {addr} THEN '{label}'" for addr, label in DUNGEONS
    )
    inlist = ",\n        ".join(addr for addr, _ in DUNGEONS)
    return f"""v2_dungeon_tx AS (
  SELECT DISTINCT
    sg.transaction_hash,
    sg.block_date,
    CASE dg.contract_address
{whens}
    END AS dungeon
  FROM starknet.calls sg
  JOIN starknet.calls dg
    ON dg.transaction_hash = sg.transaction_hash
   AND dg.block_date = sg.block_date
  WHERE sg.contract_address = {GAME2}
    AND sg.entry_point_selector = {START_GAME}
    AND dg.contract_address IN (
        {inlist}
      )
),

v2_game_dungeon AS (
  -- one dungeon per adventurer; min() breaks the tie if a tx touched more than one
  SELECT e.adventurer_id, MIN(t.dungeon) AS dungeon
  FROM {ev} e
  JOIN v2_dungeon_tx t
    ON t.transaction_hash = e.transaction_hash
   AND t.block_date = e.block_date
  GROUP BY 1
)"""


def v2_final_deaths_cte(ev="v2_ev", name="v2_death_events"):
    """Final death state per V2 game: variant 0 (adventurer) with health = 0.

    V2 has no action_count field, so the latest state is taken by block_number/event_index.
    """
    return f"""{name} AS (
  SELECT
    adventurer_id, block_time, xp, beast_health,
    ROW_NUMBER() OVER (
      PARTITION BY adventurer_id ORDER BY block_number DESC, event_index DESC
    ) AS rn
  FROM {ev}
  WHERE variant = 0    -- adventurer state
    AND health = 0     -- death
)"""


DENSHOKAN2 = "0x00263cc540dac11334470a64759e03952ee2f84a290e99ba8cbc391245cd0bf9"
DENSHOKAN1 = "0x036017e69d21d6d8c13e266eabb73ef1f1d02722d86bdcabe5f168f8e549d3cd"
TRANSFER = "0x0099cd8bde557814842a3121e8ddfd433a539b8c9f14bf31ebf108d12e6196e9"
ZERO = "0x0000000000000000000000000000000000000000000000000000000000000000"


def v2_game_owners_cte(name="v2_game_owners", since=None):
    """adventurer_id -> player_address, from denshokan V2 mints.

    V2's denshokan emits an ERC721 Transfer whose token_id is a **u256 split across
    keys[4] (low 128 bits) and keys[5] (high 128 bits)**. Recombining them as bytes
    reproduces the GameEvent `adventurer_id` exactly -- verified at 21,633 / 21,785
    (99.3%) for 2026-06-15 onward. Do NOT use bytearray_to_uint256(keys[4]) as V1 did;
    that is only the low half and matches nothing.
    """
    tf = f"    AND block_time >= {since}\n" if since else ""
    return f"""{name} AS (
  SELECT DISTINCT
    bytearray_concat(
      bytearray_substring(keys[5], 17, 16),
      bytearray_substring(keys[4], 17, 16)
    ) AS adventurer_id,
    CAST(keys[3] AS VARBINARY) AS player_address
  FROM starknet.events
  WHERE from_address = {DENSHOKAN2}
    AND keys[1] = {TRANSFER}
    AND keys[2] = {ZERO}
    AND cardinality(keys) >= 5
{tf})"""


def v1_game_owners_cte(name="v1_game_owners", since="TIMESTAMP '2025-09-15'"):
    return f"""{name} AS (
  SELECT DISTINCT
    bytearray_to_uint256(keys[4]) AS game_id,
    CAST(keys[3] AS VARBINARY) AS player_address
  FROM starknet.events
  WHERE from_address = {DENSHOKAN1}
    AND keys[1] = {TRANSFER}
    AND keys[2] = {ZERO}
    AND cardinality(keys) >= 4
    AND block_time >= {since}
)"""
