# C10 — Cross-cutting architecture

**Scope:** all of `mods/` (about 177k Lua lines in 55 mods, six modpacks), read
wide rather than deep: engine hooks and their ordering, globalsteps, ABMs/LBMs,
mod storage, engine-function overrides, the mod dependency graph, globals,
duplication across mods, the vendored `mods/BASE/` against upstream, `tools/`
and legacy code. Per-area internals belong to lanes C1–C9; findings here stay at
the architecture level and point at areas.

**Baseline:** `0f169898` (main). The working tree was clean when the lane
started and no file changed under review.

**Method:** static only. Inventories were generated with grep and small scripts
in the lane scratch dir: `luac51 -l` bytecode listings for every `.lua` under
`mods/` (SETGLOBAL/GETGLOBAL), a Python dependency check that maps each
GETGLOBAL to its owning mod and compares it with the `mod.conf` closure, a
simulation of Luanti's mod load order
(`reference_projects/luanti/src/content/mod_configuration.cpp:217-316`), and
`diff -U0` of `mods/BASE/*` against `reference_projects/minetest_game`
(`b5243f3`) with a marker-proximity check. `tools/check_fresh_server.py` was
run (PASS). No engine runs, no fixtures run, no luacheck (not installed; the
only `.luacheckrc` is the vendored `mods/ENTITIES/mobs/.luacheckrc`).

**Out of scope:** mapgen algorithms, mob AI, combat numbers, quest content,
HUD layout and item rules (C1–C9); upstream code in `mods/BASE` itself.

## Summary

- **The code is disciplined at the language level.** Exactly one SETGLOBAL per
  mod across all 55 mods, no undeclared global reads, no `minetest.` in our
  mods, no `goto`/5.2+ syntax (parser clean on every file). The two exceptions
  to "one global per mod" are by design: `grug_quality` publishes `grug_items`
  and `grug_core` publishes `grug_zones` through `rawset` (X-12).
- **Load order is load-bearing and only partly declared.** `mod.conf` describes
  a clean layered graph (no cycles), but 16 mod pairs reference a higher layer
  at runtime without a dependency (X-07), and several `register_on_mods_loaded`
  overrides only work because of the engine's current, undeclared ordering
  (X-05). Simulated order: `grug_jobs` 34th, `grug_housing` 38th.
- **Engine functions are overridden from feature mods.** `core.is_protected`
  (two layers), `core.show_formspec` (two layers), `core.create_detached_inventory`,
  `core.node_dig`, `core.calculate_knockback`, `core.register_on_craft` /
  `register_craft_predict`, plus first-step `rawset` wrapping of every
  registered node's callbacks. There is no single list of them (X-04).
- **Every periodic pass is throttled and most per-player passes are sliced**
  (46 globalsteps, see inventory). The remaining every-step work is upstream
  `player_api`, the minimap glide (deliberate, measured in the R32 perf review)
  and a few trivial resets. Per-player state is cleaned on leave (a heuristic
  scan for name-keyed tables without a `nil` clear found none).
- **The vendored "upstream + wrapper" model holds for `mods/BASE`** (every diff
  hunk sits next to a `GRUG PATCH` marker and is in VENDOR.md) **but not for
  mobs_redo**, which is a de facto fork: `api.lua` is 1,150 lines longer than
  upstream with 155 diff hunks (X-06).
- **Vendored minetest_game ABMs still mutate the world** (grass spread, grass
  cover, moss) and authored settlement ground uses exactly the nodes they
  target (X-02). The project already hit this once (dawnmere fields) and fixed
  it per instance.
- **Fail-closed load audits are everywhere** (467 `... differs` failures in 63
  files, 51 of them in `grug_mapgen`), including self-pinned SHA-256 digests
  and magic population counts outside mapgen; a data edit can stop the server
  at startup (X-08).
- **Two "mob level at pos" APIs with different meaning** (`grug_zones.mob_level_at`
  is the analytic field, `grug_core.mob_level_at` the gameplay truth with the
  spawn-region overlay); spawn checks in five mob files use the field (X-03).
- **No shared formspec-session layer.** Each module keeps its own session table;
  two of them monkeypatch `core.show_formspec` to notice replacement. The jobs
  furnace workspace re-shows its form every second and pushes the recipe book
  away (X-01, the one player-visible bug found by this lane).

## Inventories

### 1a. Globalsteps (46)

"Gate" is the accumulator interval; "Per player" says whether one pass touches
every connected player. All but the five marked *every step* follow the AGENTS
throttle rule.

| # | Mod | File:line | What it does | Gate | Per player |
|---|-----|-----------|--------------|------|------------|
| 1 | default (vendor) | `BASE/default/functions.lua:318` | reset `in_dig_up` flag | every step | no (trivial) |
| 2 | player_api (vendor) | `BASE/player_api/api.lua:246` | player animations + GRUG override hook | every step | **all players** (upstream) |
| 3 | mobs (vendor) | `ENTITIES/mobs/api.lua:203` | `grug_obstacle.begin_server_step` (A* budget reset) | every step | no (trivial) |
| 4 | grug_mobs | `spawn_regions.lua:1105` | region spawner attempts | 1 s / 4 slices | players sliced 1/4 |
| 5 | grug_mobs | `rares.lua:316` | rare watch/respawn | 10 s | no (per rare) |
| 6 | grug_mobs | `start_npcs.lua:1601` | settlement NPC placement/heal | 5 s | no (per row) |
| 7 | grug_mobs | `boss_dragons.lua:322` | arena hazards, ice break, scorch | 0.25 s (+1 s) | all players |
| 8 | grug_mobs | `target_frame.lua:216` | target frame HUD | 0.5 s | players with a frame |
| 9 | grug_mobs | `bosses.lua:765` | dragon respawn/warn (mod storage) | 10 s | no |
| 10 | grug_mobs | `rift.lua:471` | rift spawns/particles near site | 1 s | rift players |
| 11 | grug_traders | `vendors.lua:655` | vendor slot upkeep vs player positions | 5 s | all players (positions) |
| 12 | grug_farming | `init.lua:555` | natural renewal tick | 0.5 s | renewal round-robin |
| 13 | grug_fishing | `init.lua:236` | bobber bites | 0.2 s | active casts |
| 14 | grug_map | `location.lua:382` | location line/banner sample | 0.1 s, 1 s per player phase | all players (phased) |
| 15 | grug_map | `page.lua:388` | Map tab redraw budget | 0.1 s, 2 builds/pass | open Map tabs |
| 16 | grug_map | `minimap.lua:493` | minimap glide | **every step** | **all players** (deliberate; R32 perf review) |
| 17 | grug_quests | `use.lua:320` | use-objective hold + object visibility | 0.1 s hold, 0.2 s × 5 slots | players sliced |
| 18 | grug_quests | `hud.lua:162` | quest tracker | 0.1 s × 5 slots | players sliced |
| 19 | grug_inventory | `pages.lua:471` | Character page effects/home text | 1 s | all players (cheap check) |
| 20 | grug_inventory | `equipment.lua:1073` | raw-weapon LMB hint | 0.1 s | **all players** (control + wield read) |
| 21 | grug_classes | `selection.lua:655` | creation stasis reassert | 0.1 s | creation sessions |
| 22 | grug_parties | `init.lua:346` | invitation expiry | 1 s | invitations |
| 23 | grug_parties | `hud.lua:136` | party HUD | 0.1 s × 5 slots | players sliced |
| 24 | grug_pvp | `page.lua:81` | PvP tab refresh on change | 1 s | all players (cheap check) |
| 25 | grug_pvp | `init.lua:297` | location tick (flag, territory) | 1 s | all players |
| 26 | grug_housing | `stone_form.lua:496` | draft countdown re-show | 1 s | stone sessions |
| 27 | grug_housing | `stone.lua:227` | draft/expiry scan, stone node sync | 5 s | all claims |
| 28 | grug_housing | `interface.lua:140` | Character status refresh | 10 s | all players |
| 29 | grug_jobs | `discovery.lua:73` | inventory discovery scan | 2 s | **all players**, full `get_lists()` |
| 30 | grug_jobs | `workspaces.lua:392` | station advance + form refresh | 1 s | workspace viewers |
| 31 | grug_visuals | `apply.lua:433` | wielded-item visual sync | 1 s | all players |
| 32 | grug_home | `waypoints.lua:181` | waystone discovery by proximity | 1 s | all players |
| 33 | grug_abilities | `scout.lua:438` | bow draw | 0.05 s | drawing players |
| 34 | grug_abilities | `kits.lua:982` | Mend HoT | 3 s | mends |
| 35 | grug_abilities | `init.lua:2447` | LMB hold machine, ready reticle, crosshair (0.15 s) | 0.05 s | **all players** |
| 36 | grug_abilities | `init.lua:2475` | mana/rage regen, wield watch | 0.5 s | all players |
| 37 | grug_core | `combat_hud.lua:9` | in-combat icon | 0.2 s | all players |
| 38 | grug_core | `environment_damage.lua:131` | drowning/suffocation/lava | 1 s | all players (`get_properties`) |
| 39 | grug_core | `tag_carrier.lua:370` | nametag carriers | 1/8 s × 8 slots | objects sliced |
| 40 | grug_core | `atmosphere_zones.lua:537` | sky/fog per zone | 0.25 s × 8 slots | players sliced |
| 41 | grug_core | `movement.lua:682` | movement states (stun, slow, dash) | 0.1 s | active states |
| 42 | grug_core | `feed.lua:241` | message feed expiry | 0.1 s | active feeds |
| 43 | grug_core | `atmosphere.lua:256` | world clock + day/night ratio | 1 s | all players |
| 44 | grug_core | `status.lua:463` | status icons advance/HUD | 0.5 s | all players |
| 45 | grug_core | `starts_preload.lua:164` | world preparation driver | every step until ready | no |
| 46 | grug_ambience | `init.lua:412` | ambience beds/music | 0.25 s × 8 slots | players sliced |

Steady per-player polling that is not sliced: rows 2, 16, 20, 29, 35 (each
reads player state at ≥ 0.5 Hz for every player). Rows 20 and 29 are the only
ones that duplicate data another pass or hook already reads (X-13).

### 1b. ABMs and LBMs

| Kind | File:line | Nodenames | Interval / chance | Action cost / note |
|------|-----------|-----------|-------------------|--------------------|
| ABM | `BASE/default/functions.lua:166` | lava source/flowing (neighbours cools_lava, water) | 2 / 2, catch_up false | set obsidian/stone; negligible |
| ABM | `BASE/default/functions.lua:259` | `default:cactus` near sand | 12 / 83 | grow; **no catch_up=false** (upstream) |
| ABM | `BASE/default/functions.lua:270` | `default:papyrus` | 14 / 71 | grow; no catch_up=false |
| ABM | `BASE/default/functions.lua:615` | `default:dirt` next to air | 6 / 50 | light check, `find_node_near`, `set_node` → **rewrites authored bare dirt (X-02)** |
| ABM | `BASE/default/functions.lua:662` | `group:spreading_dirt_type`, dry dirt w/ grass | 8 / 50 | grass under solid → dirt |
| ABM | `BASE/default/functions.lua:697` | cobble + cobble stairs/slabs/walls near water | 16 / 200 | → mossy; **human roads are `default:cobble`** (X-02) |
| ABM | `ENTITIES/mobs/spawner.lua:159` | `mobs:spawner` | 10 / 4 | admin spawner node only |
| ABM ×3 | `ENTITIES/grug_mobs/spawn_abms.lua:198` | merged spawn groups (hull of rows) | shortest row interval / derived C | one roll dispatches a row; replaces 88 per-row ABMs (R30 P2). `mobs:spawn()` calls are captured into these rows |
| ABM | `ENTITIES/mobs/api.lua:4874` | per `mobs:spawn` spec | — | upstream path; rows are routed to the merged ABMs |
| LBM | `BASE/default/chests.lua:283` | open chests | every load | close on load (upstream) |
| LBM | `ENTITIES/grug_mobs/camps.lua:716` | guard banner | every load | init meta (VM-written nodes get no on_construct) |
| LBM | `ENTITIES/grug_mobs/camps.lua:738` | camp fire | every load | init meta + arm timer |
| LBM | `ENTITIES/mobs/api.lua:4840` | per spawn spec with `map_load` | once | upstream; unused by our rows |
| LBM | `ITEMS/grug_farming/init.lua:115` | crop soil | every load | start hydration timer if stopped |
| LBM | `ITEMS/grug_farming/init.lua:465` | crop roots | every load | repair multi-node crop geometry |
| LBM | `PLAYER/grug_jobs/station_nodes.lua:141` | 5 profession stations | every load | on_construct if inventory missing |
| LBM | `PLAYER/grug_jobs/station_nodes.lua:196` | default furnace (+active) | every load | init public hearths |
| LBM | `PLAYER/grug_jobs/workspaces.lua:544` | every station node | every load | workspace init, active/inactive swap, timer |

All LBMs are current-version activation (VM-written nodes get no
`on_construct`), which AGENTS allows. Mapgen registers no runtime ABM/LBM.

### 1c. Engine callbacks with several registrants

| Event | Count | Registrants (mods) | Does order matter? |
|-------|------:|--------------------|--------------------|
| `on_leaveplayer` | 80 | 33 mods | no (cleanup only) |
| `on_mods_loaded` | 59 | 28 mods | **yes**: overrides that replace callbacks (X-05); `grug_pvp/page.lua:483` relies on sfinv page order after `grug_parties` |
| `on_joinplayer` | 45 | 24 mods | mildly: HUD creation vs creation stasis (`grug_classes`) |
| `on_dieplayer` | 32 | 17 mods | yes in principle (PvP kill credit, XP, mount teardown); no conflict seen |
| `on_player_receive_fields` | 21 | 12 mods | first `true` stops; every handler checks its own `formname` |
| `on_player_hpchange` | 10 | 7 mods | **one modifier only** (`grug_core/combat.lua:1783`, `true`); the other nine are observers — good design |
| `on_equipment_change` (grug_core seam) | 9 | 7 mods | no |
| `on_player_inventory_action` | 6 | 4 mods | no |
| `on_shutdown` | 6 | 5 mods | no |
| `on_respawnplayer` | 5 | 5 mods | OR of results; `grug_core` owns placement |
| `on_craft` | 5 | default, grug_gear, grug_jobs (3) | **yes**: `grug_jobs` forces its gate to be last by re-appending and by wrapping `core.register_on_craft` (`grug_jobs/stations.lua:138-152`) |
| `on_punchplayer` | 2 | grug_factions, grug_abilities | **yes** (short-circuit OR): same-faction cancel in `grug_factions/init.lua:317` runs first because grug_abilities depends on grug_factions |
| `on_item_pickup` | 2 | grug_gear, grug_inventory | first non-nil wins; `grug_gear/init.lua:790` returns only for weapons, `grug_inventory/bags.lua:289` only for arrows — disjoint today |
| `on_placenode` / `on_dignode` / `on_punchnode` | 1–2 | xpanes, creative, grug_materials | no |

The project also defines 25+ of its own `register_on_*` registries
(`grug_core` 10, `grug_classes` 3, `grug_pvp` 2, `grug_mobs` 2, one each in
xp, money, parties, housing, jobs, mounts, factions, materials, plus
`grug_quests.register_on_change/turn_in/markers_changed`).

### 1d. Mod storage users

| Mod | File | Keys | Growth |
|-----|------|------|--------|
| grug_mobs | `rares.lua:55`, `spawn_regions.lua:1039`, `start_npcs.lua:495`, `rift.lua:133`, `bosses.lua:720`, `boss_dragons.lua:1207` | `rare_*:<id>`, `leader_next:<role>`, start-NPC slot placed/due, rift crack/due, `boss:dragon:<id>:*` | bounded by world content |
| grug_housing | `api.lua:12`, `registry.lua:131-192` | `claim:<id>`, `player:<name>`, `next_id` | one per claim/player; removed claims set to `""` |
| grug_parties | `init.lua:2-32` | one serialized `parties` blob, rewritten on every change | bounded by players; **asserts on load** — an invalid blob stops the server (Noted) |
| grug_home | `claim_home.lua:13` | `lost:<name>` notices | cleared on delivery |
| grug_repair | `runtime.lua:5` | `item_serial` counter | constant |
| grug_core | `starts_preload.lua:3` | one preparation state blob | constant |

No unbounded growth found. Player data lives in player meta as AGENTS says
(not reviewed here; C8).

### 1e. `core.after` chains

27 call sites outside vendored code. Self-rescheduling: only the poison tick
(`grug_mobs/verbs.lua:274-279`), bounded by a count and a generation token.
First-step installs via `core.after(0, …)` from `on_mods_loaded`:
`grug_housing/interaction.lua:175` (wrap every node's interaction callbacks),
`grug_housing/protection.lua:87` (wrap `on_punch`/`on_dig` of buildable_to
nodes), `grug_jobs/stations.lua:180` (finalize craft authority),
`grug_mapgen/init.lua:55`, `grug_mobs/start_npcs.lua:1630`. Per-trip timeout:
`grug_home/travel.lua:111` (30 s, guarded by phase).

### 1f. Overrides of engine/builtin functions

| Function | Where (in load order) | Chains previous? |
|----------|-----------------------|------------------|
| `core.calculate_knockback` | `BASE/player_api/api.lua:199` (upstream), `grug_mobs/boss_dragons.lua:654-660` | yes |
| `core.show_formspec` | `BASE/default/node_formspec.lua:92`, `grug_housing/stone_form.lua:31-38` | yes |
| `core.sound_play` | `ENTITIES/mobs/api.lua:5553` | yes; **only when `mobs_can_hear ~= false`** — off via the game's `minetest.conf:78` |
| `core.is_protected` | `grug_core/protection.lua:61`, then `grug_housing/protection.lua:42` | yes (captured once) |
| `core.node_dig` | `grug_materials/mining.lua:596` (audited at `audit.lua:416`) | yes |
| `core.create_detached_inventory` | `grug_housing/soulbound.lua:78` | yes |
| `core.register_craft_predict`, `core.register_on_craft` | `grug_jobs/stations.lua:138-152` (after first step) | yes, re-appends its gate |
| `core.handle_node_drops` | `BASE/creative/init.lua:86` (upstream) | yes |
| node defs via `rawset` | `grug_housing/interaction.lua:130` (every node: right-click, fields, allow_metadata_*), `grug_housing/protection.lua:76` (buildable_to on_punch/on_dig) | yes, at first step |
| node defs via `override_item` at load | 32 sites in 14 mods, e.g. `grug_core/water_guard.lua:60` (every floodable node's `on_flood`), `grug_housing/soulbound.lua:29-50` (every node's allow_put/move), `grug_jobs/workspaces.lua:471` (stations, **replaces** allow_* without chaining) | mostly yes |

## 2. Mod dependency graph

- **No cycles** (depends + optional_depends, among shipped mods).
- **Layering as declared:** BASE → `grug_sounds` → `grug_core` → `grug_xp`,
  `grug_money` → ITEMS base (`grug_materials`, `grug_nodes`, `grug_trees`,
  `grug_gathering`) → `grug_mapgen` → `grug_factions` → `grug_classes`,
  `grug_visuals`, `grug_inventory` → `grug_mobs` → feature mods. Simulated load
  order (engine algorithm, no `random_mod_load_order`): sfinv, creative,
  player_api, default, grug_trees, grug_gear, grug_decor, mobs, grug_sounds,
  grug_core, grug_xp, grug_money, … grug_mapgen (25), grug_factions (26), …
  grug_mobs (31), grug_quests (32), grug_pvp (33), grug_jobs (34), grug_mounts
  (35), … grug_housing (38), grug_home (39), grug_map (40), … grug_alchemy (54).
- **Undeclared upward references** (runtime only, so they work; X-07):
  `grug_core`→`grug_mobs` (`combat.lua:481`), →`grug_mapgen`
  (`starts_preload.lua:71`); `grug_xp`→`grug_classes` (`init.lua:96`);
  `grug_factions`→`grug_xp` (`init.lua:72,135`), →`grug_home` (`:298`);
  `grug_gear`→`grug_core`, `grug_classes`, `grug_inventory`, `grug_xp`
  (`init.lua:735,807`, `permissions.lua:31`) although its `mod.conf` says only
  `default`; `grug_classes`→`grug_inventory` (`talents_ui.lua:149`);
  `grug_visuals`→`grug_inventory` (`apply.lua:335`); `grug_jobs`→`grug_quality`
  (`station_operations.lua:23`, `workspaces.lua:129`); `grug_mobs`→`grug_home`,
  `grug_mounts`, `grug_quests` (`start_villagers.lua:1044-1093`,
  `capital_displays.lua:96`); vendored `mobs`→`grug_mobs` (57 refs),
  `grug_core` (17), `grug_sounds` (4) through GRUG PATCH sites.
- **Unshipped optional deps:** vendored `mobs` lists ten (tnt, invisibility,
  lucky_block, cmi, toolranks, mtobjid, visual_harm_1ndicators, mcl_sounds,
  mesecons, vizlib) — harmless, but `lucky_block.lua` and the cmi/toolranks
  branches are dead weight (X-15).
- **Declared but never referenced as a global:** many (for example
  `grug_mapgen` → stairs, doors, xpanes, beds, wool, vessels, walls, grug_decor,
  grug_trees, grug_brewing). Nearly all are legitimate: they guarantee that the
  node names a mod writes are registered first. Not a finding.

## 3. Duplication across mods (overview)

| Helper | Copies | Canonical? |
|--------|-------:|------------|
| formspec escape wrapper `esc` | 11 mods (some without `tostring`, e.g. `grug_inventory/pages.lua:5`, `grug_traders/trade.lua:39`) | `core.formspec_escape`; no shared nil-safe wrapper |
| give-or-drop (`add_item("main")` then `core.add_item(pos)`) | 8+ sites, 4 policies (main+drop, main+bags+drop, refuse with refund, quiver-first) | `grug_inventory.refund_ammo` is arrow-only; no general one (X-09) |
| NPC service gate `permitted(player, entity)` | 4 (`grug_traders/crown.lua:198`, `grug_mounts/trainer.lua:23`, `grug_housing/manager.lua:67`, `grug_home/innkeeper.lua:2`) | none; faction check centrally at click (`start_villagers.lua:1037`) |
| `first_line(text)` | 4, different semantics (translated / plain_text / raw) | `grug_core.item_name` family for items |
| wall-clock `now()` (`get_us_time()/1e6`, `os.time`, `os.clock`) | 8 + 4 local `now` | `grug_core.mono_time` (`combat.lua:427`) |
| deep copy | 8 (`copy`, `deep_copy`, `copy_table`) | builtin `table.copy` (mapgen copies exist for portable fixtures) |
| callback registry (`register_on_*` + loop) | 25+ | none; each mod rolls its own |
| formspec session tracking | jobs, traders, repair, mounts, housing, quests, node_formspec … | none; two `core.show_formspec` monkeypatches (X-01) |
| zone lookup | `grug_zones.*` (façade), `grug_core.zone_at/territory_at/mob_level_at` (overlay), `grug_pvp.territory_at`, `grug_map` region | **two level APIs with different results** (X-03) |

## 4. Globals

SETGLOBAL listing over every `.lua` in `mods/`: exactly one name per mod (53
names for 55 mods; `grug_quality` sets `grug_items`, `mobs` sets `mobs`), plus
`grug_zones` via `rawset(_G, …)` in `grug_core/zone_authority.lua:391`. Every
GETGLOBAL name is either a standard/engine global, a mod global, or an
optional-integration global of vendored mobs (`cmi`, `toolranks`, `tnt`,
`invisibility`, `lucky_block`, `mcl_*`, `mesecon`, `VH1`). No typo globals.
`tools/check_lua.sh` prints SETGLOBAL per file but does not fail on it; that is
enough given the clean state. No luacheck config for our code.

## 5. `mods/BASE` against upstream (`minetest_game` b5243f3)

| Mod | Changed files | Hunks | Hunks > 8 lines from a marker | Removed upstream files | VENDOR.md |
|-----|--:|--:|--:|--|--|
| beds | 5 | 14 | 6 (continuations of the header block) | functions.lua, spawns.lua | yes |
| creative | 1 | 1 | 0 | — | yes |
| default | 8 (+ new `node_formspec.lua`) | 48 | 26 (furnace/bookshelf rewrites under one block marker) | aliases.lua, legacy.lua | yes |
| doors | 2 | 14 | 0 | models/door.blend | yes |
| dye, walls, wool | 1 each | 1 | 0 | — | yes |
| player_api | 1 | 5 | 3 (inside the marked override block) | — | yes |
| sfinv | 1 | 3 | 0 | — | yes |
| stairs | 1 | 5 | 0 | — | yes |
| vessels | 2 | 11 | 6 (shelf rewrite under one marker) | steel bottle texture | yes |
| xpanes | 2 | 9 | 1 | — | yes |

Every "unmarked" hunk is a continuation of a marked block; nothing undocumented
was found. `default/mapgen.lua` keeps ~2,480 lines of upstream biome/ore/
decoration functions that are defined but never called (X-15).

## 6. `tools/`

143 directories, 16 MB. Shared entry points (from `tools/README.md`):
`run_fixtures.sh`, `seed_fleet/run.sh`, `check_lua.sh`,
`check_fresh_server.py` (PASS on the baseline), `luanti_headless.sh`,
`sync_to_luanti.sh`, `r35_t/upstream_check.sh`, the POI renderers
(`r36_p`, `r36_w`) and the data checks AGENTS names (`r28_design/validate.py`,
`r28_regions/run.sh`, `r29_e4/income.py --check`, `r33_ds/build_doc.py
--check`). Everything else is per-round lane fixtures (`r10_*` … `r36_*`,
`wp13`, `wp26`, `wp40`, `pt_fixes`, `r8_mob1`). Static staleness probe: of 209
`mods/...` paths named by tools, 7 no longer exist; five are deliberate "must be
absent" checks (`check_fresh_server.py:8-12`, `r33_c2/portable_test.lua:317`),
one is an optional load of the removed `grug_core/zone_bands.lua`
(`r28_world/world.lua:44`). `luanti_headless.sh` still exposes
`R8_CAVE_WRITER_DISABLED`, which is a no-op because the writer is off by
default (X-11).

## 7. Legacy (overview)

Dead or no-op: the R8 cave-mouth writer (off by default since `65e43286`,
2026-09-19), the R8 native-baseline measurement mode inside the production
`on_generated` (`r7_mapgen.lua:72-86`), default's v6/biome tail, mobs hearing
vines and `lucky_block.lua`. Names that no longer match: `grug_items`,
`grug_mobs.registered_cadence`, zone authority "compatibility adapters",
R-numbered mapgen files. Ceremony from the WP40 contract era that now costs
more than it protects: self-pinned digests and magic counts (X-08). No old
save-format readers or migrations were found (`check_fresh_server.py` PASS; the
grep for migrate/legacy/compat in our mods finds only comments and the
historical `grug_items` name).

## Findings table

| ID | Sev | Category | Title | Location |
|----|-----|----------|-------|----------|
| X-01 | Medium | Bug | Furnace workspace re-shows its form every second and pushes the recipe book (or any other form) away | `PLAYER/grug_jobs/workspaces.lua:354,392-397,226-241` |
| X-02 | Medium | Bug | Vendored grass-spread and moss ABMs rewrite authored settlement ground and cobble roads | `BASE/default/functions.lua:615,697`; `MAPGEN/grug_mapgen/wp13/palette.lua:102,190,326,666`; `wp13/decor_kit.lua:482-489`; `wp40/road_writer.lua:35` |
| X-03 | Low | Agent-trap | Two `mob_level_at` APIs; spawn checks use the field, gameplay uses the overlay | `CORE/grug_core/zone_authority.lua:411-470`; `ENTITIES/grug_mobs/spawn_policy.lua:785` and four mob files |
| X-04 | Low | Agent-trap | Engine functions and every node definition are patched from feature mods, with no inventory | see 1f |
| X-05 | Low | Agent-trap | `on_mods_loaded` overrides that replace callbacks depend on undeclared load order | `PLAYER/grug_jobs/workspaces.lua:465-500,535`; `PLAYER/grug_housing/soulbound.lua:29-50,84` |
| X-06 | Medium | Legacy | mobs_redo is a de facto fork, not a vendored tree with a wrapper | `ENTITIES/mobs/api.lua`; `VENDOR.md:531` |
| X-07 | Medium | Agent-trap | `mod.conf` understates coupling: 16 undeclared upward references, three lookup idioms | section 2 |
| X-08 | Low | Legacy | Self-pinned digests and magic population counts turn data edits into startup crashes | `ITEMS/grug_gathering/catalog.lua:7-12`, `init.lua:33-38`; `ITEMS/grug_farming/init.lua:565`; 467 `differs` checks |
| X-09 | Low | Duplication | Give-or-drop reimplemented with four different policies | see section 3 |
| X-10 | Low | Duplication | Small helpers copied across mods (esc, first_line, now, deep copy, service gate) | see section 3 |
| X-11 | Low | Legacy | Settings that no longer switch anything (R8 cave writer, native baseline) | `MAPGEN/grug_mapgen/wp40/r6_settlement.lua:1028-1032,2845`; `wp40/r7_mapgen.lua:72-86`; `tools/luanti_headless.sh:138-143` |
| X-12 | Low | Legacy | Names that no longer describe the code | `ITEMS/grug_quality/init.lua:3-24`; `ENTITIES/grug_mobs/init.lua:137`; `CORE/grug_core/zone_authority.lua:411` |
| X-13 | Low | Perf | Redundant per-player polling (weapon hint 10 Hz, discovery full-inventory scan 2 s) | `PLAYER/grug_inventory/equipment.lua:1073`; `PLAYER/grug_jobs/discovery.lua:50-77` |
| X-14 | Low | Legacy | Mixed formspec coordinate systems (sfinv legacy + v3/v4/v6) | `BASE/sfinv/api.lua:54`; 13 files with `formspec_version` |
| X-15 | Low | Legacy | Dead vendored code shipped and loaded | `BASE/default/mapgen.lua`; `ENTITIES/mobs/lucky_block.lua`, `crafts.lua:321-344`; `mobs/mod.conf` |
| X-16 | Low | Convention | Style drift: 12 files use one-space indentation and `;`-chained lines | `PLAYER/grug_home/*.lua`, `ENTITIES/grug_mobs/capital_displays.lua`, … |

## Findings

### X-01 Furnace workspace re-shows its form every second and pushes the recipe book away

- **Severity** High / **Category** Bug / **Confidence** Plausible (traced
  statically end to end; not seen in a GUI).
- **Location:** `mods/PLAYER/grug_jobs/workspaces.lua:392-397` (1 s pass),
  `:226-241` (`refresh` → `core.show_formspec`), `:354` (book button, no
  detach), `:359` (repair button, detaches); `mods/PLAYER/grug_jobs/ui.lua:819-831`
  (`open_book`), `:957-963` (book quit clears only the book session).
- **What:** the workspace pass calls `refresh(ctx, ctx.station == "furnace" or
  ctx.station == "dual_furnace")` for every registered viewer each second, and
  `refresh` calls `core.show_formspec(ctx.name, FORM, …)` whenever the player is
  still within 8 nodes. Pressing the station's book button
  (`grug_jobs.station_book_button`, rendered on every station form) opens the
  book with `core.show_formspec(name, "grug_jobs:book", …)` but leaves the
  viewer registered (contrast the repair button, which calls `detach(ctx)`
  first). Within one second the furnace form replaces the book. Closing the
  book with Esc also brings the furnace back a second later. The same applies
  to any other form shown to the player while a furnace viewer is registered.
- **Impact:** the recipe book is effectively unusable from a furnace or dual
  furnace (normal play), and a closed station "reopens itself".
- **Better (S):** detach (or mark the ctx hidden) before opening the book,
  like the repair path; or only re-show when the station form is the one
  currently open. Longer term (M): one shared "current form per player" record
  (the job that `default/node_formspec.lua:92` and
  `grug_housing/stone_form.lua:31` each do with their own `core.show_formspec`
  monkeypatch), so periodic re-shows can ask "is my form still open?". Risk:
  low; C9 should confirm in the GUI.
- **Verification (phase 2):** Confirmed, severity changed to Medium — same defect as PLY-03 in [08-player-systems.md](08-player-systems.md), verified there (`workspaces.lua:354` opens the book without detaching; the 1 s pass at `:392-401` re-shows the form via `:240`). Annoying but not harmful; one severity for both.

### X-02 Vendored grass-spread and moss ABMs rewrite authored settlement ground and roads

- **Severity** Medium / **Category** Bug (world mutation) / **Confidence**
  Verified for the mechanism, Plausible for how visible it is per settlement.
- **Location:** `mods/BASE/default/functions.lua:615-650` ("Grass spread":
  `default:dirt` next to air, light ≥ 13, a `spreading_dirt_type` within 1 →
  becomes that node), `:697-711` ("Moss growth": cobble and cobble
  slab/stair/wall next to `group:water`); palettes
  `mods/MAPGEN/grug_mapgen/wp13/palette.lua:102` (dwarf `ground_bare =
  default:dirt`, next to `dirt_with_grass` patches), `:190` (human
  `ground_patch = default:dirt` inside `ground = default:dirt_with_grass`),
  `:326` (elf), `:666` (troll); `wp13/decor_kit.lua:482-489` (Round 36 claw
  scrapes write `ground_bare` furrows into turf; used by the rare-route POIs in
  `wp40/r20_poi_catalog.lua:72-78`, two of them dwarf/troll = `default:dirt`);
  `wp40/road_writer.lua:35` (human roads `default:cobble` / `stairs:slab_cobble`).
- **What:** the vendored minetest_game growth ABMs run world-wide, including in
  towns, capitals, POIs and roads, which the project otherwise treats as
  immutable (world protection, water guard, "never damage towns/POIs"). Every
  authored bare-dirt patch bordered by grass greens over from its edge (per node
  roughly 1/50 every 6 s once a neighbour is grass, so minutes while a player is
  near), and cobble road or path blocks next to water turn mossy. The project
  hit this once already: `palette.lua:274-283` switched the field furrows to
  `grug_farming:soil` because "a field ... greened over row by row while the
  player watched", and `grug_nodes/init.lua:17` keeps `spreading_dirt_type`
  off our dirt family for the same reason. The other `default:dirt` roles were
  not converted.
- **Impact:** authored looks (beaten earth, dirt patches, Round 36 scrapes)
  disappear during play; roads by rivers change material. Cosmetic, but it
  silently undoes reviewed decor work.
- **Better (S):** add a territory check to the two ABMs through a GRUG PATCH
  (`grug_core.natural_ground_alterable(pos)` already exists and is what
  natural renewal uses), or switch the authored roles to a non-spreading node
  (a `grug_nodes` bare-dirt twin without `spreading_dirt_type`). The first
  fixes all present and future roles at once. Risk: low; the patch must stay in
  VENDOR.md.
- **Verification (phase 2):** Confirmed (Medium) — both ABMs are unpatched (`BASE/default/functions.lua:615-651`, `:697-711`), and nothing in `mods/` edits `registered_abms` or filters them by territory. `default:dirt` is still bound at `wp13/palette.lua:102,190,326,666`. The repo's own comments record the effect being seen (`palette.lua:274-283`, `dressing.lua:495-503`: fields "greened over ... while the player watched"). ABMs run only in active blocks, so the effect concentrates where players are, in towns and on roads.

### X-03 Two `mob_level_at` APIs with different results

- **Severity** Medium / **Category** Agent-trap (latent bug) / **Confidence**
  Verified (APIs), Plausible (player-visible mismatch at region borders).
- **Location:** `mods/CORE/grug_core/zone_authority.lua:417-445`
  (`grug_core.mob_level_at`: region overlay first, "One level truth for
  gameplay"); the façade `grug_zones.mob_level_at` (analytic field, no
  overlay); overlay registered at `mods/ENTITIES/grug_mobs/spawn_regions.lua:390`.
  Field callers in gameplay code: `grug_mobs/spawn_policy.lua:785`
  (`natural_min_levels`, shore crab vs reef lurker split),
  `speargrass_tiger.lua:4`, `zero_asset_variants.lua:25,137`,
  `start_zone_families.lua:29`. Overlay callers: `grug_mobs/levels.lua:379`,
  `bandit.lua:140`, `grug_fishing/catch.lua:48`.
- **What:** a mob's actual level comes from the overlay (its region's level),
  but several spawn gates decide by the field. Where the two differ (region
  belts, borders), a gate can refuse a row the recipe intends or admit one at a
  level the mob will not have. AGENTS says "a zone's level band is its mapgen
  zone record (served by `grug_zones`)", which points a new agent at the field
  API.
- **Impact:** subtle spawn mismatches; every new spawn check is a coin toss
  between the two.
- **Better (S):** move the five gameplay callers to `grug_core.mob_level_at`
  (or make the façade's name say "field"), and add one line to AGENTS'
  "Zone content" section naming the gameplay API. C5 should judge whether any
  of the gates is still needed now that spawns go through region recipes.
- **Verification (phase 2):** Partly confirmed, severity changed to Low. The two APIs exist (`zone_authority.lua:417-445`), but no mismatch reaches play today. The overlay answers only inside recipe zones (`spawn_regions.lua:372-390`), and all 38 `data/zones/*.spawns.json` have a recipe. In a recipe zone, `spawn_policy_allows` (`spawn_policy.lua:771-784`) refuses every non-critter ABM row before the per-mob `_grug_spawn_check` runs (`grug_mobs/init.lua:348-360`). The fox, ibex, tapir, scorpion, viper, poacher, husk and tiger are not critters. `spawn_policy.lua:785` is reached only outside recipe zones, where the overlay is nil and both APIs agree. So the field gates are effectively dead code, and the trap is only for future gates.

### X-04 Engine functions and every node definition are patched from feature mods, with no inventory

- **Severity** Medium / **Category** Agent-trap / **Confidence** Verified.
- **Location:** table 1f; notably `grug_housing/stone_form.lua:31-38`
  (`core.show_formspec`), `grug_housing/soulbound.lua:78`
  (`core.create_detached_inventory`), `grug_housing/interaction.lua:130,174-176`
  and `protection.lua:76,86-87` (`rawset` wrappers on all node definitions at
  the first server step), `grug_jobs/stations.lua:138-152` (wraps the engine's
  craft registration functions), `grug_mobs/boss_dragons.lua:654-660`
  (`core.calculate_knockback`, a global flag `slam_hit`).
- **What:** these are correct individually (each chains the previous handler),
  but they live in feature files, two of them install on the first step via
  `core.after(0)` and wrap through `rawset`, and the module guide has no list of
  them. An agent adding a node callback in `on_mods_loaded` of a mod that loads
  late, or calling `core.override_item` after the first step, does not know its
  callback is wrapped (or that it must be).
- **Impact:** wrong assumptions when debugging protection, inventory or form
  behaviour; easy to add a third `show_formspec` patch instead of reusing one.
- **Better (S):** one section in `docs/technical/module-guide.md` (or the
  upstream-workarounds file's sibling) listing every override, its order and
  its install time, with a fixture that asserts the chain at startup
  (`grug_materials/audit.lua:416` already does this for `node_dig`).
- **Verification (phase 2):** Confirmed, severity changed to Low — the overrides exist and each one chains (`grug_housing/stone_form.lua:31-38`, `grug_mobs/boss_dragons.lua:652-660`, `grug_jobs/stations.lua:138-152`). `docs/technical/module-guide.md:713` already names the knockback wrapper. With nothing broken today, the harm is debugging time, which fits Low better than Medium.

### X-05 Overrides that replace callbacks depend on undeclared load order

- **Severity** Medium / **Category** Agent-trap / **Confidence** Verified
  (order simulated from the engine's algorithm).
- **Location:** `mods/PLAYER/grug_jobs/workspaces.lua:471-500` (station nodes
  get new `allow_metadata_inventory_put/take/move` via `override_item`,
  **without** calling the previous ones) from its `on_mods_loaded` at `:535`;
  `mods/PLAYER/grug_housing/soulbound.lua:29-50,84` wraps every node's
  `allow_put/move` in its own `on_mods_loaded` and sets `_grug_soulbound_guard`.
- **What:** neither mod depends on the other. Today `grug_jobs` loads 34th and
  `grug_housing` 38th, so the soulbound wrapper ends up outside the station
  callbacks and works. If the order flips (a new dependency edge, an optional
  dep, or a developer enabling `random_mod_load_order`), `grug_jobs` replaces
  the soulbound wrapper while the `_grug_soulbound_guard` flag stays set, and a
  Claim Stone can be put into a public station's node inventory. The
  interaction guard handles the same risk explicitly (comment at
  `interaction.lua:168-176`, `core.after(0)`), the soulbound wrapper does not.
- **Impact:** a latent rule break that appears from an unrelated `mod.conf`
  edit.
- **Better (S):** make `grug_jobs` chain previous `allow_*` callbacks, or move
  the soulbound wrap into the same first-step install as the interaction guard,
  or declare `grug_jobs` as an optional dependency of `grug_housing`. A
  one-time check under `random_mod_load_order = true` would surface other such
  pairs.
- **Verification (phase 2):** Confirmed, severity changed to Low. The mechanism holds: `grug_jobs/workspaces.lua:494-500` replaces `allow_*` without chaining, and `grug_housing/soulbound.lua:27-50,84` wraps once and sets the guard flag. There is no `depends`/`optional_depends` path in either direction, checked transitively over all `mod.conf`. `grug_housing/interaction.lua:168-176` even notes that grug_jobs "may run after this mod". But the current order works, and a break needs an unrelated dependency change or `random_mod_load_order`, so this is latent.

### X-06 mobs_redo is a de facto fork

- **Severity** Medium / **Category** Legacy / **Confidence** Verified.
- **Location:** `mods/ENTITIES/mobs/api.lua` (5,640 lines vs upstream 4,486;
  155 diff hunks; 122 `GRUG PATCH` markers), `mods/ENTITIES/mobs/grug_obstacle.lua`
  (new file), `VENDOR.md:531` (one ~10 KB table cell describing the patches).
- **What:** AGENTS and VENDOR.md describe vendored trees as "upstream plus a
  minimal patch surface, prefer wrapper mods", with re-applying patches on
  update. For mobs_redo that no longer holds: the combat, pathing, water,
  physics, sound and death paths are rewritten in place and call into
  `grug_mobs`/`grug_core` 78 times. An upstream update is not realistic, and
  the VENDOR row is too dense to use as the patch list it is meant to be.
- **Impact:** agents follow the vendored-code rules (minimal edits, markers,
  wrappers first) on code the project actually owns, and spend effort keeping
  marker counts current. Unused upstream features (hearing override, lucky
  block, cmi/toolranks branches, spawner node) stay loaded.
- **Better (M):** declare the tree an owned fork in VENDOR.md (keep the
  upstream commit for licence/provenance), move the patch narrative into a
  structured file per subsystem, and allow removing unused upstream branches.
  No code change is required to make the decision; a later cleanup can then
  shrink `api.lua`.
- **Verification (phase 2):** Confirmed (Medium) — `api.lua` has 5,640 lines against upstream's 4,486 (`reference_projects/mobs_redo/api.lua`). A diff gives 155 hunks, and the file holds 122 `GRUG PATCH` markers. `VENDOR.md:531` is one 11.6 KB line. I count 67 direct `grug_mobs.`/`grug_core.` references in `api.lua`; the lane's 78 likely includes other mods and files.

### X-07 `mod.conf` understates coupling

- **Severity** Medium / **Category** Agent-trap / **Confidence** Verified.
- **Location:** section 2 (16 pairs). Example: `mods/ITEMS/grug_gear/mod.conf`
  declares only `default`, while `grug_gear/init.lua:735,807` uses `grug_core`,
  `grug_inventory`, `grug_xp`, and `permissions.lua:31` uses `grug_classes`.
  Three lookup idioms side by side in
  `mods/ENTITIES/grug_mobs/start_villagers.lua:1043-1093`: direct
  (`grug_home.open_innkeeper`), `rawget(_G, "grug_housing")`,
  `core.global_exists("grug_quests")`.
- **What:** all uses are at runtime (callbacks, `on_mods_loaded`), so the game
  works, but a reader of `mod.conf` sees a layering that the code does not
  follow, and a fixture that loads one mod alone fails in surprising places.
  The idioms differ in failure mode: a direct reference crashes if the mod is
  absent, `rawget` silently skips, `global_exists` skips.
- **Impact:** agents misjudge what a change to a "low" mod can break, and copy
  whichever idiom they see first.
- **Better (S):** pick one idiom for upward calls (the seam pattern AGENTS
  already uses for PvP: the higher mod installs a hook into the lower one) and
  list the existing upward edges in the module guide. Converting all 16 is M
  and optional.
- **Verification (phase 2):** Confirmed (Medium) — `grug_gear/mod.conf` declares `depends = default`, and its description says "nothing else here reads another mod". Yet `init.lua:735` calls `grug_core.level_scale`, `:799-807` uses `grug_inventory`, `grug_xp` and `grug_core` (in `on_mods_loaded`), and `permissions.lua:31` uses `grug_classes`. All three idioms appear in `grug_mobs/start_villagers.lua:1044-1093`.

### X-08 Self-pinned digests and magic population counts

- **Severity** Medium / **Category** Legacy (agent-trap) / **Confidence**
  Verified.
- **Location:** `mods/ITEMS/grug_gathering/catalog.lua:7-12` (SHA-256 of
  `nodes.lua`, `harvest.lua` and of the catalog's own canonical bytes as
  literals) checked at `init.lua:33-35`; `init.lua:36` (`#registered_nodes ~=
  12`); `mods/ITEMS/grug_farming/init.lua:565` (`#crops ~= #grug_cooking.PLANTS
  + 2`); `grug_traders/vendors.lua:594`; 467 `"... differs"` fail-closed
  checks in 63 files (51 in `grug_mapgen`, which is C1/C2's to judge).
- **What:** editing a catalog row stops the server at startup until the
  literal digest is recomputed by hand; editing `nodes.lua` does not fail at
  all, so the stored file digest silently lies (it matches today only because
  `c9645ac9` updated both). Population counts must be bumped together with
  content. These checks date from the WP33/WP40 contract era, when they guarded
  frozen evidence; today the fixtures and `validate.py` do that job.
- **Impact:** a correct content change crashes the game for the user, or an
  agent "fixes" the digest without understanding it. Fresh-server mode and the
  fixture runner make the guard redundant.
- **Better (S):** drop the self-digests and population literals outside
  mapgen (keep the structural asserts), or derive the expected values from the
  data. For mapgen, ask C1/C2 which digests still protect a cache key (those
  are legitimate, AGENTS "World-folder caches").
- **Verification (phase 2):** Confirmed, severity changed to Low. The literals at `grug_gathering/catalog.lua:7-12` match the current files (sha256sum), and only the manifest is re-checked (`init.lua:33-38`), so the file digests are never verified. The 467 checks in 63 files are confirmed. The same digest is pinned a second time in mapgen (`r7_manifest.lua:341-346`), and the 12/8 counts again at `r7_p9g.lua:108-110`. AGENTS.md mandates digests only as cache keys (`:607-611`) and calls the frozen R6 artifacts historical evidence (`:277-279`), so these pins are legacy, not current policy. Low, because the failure comes at once and loudly on the first boot after an edit and never reaches players.

### X-09 Give-or-drop reimplemented with four policies

- **Severity** Low / **Category** Duplication / **Confidence** Verified.
- **Location:** drop-at-feet: `grug_quests/state.lua:564-570`,
  `grug_fishing/init.lua:216-217`, `grug_farming/init.lua:334-337`,
  `grug_artisans/goldsmith.lua:134-136`, `grug_housing/stone_form.lua:236-240`,
  `grug_housing/api.lua:293-294`; refuse-and-refund: `grug_traders/trade.lua:410-418`;
  queue: `grug_mobs/bosses.lua:145`; quiver-first: `grug_inventory/bags.lua:271-284`.
- **What / Impact:** each site decides on its own whether bags count, whether
  arrows go to the quiver, whether items drop or are refused, and whether the
  weapon tooltip is initialised. Examples: the quest reward `give`
  (`grug_quests/state.lua:564-571`) fills main and bags but neither the quiver
  nor `grug_gear.initialize_weapon_tooltip`, which the vendor path does
  (`grug_traders/trade.lua:408`); most other sites fill `main` only.
- **Better (S):** one `grug_inventory.give(player, stack, {policy=…})` that
  initialises the tooltip, fills the quiver for arrows and applies the policy.

### X-10 Small helpers copied across mods

- **Severity** Low / **Category** Duplication / **Confidence** Verified.
- **Location:** section 3 table.
- **What / Impact:** trivial individually; the risk is the variants
  (`esc` without `tostring` errors on nil; three `first_line` semantics; four
  clocks). **Better (S):** a few helpers in `grug_core` (`esc`, `now`) when the
  files are next touched; no dedicated round.

### X-11 Settings that no longer switch anything

- **Severity** Low / **Category** Legacy / **Confidence** Verified.
- **Location:** `mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua:1028-1032`
  (`grug_mapgen_r8_cave_writer_disabled`, default **true**) and `:2845` (the
  only use), plus `r8_plan_cave` at `:538`; `wp40/r7_mapgen.lua:72-86`
  (`grug_mapgen_r8_native_baseline`, a measurement mode inside the production
  `on_generated`); `tools/luanti_headless.sh:50-54,138-143`. Neither setting is
  in `settingtypes.txt`.
- **What / Impact:** the cave-mouth writer has been off since `65e43286`
  (2026-09-19) and the headless flag that "disables" it is a no-op. Dead code in
  the hottest mapgen file, two hidden settings.
- **Better (S):** remove the writer and its flag, or document the setting if it
  is meant to come back (C1 decides).

### X-12 Names that no longer describe the code

- **Severity** Low / **Category** Legacy / **Confidence** Verified.
- **Location:** `mods/ITEMS/grug_quality/init.lua:3-24` (mod `grug_quality`
  publishes the global `grug_items`, "historical API name"; quality 3 "Rare" is
  the gold tier, 4 "Unique" reserved); `mods/ENTITIES/grug_mobs/init.lua:137`
  (`grug_mobs.registered_cadence` is the registry of grug mobs, 18 uses, named
  after the cadence gate removed in WP38); `mods/CORE/grug_core/zone_authority.lua:411-470`
  ("explicit compatibility adapters … R4 compatibility payload" are the
  production `zone_at`, `territory_at`, `mob_level_at`); R-numbered mapgen file
  names (`r6_settlement.lua`, `r7_*`, `r20_*`, `r31_*`).
- **Impact:** grep for "quality" misses the API; "compatibility" invites
  deletion under the fresh-server rule. **Better (S–M):** rename when the area
  is touched; at minimum a line in the module guide.

### X-13 Redundant per-player polling

- **Severity** Low / **Category** Perf / **Confidence** Verified (cost not
  measured).
- **Location:** `mods/PLAYER/grug_inventory/equipment.lua:1073-1090` (10 Hz,
  every player: `get_player_control` + `get_wielded_item` only to show a hint),
  while `grug_abilities/init.lua:2447` already reads controls at 20 Hz for every
  player; `mods/PLAYER/grug_jobs/discovery.lua:73-77` (every 2 s, every player:
  `inventory:get_lists()` of all lists, one ItemStack per slot) although
  `:68-71` already rescans after every inventory action.
- **Impact:** at 100 players roughly 1,000 extra wield reads/s and 3,000
  ItemStacks/s; small next to the minimap and input passes, but pure overhead.
- **Better (S):** drive the hint from the LMB state machine's fresh-press event;
  make the discovery scan event-driven (inventory action + the few `add_item`
  sources) or slice it like the quest tracker.

### X-14 Mixed formspec coordinate systems

- **Severity** Low / **Category** Legacy / **Confidence** Verified.
- **Location:** `mods/BASE/sfinv/api.lua:54` (`size[8,9.1]`, legacy
  coordinates for every inventory page), `formspec_version[3]` ×3, `[4]` ×13,
  `[6]` ×1 elsewhere; geometry comments explaining legacy spacing in
  `grug_inventory/pages.lua:101-106,195`, `ui.lua:1`, `help.lua:168-169`,
  `grug_pvp/page.lua:6`, `grug_jobs/character_tab.lua:48`, `grug_map/page.lua:5-6`.
- **Impact:** every page author re-derives the legacy spacing maths; layout
  bugs are a recurring GUI-test theme. **Better (M):** a future UI round could
  move sfinv pages to real coordinates; until then a short "which coordinate
  system does this form use" note in the module guide.

### X-15 Dead vendored code shipped and loaded

- **Severity** Low / **Category** Legacy / **Confidence** Verified.
- **Location:** `mods/BASE/default/mapgen.lua` (~2,480 lines of biome, ore and
  decoration registration functions; only the `mapgen_*` aliases are used,
  the v6 branch at `:2487` cannot run under `allowed_mapgens = v7`);
  `mods/ENTITIES/mobs/lucky_block.lua` (optional dep not shipped),
  `mobs/crafts.lua:321-344` (hearing vines, hearing is off);
  `mobs/mod.conf` (ten unshipped optional deps).
- **Better (S):** keep as is if upstream diffability matters for BASE (it does
  per VENDOR policy); for the mobs fork (X-06) remove.

### X-16 Style drift

- **Severity** Low / **Category** Convention / **Confidence** Verified.
- **Location:** one-space indentation in 12 files, e.g.
  `PLAYER/grug_home/{travel,waypoints,waypoints_core,claim_home,innkeeper}.lua`,
  `ENTITIES/grug_mobs/capital_displays.lua`, `ITEMS/grug_gear/permissions.lua`,
  `ITEMS/grug_repair/presentation.lua`, `MAPGEN/grug_mapgen/world_nodes.lua`;
  `;`-chained statements in `PLAYER/grug_jobs/discovery.lua`.
- **Better (S):** reformat when touched; not worth a pass on its own.

## Agent pitfalls

1. **Looking for the level of a place in `grug_zones`.** `grug_zones.mob_level_at`
   is the mapgen field; the level a mob actually gets is
   `grug_core.mob_level_at` (region overlay). Example: a new
   `_grug_spawn_check` copied from `speargrass_tiger.lua:4` gates by the wrong
   number (X-03).
2. **Writing `default:dirt` or `default:cobble` into a composition.** The
   vendored ABMs rewrite them in play (X-02). The project's own note at
   `wp13/palette.lua:274` tells the story; use a non-spreading node.
3. **Overriding node callbacks in `on_mods_loaded` without chaining.** Other
   mods wrap the same callbacks in their own `on_mods_loaded` or on the first
   step; whether yours ends up inside or outside depends on load order (X-05).
   Example: `grug_jobs/workspaces.lua:493` replaces `allow_metadata_inventory_put`.
4. **Re-showing a form from a timer without checking it is still open.**
   Example: X-01. The two `core.show_formspec` monkeypatches exist precisely
   because of this; there is no shared session API.
5. **Reading `mod.conf` as the dependency truth.** `grug_gear` "depends on
   default only" but calls four higher mods (X-07). Load a mod alone in a
   fixture and it fails.
6. **Treating mobs_redo like an upstream tree.** Searching upstream docs for
   behaviour of `api.lua` is misleading; 155 hunks change it (X-06). Read the
   vendored file and VENDOR.md's round sections.
7. **Editing a catalog and starting the game.** `grug_gathering` refuses to
   load on a digest mismatch; `grug_farming` on a crop count (X-08). Change the
   literal deliberately or, better, remove the pin.
8. **Assuming "compatibility" or "legacy" in a name means removable.** The zone
   authority's "compatibility adapters" are the live API; `registered_cadence`
   is the live mob registry (X-12). Conversely, legacy *formspec* coordinates
   are a live constraint of sfinv (X-14).
9. **Trusting AGENTS.md's top for conventions.** Its first 240 lines are round
   status; the conventions start at "Project conventions" (line 516) and the
   per-round rules after it. The module guide (1,491 lines) has no index of
   seams or overrides (X-04).

## Noted (no action)

- **Water guard revert loop.** `grug_core/water_guard.lua:65-81` swaps a guarded
  liquid change back with `core.swap_node`, which re-queues neighbouring liquids
  (`reference_projects/luanti/src/servermap.cpp:464-476`). At a guarded
  water-air contact this flips once per liquid step for as long as the block is
  active. Only reachable where a guarded water edge meets air (normally none;
  the perf review measured the batch cost at 3.5–9.5 µs). For C6/C1 to keep in
  mind, not to fix.
- `grug_parties/init.lua:4-30` asserts on the stored blob at load; a corrupt
  entry stops the server. Fresh-server mode makes this acceptable.
- Cactus and papyrus ABMs lack `catch_up = false` (upstream). Negligible.
- `core.sound_play` is overridden by vendored mobs unless `mobs_can_hear` is
  false; the game's `minetest.conf:78` sets it, which is a game default a server
  operator could change.
- Callback registries (25+) differ in error handling; none is hot enough to
  matter.
- `grug_zones` façade methods are vararg closures over the session
  (`zone_authority.lua:331-345`); fine at today's call rates.

## Open questions for Jan

1. **mobs_redo:** may it be declared an owned fork (VENDOR.md keeps provenance,
   the "minimal patch" rule stops applying), so unused upstream code can go?
   (X-06)
2. **Growth ABMs in protected ground:** should grass spread and moss stop in
   towns, capitals, POIs and roads (one GRUG PATCH using the existing territory
   rule), or are the authored dirt patches meant to green over? (X-02)
3. **Self-digests outside mapgen:** may the fixed SHA-256 and population pins in
   `grug_gathering`/`grug_farming` go, now that fixtures guard the content?
   (X-08)
