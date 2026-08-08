# AGENTS.md — Project Guide

WoW-inspired Luanti game, titled "Grudgelands". Goals and scope:
**[ROADMAP.md](ROADMAP.md)**. Work packages and status:
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

On top of those three sits **[README.md](README.md)** — the human-facing
entry point (story, design tour with links to every `docs/design/` file,
current state). It is **derived, never authoritative**:

- **Rule: whenever a WP is completed (or its status in BACKLOG.md
  changes), update the README's "Current State" section in the same
  commit** — shipped count, the shipped/not-yet/ready-next lists, the
  caveats, and the *Last updated* date. Keep it short: three to five
  sentences per list, no WP-by-WP retelling (BACKLOG.md is that).
- When a `docs/design/` file is added, removed or substantially changed,
  check the README's design tour for the same edit (it links and
  summarizes every design doc).
- Never put design decisions or WP detail in the README that does not
  already live in `docs/design/`, ROADMAP or BACKLOG.

## Working method (sessions & context)

1. **Session start**: read BACKLOG.md, pick the next open WP (or the one
   the user names). Check for `TODO-*.md` files that block it. Skim the
   relevant docs/research/ briefings.
2. **One WP per session** is the norm — coherent, testable, committed.
   Offload large explorations to subagents, keep the main context lean.
3. **WPs run autonomously on their own branch** (`wp<NN>-<slug>`) per
   the workflow contract in
   **[docs/process/wp-workflow.md](docs/process/wp-workflow.md)**:
   the orchestrator (Fable or Opus) ONLY orchestrates (plan, per-task
   briefs, diff reads, final integration gate — no implementing); Opus
   subagents build everything, and **at least one full Opus code review
   per WP is mandatory** (different agent than the implementer;
   checklist in the workflow doc, incl. the
   `docs/research/luanti-lua.md` rules). Merge to main only after a
   clean review; every completion message ends with a runtime test plan
   for the user.
4. **WP completion**: Lua syntax check (`luajit -e "assert(loadfile(...))"`),
   `tools/sync_to_luanti.sh` (from main, after merge), commit, update
   BACKLOG status + ROADMAP checkboxes + the README "Current State"
   section (see "Documentation layers"). Anything future sessions need
   to know goes into AGENTS.md/docs — not just the chat.
5. **Runtime tests are done by the user** (Flatpak Luanti, GUI); diagnose
   errors via `~/.var/app/org.luanti.luanti/.minetest/debug.txt`.

## Project structure

- We are building a **standalone game** (not a mod pack, not a fork of
  minetest_game/VoxeLibre). The game will eventually live in a layout like
  `games/<gameid>/` with `game.conf`, `menu/`, `mods/`, `settingtypes.txt`.
- **Third-party code is vendored, never a submodule** (decided 2026-08-06):
  every embedded foreign mod is documented in **[VENDOR.md](VENDOR.md)**
  (upstream repo + commit + license + patch list); in-place changes carry a
  `-- GRUG PATCH:` marker at the change site; prefer wrapper mods
  (`grug_mobs` pattern) over in-place edits. Details/update procedure:
  VENDOR.md.
- `reference_projects/` contains **references only — never change anything
  in there**. The eight sources are **git submodules** (converted 2026-08-08,
  WP36) — not part of the build (the game runs with the directory empty), but
  required to develop this codebase: every engine-behaviour claim, licence
  verification and `file:line` citation in the design docs points into them.
  Get them with `git submodule update --init --recursive --depth 1`.
  - **Never move a pinned commit as a side effect of other work** — it
    invalidates every citation written against it and every
    `LICENSE-media.md` row quoting it. `git submodule status` must show no
    `+`/`-`/`U` marker. Deliberate updates and the re-verification they
    require: [docs/reference_projects.md](docs/reference_projects.md).
  - **A reference project needed beyond one session MUST live here and be
    listed in [docs/reference_projects.md](docs/reference_projects.md)** —
    with upstream URL, why we need it and its licence. Ad-hoc clones into a
    scratchpad die with the session, and then a *cleared* licence silently
    costs a re-download (this happened on 2026-08-08 with animalworld,
    animalia and mobs_monster, whose commits `LICENSE-media.md` still cited).
    This is **not** in conflict with the vendoring rule above: *vendored*
    means code we **ship** in `mods/` and patch in-tree; these are sources we
    **read** and never touch, and a submodule pins exactly the commit our
    licence rows quote.
  - **Imported meshes must be animated.** A mesh without `ANIM`/`BONE`/`KEYS`
    chunks slides instead of moving; choose another source rather than
    shipping it.
  - The eight sources and what each is for: see
    [docs/reference_projects.md](docs/reference_projects.md).

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

- **Namespace prefix `grug_`** for all our mods (e.g. `grug_xp`,
  `grug_factions`, `grug_quests`, `grug_jobs`, `grug_mobs`, `grug_map`) —
  derived from the game title Grudgelands. Vendored code carries
  `-- GRUG PATCH` markers for the same reason (see VENDOR.md).
- Exactly one global table per mod (`grug_xp = {}`), sub-files via
  `dofile(core.get_modpath(core.get_current_modname()).."/foo.lua")`.
- Custom fields in item/node/entity definitions use the `_grug_` prefix
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
  punch-interval factor. **Damage pipeline lives in `grug_core/combat.lua`**
  (WP4): `deal_ability_damage` (crit ×1.5, applied via `object:punch` with
  full punch interval so armor/knockback/XP keep working), `heal_player`,
  central dodge roll (hp-change modifier), `mark_in_combat/in_combat`
  (5 s window), threat stubs `add_threat`/`add_heal_threat` (WP6 fills
  them). Crit/dodge accessors are grug_core stubs overridden by
  grug_classes. Abilities = hotbar tools in `grug_abilities` (item `range` =
  targeting range, wear bar = cooldown display); kits/numbers:
  `docs/design/classes.md`. WP19 added: **GCD 1 s** (silent gate in
  try_cast, deliberately NOT shown via wear — would churn inventory
  re-sends), **soft target lock** 8 s (separate enemy/ally slots via
  `grug_abilities.get_target(player, ally)`; fallback re-checks range +
  LOS), **absorb shields** (`grug_core.set_absorb`, soaked in the central
  hp modifier after dodge/fall mitigation), **race passives** as a perk
  table in the grug_classes race registry (`grug_classes.get_race_perk`,
  stub-mirrored as `grug_core.get_race_perk`; elf range via per-stack
  meta `range` override) and mob slows (`grug_mobs.slow`, staticdata-safe
  countdown shared with root). NB a lethal ability punch removes
  animation-less mobs synchronously — capture mob pos/luaentity BEFORE
  `deal_ability_damage`. **mobs_redo `do_punch` gotcha**: any truthy
  return cancels the punch (api.lua comment claims the opposite) — hook
  wrappers must return nil; player-hit hook:
  `grug_core.register_on_player_hit_mob` (fired by grug_mobs).
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
  **WP6 patterns (binding for every new mob):**
  - **Level/tier engine contract** (`grug_mobs/levels.lua`): a mob def
    NEVER hand-sets `hp_min`/`hp_max`/`damage`/XP/`armor` — they are
    derived from `grug_core.mob_level_at`/`guard_level_at` plus the tier
    multipliers on the first active tick. `_grug_fixed_level` is the one
    documented exception (Kraken L100). Everything else (speeds,
    view_range, drops, visuals) stays def-owned.
    **Four tiers since WP36**: `critter` (added for the small animals —
    fixed L1, 1 HP, 10 XP, no fall damage, never promotable; the second
    documented exception to "stats derived") plus `normal`/`elite`/`rare`,
    whose arithmetic is unchanged. The **telegraph gate is a POSITIVE
    elite/rare test** (`grug_mobs.tier_telegraphs`, one predicate for both
    call sites) — a `tier ~= "normal"` test hands a rabbit a 2 s wind-up
    and a ×3 cone hit the day a fourth tier appears.
  - **Three behaviour classes, and a new mob picks one**
    (`biomes_mobs.md` §3.0): **critter** (small, scenery with a use —
    food-only drops, `passive` + `runaway`), **passive prey** (the large
    grazers — `grug_mobs.passive_prey` in `verbs.lua`: `passive = false`
    is what buys retaliation, `attack_players`/`attack_npcs = false` is
    what removes aggro on sight, `runaway` must be OFF because on_punch
    sets it a dozen lines before the retaliation block resets it, and
    **`attack_type` must be set** — `do_states`' attack branch dispatches
    on three values with no `else`, so a retaliating mob without one holds
    a target and does nothing at all) and **enemy** (§3.1's verbs).
    Ground mobs that can end up in the attack state carry
    `pathfinding = 1`; fliers never do (`core.find_path` is a ground
    search).
  - **Runtime field installation**: mobs_redo's `register_mob` copies an
    EXPLICIT def-field whitelist into the entity table (api.lua:3196ff)
    and staticdata drops function fields — so every `_grug_*` field an
    api.lua patch reads off `self`, and every callable, must be
    (re-)installed from the `do_custom`/`do_punch` wrappers on each
    activation, not written in the def.
  - **Countdowns tick in `do_custom`, never `core.after`**: a mob can
    die, be unloaded or leash-reset inside the window, and mobs_redo
    persists plain fields — a lost timer would save the mob permanently
    rooted. (`core.after` is fine for PLAYER-side effects, re-fetching
    the player by name.)
  - **Chase model** (combat_stats §3/§4): give up at **45 m** (an
    api.lua patch — vanilla uses `view_range`, ≤ 16 m, which made every
    other rule dead code), walk speed beyond **25 m** (soft de-aggro),
    leash at **40 m dragged from the chase anchor** (not from home) or
    15 s without contact, then the **evade run-home** if the mob stands
    beyond its own radius from its post.
  - **`aoc` is per entity NAME**, counted in a 128-node sphere — two
    rows of one name share a budget, per-biome tints do not. Spawn
    calibration reference: **`docs/research/wp6_spawn_budget.md`**.
  - **20 `GRUG PATCH` sites in `mods/ENTITIES/mobs/api.lua`** — the
    inventory and rationale live in VENDOR.md; re-apply them on any
    mobs_redo update.
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
- **Materials & depth gating** (shipped with WP25; `items_crafting.md`
  §3.0.1/§3.0.4, `world.md` §2 R6):
  - **The material ladder has a public interface** —
    `grug_materials.TIERS`, `tier_at(y)`, `stratum_node_for(y)`,
    `level_for_tier(tier)`. Nothing outside `grug_materials` hardcodes a
    depth boundary or a stratum node name; ask the mod. WP24's isle
    generator is the first consumer, because a VoxelManip pass does not
    get the strata from the mapgen ore stage the way the continent does
    (`grug_nodes/ore_respawn.lua` is the second — its fallback would
    otherwise punch level-0 stone into a level-3 wall).
  - **Engine contract, `groupcaps.<group>.maxlevel`**: it is not only the
    diggability gate. `leveldiff = maxlevel − node level` feeds three
    formulas at once (`reference_projects/luanti/src/tool.cpp:394-414`,
    documented in `lua_api.md:2715-2731`): `leveldiff < 0` → not diggable
    at all, `leveldiff > 1` → `time = time / leveldiff`, and
    `real_uses = uses · 3^leveldiff`. **Changing a `maxlevel` therefore
    changes durability and dig speed with it** and has to be compensated
    in `uses`/`times` — WP25 walked into exactly this (the re-tiered
    bronze pick silently fell from 180 usable blocks to 20). Such
    re-parameterisations of vendored items go through
    `core.override_item`, which **replaces a named field wholesale, it
    does not merge** — so an override must restate the full upstream
    `groups` / `tool_capabilities` with one field changed.
- **Traders/gold** (shipped with WP7; `docs/design/economy.md`,
  `items_crafting.md` §3.8/§8.2, `world.md` §7). **WP7 patterns
  (binding):**
  - **`grug_money` is the ONLY money API.** One integer in copper units
    in player meta (100c = 1s, 100s = 1g, conversion display-only);
    `get/set/add/take` (take is atomic and never goes negative) plus
    `register_on_change`. **Never read or write the meta key directly** —
    the clamp, the HUD refresh and the change callbacks all live in
    those functions. `PlayerMetaRef:set_int` is a real 32-bit signed
    store, hence the hard ceiling `grug_money.MAX`.
  - **`_grug_sell_price` (copper) is the universal buy-back field** in
    an item def — that is how "traders buy EVERY mob drop" is
    guaranteed. For **foreign items we must not touch** (vendored
    `default:` / `mobs:`) use `grug_traders.set_price(name, copper)`
    instead of overriding someone else's def; `grug_traders.sell_price`
    resolves override → def field → 0, and **0 means "not sellable"**.
  - **`grug_gear` is a GENERATED catalog, never a hand-written list**:
    the six bracket catalogs come out of the §3.1/§3.2 curves at load
    time. Public surface for anything that sells gear:
    `grug_gear.BRACKETS`, `bracket_for_level`, `get_price`,
    `get_sell_price`, `catalog[b].fixed/.extras/.all`. Buy-back is 25 %
    of the sale price everywhere.
  - **Armor pipeline** (armor was inert before WP7): item def
    `_grug_armor` → `grug_inventory.get_equipped_armor` (sums the four
    armor slots, **cached per player**, invalidated from the equipment
    inventory action, `grug_inventory.invalidate_armor` for server-side
    list writes, and on join) → `grug_core.get_armor_percent`
    (stub-override pattern, like crit/dodge) → one branch in the central
    hp-change modifier: **punch damage only**, after the dodge roll,
    before the absorb shield, `math.ceil` so armor alone never makes a
    hit free. **Capped at 60 in the consumer AS WELL AS the overrider** —
    that modifier is registered with `true` (may raise HP), so a pct >
    100 would turn a punch into a heal.
  - **Armor-rank gate**: items carry `grug_armor_class` (cloth 1 <
    leather 2 < metal 3), classes carry `armor_rank`
    (`grug_classes.get_armor_rank`, no class = 1); the check sits in the
    existing group-filtered `allow_put` with a **throttled** chat
    refusal (the allow callback fires repeatedly while dragging), and a
    class change unequips what the new rank may not wear.
  - **Vendor NPCs use plain `mobs:register_mob`, NOT
    `grug_mobs.register_mob`** — that wrapper IS the level/XP engine and
    would give a shopkeeper a level, a health bar and aggro wrappers.
    `type = "npc"` is what makes them permanent (it exempts them from
    all three mobs_redo removal paths); a **truthy `do_punch` return**
    is what makes them invulnerable (the api.lua precedence gotcha
    above). Placement is a throttled globalstep against fixed capital
    offsets — **no mapgen change**, so existing worlds get vendors too;
    the presence gate must stay inside the object-activation radius or
    duplicates spawn forever.
  - **Rotation is deterministic**: seed = `floor(os.time()/3600)` +
    per-vendor salt + bracket, fed into **`PcgRandom`** — never
    `math.random`/`table.shuffle`, whose sequence depends on what else
    called them since startup. Two players at one vendor in one hour
    must see the same shelf, and a restart must not re-roll it.
  - **No detached inventories in trade UIs.** The reference
    implementations (VoxeLibre `mobs_mc/villager.lua`, LotT
    `lottmobs/trader.lua`) move items through detached
    `wanted/input/offered/output` lists — that loses whatever sits in
    the input list when a player disconnects mid-trade. Every transfer
    goes directly against the player's own `main` list, the vendor's
    "stock" is a computed list of names and prices, and **every formspec
    action re-validates from scratch** (session, distance to the stored
    POSITION not an ObjectRef, access rule, and prices/counts recomputed
    server-side against the snapshot the player was shown).
  - **Three startup audits** in `grug_traders/init.lua`
    (`register_on_mods_loaded`, silent when clean): every mob drop has a
    price; no vendor buy/sell spread that prints money (discount
    included); no craft/cook recipe whose output is worth more than its
    priced inputs (the §3.8 anti-loop rule — the real case was smelting
    a 3c iron lump into a 5c steel ingot). Add prices, don't disable
    them.
- **Quests**: no ready-made framework in the references. Building blocks:
  trigger/counter patterns from `lottachievements` (awards fork), event
  stages from VoxeLibre `mcl_events` (`cond_start/on_step/cond_complete`),
  quest log as a formspec, state in player meta, quest givers via NPC
  `on_rightclick`, HUD `waypoint` elements for quest targets.
- **Mapgen/biomes** (decided in WP2, reworked in WP18): engine biomes on
  mapgen v7, territory/race-region confinement via the biome definition's
  `min_pos`/`max_pos` cuboids (works on x/z, not just y!). **20 biome
  registrations** = 13 band biomes (12 mirrored bands plus `grug_crags`'
  alpine cap `grug_crags_snowy`) + 3 extra slabs — the 2 extra
  `grug_deep_forest` ones (the only band that needs a hole in the middle of
  its cuboid for the 2026-08-08 capital-guarantee carve) and
  `grug_badlands_east`, WP36's Throng mirror of `grug_deep_forest_east` —
  + the 4 universal ones. The centre
  band was split into slabs the same way and rolled back the same day —
  read the D4 note before re-proposing it.
  See `docs/design/biomes_mobs.md` §1.3; every band is authored ONCE in
  Throng coordinates and registered mirrored at z=0 (`register_mirrored`
  in `grug_mapgen/biomes.lua`; the universal swamp/beach/ocean/underground
  are registered once — a biome name may exist only once); the cuboids
  overlap widely (101–450 nodes in x, up to 500 in z)
  and inside an overlap the heat/humidity voronoi picks per position —
  that IS the settled/wild patch mosaic. `grug_mapgen` owns all
  biome/ore/decoration registrations; default's
  `register_biomes/ores/decorations` are NOT called (see tail of
  `mods/BASE/default/mapgen.lua`); it also overrides the v7 terrain and
  the climate noise params (`override_meta = true` → **existing worlds get
  seams; test mapgen work on a FRESH world**).
  **Landmine**: ore/decoration defs whose `biomes` names don't resolve
  are silently unrestricted (world-wide) — never register ores/decos
  against biome names that might not exist. `game.conf` pins
  `allowed_mapgens = v7`.
  **Registration order is a tool, not trivia**: in mgv7 a mapchunk runs
  caves (`mapgen_v7.cpp:335`) → ores (`:355`) → dungeons (`:359`), and
  inside the ore stage the ores run in **registration order**, each
  converting only nodes that still match its `wherein`. That is the whole
  mechanism behind the six rock strata (`grug_mapgen/ores.lua`): an
  `ore_type = "stratum"` registered LAST with `wherein = "default:stone"`
  takes exactly the nodes no other ore claimed — so not one vein's
  `wherein` had to change — and, running after the caves, it also
  converts the already-carved cave walls, which therefore inherit their
  stratum for free. A `register_on_generated` VoxelManip pass would have
  got neither of those for free. (Dungeons run after the ores, so dungeon
  walls are *not* stratum rock — accepted.)
  **Landmine since WP25: `default:stone` no longer exists below −100.**
  Every node whitelist, every `wherein`/`place_on` and every mob spawn
  `nodes` list that means "underground rock" has to carry
  `group:grug_stratum` as well, or it silently narrows to the −40…−100
  sliver. WP25 repaired exactly that on four cave spawn rows (zombie,
  giant spider, stone + mesa golem); `default:stone` itself carries
  `grug_stratum = 1`, so the group alone is the complete predicate.
  The two things biomes cannot express live in VoxelManip passes, and
  since WP36 in **two different Lua environments** — the split is the
  rule, not a detail: a pass that only needs the chunk belongs in the
  **mapgen env** (`core.register_mapgen_script`), a pass that needs
  `grug_core`, mod storage or the POI registry cannot go there at all
  and stays in `register_on_generated` in the main env.
  The **continent ocean mask** is the first kind
  (`grug_mapgen/ocean_mask_mapgen.lua`; two mirrored continent
  rectangles; a coast noise insets them by 0..150 nodes INWARD only — so
  the strait is guaranteed by construction, not by luck — surface cap +
  flood outside, taper inward, box fast path skips inland/deep chunks;
  it carves up to **`emax.y`**, not `maxp.y`, because the engine places
  decorations up to the emerged top edge — `mg_decoration.cpp:424` — and
  clamping to `maxp.y` is what left floating tree crowns over the water).
  Its geometry (`column_cap`, a pure function of x/z) lives in
  `grug_mapgen/geometry.lua`, which **both** environments `dofile`; the
  continent rectangle itself comes from `grug_core` and reaches the
  mapgen env via `core.ipc_set` — never copy those constants.
  A `run_at_every_load` LBM in `grug_mapgen/ocean_mask.lua` heals worlds
  generated before that fix. `column_cap` being (x, z)-pure is what makes
  it idempotent; what makes it *safe* is the carved-column discriminator —
  it cuts only where the map still shows the mask's own signature (biome
  ground at the cap, air/liquid directly above), because `column_cap`
  knows where the mask cuts but not whether it cut, and an unconditional
  sweep would decapitate every legal coastal tree in the band. **The same
  discriminator gates `clean_shell` in the mapgen pass**, so its residuals
  are not LBM-only, and it is *not* free of false positives: on the
  `h == cap` contour a column legitimately carrying a neighbouring tree's
  crown reads as carved and loses it. The four residual classes — which
  one is "overflow survives" and which one is "legal terrain is cut" —
  are enumerated in `ocean_mask.lua`'s header; keep that list honest.
  The **six race-capital camp platforms** are the second kind
  (`grug_mapgen/structures.lua`, with the outposts and bandit camps).
  **Exactly ONE decider, the answer is ALWAYS persisted, and a caller that
  finds the height undecided FORCES the decision instead of inventing one**
  (WP36 — before it, `get_spawn_pos` silently substituted the
  `CAMP_PLATFORM_Y` minimum and wrote nothing down, so the same capital read
  y 8 in one session and y 36 in the next). The ladder, in order:
  `core.get_spawn_level` at the anchor − 2 (mgv7 refuses anything above
  y 17, in a river or in water, so it answers nil at many capitals) → a
  footprint heightmap median in `grug_mapgen` → `probe_platform_y`, a
  main-env VoxelManip ground probe over the finished map. All three measure
  the **same** footprint, `grug_core.CAMP_SAMPLE_RADIUS` — two fallbacks
  measuring two different areas would be two different answers again.
  `grug_core.get_camp_platform_y` reads, `set_camp_platform_y` writes
  (first writer wins, per race id in mod storage), and
  **`grug_core.request_camp_platform`** is what a caller uses when the
  answer is missing: it emerges the footprint (idempotent, bounded per
  session), and its completion callback falls back to the probe — which is
  the only decider that can see a footprint whose surface sits exactly on a
  **mapchunk y edge**, the case no heightmap can report and the WP18
  deadlock that was never actually closed. A staggered startup sweep
  requests all six so an unvisited capital cannot leave the protection rules
  answering from their own fallback. Two invariants the review had to add:
  **a decided height is not a built platform** — `build_camp` only runs from
  `register_on_generated`, so whenever the probe decides, the chunks are
  already on disk and `grug_core.ensure_camp_platform_built` (stub in
  `grug_core`, implemented in `grug_mapgen`) has to build it from the
  finished map — and **an uncertain measurement persists nothing**, because
  a graceful shutdown fires every queued emerge callback with
  `EMERGE_CANCELLED` while the env and mod storage are still alive, and
  first-writer-wins would make a half-generated reading permanent.
  NEVER decide a platform y from the mapchunk heightmap alone: it exists per
  chunk, so the value and the build order become chunk-order-dependent and
  can deadlock. Zone/level queries:
  `grug_core.territory_at` (accord/throng/ocean), `zone_at`
  (underground/ocean/strait/war_coast/coast/core/inner/outer — the
  `_grug_spawn_zones` vocabulary), `difficulty_at`, `mob_level_at`
  (radial field + war-coast/strait caps + depth axis), `guard_level_at`
  (inverse field, elite in the core — WP6 consumes it) and `open_sea_at`.
  LotT trick: biome signature nodes drive mob spawns via a node whitelist
  — those tops live in `grug_nodes` (blight_dirt, bone/forest/silver
  litter, mesa_clay, mud) and exist FOR the trick; `_grug_spawn_zones`
  (and the generic `_grug_spawn_check`) do the ring gating on top.
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
  `~/.var/app/org.luanti.luanti/.minetest/games/grudgelands`.
  Re-sync after every code change. Engine logs:
  `~/.var/app/org.luanti.luanti/.minetest/debug.txt`.
- Take `strict.lua` warnings (undeclared global) seriously — usually typos.
- Server log via `core.log("action"|"warning"|"error", msg)`.
