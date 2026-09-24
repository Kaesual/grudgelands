# Backlog — Work Packages

Current implementation work and remaining scope. [Design](docs/design/README.md)
owns game rules; [ROADMAP](ROADMAP.md) owns goals; [project status](docs/STATUS.md)
owns the latest local/remote delivery and GUI acceptance. Completed implementation
narratives are [historical receipts](docs/archive/planning/backlog-before-consolidation.md),
not additional current contracts. No behavior changes are authorized by this cleanup.

## Readiness

There are **53 identities**: WP0–WP49 and WP-Scout/WP-HUD/WP-Speed.
**27 delivered**, **1 canceled** (WP16), **25 open or partial**. This corrects the
old summary's omission of the already-delivered WP8, WP12 and WP20; it does not
claim any additional implementation or GUI acceptance.

- Current work: [Round 20](docs/planning/round20-state.md), integration and final gates.
- WP5's selected fixed-tier enchanting is delivered; loot, cultural/PvP finishes
  and masterwork remain. WP44's economy/measurement remains open.
- WP11's talent consumers are delivered; measured respec prices await WP44.
- Round 20 supplies authored art for the remaining 70 WP13 slots (100 total
  anchors), subject to its final gates and GUI acceptance. The recorded
  `bandit_frontier` core-width discrepancy (24 decided, 16 implemented) remains;
  new art fits the existing core and does not silently expand it.
- WP14 ordinary offhands are delivered; moving held-torch light was deferred
  after the R18 complexity preflight. WP21's broader rest/recovery scope remains.
- Friendly-guard healing remains deferred as a coherent support-combat feature;
  its rule owner is combat_stats.md. No implementation is scheduled here.
- WP37's old blanket density reduction conflicts with later scoped increases:
  **do not execute the old task card until reconciled**. See the documentation
  round findings. Current runtime tuning is not changed here.
- WP27–WP30 contain substantially delivered gear/recipes; check their remainders
  against the topic audit before treating historical dependency order as untouched.
- WP24/WP34/WP41/WP42/WP23 retain the dependency chain below. WP17 claim-bound
  travel and boats are separate from the delivered innkeeper home return.
- WP31 mount runtime and WP32 farming are delivered in bounded rounds; economy,
  Housing integration and recorded acceptance remain separate.

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
| WP5 | [Loot, found-item affixes and cultural/PvP finishes](docs/planning/work-package-scopes.md#wp5) | Selected enchanting delivered; broader loot/finish/masterwork open. | WP1 ✅, WP3 ✅, WP43 ✅ |
| WP6 | Mob roster, threat, guards and combat feel | Delivered; historical receipt below. Current rules: topic design. | — |
| WP7 | Ledger currency and traders (WP44 rebase outstanding) | Delivered legacy economy; current price curve and 25% buy-back await WP44. | — |
| WP8 | Quest framework | Framework delivered; Round 20 candidate: 240 quests with talk handoffs. Broader story remains WP9. | — |
| WP9 | [Named-zone story and questlines](docs/planning/work-package-scopes.md#wp9) | Round 20 adds capital/regional journeys; full high-level story and finale remain open. | WP6, WP8, WP40, WP41 |
| WP10 | [Profession content and priced integration](docs/planning/work-package-scopes.md#wp10) | Framework and seven catalogs delivered; wider/priced content remains. | WP26 ✅, WP33 ✅, WP43 ✅, WP44 |
| WP11 | [Talent trees: measured respec-price remainder](docs/planning/work-package-scopes.md#wp11) | Talents implemented; WP44 respec calibration open. | WP3 ✅, WP4 ✅, WP-Speed ✅ |
| WP-Scout | Scout class and talent trees | Delivered; historical receipt below. Current rules: topic design. | — |
| WP-HUD | Exact health/resource HUD | Delivered; historical receipt below. Current rules: topic design. | — |
| WP-Speed | Shared movement modifiers | Delivered; historical receipt below. Current rules: topic design. | — |
| WP12 | World atlas | Delivered through R19: whole-atlas zoom/scroll and live markers; waypoints remain WP17. | — |
| WP13 | [Remaining authored structures and POI roster](docs/planning/work-package-scopes.md#wp13) | Round 20 completes authored roster art; geometry discrepancy and GUI acceptance remain. | WP40 ✅, WP43 ✅ |
| WP14 | [Offhands delivered; carried-light remainder](docs/planning/work-package-scopes.md#wp14) | Ordinary offhands delivered; moving light deferred. | WP3 |
| WP15 | Character equipment and bags | Delivered; historical receipt below. Current rules: topic design. | — |
| WP16 | Canceled historical proposal | Canceled 2026-08-12; no game code shipped. | — |
| WP17 | [Boats, waypoint travel and claim-bound Home Stone](docs/planning/work-package-scopes.md#wp17) | Future boats/waypoints/claim travel; innkeeper return already delivered. | WP24, WP40 |
| WP18 | First continent map (superseded by WP40) | Delivered; historical receipt below. Current rules: topic design. | — |
| WP19 | Original kit and race-passive tuning | Delivered; historical receipt below. Current rules: topic design. | — |
| WP20 | Same-faction parties | Delivered R14–19: persistent parties, management and optional HUD. | — |
| WP21 | [Recovery/rest and Housing integration](docs/planning/work-package-scopes.md#wp21) | Food/recovery basics delivered; broader rest/Housing open. | WP1 |
| WP22 | [Tool-speed calibration, wear/repair remainder](docs/planning/work-package-scopes.md#wp22) | Tier wear and money repair delivered; speed/Housing remainder. | WP5, WP7, WP43, WP44 |
| WP23 | [Full dragon encounters](docs/planning/work-package-scopes.md#wp23) | Bosses present; full encounter dependencies remain. | WP13, WP17, WP34, WP40, WP41, WP43 |
| WP24 | [Open-world Claim Stone Housing](docs/planning/work-package-scopes.md#wp24) | Approved design; implementation and economy integration open. | WP40, WP43, WP44 |
| WP25 | Original strata/materials (superseded by WP43) | Delivered; historical receipt below. Current rules: topic design. | — |
| WP26 | Furnace and alloy chain | Delivered; historical receipt below. Current rules: topic design. | — |
| WP27 | [Armor catalog remainder](docs/planning/work-package-scopes.md#wp27) | Base armor/visuals delivered; broader contract reconciliation remains. | WP26, WP43 |
| WP28 | [Remove superseded recipe/tool registrations](docs/planning/work-package-scopes.md#wp28) | Review current registrations before further removals. | WP29, WP40 R7 |
| WP29 | [Canonical gear/tool catalog remainder](docs/planning/work-package-scopes.md#wp29) | Current catalog/recipes delivered; broader contract remainder. | WP26, WP27, WP43 |
| WP30 | [Trader catalog and final prices](docs/planning/work-package-scopes.md#wp30) | Await final catalog/economy integration. | WP5, WP29, WP44 |
| WP31 | [Mount acceptance and price calibration](docs/planning/work-package-scopes.md#wp31) | Runtime/services/art delivered; GUI and economy remainder. | WP28, WP40, WP44 |
| WP32 | [Farming Housing integration and acceptance](docs/planning/work-package-scopes.md#wp32) | 17-family farming and world sources delivered; Housing remainder. | WP10, WP24, WP33 |
| WP33 | Gathering/source catalog | Delivered; historical receipt below. Current rules: topic design. | — |
| WP34 | [Deep pressure and renewable camp resources](docs/planning/work-package-scopes.md#wp34) | Open; structures/economy and depth decisions required. | WP6, WP13, WP40, WP43, WP44 |
| WP35 | Equipped weapon source and appearance | Delivered; historical receipt below. Current rules: topic design. | — |
| WP36 | Reference submodules and first runtime fixes | Delivered; historical receipt below. Current rules: topic design. | — |
| WP37 | [Surface-density plan reconciliation](docs/planning/work-package-scopes.md#wp37) | Paused for explicit reconciliation with R16 fightable-only +30%; no density change authorized by documentation cleanup. | WP6 ✅ |
| WP38 | Held melee timing and settlement | Delivered; historical receipt below. Current rules: topic design. | — |
| WP39 | Crosshair-authoritative combat | Delivered; historical receipt below. Current rules: topic design. | — |
| WP40 | Named-zone world foundation | Development delivery accepted; first-public-release gates remain open. | — |
| WP41 | [Geographic PvP transaction](docs/planning/work-package-scopes.md#wp41) | Open; WP5 finish/PvP consumers remain prerequisites. | WP5, WP39, WP40 |
| WP42 | [Bounded war-front encounters](docs/planning/work-package-scopes.md#wp42) | Open; structures and PvP prerequisites. | WP13, WP40, WP41 |
| WP43 | Canonical material/depth registry | Delivered; historical receipt below. Current rules: topic design. | — |
| WP44 | [Economy rebase and measured income](docs/planning/work-package-scopes.md#wp44) | Open; target prices/Income Ledger not runtime. | WP7 ✅, WP43 |
| WP45 | Character-creation stasis and safe arrival | Delivered; historical receipt below. Current rules: topic design. | — |
| WP46 | Indirect terrain-damage guard | Partial: actor-neutral guard and protected water flow delivered; fire/explosion/lava/admin remainder below. | WP40, WP13, WP24 integration |
| WP47 | Skills catalog and recoverable representations | Delivered R12–13; current rules in inventory_equipment.md. | — |
| WP48 | Mapgen writer performance and parallel emerge | Partial R9-PERF delivery; broader optimization and engine threading constraint remain below. | WP40 |
| WP49 | Fixed mapgen source-audit roster | Open; decided, not scheduled. Scope below. | WP40 |

### WP46 — Terrain-damage guard: explosions, fire and lava never damage settlements or POIs

**Open remainder (user requirement 2026-09-19).** Round 11 delivers the neutral
`world_alterable` authority and protected ordinary/river-water flow prerequisite
for buckets. General explosion, fire and lava consumers remain separate work.

Requirement: explosions (mobs and players) must not damage cities, starts and
POIs, and fire must never spread into them — a burning or destroyed authored
block could only be repaired by an admin. Today nothing in the game destroys
terrain: there is no `fire` and no `tnt` mod, lava is natural only (no
bucket), the Rift Spawn explodes with terrain radius 0, and the dragon
rime/scorch effects write only into air and restore it by timer. The risk is
future content (Nether V2 fire, later explosive mobs, TNT, lava buckets).

Plan (decided direction, details in the lane brief):

1. **One guard predicate in `grug_core`**, actor-neutral:
   `grug_core.world_alterable(pos)` = not inside any settlement claim (the
   six capitals with precinct and outer ring, the six starts, every POI and
   landmark footprint, housing claims) — the same authority
   `world_protected_for_faction` already uses in `protection.lua`, without a
   player name. Every effect that changes nodes on its own (not through a
   player's dig/place, which `core.is_protected` already covers) calls it per
   node: mob explosions, fire spread, lava flow into non-natural nodes,
   boss ground effects.
2. **mobs_redo `explode` GRUG PATCH:** terrain damage stays radius 0 for every
   mob in V1 (a KAT rejects any mob def with `explosion_radius > 0`); if a
   later design wants craters, the patched `mobs:boom` skips every node the
   guard refuses.
3. **Fire policy:** V1 ships no fire mod. When fire arrives (Nether), spread
   is an ABM that (a) asks the guard per target node, (b) has a burn budget
   per flame (finite lifetime), and (c) never ignites nodes of the settlement
   palettes; "eternal flame" nodes exist only as authored decoration without
   spread.
4. **Lava:** mapgen keeps natural lava outside settlement and POI exclusions
   (verify with the WP40 exclusion predicates); a lava bucket, if ever added,
   is placement and therefore already covered by `core.is_protected`.
5. **Static gate:** `tools/static.sh`-style sweep failing on any new
   `explosion_radius`, `fire:`, `tnt` or `lava_source` placement in
   `mods/*/grug_*` that does not reference the guard.
6. **Repair safety net:** an admin command that re-projects an authored
   settlement blueprint at its anchor (the WP40/WP13 projection is
   deterministic), so any damage that slips through is reversible without
   hand repair.

Acceptance: KAT proving the guard over all twelve settlements and a POI
sample (inside → refused, one node outside → allowed), the explosion KAT,
the static sweep, and a headless probe detonating a Rift Spawn at a capital
wall with zero node changes.

### WP48 — Mapgen writer performance and parallel emerge

**Open (from the Round 9 MAP-C plateau attempt, 2026-09-19).** The WP40
writer spends its time in Lua post-processing per MODIFIED voxel (dirty-
intent scan, light-context scan, replay), with apparent fixed costs per
touched chunk slice: a v7 plateau that turns the whole sky below 441 into
stone-to-air writes raised emerge time by 30–70 % regardless of height,
and a bulk-clear fast path for the per-voxel resolution did not help
(evidence in `tools/r9_map_c/evidence/`). Two levers, measured with the
profiler's phase records before any change:

1. Make the post-processing loops proportional to changed runs instead of
   whole slices (benefits main today: the writer is ~21 of 68 s over the
   profiler corpus).
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

Only with that data is the v7 plateau (caves everywhere under the
surface) worth revisiting; Round 9 shipped MAP-C without it (ruling 35).

### WP49 — R7 source-audit refreeze on a fixed mapgen roster

**Status (2026-09-19):** decided, not scheduled (Round 9 ruling 43,
option A). `tools/wp40/r7/source_audit.sh` derives its "changed production
Lua" roster as every `mods/` Lua file added or modified since `d6002a2`
plus untracked files, and asserts the count frozen on 2026-09-15 (157,
`changed_production_lua.txt`). Today's main derives 293, so the prefreeze
audit exits 1 on main; nothing runs it (static.sh only runs `run.sh unit`,
`final_micro.sh` does not call it). The R7 micro fixture executes exactly
the roster and has hand-built environments only for those 157 modules, so
the roster cannot be refreshed from the derivation without extending the
fixture to ~136 unrelated modules (mobs, WP13 capitals, jobs, professions)
that have their own KATs.

**Plan:** replace the derivation with a fixed mapgen roster: the WP40
modules (`mods/MAPGEN/grug_mapgen/wp40/`, `wp13/` capital cores used by
R7) and their direct dependencies, listed explicitly in
`changed_production_lua.txt`, with the audit asserting that every listed
file exists and every WP40 module is listed (no baseline diff). Update the
README procedure, the count assertions (`source_audit.sh`, `final_micro.sh`,
`micro_kat_cli.lua`, fixture defaults) and re-run `run.sh static` to
refreeze. One small lane, after Round 9 (DOCS or MAP-B follow-up); the
final micro stays the sole PUC gate meanwhile.

### First-public-release gates

**Open; owner: the project coordinator preparing the first public release.**
Trigger: freeze the intended release candidate, before asking the user to approve
that release. These obligations remain visible after WP40 development completion
by explicit user decision on 2026-09-13; they are not passed or waived gates.

- Freeze game/engine/settings identity and choose the intended public seed.
- Rebase resource supply and regional access checks onto the current sampler
  and candidate. Historical 32-seed per-host-hash artifacts are not a current
  supply/access certificate.
- Execute the reviewed current-candidate feature/native and generation-order
  smoke with runtime/RSS evidence. Historical seed-0 G3 predates later changes;
  it also did not prove native dungeon preservation. Record event absence and
  other coverage limits explicitly.
- Confirm native and actual fallback-engine startup/generation/restart on that
  candidate, reusing evidence only where unchanged inputs justify it. The
  accepted 2026-09-13 browser test has no visible build ID; do not invent one.
- Complete the Z-Image media gate for `menu/icon.png`: set ContentDB's
  **AI-generated media flag** (content policy §4.3), credit Z-Image, retain Jan
  Hangebrauck as prompt/mask author and rights holder, keep the source render
  and derivative under CC0 1.0, and retain the source/prompt/export record in
  `menu/LICENSE-media.md` (added 2026-09-16).

Contract and evidence boundary: [R8](docs/research/wp40-simple-map-r8-contract.md)
and [WP40 completion](docs/research/wp40-completion.md). This is a development-WP
completion, not a public release. Only the user's explicit announcement ends
fresh-server mode; Lua 5.1 remains supported throughout development.

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
