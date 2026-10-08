# Upgrade contract

Release mode starts with 0.41.0 (Round 41, the user's ruling 9 of
2026-10-07; [round 41 plan](../planning/round41-plan.md) §2.9–§2.10). The
hosting platform runs Grudgelands worlds (map, players and auth in
PostgreSQL, mod storage in SQLite) and is built against this contract (the
platform's task files `~/projects/kaesual-stack/.local/grudgelands-upgrade-contract-task.md`
and, since Round 43, `grudgelands-migration-contract-task.md` revision 2 in
the same folder; not in this repository). This file owns the game's side of
it. The working rules are in [AGENTS.md "Release mode"](../../AGENTS.md#release-mode).

## 1. Four outcomes

An upgrade of a world to a newer Grudgelands version is exactly one of:

- **compatible:** nothing to do; the new code boots the world and reads every
  saved state. A best-effort intent, also for worlds in full-preparation mode:
  no saved test worlds prove it.
- **map reset:** the platform stops the server, empties the map table, raises
  the setting `grug_reset_world` and starts the server; the game does the
  rest (§3). The seed and `map_meta.txt` survive.
- **migrate** (since Round 43): with the server stopped and the world backed
  up, the target version's migration tool converts the world offline, and the
  game finishes a step's online work at the next load and at each affected
  character's next join (§5).
- **new server:** the platform refuses the in-place upgrade.

Upgrades only go forward. **New server** wins over everything. **Map reset**
and **migrate** combine: the platform empties the map first, then runs the
tool, then raises `grug_reset_world`, so a step works on an empty map and
never relies on map-bound mod storage (§3.2), which the game clears only at
the next load.

What a change needs:

| Change | Outcome |
|---|---|
| Nothing saved changes meaning | compatible |
| World generation, or map-bound state (§3.2) the new code cannot read | map reset |
| A removed item: a step replaces or removes it in inventories, offline characters included | migrate |
| Restructured character state (quests and their objectives, prerequisites or order, talents, saved formats): a step converts it, offline or as online work at the character's next join | migrate |
| Saved character or world state the new code cannot read that is not map-bound, when the round decides not to migrate it | new server |
| A change to a validated world-creation scalar (`game.conf`'s mapgen pins, `r7_runtime.lua` `validate_live_scalars`) | new server |

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

`tools/web_data/upgrade.json`, exactly this shape (schema 2 since Round 43,
which added the `migrate` list of the platform's migration contract):

```json
{"schema": 2, "version": "0.43.0", "map_reset": ["0.40.1"], "new_server": [], "migrate": []}
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
- `tools/check_upgrade.py` checks these rules against the last pushed commit
  (`origin/main`; `--base REF` for another) and runs its own self-test of the
  rules first (also alone: `--self-test`). A missing earlier declaration is
  accepted once; a pushed schema-1 declaration counts as one without
  `migrate` entries. It also proves the game's step registry
  (`grug_core.migrations` `versions`, which the start guard reads) equal to
  `migrate`, and that each `migrate` entry's step file
  `tools/migration/steps/vX_Y_Z.py` exists and, once pushed, is unchanged.
  It runs at every round end.
- The first declaration (0.41.0) covers the one migration that is due: the
  user's production server moves from 0.40.0 to 0.41.0 with a map reset
  (it crosses 0.40.1, which changed world generation; Round 41's own mapgen
  fix is covered by the same reset). No history before 0.40.0 is audited.
- 0.43.0 ships the migration foundation alone, with an empty `migrate` list
  (Round 43 ruling 2); the first real step comes in a later version.
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
| `grug_housing` (`registry.lua` `map_reset`) | every `claim:<id>`; a `player:<name>` whose stone stood becomes `needs_stone` | `next_id` (monotonic), every other player record (a carried stone stays carried) |
| `grug_core` `reset_world` | — | the world record itself |
| `grug_home` `claim_lost:<name>` | — | pending notices of a past pick-up or destruction |
| `grug_parties` `parties`, `grug_repair` `item_serial` | — | not map-bound; the serial is a monotonic counter |

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
  (`grug_classes/selection.lua`: frozen, immortal, the waiting screen), like
  every existing character during world preparation.
- Once the preparation is ready and its race start has loaded
  (`grug_factions.prepare_spawn`), it is moved there without the arrival
  flow or the welcome, its map-bound player state is cleared
  (`grug_core.map_reset.register_on_relocate`) and only then its record is
  written (`grug_core.map_reset.relocated`).
- A failed load is logged at error level, leaves the record unwritten and
  disconnects the player with a short message; the next join tries again.
- **New characters:** `on_newplayer`, and a join without a stored
  `grug_classes:race`, record the world's applied value without a move. The
  creation stasis (`grug_core.player_in_creation_stasis`) decides nothing.
  A created character that had not arrived yet takes the arrival teleport to
  its race start, which writes the record too.

### 3.4 Adding map-bound state

New state that describes the map (a position, a placed node or entity, a
generated feature) gets its clear in the same change: a
`grug_core.map_reset.clear` call in the owner's load for mod storage, a
`grug_core.map_reset.register_on_relocate` callback for player meta. The
fixture is `tools/r41_up/portable_test.lua`.

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
completion with the platform summary); 0.43.0 declares no step yet. The
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
  lock). The tool cannot detect a running server: stopping it is the
  caller's duty.
- It runs from the repository root of a full export of the commit (every
  tracked file except `reference_projects/`), on Python 3.13 or newer with
  the standard library; `psycopg` 3 only for a PostgreSQL world, imported
  lazily (`tools/migration/requirements.txt` for self-hosters; the platform
  uses Debian trixie's packages).
- The world comes from `world.mt` only: `player_backend`, `auth_backend`,
  `mod_storage_backend`, each `sqlite3` or `postgresql`, and the matching
  `pgsql_*_connection` strings handed to libpq (a password may come from
  `PGPASSFILE`). Anything else (files, leveldb, a missing key) is refused.
  The engine's table layouts are checked; the tool never writes `world.mt`,
  never creates, alters or drops a table, and never creates a database file.
  A missing `players.sqlite` or `auth.sqlite` (nobody ever joined) counts as
  empty; a missing `mod_storage.sqlite` is refused.
- **Exit codes:** `0` migrated, nothing to do, or checked; `2` refused before
  anything was written (a newer world, an unsupported backend or layout, an
  invalid `world.mt`, a failed connection, a lock not acquired); `1` failed
  once the first step had begun: the world is undefined, restore the backup.
- **Output:** one JSON object per line on stdout (`start`, `step_start`,
  `step_done` with counts, `done`, or `refusal` with its reason at exit 2,
  `failed` at exit 1), the same as text on stderr.

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
  version is the tool's own key. Map blocks are deferred until the first
  step that needs them (Round 43 ruling 4).
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
  Round 43's integration suite `tools/r43_it/run.sh` is the pattern (it
  assumes an empty `migrate` list; the round of the first real step adapts
  it).
- Whenever `tools/migrate.py` or `tools/migration/` changes, the test of
  **every** declared step runs in the `debian:trixie` container (older steps
  run on the shared helpers); the tool's unit tests are
  `tools/r43_mt/container_test.sh`. The online-work fixtures of every
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

