# AGENTS.md — Project Guide

WoW-inspired Luanti game (working title "World of Blockcraft"). Goals and
scope: **[ROADMAP.md](ROADMAP.md)**. Work packages and status:
**[BACKLOG.md](BACKLOG.md)**. Detailed research notes on the reference
projects: **[docs/research/](docs/research/)**.

## Language rules

- **All Markdown documentation in this repo is written in English.**
  Exception: `docs/research/` contains older German reference notes; they
  may stay German until substantially rewritten.
- Chat with the user is in **German**; code identifiers and code comments
  are in English.

## Documentation layers

All project state lives in the repo, not in the chat history. Three layers,
strictly separated:

1. **`docs/design/`** — the *decided* game design (living spec: rules,
   numbers, lists only — no open questions, no discussion).
2. **`TODO-<topic>.md`** (repo root) — *open* design questions: context,
   options, recommendation, decision state. When every question in a file
   is decided, fold the results into `docs/design/` (and update
   ROADMAP/BACKLOG where affected), then **delete the TODO file**.
3. **[BACKLOG.md](BACKLOG.md)** — implementation work packages (WPs). WPs
   reference `docs/design/` instead of inventing design on the fly.

## Working method (sessions & context)

1. **Session start**: read BACKLOG.md, pick the next open WP (or the one
   the user names). Check for `TODO-*.md` files that block it. Skim the
   relevant docs/research/ briefings.
2. **One WP per session** is the norm — coherent, testable, committed.
   Offload large explorations to subagents, keep the main context lean.
3. **WP completion**: Lua syntax check (`luajit -e "assert(loadfile(...))"`),
   `tools/sync_to_luanti.sh`, commit, update BACKLOG status + ROADMAP
   checkboxes. Anything future sessions need to know goes into
   AGENTS.md/docs — not just the chat.
4. **Runtime tests are done by the user** (Flatpak Luanti, GUI); diagnose
   errors via `~/.var/app/org.luanti.luanti/.minetest/debug.txt`.

## Project structure

- We are building a **standalone game** (not a mod pack, not a fork of
  minetest_game/VoxeLibre). The game will eventually live in a layout like
  `games/<gameid>/` with `game.conf`, `menu/`, `mods/`, `settingtypes.txt`.
- **Third-party code is vendored, never a submodule** (decided 2026-08-06):
  every embedded foreign mod is documented in **[VENDOR.md](VENDOR.md)**
  (upstream repo + commit + license + patch list); in-place changes carry a
  `-- WOB PATCH:` marker at the change site; prefer wrapper mods
  (`wob_mobs` pattern) over in-place edits. Details/update procedure:
  VENDOR.md.
- `reference_projects/` contains **references only — never change anything
  in there**:
  - `luanti/` — the engine itself (C++ + builtin Lua). API reference:
    `reference_projects/luanti/doc/lua_api.md` (~12,700 lines, THE source).
  - `Lord-of-the-Test/` — best faction reference (privileges + ally matrix,
    faction-aware mob AI, traders).
  - `VoxeLibre/` — best architecture reference (XP system, villager
    trading, map rendering, modpack structure).
  - `minetest_game/` — minimal base game (node/tool palette in
    `mods/default`).
  - `mobs_redo/` — mob engine (MIT license → we may fork/embed it).

## Lua & Luanti environment (IMPORTANT)

- **Lua 5.1 — and plain-5.1 compatibility is a HARD requirement** (decided
  2026-08-06): the engine prefers **LuaJIT** but silently falls back to
  bundled Lua 5.1.5, and our code must run on both. Full reference incl.
  do-not-write checklist:
  **[docs/research/luanti-lua.md](docs/research/luanti-lua.md)**. Key rules:
  - **No `goto`**, no `\u{...}`/`\x..`/`\z` string escapes (LuaJIT-only),
    no integer division `//`, no bitwise operator syntax (`&`, `|`) —
    use `bit.*` (engine-injected, both builds, 32-bit).
  - `unpack` (not `table.unpack`); `table.pack`/`rawlen`/`__len`/`__pairs`
    are unsafe even on LuaJIT (need a distro compat flag) — avoid.
  - Numbers are C doubles, no integer type; safe integer range ±(2^53−1).
  - Vector `==` only works if BOTH operands carry the vector metatable —
    compare positions with `vector.equals`, never `==`.
  - Backported from 5.4 (engine-injected, both builds):
    `string.pack`/`unpack`/`packsize`.
- Engine version of the reference checkout: **Luanti 5.17.0-dev** (git
  checkout after 5.16).
- **Use the `core.*` namespace** — `minetest.*` is only a deprecated alias.
- **All game logic runs server-side.** Mods run on the server only;
  definitions/media are transferred to clients automatically. SSCSM
  (server-sent client-side mods) is still a stub in the engine — do not use.
- **Sandbox** (with `secure.enable_security`): fully available are
  `coroutine`, `string`, `table`, `math`, `bit`; `io`/`os`/`debug` are
  heavily restricted (no `os.execute`/`os.exit`); **`require` is disabled
  outright**; `dofile`/`loadfile` may READ the game dir and all mod dirs
  (write access is world dir/mod-data only — details in
  docs/research/luanti-lua.md). `core.request_insecure_environment()`
  only via `secure.trusted_mods` — we don't need it.
- **Globally injected helpers** (builtin): `dump()`, `string.split`,
  `string:trim()`, `table.copy/indexof/insert_all/shuffle`,
  `math.round/sign/hypot`, `vector.*` (metatable-based, overloaded
  operators: `vector.new/add/distance/direction/normalize/...`),
  `core.after(sec, fn)`, `core.serialize/deserialize`,
  `core.parse_json/write_json`.
- The engine's `strict.lua` warns about undeclared globals — declare mod
  globals explicitly (one global table per mod, see conventions).

## Game/mod anatomy

- `game.conf`: `title` (required), `description`, `first_mod`/`last_mod`,
  `allowed_mapgens`/`default_mapgen`, `disabled_settings` (e.g.
  `!enable_damage` forces PvE damage), `author`, `textdomain`.
- Every mod: `mod.conf` (`name`, `depends`, `optional_depends`) +
  `init.lua`. Media in `textures/ sounds/ models/ locale/` (names:
  `a-zA-Z0-9_.-`; models `.b3d/.obj/.gltf/.glb`, sounds `.ogg`).
- Registered names are always `modname:name`; `:foo:bar` overrides a
  foreign registration (requires a dependency).
- We use modpacks (folders with `modpack.conf`) for grouping like
  VoxeLibre: `CORE/`, `PLAYER/`, `ENTITIES/`, `ITEMS/`, `MAPGEN/`, `HUD/`.

## Project conventions

- **Namespace prefix `wob_`** for all our mods (e.g. `wob_xp`,
  `wob_factions`, `wob_quests`, `wob_jobs`, `wob_mobs`, `wob_map`).
- Exactly one global table per mod (`wob_xp = {}`), sub-files via
  `dofile(core.get_modpath(core.get_current_modname()).."/foo.lua")`.
- Custom fields in item/node/entity definitions use the `_wob_` prefix
  (pattern from VoxeLibre's `_mcl_*`).
- Dispatch behavior via **groups** instead of name lists (VoxeLibre
  pattern).
- Persistence:
  - Player data (race, class, faction, XP, level, talents, jobs, gold,
    quest state, map exploration) → `player:get_meta()` (PlayerMetaRef,
    auto-persisted). Complex structures via `core.serialize` as string.
  - Mod-wide data → `core.get_mod_storage()` (fetch at load time).
  - Node data (workstations) → `core.get_meta(pos)`.
- Performance rules (distilled from VoxeLibre):
  - **Always** throttle `register_globalstep` with a dtime accumulator.
  - Node timers for machines/workstations (forge, alchemy).
  - LBMs for one-shot load fixes/migrations.
  - ABMs only for ambient random events, throttled via `chance`/`interval`,
    `catch_up = false` where possible.
  - In hot loops use `core.get_node_raw`/content IDs + VoxelManip instead
    of `get_node`.

## Key APIs for our features (quick reference)

Details + line numbers in [docs/research/](docs/research/).

- **Factions**: pattern from Lord of the Test `lottclasses` — faction as a
  **privilege** + ally matrix + predicates (`*_same_race_or_ally`),
  selection formspec on join (re-prompt on abort), starter-kit dispatch.
  LotT has NO per-faction spawns and no player-PvP gating — we build those
  ourselves (`core.register_on_punchplayer` /
  `register_on_player_hpchange`).
- **XP/levels**: template VoxeLibre `mods/HUD/mcl_experience/init.lua` — XP
  as an int in player meta, `level_to_xp` curve, `register_on_add_xp`
  pipeline, HUD bar. XP loss on death via `core.register_on_dieplayer`.
- **Combat/classes**: damage = damage_groups × armor_groups (÷100) ×
  punch-interval factor. **Damage pipeline lives in `wob_core/combat.lua`**
  (WP4): `deal_ability_damage` (crit ×1.5, applied via `object:punch` with
  full punch interval so armor/knockback/XP keep working), `heal_player`,
  central dodge roll (hp-change modifier), `mark_in_combat/in_combat`
  (5 s window), threat stubs `add_threat`/`add_heal_threat` (WP6 fills
  them). Crit/dodge accessors are wob_core stubs overridden by
  wob_classes. Abilities = hotbar tools in `wob_abilities` (item `range` =
  targeting range, wear bar = cooldown display); kits/numbers:
  `docs/design/classes.md`. **mobs_redo `do_punch` gotcha**: any truthy
  return cancels the punch (api.lua comment claims the opposite) — hook
  wrappers must return nil; player-hit hook:
  `wob_core.register_on_player_hit_mob` (fired by wob_mobs).
- **Mobs**: embed and patch mobs_redo (MIT). Faction targeting: condition
  in `general_attack()` (api.lua:1699ff) following the LotT pattern
  (`race` field in the mob def + ally check); territory/tier gating via
  `mobs:spawn_abm_check()`. Tiers via `hp_max`/`armor` (lower = tougher)/
  `damage`/`view_range`/`group_attack`. Dynamic loot: `drops` can be a
  function. Quest kill credit: `on_death(self, killer)`.
  Quest/trader NPCs: `type="npc"`, `passive`, `on_rightclick` → formspec;
  placement via `mobs:add_mob(pos, def)`.
  **Pathfinding is a quality criterion** (user requirement: dangerous mobs
  must not fail at terrain, otherwise they are not dangerous): mobs_redo
  has `pathfinding = 1|2` (uses `core.find_path`, 2 = can break/build
  nodes) plus `stepheight`/`jump_height`/`fear_height` — always enable and
  test these when tuning mobs. VoxeLibre `mcl_mobs` has its own, more
  advanced `pathfinding.lua` (+ the villagers' `gopath`) — if mobs_redo
  pathfinding is not good enough, adapt from there (GPL ok, see below).
  Fallback design: additionally make heartland mobs fast (`run_velocity`)
  and give them ranged attacks (`attack_type = "dogshoot"`) so terrain
  exploits are not trivial.
- **Loot/enchantments**: class items (wand, mage/warlock robe, iron
  armor/sword, dagger, …) drop with **random roll ranges** (e.g. strength
  +1..+3, attack speed +5..+20%). Implementation like VoxeLibre
  `mcl_enchanting`: store the rolls in **item meta** (`stack:get_meta()`),
  generate the description via meta key `description` with the rolled
  values (pattern `_mcl_generate_description`). Effect: attack speed via
  `tool_capabilities.full_punch_interval` in the stack meta override;
  apply stats to player stats on equip/swap. Drop source: a `drops`
  function in the mob def rolls on kill (base variant everywhere, improved
  variant with better ranges only on elite/heartland mobs).
- **Traders/gold**: templates VoxeLibre `mobs_mc/villager.lua` (trade
  tiers, detached inventory `wanted/input/offered/output`) and LotT
  `lottmobs/trader.lua` (faction-dependent stock). Money is ONE integer
  in copper units in player meta (100c = 1s, 100s = 1g, conversion is
  display-only; `docs/design/economy.md`); traders buy EVERY mob drop
  (buy-price field `_wob_sell_price` in item defs).
- **Quests**: no ready-made framework in the references. Building blocks:
  trigger/counter patterns from `lottachievements` (awards fork), event
  stages from VoxeLibre `mcl_events` (`cond_start/on_step/cond_complete`),
  quest log as a formspec, state in player meta, quest givers via NPC
  `on_rightclick`, HUD `waypoint` elements for quest targets.
- **Mapgen/biomes** (decided + built in WP2): engine biomes on mapgen v7,
  territory/race-region confinement via the biome definition's
  `min_pos`/`max_pos` cuboids (works on x/z, not just y!). Bands overlap
  by 200 nodes; inside the overlap the heat/humidity voronoi picks, which
  gives organic transitions. `wob_mapgen` owns all biome/ore/decoration
  registrations; default's `register_biomes/ores/decorations` are NOT
  called (see tail of `mods/BASE/default/mapgen.lua`).
  **Landmine**: ore/decoration defs whose `biomes` names don't resolve
  are silently unrestricted (world-wide) — never register ores/decos
  against biome names that might not exist. `game.conf` pins
  `allowed_mapgens = v7`. Camp platforms (terrain-adaptive height:
  heightmap median, persisted in mod storage) + the x=±2000 mountain wall
  are a small `register_on_generated` VoxelManip pass
  (`wob_mapgen/structures.lua`). **NB the wall and the land borderland
  are scheduled for removal — continent redesign (two ocean-separated
  continents, world.md §1, WP18).** Zone/difficulty queries:
  `wob_core.territory_at/zone_at/difficulty_at/mob_level_at`.
  LotT trick: biome signature nodes (e.g. grass variants) drive mob spawns
  via a node whitelist.
- **Map/fog of war**: VoxeLibre `mcl_maps` renders explored chunks as PNG
  (`colors.json`, height shading) and pushes them via
  `core.dynamic_add_media` — the best base for our global map. Minimap
  gating: `hud_set_flags{minimap=...}` (pattern: minetest_game `map`).
- **UI**: formspecs (`core.show_formspec` +
  `register_on_player_receive_fields`), set `formspec_version` +
  `real_coordinates[true]`. 3D character preview: `model[]` element.
  Skill tree = formspec with an `image_button` grid.
- **Player model/skins**: `player:set_properties{visual="mesh", mesh=...,
  textures={...}}`; texture layering (skin/armor/wielditem) following
  LotT `lottarmor/multiskin.lua`.

## Licenses

- **Code: GPL-3.0-or-later** (decided 2026-07-03 as "GPL", made precise
  2026-08 — full text in `LICENSE.txt`; rationale and compatibility
  matrix in [docs/research/licensing.md](docs/research/licensing.md)).
  Compatible code inputs: MIT, Apache-2.0, LGPL-2.1/3.0 (also "-only"),
  GPL-2.0-or-later, GPL-3.0. **Hard exclusion: GPL-2.0-only code.**
- **Media: keep each file's original license** (CC0 / CC BY / CC BY-SA /
  GPL), documented per mod in a `LICENSE-media.md` table: file, author,
  source URL, exact license + version, modifications made. **Never NC or
  ND media.** When we accumulate more sources, add a top-level
  `CREDITS.md` (Mineclonia model).
- Before importing anything, verify the license **in the source repo**
  (LICENSE/README files) — ContentDB metadata can be wrong (real case:
  a CC BY-NC sound hidden inside the otherwise-clean ambience mod).
- Asset shopping lists with verified licenses:
  [docs/research/assets/](docs/research/assets/).
- **Never copy WoW assets/names 1:1** — Blizzard IP. Own assets, own names
  with a recognizable character ("inspired by", not "copied").

## Testing & development

- Local testing: Luanti is installed as a **Flatpak** (`org.luanti.luanti`,
  sandboxed without access to `~/projects`!). Therefore run
  `tools/sync_to_luanti.sh` — it copies the game to
  `~/.var/app/org.luanti.luanti/.minetest/games/world_of_blockcraft`.
  Re-sync after every code change. Engine logs:
  `~/.var/app/org.luanti.luanti/.minetest/debug.txt`.
- Take `strict.lua` warnings (undeclared global) seriously — usually typos.
- Server log via `core.log("action"|"warning"|"error", msg)`.
