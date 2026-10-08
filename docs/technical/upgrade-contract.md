# Upgrade contract

Release mode starts with 0.41.0 (Round 41, the user's ruling 9 of
2026-10-07; [round 41 plan](../planning/round41-plan.md) §2.9–§2.10). The
hosting platform runs Grudgelands worlds (map, players and auth in
PostgreSQL, mod storage in SQLite) and is built against this contract
(the platform's task file
`~/projects/kaesual-stack/.local/grudgelands-upgrade-contract-task.md`, not
in this repository). This file owns the game's side of it. The working rules
are in [AGENTS.md "Release mode"](../../AGENTS.md#release-mode).

## 1. Three outcomes

An upgrade of a world to a newer Grudgelands version is exactly one of:

- **compatible:** nothing to do; the new code boots the world and reads every
  saved state. A best-effort intent, also for worlds in full-preparation mode:
  no saved test worlds prove it.
- **map reset:** the platform stops the server, empties the map table, raises
  the setting `grug_reset_world` and starts the server; the game does the
  rest (§3). The seed and `map_meta.txt` survive.
- **new server:** the platform refuses the in-place upgrade.

Upgrades only go forward. When a move crosses both kinds, **new server**
wins.

What a change needs:

| Change | Outcome |
|---|---|
| Nothing saved changes meaning | compatible |
| World generation, or map-bound state (§3.2) the new code cannot read | map reset |
| Saved character or world state the new code cannot read that is not map-bound: an XP-curve change, a removed or restructured quest (objectives, prerequisites, order), a removed item, rebuilt talents | new server |
| A change to a validated world-creation scalar (`game.conf`'s mapgen pins, `r7_runtime.lua` `validate_live_scalars`) | new server |

There are **no data migrations**: a change the new code cannot read is
declared, never converted. Ids of quests, items, achievements and waypoints
stay stable; a renamed item may keep its old name with `register_alias`
(`tools/check_fresh_server.py` allows it). Mapgen parameters a version
needs keep being set by the game itself.

Every lane states its change's outcome in its report and the reviewer checks
it ([round workflow §3](../process/round-workflow.md#3-gates)); the round's
declaration follows from them.

## 2. The declaration

`tools/web_data/upgrade.json`, exactly this shape (schema 2 since Round 43,
which added the `migrate` list of the platform's migration contract):

```json
{"schema": 2, "version": "0.42.0", "map_reset": ["0.40.1"], "new_server": [], "migrate": []}
```

- `version` equals `game.conf`'s `version`. Versions are
  `major.minor.patch`, compared numerically per component, and never
  decrease.
- Each list holds, strictly ascending, the versions that need that outcome
  when a world crosses them: a move from `a` to `b` crosses every entry `v`
  with `a < v <= b`. Entries are never edited or removed, every entry is at
  most `version`, and a new entry comes only together with a version bump.
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
