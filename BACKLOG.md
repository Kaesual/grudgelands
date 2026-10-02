# Backlog — Work Packages

Current implementation work and remaining scope. [Design](docs/design/README.md)
owns game rules; [ROADMAP](ROADMAP.md) owns goals; [project status](docs/STATUS.md)
owns the latest local/remote delivery and GUI acceptance. Completed implementation
narratives are [historical receipts](docs/archive/planning/backlog-before-consolidation.md),
not additional current contracts. No behavior changes are authorized by this cleanup.

## Readiness

There are **54 identities**: WP0–WP50 and WP-Scout/WP-HUD/WP-Speed.
**42 delivered**, **3 canceled** (WP16, WP37, WP49), **9 open or partial**.
The 2026-09-29
[WP audit](docs/planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
closed WP14, WP21, WP22, WP23, WP27, WP29, WP31 and WP32 as delivered, merged WP7's rebase, WP11, WP30 and the price parts of WP22 and
WP31 into WP44 (WP11 and WP30 count as delivered), and canceled WP37 and WP49.
WP28 followed in Round 26, WP50 in Round 27, WP17 and WP44 in Round 29. The
audit's letters and numbers (for example E5) are cited below.

- **Latest delivery:
  [Round 30 "Performance and clean-up"](docs/planning/round30-plan.md#completion-2026-10-02)
  complete locally** (2026-10-02, not pushed): the
  [performance review](docs/research/perf-review-2026-10.md)'s lanes P1–P4
  (quest-state cache and Map tab every 2 s, the region-map file cache and boot
  memory, the per-step A* budget with the give-up of unreachable targets and
  three merged spawn ABMs, per-player ticks), Return home on the Character
  page, piers and beaches at the dragon-island landings, the quest and fixture
  clean-up with the Dawnmere duplication fix, and the band-4/5 loot smoothing
  with recomputed prices. Next: fresh world and GUI test, then Round 31 PvP
  ([Round 30](#round-30--performance), [carry-overs](#round-30-carry-overs)).
- [Round 29 "Economy and travel"](docs/planning/round29-plan.md#completion-2026-10-02)
  (2026-10-02, pushed as `e512bb5c` after the user's fresh-world test): 491 quests on the Round 28
  framework replace the 240 legacy quests (one track per race, the
  contested 31–40 zones, the 41–60 front with repeatable and island
  bounties; WP9 advances); WP44 delivered (one price module, 5% buy-back,
  income-derived mount, boat and respec prices, claim-station repair D7);
  WP17 delivered (boats as water mounts, the Shipwright, waystones at every
  start and capital, the Kraken retune); a mapgen bundle (gems by depth,
  `apex_sockets` removed, mapgen band data, the Battlegrounds 50 % wider
  with a middle road); the spawn playtest fixes; a read-only
  [performance review](docs/research/perf-review-2026-10.md), which became
  Round 30 ([carry-overs](#round-29-carry-overs)).
- [Round 28](docs/planning/round28-questing-leveling-plan.md#completion-2026-10-02)
  (2026-10-02, pushed): the 2026-09-30 playtest fixes, the questing and
  leveling framework, the catalogue with 89 icons and the naming rule,
  rule-based spawn regions for all 38 zones with the border rule,
  quest-log level ranges and zone names. It advanced WP5, WP6, WP8 and WP10.
- [Round 27](docs/planning/round27-minimap-plan.md#completion-2026-09-30)
  (2026-09-30; pushed): WP50 delivered — our own
  round minimap with quest, service, home and party markers in place of the
  native one, the `grug_map_quality` setting (normal/high) for the Map tab and
  the minimap, readable relief and the tiled map base (Lane M), and the
  documentation (Lane D). Next: short playtest.
- [Round 26](docs/planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29)
  (2026-09-29, pushed): Claim Stone draft and
  activation with the Housing Steward (Lane S), the registration cleanup
  (WP28 delivered, Lane R), the status-icon package (audit D10, Lane I),
  organic capitals with a character per capital (the D72 follow-up, Lane W)
  and its documentation cleanup (Lane D). Next: fresh world and playtest.
  Not in that round: the depth pulse (WP34), WP44, WP17, WP41, WP9, WP5 and
  WP10.
- Round 25 delivers WP24 Housing; its playtest is under way. Round 24 is
  pushed (`d4eaffff`) and accepted.
- **V1 scope** ([ROADMAP](ROADMAP.md#v1-scope)): WP17 boats and waypoints (starts
  and capitals only), WP41 geographic PvP and WP9's story levels 41–60 with
  the finale are V1; WP42's scripted NPC battles come after V1, while small
  PvP POIs may come in V1.
- **Removed systems** (never to be built): renewable ores and camp sockets
  (E5), natural out-of-combat HP regeneration and rested XP (WP21: food is the
  recovery system), carried torch light (C5), the dragon hoard chest (E11) and
  `/unstuck` (B3).
- Open work without its own WP: friendly-guard healing stays deferred as a
  coherent support-combat feature (rule owner `combat_stats.md`); the T6 lava
  lakes of `world.md` §4c stay planned (E3) with no scheduled owner. Repair at
  crafting stations inside a claim (D7) shipped in Round 29.

“Delivered” records the package's bounded development delivery. It does not mean
all later refinements, release gates or user GUI checks have passed. Historical
technical evidence certifies its recorded bytes, never an arbitrary later head.

## Phase 1 (MVP)

| WP | Scope | Status / remaining work | Dependencies |
|----|-------|-------------------------|--------------|
| WP0 | Game foundation | Delivered; historical receipt below. Current rules: topic design. | — |
| WP1 | Starter mobs, XP and drops | Delivered; historical receipt below. Current rules: topic design. | — |
| WP2 | First territory mapgen (superseded by WP40) | Delivered; historical receipt below. Current rules: topic design. | — |
| WP3 | Character creation and original classes | Delivered; historical receipt below. Current rules: topic design. | — |
| WP4 | Original ability framework | Delivered; historical receipt below. Current rules: topic design. | — |
| WP5 | [Loot, found-item affixes and cultural/PvP finishes](docs/planning/work-package-scopes.md#wp5) | Found-item loot and selected enchanting delivered; Round 28 adds loot by level band (family drop tables, 119 catalogue items) and data-driven enchant inputs. Round 29's per-band payout calibration completes the loot/demand audit. Cultural/PvP finishes and masterwork (item-level-70 upgrade, D3) open. Named rares drop no trophies (D4). | WP1 ✅, WP3 ✅, WP43 ✅ |
| WP6 | Mob roster, threat, guards and combat feel | Delivered; historical receipt below. Round 28 adds sub-types (195 incl. 49 named leaders) and rule-based spawn regions for all 38 zones ([spawn_regions.md](docs/design/spawn_regions.md)); Round 29 sets leader HP to 1.5×; Round 30 lets mobs give up unreachable targets, merges the spawn ABMs and fixes the start-NPC duplication. Current rules: topic design. | — |
| WP7 | Ledger currency and traders | Delivered; Round 29 (WP44) replaced its price curve and 25% buy-back. | — |
| WP8 | Quest framework | Framework delivered; Round 20: 240 quests with talk handoffs. Round 28: per-zone quest data, area, item-group, multi-objective and quest-drop objectives, repeatables, travel credit on accept, load-time validation, target level ranges in the log. Round 29: text placeholders filled per seed, the compass-word check, copper from weight. Round 30: the legacy fields removed (unknown fields stop the load), the decoded-state cache and markers that follow held items and levels. Broader story remains WP9. | — |
| WP9 | [Named-zone story and questlines](docs/planning/work-package-scopes.md#wp9) | Round 29 replaces Round 20's 240 quests with 491 on the Round 28 framework: one track per race to 30, the contested 31–40 zones, front quests 41–60 with repeatable and island bounties. **V1:** the main storyline 41–60 and the finale remain open. | WP6 ✅, WP8 ✅, WP40 ✅; WP41 for PvP-tag quests |
| WP10 | [Profession content and priced integration](docs/planning/work-package-scopes.md#wp10) | Framework and seven catalogs delivered; Round 28 makes every profession self-contained (no metal fittings; enchant inputs = own material + tier loot + a mined or gathered item). Cultural finishing and helper NPC services remain (cultural masters later, D11). | WP5, WP26 ✅, WP33 ✅, WP43 ✅, WP44 |
| WP11 | [Talent trees](docs/planning/work-package-scopes.md#wp11) | Delivered; closed 2026-09-29, respec price merged into WP44 (C2) and set in Round 29. | WP3 ✅, WP4 ✅, WP-Speed ✅ |
| WP-Scout | Scout class and talent trees | Delivered; historical receipt below. Current rules: topic design. | — |
| WP-HUD | Exact health/resource HUD | Delivered; historical receipt below. Current rules: topic design. | — |
| WP-Speed | Shared movement modifiers | Delivered; historical receipt below. Current rules: topic design. | — |
| WP12 | World atlas | Delivered through R19: whole-atlas zoom/scroll and live markers; waystone markers came with WP17 (Round 29). | — |
| WP13 | [Remaining authored structures and POI roster](docs/planning/work-package-scopes.md#wp13) | Round 20 completes roster art; Round 21 improves access/ground; Round 23 walls all six capitals. `bandit_frontier` core stays 16 (E1); Round 26 gives every capital its own outline and character (D72). Remaining: a separate POI walk (E2). | WP40 ✅, WP43 ✅ |
| WP14 | [Offhands](docs/planning/work-package-scopes.md#wp14) | Delivered; closed 2026-09-29. Carried light canceled (C5). | WP3 ✅ |
| WP15 | Character equipment and bags | Delivered; historical receipt below. Current rules: topic design. | — |
| WP16 | Canceled historical proposal | Canceled 2026-08-12; no game code shipped. | — |
| WP17 | [Boats and waypoint travel](docs/planning/work-package-scopes.md#wp17) | **V1.** Delivered in Round 29 ([travel plan completion](docs/planning/travel-boats-waypoints-plan.md#completion-2026-10-02)): boats as water mounts from the Shipwright in every capital (the only access to the dragon islands), waystones at every start and capital, the Kraken retune. No `/unstuck` (B3). The user's Round 29 test passed; Round 30 adds a pier and a beach at each island landing (`boats.md` §7.1). | WP40 ✅, WP13 ✅ |
| WP18 | First continent map (superseded by WP40) | Delivered; historical receipt below. Current rules: topic design. | — |
| WP19 | Original kit and race-passive tuning | Delivered; historical receipt below. Current rules: topic design. | — |
| WP20 | Same-faction parties | Delivered R14–19: persistent parties, management and optional HUD. | — |
| WP21 | [Recovery/rest](docs/planning/work-package-scopes.md#wp21) | Food recovery delivered; closed 2026-09-29: food is the recovery system, no natural HP regeneration, no rested XP. | WP1 ✅ |
| WP22 | [Tool wear and repair](docs/planning/work-package-scopes.md#wp22) | Delivered; closed 2026-09-29. Dig speed stays as in the game (D8); prices to WP44; claim-station repair (D7) below. | WP43 ✅ |
| WP23 | [Dragon encounters](docs/planning/work-package-scopes.md#wp23) | Delivered R8–R10; closed 2026-09-29. Boat route → WP17, island PvP tag → WP41; no hoard chest (E11), no apex sockets (E5). | — |
| WP24 | [Open-world Claim Stone Housing](docs/planning/work-package-scopes.md#wp24) | Delivered in Round 25 ([completion](docs/planning/round25-housing-plan.md#completion-2026-09-29)): Claim Stones as in `housing.md`, no price, housing masks removed; road and POI protection alongside. Round 26 Lane S adds the draft and 5-lump activation, the 12 h pick-up lock, the Housing Steward and admin removal. User playtest under way; carry-overs below. | WP40 |
| WP25 | Original strata/materials (superseded by WP43) | Delivered; historical receipt below. Current rules: topic design. | — |
| WP26 | Furnace and alloy chain | Delivered; historical receipt below. Current rules: topic design. | — |
| WP27 | [Armor catalog](docs/planning/work-package-scopes.md#wp27) | Delivered; closed 2026-09-29 (no G2 surcharge, Round 10 ruling 7). | WP26 ✅, WP43 ✅ |
| WP28 | [Remove superseded recipe/tool registrations](docs/planning/work-package-scopes.md#wp28) | Delivered in Round 26 Lane R: mobs_redo utility items removed (D5), silver-sandstone recipes removed (D6), all tier tools under `grug_materials:` with 12 aliases (D9), two surface critters at 0.75 density, `chance` 2200 → 2933 (C6). | — |
| WP29 | [Gear/tool catalog](docs/planning/work-package-scopes.md#wp29) | Delivered; closed 2026-09-29. Tool-namespace unification moved to WP28. | WP26 ✅, WP43 ✅ |
| WP30 | [Trader catalog](docs/planning/work-package-scopes.md#wp30) | Catalog delivered; closed 2026-09-29, prices merged into WP44 (C2). | — |
| WP31 | [Mounts](docs/planning/work-package-scopes.md#wp31) | Delivered (C3); prices merged into WP44 and set in Round 29; boats are the water mode since Round 29. | WP40 ✅ |
| WP32 | [Farming](docs/planning/work-package-scopes.md#wp32) | Delivered 2026-09-29 (C4), GUI acceptance pending; Claim Stone integration shipped with WP24. | WP24 ✅, WP33 ✅ |
| WP33 | Gathering/source catalog | Delivered; Round 23 replaces exact-baseline renewal with habitat-driven renewal ([receipt](docs/research/round23-habitat-renewal.md)). Current rules: topic design. | — |
| WP34 | [Deep spawn pulse](docs/planning/work-package-scopes.md#wp34) | Only the depth pulse remains; kept, for later (E5). Renewable camp resources removed. the Land Guard and the Rift Spawn's deep row join the pulse (E4); placement and servant roster open. | WP6 ✅, WP40 ✅ |
| WP35 | Equipped weapon source and appearance | Delivered; historical receipt below. Current rules: topic design. | — |
| WP36 | Reference submodules and first runtime fixes | Delivered; historical receipt below. Current rules: topic design. | — |
| WP37 | [Surface-density cut](docs/planning/work-package-scopes.md#wp37) | Canceled 2026-09-29: superseded by Round 24 ruling 27 (about 1.5× density). Only Bone Weevil and Bog Fowl get 0.75 density (`chance` 2200 → 2933), delivered with WP28 (C6). | WP6 ✅ |
| WP38 | Held melee timing and settlement | Delivered; historical receipt below. Current rules: topic design. | — |
| WP39 | Crosshair-authoritative combat | Delivered; historical receipt below. Current rules: topic design. | — |
| WP40 | Named-zone world foundation | Development delivery accepted; first-public-release gates remain open. | — |
| WP41 | [Geographic PvP transaction](docs/planning/work-package-scopes.md#wp41) | **V1.** Open; geography seam delivered; WP5 hooks are consumption-only. Brief partly stale (death XP, Home Stone channel). | WP39 ✅, WP40 ✅ |
| WP42 | [Bounded war-front encounters](docs/planning/work-package-scopes.md#wp42) | **After V1** (scripted battles; PvP POIs may come in V1). Anchors and art delivered; may precede WP41 (B6). | WP13 ✅, WP40 ✅ |
| WP43 | Canonical material/depth registry | Delivered; Round 24 replaces pick depth bounds and shatter with tier rock and engine-native gating (rulings 1–8). Current rules: topic design. | — |
| WP44 | [Economy rebase, lighter pass](docs/planning/work-package-scopes.md#wp44) | Delivered in Round 29 ([lane status](docs/planning/economy-vendor-plan.md#lane-status-round-29-2026-10-02)): one price module for every payout, 5% buy-back on vendor goods, the vendor rule and shelves, the audit fixes, quest copper from weight, repair at claim stations (D7), mount, boat and respec prices from a simple income estimate (D1, D2); gems by depth. The user's Round 29 test passed; Round 30 smooths the band-4/5 loot medians and recomputes Expert Riding and two respec prices. | WP7 ✅, WP43 ✅ |
| WP45 | Character-creation stasis and safe arrival | Delivered; Round 24 makes creation pausable (ruling 32). Current rules: topic design. | — |
| WP46 | Indirect terrain-damage guard | Partial: actor-neutral guard and protected water flow delivered; the fire/explosion remainder is deferred until a fire or explosion source exists (expected with V2's Nether) (E6). | WP40 ✅, WP24 ✅ |
| WP47 | Skills catalog and recoverable representations | Delivered R12–13; current rules in inventory_equipment.md. | — |
| WP48 | Mapgen writer performance and parallel emerge | Partial; parked until a playtest shows slowness (E8). | WP40 ✅ |
| WP49 | Fixed mapgen source-audit roster | Canceled 2026-09-29: its audit script was deleted in Round 22 (D1/D3/D22). | — |
| WP50 | [Own minimap and map quality](docs/planning/work-package-scopes.md#wp50) | Delivered in Round 27 ([completion](docs/planning/round27-minimap-plan.md#completion-2026-09-30)): our own round minimap on the pre-generated map with quest-giver, service, home and party markers; native minimap off; `grug_map_quality` normal/high shared with the Map tab; readable relief; 512 px tiles. Playtest pending; carry-overs below. | WP40 ✅, WP24 ✅ |

### WP46 — Terrain-damage guard: explosions, fire and lava never damage settlements or POIs

**Partial; the remainder is deferred until a fire or explosion source
exists** (E6, user decision 2026-09-29), expected with V2's Nether.
Round 11 delivers the neutral `grug_core.world_alterable` authority and the
protected ordinary/river-water flow for buckets. Nothing in the game damages
terrain today: there is no `fire` and no `tnt` mod, lava is natural only (no
bucket), the Rift Spawn explodes with terrain radius 0, and the dragon
rime/scorch effects write only into air and restore it by timer. The risk is
future content (Nether V2 fire, later explosive mobs, TNT, lava buckets).

Requirement (user 2026-09-19, extended 2026-09-29): explosions (mobs and
players) must not damage capitals, starts, landmarks and POIs, and fire must
never spread into them. A future fire or explosion guard also spares **roads
and the building cores of POIs, villages and camps** (E7, `world.md` §2 R1b).
Today `world_alterable` does not consult that Round 25 layer
(`grug_core.world_feature_at`); a future consumer must.

When the work is scheduled (with the first fire or explosion source):

1. **One guard predicate in `grug_core`**, actor-neutral, asked per node by
   every effect that changes nodes on its own (not through a player's
   dig/place, which `core.is_protected` already covers): mob explosions, fire
   spread, lava flow into non-natural nodes, boss ground effects. It covers
   the hard-protected capital cities and start towns, landmark and functional
   footprints, road corridors and POI boxes; Claim Stone claims guard only
   their arrival cube (claim protection against explosions and fire is not
   part of V1, Round 25).
2. **mobs_redo `explode` GRUG PATCH:** terrain damage stays radius 0, or the
   patched `mobs:boom` skips every node the guard refuses. Note:
   `mobs/api.lua` defaults `explosion_radius or 1`, so a new explode mob needs
   an explicit radius.
3. **Fire policy:** spread is an ABM that asks the guard per target node, has
   a burn budget per flame and never ignites settlement palettes; "eternal
   flame" nodes are decoration without spread.
4. **Lava:** mapgen keeps natural lava outside settlement and POI
   exclusions; a lava bucket, if ever added, is placement and already covered
   by `core.is_protected`.
5. **Repair safety net (optional):** an admin command that re-projects an
   authored settlement blueprint at its anchor.

Checks follow the Round 22 minimal policy: a small fixture of the guard and a
short headless probe, no KAT suite or static sweep.

### WP48 — Mapgen writer performance and parallel emerge

**Parked until a playtest shows that preparation or exploration is too slow**
(E8, user decision 2026-09-29). Performance numbers are comparisons, never
targets. The rest of this section is the record.

**Opened by the Round 9 MAP-C plateau attempt, 2026-09-19.** The WP40
writer spends its time in Lua post-processing per MODIFIED voxel (dirty-
intent scan, light-context scan, replay), with apparent fixed costs per
touched chunk slice: a v7 plateau that turns the whole sky below 441 into
stone-to-air writes raised emerge time by 30–70 % regardless of height,
and a bulk-clear fast path for the per-voxel resolution did not help
(evidence in `tools/r9_map_c/evidence/`, retired; git history keeps it).
Two levers, measured with the profiler's phase records before any change:

1. Make the post-processing loops proportional to changed runs instead of
   whole slices (Round 9 measurement: the writer was ~21 of 68 s over the
   profiler corpus; Rounds 22–24 changed the writer, so re-measure first,
   now aimed at underground chunks).
2. Move the deterministic per-chunk mapgen into Luanti's mapgen
   environment (`core.register_mapgen_script`, emerge-thread Lua states)
   and lift the pinned `num_emerge_threads = 1`; requires the global
   state (manifests, memoisation, mod storage) to become per-thread or
   read-only.

**Lever 2 is blocked by the engine (verified 2026-09-19):** Luanti issue
#9357 ("Mapgen: unfinished y-slices with num_emerge_threads > 1", open,
label non-trivial) makes v7/valleys/carpathian lose biome nodes, ores and
caves in the topmost/lowermost y-slice of mapchunks and truncates
decorations when more than one emerge thread runs; the engine therefore
enables multithreading by default only for singlenode
(`reference_projects/luanti/src/emerge.cpp:180-187`). The mapgen already
runs in the mapgen environment (`register_mapgen_script`), so the Lua side
is ready, but `num_emerge_threads = 1` stays pinned until the engine fixes
#9357 (PR #16224 pending) or the project moves to singlenode with its own
cave/ore generation, which `mapgen-control.md` rejected.

**R9-PERF substep implemented (2026-09-20):** three bounded
single-thread writer optimizations are complete: already-dirty liquid columns
short-circuit repeated neighbor scans, exact horizontal classification uses a
bounded FIFO while the lattice LRU grows from 4 to 16 entries, and composed R5
lighting is delegated to the final R6 transaction while standalone R5 keeps its
own lighting. All cold/disk measurements retain the same 97 owners, 49,664,000
voxels and content/param2/light digest. The measured sequence endpoint falls
from 77.572800 s to 64.187408 s (-17.26%); it reuses sequence endpoints and is
descriptive rather than a replicated fourth pair. The independent review found
no findings. Evidence, exact limits and the final PUC/LuaJIT parity digest are
recorded in [the R9-PERF completion record](docs/research/r9-perf-completion.md).
WP48 remains open: the engine threading block and broader changed-run
post-processing work are unchanged.

The v7 plateau (caves everywhere under the surface) is no longer a
performance question: Round 24 ruling 13 keeps caves out of the fill, and own
fill caves are only a possible later package (Round 22 D77(d)).

**Round 23 (2026-09-28)** (Phase 2 tree line: [receipt](docs/research/round23-tree-line.md)):
- Full-world preparation now covers the whole column players can trigger,
  from the neighbourhood's lowest bed minus reach up to above the flight
  ceiling.
- A writer fast path skips air chunks the writer provably cannot change.
- The Round 11 ecology main-environment `on_generated` is removed.
- Underground chunks remain the dominant Lua cost; they have no safe fast
  path yet.
- The engine threading block is unchanged. An own-engine patch was evaluated
  and deferred.
- [Receipt](docs/research/round23-full-column-preparation.md).

**Round 24 (2026-09-29):** output-identical P8 vein and layer-pass speedups
(218 of 218 chunks content-identical, about 20 % less Lua mapgen time), after
Lane B's ores and layers in the fill had cost mountain boxes about +20 %.
[Evidence](tools/r24_fill/evidence/b2.txt).

### WP49 — R7 source-audit refreeze on a fixed mapgen roster

**Canceled 2026-09-29** (C1). WP49 was to refreeze
`tools/wp40/r7/source_audit.sh` on a fixed mapgen roster (Round 9 ruling 43).
That script and the final micro were deleted in Round 22 (`66e3832e`, "retire
unused tools", D3/D22), and Round 22 D1 removed the PUC gate it served. The
frozen 157-file roster stays historical evidence only.

### Round 24 carry-overs

**Noted 2026-09-29** ([completion](docs/planning/round24-mining-underground-mobs-plan.md#completion-2026-09-29)); none blocks
the playtest.

- WP48: `tools/wp40/profile/instrument-settlement-stages.patch` no longer
  applies to `r6_settlement.lua` on main (stale since Round 22). Re-anchor it
  before the next stage profile.
- WP45: a one-time waiting-screen race when an Esc crosses a progress update.
- The "Requires level N" tooltip line does not relabel tool stacks from older
  worlds. This does not matter for fresh worlds.

### Round 25 carry-overs

**Noted 2026-09-29** ([completion](docs/planning/round25-housing-plan.md#completion-2026-09-29));
none blocks the playtest.

- **Capitals: more irregular wall outline and more variety** (user idea
  2026-09-29, audit A1–A5): **done in Round 26 Lane W.** The outline stays
  star-shaped inside the 512 reserved square; with the replan at +8 %/+16 %
  area the named-building drops went from 2 to 0 of 200 seeds.
- WP24: an admin command to remove a claim or an orphaned fuelled stone. A
  fuelled stone without a registry row (for example after a crash between the
  map save and the mod-storage save) cannot be dug by anyone (Lane A review).
  **Done in Round 26 Lane S:** `/claim_remove <player> | here | orphans`.
- WP24: a `buildable_to` node such as snow in the arrival cube cannot be dug,
  not even by the owner (arrival-cube placement guard). **Done in Round 26
  Lane S:** it is dug under the ordinary claim rules; placing stays refused.
- WP24: two touching claims can cover all three route points of one named
  rare and suppress its spawn (consequence of ruling 24). Accepted by the user
  (E12); no work.
- Housing follow-up: crafting stations inside an active claim repair at the
  trader price, as a convenience (D7, `durability_repair.md`). **Done in
  Round 29 Lane E1.**
- The per-run early-out in `world_protection` (Lane E) relies on dyadic road
  profiles (multiples of 1/16). Revisit if road profiles change.
- Remove `apex_sockets` from mapgen (E5). **Done in Round 29 Lane M-res.**

### Round 26 carry-overs

**Noted 2026-09-29** ([completion](docs/planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29));
none blocks the playtest. All are low priority.

- Capitals: Lethariel's south gatehouse sits slightly further over the civic
  lake (up to about 0.8 node); check it in the playtest.
- Capital planner hardening (optional): clamp to `rmax` after the partial
  smoothing, assert `POLY` ≥ 4, and guard a plaza that has no avenue.
- `tools/wp13/node_tiles.json` (generated) still lists `mobs:mob_repellent`;
  regenerate it. The Round 25 engine probes `tools/r25_claim_core/run.sh`
  and `tools/r25_interfaces/run.sh` assume the pre-draft Claim Stone; the
  current probe is `tools/r26_claim_activation/`.

### Round 27 carry-overs

**Noted 2026-09-30** ([completion](docs/planning/round27-minimap-plan.md#completion-2026-09-30));
none blocks the playtest.

- Map tab region labels are sized for a 1280×720 window at the default font;
  a larger client font can bring the small hypertext scrollbar back.
- In start towns several minimap markers (quest givers, trainers, innkeeper)
  stack on top of each other; like the Map tab they are not clustered. The
  playtest decides whether this needs handling.
- A new home (innkeeper binding or Claim Stone) appears on the minimap up to
  5 s later: static markers refresh on quest changes and every 5 s.
- Minimap glide: delivered 2026-09-30 (the map glides under a centred arrow
  inside a pewter bezel, merged as `9c8ece8c`;
  [follow-up](docs/planning/round27-minimap-plan.md#follow-up-gliding-minimap-2026-09-30)).

### Round 28 carry-overs

**Noted 2026-10-02** ([completion](docs/planning/round28-questing-leveling-plan.md#completion-2026-10-02)).
The Round 29 content proposed here (quest files per race track, the
contested zones and the front; economy lanes E1–E5; WP17; the mapgen bundle
with gem depth tiers, `apex_sockets` removal, the wider Battlegrounds, the
middle road and mapgen band data) is **delivered in Round 29**
([completion](docs/planning/round29-plan.md#completion-2026-10-02)); its
inputs were the [quests plan](docs/planning/round29-quests-plan.md), the
[economy plan](docs/planning/economy-vendor-plan.md) and the
[boats and waypoints plan](docs/planning/travel-boats-waypoints-plan.md).

**Future package — outpost seed** (Round 28 plan item 46, user G8): a
player-placed seed in contested land spawns workers who build a small fort;
killing the workers and destroying the seed stops it. Specified after the
playtest of the front quests and bounties.

**Catalogue and loot:**

- Elite ideas never shipped (dropped from the catalogue ideas): Rat King,
  Old/Giant Boar, Silver Fox, Rotting Brute, an elite Giant Scorpion.
- Loot text pass (identical descriptions across tiers, "Spider Silk" from
  T5/T6 outlaws): **done in Round 29 Lane E1** (tier-distinct lines, shown as
  Raw Silk).
- Six of the 195 sub-types appear in no recipe (measured 2026-10-02): the
  optional cap-1 elites `causeway_construct`, `siege_war_construct`,
  `seam_mesa_golem`, `seam_stone_golem` and `crown_stone_golem` (a recipe
  roster cannot cap a role at one) and the Salt Reef Lurker.

**Spawn regions:**

- Steep zones get no generated camp cells. Partly addressed in Round 29
  (M-geo): a camp with no block meeting every rule takes its flattest block
  up to slope 0.5.
- Camps sit in tight clusters in Mournfen and Bannerbreak.

**Quest system (Lane Q0 review notes, low severity):**

- The zone-band fallback of a target's level range ignores a definition's
  own min/max levels, and for zone-filtered kills the displayed zone and the
  zone used for the level fit can differ. Only legacy objectives reached
  these paths. **Round 30 Lane C** removed the zone filter with the legacy
  fields; the zone-band fallback now serves only a base mob in a zone
  without a recipe, which no shipped zone is.
- The game (Lua) and `tools/r28_design` (Python) disagree at edges on item
  sources.
- Wording: "level" in the quest log, "levels" on the Map tab (M1).

**Zone names (Lane M1 notes):**

- The zone marker icon on the Map tab is a placeholder for art.
- On very small windows the entry banner and the flight warning may lack
  clearance.

### Round 29 carry-overs

**Noted 2026-10-02** ([completion](docs/planning/round29-plan.md#completion-2026-10-02));
none blocks the fresh-world playtest.

- **Riding tier purchase fixture:** no portable test buys riding tiers 1–4 at the shipped prices (the boats are covered; same code path). Add a loop to `tools/r29_b` or `tools/r29_e4` when that code is next touched (E4 review, 2026-10-02). **Done in Round 30 Lane C** (`tools/r29_b` section H).
- **Band-5 loot median smoothing** (user, 2026-10-02: prices kept for now).
  E1's band-5 median per kill lands above its target and band 4's below,
  so band 5's income rises ×3.6 over band 4 instead of ×2.5 and Expert
  Riding is steep (1g63s against 1g38s on the target axis; Master 7g33s
  against 8g76s). Smoothing the band medians would move the E4 prices
  (`tools/r29_e4/income.py --check`). A few band-3 loot outliers have no T3
  replacement. **Done in Round 30 Lane E:** band 4 39.0 → 43.6c, band 5
  147.6 → 119.5c; Expert Riding 1g37s, respec 31–40 2s and 41–50 6s; the
  band-3 outliers and band 6 stay (Round 30 carry-overs).
- **Quests the new format cannot express:** kill objectives name only
  spawn-recipe roles and leaders, so enemy-faction guard quests and PvP
  quests (which also need WP41's tag) have no form. A design step first.
- **Legacy quest fields in code:** no shipped quest uses `mobs`, `zone`,
  fixed `xp`, `faction`/`race` gates or the line `legacy`, but
  `grug_quests` (`registry.lua`, `validate.lua` incl. `LEGACY_GUARDS`) and
  `tools/r28_design/validate.py` (`--legacy`, its README) still accept
  them. Remove in fresh-server mode. **Done in Round 30 Lane C:** unknown
  fields stop the load (`E-unknown-key`), `--legacy` is gone.
- **Possible bugs** (perf review side observations, not reproduced):
  Dawnmere once held 53 NPC objects after 13 logged placements (duplication?);
  mobs_redo `general_attack` raises the mob's eye height per candidate
  (`sp = s` aliases the position, then `sp.y = sp.y + 1` in the loop).
  **Both fixed in Round 30:** the duplication was real (Lane C: start NPCs
  whose block was saved and unloaded before their next deactivation came
  back twice; `start_npcs.lua` passes `_grug_unplaced` in the staticdata),
  the eye is a copy at the position + 1 (Lane P2).
- **Dragon-island landings** (final engine check 2026-10-02): the boat
  landings are mostly a one-node shore strip at y 1 with cliffs 40–130
  nodes high about 5 nodes inland (seed 42 both landings, seed 20261002 the
  south landing; the other was a real beach). The islands are boat-only, so
  stepping ashore may be hard or impossible. Mapgen: guarantee a walkable
  beach or ramp at each landing; check in the user's GUI playtest first.
  **Done in Round 30 Lane L:** a sand beach and a wooden pier at all four
  landings (`boats.md` §7.1); no path up the island, by design (the islands
  stay untamed, user 2026-10-02).
- **Pallcloth Den** (Blackwind Rise): its trail now joins the middle road,
  so it runs along the front; check in the playtest.
- **Thin front areas:** Gravesalt `tomb_fen` forms only 1–2 regions on some
  seeds (2.6 % of the land on seed 1234) and Shattered Line `siegecrest`
  3.8 % on seed 314159; their quest targets form on all six checked seeds.
  Blackwind Rise's bandit hideout uses the camp slope fallback on seeds 42,
  2 and 99 (0.42–0.47; accepted). Mournfen's camp belt warns on seed 99999
  in the region renderer.
- **Stale fixtures:** `tools/r24_density_xp/fixture.lua` and
  `tools/r25_spawn_guard/fixture.lua` fail on main: `r24_density_xp/
  roster.lua` reads the removed `grug_mobs/wp40/r7_settlement.lua`.
  **Done in Round 30 Lane C:** `r25_spawn_guard` repaired, the
  `r24_density_xp` fixture deleted (its palette budget applies to no zone),
  `r27_quest_item_names` repaired too.
- Smaller notes: the POI "West Trench Mouth" trips the compass-word rule
  (quests must not name it); T1 trinkets keep Cut Quartz (accepted); the
  bronze tool stock against the gear axis and base-mob fallback drops (E1
  review notes).

### Round 30 — performance

**Delivered locally 2026-10-02**
([completion](docs/planning/round30-plan.md#completion-2026-10-02)): every
item below shipped (#22, an investigation, as a proposal); the before/after numbers and the rulings made during
the round are in the completion section, open notes in
[Round 30 carry-overs](#round-30-carry-overs). The record as planned, from
the read-only
[performance review](docs/research/perf-review-2026-10.md) (§5 lane
split; numbers are comparisons, never targets). Rulings of 2026-10-02:

- **#4 yes:** mobs give up a static target they cannot reach instead of
  repeating a full no-path A* forever.
- **Region-map file cache yes** (#2, design in §3 of the report): boot
  9.5 s of region-map builds → about 2 ms of loading.
- **#3 Map tab:** the arrow and the rebuild at most every 2 s, a rebuild
  only when the marker signature changes, one shared marker style.
- **#11 spawn ABMs:** retire the surface spawn ABMs where the region
  spawner is authoritative; merge the rest (underground, ocean, rift) into a
  few ABMs.
- The other findings as the report recommends.

Lanes:

- **P1 Quest state and map UI:** #1 (quest state deserialized per giver),
  #5 (tracker HUD in one step), #3 (Map tab), #12 (minimap glide), the NPC
  tag callback part of #10.
- **P2 Mob pathing and allocation:** #4, #13 (stuck patrol A*), #6
  (`get_properties()` per step), #17 (privilege checks), #18 (`mobs_can_hear
  = false`), and #11 (spawn ABMs).
- **P3 Region-map cache and boot memory:** #2, #9, #20, #21; investigate
  #22 (grug_mapgen load on a cache hit).
- **P4 Per-player ticks and misc:** #7 (crafting recipe scan), #8
  (crosshair rays), #10 (tag-carrier slotting), #14, #15, #16, #19.

Order: P1 and P3 in parallel, then P2 and P4; each lane re-runs its probe
as a before/after comparison. All four delivered, with a P1 follow-up
(Return home on the Character page, user ruling) and P1b (markers follow
held objective items and level changes).

Also in Round 30 beside the performance lanes (user, 2026-10-02):

- **Island landings (mapgen):** each dragon-island boat landing gets a simple
  wooden pier and a little beach, so a player can step ashore from a boat
  ([Round 29 carry-overs](#round-29-carry-overs)). This narrows the travel
  plan's "no docks" scope for these landings only. **Done (Lane L).**
- **Clean-up after the quest rebuild:** drop the legacy quest fields the loader,
  validator and `validate.py --legacy` still accept; repair the stale fixtures
  `tools/r24_density_xp` and `tools/r25_spawn_guard`; add the riding-tier
  purchase fixture; look at the 18 "No craft recipe known for output" boot
  warnings (leathers, bolts, woods; `clear_craft` calls). **Done (Lane C),**
  all four; the 18 calls were no-ops and are removed.
- **Possible bugs** from the performance review: the Dawnmere NPC duplication
  (seen once) and the mobs_redo `general_attack` eye height (with P2).
  **Both fixed (Lanes C and P2).**
- **Band-5 loot median smoothing** (Expert riding steep; prices recomputed with
  `tools/r29_e4/income.py` afterwards). **Done (Lane E).**

Planned next (user, 2026-10-02): Round 31 PvP (WP41 with enemy-guard quest
objectives and small PvP POIs from WP42, planned in its own design session),
Round 32 the WP9 main storyline 41–60 and the finale.

**Dragon arena design iteration** (user, 2026-10-02; next round, a small
design step first): the ice dragon (Wyrmglass) stands on a square, rather
plain terrace (the jungle dragon's arena is to be checked). The arena core
(32 nodes, `simple_map.lua` POI kind `dragon`, `arena_terrace`) is already
protected as a POI core (`grug_core.world_feature_at`; the dragon's own
breath patches are exempt), so terrain can shape the fight: lava pits,
spiked pillars, cover, height and similar hazards, per dragon. The islands
themselves stay untamed: no mapgen paths or roads by design (user
2026-10-02, `boats.md` §7.1).

### Round 30 carry-overs

**Noted 2026-10-02** ([completion](docs/planning/round30-plan.md#completion-2026-10-02));
none blocks the fresh-world playtest. Numbers are comparisons, never targets.

- **grug_mapgen warm load (perf review #22, proposal; the user decides):** on
  a cache hit grug_mapgen still spends about 6.35 s loading (settlement
  preparation 4.09 s, the capitals about 3.5 s). Storing
  `prepared_handover()` as a fifth section of the world-layout cache (D71)
  would cut that part 4.6 → about 1.2 s; size M, risk medium (the manifest
  SHA must stay covered).
- **Region-map cache (P3 review notes):** a cold build still peaks at about
  150 MiB of Lua heap, because the zone-query caches are kept for the session;
  the zone-grid encode assert (more than 255 zones) sits outside the pcall
  that turns a cache failure into a rebuild, while the rehydrate asserts sit
  inside the build pcall; the mapgen data files and the engine version are
  not part of the cache keys (the same holds for the D71 world-layout cache).
- **Quest markers (P1b review notes):** held objective counts are not capped
  at what the objective needs, so over-gathering re-computes the markers on
  each 0.5 s tracker poll (refine to `min(count, needed)`); a turn-in whose
  reward fails skips `changed()` (pre-existing).
- **Economy:** band 6 pays 0.80 of its target axis (239.3c against about
  300c), so Master Riding stays 7g33s against about 8g76s on the axis; the
  band-3 outliers (Crocodile Tooth, Shiny Scale; T4 items in bands 2–3) stay
  because no T3 replacement exists
  ([economy plan](docs/planning/economy-vendor-plan.md#band-smoothing-round-30-2026-10-02)).
- **Map tab:** an empty strip remains where the Return home button was.
- **Mob give-up (P2 notes, for the GUI test):** a player who keeps
  re-aggroing a mob from a pillar or a closed house gets it fully healed at
  each give-up (about every 7 s); P2's one-seed count run showed +55 % spawn
  attempts in a shallow cave, judged run noise (the merged dispatcher keeps
  every row's rate by construction).

### Round 26 capital wall follow-ups

**Noted 2026-09-30** after the playtest fix `1ff541e4` (wall–gatehouse gaps
10336 → 0 and leaking gates 2287 → 0 over 200 seeds; river dips 271 → 86 by
`tools/r26_capitals/gate_gaps.lua`, whose merged dip metric undercounts a
crossing plus a bend clip). Lethariel leaves more of its crown lake shore
unwalled; the user accepted this.

- River V-dips still occur where a whole run of rays sits on the far bank:
  the bank-run pass moves rays one at a time and never the whole run back to
  its neighbours' bank (for example seed 9469376632389957802, Lethariel and
  Kezamba). Same as before the fix, not a regression against main.
- Streets on the wall line: after the Round 27 playtest fix (lanes, squares,
  junctions and the plaza keep off the wall band; every gatehouse's outermost
  column is a tower) capital plans with a wall opening away from a gate fell
  from 58 to 6 of 1200 over 200 seeds. The remaining 6 (Lethariel seeds
  10977656699485584087, 10086036900283954633, 17175927337665330950,
  13094141985803758170; Kezamba 14402018182688909832; Gor Drazhak
  17608184500408850831) are outline geometry: where the gate-line pass stops
  at water, the wall leaves a gatehouse through its inner face and the avenue
  covers the wall line beside the box. Options: let the wall win over avenue
  columns beside a gatehouse (cheap, may narrow the approach), or make the
  wall leave the box sideways (cleaner, touches the river-dip tuning and needs
  a new dip run). Deferred by the user 2026-09-30.

### First-public-release gates

**Open; owner: the project coordinator preparing the first public release.**
Trigger: freeze the intended release candidate, before asking the user to approve
that release. These obligations remain visible after WP40 development completion
by explicit user decision on 2026-09-13; they are not passed or waived gates.
Rewritten 2026-09-29 after the WP audit (E9, E10).

Gates:

- Freeze game/engine/settings identity and choose the intended public seed.
  Since Round 22 D24 the coast and borders vary per seed, so the seed is a
  free choice.
- Complete the Z-Image media gate for `menu/icon.png`: set ContentDB's
  **AI-generated media flag** (content policy §4.3), credit Z-Image, retain Jan
  Hangebrauck as prompt/mask author and rights holder, keep the source render
  and derivative under CC0 1.0, and retain the source/prompt/export record in
  `menu/LICENSE-media.md` (added 2026-09-16).

Release checks with judgement, not gates (E10: sometimes thorough, never a
rigid rule that forces hour-long tests):

- Start, generate and restart the candidate on the native engine, as deep as
  the changes since the last playtest warrant; there is no mandatory native
  smoke with runtime/RSS evidence.
- The PUC Lua 5.1 (fallback-engine) run is **optional** (E9): at most one
  crash smoke test once the mapgen is finished (Round 22 D1).
- One spot check of resource supply and regional access on a few seeds (rough
  ~5 % parity target, `world_zones.md` §11; Round 22 D21).

Evidence boundary: [R8](docs/research/wp40-simple-map-r8-contract.md) and
[WP40 completion](docs/research/wp40-completion.md) are historical owner texts,
superseded for these checks by Round 22 D1/D5 and the decisions above. This is
a development-WP completion, not a public release. Only the user's explicit
announcement ends fresh-server mode. Plain Lua 5.1 compatibility of the code
stays a hard rule throughout development; only PUC runtime testing is
optional.

## Historical receipts and unresolved carry-overs

The [pre-consolidation backlog](docs/archive/planning/backlog-before-consolidation.md)
retains original completion records, review calibration, runtime observations,
old acceptance descriptions and carry-overs. Its obsolete migration, radial-map,
soft-lock, ballistic and refinement instructions do not govern new work.

Do not silently discard a historical carry-over merely because its parent WP is
marked delivered. Reconcile it against current design and the domain findings;
if still open, retain an owner here. The current documentation round records its
coverage and remaining uncertainties rather than declaring every old claim verified.

For execution use [WP workflow](docs/process/wp-workflow.md), current topic rules
and a refreshed bounded task brief. Historical research briefs are starting
material, not permission to restore superseded requirements.
