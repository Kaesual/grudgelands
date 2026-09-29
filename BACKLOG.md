# Backlog — Work Packages

Current implementation work and remaining scope. [Design](docs/design/README.md)
owns game rules; [ROADMAP](ROADMAP.md) owns goals; [project status](docs/STATUS.md)
owns the latest local/remote delivery and GUI acceptance. Completed implementation
narratives are [historical receipts](docs/archive/planning/backlog-before-consolidation.md),
not additional current contracts. No behavior changes are authorized by this cleanup.

## Readiness

There are **54 identities**: WP0–WP50 and WP-Scout/WP-HUD/WP-Speed.
**39 delivered**, **3 canceled** (WP16, WP37, WP49), **12 open or partial**.
The 2026-09-29
[WP audit](docs/planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29)
closed WP14, WP21, WP22, WP23, WP27, WP29, WP31 and WP32 as delivered, merged WP7's rebase, WP11, WP30 and the price parts of WP22 and
WP31 into WP44 (WP11 and WP30 count as delivered), and canceled WP37 and WP49.
WP28 followed in Round 26. The audit's letters and numbers (for example E5)
are cited below.

- **Latest delivery:
  [Round 26](docs/planning/round26-capitals-housing-cleanup-plan.md#completion-2026-09-29)
  complete** (2026-09-29, local main, no push): Claim Stone draft and
  activation with the Housing Steward (Lane S), the registration cleanup
  (WP28 delivered, Lane R), the status-icon package (audit D10, Lane I),
  organic capitals with a character per capital (the D72 follow-up, Lane W)
  and this documentation cleanup (Lane D). Next: fresh world and playtest.
  Not in this round: the depth pulse (WP34), WP44, WP17, WP41, WP9, WP5 and
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
  lakes of `world.md` §4c stay planned (E3) with no scheduled owner; repair at
  crafting stations inside a claim at the trader price (D7, Round 25
  carry-overs below).

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
| WP5 | [Loot, found-item affixes and cultural/PvP finishes](docs/planning/work-package-scopes.md#wp5) | Found-item loot and selected enchanting delivered; cultural/PvP finishes, masterwork (item-level-70 upgrade, D3) and the loot/demand audit open. Named rares drop no trophies (D4). | WP1 ✅, WP3 ✅, WP43 ✅ |
| WP6 | Mob roster, threat, guards and combat feel | Delivered; historical receipt below. Current rules: topic design. | — |
| WP7 | Ledger currency and traders | Delivered (legacy price curve, 25% buy-back); WP44 replaces both. | — |
| WP8 | Quest framework | Framework delivered; Round 20: 240 quests with talk handoffs. Broader story remains WP9. | — |
| WP9 | [Named-zone story and questlines](docs/planning/work-package-scopes.md#wp9) | Round 20: 240 quests up to level 40. **V1:** story levels 41–60 and the finale remain open. | WP6 ✅, WP8 ✅, WP40 ✅; WP41 for PvP-tag quests |
| WP10 | [Profession content and priced integration](docs/planning/work-package-scopes.md#wp10) | Framework and seven catalogs delivered; cultural finishing and helper NPC services remain (cultural masters later, D11). | WP5, WP26 ✅, WP33 ✅, WP43 ✅, WP44 |
| WP11 | [Talent trees](docs/planning/work-package-scopes.md#wp11) | Delivered; closed 2026-09-29, respec price merged into WP44 (C2). | WP3 ✅, WP4 ✅, WP-Speed ✅ |
| WP-Scout | Scout class and talent trees | Delivered; historical receipt below. Current rules: topic design. | — |
| WP-HUD | Exact health/resource HUD | Delivered; historical receipt below. Current rules: topic design. | — |
| WP-Speed | Shared movement modifiers | Delivered; historical receipt below. Current rules: topic design. | — |
| WP12 | World atlas | Delivered through R19: whole-atlas zoom/scroll and live markers; waypoints remain WP17. | — |
| WP13 | [Remaining authored structures and POI roster](docs/planning/work-package-scopes.md#wp13) | Round 20 completes roster art; Round 21 improves access/ground; Round 23 walls all six capitals. `bandit_frontier` core stays 16 (E1); Round 26 gives every capital its own outline and character (D72). Remaining: a separate POI walk (E2). | WP40 ✅, WP43 ✅ |
| WP14 | [Offhands](docs/planning/work-package-scopes.md#wp14) | Delivered; closed 2026-09-29. Carried light canceled (C5). | WP3 ✅ |
| WP15 | Character equipment and bags | Delivered; historical receipt below. Current rules: topic design. | — |
| WP16 | Canceled historical proposal | Canceled 2026-08-12; no game code shipped. | — |
| WP17 | [Boats and waypoint travel](docs/planning/work-package-scopes.md#wp17) | **V1.** Boats, waypoints at starts and capitals, Kraken retune; the boat route to the dragon islands comes from WP23. No `/unstuck` (B3). Innkeeper return and the Claim Stone travel home already delivered. | WP40 ✅, WP13 (shipwright) |
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
| WP31 | [Mounts](docs/planning/work-package-scopes.md#wp31) | Delivered (C3); prices merged into WP44. | WP40 ✅ |
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
| WP44 | [Economy rebase, lighter pass](docs/planning/work-package-scopes.md#wp44) | Open: price tables, 5% buy-back, audit fixes, quest copper rescale, respec and mount prices from a simple income estimate (D1, D2). | WP7 ✅, WP43 ✅ |
| WP45 | Character-creation stasis and safe arrival | Delivered; Round 24 makes creation pausable (ruling 32). Current rules: topic design. | — |
| WP46 | Indirect terrain-damage guard | Partial: actor-neutral guard and protected water flow delivered; the fire/explosion remainder is deferred until a fire or explosion source exists (expected with V2's Nether) (E6). | WP40 ✅, WP24 ✅ |
| WP47 | Skills catalog and recoverable representations | Delivered R12–13; current rules in inventory_equipment.md. | — |
| WP48 | Mapgen writer performance and parallel emerge | Partial; parked until a playtest shows slowness (E8). | WP40 ✅ |
| WP49 | Fixed mapgen source-audit roster | Canceled 2026-09-29: its audit script was deleted in Round 22 (D1/D3/D22). | — |
| WP50 | [Own minimap and map quality](docs/planning/work-package-scopes.md#wp50) | **Round 27** ([plan](docs/planning/round27-minimap-plan.md)): our own round minimap on the pre-generated map with NPC, quest-giver and party markers; native minimap off; `minetest.conf` map quality normal/high shared with the Map tab; readable relief. | WP40 ✅, WP24 ✅ |

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
  trader price, as a convenience (D7, `durability_repair.md`). Not scheduled;
  the price source switches with WP44.
- The per-run early-out in `world_protection` (Lane E) relies on dyadic road
  profiles (multiples of 1/16). Revisit if road profiles change.
- Remove `apex_sockets` from mapgen (E5): main still generates 24
  hard-protected socket columns (`wp40/source/simple_map.lua:357-372`, `:471`,
  `:489-495`; `r6_settlement.lua:1205-1231`) although the design has none.

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
