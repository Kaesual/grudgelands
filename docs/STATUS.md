# Project status

Updated 2026-10-02. This is the delivery pointer, not another game specification.

- **Round 28 delivered locally** (2026-10-02,
  [plan, completion and playtest checklist](planning/round28-questing-leveling-plan.md#completion-2026-10-02)).
  Every lane is merged on main (last lane W1 `f35998d5`); pushed up to
  `9dd85b6e` (Tracks A and B, catalogue, icons); N1, S1, M1, Q0, S2 and W1
  are local. Each lane was independently reviewed by Opus.
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
    terrain kinds, camps and leaders by rule; leaders 1.15× and 2× HP), with
    the border rule across zones ([spawn_regions.md](design/spawn_regions.md)).
    The Broken Causeway plays 41–50, Gravesalt Escarpment and The Skyglass
    Canopy 51–60 (gameplay band; the mapgen is unchanged).
  - **Players see:** each objective's target level range in the quest log
    and offer; the zone or town name under the minimap, zone markers on the
    Map tab and a short entry banner ([world_map.md](design/world_map.md)).
  - **Interim:** the 240 legacy quests stay until new quest files replace
    them (their XP is oversized against the new curve; 22 accepted
    `W-recipe-target` warnings); the Causeway's plants and ores still follow
    31–40. The quest content per race track, the front and island quests
    move to Round 29 with the economy, WP17 and a mapgen bundle.
  - Next: synchronize, push, fresh world and spawn playtest.

- **Round 27 delivered locally** (2026-09-30, WP50,
  [plan, completion and playtest checklist](planning/round27-minimap-plan.md#completion-2026-09-30)).
  Lanes M (`cda93c90`) and D merged on main; pushed up to `96bcab41`.
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
- **Latest game:** local main carries Round 28, which includes Rounds 20–27
  and the 2026-09-28 playtest fixes. Round 24 is the latest accepted state;
  the 2026-09-30 playtest with friends fed Round 28. Fresh-world development
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
  The [Round 28 checklist](planning/round28-questing-leveling-plan.md#playtest-checklist)
  covers the spawn regions, fixes, slots, feed and zone names, the
  [Round 27 checklist](planning/round27-minimap-plan.md#playtest-checklist)
  covers the minimap and map quality, the
  [Round 26 checklist](planning/round26-capitals-housing-cleanup-plan.md#playtest-checklist-fresh-world)
  the capitals and Claim Stone activation, the
  [Round 25 checklist](planning/round25-housing-plan.md#playtest-checklist-fresh-world)
  the rest of housing; earlier rounds keep their own checklists. The
  user wants a separate walk of the Round 20 POI art (audit E2).
- **Remote observation:** local `origin/main` is `9dd85b6e` (observed
  2026-10-02: Round 27 complete and Round 28 up to the loot icons). Round 28
  N1, S1, M1, Q0, S2 and W1 are local only.
- **Release:** unreleased fresh-server development. The Nether is expansion
  content. [First-public-release gates](../BACKLOG.md#first-public-release-gates)
  remain open.

Older deliveries: [R18](research/round18-completion.md),
[R17](research/round17-completion.md), [R16](research/round16-completion.md),
[R15](research/round15-completion.md), [R14](research/round14-completion.md),
[R13](research/round13-completion.md), [R12](research/round12-completion.md),
[R11](research/round11-completion.md). Read these for evidence or provenance,
not to reconstruct the current rules from successive overrides.
