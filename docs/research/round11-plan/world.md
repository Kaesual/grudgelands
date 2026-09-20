> Consolidated planning annex. [README.md](README.md) governs any conflict.
> Values are proposed for approval with the complete plan; no runtime is implemented.

# Round 11 WORLD / FARM / CAP implementation brief proposal

Planning date: 2026-09-20. Baseline: current `main` after Round 10. This is a
proposal for consolidation and implementation briefing. It does not authorize
implementation and does not itself amend `docs/design/`.

## 1. Fixed user decisions and boundaries

The implementation package must preserve these accepted decisions:

- Reduce initial wild food/cooking plant density to approximately 50% while
  preserving every current zone, level/depth, biome, support and shore rule.
- Wild plants renew slowly and density-aware. Ores, gems, mineral resources,
  Rock Salt, Salt Crust and other nonplant resources remain governed by
  `world.md` R4 and do not renew outside its protected mining sockets.
- Add one empty Iron Bucket and one Water Bucket in Basics before Housing is
  available. V1 buckets handle ordinary and river water only; there is no lava
  bucket.
- The shared capital-core gatehouse removes exactly one additional obstructing
  block from the upper-floor stair opening. Do not redesign the stair and do
  not add a dedicated clearance test.
- Capital profession premises receive readable protected exterior frames and
  interior product stands for every profession. Displays are fixed scenery,
  never inventories or collectible item entities.
- Capital stables become open shelters: dirt floor, one-node fence perimeter,
  flat roof on six posts, with bounded mount-display movement. GAME owns entity
  movement/animation and persistence semantics; CAP owns the shelter and
  sockets.
- The beach's accepted overall course, width and profile mix remain unchanged.
  Only the narrow residual pillars/plates are in scope.

Non-goals: ore renewal, general ecosystem simulation, player-editable display
frames, a new general liquid API, lava handling, all of WP24 Housing, all of
WP46 terrain-damage protection, mount flight, or changes to regional plant
distribution.

## 2. Ownership and package order

Use three bounded implementation packages with non-overlapping primary files:

1. **WORLD-CAP geometry**: beach witness diagnosis/correction, the one-block
   gate edit, open stable blueprints/sockets, and profession-premise scenery.
   Primary ownership is `mods/MAPGEN/grug_mapgen/wp40/height.lua`, the smallest
   required WP40 fixtures, and `mods/MAPGEN/grug_mapgen/wp13/` capital modules.
2. **FARM ecology and bucket**: initial density, renewal runtime and water-only
   bucket. Primary ownership is `mods/MAPGEN/grug_mapgen/world_content*.lua`,
   `mods/MAPGEN/grug_mapgen/wp40/world_content.lua`,
   `mods/ITEMS/grug_farming/`, `mods/CORE/grug_core/` for the actor-neutral
   mutation predicate, and the smallest appropriate item/crafting mod.
3. **GAME stable displays**: consume CAP's stable movement sockets and give
   ground mounts bounded idle movement while flying appearances remain grounded
   and receive an available idle/head animation. GAME must not edit capital
   geometry. This package is only an interface dependency here; its detailed
   entity brief belongs to GAME.

Update the living design before code. After reviewed implementation, update
BACKLOG/ROADMAP/README only as required by the normal WP workflow. Fresh-world
mode applies; add no migration or cleanup path for earlier development worlds.

## 3. WORLD-CAP geometry contract

### 3.1 Gate opening

`wp13/capitals.lua` owns the shared `M.gatehouse` flight. Remove exactly the
one upper-floor block identified by the user, immediately beyond the present
stairwell opening in the ascent direction. All four rotated instances inherit
the change. Do not change tread count, rise, deck height, gate passage, room
dimensions or other gatehouse cells. Update existing blueprint identities and
ordinary aggregate KAT expectations caused by the byte change. Add no bespoke
headroom/clearance test.

### 3.2 Beach witness diagnosis and correction

The required witness is world seed `15140735923413111218`, around
`(-414, 20, -2724)` and `(-511, 20, -2562)`. Before choosing a fix, add a
bounded read-only diagnostic fixture for a small rectangle around each witness.
For each residual high column record incoming height, final height, coast
profile/distance/run, exact static-exclusion id, functional kind/id, and
coordinates modulo the 80-node owner width.

The leading, still unconfirmed hypothesis is `wp40/height.lua`'s broad coast
geometry veto through generic `static_exclusion_values_at`: claim/exclusion
envelopes can preserve complete native columns although no authored surface
occupies that column. If the witness confirms it, introduce a purpose-specific
coast-shaping exclusion query. It protects actual structure/build footprints,
route carriageways/decks and required shoulders, foundations, water seals,
bridges/causeways/fords, POI functional surfaces, capital/start cores and
coastal housing cores. A broad fitting/blend, claim or analytical exclusion
envelope alone does not veto coast shaping. Preserve existing protection and
claim geometry; this predicate controls terrain shaping only.

Stop and return to planning if the witness instead identifies a mapchunk seam,
stale generated blocks, or a later writer pass. Do not hide the symptom by
locally shaving columns. Acceptance is: no isolated one-node high columns or
one-node-thick high plates in both witness rectangles; adjacent beach height
steps remain walkable/coherent; accepted profile selection, sand widths,
functional structures and route/water seals remain intact.

### 3.3 Open stable and profession readability

Define one shared stable vocabulary that each capital palette can skin:

- natural dirt/packed-earth floor;
- one-node-high fence enclosure with a clear entrance;
- flat roof on exactly six structural posts;
- no solid perimeter wall;
- trainer/public approach and all station access remain unobstructed;
- publish bounded ground movement regions and rest/look sockets, all beneath
  the roof and inside the fence. CAP publishes geometry only.

Every profession premise gets a consistent readable pair: at least one exterior
fixed frame/sign showing a representative product and at least one interior
fixed stand or rack. Cover Weaponsmith and Armorsmith in their shared forge
without merging their identities, plus Alchemist, Tailor, Leatherworker,
Woodcarver, Goldsmith and Cooking. Reuse the existing decorative-display seam
used by capital services where possible. Displays must be authored protected
nodes/entities with fixed item identity, no inventory callbacks, no drops,
no punch/take path, no item entity and deterministic restoration on ordinary
current-version activation/reload.

## 4. FARM ecology contract

### 4.1 Initial population

Double every wild plant candidate denominator, leaving all other predicates
unchanged: `256 -> 512`, `512 -> 1024`, `768 -> 1536`, and `1024 -> 2048`.
Apply the same factor to the older independent Potato and Corn wild sources and
the existing gathering plant families, not only the fifteen Round-10 cooking
rows. First inventory all renewable plant-source node names and explicitly
exclude ore/mineral/salt/resource nodes. Preserve candidate rejection without
relocation during initial map generation.

### 4.2 Proposed renewal numbers (not yet accepted design)

Use deterministic **64 x 64 horizontal habitat cells**, keyed by species and
cell coordinates. A 16 x 16 cell cannot represent 1/512--1/2048 densities
without rounding most targets to zero. The target is the count of deterministic
initial candidates that would pass that species' current density hash inside
the cell before occupancy rejection, capped by actually legal habitat. This
preserves sparse statistical densities rather than rounding a nominal ratio.

Proposed timing: first replacement opportunity uniformly 4--8 real hours after
depletion; a failed attempt backs off uniformly 30--60 minutes. One successful
placement consumes one debt. These values make farming materially faster and
more reliable while still replenishing wilderness for later players.

Record depletion for every disappearance path that can be observed: player dig
through the node callback, replacement/destruction callbacks, and loaded-block
reconciliation. Do not rely only on `after_dig_node`. Coalesce state as
`species + cell -> debt count + next due time`; cap debt at the cell's target.
Persist only nonzero debt in mod storage. Nodes placed by players/crops never
create ecology debt.

A single throttled scheduler runs once per 10 seconds. Proposed global budget:
at most **8 due-cell services and 64 candidate checks per scheduler pass**, with
at most **2 successful placements per pass**. It considers only mapblocks
already loaded around connected players; it calls neither `emerge_area` nor
`load_area` and performs no world-wide scan. At 100 players these remain global,
not per-player, budgets. Deduplicate loaded cells before scheduling.

Do not scan all 64 x 64 columns when servicing a cell. Persist a compact
generated-baseline candidate set/count when that cell is first touched and an
observed natural-source set maintained by source lifecycle callbacks and loaded
mapblock reconciliation. Every inspected node is charged to the 64-candidate
global budget. A partially loaded cell is never treated as empty: service only
loaded mapblocks, defer candidates whose mapblock or required neighbor is
unloaded, and compute no deficit from unseen portions. The baseline
distinguishes a naturally sparse cell from depletion; renewal restores recorded
debt toward that baseline and never tops up a naturally sparse cell.

For a due cell below its recorded baseline, test a deterministic rotating list
of at most eight positions per service. Re-evaluate the current authoritative zone, band/depth, biome,
support, shore, air/clearance and cave predicates. Require the destination and
support to be natural and unmodified; refuse hard protection, authored/route/
water surfaces, housing reservations and active player claims. Never replace a
node, never place into `ignore`, and never preload a neighbor for a shore test.
If a required neighbor is unloaded, defer the attempt. Cave plants use the same
queue and their exposed-rock/air predicate.

Loaded-block reconciliation is bounded and lazy: when an eligible source's
mapblock becomes active, inspect only registered source nodes/cell bookkeeping
needed for that block; it may add missing debt for non-dig depletion but may not
infer debt merely because a cell naturally generated below its statistical
target. Persist a small generated baseline/observed identity per touched cell
so natural hash rejection is not mistaken for harvesting.

### 4.3 Ecology API boundary

Put shared habitat eligibility and source-family data beside the current world
content catalog so mapgen and runtime use one predicate vocabulary. Runtime must
call the authoritative zone API and a new actor-neutral
`grug_core.world_alterable(pos)` protection/claim seam rather than copy zone
polygons. It must not call `core.is_protected(pos, "")`, because the current
wrapper deliberately treats an empty/offline actor as protected. This narrow
predicate is also required by the water-flow guard below; it does not absorb
WP46 explosions, fire, lava or repair tooling. Expose only narrow registration
hooks to older Potato/Corn and
gathering sources: source node, species key, initial density, placement mode and
eligibility callback. No ABM per plant and no timer per missing node.

## 5. Water-only Iron Bucket contract

Register `empty_iron_bucket` and `water_bucket` as stack size 1 items. The Basics
recipe is exactly three `grug_materials:iron_bar` in the familiar V-shape. Do
not use the stale default steel-ingot identity. The recipe has no profession,
level or Housing gate.

V1 source-family rule: fill from an actual `default:water_source` or
`default:river_water_source`; refuse both flowing variants, decorative/civic
water and every lava node. There remains one visible Water Bucket item. Store
the captured source family in stack metadata (`ordinary` or `river`) and retain
it through inventory moves. Placement consumes the Water Bucket, places the
matching source family into a buildable empty target and returns the empty
bucket. Missing or invalid family metadata fails closed. Both actions use normal
pointed-node reach and check
`core.is_protected` at the node being removed/placed; inventory changes occur
only after the node mutation succeeds.

### 5.1 Required bounded water-flow guard

Bucket release depends on a bounded water slice of WP46 in this round. Implement
the shared actor-neutral `grug_core.world_alterable(pos)` predicate and guard
ordinary/river liquid transformation at protected authored and claimed nodes.
This slice handles water only; explosions, fire, lava, the static sweep and the
repair command remain in WP46.

The engine provides two relevant seams. A node's `on_flood(pos, oldnode,
newnode)` runs before a non-air flood and can veto it by returning true
(`lua_api.md:11009-11014`; `servermap.cpp:1172-1175`). Wrap existing floodable
node callbacks after registrations are complete: when `world_alterable` refuses
the target, return true before the original callback, preventing its drop or
destruction; otherwise preserve the original callback and return semantics.
For air and liquid-to-liquid transformations, use
`core.register_on_liquid_transformed(pos_list, old_node_list)`, which reports
the old node after the engine change (`lua_api.md:6774-6779`). Restore the exact
old node, including param2, at refused positions with a no-drop node write and
perform the smallest required liquid/light update.

Restoring protected boundary air can make the engine retry every liquid
interval, and the pinned API explicitly permits repeated on_flood calls.
Require bounded work per engine-transformed boundary node and bounded cache
storage per loaded mapblock; do not require zero callbacks or quiescence.
Reuse the engine's existing liquid scheduler, with no new polling/retry queue
and no per-attempt allocation growth. Release evidence must bound steady-state
cost and queue/storage size under the declared 100-player boundary scenario.
Never remove or mutate an allowed outside source. If the actual semantics or
performance fail, root replans the bounded water guard; an engine fork or custom
fluid simulation is not authorized by this plan. No drops/item entities.

## 6. Validation and evidence budget

No implementation or runtime execution occurs during planning. During
implementation:

- On every Lua change run `tools/bin/luac51 -p`, inspect SETGLOBAL for changed
  mod files, and run all five required Lua 5.1/source sweeps.
- Use LuaJIT for development fixtures, the two bounded coast witness scans,
  deterministic density/ecology simulations, capital blueprint checks and any
  seed/population work. Never schedule an intermediate PUC runtime suite.
- Ecology checks must cover: all plant families including Potato/Corn; exact
  halved initial hashes; no ore/mineral/salt registration; unloaded cells cause
  no load; global budgets remain fixed with 100 synthetic players; coalesced
  persistence/reload; dig and non-dig depletion; claim/protection refusal; and
  no placement over player-modified support.
- Water-flow checks cover both source families flowing toward protected air and
  floodable nodes, preservation of exact old node/param2, no drops, original
  `on_flood` behavior outside protection, and bounded per-event work and
  loaded-boundary storage without a growing queue. Repeated callbacks allowed
  by the engine are not themselves a failure.
- CAPITAL checks use existing blueprint/socket/identity suites. The user's gate
  ruling forbids a new dedicated stair-clearance test. Stable checks assert six
  posts, fence height one, open walls, dirt floor, roof coverage and movement
  sockets inside the enclosure.
- Bucket checks cover ordinary and river source fill/place with family metadata,
  both flowing variants and lava refusal, invalid/missing family refusal,
  protection refusal, full-inventory behavior and exact empty/filled exchange.
- Keep at most seven interpreter processes active across all agents. Independent
  LuaJIT jobs use separate immutable inputs/output paths and idle scheduling.
- On frozen final bytes run exactly one compact PUC 5.1 micro-KAT process that
  loads every changed production module and the same fixture once under LuaJIT;
  require byte-identical canonical output. Any later relevant Lua-byte change
  replaces this pair. Reviewers inspect the immutable evidence and do not rerun
  the PUC process.

GUI acceptance remains a fresh-world user test: both beach witnesses, all profession premises, stable movement,
natural plant scarcity/renewal observation, and bucket-created irrigated soil.

## 7. Stop conditions

Return to the coordinator without inventing behavior if: the beach witness
does not implicate the broad exclusion veto; a source family cannot report
non-dig depletion without a global scan; claim authority lacks a read-only
system predicate; decorative displays expose mutable inventory/drop behavior;
the six-post stable cannot contain the existing mount collision boxes; or the
water transform callbacks cannot preserve protected state without drops/loss
and bounded per-event work and loaded-boundary storage.
