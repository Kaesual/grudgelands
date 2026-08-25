# WP40 Simple Map Rebase Plan

**Status:** D1-D7 and R0 authority fold independently accepted 2026-08-25;
R1 is next

**Ruling date:** 2026-08-25

**Decision record:** this plan and the folded
`docs/design/world_zones.md`/`docs/research/wp40-engineering-brief.md`

## 1. Purpose

Rebase WP40 from an exact seed-dependent polygon/topology compiler onto a
small fixed horizontal world model. Preserve the recognizable authored world,
stable identities, progression, routes, policy, vertical mapgen correctness
and downstream gameplay scope. Remove exact geometric guarantees that have no
runtime consumer and no material player-visible value.

The user accepted seven simplification decisions:

1. fixed macro layout across world seeds;
2. route graph as gameplay adjacency;
3. paths validate against land and never repair it;
4. guaranteed capital ownership only for the 512 by 512 build envelope;
5. no stable exact boundary identity/API requirement; and
6. one authored gameplay difficulty target per zone instead of gate-control
   interpolation; and
7. one nominal shared `expanded_land_at(80)` shelf classifier instead of exact
   Euclidean distance to the final CSG coastline.

The target still blends through one mandatory global border transition. D6
retires the old capital 20/25/30 gameplay-progression profile together with the
exact core/gate controls; capital guard floors remain a separate policy rule.
D7 retires the old node-exact Euclidean shelf boundary while retaining the
nominal 80-node visual/policy band and all immutability semantics.

The rough "one day" target is not a deadline. It describes the intended order
of complexity. The implementation may take hours or several days if that buys
clear data, visual quality and robust bounded validation. It must not grow back
into a topology research program.

## 2. Immediate coordination ruling

With the reviewed R0 contract rebase accepted:

- current accepted T0/T1/T2 artifacts remain unchanged factual evidence, while
  the present design/process files remain formal authority;
- no existing artifact, evidence directory or accepted review record is
  rewritten to imply that it tested the new model;
- no new exact-topology package should be opened; and
- existing T2 branches, worktrees and artifacts are inactive historical or
  salvage sources. The old T2 agent will not be resumed. This rebase context is
  the authoritative continuation of WP40; R0/R1 explicitly decide whether any
  old piece is reusable, and nothing merges automatically.

After the plan review, the rebase continues in this authoritative context on
the existing `wp40-named-zone-world-foundation` branch. It is already WP40's
dedicated branch; creating another branch or worktree would add no isolation.
Existing inactive or unrelated worktrees and untracked files are not touched.
The recorded start is commit `d115dcd3e068bd68080562a8cd2e7ddc0e29ee1e`,
tree `56ad54b229b89a27845200ef9575b52069396f84`. No old branch is
merged or cherry-picked wholesale. Only the reviewed data families in Section
5.1 plus `canonical.lua`, `deterministic.lua` and the generic safe-integer,
polygon, segment-distance and ellipse predicates from `geometry/exact.lua` may
be re-authored or copied deliberately. The old compiler, topology modules and
validators are not imported.

## 3. Preserved product scope

The rebase keeps these player-visible and engine-correctness outcomes:

- 38 stable named zones, six race regions, two factions, Holy Grounds and two
  dragon islands;
- the same starts, capitals, stable anchor-slot vocabulary and critical fixed
  content identities;
- a reliable authored travel graph beginning from the present 57 land routes,
  plus explicit boat/island links;
- easy safe hinterlands, stronger outward progression, contested frontier and
  level-60 island endpoints;
- stable faction, territory, PvP, housing, protection, mount/water and depth
  semantics;
- exactly ten peaceful housing-mask identities, four 600 by 300 coastal cores,
  whole-footprint 101 by 101 eligibility and a capacity export for WP24;
- the 30/24/3 road-class split and 7/16, 5/12 and 3/8 surface/corridor widths;
- two distinct 96-node approaches and landing beaches per dragon island, with
  the existing route-parity outcome;
- attractive local terrain, biome, water, landmark, route and decoration
  variation;
- a small globally queryable project-owned terrain-height field, with v7 as
  the native cave/ore/dungeon/stratum substrate rather than height authority;
- preservation of caves, strata, ores and native dungeons under the authored
  surface rewrite;
- one consolidated VoxelManip content transaction; and
- stable deterministic public geography queries and consumer migration.

The rebase does not cut T3 through T9 product scope merely because their
horizontal inputs become simpler.

## 4. Retired exact guarantees

The R0 fold retired these former product requirements:

- the exact 61-edge geometric land-boundary dual;
- byte identity of its original 57 boundary records and the four added flank
  records;
- canonical shared-boundary station rasters and stable boundary IDs;
- exact half-open face cycles, perimeter attachments and side/tie ownership;
- base-bay mouth apertures, closure wings and their topology proof;
- the closed 22-component coast-projection roster;
- exact `nearest_boundary_at` distance/identity;
- route coincidence with a shared zone boundary;
- seed-dependent macro land/zone topology and the 4,123-seed topology census;
- exact core/gate gameplay-level control fields and the capital 20/25/30
  directional progression profile;
- node-exact Euclidean interpretation of the 80-node shelf boundary (the new
  classifier keeps a nominal 80-node expanded band); and
- repeating the identical fixed-layout housing-mask/packing audit across 32
  geometry seeds (run it once per layout version; height/resource audits still
  use representative seeds); and
- validation/evidence whose only purpose is proving the retired structures.

Historical documents and evidence remain readable as history. Live design,
implementation plans, runners and acceptance gates must clearly label them as
superseded rather than leaving two active contracts.

## 5. Target horizontal data model

The reviewed implementation should converge on one compact engine-free source
and one pure evaluator. Proposed ownership:

| File | Responsibility |
| --- | --- |
| `mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua` | zones, hubs, independent macro primitives, paths/crossings, anchors, water, housing, relief/landmark/biome records, cores and visual parameters |
| `mods/MAPGEN/grug_mapgen/wp40/simple_map.lua` | pure normalized 2D queries and precomputed fixed-layout data |
| `mods/MAPGEN/grug_mapgen/wp40/height.lua` | pure globally queryable project-owned `H(full_seed, x, z)` and grading |
| `mods/MAPGEN/grug_mapgen/wp40/planner.lua` | pure typed voxel-operation plan; no engine writes |
| `tools/wp40/render_simple_map_svg.lua` | read-only SVG rendering through the production evaluator |
| `tools/wp40/simple_map_test.lua` | structural and, after visual freeze, spatial invariants |
| `tools/wp40/run_simple_map.sh` | interpreter-selectable test/render entrypoint |
| `docs/research/wp40-simple-map-preview.svg` | current human-review artifact, regenerated rather than hand-edited |

R1 may adjust names if they conflict with established module layout, but
responsibilities may not be split into a second geometry authority.

### 5.1 Source families

The source contains only the families needed by the simple model:

- constants and fixed interesting extent;
- zones and one hub per zone;
- the complete 61-pair allowed geometric-contact set;
- a small ordered list of additive/subtractive macro land primitives;
- fixed start/capital ownership cores;
- typed paths with ordered centrelines and explicit crossing interfaces;
- fixed and candidate anchor records;
- simple explicit hydrology/water masks;
- four explicit between-prong bay masks with mainland ownership/policy;
- ten housing masks and four coastal housing cores;
- compact relief profiles, simple required-landmark masks and logical-biome
  palettes/selector parameters;
- hard-protection and claim-exclusion footprints; and
- fixed visual-warp and preview parameters.

The compiled payload also contains the derived continuous difficulty lattice;
it is not a second source authority.

The current catalog is mined for stable records; it is not retained wholesale
as a compatibility schema. Exact topology-only families disappear from the new
source after their historical evidence is retained.

Housing masks exclude the union of every candidate-anchor envelope, not only
the seed-selected candidate. Their 2D center predicate and packing capacity are
therefore fixed by layout version and need no repeated geometry census.

### 5.2 Fixed layout and controlled variation

Land, macro-region assignment, hubs, route centrelines and zone ownership are
independent of the world seed. A versioned fixed layout ID owns the common
coordinate warp.

World seed may still choose among a prevalidated secondary-anchor candidate
set and drive terrain detail, logical biome/content selection, resources and
decorations. Candidate selection is one bounded canonical hash choice among
the R2-frozen horizontally valid candidates. It is final: the later height and
grading layer must fit the selected candidate and may not reject or reselect
it. It is never a geometry search or rejection loop.

The evaluator/payload binds one canonical full seed string at construction;
public calls never accept or truncate a seed. The SVG uses documented preview
seed `0`, shows the selected candidate solid and all alternatives as faint
markers.

### 5.3 Deterministic coordinate warp

Reuse T1's canonical full-seed-safe hashing to construct the lattice, but do
not call its checked arithmetic or SHA-hash lattice corners on every map
column. The source fixes 1,024-node cells and at most 32 nodes of displacement
per axis. At load/compile time:

1. build a small fixed-layout warp lattice over the finite interesting extent;
2. derive each lattice vector once from the versioned fixed layout ID;
3. store the integer vectors in the compiled/simple-map data; and
4. prove every interpolation intermediate remains below `2^53`, validate a
   displacement Lipschitz constant below one so the warp cannot fold space,
   and evaluate queries with plain integer arithmetic plus Q16 interpolation.

The lattice includes one full cell of halo beyond every primitive and shelf.
Queries outside that padded extent return deep ocean/no zone without clamping
or extrapolating the warp.

The warp is common to land and zone scoring; every hub is transformed through
the same warp before scoring so a hub has zero distance from itself. The exact,
unwarped Holy Grounds rectangle remains the legal protection/macro-region
authority. There is no per-zone boundary noise.

### 5.4 Land membership

Land is the union/difference of a small list of axis-aligned capsules, rounded
rectangles and ellipses evaluated at the warped coordinate. Use integer and
rational comparisons inside the exact safe-integer range.

Elandor and Kragmar use separately authored primitive records and are not
reflections of one another. The Holy Grounds rectangle is exact/unwarped; the
mainland lobes and two island silhouettes use the common warp.

Exterior water classes use one ordered total classifier:

- exact fixed features first: fixed land except any planned-water submask
  declared by that same feature;
- explicit planned/bay water membership with its zone owner second;
- final composed land membership third;
- immutable dragon channels fourth (source validation rejects land overlap);
- `expanded_land_at(80) and not land_at` gives the nominal coastal shelf; and
- remaining exterior is deep ocean.

Declared interior planned water keeps the fixed feature's zone owner;
unrelated general water masks cannot cut fixed land. This accepted D7
classifier is total. Fixed unwarped land and every
warped additive primitive use closed membership (`<=`). Every subtractive
primitive has one closed explicit planned-water mask, and planned water wins
over ordinary land. `expanded_land_at(r)` expands fixed-land extents and each
additive primitive by `r` after the query point is warped; it neither shrinks
nor expands subtractive masks. The classifier consults it only after fixed
land, planned water, ordinary land and closed channel masks have failed, and
shelf equality is included. This is deliberately a dilation of authored
positive shapes, not exact Euclidean distance to the final CSG boundary.

Shelf policy and dressing both inherit from the same nearest eligible mainland
hub. This dilation is an intentionally simplified visual/policy band, not a
claim of exact Euclidean distance around every warped point. Channels retain
their full-depth immutability and minimum width/warning/hard-strip gates.

### 5.5 Zone ownership

After fixed core overrides, restrict candidates to one macro-region and choose
the least integer power score:

```text
score = squared_distance(w(point), w(hub)) - bias
```

Use numeric zone ID for exact ties. Warped integer deltas are bounded by 8,192
nodes and `abs(bias) <= 2^24`, so scores and differences are exactly
representable by Lua doubles without rational cross multiplication. Candidate
counts are structurally bounded at 16/16/4/1/1.

Gameplay difficulty is a separate fixed continuous lattice, not a boundary
query. At each 32-node lattice point, take the hard zone target selected by the
power/macro owner and apply a separable triangular kernel with
`max(0, 192 - abs(delta))` weights on each axis. Store the normalized Q16 value
once. Runtime performs two sequential one-axis Q16 lerps (never a Q16-cubed
product) and rounds only the final level; the compile-time bound covers kernel
normalization and both lerps below `2^53`. Mainland and each island use separate
component lattices, so smoothing never crosses ocean. This remains continuous
when the nearest rival changes, at three-zone junctions and across the exact
Holy macro edge. No public or internal stable boundary identity is required.

### 5.6 Path model

Each path record has:

- stable ID and `road`, `trail`, `rail`, `river` or `boat` kind;
- class/profile and corridor width;
- ordered integer centreline points;
- stable endpoint IDs; and
- explicit bridge/ford/tunnel/causeway/ferry/landing interfaces.

Dry paths never add land. Source validation reports any ordinary corridor that
leaves land outside a declared crossing. Sparse path/hydrology queries reuse a
small 128-node candidate index at the public-query stage; R1 rendering may
brute-force the small catalog. Exactly 57 land routes define `neighbors(id)`
and retain 30 primary, 24 secondary and three trail records with 7/16, 5/12
and 3/8 profiles. Required POIs have explicit spurs. Boat routes are a separate
travel graph with the two distinct approaches/landings and parity gate per
island; they never make land neighbors.

## 6. Query and compatibility contract

The pure 2D core initially owns:

```text
macro_region_at(x, z)
land_at(x, z)
id_at(x, z)
water_class_at(x, z)
nearest_path_at(x, z, optional_kind)
selected_anchor_2d(zone_id, slot_id)
```

After horizontal and vertical products are final, the public policy surface
supplies:

- defensive-copy `get`, `at`, `neighbors`, `travel_links` and `anchor`
  accessors;
- allocation-free `id_at`, `biome_at`, `race_region_at`, `faction_at`,
  `territory_rule_at`, `pvp_rule_at`, `surface_mob_level_at`, `mob_level_at`,
  `guard_level_at`, `terrain_height_at` and `water_class_at` scalars;
- indexed `nearest_route_at` and `nearest_hydrology_at`;
- unconditional `housing_eligible_at`, where `true` means the complete 101 by
  101 future reservation passed every static exclusion; and
- no public stable `nearest_boundary_at` replacement unless a real consumer
  later establishes a need.

`surface_mob_level_at` means gameplay difficulty, not terrain elevation. Each
zone has one authored target and the fixed continuous difficulty lattice
applies. The existing independent depth floor still wins in `mob_level_at`
below ground.
`terrain_height_at` is the globally queryable project-owned `H`.

Policy precedence remains explicit: bounded hard-protection volumes first;
deep ocean and dragon channels immutable at every y; the exact Holy rectangle
immutable through y = -700 and contested/editable at y = -701 and below;
zone-owned planned water and shelf inherit their declared/nearest-hub policy;
ordinary land then uses its zone fields. Planned water, shelf, paths and static
exclusions remain claim-ineligible.

Existing `grug_core.territory_at`, `zone_at`, `mob_level_at`,
`guard_level_at`, `difficulty_at`, `open_sea_at` and protection callers migrate
through small compatibility adapters. Existing
`grug_core.surface_level_at(x, z)` already means terrain height and must never
be redirected to difficulty; it keeps that semantic and switches to
`terrain_height_at` only in the atomic production cutover. The coarse spawn
buckets may remain derived during R7; no mob consumer requires exact boundary
identity.

## 7. Delivery sequence and gates

### R0 — reviewed authority rebase

Owned result:

- independently reviewed simple-map decision and this delivery plan;
- accepted D1-D7 folded into `world_zones.md`;
- WP40 row/decomposition rewritten in BACKLOG and the engineering brief;
- a closed supersession table covers `docs/research/wp40-source-authority.md`,
  `docs/research/wp40-t2-plan.md`, `docs/research/wp40-t2-contracts.md`, every
  old final runner, `docs/research/wp40-acceleration-and-delivery-plan.md`,
  `docs/research/wp40-puc-final-gate-inventory.md`, `AGENTS.md`,
  `docs/process/wp-workflow.md` and the WP40 interpreter clauses in
  `docs/research/luanti-lua.md`; the two newly named research files each get
  an explicit supersession/status row;
- already self-labeled historical/evidence records such as the T2 handover,
  reality-corrections and degeneracy-completeness notes need no new status
  label and remain readable history;
- the T2 S1 locked-surface/winner-seed rule is explicitly dissolved while its
  accepted artifacts remain unchanged readable history;
- the rewritten brief is checked against
  `docs/research/mapgen-control.md`'s required engineering subjects;
- BACKLOG, ROADMAP and dependent-WP wording are updated consistently;
- an `rg`-backed legacy geography/height API-to-consumer matrix names every
  target query, transition adapter and removal test;
- README design tour/current state checked as required by `AGENTS.md`; and
- the discarded `tools/wp40/render_simple_map_preview.lua` scratch file is
  removed before R1 creates the production-backed renderer; and
- the resolved root TODO deleted after the authoritative fold.

Gate:

- one unambiguous live WP40 contract;
- D7 is no longer pending;
- preserved product requirements enumerated;
- retired exact requirements enumerated;
- no historical evidence falsified or relabeled;
- no old runner/process document still names PCC/F1/F2 or the exact T2 schema
  as a live final gate;
- independent strong-agent review clean; and
- no production code change in R0.

Review record (2026-08-25): independent read-only Fable xhigh review found two
High and six Medium authority defects. Focused rereviews exposed six related
Medium residues. Every finding was corrected; the final focused rereview
returned **ACCEPTED** with zero Critical, High or Medium findings. R0 changed no
production code and preserved historical evidence bytes and measurements.

### R1 — descriptive 2D model and SVG

Owned result:

- slim source skeleton extracted with stable IDs;
- pure land/region/zone/path/water/housing/anchor evaluator;
- fixed warp lattice;
- SVG renderer with independent layers; and
- a generated preview presented to the user.

Pre-visual gate checks only structure and determinism:

- Lua 5.1 syntax/static gates;
- source schema/count/ID/reference validity;
- exact 57-route class/profile counts, separate boat graph, ten housing masks,
  four coastal cores and independently authored continent records exist;
- pure evaluator and renderer use the same source/module;
- no route-to-land repair or candidate invention code exists;
- repeated same-interpreter rendering is byte-identical;
- a short representative PUC/LuaJIT canonical parity check; and
- the SVG parses successfully.

R1 reports advisory connectedness/route-fit/water-class failures but does not
repair them or tune hidden algorithm constants to turn them green. The user
first reviews the picture; route centrelines are expected to be re-authored
from the retained endpoints/classes because the old five-point records were
boundary-derived skeletons, not finished scenic roads.

### V1 — mandatory user visual gate

The user reviews land silhouette, zone proportions, progression, route shape,
POI distribution, islands, Holy Grounds and overall beauty. Each requested
change edits source data or the single common visual policy. No hidden repair
logic is accepted.

The layout does not become frozen until the user explicitly accepts it.

### R2 — freeze and validate the accepted 2D layout

After V1, add and freeze the small spatial invariant set:

- one connected mainland and two connected islands on the complete integer
  node grid of the finite authored extent;
- all 38 zones nonempty and connected on that grid;
- hubs and fixed cores own themselves;
- complete 600 by 500 start cores and 512 by 512 capital envelopes are dry
  except for explicitly declared civic-water features, correctly owned and
  retain their required route exits; the underlying power
  owner already agrees throughout each core so the override creates no hidden
  island or unblended boundary;
- fixed anchors are valid and every candidate set has a horizontally valid
  member; the frozen set is final for later grading;
- dry routes fit land except at declared crossings;
- crossings, endpoints, 57-route 30/24/3 classes, 7/16--5/12--3/8 profiles,
  POI spurs and land-graph references are complete; an ordinary two-zone route
  enters no undeclared third zone;
- the separate boat graph retains two distinct 96-node approaches/landings per
  island and the at-most-10-percent parity gate;
- every emergent geometric contact belongs to the checksum-covered complete
  61-pair source allowlist (57 land-route pairs plus four historical
  boundary-only flank pairs); allowed pairs need not all occur and no dual is
  materialized;
- each of the four bays is open and connected from outer water to its head,
  stays at least 64 nodes wide, reaches neither capital belt nor a housing core,
  disconnects no prong and creates no new land contact;
- exact Holy bounds, water precedence, minimum channel/warning/hard-strip
  widths and shelf-policy inheritance pass;
- exactly ten whole-footprint housing-center masks pass every 2D exclusion and
  the four coastal cores retain 600-node frontage and 300-node depth;
- the existing deterministic packing portfolio runs once: all 111 by 111
  lattice origins, best/worst conflict-graph greedy orders, 16 canonical hash
  orders, edge/route/POI-biased and row-major/reverse orders, with its
  constructive minimum/maximum and auditable upper bound. Each hash order is
  fixed by `schema, "housing-pack-NN", layout_id, mask_id, [x,z], 0,0,0`
  under the retained T1 length-prefixed grammar; priority is digest word zero
  as unsigned big-endian 32-bit, then canonical z/x;
- required relief profile/landmark IDs and logical-biome palette/selector
  records are complete, uniquely owned and independently authored where
  required;
- reflected-coordinate/source-digest checks prove Kragmar is not generated by
  reflecting Elandor;
- progression/faction/PvP metadata is complete, and the rounded difficulty
  lattice changes by at most two levels between every orthogonally adjacent
  walkable land pair and along every ordinary land route; island endgame is
  separated by water/boat travel rather than exempted land discontinuity;
- deterministic canonical 2D artifact and SVG;
- bounded regional candidate counts;
- warp safe-integer, no-fold and extreme-coordinate KATs; and
- an 80 by 80 LuaJIT horizontal classification benchmark no slower than 5 ms
  median, with its absolute/relative WP18 difference published and more than
  2 ms added horizontal cost requiring review; one x/z result is reused across
  the vertical column.

Expensive full-layout scans run under LuaJIT. PUC 5.1 runs syntax/static gates
and targeted representative KATs whose canonical digest is compared with
LuaJIT. No exhaustive PUC population is added.

### R3 — pure global height and final immutable payload

Write one small reviewed vertical contract and engine-free implementation for
the project-owned `H(full_seed, x, z)`. It uses precomputed broad/detail integer
noise lattices, compact per-zone relief profiles, simple §8.4 landmark masks
and a fixed grading priority for starts, capitals, paths and the already
selected anchors. It is globally queryable, independent of emerge order and
never reads an engine spawn level or generated chunk.

R3 also freezes final 3D anchors, hard-protection volumes and housing results.
The selected 2D anchor may not be rejected; grading must accommodate it. The
four coastal cores prove the at-most-12-node natural-relief bound in every
eligible 101 by 101 reservation. Landmark ownership and its route/housing/
grading constraints receive focused gates.

### R4 — first complete geography/policy payload, still disabled

Wire the first complete simple payload and implement `grug_zones`, scalar
policy precedence, final housing predicate, logical biome query, anchors, hard
protection and compatibility adapters. Preserve safe coordinate normalization
and defensive-copy versus allocation-free hot-path rules. Add the 128-node
sparse-feature index here.

No adapter or production callback is enabled yet. Gate one fail-closed
horizontal/vertical evaluator, matching engine/offline loaders, canonical
PUC/LuaJIT representative parity and no live exact-topology dependency outside
clearly historical evidence.

### R5 — pure typed planner and disabled consolidated map adapter

Implement the short typed operation priority and the single VoxelManip
transaction against native v7 cave/ore/dungeon/stratum substrate. The new
callback remains provably disabled. Native-preservation, owner-slice,
mapchunk-order and dirty/light/liquid gates run without allowing it to coexist
with a legacy writer in a production configuration.

### R6 — surface, resources and final varying-seed evidence

Map frozen logical biome IDs to content, place deterministic decorations and
resources, and retain WP43 material/depth APIs. No catalog reopens zone, land
or biome-selection authority. Produce the 32-representative-seed G1/G2,
cultural-resource, regional-parity, practical opposing/deep/island-access and
24-apex-slot ledgers. Export R2's fixed-layout housing portfolio, bounds and
capacity result for WP24.

### R7 — atomic production cutover and consumer migration

In one reviewed cutover gate:

- remove/disable the legacy `ocean_mask.lua` and `structures.lua` writer paths;
- enable the single WP40 VoxelManip writer;
- switch every covered geography adapter, including `difficulty_at` and
  `open_sea_at`;
- preserve `grug_core.surface_level_at(x, z)` as terrain-height semantics while
  redirecting it to `grug_zones.terrain_height_at`;
- move spawn, protection, mobs, Kraken, rares, gathering, map, mounts, housing
  and travel to the stable results; and
- prove no loader/callback/settings path can activate both mapgen writers and
  the R0 consumer matrix has no uncovered live call site.

### R8 — release evidence and rollout

Run focused deterministic, vertical preservation, operation-order,
performance, capacity/supply, visual-world and runtime gates. Replace the old
exhaustive topology population with the frozen-layout invariant artifact plus
world-seed tests only for height, biome/content/resource choices that still
vary by seed.

## 8. Test budget and interpreter ownership

All Lua remains plain-5.1-compatible.

- Every changed Lua file: `tools/bin/luac51 -p`. Changed mod code also runs all
  five repository sweeps and `SETGLOBAL` inspection. Every changed
  `tools/wp40/*.lua` file separately runs the do-not-write searches because the
  repository sweeps do not cover tools; runners first prove `rg` is available.
- Long full-layout raster/flood/path/anchor scans: LuaJIT.
- Intermediate parity: small representative PUC 5.1 KATs with byte-identical
  canonical digest/artifact comparison to LuaJIT.
- Runtime-capable harnesses with nontrivial cost support `WP40_LUA_BIN` and
  default to LuaJIT.
- The old bounded T2-final PCC/F1/F2 gate is not run against an incompatible
  new schema merely for ceremony. R0 replaces it by name in `AGENTS.md`,
  `docs/process/wp-workflow.md`, `docs/research/luanti-lua.md` and every live
  runner before R1; the old gate remains readable history only.
- Real fallback-engine testing remains a separate user runtime gate.

## 9. Review brief

The independent reviewer must inspect this plan and the decision source
against actual `world_zones.md`, the WP40 engineering brief, BACKLOG, current
source/catalog/module dependencies and real runtime consumers. Apply the full
checklist in `docs/process/wp-workflow.md`.

Required lenses:

1. **Scope preservation:** identify any player-visible WP40 promise silently
   lost rather than deliberately simplified.
2. **Authority closure:** find any old exact contract that would remain live
   beside the new one or any historical evidence that the plan would misstate.
3. **Algorithm sufficiency:** test whether fixed primitives, restricted power
   hubs, explicit paths/water and fixed cores can represent the
   planned world without a repair subsystem.
4. **Downstream completeness:** verify T3-T9, WP9/WP12/WP13/WP17/WP23/WP24/
   WP31/WP33/WP34 and legacy runtime consumers retain a viable input.
5. **Determinism/Lua/performance:** verify the fixed warp, integer power score,
   index, candidate choice and interpreter/test budget are feasible under
   plain Lua 5.1 and mapgen hot-path constraints.
6. **Execution safety:** verify the coexistence/cutover sequence cannot create
   two production geometry authorities or accidentally consume inactive T2
   worktree state.

Findings are severity-ranked with file/line evidence and a concrete failure
scenario. Critical/High plan fixes receive focused re-review before R0.

## 10. Stop conditions

Stop and return to contract review if implementation would require any of the
following:

- a second zone-ownership evaluator;
- a path, anchor or validator that mutates land or zones to make itself fit;
- a new stable boundary identity;
- seed-dependent macro topology;
- a source-specific exception inside the generic evaluator;
- a new unbounded recovery/search loop;
- rejecting or reselecting an R2-frozen anchor during vertical fitting;
- using engine spawn levels or generated chunk-local v7 height as global `H`;
- a second VoxelManip transaction;
- enabling the new writer before the atomic legacy-writer/API cutover;
- weakening native dungeon/cave/ore/stratum preservation without explicit user
  approval; or
- inventing player-visible semantics not covered by the folded design.

Source-data corrections and visual parameter edits are expected and are not
stop conditions when they preserve the single simple model.
