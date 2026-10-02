# Project status

Updated 2026-10-02. This is the delivery pointer, not another game specification.

- **Round 30 "Performance and clean-up" delivered locally** (2026-10-02,
  [plan, completion and playtest checklist](planning/round30-plan.md#completion-2026-10-02)).
  Every lane is merged on local main (last lane P2, `b64709d7`), each
  independently reviewed by Opus; not pushed. Numbers are each lane's
  before/after comparison on its own probe, never targets.
  - **Quest state and map UI (P1, P1b):** a decoded quest-state cache and one
    marker pass for all givers (minimap 55.8 → 9.3 ms/s, quest HUD 17.1 →
    6.5 ms/s at 40 stand-ins); the Map tab sends at most every 2 s and only
    on a change (17.2 → 0.93 ms/s, 179 → 33 KB/s); **Return home** moved to
    the Character page (user ruling); quest markers and NPC tags follow held
    objective items and level-ups within about 1.5 s
    ([world_map.md](design/world_map.md), [home_travel.md](design/home_travel.md)).
  - **Region-map cache and boot memory (P3):** the region maps and the Map
    tab's zone grid are read from the world folder on a later start (warm
    boot 15.3 → 7.2 s), only the compact maps stay in memory (Lua heap
    127.6 → 70.5 MiB), boot peak memory 2.12 → 1.76 GB
    ([spawn_regions.md](design/spawn_regions.md#cache-and-memory)).
  - **Mob pathing and spawning (P2):** A* inside about 3 ms per server step
    with waits after a failed search, and **mobs give up a target they cannot
    reach** after three failed searches (dragons only wait, kings only drop
    the target; 40 blocked chasers 6.83 → 0.68 ms per step); no per-step
    `get_properties()` (garbage 7.75 → 4.93 MiB/s); 56 of 88 spawn rows
    retired and the rest in three merged ABMs (block scans 404 → 104 per
    second); the `general_attack` eye-height bug fixed
    ([combat_stats.md](design/combat_stats.md), [biomes_mobs.md](design/biomes_mobs.md) §4).
  - **Per-player ticks (P4):** a crafting lookup index (200 → 5 µs), the
    crosshair state every 0.15 s (14 → 7.7 ms/s standing), tag carriers in
    eight slots, the flight-border sweep 268 → 43 µs, fewer crop-soil timers.
  - **Island landings (L):** a sand beach and a wooden pier at each of the
    four dragon-island landings; the islands get no paths or roads by design
    ([boats.md](design/boats.md) §7.1).
  - **Clean-up (C):** the legacy quest fields removed (unknown fields stop the
    load), the stale fixtures repaired, the riding-tier purchase fixture, no
    craft warnings at boot; the **Dawnmere NPC duplication** found and fixed
    (start NPCs could come back twice after an early block unload).
  - **Band smoothing (E):** band-4/5 loot medians 39.0 → 43.6c and 147.6 →
    119.5c; Expert Riding 1g37s, respec 31–40 2s and 41–50 6s
    ([economy.md](design/economy.md)).
  - Final fresh-world engine check: at integration. Next: synchronize,
    fresh world, the user's GUI test; then Round 31 PvP.

- **Round 29 "Economy and travel" complete and pushed** (2026-10-02,
  [plan, completion and playtest checklist](planning/round29-plan.md#completion-2026-10-02)).
  Every lane is merged on main (last lane D, `e512bb5c`), each
  independently reviewed by Opus; the user tested it on a fresh world and
  pushed it. The quest lanes were merged
  together after the user approved a sample per track.
  - **Quests (Q1–Q9, T):** 491 quests in 42 zone files replace the 240
    legacy quests: one track per race from the start zone to its heartland
    (Human 54, Dwarf 58, Elf 71, Undead 53, Orc 48, Troll 63), the contested
    31–40 zones (35 / 30) and the 41–60 front with repeatable and island
    bounties (40 / 39). Seed-dependent directions are placeholders filled
    from the spawn regions; fixed compass words fail the load; copper comes
    from the quest's weight; the front budget counts two repeats per bounty.
    Every target forms on six seeds
    ([quests.md](design/quests.md)).
  - **Economy (E1, E4; WP44 delivered):** one price module for every
    payout (loot and gathered goods by class and tier, processed goods by
    their inputs, 5 % buy-back on vendor goods), shelves by the vendor
    rule, the Common gear axis 25c … 25s, repair at crafting stations in an
    active claim; riding 1s10c / 7s / 1g37s / 7g33s, boats 1s10c / 7s,
    respec 15c … 12s from a per-band income estimate
    ([economy.md](design/economy.md)).
  - **Travel (B, W, A; WP17 delivered):** boats as water mounts from the
    Shipwright in every capital (L15 and L30), waystones in all six capitals
    and starts with instant free travel between discovered stones, the
    Kraken Guard at 10 nodes/s in deep ocean
    ([boats.md](design/boats.md), [world.md](design/world.md) §6).
  - **Mapgen bundle (M-res, M-geo):** gems by depth (T1 Citrine … T6
    Diamond), `apex_sockets` removed, mapgen band data (Causeway 41–50,
    Gravesalt and Skyglass 51–60), the Battlegrounds about 50 % larger with
    a middle road from Highcourt to Gor Drazhak. A fresh world is required.
  - **Spawn playtest fixes (P):** no spawn puff, leader HP 1.5×, the Basics
    book's tiers (T6 shows 36 recipes).
  - **Performance review** (read-only):
    [perf-review-2026-10.md](research/perf-review-2026-10.md); its lanes
    P1–P4 and the user's rulings became Round 30.
  - **Final engine check PASS** (seeds 42 and 20261002): middle road,
    Battlegrounds borders, bands, moved sites, channel, waystones and
    Shipwrights, gems by band, clean load. Finding: the dragon-island boat
    landings were mostly a one-node shore strip below high cliffs (piers
    and beaches in Round 30).

- **Round 28 complete and pushed** (2026-10-02,
  [plan, completion and playtest checklist](planning/round28-questing-leveling-plan.md#completion-2026-10-02)).
  Every lane is merged on main (last lane W1 `f35998d5`), synchronized to
  Luanti and pushed. Each lane was independently reviewed by Opus.
  - **Track A (playtest fixes):** road protection half width + 1 and idle
    aggressive mobs walk away from roads and towns; mob environmental damage
    in percent of max HP, melee knockback as a small displacement, hits never
    stall a mob's attack clock, simple separation; elites at scale 1.4,
    kings at size 1.6, world-sized HP bars, rotated selection boxes; Charge
    checks its landing
    room, failure messages are back, the LMB lock decides combat or gather at
    key-down; one respawn teleport without launch, death messages name the
    shooter, stations drop their contents when dug; the message feed above
    the bars, riding trainer states, "Damage reduction", the Professions tab
    and "N locked" recipe books; per-class offhand (shield, caster offhand,
    Scout melee), Scout ranged and melee slots and the Scout-only quiver.
  - **Track B (framework):** data-driven mob sub-types and loot by level band
    with a participant drop hook; kill XP `M(L) = 25 + 5L` and the curve
    `M(L) × (8 + 0.29(L − 1))` (4,200 XP to L10, 194,220 to L60), quest and
    gathering XP in kill equivalents; quests as per-zone JSON with item-group,
    multi-objective, area and quest-drop objectives, repeatables, travel
    credit on accept and load-time validation; self-contained professions
    (no metal fittings, data-driven enchant inputs, six duplicate cooking
    routes removed) ([progression.md](design/progression.md),
    [quests.md](design/quests.md), [biomes_mobs.md](design/biomes_mobs.md)).
  - **Catalogue:** 195 sub-types (49 named leaders, 18 elites), 119 loot
    items with 89 new icons, drops and enchant inputs per band; signal words
    (Small, Large, Braindead …) only in start zones, a unique name everywhere
    else.
  - **Spawn regions:** every one of the 38 zones spawns its surface mobs
    from a rule recipe built on the seed's own terrain (32-node cells, belts,
    terrain kinds, camps and leaders by rule; leaders 1.15× size and 2× HP,
    1.5× HP since Round 29), with
    the border rule across zones ([spawn_regions.md](design/spawn_regions.md)).
    The Broken Causeway plays 41–50, Gravesalt Escarpment and The Skyglass
    Canopy 51–60 (gameplay band; the mapgen is unchanged).
  - **Players see:** each objective's target level range in the quest log
    and offer; the zone or town name under the minimap, zone markers on the
    Map tab and a short entry banner ([world_map.md](design/world_map.md)).
  - **Interim (resolved in Round 29):** the 240 legacy quests stayed until
    new quest files replaced them; the Causeway's plants and ores followed
    31–40 until the mapgen band data. The quest content per race track, the
    front and island quests moved to Round 29
    ([quests plan](planning/round29-quests-plan.md#1-why-this-is-its-own-step))
    with the [economy](planning/economy-vendor-plan.md),
    [boats and waypoints](planning/travel-boats-waypoints-plan.md) and a
    mapgen bundle.
  - The spawn playtest (2026-10-02) fed Round 29 (findings P1–P4).

- **Round 27 delivered and pushed** (2026-09-30, WP50,
  [plan, completion and playtest checklist](planning/round27-minimap-plan.md#completion-2026-09-30)).
  Lanes M (`cda93c90`) and D merged on main; fully pushed (in `9dd85b6e`).
  The Round 26 playtest fix for capital walls (no gaps at gatehouses, fewer
  walls in rivers) is merged as `1ff541e4`; follow-ups in the BACKLOG.
  - **M:** our own round, north-up minimap in the native minimap's box
    (about 900 nodes, snapped to a coarse grid so the client texture cache
    grows only per cell) with quest givers by state, the Housing Steward,
    trainers, innkeepers, home and party members with rim arrows; native
    minimap off; a "Show minimap" switch on the Map tab. `grug_map_quality`
    normal (1080×960, about 10 s, 0.92 MB) or high (3600×3200, about 56 s,
    6.93 MB), sent as 512 px tiles; hillshade, 16/64-node contours and a
    stone tint; region-label scrollbar fix
    ([world_map.md](design/world_map.md)).
  - **D:** documentation of the Lane M facts and WP50 closure.
  - **Glide follow-up** (merged as `9c8ece8c`,
    [follow-up](planning/round27-minimap-plan.md#follow-up-gliding-minimap-2026-09-30)):
    the arrow stays centred and the map glides under it every server step
    inside a pewter bezel; about 880 nodes, one texture per 6 (normal) or 16
    (high) base-pixel cell, high at half resolution; about 3.7–3.9 times the
    snapped HUD traffic.
  - Next: short playtest.

- **Round 26 delivered locally** (2026-09-29,
  [plan, completion and playtest checklist](planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29)).
  All lanes are merged on local main: S `377e7cd4`, R `4e88234c` with the Troll follow-up `ed7d79a1`, I `abaaa262`, W `ce2264e9`, D (branch `r26-d-docs`). Pushed.
  - **S:** a placed Claim Stone is a half-transparent draft that protects
    nothing and crumbles after 5 minutes unless activated with 5 lumps; the
    only lock is 12 hours without pick-up after activation; the Housing
    Manager is now the Housing Steward; `/claim_remove`; snow in the arrival
    cube can be dug ([housing.md](design/housing.md) §§2a, 3, 5).
  - **R:** mobs_redo utility items and silver-sandstone recipes removed, all
    tier tools under `grug_materials:` with 12 aliases, the two surface
    critters at 0.75 density (WP28 delivered); Trolls also get +50% food
    healing.
  - **I:** the status icon row above the skill bar (green/red/gold frames,
    at most 10, no cooldowns), a combat icon right of the health bar instead
    of the "Combat" text, Character page Stats/Effects tabs and class icons
    in the party HUD and Group page (audit D10;
    [inventory_equipment.md](design/inventory_equipment.md) §5).
  - **W:** more irregular, still star-shaped capital outlines at about the
    same area, a character per capital, towers at bends and gatehouses, and
    a replan when a named building is dropped (2 → 0 of 200 seeds; planning
    5.7 → 6.2 s per seed, preparation 14.5 → 14.9 CPU s; engine check seed
    42 PASS 36/36) ([world_zones.md](design/world_zones.md) §12).
  - **D:** documentation after the
    [work-package audit](planning/wp-audit-2026-09-29.md) and its
    [user decisions](planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29),
    then the lane facts.
  - Next: fresh world and playtest.

- **Round 25 delivered locally:** Claim Stone housing (WP24,
  [housing.md](design/housing.md)): one free, soulbound stone from the
  Housing Steward in each capital from level 20; a 101 × 101 claim column from
  y = −100 up in the own L11–30 home zones, 16 nodes clear of settlement cores
  and hard footprints; coal or charcoal fuel as a "paid until" time (a full
  slot lasts about a month); Interact/Everything permissions with a
  right-click and node-inventory guard; stone form, Character-page status;
  the stone as travel home with an arrival cube; no hostile spawns in active
  claims; housing masks removed. Roads, bridges and POI, village and camp
  cores are protected for everyone, with hint reasons ("Road – protected").
  The capital planner places required and named buildings before fill: load
  failures 1.3 % of seeds → 0 of 200, capital layouts changed. All nine lanes
  merged on local main (`7ca48666`), independently reviewed and synchronized
  to Luanti on 2026-09-29. Pushed.
  [Plan, completion and playtest checklist](planning/round25-housing-plan.md#completion-2026-09-29).
  The first playtest has started; its follow-up rulings 30–33 feed Round 26.

- **Round 24 delivered, pushed and accepted:** tier rocks with engine-native pick gating
  replace depth bounds and shatter (loose ground by hand or shovel, axe and
  shovel tiers, protection and pick hints on punch, tool level requirements);
  the terrain fill hosts ores and bands (coal near the Orc start 0.10–0.37 →
  0.90–1.05 of target at 5–16 depth), with mountain and cliff layers,
  decorative nests and output-identical P8 speedups (about 20 % less Lua
  mapgen time); start-zone level gradient, 32-node idle wander leash, calm
  roaming pace, filled thin spawn cells and a per-zone mob density budget
  (about 1.5×); gathering XP; ten one-line tracked quests; lava and drowning
  scaled to max HP; hard protection from 100 below each footprint's placement
  height instead of y ≥ −700; housing areas as ordinary terrain; pausable
  character creation. All 13 lanes reviewed and merged (`1e338503`) and
  synchronized to Luanti on 2026-09-29. Pushed with the playtest
  protection-hint fix and the Round 25 plan as `d4eaffff`; accepted by the
  user.
  [Plan, completion and playtest checklist](planning/round24-mining-underground-mobs-plan.md#completion-2026-09-29).

- **Round 23 delivered locally:** full-column world preparation (a finished
  full-world preparation leaves nothing to generate for walking, diving or
  flying; fast path for air chunks), habitat-driven vegetation renewal
  replacing the exact-baseline ecology (saplings behind `grug_tree_regrowth`),
  and capital walls (Highcourt core wall, Lethariel curtain, Kezamba palisade,
  taller cores, closed Nhal Veyr bars, walls end at lake shores). All lanes
  independently reviewed, merged and synchronized to Luanti.
  [Completion and GUI checklist](research/round23-completion.md),
  [plan](planning/round23-world-life-plan.md). No push. Phase 2 (tree line
  with shrub band and snow caps, forests and clearings) and the lake-wall
  playtest fix are merged (`f54c299d`) and synchronized.

- **Playtest fixes 2026-09-28 delivered locally:** food click/hold input,
  server-side node UIs, crosshair range feedback with own crosshair, 2.5 s bow
  draw with damage curve and power ring, eating visual, movement stances,
  swimmers stay in water, fish drop, first-person rod, recipe-book ingredient
  navigation, Blink targeting; follow-up bow tuning, eating ring and immediate
  combat exit. Eight lanes independently reviewed, all probes and a headless
  boot passed on merged main `fede63db`; synchronized to Luanti.
  [Receipt and GUI checklist](research/playtest-fixes-2026-09-28.md). No push.

- **Round 21 startup correction:** fixed the missing fish disposition and native
  arrow recipe catalog binding; real isolated server startup and 200-arrow craft
  passed. Merged as `f00433c7` and synchronized.
  [Receipt](research/round21-startup-fix.md). No remote push.
- **Round 21 delivered locally:** terrain/POI access, resource calibration,
  furnaces, aquatic detail and feedback fixes. Independently reviewed, final
  gates passed, merged as `96c40fa3` and synchronized to Luanti on 2026-09-24.
  [Receipt](research/round21-completion.md), [playtest](research/round21-playtest.md),
  [execution state](planning/round21-state.md). No remote push.
- **Round 20 delivered locally:** 240 quests, all 100 anchor art slots, contextual
  input and equipment/UX fixes. Independently reviewed, final gates passed,
  merged as `8308229f` and synchronized to Luanti on 2026-09-24. No push.
  [Completion receipt](research/round20-completion.md),
  [playtest checklist](research/round20-playtest.md),
  schematic POI gallery (`tools/r20/evidence/pois/`, retired in Round 22;
  git history keeps it).
- **Documentation consolidation:** complete with independent Astra PASS;
  [receipt and coverage](maintenance/documentation-round.md). Remaining decisions
  and code/design discrepancies: [findings](maintenance/findings.md).
- **Latest game:** local main carries Round 30, which includes Rounds 20–29
  and the 2026-09-28 playtest fixes. Round 29 is the latest pushed state,
  tested by the user on a fresh world (2026-10-02); Round 24 is the latest
  formally accepted one. The 2026-09-30 playtest with friends fed Round 28,
  the 2026-10-02 spawn playtest Round 29. Fresh-world development
  remains in force.
- **Technical reviews/gates:** recorded PASS for those delivered candidates;
  not a fresh certification of arbitrary later changes.
- **Preparation performance follow-up:** the bounded two-request pipeline
  completed the same measured prefix in a further 24% less time than the prior
  40 ms scheduler. Its native emerge worker reached 99.43% of one core over the
  matched steady interval. Completed preparation remains inactive during later
  on-demand cave generation; engine tick/thread settings are unchanged.
  Independent review, native comparison, two-pending stop/resume and final
  interpreter parity passed. Merged to local main and synchronized. Receipt:
  [full-speed follow-up](research/pregen-fullspeed.md). No remote deployment
  claimed. Prior measurement: [scan-budget follow-up](research/pregen-scan-budget.md).
- **GUI acceptance:** user-run and pending where not explicitly accepted.
  The [Round 30 checklist](planning/round30-plan.md#playtest-checklist)
  covers the Map tab rate, quest markers, Return home on the Character page,
  mobs giving up, spawns, crafting, the crosshair, island landings, prices
  and the faster second start; the
  [Round 29 checklist](planning/round29-plan.md#playtest-checklist)
  covers quests, economy, gems, prices, the Battlegrounds, boats and
  waystones (tested by the user 2026-10-02), the
  [Round 28 checklist](planning/round28-questing-leveling-plan.md#playtest-checklist)
  covers the spawn regions, fixes, slots, feed and zone names, the
  [Round 27 checklist](planning/round27-minimap-plan.md#playtest-checklist)
  covers the minimap and map quality, the
  [Round 26 checklist](planning/round26-capitals-housing-cleanup-plan.md#playtest-checklist-fresh-world)
  the capitals and Claim Stone activation, the
  [Round 25 checklist](planning/round25-housing-plan.md#playtest-checklist-fresh-world)
  the rest of housing; earlier rounds keep their own checklists. The
  user wants a separate walk of the Round 20 POI art (audit E2).
- **Remote observation:** Round 29 is pushed complete (`e512bb5c`,
  2026-10-02), including Rounds 27 and 28. Round 30 is local only.
- **Release:** unreleased fresh-server development. The Nether is expansion
  content. [First-public-release gates](../BACKLOG.md#first-public-release-gates)
  remain open.

Older deliveries: [R18](research/round18-completion.md),
[R17](research/round17-completion.md), [R16](research/round16-completion.md),
[R15](research/round15-completion.md), [R14](research/round14-completion.md),
[R13](research/round13-completion.md), [R12](research/round12-completion.md),
[R11](research/round11-completion.md). Read these for evidence or provenance,
not to reconstruct the current rules from successive overrides.
