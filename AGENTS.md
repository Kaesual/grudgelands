# AGENTS.md — Project Guide

MMO-inspired Luanti game, titled "Grudgelands". This file holds the working
rules; every fact has one owner and the others link to it
([owners](docs/process/documentation.md#one-owner-per-fact)): status, push and
acceptance in [docs/STATUS.md](docs/STATUS.md); goals in
[ROADMAP.md](ROADMAP.md); open work in [BACKLOG.md](BACKLOG.md); how a round
runs, its gates and the review checklist in the [round
workflow](docs/process/round-workflow.md); model routing in the [agent model
policy](docs/process/agent-model-policy.md); which mod owns what in the [mod
map](docs/technical/mod-map.md); Lua and engine rules in
[luanti-lua.md](docs/technical/luanti-lua.md); everything else from
[docs/README.md](docs/README.md).

**Current state:** Round 42 (mob navigation; 0.42.0, compatible) is
complete on main and its playtest accepted (the user, 2026-10-08;
[plan](docs/planning/round42-plan.md)). origin/main is `71f777e2` (pushed
2026-10-08): Round 41 (0.41.0, map reset) and every Round 42 lane up to
ST under 0.41.0; 0.42.0 (CL and lane D) is not pushed. Rounds 25–35
count as GUI-accepted (the user, 2026-10-05), Round 39 too (2026-10-06);
the GUI tests of Rounds 36–38, 40 and 41 are open. Next: Round 43 (world
migrations) in parallel with Round 44's wave 1 (UI rework), then Round 45
(crafting); each waits for the user's "go". Details:
[STATUS](docs/STATUS.md).

## Language rules

- **All Markdown documentation in this repo is written in English.** Exception:
  `docs/research/` contains older German reference notes; they may stay German
  until substantially rewritten.
- Chat with the user is in **German**; code identifiers and code comments are in
  English.

## Standing user rulings

- **Naming (2026-10-03, generalised 2026-10-05):** the factions are **The
  Accord** and **The Throng**, in chat too, never translated. Never name an
  existing game as a reference — no titles, studios, or their faction, class,
  ability or place names — in docs, code comments, ids, briefs, pages or chat;
  describe mechanics in neutral words ("MMO-inspired"). Provenance is not a
  reference (user ruling 2026-10-06): code and licence provenance (VENDOR.md,
  LICENSE-media.md, CREDITS.md, `docs/reference_projects.md`, source
  citations) names the Luanti projects we vendor or read; the rule covers
  design inspiration.
- **The web build is a target system** next to desktop: both are tested, and
  effects keep the particle budget ("Performance").
- **Agent execution channel (2026-09-20):** models of the coordinator's own
  provider run as native subagents; CLI delegation only crosses providers
  (Claude may run Codex CLI, Codex may run Claude CLI when authorized). This
  changes mechanics, not authorization or review duties ([cross-CLI
  orchestration](docs/process/cross-cli-orchestration.md)).
- **Model routing:** the user decides per session which model coordinates,
  implements and reviews; the policy's roles are defaults. Independent review of
  every non-trivial change stays mandatory.
- **Version (user, 2026-10-05):** `game.conf`'s `version` counts
  `0.<round>.<patch>` (0.37.0 first); it is the one source Help → About
  and the newest [CHANGELOG](CHANGELOG.md) entry show (`tools/r37_dc`
  checks both).
- **Only the user pushes.** Agents never push.

## Release mode

- **The user's announcement (2026-10-07, Round 41 ruling 9):** fresh-server
  development mode ended with **0.41.0**. Worlds survive upgrades through the
  hosting platform's upgrade contract
  ([upgrade contract](docs/technical/upgrade-contract.md)): every upgrade is
  **compatible**, needs a **map reset** or needs a **new server**, declared
  in `tools/web_data/upgrade.json` and checked by
  `python3 tools/check_upgrade.py`. Exactly one real world existed then (the
  user's production server on 0.40.0); nothing checks, audits or supports
  older versions.
- **No data migrations.** A change the new code cannot read from saved state
  is declared, never converted: a map reset when the state is map-bound (or
  world generation changed), otherwise a new server (an XP-curve change,
  removed or restructured quests, removed items, rebuilt talents, a validated
  world-creation scalar). "New server" wins when both apply. The only
  migration mechanism is the map reset (`grug_reset_world`,
  `grug_core.map_reset`); new map-bound state gets its clear in the same
  change.
- **Stable ids:** quests, items, achievements and waypoints keep their ids;
  a renamed item may keep its old name with `register_alias`. Unknown ids in
  saved state are ignored or dropped, never a crash.
- **Every lane classifies its change** (compatible, map reset, new server)
  in its report and the reviewer checks it; a new-server change is reported
  before it is built ([round workflow](docs/process/round-workflow.md#3-gates)).
- A compatible version should boot every world of the version before,
  full-preparation worlds included: best effort, without saved test worlds.
  Keep it minimal: no mechanism for a case that does not occur.
- Still no backward-compatibility branches, old-format readers,
  compatibility placeholders or cleanup LBMs for the development versions
  before 0.40.0; the twelve tool aliases `grug_materials.TOOL_ALIASES` (Round
  26 ruling 14) stay. Current-version persistence (saving and reloading the
  same world, reconnects, inventories, entity activation) remains required.

## Anthropic repository sharing authorization

**Standing user authorization, decided 2026-08-30:** every file in this
repository, including its read-only reference submodules and prepared snapshots,
may be sent to Anthropic when an authorized Claude Opus or Claude Fable task
needs it, without a separate confirmation. Keep each snapshot bounded to the
reviewed or delegated package; this permits no unrelated publication, no writes
by a read-only reviewer and no other side effect. Model/task authorization stays
separate: each new Fable task still needs the approval the [agent model
policy](docs/process/agent-model-policy.md) requires.

## Documentation layers

All durable project state belongs in the repo: what a future session needs goes
into AGENTS.md or `docs/`, not only the chat. Owners, archival and conflict
rules: [documentation maintenance](docs/process/documentation.md).

1. **`docs/design/`** — the *decided* game design (rules, numbers, lists; no
   open questions, no discussion).
2. **`TODO-<topic>.md`** (repo root) — *open* design questions. When every
   question in a file is decided, fold the results into `docs/design/` (and
   ROADMAP/BACKLOG where affected), then **delete the TODO file**.
3. **[BACKLOG.md](BACKLOG.md)** — work packages (WPs) and carry-overs; WPs
   reference `docs/design/` instead of inventing design.

**[README.md](README.md)** is the player-facing entry point, **derived, never
authoritative**; it keeps only a short "Current state". The round log is the
player changelog [CHANGELOG.md](CHANGELOG.md), one entry per round. At the end
of each round lane D writes the round's CHANGELOG entry and updates the README's
current state ([round
workflow](docs/process/round-workflow.md#4-lane-d-and-the-post-merge-status-step));
a design file added, removed or substantially changed also updates its design
tour; it never carries design or WP detail that does not already live in
`docs/design/`, ROADMAP or BACKLOG.

## Working method

- **Session start:** read [STATUS](docs/STATUS.md), then the current round plan
  (`docs/planning/round<NN>-plan.md`) or the task the user names; check for
  `TODO-*.md` files that block it.
- **Rounds and lanes:** work runs in rounds planned with the user, as lanes on
  `r<NN>-<lane>` branches in `.claude/worktrees/`, each independently reviewed
  and merged by the coordinator. Flow, gates, review checklist, brief rules and
  templates: [round workflow](docs/process/round-workflow.md).
- **Findings are hypotheses:** check a review finding, report claim or error
  message at the cited place before acting on it.
- **Rough targets, not hard gates:** new rules are guide values; checks only
  where gameplay would otherwise break; in doubt, ask the user.
- **Escalate** a fix that makes the design clearly more complex or world
  generation noticeably slower; do not solve or accept it alone.
- **Runtime tests are the user's** (Flatpak Luanti GUI, desktop and web build);
  every round ends with a GUI checklist.

## Project structure

- A **standalone game** (not a mod pack, not a fork of another Luanti
  game). The repository root is the game (`game.conf`, `menu/`, `mods/`,
  `settingtypes.txt`). **Standard unmodified Luanti clients are required:** no
  client or engine fork, no dependency on an upstream PR, no required client
  mod.
- **Third-party code is vendored, never a submodule** (2026-08-06):
  `mods/BASE/*` and the mobs_redo fork `mods/ENTITIES/mobs`, each in
  **[VENDOR.md](VENDOR.md)** (upstream, commit, license, patch list); in-place
  changes carry a `-- GRUG PATCH:` marker; prefer wrapper mods (`grug_mobs`
  pattern) over in-place edits.
- `reference_projects/` holds **read-only reference sources as git submodules**
  (WP36): not part of the build, but every engine claim, licence check and
  `file:line` citation points into them (`git submodule update --init
  --recursive --depth 1`). **Never move a pinned commit as a side effect** —
  `git submodule status` shows no `+`/`-`/`U`; deliberate updates and **every
  reference needed beyond one session** go through
  [docs/reference_projects.md](docs/reference_projects.md) (URL, purpose,
  licence; scratchpad clones die with the session).
- **Imported meshes must be animated** (`ANIM`/`BONE`/`KEYS` chunks); a static
  mesh slides instead of moving.

## Lua & Luanti environment (IMPORTANT)

- **Plain Lua 5.1 is a HARD requirement** (2026-08-06): the engine prefers
  LuaJIT but silently falls back to bundled Lua 5.1.5, and our code runs on
  both. The do-not-write checklist and the engine facts:
  **[docs/technical/luanti-lua.md](docs/technical/luanti-lua.md)**. Key rules:
  - **No `goto`**, no `\u{...}`/`\x..`/`\z` escapes, no `//`, no bitwise
    operator syntax (use `bit.*`, 32-bit); `unpack`, never `table.unpack`; no
    `table.pack`/`rawlen`/`__len`/`__pairs`. Numbers are doubles (safe integers
    ±(2^53−1)).
  - **Deterministic code** (all of `mods/MAPGEN`, and anything that must agree
    across processes): `x * x`, never `x ^ 2` (check_lua sweep 6), and no
    `pairs` order over string keys in output — sort the keys first.
  - Compare positions with `vector.equals`, never `==`.
  - `pairs(core.registered_nodes)` never yields alias names; resolve known names
    directly (`core.registered_nodes[name]`, `core.get_content_id`).
- **Check every changed Lua file** with `bash tools/check_lua.sh <files>` from
  the repository root, Lua under `tools/` included: the plain-5.1 parser
  (`tools/bin/luac51`, built once by `tools/build_lua51.sh` — **not** `luajit`,
  which accepts what the fallback rejects), the `SETGLOBAL` listing and six
  sweeps. It needs ripgrep and fails fast without it.
- **PUC is ignored during development** (user ruling 2026-09-25, Round 22 D1;
  every lane's rule since Round 29): all executable runs use LuaJIT; no PUC
  fixture, parity digest or gate; at most one optional PUC crash smoke test at
  the end, once the mapgen is finished (BACKLOG release checks).
- **At most 8 Lua processes at once on the workstation**, counted across all
  agents, lanes and reviews (8 physical cores, user ruling). Parallel runs are
  preferred: do not serialize independent seeds or partitions for
  convenience, and do not parallelize jobs that share mutable output or whose
  correctness depends on execution order. Fleets run under
  `chrt --idle 0` and `ionice -c3`, each process with its own output and a
  deterministic merge step. The host is the user's workstation: wall time is
  **never** a kill criterion (abort only on an intrinsic projection or lost
  liveness), timings under unintended contention are invalid, and the same work
  never runs twice. A round's queue script enforces the cap.
- The reference checkout is **Luanti 5.17.0-dev**, a read-only source; a newer
  engine never unlocks newer Lua syntax. **Read the engine's Lua, never guess:**
  `reference_projects/luanti/builtin/`, `lib/lua/src/`,
  `src/script/lua_api/l_*.cpp`.
- **Engine workarounds** live in
  [docs/technical/upstream-workarounds.md](docs/technical/upstream-workarounds.md);
  check it at every engine version change and at the start of each round; a new
  workaround gets an entry there.
- **`core.*`**, never `minetest.*`. **All game logic runs server-side**; no
  SSCSM. The sandbox disables `require`, `os.execute` and most of
  `io`/`os`/`debug`; we never request the insecure environment. `strict.lua`
  warns on undeclared globals — treat each warning as a bug.

## Game/mod anatomy

- Every mod: `mod.conf` (`name`, `depends`, `optional_depends`) + `init.lua`;
  media in `textures/ sounds/ models/ locale/` (names `a-zA-Z0-9_.-`, models
  `.b3d/.obj/.gltf/.glb`, sounds `.ogg`). Registered names are
  `modname:name`; `:foo:bar` overrides a foreign registration (needs a
  dependency). `game.conf` pins `allowed_mapgens = v7`.
- Six modpacks: `BASE/` (vendored), `CORE/`, `PLAYER/`, `ENTITIES/` (with the
  vendored mobs fork), `ITEMS/`, `MAPGEN/`; HUD elements live in their owning
  mod. Owners, seams and traps (`mod.conf` understates the coupling): [mod
  map](docs/technical/mod-map.md).

## Project conventions

- **Namespace `grug_`** for our mods; exactly one global table per mod, named
  after it, sub-files via
  `dofile(core.get_modpath(core.get_current_modname()).."/foo.lua")`. Two
  documented exceptions: `grug_quality` publishes `grug_items`, `grug_core` also
  publishes the zone façade `grug_zones`.
- Custom definition fields use the `_grug_` prefix; dispatch behaviour via
  **groups**, not name lists.
- Persistence: player data → `player:get_meta()` (structures via
  `core.serialize`); mod-wide data → `core.get_mod_storage()` (fetched at load);
  node data → `core.get_meta(pos)`.
- **Terrain-damage guard (user, 2026-09-19):** towns, starts, capitals and POIs
  are never damaged. Anything that writes or removes nodes from mobs, combat,
  fire, explosions or lava asks `grug_core.world_alterable(pos)`; the two
  recorded exceptions are the rift's crack and settlement NPCs opening and
  closing doors (`grug_mobs/npc_doors.lua`, Round 42 ruling 15).
- **Performance basics:** throttle every `register_globalstep` with a dtime
  accumulator; node timers for stations; LBMs only for current-version
  activation; ABMs only for ambient events (`chance`/`interval`, `catch_up =
  false`); `core.get_node_raw`, content ids and VoxelManip in hot loops.

The topic rules below name the one path to use; the
[module guide](docs/technical/module-guide.md) holds the seams behind them.

### Zone content

- **Mobs, loot, quests and enchant inputs are data**, per zone where per-zone
  (`grug_mobs/data/zones/<zone>.spawns.json`,
  `grug_quests/data/zones/<zone>.quests.json` and `.front.quests.json`,
  `grug_mobs/data/{subtypes,items,drops,tints}.json`,
  `grug_professions/data/enchants.json`). Tune data, not code.
- **Zone data holds rules, never coordinates** (maps differ per seed): surface
  spawns come from the recipe's regions on the seed's own terrain
  ([spawn_regions.md](docs/design/spawn_regions.md)). A zone's level band is its
  mapgen record (`grug_mapgen/wp40/source/simple_map.lua`) and changes only in a
  mapgen round; a mob's surface level is `grug_core.mob_level_at` (the
  spawn-region overlay), not `grug_zones.mob_level_at`.
- **After a recipe change:** `tools/r28_regions/run.sh <zones>` and
  `tools/r28_world/run.sh` (border rule `tools/r28_world/border_rule.py`); show
  the images when the user decides a distribution. Design files:
  `python3 tools/r28_design/validate.py`.
- **Names are data per slot** (zone, source, level band) in
  `grug_mobs/data/names.json`, built by `tools/r38_b1/gen_names.py
  --proposals` (`--check`); code-built names (kings, dragons, whelps …) read
  it, no second copy in code (PvP captains: `pvp_names.json`). **A kill counts by the name
  the mob shows**, so a quest's name is its exact target
  (`tools/r38_names/guarantee.py --check`); item objectives name items, the
  mobs they mention are guidance. The rules — normal mobs at most two words,
  named, elite and boss at most three, no signal words, Piglet only for the
  start pigs, one level stretch within one drop tier — are owned by
  [biomes_mobs.md "Names"](docs/design/biomes_mobs.md#round-28-sub-types-and-loot-by-band);
  the gate is `tools/r38_names/check_rules.py --shipped` (the Round 28
  `build_review.py` is retired). **Quest texts** name items,
  never tooltip texts; seed-dependent directions and places are placeholders
  ([spawn_regions.md](docs/design/spawn_regions.md#directions)), never a fixed
  compass word. Quest files that require each other change together.

### Economy and travel

- **One price module pays every vendor** (`grug_traders/prices.lua`, pure
  `price_rules.lua`): no price fields, no `set_price`; a new sellable needs a
  class and a tier; a new recipe passes the load audit (output ≤ inputs)
  ([economy.md](docs/design/economy.md)).
- **Money check:** `tools/r29_e4/income.py --check` (mount, boat and respec
  prices, the crown fee) after any change to loot, repair or quest copper.
  Quests pay copper from their weight unless `rewards.copper` is set. Quest
  checks: `quest_targets.py` (region stats of three seeds), `validate.py
  --game`, `ledger.py --track <race>`.
- **All travel** (home return, respawn, waystones) goes through
  `grug_home/travel.lua`; boats are water mounts in `grug_mounts`. Gems are
  depth-tiered, each in its own tier rock; there are no gem grades and no apex
  sockets.

### Performance

- **Numbers are comparisons, never targets:** before and after on the same
  seed, area and probe (method: the
  [performance review](docs/research/perf-review-2026-10.md)). **No wall-clock
  budgets in code**: nothing decides its output by elapsed time.
- **Particles** are welcome, but the total at once stays in the **hundreds,
  never thousands** (the web build); every spawner has a bounded amount and
  lifetime. Effect briefs name the budget; reviews check it.
- **World-folder caches** (world layouts, region maps, the Map tab's zone grid)
  share the key `grug_mapgen.wp40.world_key` plus a digest of their builders'
  files; a new input joins the key; any failure rebuilds, never stops the load.
- **Mob per-step code:** A* only inside the per-step budget, no
  `get_properties()` (`self._grug_cbox`), spawn rows only through the three
  merged spawn ABMs. **Quest state** is cached decoded: never write into a table
  `load` returns; marker consumers read `grug_quests.marker_states`.
- **No pass handles every player or zone in one step:** periodic passes spread
  work over slots or a per-pass budget, measured with stand-ins before and
  after.

### PvP, factions and looks

- **PvP is one flag per player** (`grug_pvp`, [pvp.md](docs/design/pvp.md)):
  combat asks `grug_pvp.can_harm`/`can_support` and never changes PvP state;
  `grug_core` reaches PvP only through the seams `grug_pvp` installs; the
  location is sampled once a second, never on the combat path. A combat-path
  change reports the PvE micro run before and after (`tools/r31_pvp/run.sh`).
- **A position's territory** comes from `grug_pvp.territory_at`, never the
  player's flag. **An NPC's faction decides whom it serves and its map marker**
  (`grug_factions.serves`/`refuse`), never the place.
- **Looks** are stored once per player (`grug_visuals.set_look`) and rolled once
  per NPC; look and enchant art comes from the generators
  (`tools/wp13/gen_character_visuals.py`, `tools/r31_b/gen_enchant_masks.py
  --check`). PvP POIs are rules in `grug_mapgen/wp40/r31_pvp_catalog.lua`.
- **Realm websites read player meta** (the contract in the
  [module guide](docs/technical/module-guide.md#player-meta-read-by-external-tools)):
  those keys and the appearance format are not renamed without notice; a
  format change raises `APPEARANCE_VERSION`. A change to items, factions,
  classes, races or textures regenerates `tools/web_data/web_data.json`
  (`export.lua --check`); a change to the player model or its animations
  reruns `tools/web_data/model/build_glb.py --check` and `check_glb.py`.

### Combat, input and notices

- **Every server aiming ray goes through `grug_core.aim_raycast`**, never
  `core.raycast` with objects (the engine misreads rotated selection boxes,
  [upstream-workarounds.md](docs/technical/upstream-workarounds.md) §1);
  node-only rays keep the engine's raycast; aiming rays skip objects the player
  cannot see.
- **The LMB hold is one state machine** (`grug_abilities/input.lua`,
  [classes.md](docs/design/classes.md#left-click-and-held-input) §2b): a new
  hold rule changes that machine and its fixture, never adds a second lock.
- **Talent values are level-proof** (a percentage of the base hit or of `K(L)`,
  listed in `LEVEL_SCALED_KEYS`; [skill_trees.md](docs/design/skill_trees.md)
  §2.10); a flat "+N" is a design error. Support amounts multiply by
  `grug_classes.get_support_factor`; spells floor once after the level scalar
  ([combat_stats.md](docs/design/combat_stats.md) §2).
- **Personal notices go to the message feed** (`grug_core.feed`), never chat;
  chat keeps deaths, rare sightings, boss and dragon warnings. Quest kill labels
  use the zone's mob name (`validate.py`).
- **Character creation** stores nothing before "Create character"
  (`grug_classes/selection.lua`). Night region mobs leave at dawn
  (`grug_mobs/dawn.lua`).

### Items, professions and achievements

- **One source per item number:** [item_tiers.md](docs/design/item_tiers.md);
  its tables are generated by `tools/r33_ds/` (`build_doc.py --check`): change
  data or script, never a generated table. Drop rates are data in
  `grug_quality/init.lua`.
- **An enchant's value is never stored free:** each enchant carries stat,
  channel and tier, and `grug_items.enchant_value(stat, ilvl, tier)` derives it
  through grug_quality's one store path on every level or tier change. Station
  work is a `grug_jobs.register_station_operation` kind.
- **Profession progress** comes only from recipes with the `progress` flag,
  through `grug_jobs.award_progress`.
- **Achievements** are catalog data on existing counters fed by hooks
  (`grug_mobs.register_on_boss_kill`, `grug_pvp.register_on_stat`,
  `grug_jobs.register_on_award_progress`), never a second kill, craft or boss
  path; stored per character. The cloak model comes from
  `tools/r33_c3/gen_cloak_model.py --check`.
- **Capital services** take over a gate resident
  (`grug_core.assign_service_socket`), no blueprint change.

### Sound

- **Approval gate (user, 2026-10-04):** no sound file ships unless the user
  picked that exact file on a listening page, recorded in an `approved.txt` the
  fixture checks every `.ogg` against. An event without an approved file stays
  silent, never a placeholder; a changed cut needs a new pick. Every file has a
  `LICENSE-media.md` row; attribution licences also go into
  [CREDITS.md](CREDITS.md). Rules: [sound.md](docs/design/sound.md).
- **One play path:** `grug_sounds.play(event, target)` with the spec in `EVENTS`
  and the event in `HOOKS`; no new `core.sound_play` for game events. Mob voices,
  ability cues, beds, loops and music are data (`_grug_voice`,
  `grug_abilities.CAST_SOUNDS`, `grug_ambience/data.lua`); music tracks live in
  `grug_ambience/music/` and are pushed on demand.
- **Downloads:** reuse downloaded material first, access Freesound serially
  with HQ previews only, never delete or move downloaded source material.

### Quests, main line, rift and decor

- **The main line** follows the approved
  [story bible](docs/planning/round36/story-bible.md); the final turn-in ids
  `accord_main_final` / `throng_main_final` are fixed and chapter gates come
  from `requires` ([quests.md](docs/design/quests.md) "The main line").
- **"Use at a place"** is an objective, never a node (`grug_quests/use.lua`).
  Other mods hear turn-ins through `grug_quests.register_on_turn_in`, never a
  second completion path; `grug_quests.quest_held` is the cheap "has or did"
  query.
- **The rift is runtime content** (`grug_mobs/rift_core.lua`), its crack one of
  the two recorded exceptions to POI protection, besides NPC door use
  ([world.md](docs/design/world.md) §4b).
- **Decor is a kit** (`grug_mapgen/wp13/decor_kit.lua`): authored rows placed
  whole or failing the build; it never changes a composition's bounds, sockets
  or protection box, never blocks a window or a way; `tools/r36_w` holds every
  composition to `baseline.tsv` ([settlements.md](docs/design/settlements.md)
  "Decor pass").

### World generation

- The WP40 R7 pipeline in `grug_mapgen` is the only mapgen owner (seams and the
  boundaries tests must cross:
  [module guide](docs/technical/module-guide.md#mapgen-and-biomes)). Test mapgen
  work on a **fresh world**.
- **Engine-run budget** (user, 2026-09-28): portable fixtures are the main
  proof; a few engine runs of at most about 5 minutes; one final run of about 15
  minutes over a chosen small region (ocean, coast, mountain, one start),
  bounded by region and ended by a normal shutdown. Never a full world or a
  repeated long run; reviewers read the receipts. Derive bounds from parameters
  instead of scanning; more goes to the user first.
- The **seed fleet** gates world-generation changes
  ([round workflow](docs/process/round-workflow.md#3-gates)); a change that only
  places, swaps or turns nodes needs no run.
- **One layout assembly** (Round 37): `wp40/world_assembly.lua` is the world's
  layout wiring; `r7_runtime.lua`, every portable tool and the seed fleet build
  on it, never on a copy. The seed fleet (`tools/seed_fleet/runtime.lua`)
  builds the real runtime and plans and writes five chunks per seed through
  `plan_slice` and the writer against a fake VoxelManip, about 25 s per seed
  (`quick` about 6 minutes at 6–8 parallel, `full` about 17 minutes). A
  `fail()` on the per-chunk path fails the fleet and the fixtures, so it must
  pass `quick`; on a live server it no longer stops the server: the chunk
  keeps the engine's terrain and is reported through `grug_core.severe`
  (`wp40/degrade.lua`, Round 41).
- **Decorations are owner-only:** tall trees are lost in height bands
  (emergent jungle trees: no ground at y ≡ 15..50 mod 80) and on 2–4-node
  lines along chunk borders
  ([R6 contract](docs/research/wp40-simple-map-r6-contract.md) §8.2,
  "Treeless bands"); the fix is a BACKLOG item.

## Licenses

- **Code: GPL-3.0-or-later** (`LICENSE.txt`; [licensing
  research](docs/research/licensing.md)). Compatible inputs: MIT, Apache-2.0,
  LGPL-2.1/3.0, GPL-2.0-or-later, GPL-3.0. **Never GPL-2.0-only.**
- **Media keep their original license** (CC0, CC BY, CC BY-SA, GPL), one
  `LICENSE-media.md` row per file (author, source URL, exact license and
  version, modifications); attribution authors also in [CREDITS.md](CREDITS.md).
  **Never NC or ND media.**
- Verify a license **in the source repo** before importing; ContentDB metadata
  can be wrong. Asset lists: [docs/research/assets/](docs/research/assets/).
- **Never copy assets or names 1:1 from existing commercial games**; own assets
  and names, "inspired by", not "copied" (and see "Naming").

## Testing & development

- **Fixtures:** `tools/run_fixtures.sh` runs every portable fixture under
  LuaJIT; a new one takes the repository path as `arg[1]` and exits non-zero on
  failure. Fixture and probe folders per round:
  [tools/README.md](tools/README.md).
- **Seed fleet:** `tools/seed_fleet/run.sh quick|full`; when each is required:
  [round workflow](docs/process/round-workflow.md#3-gates).
- **The user's GUI install** is a Flatpak (`org.luanti.luanti`, no access to
  `~/projects`): `tools/sync_to_luanti.sh` copies the game to
  `~/.var/app/org.luanti.luanti/.minetest/games/grudgelands`; the coordinator
  syncs from main after merges, never from a branch unless the user asks. The
  user's runtime errors are diagnosed from `debug.txt` in that folder.
- **Agent engine runs never touch that personal folder** (2026-09-14: the user's
  client may be running, and two instances on one folder can crash). Boot only
  through `tools/luanti_headless.sh` or with the same guarantees: a fresh temp
  directory as `LUANTI_USER_PATH` **and** all XDG dirs, the log inside it, a
  `timeout --kill-after`, cleanup, `LC_ALL=C` (the launcher exports it), and at
  the end `pgrep -f '^luanti.bin'` showing no server of yours. Kill only your
  own run. A launcher that falls back to the personal folder when
  `LUANTI_USER_PATH` is empty is a defect; the WP40 profiler
  (`tools/wp40/profile/run.sh`) needs a launcher that forwards its path.
- Read the relevant [module guide](docs/technical/module-guide.md) section
  before touching a module; never infer current behaviour from an old report.
- Server log via `core.log("action"|"warning"|"error", msg)`. An error the
  server survives but an administrator must see goes through the one
  severe-error helper `grug_core.severe.report(source, summary, details, key)`
  (`grug_core/severe.lua`): an error line with the literal prefix
  `[GRUG-SEVERE]` and a red chat message to every player once per key; the
  mapgen environment loads the same file by `dofile` and its chat part
  reaches the main thread through gen_notify.
