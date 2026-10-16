# Upgrade contract

Release mode starts with 0.41.0 (Round 41, the user's ruling 9 of
2026-10-07; [round 41 plan](../planning/round41-plan.md) §2.9–§2.10). The
hosting platform runs Grudgelands worlds (map, players and auth in
PostgreSQL, mod storage in SQLite) and is built against this contract (the
platform's task files `~/projects/kaesual-stack/.local/grudgelands-upgrade-contract-task.md`
and, since Round 43, `grudgelands-migration-contract-task.md` revision 2 in
the same folder; not in this repository; the pre-reset pass of §3.5 was
agreed on 2026-10-16, [round 50 plan](../planning/round50-plan.md) §2
"Platform agreement"). This file owns the game's side of it. The working rules are in [AGENTS.md "Release mode"](../../AGENTS.md#release-mode).

## 1. Four outcomes

An upgrade of a world to a newer Grudgelands version is exactly one of:

- **compatible:** nothing to do; the new code boots the world and reads every
  saved state. A best-effort intent, also for worlds in full-preparation mode:
  no saved test worlds prove it.
- **map reset:** the platform stops the server, runs the pre-reset pass of
  the target's tool (§3.5; for a target at or above the declaration's
  `map_reset_pass`), empties the map table, raises the setting
  `grug_reset_world` and starts the server; the game does the rest (§3).
  The seed and `map_meta.txt` survive.
- **migrate** (since Round 43): with the server stopped and the world backed
  up, the target version's migration tool converts the world offline, and the
  game finishes a step's online work at the next load and at each affected
  character's next join (§5).
- **new server:** the platform refuses the in-place upgrade.

Upgrades only go forward. **New server** wins over everything. **Map reset**
and **migrate** combine. **The tool runs first** (since 0.50.0, the
declaration's `map_reset_pass`): before every emptying of the map one tool
run `--world <dir> --map-reset` packs the claims' containers from the old
map (the pre-reset pass, §3.5) and then runs the due steps; only after its
exit 0, with the `done` line carrying `"map_reset": true`, does the
platform empty the map and raise `grug_reset_world`. A step never reads the
map and never relies on map-bound mod storage (§3.2), which the game clears
only at the next load. For a target below `map_reset_pass` the old order
stays: the platform empties the map first, then runs the tool without
`--map-reset`.

What a change needs:

| Change | Outcome |
|---|---|
| Nothing saved changes meaning | compatible |
| World generation, or map-bound state (§3.2) the new code cannot read | map reset |
| A removed item: a step replaces or removes it in inventories, offline characters included (a step never reads the map: items in node inventories on the map stay, and at a map reset the pre-reset pass packs those in claims, whose unregistered items the game drops at the next load, §3.5), and in the mail (since 0.48.0: the item strings of letter attachments in `grug_mail`'s mod storage, keys `box:<name>`, and the player list `grug_mail_out`); the first, 0.44.0, removes the mount items and every skill outside the hotbar (§5.8) | migrate |
| Restructured character state (quests and their objectives, prerequisites or order, talents, saved formats): a step converts it, offline or as online work at the character's next join | migrate |
| Saved character or world state the new code cannot read that is not map-bound, when the round decides not to migrate it | new server |
| A change to a validated world-creation scalar (`game.conf`'s mapgen pins, `r7_runtime.lua` `validate_live_scalars`) | new server |
| A change to a validated world-creation scalar the game forces over `map_meta.txt` itself (`core.set_mapgen_setting*` with `override_meta`, `r7_native.lua` `apply_and_validate_main`: the six v7 terrain and climate noise params and, since Round 49, `mgv7_spflags`) | map reset |

**Data migrations only through the tool, with a test:** a change to state
that is not map-bound and that the new code cannot read is converted by a
declared step (§5) whose test runs the step end to end, or declared a new
server; never converted at load by code
scattered over the mods (`tools/check_fresh_server.py` guards the retired
mechanisms and keeps the markers in grug_core's runner). Ids of quests,
items, achievements and waypoints stay stable; a renamed item may keep its
old name with `register_alias` (`tools/check_fresh_server.py` allows it).
Mapgen parameters a version needs keep being set by the game itself.

Every lane states its change's outcome in its report and the reviewer checks
it ([round workflow §3](../process/round-workflow.md#3-gates)); the round's
declaration follows from them.

## 2. The declaration

`tools/web_data/upgrade.json`, exactly this shape (schema 3 since Round 50,
which added `map_reset_pass`; schema 2 since Round 43 added the `migrate`
list of the platform's migration contract):

```json
{"schema": 3, "version": "0.50.0", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0"], "map_reset_pass": "0.50.0"}
```

- `version` equals `game.conf`'s `version`. Versions are
  `major.minor.patch`, compared numerically per component, and never
  decrease.
- Each list holds, strictly ascending, the versions that need that outcome
  when a world crosses them: a move from `a` to `b` crosses every entry `v`
  with `a < v <= b`. Entries are never edited or removed, every entry is at
  most `version`, and a new entry comes only together with a version bump.
- Each `migrate` entry `v` has exactly one step, which migrates a world of
  the previous version to `v` (§5.2). A pushed step is never changed; a fix
  is a later, new step.
- `map_reset_pass` is the first version whose tool runs the pre-reset pass
  (`--map-reset`, §3.5): 0.50.0, at most `version`, never edited once
  pushed. The platform reads it from the target's (its built-in pin's)
  declaration and runs the pass before every emptying of the map when the
  target is at or above it.
- `tools/check_upgrade.py` checks these rules against the last pushed commit
  (`origin/main`; `--base REF` for another) and runs its own self-test of the
  rules first (also alone: `--self-test`). A missing earlier declaration is
  accepted once; a pushed schema-1 declaration counts as one without
  `migrate` entries, a pushed schema-1 or schema-2 one as one without
  `map_reset_pass`. It also proves the game's step registry
  (`grug_core.migrations` `versions`, which the start guard reads) equal to
  `migrate`, and that each `migrate` entry's step file
  `tools/migration/steps/vX_Y_Z.py` exists and, once pushed, is unchanged.
  It runs at every round end.
- The first declaration (0.41.0) covers the one migration that is due: the
  user's production server moves from 0.40.0 to 0.41.0 with a map reset
  (it crosses 0.40.1, which changed world generation; Round 41's own mapgen
  fix is covered by the same reset). No history before 0.40.0 is audited.
- 0.43.0 ships the migration foundation alone, with an empty `migrate` list
  (Round 43 ruling 2); 0.44.0 declares the first real step, 0.45.0 the
  second (§5.8). The
  platform adopts a version with a real step only once its runner is in
  production (Round 44 ruling 3).
- 0.46.0 (Round 46) declares the second map reset: seed-dependent POI
  placement and the new ore, gem and coal table change world generation.
  It declares no step; the production world is not moved now but later in
  one combined update ([round 46 plan](../planning/round46-plan.md#5-rules)).
- 0.47.0 (Round 47) needs the third map reset (world generation changes
  again) and the third step, 0.47.0 (§5.8): the pick level scale moved, and
  the copies of tool capabilities that crafted and broken tools keep in
  item meta are rebuilt at each character's next join. The production
  server moves from 0.45.1 to 0.47.0 in one step, crossing both.
- 0.48.0 (Round 48) needs the fourth map reset (the mailboxes are placed
  by world generation) and the fourth step, 0.48.0 (§5.8): every bag holds
  half as much, so at each character's next join the inventory is sorted
  into the new sizes and what no longer fits is mailed.
- 0.50.0 (Round 50) moves to schema 3 with `"map_reset_pass": "0.50.0"`:
  its tool packs the claims' containers before a map reset (§3.5). It is
  compatible and declares no step; the production world moves from 0.48.1
  to 0.50.0 across 0.49.0's map reset, and that reset packs its claims.
- **History:** released commits stay reachable on `origin/main`; its history
  is never rewritten. The platform fetches older released commits to create
  test realms and to restore backups, and builds its tool runner from the
  target commit.

## 3. The map reset

### 3.1 Setting and records

- `grug_reset_world` (`settingtypes.txt`, int, default 0, min 0, marked
  platform-owned; nobody else changes it).
- **World record:** `grug_core`'s mod storage, key `reset_world`.
  **Character record:** player meta `grug_core:reset_world`. A missing record
  is 0.
- A setting strictly above the world record triggers the world part at that
  start. The world's applied value is then the setting, else the record.
- A character whose record is below the world's applied value is relocated
  at its next join.
- Code: `grug_core/map_reset.lua` (`grug_core.map_reset`).

### 3.2 Map-bound state

Each mod clears its own map-bound mod-storage state during its own load,
through `grug_core.map_reset.clear(owner, fn)`, before it reads that state.
Clears are idempotent (a start that stops before the record is written runs
them again), keep monotonic counters and the world's preparation mode; a
clear that raises stops the load with an error naming it. The world record is
written in `register_on_mods_loaded`, after every clear.

| Mod storage | Map-bound, cleared | Kept |
|---|---|---|
| `grug_core` `world_preparation` (`starts_preload.lua`) | the plan and its progress: total, cursor, order, geometry, reach, authority digest, selection | `mode` (starts or full): the selected plan starts again |
| `grug_mobs` (`map_reset.lua`) | every record of the world's authored actors: `startnpc:` and `startnpcdue:` (settlement NPC markers and respawn times), `rare_alive:` and `rare_next:`, `boss:dragon:<id>:alive/due/warned`, `leader_next:`, `rift_crack:` and `rift_boss_due:`, `live_pos:` and `live_absent:` | `live_gen:<key>`, the liveness generations (monotonic: a copy of an older generation never returns) |
| `grug_housing` (`registry.lua` `map_reset`) | every `claim:<id>`; a `player:<name>` whose stone stood becomes `needs_stone` | `next_id` (monotonic), every other player record (a carried stone stays carried), the pre-reset pass's `recovered:<player>:<seq>:<n>` and `pack_seq` (§3.5) |
| `grug_core` `map_reset_pack:<seq>` (§3.5) | — | the pass's marker until the game's handler has run at the next load |
| `grug_core` `reset_world` | — | the world record itself |
| `grug_home` `claim_lost:<name>` | — | pending notices of a past pick-up or destruction |
| `grug_parties` `parties`, `grug_repair` `item_serial` | — | not map-bound; the serial is a monotonic counter |
| `grug_mail` (Round 48): `box:<name>`, `tickets`, `broadcasts`, `factions`, `next_id` | — | not map-bound: letters, attachments, tickets and announcements survive a map reset; `next_id` is a monotonic counter |

The world-folder caches (world layouts, region maps, the world-map tiles and
zone grid) derive from the seed and the code and stay valid. The settlement
NPCs, rares, dragons, leaders and the rift return as on a fresh world.

| Player meta | Map-bound |
|---|---|
| the position (engine) | moved to the race start (§3.3) |
| `grug_home:claim` (the Claim Stone as travel home) | cleared at the relocation (`register_on_relocate`); the travel home falls back to the innkeeper. The Claim Stone does not come back: the Housing Steward hands out a new one, as after losing it ([housing](../design/housing.md) §3) |
| `grug_pvp:loc` | not cleared: sampled again from the new position after the release |

Nothing else about a character changes: level, XP, money, inventory,
equipment, talents, quests, achievements, professions, mounts, discovered
waypoints, parties, the bound innkeeper (a stable id).

### 3.3 The player part

- On join, a created character (`grug_classes:race` stored) whose record is
  below the world's is held by character creation's own hold
  (`grug_classes/selection.lua`: frozen, immortal, the waiting screen) and
  moved at once to the waiting point (0, 31000, 0), where the engine
  generates no map ([world preparation](../design/world_preparation.md#the-waiting-point)).
  Its old position is not kept: a disconnect there leaves the record
  unwritten, and the next join comes back to the same wait.
- Once the preparation is ready and its race start has loaded
  (`grug_factions.prepare_spawn`), it is moved there without the arrival
  flow or the welcome, its map-bound player state is cleared
  (`grug_core.map_reset.register_on_relocate`) and only then its record is
  written (`grug_core.map_reset.relocated`).
- A failed load is logged at error level, leaves the record unwritten and
  disconnects the player with a short message; the next join tries again.
- **New characters:** `on_newplayer`, and a join without a stored
  `grug_classes:race`, record the world's applied value and need no
  relocation; they wait at the waiting point like every unfinished character
  and arrive at their race start. The creation stasis
  (`grug_core.player_in_creation_stasis`) decides nothing.
  A created character that had not arrived yet takes the arrival teleport to
  its race start, which writes the record too.

### 3.4 Adding map-bound state

New state that describes the map (a position, a placed node or entity, a
generated feature) gets its clear in the same change: a
`grug_core.map_reset.clear` call in the owner's load for mod storage, a
`grug_core.map_reset.register_on_relocate` callback for player meta. The
fixture is `tools/r41_up/portable_test.lua`.

### 3.5 The pre-reset pass

Round 50 rulings 4, 5, 8 and 9 ([round 50 plan](../planning/round50-plan.md)
§2 and §3): at every map reset from 0.50.0 on, the containers in the
housing claims come back to their owners. The migration tool packs them
from the old map while the server is stopped; the game hands them out
after the reset (the Claim Stone, [housing](../design/housing.md)).

- **When:** before every emptying of the map of a world whose target is at
  or above `map_reset_pass` (§2): a version move that crosses a `map_reset`
  entry, one that crosses `migrate` entries as well, and the operator's
  manual "Reset the map" of a world already at the target.
- **The order on the stopped realm:** the automatic backup; the target's
  tool `--world <dir> --map-reset` (the pass, then the due steps, in one
  run); after exit 0 with the `done` line's `"map_reset": true`, the map is
  emptied; `server.conf` with the raised `grug_reset_world`; the
  acknowledgement. Exit 2 (refused before any write) leaves the realm
  stopped with its old map; exit 1, or any failure after the pass began,
  needs the backup restored in place. The map is never emptied after a
  failure, and nothing repeats automatically.
- **What it reads:** every claim record (`grug_housing` mod storage
  `claim:<id>`, `v2|owner|x|y|z|…|paid_until|…`, drafts and claims without
  fuel included; a record that does not decode is skipped, as the game's
  load drops it), and in each claim's area (x ± 50, z ± 50, from y = −100
  upward) the map blocks that exist, nothing else. Every node whose metadata
  inventory holds an item is packed, whoever placed it; a node whose lists
  are all empty is not. A personal workspace record (node meta
  `grug_jobs:workspace:<name>`) that holds items is packed as a chest
  holding its stacks.
- **What it writes,** only `grug_housing` and `grug_core` mod storage rows,
  only new keys, in one transaction, never a player, auth or map row:
  - `recovered:<owner>:<seq>:<n>`, one item string each: a
    `grug_housing:packed_container` with item meta `node` (the node name as
    stored, so a lit furnace is `default:furnace_active`), `lists` (a
    `core.serialize`d table of list name → one item string per slot, `""`
    for an empty one, each exactly as the map stores it) and `seq`; or
    charcoal (`grug_smelting:charcoal`, stacks of at most 99): the claim's
    remaining paid time (`paid_until` minus the pass's wall-clock time)
    divided by `LUMP_SECONDS`, rounded up. `n` counts from 1 per owner and
    pass: containers in claim id and position order, then the charcoal;
  - `pack_seq`, the pass number (`seq`), one above the last;
  - `grug_core` `map_reset_pack:<seq>`, the marker the game's next load
    handles (it drops items the running version does not register, keeps
    stacks a smaller list cannot hold, writes the descriptions, then
    deletes the marker; safe to run again, §5.6).
  Every entry is proved to read back to exactly what was packed before the
  transaction begins; inside it, every `recovered:` key is checked to be
  new, every written key to read back and the row count to grow by exactly
  the new keys.
- **Later passes append:** earlier entries stay until their items are
  taken; the pass number grows. A pass on a restored backup writes the same
  rows (only the charcoal follows the clock).
- **Refused before any write** (exit 2): a world below 0.48.1
  (`pack_baseline`, Round 50 ruling 9; a world without a record counts as
  0.41.0); a pending `map_reset_pack:` marker (`pack_pending`: an earlier
  pass the game never loaded, so its map may already be gone and a second
  pass would hand out its charcoal twice; restore the backup taken before
  it); a block in a claim that does not decode (`map_block`); claims but
  not one block in the map (`map_empty`: the map was emptied first).
- **Map block format:** 29 only, the one format every engine since 5.5.0
  writes (zstd, reference_projects/luanti commit d1624a552 of 2021-08-31;
  `src/serialization.h` `SER_FMT_VER_HIGHEST_WRITE`, every save in
  `servermap.cpp` `saveBlock`). A 0.48.1 world's map was generated after
  the 0.48.0 map reset by the engine the game needs, so it holds no other
  format; another one is refused (`map_block`), never skipped.
- **Not packed:** dropped items and other objects, nodes outside the claims,
  and what plan D7 leaves out (a furnace's burning, a locked chest's former
  owner, a node's facing).
- **Code and tests:** `tools/migration/mapblock.py` (the map, read-only, and
  the decoder, with the engine lines it follows), `pack.py` (the pass);
  `tools/r50_ptool/run.sh` (§5.7).

## 4. Unknown ids in saved state

Unknown quest ids, item names, achievement ids and waypoint ids in saved
state never crash; they are ignored or dropped:

- quests: `grug_quests/state.lua` drops an unregistered id from the active
  and tracked lists when it decodes a state; `completed` and `cooldowns` are
  only looked up by id;
- waypoints: the discovered set is only consulted for registered stones and
  the next write keeps registered ids only (`waypoints_core.lua`);
- achievements: tiers and counters are read per catalogue row, unknown cloaks
  are ignored and an unknown selected cloak reads as No cloak
  (`grug_achievements/core.lua`);
- items: the engine keeps an unknown item as an unknown-item stack; every
  lookup of a held stack's definition in our code is nil-guarded (audited in
  Round 41).

## 5. Migrations

Round 43 built the mechanism ([round 43 plan](../planning/round43-plan.md),
completion with the platform summary); 0.43.0 declared no step, 0.44.0 the
first (§5.8). The
tool's interface in full (every event and its fields, every refusal and
failure reason) is owned by
[tools/README.md "The migration tool"](../../tools/README.md#the-migration-tool);
hosts follow the README's
[hosting steps](../../README.md#play-with-luanti).

### 5.1 The tool

- `python3 tools/migrate.py --world <dir>` migrates a **stopped** world to
  the checkout's `game.conf` version: every due step in ascending order.
  `--check` reports the world's version and the due steps and changes
  nothing; it proves write access with a real write on every backend, rolled
  back (SQLite under `BEGIN IMMEDIATE`, PostgreSQL waiting at most 5 s for a
  lock). `--map-reset` runs the pre-reset pass (§3.5) first and then the due
  steps, in one run; a world at the target with nothing due still packs and
  exits 0 (`"applied": []`). `--check --map-reset` also selects one map
  block and decodes it, which proves zstd importable, besides the
  rolled-back write on mod storage, where the pass writes. The tool cannot
  detect a running server: stopping it is the caller's duty.
- It runs from the repository root of a full export of the commit (every
  tracked file except `reference_projects/`), on Python 3.13 or newer with
  the standard library; `psycopg` 3 only for a PostgreSQL world, and zstd
  for the map blocks of the pre-reset pass (Python 3.14's
  `compression.zstd`, else `zstandard`), both imported lazily
  (`tools/migration/requirements.txt` for self-hosters; the platform uses
  Debian trixie's packages, `python3-psycopg` and `python3-zstandard`).
- The world comes from `world.mt` only: `player_backend`, `auth_backend`,
  `mod_storage_backend`, each `sqlite3` or `postgresql`, and the matching
  `pgsql_*_connection` strings handed to libpq (a password may come from
  `PGPASSFILE`). Anything else (files, leveldb, a missing key) is refused.
  The map, read only by the pre-reset pass: `backend` (`sqlite3`, also
  when the key is missing, as in the engine, or `postgresql`) and
  `pgsql_connection`; `map.sqlite` is opened read-only, PostgreSQL in a
  read-only session, and the tool reads `blocks` by position ranges per
  claim; it never writes, deletes or alters a map row. Emptying the map is
  the platform's job.
  The engine's table layouts are checked; the tool never writes `world.mt`,
  never creates, alters or drops a table, and never creates a database file.
  A missing `players.sqlite` or `auth.sqlite` (nobody ever joined) counts as
  empty; a missing `mod_storage.sqlite` is refused.
- **Exit codes:** `0` migrated, nothing to do, or checked; `2` refused before
  anything was written (a newer world, an unsupported backend or layout, an
  invalid `world.mt`, a failed connection, a lock not acquired); `1` failed
  once the first step had begun: the world is undefined, restore the backup.
- **Output:** one JSON object per line on stdout (`start`, with
  `--map-reset` `pack_start` and `pack_done` with the counts `claims`,
  `players`, `containers`, `items`, `charcoal` and `blocks_read`, then
  `step_start`, `step_done` with counts, `done` (with `--map-reset` also
  `"map_reset": true`, and `backends` names `map`), or `refusal` with its
  reason at exit 2, `failed` at exit 1), the same as text on stderr. The
  platform counts a pass as done only on exit 0 with that `done` line.

### 5.2 Steps and the data API

- A step is `tools/migration/steps/v<major>_<minor>_<patch>.py` exporting
  `migrate(world)`; the tool takes the steps from the declaration's
  `migrate` list. Each step runs in one transaction per backend, committed
  after the step (player, auth, then mod storage carrying the world version)
  or all rolled back when it raises.
- The data API (`tools/migration/data.py`): every character, offline ones
  included; its player meta, inventory (lists, sizes, items with count, wear
  and meta) and position; auth entries and their privileges (writes:
  privileges only); mod storage per mod (read, write, delete); the markers
  (§5.6); the raw SQLite or PostgreSQL connection of a backend as the escape
  hatch. Codecs (`tools/migration/codec.py`): `core.serialize` /
  `core.deserialize` (references and cycles read), `core.write_json` /
  `core.parse_json`, item strings, each verified against the engine's code.
- **Limits:** a step never creates, renames or deletes a character or an
  auth entry and never changes a table layout; the tool checks this after the
  step, also for raw-connection writes, and rolls back (exit 1). The world
  version is the tool's own key. A step never reads the map (Round 50
  platform agreement); map blocks are read only by the pre-reset pass
  (§3.5), before the steps and outside their reach.
- **The baseline rule:** a step relies only on the state the previous
  `migrate` step or map reset left, plus what the versions in between write
  without a load. Never on data a compatible version writes lazily at a
  load (a world can jump from 0.42 to 0.45 without loading under 0.43), and
  never on an earlier step's online work having finished (a character who
  has not joined since still carries that step's marker).
- A step that needs the game's Lua or native code at offline time is
  reported to the platform before it is built; online work (§5.6) is the
  usual way to reuse game Lua.

### 5.3 The world version record

- `grug_core`'s mod storage, key `world_version`, a `major.minor.patch`
  string. A missing record on an existing world is **0.41.0**, the baseline
  (a 0.40.0 world arrives only with the 0.40.1 map reset and counts the
  same); a record that is no `major.minor.patch` refuses the start and the
  tool (`record`).
- The tool writes it after each step, in that step's mod-storage
  transaction; with nothing due it writes nothing.
- The game writes its own version when no step lies between: a recognised
  new world at the guard, an existing world at the first server step once
  the load has succeeded (`core.after(0)` from `register_on_mods_loaded`),
  so a failed load never bumps it.
- It is independent of the map reset's `reset_world` (§3.1): that one counts
  resets and drives the clears, this one names the version that last
  started the world and drives the guard.
- Code: `grug_core/world_version.lua` (`grug_core.world_version`).

### 5.4 The start guard

- It runs at the top of `grug_core` (`init.lua` loads `migrations.lua`, then
  `world_version.lua`), before any of the game's code reads or writes saved
  state, the map-reset clears included. The mods that can load before
  `grug_core` (everything that does not depend on it) write no saved state at
  load. There is no separate guard mod: a mod's storage is bound to the
  loading mod (`builtin/common/mod_storage.lua`), so it could not read
  `grug_core`'s record.
- After a mod-load error the engine skips the environment's saves but still
  commits the mod-storage transaction (`server.cpp`, the destructor); the
  guard writes nothing before it refuses.
- The decision compares the record with `game.conf`'s version and the
  registry `grug_core.migrations.versions` (the runtime tree has no `tools/`,
  so the guard cannot read the declaration; `check_upgrade.py` proves the two
  equal):
  - newer world: *"This world is at version X, newer than this game's
    version Y; the server does not start: downgrade to X to continue."*
  - a step between: *"This world is at version X and needs the migration
    step V before this game's version Y can start it; the server does not
    start: back up the world and run the tool from the game's repository
    root: python3 tools/migrate.py --world &lt;world path&gt;"* (several steps:
    "steps V1, V2");
  - otherwise the start goes on. A move that combines a map reset with a
    step passes the guard (the tool already ran) and then resets.
- Each message carries the prefix `[grug_core]` and stops the load as a
  mod error.

### 5.5 New-world recognition

Conservative: in doubt, a world is existing; one wrongly taken for new would
skip its due steps.

- **The game:** new only when `grug_core`'s storage holds no key (every
  start that loaded `grug_core` writes the world preparation's mode), the
  world directory holds no `env_meta.txt` (the engine writes it whenever an
  environment ran) and no `players.sqlite` and no `players/` directory.
  Auth entries are never looked at (a platform may create them before the
  first start); a PostgreSQL player backend is covered by the first two.
  A new world counts as the game's version and is stamped at once.
- **The tool:** the game's rule, tightened to no mod-storage entry of any
  mod and no row of the player backend; a world new to the tool is new to
  the game. Nothing is due and nothing is written; the game stamps it at its
  first start.

### 5.6 Online work

- A step that leaves online work writes markers in its own transactions:
  the world part in `grug_core`'s mod storage, key
  `migrate_world:<version>`; a character part in player meta,
  `grug_core:migrate:<version>` (the tool's `world.mark_world()` and
  `world.mark_character(name)`; the value is handed to the handler).
- The game's handlers live in `grug_core.migrations.handlers[version]`
  (`world(marker)`, `character(player, marker)`). World markers run in
  `register_on_mods_loaded`, after every map-reset clear; character markers
  run in the first join callback of all, before the map reset's relocation.
  Several pending markers run in step order; each is deleted only after its
  handler succeeded.
- A failing world handler stops the load; a failing character handler
  reports through `grug_core.severe`, disconnects the player and keeps the
  marker, so the next load or join runs it again. A handler must be safe to
  rerun over what the failed attempt and the game's own load or join left.
  A marker of an unregistered version is ignored.

### 5.7 Tests

- **Each declared step has its test** (contract R8): a minimal world at the
  previous version, the step, a headless boot of the new version on the
  result, then the checks, its online work at load and at a join included.
  Round 43's integration suite `tools/r43_it/run.sh` is the pattern; its
  test steps lie below the declared ones, so its tool runs and guard
  messages include the declaration's `migrate` list (since 0.44.0). The
  step 0.44.0's test is `tools/r44_ms/run.sh`, 0.45.0's
  `tools/r45_ms/run.sh` with the join part's fixture
  `tools/r45_ms/portable_test.lua`, 0.47.0's `tools/r47_ms/run.sh` with
  `tools/r47_ms/portable_test.lua`, 0.48.0's `tools/r48_bags/run.sh` with
  `tools/r48_bags/portable_test.lua` (§5.8). A tool run on a world before a
  step also runs every later declared step, so an older step's exact checks
  read a copy migrated by that step alone (the tool in-process, pinned to its
  checkout), and the mechanism's checks leave the declared steps' markers
  out.
- Whenever `tools/migrate.py` or `tools/migration/` changes, the test of
  **every** declared step runs in the `debian:trixie` container (older steps
  run on the shared helpers); the tool's unit tests are
  `tools/r43_mt/container_test.sh`, the pre-reset pass's
  `tools/r50_ptool/run.sh` (unit tests and PostgreSQL in the runner's image,
  then a boot whose probe reads the packed entries back). The online-work fixtures of every
  declared step stay in `tools/run_fixtures.sh` for good (old handlers run
  against new game code).
- **Test hooks** for undeclared, test-only steps; neither is reachable from
  a shipped game or the command line:
  - the game: the setting `grug_test_migrations = true` (no shipped
    configuration sets it, `settingtypes.txt` does not list it) makes
    `grug_core` load `<world>/grug_test_migrations.lua` before the guard; it
    returns `{ {version =, world =, character =}, ... }`, and those steps join
    the guard and the runner;
  - the tool: `migration.cli.main(argv, test_steps={version: module})`.


### 5.8 The declared steps

| Step | What it does | Online work | Test |
|---|---|---|---|
| 0.44.0 (Round 44, the UI rework) | For every character, offline ones included: every mount item leaves every list, every skill every list but the hotbar (`main` slots 1–8); nothing else changes, the purchased mounts stay in player meta (`grug_mounts:*_tier`) and the quickbar reads them; a character's inventory is written only when something goes. Player inventories only: a crafting station's grid (a detached inventory saved in node meta) may still hold such an item and would need the deferred map part (rare; nothing is lost); a dropped one is deleted | none | `tools/r44_ms/run.sh`: unit tests, then a 0.43.0 world built by the 0.43.0 game, the shipped tool in the runner's container, a boot and joins of 0.44.0 |
| 0.45.0 (Round 45, the crafting rework) | For every character, offline ones included, in this order: every `grug_alchemy:mixture_*` stack leaves every list (alchemy makes finished potions, the mixtures are inert); the stacks of the engine `craft` grid, then of the engine list `craftresult` (a craft whose follow-up move failed left real items there), move in slot order into **empty** slots of `main[9..]`, the equipped bags (bag slot order, only slots the bag's size holds) and then the hotbar (the give helper's order; empty slots only, the tool cannot read `stack_max`), an empty grid is stored with size 0, `craftresult` keeps its size 1, and what does not fit stays in its list; every gear stack of the 0.44.0 game (weapons, shields, spellbooks, armour, trinkets) without an item level of its own (`grug_ilvl` missing or not above 0) gets the 0.44.0 definition's item level as `grug_ilvl` and, unless it has one, its requirement as `grug_req_level`, in every list (crafted, rolled, upgraded and crowned gear is never touched); the dead `craftpreview` stack and the player meta `grug_jobs:seen_items` go; every character gets the marker. A character's inventory is written only when something changed. Player inventories only: gear and mixtures in node inventories on the map follow the new definitions (accepted, spec §6) | Each character's next join (`grug_core.migrations.handlers["0.45.0"]`, first join callback): what the grid and `craftresult` still hold goes through the give helper, then into the output area `grug_craft_out`, then drops at the feet (ruling 6; a failed drop keeps the rest in the grid and fails the handler); the tool capabilities of a weapon whose damage no longer matches its item level are rewritten (`grug_items.refresh_capabilities`: unmodified first-tier weapons, whose damage the ladder lowered; a broken one keeps them for the repair); every gear tooltip is rebuilt. `grug_inventory`'s own join callback then drops the equipment caches | `tools/r45_ms/run.sh`: unit tests, then a 0.44.0 world built by the 0.44.0 game, the shipped tool in the runner's container (also on PostgreSQL, every row equal to the SQLite result), a boot and joins of 0.45.0; the join part's fixture `tools/r45_ms/portable_test.lua`; the chain from a 0.43.0 world and from a record-less (0.41.0) copy through 0.44.0 and 0.45.0 in one run: `tools/r44_ms/run.sh` |
| 0.47.0 (Round 47, the pick level scale) | Every character, offline ones included, gets the marker; nothing else is written (the rebuild needs the new definitions, which only the game has) | Each character's next join (`grug_core.migrations.handlers["0.47.0"]`, first join callback): every tool stack (grug_quality family `tool`: picks, axes, shovels, hoes) that keeps a copy of its capabilities in item meta (`tool_capabilities`, written by every craft) or the copy for the repair (`_grug_repair_caps`, a broken tool) is rebuilt from its current definition (`grug_items.refresh_capabilities`, the craft path's own rebuild; a broken stack stays broken), in every list of the player's inventory: main and the hotbar, the bags' content lists, the crafting output area and every other list. A tool without a copy follows its definition and is not touched; only a changed stack is written. Not covered and not needed: tools in node inventories (chests, stations) and dropped ones are map-bound and go with the map reset; no other player-bound storage holds items (detached inventories are rebuilt per session; station jobs never take a tool) | `tools/r47_ms/run.sh`: unit tests, then a 0.45.1 world built by the 0.45.1 game, the tool in the runner's container, a boot and a join of 0.47.0; the join part's fixture `tools/r47_ms/portable_test.lua` |
| 0.48.0 (Round 48, the bags at half size) | Every character, offline ones included, gets the marker; nothing else is written (the layout needs the game's sort order and stack sizes, the leftovers the game's mail) | Each character's next join (`grug_core.migrations.handlers["0.48.0"]`, first join callback, so before the bags' join callback sizes the content lists): a character with bags has `main[9..]` and the bags' content lists sorted once into the new sizes (4 / 8 / 12 / 16 instead of 8 / 16 / 24 / 32) through the one sort path (`grug_inventory.sort` with target sizes); the hotbar is not touched; soulbound and bound items keep a cell; what does not fit (the end of the sort order) is sent as "npc" letters from "Lost and Found", four stacks each (`grug_mail.send_system` with stacks), each stack leaving its cell only once its letter is sent; then the content lists shrink, and one feed line follows the join when letters were sent. A character without bags only loses the marker. A failed send fails the handler with the unsent stacks still beyond the new sizes; the bags' join callback never shrinks a list over items, so the next join sends only the rest. Not covered and not needed: node inventories hold no bag contents; the step only adds letters to `grug_mail`'s storage | `tools/r48_bags/run.sh`: unit tests, then a 0.47.0 world built by the 0.47.0 game, the tool in the runner's container, a boot and joins of 0.48.0; the join part's fixture `tools/r48_bags/portable_test.lua` |

0.49.0 to 0.50.0 declare no step. The pre-reset pass (§3.5) is no step: it
has no version of its own, runs at every map reset from 0.50.0 on, and
writes no world version.

The 0.44.0 step identifies the items by the 0.43.0 game's names, frozen in
the step: a skill is any item of `grug_abilities` (`grug_abilities:<id>`,
registered only by `register_ability`), a mount item one of the six tier
items of `grug_mounts/catalog.lua`; its end-to-end test proves both against
the registrations of a running 0.43.0 game.

The 0.45.0 step's tables are the 0.44.0 game's, frozen in the step: the 156
gear items built from `grug_gear.MATERIALS`, the weapon families, the armour
lines and slots and the trinket identities, each with its bracket's
(`_grug_ilvl`, `_grug_req_level`): 3/1, 10/10, 20/20, 30/30, 40/40, 50/50;
the eight bags and their sizes; the mixture prefix (ST's 40 ids). Its
end-to-end test proves them against the registrations of a running 0.44.0
game (every equipment item with an item level, no other equipment, no alias
to any of them) and shows that every pinned item's 0.45.0 definition
differs.
