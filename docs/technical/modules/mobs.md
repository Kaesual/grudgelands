# Mobs

Part of the [module implementation guide](../module-guide.md), which indexes every
area. mobs_redo and the mob runtime, sub-types, loot, spawn regions, garrisons, arenas, the rift and the smaller mob behaviours. Implementation seams and engine pitfalls only; the
[design docs](../../design/README.md) own the game rules. Source paths in code
spans are repository-relative.

Sections: [Mobs](#mobs), [Mob sub-types, loot and spawn regions](#mob-sub-types-loot-and-spawn-regions), [PvP garrisons and dragon arenas](#pvp-garrisons-and-dragon-arenas), [The rift](#the-rift), [Mob voices](#mob-voices), [Dawn departure](#dawn-departure), [Room for a body](#room-for-a-body), [Flier clips](#flier-clips), [Mobs in water](#mobs-in-water).

## Mobs

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- A boss's reset is `grug_mobs.reset_home` (kings, Generals, Expedition bosses through the
  boss floor; guards and the other `_grug_reach_reset` mobs through their give-up); a new
  boss or out-of-reach rule ends there, never in a second heal-and-evade path.
- An evader's way home is `aggro.lua`'s `evade_walk`; a new way home registers a guide
  (`grug_mobs.register_evade_guide`), never a second walk.

### mobs_redo, NPC clicks and pathfinding

- **Mobs**: embed and patch mobs_redo (MIT). Faction targeting: mobs_redo's
  `general_attack()` asks the `_grug_ignore_player` veto, which `grug_mobs`
  installs with the mob's `_grug_faction` (`grug_mobs/init.lua`); there is
  no `race` field. Territory/tier gating via `mobs:spawn_abm_check()`. Tiers
  via `hp_max`/`armor` (lower = tougher)/`damage`/`view_range`/
  `group_attack`. Loot passes the `_item_drop_filter` gate
  (`grug_mobs/aggro.lua`). Quest kill credit subscribes to the shared eligible participant event
  from `grug_mobs.award_kill_xp`; it must not use only the death killer.
  Quest/trader NPCs: `type="npc"`, `passive`, `on_rightclick` → formspec;
  placement via `mobs:add_mob(pos, def)`. Every NPC whose right-click opens
  a dialog (the villagers' services and answers, the quest givers, every
  vendor) first asks `grug_mobs.door_before_npc(self, clicker)`
  (`door_click.lua`, 0.49.1): the engine's pointing, the client's too,
  prefers an object up to one node squared farther than a node
  (`src/raycast.cpp` RaycastSort), so a click on a closed door with an NPC
  close behind it can reach the NPC (in either half, depending on the gap,
  distance and angle); the helper casts the clicker's look ray and hands
  the click to the door's `on_rightclick` when the ray meets the NPC and,
  physically before it, a closed door. Fixture `tools/r491_door`, engine probe
  `tools/r491_door/probe.sh`.
  **Pathfinding is a quality criterion** (user requirement: dangerous mobs
  must not fail at terrain, otherwise they are not dangerous): mobs_redo's
  `pathfinding = 1` lets a mob search (`core.find_path` through
  `mobs/grug_nav.lua` since Round 42; upstream's level 2, break/build
  nodes, is gone) plus `stepheight`/`jump_height`/`fear_height` — always
  enable and test these when tuning mobs. VoxeLibre `mcl_mobs` has its own, more
  advanced `pathfinding.lua` (+ the villagers' `gopath`; GPL ok, see below),
  but Round 42 builds no pathfinder of our own ([round 42
  plan](../../planning/round42-plan.md) ruling 1).
  Fallback design: additionally make heartland mobs fast (`run_velocity`)
  and give them ranged attacks (`attack_type = "dogshoot"`) so terrain
  exploits are not trivial.

### WP6 patterns (binding for every new mob)

  **WP6 patterns (binding for every new mob):**

#### Level and tier contract

  - **Level/tier engine contract** (`grug_mobs/levels.lua`): a mob def
    NEVER hand-sets `hp_min`/`hp_max`/`damage`/XP/`armor` — they are
    derived from `grug_core.mob_level_at`/`guard_level_at` plus the tier
    multipliers on the first active tick. `_grug_fixed_level` is the sole
    explicit fixed-entity mechanism: it bypasses positional/role fields only
    for deliberately designed fixed entities. Its implemented uses are the
    Kraken L70 (elite), the Round 51 sharks (Bay Shark L30, Abyssal Shark
    L70 elite), the island dragons L70 and their whelps L60, the capital
    kings L70 and their royal guards L60, the PvP fortress Generals L65 and
    their bodyguards L60, and the rift boss L60. There is no second king-specific level path.
    Everything else (speeds, view_range, drops, visuals) stays def-owned.
    The game's max HP is the Lua field `self.hp_max`; the engine's `hp_max`
    property is u16, so it is written as at most 65535 and every reader asks
    the field first (Round 73: the Expedition bosses and the dragons are above it).
    **Four tiers since WP36**: `critter` (added for the small animals —
    fixed L1, 1 HP, 0 XP, no fall damage, never promotable; the second
    documented exception to "stats derived") plus `normal`/`elite`/`rare`,
    whose arithmetic is unchanged. The **telegraph gate is a POSITIVE
    elite/rare test** (`grug_mobs.tier_telegraphs`, one predicate for both
    call sites) — a `tier ~= "normal"` test hands a rabbit a 2 s wind-up
    and a ×3 cone hit the day a fourth tier appears.

#### Per-viewer nametags

  - **Per-viewer nametags since 2026-09-18**: every tagged mob, peaceful NPC,
    vendor and player owns one invisible `grug_core:tag_carrier` child. Parent
    tags stay empty/alpha-zero; the child text is observer-managed at 25 m show
    / 30 m hide independently per viewer, with a player's owner excluded.
    Create/remove carriers through the shared `grug_core/tag_carrier.lua` seam,
    update text there (including telegraph/tier/HP changes), and leave observer
    sets plus orphan cleanup to that module's one central 1 Hz pass (since
    Round 30 spread over eight slots of each second; visibility callbacks run
    only for observed carriers or on an observer-set change). Carriers
    are non-pointable, non-physical and unsaved. Unsaved Lua entities never
    enter the engine's static-object count used by mobs_redo `aoc`; do not
    compensate or otherwise modify that spawn-budget comparison for carriers.
    Since Round 67 (ruling 25) `grug_mobs.wants_nametag` (levels.lua)
    decides who gets one: no carrier for a critter (`_grug_disposition`) or
    a settlement resident on an `idle`/`work` socket (`_grug_socket_role`);
    `update_tag`, the shared `after_activate` and the settlement NPCs'
    `install_nametag` ask it. Fixture `tools/r67_world`. Since Round 72 a
    faction unit has a second, foe carrier while a viewer of the other side is
    in range (`resolve_unit` in `tag_carrier.lua` works out the unit's faction
    and kind through the stub `grug_core.get_player_object_faction`, which
    `grug_factions` fills); callers keep their one handle, and text, the HP
    bar and the visibility callbacks reach both carriers. Fixture
    `tools/r72_tags`. Since Round 81 (audit C1-04, X4-03) each player's
    faction is read once a second on the player's join slot
    (`grug_core.register_player_pass`), so a faction chosen later shows
    within about two seconds; the player snapshot (positions every 1/8 s,
    also read by `nearest_tag_player_d2`) is bucketed in 32-node cells and a
    carrier tests only its own and the eight neighbouring cells; an observer
    set is rebuilt and sent only when it changed; an HP bar follows a rescale
    of its parent through `grug_core.sync_tag_carrier_box` (the tier
    promotion in `levels.lua`) instead of reading the parent's properties on
    every visit. Fixture `tools/r81_social`.
    Since Round 78 a player's lost carrier (gone, invalid or detached) is
    replaced in its row by the pass and by `create_tag_carrier`, which
    therefore may hand back a new handle (or, while the player's block is not
    in memory, the old invalid one, whose text is kept for the replacement);
    `grug_factions.refresh_player_tag` asks for it on every call and is the
    re-ensure hook of grug_home teleports, respawns and `grug_mounts` mount and
    dismount. A mob's lost carrier is still forgotten. Fixture `tools/r78_tags`.

#### Three behaviour classes

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

#### Runtime fields and staticdata

  - **Runtime field installation**: mobs_redo's `register_mob` copies an
    EXPLICIT def-field whitelist into the entity table and staticdata drops
    function fields — so a `_grug_*` field an api.lua patch reads off `self`
    never comes from the def by itself. A definition-constant field (and a
    shared method such as the empty `general_attack`) is published once on
    the registered prototype after `mobs:register_mob`
    (`core.registered_entities[name]`, the entity's metatable; the aggro
    config through `grug_mobs.publish_aggro_fields`, Round 81); only
    per-instance runtime state is written onto `self`. A value written onto
    `self` is saved in staticdata and outlives a later retune: the speed
    effects therefore remove a restored speed equal to the definition's
    instead of writing it back, and the after_activate wrapper drops an older
    save's copies of definition values (`grug_mobs.drop_prototype_copies`).
  - **`core.add_entity` stores the staticdata of that moment**
    (`ServerEnvironment::addActiveObjectRaw`): fields written after the
    call reach the mapblock only at the entity's next deactivation. A block
    saved and unloaded in between keeps that first snapshot, and the
    deactivation then stores a second copy, so the entity comes back twice.
    Pass what identifies the entity in `add_entity`'s staticdata
    (`start_npcs.lua` `place`: `_grug_unplaced`, Round 30).
  - **An actor the map never saves is added unsaved** (Round 84 ELITE,
    `grug_mobs/unsaved.lua`; [upstream workarounds](../upstream-workarounds.md)
    §11): `static_save = false` after the add is too late, because the
    add-time snapshot survives a block that unloads with the object alive.
    `grug_mobs.add_mob_unsaved` / `add_entity_unsaved` mark the name being
    placed, and `grug_mobs.unsaved_claim`, the first statement of
    `init.lua`'s after_activate wrapper, turns static_save off inside the
    add. A definition with `_grug_unsaved` (the leader sub-types,
    `subtypes.lua`; the rift boss) has no saved form: every other
    activation of it is an old snapshot and removes itself before anything
    else runs (no fight, drop or credit). The leaders, the rift boss and the
    depth pulse's arrivals go through these helpers; a spawner that adds an
    `_grug_unsaved` actor past them loses it at once, with a log line.

#### Per-step allocation

  - **Per-step mob code allocates nothing it can avoid (Round 30 P2):** read
    a mob's collision box from `self._grug_cbox` (written wherever the box is
    set; `grug_obstacle.mob_cbox` / `object_cbox`), never `get_properties()`
    in a step; privilege checks go through the cached `mobs.has_priv`
    (since Round 81 a delegate of `grug_core.has_priv`). A*
    runs inside a per-step time budget (about 3 ms) with a negative path
    cache (`grug_obstacle.no_path_gate` / `note_search_result`). Combat
    navigates through `mobs/grug_nav.lua` (`mobs.grug_nav`, Round 42: the
    stuck detector, the local search, the follower and the give-up rule of
    `combat_stats.md` "Navigation" and "Unreachable targets are given up",
    `grug_mobs.give_up_target` in `aggro.lua`; kings, Generals and bosses
    reset by `boss_floor.lua`, Round 72: the boss floor over `nav.cell`, the
    one-way window, the 15 s rule, all ending in `grug_mobs.reset_home`;
    guards, captains, the rift boss, leaders and rares carry
    `_grug_reach_reset`, read only by `grug_mobs.reach_reset` (`aggro.lua`),
    which switches on `nav.strict` (search the target at the pull, padding 16,
    two failures) and makes their give-up `reset_home`, Round 72 GUARDNAV;
    Round 49 NAV2: `check_path`
    repairs a waypoint without head room or width from the cells round it,
    a stuck episode's searches pad 6, 12, then 16 (`PADDING_STEPS`), and
    ground `dogshoot` mobs with a ranged phase navigate too, to regain sight
    of their target); `nav.fixed_step` is the fixed-walk interface. A walk
    to a fixed goal (a patrol, a post or seat,
    the evade, the rift boss's way home) goes through `patrol.lua`
    `grug_mobs.walk_fixed` from its owner's 1 Hz tick and
    `grug_mobs.walk_follow` on every other step (the per-step steer while
    a path is followed), `walk_clear` when it ends; the royal follow
    (`bosses.lua`) calls `fixed_step`/`combat_step` itself every step
    (Round 42 NV2, `world.md` §4a "Fixed walks"). A walk in a start town or
    a capital between two fixed points (a villager's spots, the watch's
    waypoints) goes through `routes.lua` (Round 42 NV3,
    `settlements.md` "Settlement walkers"): `grug_mobs.route_walk` from the
    owner's tick and `route_follow` on the other steps, `route_clear` when it
    ends; the settlement route cache builds each leg once with
    `nav.claim_search` (the cap and the budget for a caller outside the
    follower) and `nav.search`, and reads a capital's streets from
    `grug_mapgen.wp40.road_layout_text` with `wp40/road_layout.lua`'s own
    decoder. Doors (Round 42 DR, `settlements.md` "Doors") go through
    `npc_doors.lua`: the route cache's door plans and the fixed walk's door
    detour (walkers and post guards only) find doors with `npc_doors.near`
    / `between`, open them with `approach` (the vendored `doors.get(pos):open()`
    with no player, its own sounds) and close them with `settle` from
    `walk_follow`; a door is a wall to every search. Every search is
    `nav.search` behind the per-mob lockout, the negative cache, the count
    cap and the budget (`claim_path_budget`, `note_path_cost`); never an
    unbudgeted `core.find_path`. Fixtures `tools/r30_p2` (also the merged
    spawn ABMs and the eye height), `tools/r42_nv1`, `tools/r42_nv2` and
    `tools/r42_nv3`, `tools/r42_dr`. The evade's way home (`aggro.lua`
    `evade_walk`, Round 74) asks the evade guides first
    (`grug_mobs.register_evade_guide(fn)`, `fn(self, pos, home) -> point |
    nil`, in registration order; the Expeditions register theirs), then the
    mob's trail (`self.temp.grug_evade_trail`, recorded in the 1 Hz leash
    slot while it chases), then the walk home; each answer is a fixed walk
    of its own key (fixture `tools/r74_trail`).

#### Countdowns, chase model and idle recovery

  - **Countdowns tick in `do_custom`, never `core.after`**: a mob can
    die, be unloaded or leash-reset inside the window, and mobs_redo
    persists plain fields — a lost timer would save the mob permanently
    rooted. (`core.after` is fine for PLAYER-side effects, re-fetching
    the player by name.)
  - **Chase model** (combat_stats §3/§4, Round 19 follow-up): ordinary
    ambient mobs have no distance give-up/slowdown. After 15 s without effective
    incoming damage from any player/eligible guard, a live current target must
    move at least 0.25 nodes horizontally since the previous 1 Hz sample before
    return starts. Standing still does not reset that clock; outgoing mob hits
    do not refresh it. Sample only target X/Z in runtime temp, reseed on target
    switch, and preserve dead/missing-target cleanup. Bosses/guards/camps/rares
    retain their authored limits, including 45 m give-up, 25 m slowdown and
    40 m chase-origin drag/contact timeout where applicable. Return-home and
    the 40 s teleport fallback remain unchanged.
  - **Idle recovery** (Round 19 follow-up): registered living mobs/guards/bosses
    fully reset after 30 s calm without observed HP loss. Actual targets/actions,
    runaway/flop, evade and shared recent boss-group activity block recovery.
    Sample HP at the existing 1 Hz maintenance tick, all sources included;
    reward ledgers are not combat state. Never refresh pursuit from outgoing
    hits, never resurrect, never heal a retinue member mid-encounter.

#### aoc and the GRUG PATCH sites

  - **`aoc` is per entity NAME**, counted in a 128-node sphere — two
    rows of one name share a budget, per-biome tints do not. Spawn
    calibration reference: **`docs/research/wp6_spawn_budget.md`**.
  - **`GRUG PATCH` sites in `mods/ENTITIES/mobs/api.lua`** (156 counted
    2026-11-17, Round 81; the current count per file is VENDOR.md's row) — the inventory and rationale live in
    VENDOR.md; re-apply them on any mobs_redo update. Round 34 F1's four
    water sites (`grug_may_wade` in the support probe, `grug_bank_ahead` and
    `GRUG_CLIMB_RISE` in `falling()`) and S1b's two sound call-outs
    (`mob_sound` routes a `grug_sounds` event through `grug_sounds.play`;
    `on_punch` plays `grug_core.melee_hit_sound`) are the newest. The 41st to 43rd (mob pressure, 2026-09-16) are the
    attack-cadence patch of `combat_stats.md` §4 and user ruling 1: the
    cadence advances during the CHASE with the backlog capped at one, the
    in-reach branch runs to a contact distance of `reach × 0.6` instead of
    freezing the mob, and the punch sits outside both branches with the
    in-reach and line-of-sight tests where it lands. The 44th to 59th
    (round-5 combat AI, 2026-09-17) raise ordinary reach to 3 m, navigate
    blocked close cover (replaced by `mobs/grug_nav.lua` in Round 42),
    remove implicit ordinary-hit knockback and disable object-to-object
    collision; `mobs/grug_obstacle.lua` holds the A* budget, the negative
    path cache and the collision-box cache.
    The 40th (WP13 playtest round 2, 2026-09-15) is the
    per-TARGET non-combatant veto in `general_attack`'s candidate filter:
    hostiles and guards MAY fight each other, but nothing in the world may
    acquire an entity carrying `_grug_noncombatant` (villagers, elders,
    vendors — they cancel every punch, so such a fight never ends). The flag
    is installed at activation by `grug_mobs.noncombatant`; do NOT narrow an
    attacker's `attack_npcs` on a civilian's behalf.
    WP35's 21st: the `set_wielded_item` write-back at
    the end of the wear block runs only when wear/toolranks changed the stack
    (on a player that call is a full inventory serialization plus packet; the
    skipped no-op ability writes were ~140/s at the 100-player target). WP38
    reshaped the melee patches: the 2026-08-07 cadence gate is deleted;
    the player-melee flag is `grug_melee`, the damage loop keeps
    vanilla's `tflp/fpi` factor (the authoritative swing supplies
    `tflp == fpi`) and adds the Strength bonus before armor scaling, the
    crit roll follows the `immune_to` loop, and knockback fires when the hit
    lands (`subtract >= 1`). Round 37 (CMB-03) removed WP38's proportional
    tool/fist path: the remainder accumulator, its preview and commit, the
    ordinary-input clock seam and the per-stack wear accumulator
    (`grug_fraction`, `_grug_melee_wear_id`); native tool and fist packets
    already returned at the input seam, so none of it was reachable. The
    2026-08-10 native-input correction added two sites: full
    authoritative proc preparation folds the selected skill's replacement
    delta into the same punch before crit, and accepted finish after
    `do_punch`/CMI is the only place that pays/resets/applies it. The review
    added the 31st site: `grug_mobs.accepted_player_punch` runs provocation, loot
    tag, threat/rage and lethal rare/XP work only after both `do_punch` and CMI
    accept, before health subtraction; the melee-crit visual is deferred to the
    same boundary, so neither cancel path has irreversible hit side effects.
    The held-soft-target correction adds the 32nd marker: a native swing-item
    combat packet calls the Core input/acquisition seam and returns before all
    mobs_redo combat side effects; only the exact-target, claim-once token of a
    server-owned full punch may continue.

## Mob sub-types, loot and spawn regions

**Rules** (the working rules for this area; the checks to run after a change are in
[checks.md](../../process/checks.md)):

- **Mobs, loot, quests and enchant inputs are data**, per zone where per-zone
  (`grug_mobs/data/zones/<zone>.spawns.json`, `grug_quests/data/zones/<zone>.quests.json`
  and `.front.quests.json`, `grug_mobs/data/{subtypes,items,drops,tints}.json`,
  `grug_professions/data/enchants.json`): tune data, not code.
- A zone's level band is its mapgen record (`grug_mapgen/wp40/source/simple_map.lua`) and
  changes only in a mapgen round; a mob's surface level is `grug_core.mob_level_at` (the
  spawn-region overlay), never `grug_zones.mob_level_at`.
- Names are data per slot (zone, source, level band) in `grug_mobs/data/names.json`;
  code-built names (kings, dragons, whelps …) read it, never a second copy in code (PvP
  captains: `pvp_names.json`). The naming rules are
  [biomes_mobs.md "Names"](../../design/biomes_mobs.md#round-28-sub-types-and-loot-by-band).

- **Mob sub-types, loot and spawn regions (Round 28):** all in `grug_mobs`,
  data under `data/` (JSON; a missing file means "no data", a broken one
  fails the load).
  - `subtypes.lua` registers each sub-type `grug_mobs:<role>` as a copy of
    its already registered base (loaded after every mob file), from
    `data/subtypes.json` and `tints.json`; loot items from `items.json`;
    drops by level band from `drops.json`. Quest-only drops go through
    `grug_mobs.register_participant_drop_hook` (`aggro.lua`), rolled per
    eligible participant.
  - `names.lua` (Round 38, `grug_mobs.names` over the pure
    `names_core.lua`) reads `data/names.json` (slot key
    `<zone or world>/<source>/L<lo>-<hi>` -> name, written by
    `tools/r38_b1/gen_names.py` from `tools/r38_names/inventory.py`; two
    names overlapping in one source and scope fail the load) and names every
    mob by (source, zone, level): `grug_mobs.apply_name`, called by
    `levels.lua` once per activation (with the level settled) and on every
    `relevel`, and by `start_npcs.lua` at a garrison placement. The source is
    `_grug_name_key` (a rare's `rare.<id>`, a garrison post's
    `<settlement key>.<post>`, from `pvp_garrison.lua` `G.slot`) or the
    entity role; a source the file does not name keeps its description (the
    PvP captains, commanders and Generals keep their `pvp_names.json`
    names). The quest kill credit compares this name (fixture
    `tools/r38_b1`).
  - `spawn_regions.lua` (`grug_mobs.spawn_regions`) reads
    `data/zones/<zone>.spawns.json`: every zone's `recipe` (a file without
    one, or with a `palette`, fails the load: Round 81, ruling 6, removed the
    old ABM palette path and the surface rows only it could reach). It builds
    every recipe zone's region map at server start (mods loaded) through the
    lazy `SR.map` and the pure
    `spawn_regions_core.lua`, which `tools/r28_regions` runs unchanged, so
    the review images are what spawns. Since Round 30 (P3)
    `spawn_regions_cache.lua` (pure, plain Lua 5.1) keeps only the compact
    form of each map (`SR.map`; `SR.full_map` builds the full one for tools)
    and `SR.start_maps` reads every current zone from
    `<world>/grug_region_maps.txt` and builds the rest; the compact map's
    `cell_frame` and `cell_region(i, j)` (Round 85) read its cell grid, and
    `SR.each_cell(zone, fn)` walks every land cell with its region (the
    claim mask's camps and quota, `grug_housing/mask.lua`). Its key is the
    world-layout key (`grug_mapgen.wp40.world_key`) plus a digest of the
    builder's files: **a new file the build reads must join that key**, or
    `tools/r30_p3` (input coverage) fails. API: `region_at`, `level_at`,
    `describe` (direction phrases for quest texts), `area_roles`,
    `leader_pos`; every spawned mob carries `_grug_area` (dawn, density,
    camp head counts, the zone of its name). Its one throttled globalstep runs one ambient attempt per
    player per second in four player slices and, since Round 32 (perf
    review R3), the camp slots (`grug_mobs.region_camp_tick`, `camps.lua`)
    and leaders (`SR.leader_tick`) in `SR.SLOW_SLICES` (20) zone slices of
    0.25 s, so each zone is still served once per `SR.SLOW_PERIOD` (5 s)
    but no step weighs every camp against every player (fixture
    `tools/r28_s1`, section "Round 32 F4"). A leader is added through
    `grug_mobs.add_mob_unsaved` and tracked by its ObjectRef only
    (`live_leaders`); its sub-type is `_grug_unsaved`, so a snapshot 0.83.0
    or older left in the map removes itself at activation (fixtures
    `tools/r28_s1` "Leaders", `tools/r84_elite`). Rules: [spawn_regions.md](../../design/spawn_regions.md),
    [biomes_mobs.md](../../design/biomes_mobs.md) §4.2.
  - `depth_pulse.lua` (Round 46, `grug_mobs.depth_pulse`): the depth pulse
    below y −300 ([biomes_mobs.md](../../design/biomes_mobs.md) §4.1). One
    throttled globalstep serves the players and the live arrivals in four
    slices of each second; per player a roll (`DP.rate`), the shared cap
    within 24 nodes (`DP.cap`, `_grug_pulse` entities), a spot by up to four
    rays (`DP.find_spot` over `DP.world`), the refusals (`DP.refused`), a
    2 s wind-up (`depth_windup`, `depth_burst` in
    `grug_core/particle_effects.lua`) and `grug_mobs.add_mob_unsaved` with
    `ignore_count` (unsaved from its first activation; snapshots older
    versions left look like ordinary mobs and stay); the arrival gets
    `_grug_pulse`, `_grug_no_coin_bag` and
    `underground_spawned(..., skip_elite)`, and
    fades after 10 s without a target. `DP.players` is the seam the depth
    probe (`tools/r24_density_xp` `POINTS=pulse`) replaces with stand-ins;
    the pure parts are driven by `tools/r46_dp`. The roster bands
    (`DP.ROSTERS`) also feed the names inventory (`tools/r38_names`,
    source `depth_pulse`).
  - Since Round 36 a relevel recomposes a humanoid's skin and
    `grug_mobs.refresh_visual` puts the zone tint (the corrupted sub-types'
    ember) back on top through `grug_mobs.reapply_zone_variant`
    (`subtypes.lua`; fixture `tools/r36_q0`).
  - `env_damage.lua` (percent environmental damage, read by the
    `grug_env_damage` GRUG PATCH), `roam_avoid.lua` (idle aggressive mobs
    walk away from roads, towns and active claims), `separation.lua` (separation and melee
    knockback as position displacement).
  - Zone level bands live only in the mapgen source
    (`wp40/source/simple_map.lua`), served by `grug_zones.get`/`at`.
  - Tools after a recipe change: `tools/r28_regions/run.sh` (images and
    stats per seed, then `quest_targets.py`), `tools/r28_world/run.sh`
    (world view, border fit; `border_rule.py`), the catalogue checks
    `tools/r28_design/validate.py` and, for the names since Round 38,
    `tools/r38_names/check_rules.py --shipped`, `guarantee.py --check` and
    `tools/r38_b1/gen_names.py --check` (`tools/r28_names/build_review.py`
    is retired).

## PvP garrisons and dragon arenas

- **PvP garrisons and dragon arenas (Round 31):** `grug_mobs/pvp_garrison.lua`
  (pure; built in `init.lua` before `guard.lua` from the mapgen catalogue
  `r31_pvp_catalog.lua` and `data/pvp_names.json`) answers per socket which
  NPC stands there (`G.slot`: entity, levels, tier, respawn, royal, leader,
  name, mixed, area), the quest area `"<zone>/<settlement key>"` and its
  roles (`G.area_roles`, read by `grug_quests` and `tools/r28_design`).
  Round 36: the war commander of the two camps `pvp_names.json`'s
  `commanders` names (`G.commander`, the role `commander` in `G.slot`); he
  has no blueprint socket, so `start_npcs.lua` appends the post
  `M.commander_socket` derives from the captain and the west yard post.
  `guard.lua` registers the camp captains and the commanders (the guard
  chassis, `grug_mobs.LEADER` factors from `levels.lua` in the definition),
  `bosses.lua` the Generals from `king_def` (the seat race from
  `catalog.SEAT_RACE`) and their bodyguards; `start_npcs.lua` serves a PvP
  POI as its own settlement kind and books the respawn slots (the General's
  group on the royal path). `dragon_arena.lua` holds the pure arena rules
  (radius from the mapgen profile, inside band, 250/350/500 per second,
  the reset test; since Round 34 the thin ice: `ice_step` marks every thin-ice
  node of the 3×3×3 cube around a sampled player's feet as one break event
  due `ICE_BREAK_DELAY` (1 s) later, keyed server-wide by node position, a
  pending node never reset or postponed; `ice_due` pops the events that are
  due; since Round 36 `push`, the velocity of the wing gust and the dive's
  slam, weakened by the player's live braking so that he stays within
  radius − 4; `boss_dragons.lua` turns the punch push off for the slam's hit
  through a `core.calculate_knockback` wrapper around grug_core's
  weight-class push, `grug_core/knockback.lua`);
  `boss_dragons.lua` applies them (one `ice_break` sound per event):
  `_grug_target_veto` (a hook in the `init.lua` acquisition veto, honoured by
  `grug_core`'s `valid_target`, `add_threat` and `taunt`; since Round 51 the
  water swimmers under the ordinary leash carry it on their prototype too,
  `grug_mobs/swimmer.lua`, vetoing players out of the water and off a boat),
  the once-a-second
  arena tick (threat prune, reset and flight home, hazards and the wrath
  through `set_hp`; `grug_core.bypasses_absorb` covers the wrath), the
  participants table per dragon. Fixtures `tools/r31_g`, `tools/r31_da2`,
  `tools/r36_g` (the wider hazards, the refreeze, the gust; `engine.sh` the
  hazard counts and a push on a stand-in).

## The rift

- **The rift (Round 36):** `grug_mobs/rift_core.lua` (pure: the site
  constant `SITE`, each candidate's crack waypoints and `crack_cells`, the
  respawn and particle numbers) and `rift.lua` (the void node, the one-time
  crack behind the storage key `rift_crack:<site>`, the particles, the rift
  boss and its once-a-second pass; `grug_mobs.rift_players` is the probe's
  seam for stand-in players). The boss is `_grug_unsaved` and added through
  `grug_mobs.add_entity_unsaved` (Round 84 ELITE; a saved copy removes
  itself). It settles through `bosses.lua`'s ledger
  (`grug_mobs.boss_settle`); a boss reward hook is `fn(self, boss_id, player,
  locked)`, `locked` for a kill inside the character's lockout (grug_quality
  rolls `BOSS_DROPS.locked`'s tier, the rift boss's elite row, else nothing).
  The void's player damage is the node group `grug_pool_damage` (a percent
  of the pool per second), applied in grug_core's central hp modifier through
  `grug_core.node_pool_damage` (`environment_damage.lua`), lava's pattern.
  The boss rises only for an eligible player near (`rift_core.FINALE_QUESTS`
  through `grug_quests.quest_held`, `state.lua`: "active", "completed" or
  nil from the cached state, cheap enough for a once-a-second pass; with
  grug_quests absent everyone is eligible).
  Fixtures `tools/r36_r` (with `numbers.py` and `engine.sh`), `tools/r33_c1`.
- **Authored actors and their liveness (Round 37 MP):** `mobs/api.lua`'s
  `grug_authored` (a GRUG PATCH) exempts every NPC and every mob marked
  `_grug_authored` from the active-mob limit's count and removal: by its
  definition (the dragons, the rift boss; `grug_mobs.register_mob` publishes
  the field on the prototype) or by its spawner through `mobs:add_mob`'s def
  (rares, leaders), which hands the mark in as staticdata. A shutdown makes
  no unload despawn decision (`grug_shutting_down`). `grug_mobs/liveness.lua`
  is the one "is it still out there" rule for the actors that persist with
  the map without a socket, the named rares (`"rare:<id>"`) and the dragons
  (`"dragon:<id>"`): a spawn takes `next_generation(key)` and stamps
  `_grug_live_key`/`_grug_live_gen` (a dragon through `add_entity`'s
  staticdata, a rare through `add_mob`'s `_grug_staticdata`); the first statement of
  `init.lua`'s after_activate wrapper, `grug_mobs.live_claim`, removes a stale
  or second copy; a class-level `on_deactivate` records the last place; the
  callers' 10 s passes ask `watch(key, dt)`, which counts absence only while
  that place is an active mapblock and answers `"lost"` after
  `LOST_AFTER` (60 s) of it; a rare's death by any cause books its ordinary
  respawn first (`settle_mob_death`), so "lost" covers removals only. Royal summons, whelps and other
  encounter adds are not authored. Fixture `tools/r37_mp` (with `engine.sh`,
  the restart test).

## Mob voices

- **Mob voices (Round 34 S1b):** `grug_mobs/voices.lua` holds `VOICES`, the
  families (humanoid, goblin, undead, mummy, skeleton, spirit, giant,
  elemental, canine, feline, boar, beast, grazer, bird, crow, critter,
  insect, slime, reptile, aquatic, dragon, kraken), each mapping
  `war_cry`/`damage`/`death`/`telegraph` to `grug_sounds` events.
  `grug_mobs.register_mob` calls `apply_voice`, which turns the definition's
  `_grug_voice` into the mobs_redo `sounds` table with only the events that
  have a spec (explicit `def.sounds` entries win); a definition without
  `_grug_voice` is a load error, `false` means no voice, and a sub-type
  copies its base's field. No family has a `random` call; felines have no
  `war_cry`. `telegraph.lua` plays the family's `telegraph` cue at a
  wind-up (only the humanoids have one); the dragons play `telegraph` from
  `boss_dragons.lua`. Fixture `tools/r34_s1b`.

## Dawn departure

- **Dawn departure (Round 35 E):** `grug_mobs/dawn.lua`
  (`grug_mobs.dawn_tick`, called from the shared `do_custom` wrapper right
  after `leash_tick`; a `false` return ends the step of a mob that left)
  removes a free region mob whose `_grug_spawn_clock` is `"night"` by day
  (`SR.clock_now`) with mobs_redo's smoke puff — no drops, XP or kill
  credit — unless it is in combat or a player is within
  `grug_mobs.DAWN_NEAR` (64) nodes on every axis (a cube, edge included,
  `grug_mobs.dawn_players_clear`; Round 45 playtest, a 32-node sphere
  before); one field test per step, a check every `DAWN_INTERVAL` (1 s) per
  night mob. Camp members (their tag's unit is a camp) and every mob without
  the clock stay. Fixture and engine probe `tools/r35_e`.

## Room for a body

- **One collision-box test (Round 67 WORLD):** `grug_mobs/room.lua`
  `grug_mobs.box_blocked(pos, box)`: a walkable node's real collision boxes
  (`core.get_node_boxes`) overlapping the box shrunk by 0.05 per side,
  boxes up to half a node above its bottom counted as footing; unknown and
  unloaded nodes solid. Its users: `spawn_room_refused` (a mob wider than one
  node, from `mobs:spawn_abm_check`, init.lua), `tier_scale` (levels.lua
  `apply_tier_visuals`; the applied scale is the saved `_grug_visual_scale`
  and the feet are kept), the stuck cleanup (`give_up_stuck` from aggro.lua
  `give_up_target` flags; `stuck_tick` from the `do_custom` wrapper after
  `dawn_tick` removes once nobody is within `STUCK_WATCH` (32, `room.lua`)
  nodes; `grug_mobs.mob_bound`, dawn.lua's list, stays) and the flying
  mount's summon (grug_mounts entity.lua). Fixture `tools/r67_world`.

## Flier clips

- **Fly clip in the air (Round 45 playtest):** `grug_mobs/flight.lua`
  `install_flier_animation`, called by `grug_mobs.register_mob` right after
  `mobs:register_mob`, wraps `set_animation` on the prototype of every air
  flier (`fly_in` "air" or a list holding it, `fly` or `keep_flying`) that
  has a fly clip: a "stand", "walk" or "run" request plays "fly" while the
  mob flies (`self.fly`), is inside its element (`flight_check`) and does
  not stand on walkable ground out of water — the rule of do_states' walk
  state and `grug_mobs.walk_animation`. The swing lock still holds those
  requests back while a punch clip runs. Fixture `tools/r45_pt7`.

## Mobs in water

- **Mobs in water (Round 34 F1):** the wading rule lives in the vendored
  probe (`grug_may_wade`, see the `GRUG PATCH` list); the way back to land is
  `grug_mobs/aggro.lua` `shore_check` in the 1 Hz leash tick (an idle
  floating mob in water swims toward its home). `floats` is a boolean in
  every definition. Fixture and engine probe `tools/r34_f1`.
- **Speed in water (Round 84 WATER, rulings 3 and 4):** the vendored
  `grug_liquid_speed` (`mobs/api.lua`, shared by `set_velocity` and the stuck
  detector's expected speed) leaves a mob in a `water`-group node at its land
  speed times its definition's `_grug_water_speed_factor` (nil: 1; copied
  onto the entity by `register_mob`, so a retune reaches saved mobs); any
  other viscous liquid (lava) still divides by viscosity + 1. A per-medium
  speed is this factor, never a second writer of `walk_velocity` /
  `run_velocity` (those belong to the root/slow engine, init.lua). The
  Tortoise (`tortoise.lua`) uses it (1.25) and is a neutral `dogshoot` mob
  with `_grug_shot_range` 33 and its own homing mud ball, whose hit slows
  through `grug_mobs.slow_player`. Fixture `tools/r84_water`.
