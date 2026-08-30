# WP40 Simple Map Rebase Plan

**Status:** D1-D7 and R0-R5 are accepted. Fixed-layout V1e R2 remains the live
horizontal authority; the pure R3 vertical implementation and the complete,
still-disabled R4 geography/policy and R5 planner/adapter payloads were
independently accepted. V1d remains historical evidence at `d337160`; R6 is
next.

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

- 38 stable named zones, six race regions, two factions, Battlegrounds and two
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
- local preservation of ordinary native cave air/liquid at or below the
  current owner slice's pre-cave v7 height, supporting ore/resource/stratum
  solids below the final authored surface, and unconditionally y-disjoint
  native dungeons under the authored surface rewrite;
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
| `tools/wp40/simple_map_test.lua` | fast structural, parity, sampled-layout and benchmark smoke tests |
| `tools/wp40/simple_map_r2_{metadata,cores,water,routes,grid,housing}.lua` | read-only exact R2 validators; all geometry queries stay in the production evaluator |
| `tools/wp40/simple_map_r2_test.lua` | LuaJIT-only authoritative R2 composition and canonical artifact writer |
| `tools/wp40/run_simple_map.sh` | PUC/LuaJIT parity and SVG-render entrypoint |
| `tools/wp40/run_simple_map_r2.sh` | exhaustive LuaJIT R2 entrypoint with Lua 5.1 syntax/static gates |
| `docs/research/wp40-simple-map-v1e-preview.svg` | accepted V1e human-review preview, regenerated rather than hand-edited; the accepted V1d SVG remains historical evidence |
| `docs/research/wp40-simple-map-r2-artifact.tsv` | canonical machine-readable R2 evidence, regenerated rather than hand-edited |

R1 may adjust names if they conflict with established module layout, but
responsibilities may not be split into a second geometry authority.

### 5.1 Source families

The source contains only the families needed by the simple model:

- constants and fixed interesting extent;
- zones and one hub per zone;
- a small ordered list of additive/subtractive macro land primitives;
- fixed start/capital ownership cores;
- typed paths with ordered centrelines, derived planned-water grading and named
  crossing interfaces where a landmark needs an explicit transition;
- 100 fixed anchor records, including approved V1d-candidate provenance for
  the 84 layout-fixed secondary anchors;
- simple explicit hydrology/water masks;
- four explicit between-prong bay masks whose landward parts carry mainland
  ownership/policy and whose declared outer caps become ownerless deep ocean;
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

Housing masks exclude the 100 actual anchor envelopes and the 74 actual
POI-spur corridors. Retired anchor/spur alternatives reserve no land. Their 2D
center predicate and packing capacity are therefore fixed by layout revision
and need no repeated geometry census.

### 5.2 Fixed layout and controlled variation

Land, macro-region assignment, hubs, route centrelines and zone ownership are
independent of the world seed. A versioned fixed layout ID owns the common
coordinate warp.

World seed drives terrain detail, logical biome/content selection, resources
and decorations, but never 2D anchor placement. All 100 anchors are frozen by
the layout revision; the 84 migrated secondary records preserve only the
approved V1d candidate index as provenance. The later height and grading layer
must fit each fixed position and may not reject, move or reselect it.

The evaluator/payload binds one canonical full seed string at construction;
public calls never accept or truncate a seed. The SVG uses documented preview
seed `0` for seeded fields and shows only the fixed anchor roster.

### 5.3 Deterministic coordinate warp

Reuse T1's canonical full-seed-safe hashing to construct the lattice, but do
not call its checked arithmetic or SHA-hash lattice corners on every map
column. V1b used 1,024-node cells and at most 96 nodes of displacement per
axis; V1c used 512-node cells and at most 64 nodes. The current V1d candidate
uses the same single warp with 256-node cells and at most 60 nodes of
displacement: shorter visible bends without another query or per-zone noise
field. This remains below the no-fold limit. At load/compile time:

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
unwarped Battlegrounds rectangle remains the macro-region authority. Its stable
source and macro/policy keys remain `holy_grounds`; final protection no longer
uses a blanket rectangle rule. There is no per-zone boundary noise.

### 5.4 Land membership

Land is the union/difference of a small list of axis-aligned capsules, rounded
rectangles and ellipses evaluated at the warped coordinate. Use integer and
rational comparisons inside the exact safe-integer range.

Elandor and Kragmar use separately authored primitive records and are not
reflections of one another. The Battlegrounds rectangle is exact/unwarped; the
mainland lobes and two island silhouettes use the common warp.

Exterior water classes use one ordered total classifier:

- exact fixed features first: fixed land except any planned-water submask
  declared by that same feature;
- the deep-ocean cap of a matched outer bay mouth second;
- explicit planned/bay water membership with its zone owner third;
- final composed land membership fourth;
- immutable dragon channels fifth (source validation rejects land overlap);
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
the least fixed-point power score:

```text
score = squared_distance(w(point), w(hub)) - bias
```

Use numeric zone ID for exact ties. The owner-only warp keeps eight fractional
bits while land and water masks retain the ordinary integer warp. Scaled
coordinate deltas stay below 8,192 times 256 and the score subtracts
`bias * 256^2`; with `abs(bias) <= 2^24`, scores and differences remain exactly
representable by Lua doubles without rational cross multiplication. Candidate
counts are structurally bounded at 16/16/4/1/1.

Speargrass Reach is the sole nonzero ordinary site bias, exactly `256`
node-squared units; all other zone biases are zero. With the eight-bit owner
warp scale this is a sub-node raster tie nudge, not a second boundary model.
The exact whole-grid connectivity gate, not the nudge itself, proves the final
result.

The four coastal housing cores are a second small override family, but remain
mutable ordinary land. Each is one fixed vertical capsule compiled from its
landmark envelope: rounded/tapering ends, at least 600 nodes of frontage and
at least 300 nodes of inland depth. Core membership precedes macro coast,
ordinary power ownership and hydrology, so its exact R2 scan can require every
member node to be dry, owned by the declared housing zone, mask-eligible and
static-exclusion-free without a repair pass.

Gameplay difficulty is a separate fixed continuous lattice, not a boundary
query. At each 32-node lattice point, take the hard zone target selected by the
power/macro owner and apply a separable triangular kernel with
`max(0, 192 - abs(delta))` weights on each axis. Store the normalized Q16 value
once. Runtime performs two sequential one-axis Q16 lerps (never a Q16-cubed
product) and rounds only the final level; the compile-time bound covers kernel
normalization and both lerps below `2^53`. Mainland and each island use separate
component lattices, so smoothing never crosses ocean. This remains continuous
when the nearest rival changes, at three-zone junctions and across the exact
Battlegrounds macro edge. No public or internal stable boundary identity is
required.

### 5.6 Path model

Each path record has:

- stable ID and `road`, `trail`, `rail`, `river` or `boat` kind;
- class/profile and corridor width;
- ordered integer centreline points;
- stable endpoint IDs; and
- explicit bridge/ford/tunnel/causeway/ferry/landing interfaces.

Paths never change horizontal land ownership. Where a land path intersects
planned water, the intersection deterministically becomes a later graded
bridge, ford or causeway span; named crossing records remain only where a
landmark or vertical transition needs explicit identity. Coastal shelf, deep
ocean and dragon-channel intersections still fail. A route may geometrically
pass through another zone without adding that zone to the route-neighbor
graph. Sparse path/hydrology queries reuse a
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
deep ocean and dragon channels immutable at every y; zone-owned planned water
and shelf inherit their declared/nearest-hub policy; ordinary land then uses
its zone fields. Battlegrounds ordinary terrain is contested/editable for both
factions at every y but remains claim-ineligible. Planned water, shelf, paths
and static exclusions remain claim-ineligible.

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

**R1 completion record (2026-08-25):** the engine-free source, pure evaluator,
offline loader, canonical KAT, SVG renderer and one current preview artifact
are implemented. The runner passed Lua 5.1 syntax/`SETGLOBAL`/portability
checks, byte-identical LuaJIT/PUC 5.1 KATs for seeds `0`, `1`, `2^63` and
`2^64-1`, byte-identical repeated rendering and XML parsing. Seed 0 produced
KAT digest `4cba92a92e2b9ee39f51e79438eed77b9cd60b29c2df1e9fb42014cc70bc3112`;
the generated preview SHA-256 is
`db75907095b9bf917efc9a6869d711811d29faa4011d644108c237653fc1b4b4`.
The final sampled report remained deliberately advisory: three land
components (mainland plus two islands), three disconnected sampled zones,
zero missing zones, twelve undeclared sampled contacts, 175 of 7,080 dry-route
samples on non-land, 99 declared water-crossing samples, 252 of 252 candidate
anchors in their intended zones, and zero bay/channel/sample failures. The
5.687 ms local 80 by 80 classifier median is also advisory until R2's binding
measurement. None of these values triggered repair or visual tuning before
V1.

Calibration record: implementing/integrating model GPT-5.6 Sol; independent
review models GPT-5.6 Sol (pre-review audit) and explicitly authorized Claude
Fable (formal acceptance). The pre-review audit found 0 Critical / 6 High / 3
Medium; the first full Fable review found 0 Critical / 0 High / 3 Medium. Two
correction rounds closed every accepted finding; the focused Fable rereview
returned **ACCEPTED**, 0 Critical / 0 High / 0 Medium. Observed elapsed wall
time is `unknown` because the implementation crossed a context compaction.

### V1 — mandatory user visual gate

The user reviews land silhouette, zone proportions, progression, route shape,
POI distribution, islands, the then-called Holy Grounds and overall beauty.
Each requested
change edits source data or the single common visual policy. No hidden repair
logic is accepted.

The layout does not become frozen until the user explicitly accepts it.

### V1b — bounded microgeometry refinement

The first V1 review accepted symmetry, macro silhouette, zone sizes and
distribution, the then-called Holy Grounds, islands and the overall map layout.
Before R2, the
user requested one deliberately small refinement pass for less uniform zone
edges, fewer straight roads and a more legible, coherent river/lake system.

V1b keeps all stable zone, route, anchor, landmark and hydrology IDs plus the
57-route graph, endpoints, classes, explicit interfaces and macro primitives.
It changes only three readable source policies:

- the one common fixed warp's maximum displacement grows from 32 to 96 nodes
  per axis while retaining the 1,024-node lattice, safe-integer interpolation
  and no-fold proof;
- each route's authored midpoint, endpoints and every explicit crossing remain
  exact pins, while a bounded source-time integer curve adds two offset points
  per leg from a fixed class amplitude; there is no A*, pathfinding, land
  repair or runtime randomness; and
- the existing 25 hydrology records are re-authored into longer connected
  reaches with visibly wider tarn/lake/cenote masks. Water-surface offsets and
  explicit rapid/waterfall interfaces remain the future R3 height authority;
  terrain does not discover or move waterfalls automatically.

The revised fixed layout is `wp40-simple-map-v1b`. A regenerated SVG returns
to the user before R2. Its connectedness, route-fit, contact, channel and
performance diagnostics remain advisory exactly as in R1; V1b does not repair
them merely to improve a report.

**V1b technical completion record (2026-08-25):** the runner passed Lua 5.1
syntax/`SETGLOBAL`/portability checks, byte-identical LuaJIT/PUC 5.1 KATs for
seeds `0`, `1`, `2^63` and `2^64-1`, repeated-render byte identity and XML
parsing. The expanded KAT binds every derived route point and hydrology support
point. Seed 0 produced
`66d980db38fef30fd5081a897eba5b394366ecd139853ab00fb83ada8aebcc6b`;
the generated SVG SHA-256 is
`c2d54900d02117073a34b78d2a538742a64b84cf599d1fc5ff847562179d8cf5`.
The final advisory report has three land components, nine disconnected sampled
zones, zero missing zones, fifteen undeclared sampled contacts, 329 of 7,770
undeclared off-land route samples, 246 declared-water crossing samples, 252 of
252 candidate anchors in their intended zones, zero bay/sample failures and
34 channel-interior failures. The last local 80 by 80 median was 5.261 ms;
V1c later retires the then-proposed binding 5 ms threshold because it had no
whole-mapchunk budget or measured derivation. The measurement remains useful
comparative evidence.

Calibration record: implementing/integrating model GPT-5.6 Sol; independently
reviewing model explicitly authorized Claude Fable. The initial review found
0 Critical / 0 High / 0 Medium / 3 Low and returned **ACCEPTED**. One small
cleanup round closed all three Low observations without changing KAT or SVG
bytes; policy requires no focused rereview for Low corrections. Observed
elapsed wall time is `unknown`.

### V1c — visual closure candidate

Before freezing R2, the user authorized one final bounded visual pass. V1c
uses the fixed layout id `wp40-simple-map-v1c`, keeps every stable zone, route,
anchor, landmark, interface and hydrology ID, and makes only source-readable
adjustments:

- the four existing bay masks now cover the complete open gaps between the
  start lobes, while slightly deeper mainland belts keep both continents
  connected behind their authored heads;
- the mainland fronts overlap behind the exact then-called Holy Grounds
  rectangle, so the then-current macro/protection precedence remains
  authoritative without accidental
  shelf seams along the long north and south edges from x = -2400 through
  +2400; the extreme corner transitions into the immutable channels remain an
  explicit R2 full-grid validation subject;
- the exact then-called Holy Grounds rectangle remains unchanged and solid except for its
  explicit hydrology, while its internal nearest-hub ownership reuses the same
  already-computed common warp as every other non-fixed zone;
- the single common warp changes from 1,024/96 to 512/64 cell/displacement
  parameters. Each query still reads and interpolates exactly four lattice
  vectors; only the tiny load-time lattice gains entries;
- selected long river reaches gain a few authored support points, and pond,
  lake, tarn and cenote masks use short curved variable-width point chains
  instead of equal-width two-point capsules; and
- preview-only colors distinguish ordinary mainland frontier land from the
  then-called Holy Grounds without changing classification.

No second noise field, per-zone random function, pathfinder, erosion pass,
Bezier evaluator or repair loop is added. The 80 by 80 LuaJIT classifier
measurement remains published as advisory comparative evidence. The previous
5 ms absolute and 2 ms regression thresholds are retired: neither had a
measured whole-mapchunk budget or documented derivation. A fixed performance
limit may become binding only after that evidence exists.

**V1c technical completion record (2026-08-25):** the runner passed Lua 5.1
syntax/`SETGLOBAL`/portability checks, byte-identical LuaJIT/PUC 5.1 KATs for
seeds `0`, `1`, `2^63` and `2^64-1`, repeated-render byte identity and XML
parsing. Seed 0 produced KAT digest
`d32688cae3d748947f15e76e52717212e078bfe5ee254f0c1f5f9a2ca1bf4640`;
the generated SVG SHA-256 is
`922178bdd566dc39a56492c505e163dab7d24d27102ee9c691c6b410fa958463`.
The final advisory 16-node sampled report has three land components, twelve
disconnected zones, zero missing zones, fifteen undeclared contacts, 316 of
7,770 undeclared off-land route samples, 256 declared-water crossing samples,
252 of 252 candidate anchors in their intended zones, zero bay/sample failures
and 61 channel-interior failures. On the local x86-64 AMD Ryzen 7 9800X3D host,
LuaJIT measured a 5.919 ms median for the 80 by 80 classifier probe. That value
is evidence, not a pass/fail limit.

Calibration record: implementing/integrating model GPT-5.6 Sol; independently
reviewing model explicitly authorized Claude Fable at xhigh effort. The first
full review found 0 Critical / 0 High / 2 Medium / 5 Low and returned
**REJECTED**. The layout-id/bay-table, path-kind, fixed-core water and scoped
seam corrections closed both Medium findings and the three directly relevant
Low findings. A focused rereview returned **ACCEPTED**, 0 Critical / 0 High /
0 Medium. Non-blocking follow-ups remain explicit rather than silently
repaired: the then-open water/macro territory-policy discussion was resolved
by the 2026-08-27 Battlegrounds ruling in V1d below, while R2 had to check the
one-node Highcourt river/core tangency plus the remaining validation-strength
observations before freezing the complete integer layout.
Observed elapsed wall time is `unknown` because the work crossed a context
compaction.

### V1d — bounded boundary, coast and capital-access closure

The fixed layout id is `wp40-simple-map-v1d`. The V1c review was nearly
accepted visually. Before R2, the user requested one
last bounded pass: visibly shorter organic zone-boundary meanders, less land
removed by the four bays and a verified anti-wall capital approach. V1d keeps
all 38 zone ids, hubs, macro primitives, route graph edges, route ids,
hydrology ids, anchors, housing masks and fixed cores.

- The same single common warp changes from 512/64 to 256/60
  cell/displacement parameters. A query still interpolates exactly four cached
  lattice vectors. There is no second octave, boundary noise, per-zone random
  function or authored boundary polyline.
- The four existing bay masks retain their ids but move the widest samples
  outside the visible extent so only their curved inland shoulders enter the
  map, then taper close to the start lobes. Ten short
  variable-width samples per bay produce the winding coast without adding a
  water or erosion algorithm.
- The final visual correction clips the outer part of each matched bay mask to
  ownerless deep ocean at warped z = -3000 on Elandor and z = +3000 on
  Kragmar. The same shared warp gives each transverse mouth boundary its
  gentle meander; no new field or water algorithm is introduced.
- The access audit found that capital envelopes and gates were hard-protected,
  but every road beyond them was only claim-excluded and mutable. Six explicit
  capital-ingress records therefore concatenate existing route pairs into one
  128-node-wide shallow hard-protected public corridor per capital, continuous
  from the capital into the exact Battlegrounds rectangle. They add no route or
  zone edge and the SVG shows their width as a faint route underlay.
- At V1d acceptance, Holy Grounds naming and blanket shallow protection were
  deliberately left unresolved because R2 freezes geometry rather than final
  policy. The 2026-08-27 Battlegrounds ruling now keeps all stable zone ids,
  individual display names, exact rectangle and internal `holy_grounds` keys,
  while renaming the player-facing macro region and making ordinary terrain
  shared mutable and claim-excluded at every depth. Explicit bounded hard
  protection and flight permission remain unchanged.

The generated V1d SVG returns to the user before R2. Full-grid topology,
route-fit, contact, channel and timing diagnostics remain advisory until R2;
V1d does not repair them to improve a report.

**V1d technical completion record (2026-08-25):** the runner passed Lua 5.1
syntax/`SETGLOBAL`/portability checks, byte-identical LuaJIT/PUC 5.1 KATs for
seeds `0`, `1`, `2^63` and `2^64-1`, repeated-render byte identity and XML
parsing. Seed 0 produced KAT digest
`263adbd158c90cadfd70f25e1f631ad7c55eff9fd1aaa9dbd26034a3fd0a1f11`;
the generated SVG SHA-256 is
`92569330f9be0c7a5bd64510fb1cf04307d35acd99e7e5af2db20dc7b8829910`.
The final advisory 16-node sampled report has three land components, eleven
disconnected zones, zero missing zones, thirteen undeclared contacts, 316 of
7,770 undeclared off-land route samples, 256 declared-water crossing samples,
252 of 252 candidate anchors in their intended zones, zero bay/sample or
hydrology-sample failures and 30 channel-interior failures. Its water-class
counts are 100,168 land, 17,396 planned water, 5,997 shelf, 1,867 channel and
55,423 deep ocean. On the local x86-64 AMD Ryzen 7 9800X3D host, LuaJIT
measured a 5.838 ms median for the 80 by 80 classifier probe. That value is
evidence, not a pass/fail limit.

The capital-access audit found that the prior gate-road claim exclusions did
not prevent player-built walls. V1d now binds six 128-node-wide ingress
corridors, each assembled from two existing route records and hard-protected
continuously from one capital to the Battlegrounds. This is a geographic access
guarantee, not a combat-safety guarantee. It adds neither route edges nor a
pathfinder.

Calibration record: implementing/integrating model GPT-5.6 Sol; independently
reviewing model explicitly authorized Claude Fable at xhigh effort. The first
full review found 0 Critical / 0 High / 2 Medium / 5 Low and returned
**REJECTED**. The layout contract, bay/core exclusion, bay-ownership wording,
ingress class binding, Highcourt route choice and authored-extent wording were
corrected. A focused rereview returned **ACCEPTED**, 0 Critical / 0 High /
0 Medium. Its remaining non-blocking observation is that the two Gravesalt
ingress routes end in authored shallow marsh without a complete crossing pair;
R2 owns that route-fit/crossing check rather than V1d inventing a repair. The
later Battlegrounds policy was still deliberately deferred at this historical
gate and was resolved by the 2026-08-27 ruling above. Observed elapsed
wall time is `unknown` because the work crossed a context compaction.

Final mouth-correction calibration: implementing/integrating model GPT-5.6
Sol; independently reviewing model Claude Opus at medium effort. The first
delta review found 0 Critical / 0 High / 2 Medium and returned **REJECTED**;
both findings were documentation-authority gaps, while the geometry,
precedence, ownership, Lua 5.1 behavior and preserved warp all checked out.
After those fixes, a focused review found two further stale paragraphs and
again returned **REJECTED**, 0 Critical / 0 High / 2 Medium. The final focused
rereview returned **ACCEPTED**, 0 Critical / 0 High / 0 Medium. Its six Low
observations remain non-blocking: redundant direction data, an unasserted
land/shelf-clearance rationale, one mirrored diagnostic loop, the preview-only
full control centreline, the already accepted landward bay tongue and the
later 48-node flight-warning integration. The runner evidence above was
produced locally by Sol; the read-only reviewer did not rerun it.

The V1d KAT/SVG digests above are immutable historical visual-acceptance
evidence, not reproduction targets for the later R2 freeze. R2 deliberately
freezes routes, adds exact fixed-point ownership evidence and binds the four
coastal housing cores; its current KAT, SVG and canonical artifact digests are
recorded below and supersede V1d for current-tree reproduction.

### R2 — freeze and validate the accepted 2D layout

With V1d visually approved, add and freeze the small spatial invariant set:

- one connected mainland and two connected islands on the complete integer
  node grid of the finite authored extent;
- all 38 zones nonempty and connected on that grid, treating local hydrology
  as part of its zone but excluding owner-inheriting shelf and bay water from
  political-territory components;
- hubs and fixed cores own themselves;
- complete 600 by 500 start cores and 512 by 512 capital envelopes are dry
  except for explicitly declared civic-water features, correctly owned and
  retain their required route exits; underlying unconstrained power-owner
  disagreement is recorded as diagnostic evidence, while complete final-zone
  connectivity is the binding proof that the deliberately simple fixed-core
  override creates no detached territory;
- all 16 authored-fixed and 84 layout-fixed anchors are valid at their one
  frozen position; every layout-fixed record retains its approved V1d
  candidate index as provenance, and the 100-position set is final for later
  grading;
- route and POI-spur corridors stay on land or locally owned planned water;
  planned-water intersections are deterministic derived grading spans, while
  shelf, deep ocean and dragon channels remain forbidden;
- crossings, endpoints, 57-route 30/24/3 classes, 7/16--5/12--3/8 profiles,
  POI spurs and land-graph references are complete; geometric passage through
  another zone never creates an implicit route edge;
- the six 128-node capital ingress corridors continuously concatenate their
  declared primary/secondary route pair from the protected capital envelope
  into the exact Battlegrounds rectangle; the 128-node footprint is the protected and
  claim-excluded public envelope around the route, while its route surface is
  graded across any planned water it meets;
- the separate boat graph retains two distinct 96-node approaches/landings per
  island and the at-most-10-percent parity gate;
- all emergent geometric contacts are recorded deterministically as diagnostic
  layout evidence, but do not define route neighbors and require no allowlist
  or stable boundary identity;
- each of the four bays is open and connected from outer water to its head,
  stays at least 64 nodes wide, reaches neither a capital envelope nor a
  coastal housing core, disconnects no prong and creates no new land contact;
- exact Battlegrounds bounds, water precedence, minimum channel/warning/hard-strip
  widths and shelf-policy inheritance pass;
- exactly ten whole-footprint housing-center masks pass every 2D exclusion;
  each of the four mutable vertical-capsule coastal cores retains at least
  600-node frontage and 300-node depth, and every member node is dry,
  zone-owned, mask-eligible and static-exclusion-free;
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
- exact bounded counts for the 16 authored-fixed and 84 layout-fixed anchors,
  including complete approved-candidate provenance;
- warp safe-integer, no-fold and extreme-coordinate KATs; and
- a published 80 by 80 LuaJIT horizontal classification benchmark with host,
  interpreter, absolute result and WP18-relative comparison. It is comparative
  evidence until a whole-mapchunk budget justifies a fixed threshold; one x/z
  result is reused across the vertical column.

Expensive full-layout scans run under LuaJIT. PUC 5.1 runs syntax/static gates
and targeted representative KATs whose canonical digest is compared with
LuaJIT. No exhaustive PUC population is added.

**R2 implementation and evidence record (2026-08-25; independently
accepted):** the LuaJIT-only authoritative runner validates a 7,201 by
6,401 grid, or 46,093,601 horizontal nodes. It reports exactly three land
components, all 38 political territories connected, 74 diagnostic contacts,
17 diagnostic unrouted contacts, no unknown water and maximum adjacent
difficulty delta 1 against limit 2. The route validator freezes all 57 routes,
proves zero route/POI/ingress columns on forbidden water and checks 1,499,010
orthogonal route-corridor difficulty edges with maximum delta 1. All 12 fixed
cores and 84 candidate sets pass. All four bays and two channels pass; each
bay has a warp-derived realized-width lower bound of at least 74 nodes.

The four exact coastal capsules contain 160,679 / 160,679 / 161,607 / 160,679
member nodes respectively, all dry, correctly owned, mask-eligible and
static-exclusion-free, and provide 81,254 / 81,254 / 81,982 / 81,254 centres
whose complete 101 by 101 square remains inside the capsule. The exhaustive
housing run measures 1,092,289 eligible centres, 123,210 lattice origins and
230 deterministic orders. Summed per-mask portfolio minima/maxima are 42/72
for Elandor and 43/82 for Kragmar; exact Claim-Stone faction limits remain a
later policy choice below this measured capacity rather than an R2 invention.

The canonical artifact body digest is
`73165e1ad9e9dd03bc608b544e5906a10df2bf7b2c23779b311ad3cbdadf4f7b`;
its complete-file SHA-256 is
`02585d6644265e8889edb3311045d76c2dd7152700dff33563bd8daabc13c339`.
It embeds SHA-256 rows for all 14 executable R2 inputs. The ordinary runner
passes LuaJIT/PUC 5.1 byte parity for seeds `0`, `1`, `2^63` and `2^64-1`;
seed 0 is
`0a945840673d3170ce545c3c12af1422dcd12da5398a88faaf39c42d5346056d`.
Repeated SVG rendering is byte-identical and XML-valid; the current preview
SHA-256 is
`0739e7568a254b5883f8ed2d3fe4ac182056e017dc6d8274b441c5a27136dadc`.

Every measurement in this 2026-08-25 record, including the route-difficulty-
edge count, the housing eligible-centre count and the summed per-mask portfolio
minima/maxima, is superseded pre-V1e V1d evidence. The accepted V1e artifact
recorded below is the sole live source for R2 digests, counts and capacity.

On the local x86-64 AMD Ryzen 7 9800X3D host under LuaJIT
2.1.1767980792, the allocation-free 80 by 80 classifier median is 7.537 ms,
or about 1.18 microseconds per horizontal column. The exact extracted WP18
surface `zone_at` branch structure measures 0.140 ms on the same coordinates;
R2 is 5,293.0 percent slower because it answers land/water, warped named-zone,
fixed-core and hydrology ownership rather than the old rectangle/radial label.
This is comparative evidence only: one result is reused for the vertical
column, and no absolute threshold exists without a whole-mapchunk budget.

Calibration record: implementing/integrating model GPT-5.6 Sol; initial
independent review model explicitly authorized Claude Opus at xhigh effort;
focused correction reviewer GPT-5.6 Sol at xhigh effort in a fresh read-only
context. The first full review found 0 Critical / 0 High / 3 Medium / 7 Low
and returned **REJECTED**. The first correction round replaced asserted
coastal-core metadata with exact realized capsules, added the durable digest
and benchmark record and closed the seven Low evidence gaps. Its focused
review found 0 Critical / 0 High / 2 Medium / 0 Low: the SVG still depicted
the capsule envelopes as rectangles and the live engineering brief retained
three superseded pre-R2 rules. The second correction round fixed both; its
focused rereview returned **ACCEPTED**, 0 Critical / 0 High / 0 Medium / 0
Low. Critical/High count is 0; fix-round count is two; observed elapsed wall
time is `unknown` because work crossed a context compaction. The durable
review record is [wp40-simple-map-r2-review.md](wp40-simple-map-r2-review.md).

**Accepted bounded V1e correction:** V1d remains the geometry/hash domain,
while source revision `wp40-simple-map-v1e` migrates the
84 secondary anchors to their accepted seed-zero positions and single POI
spurs. Together with the 16 directly authored anchors this yields 100
seed-independent anchor envelopes; unused candidate alternatives reserve no
housing land. The focused correction also closes the three previously unnamed
unequal-height reach contacts as exact contact-face waterfalls without moving
any reach footprint. Wet named WP40 hydrology uses non-renewable range-two
river water, the lower waterfall bed leaves one source-node-deep receiver
open, and native liquid simulation owns the fall itself. All V1e R2 gates
passed on 2026-08-27, including independent review and the user's explicit SVG
approval. The sole live R2 artifact has body/file SHA-256
`1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b` /
`ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b`;
the accepted SVG SHA-256 is
`5816941d7bb7524a653b7cbe6b471f842be8bdc89db5e18f9fbf2017555e8fdc`.
The review is recorded in
[wp40-simple-map-v1e-r2-review.md](wp40-simple-map-v1e-r2-review.md). V1d is
historical evidence at `d337160`. The pure R3 vertical implementation and its
canonical artifact were independently accepted on 2026-08-27; the review is
recorded in [wp40-simple-map-r3-review.md](wp40-simple-map-r3-review.md).

### R3 — pure global height and final immutable payload

The independently accepted implementation and canonical artifact follow
[wp40-simple-map-r3-contract.md](wp40-simple-map-r3-contract.md). Its
engine-free implementation provides
the project-owned `H(full_seed, x, z)`. It uses precomputed broad/detail integer
noise lattices, compact per-zone relief profiles, simple §8.4 landmark masks
and a fixed grading priority for starts, capitals, paths and the fixed
anchors. It is globally queryable, independent of emerge order and
never reads an engine spawn level or generated chunk.

For hydrology, each concrete interface owns its exact water-surface offsets,
node run and node drop. A transition profile's `run`/`drop` pair is only a
normalized shape descriptor and never overrides those interface values. R3
validates the interface offsets against its referenced reaches before grading
terrain or writing a rapid/waterfall transition.

R3 also freezes final 3D anchors, hard-protection volumes and housing results.
A fixed 2D anchor may not be rejected or moved; grading must accommodate it. The
four coastal cores prove the at-most-12-node natural-relief bound in every
eligible 101 by 101 reservation. Landmark ownership and its route/housing/
grading constraints receive focused gates.

### R4 — first complete geography/policy payload, still disabled

The independently accepted implementation and canonical artifact follow
[wp40-simple-map-r4-contract.md](wp40-simple-map-r4-contract.md). R4 wires the
first complete simple payload and implements `grug_zones`, scalar policy
precedence, the final housing predicate, logical biome queries, anchors, hard
protection, compatibility adapters and the 128-node sparse-feature indexes.
It preserves safe coordinate normalization and defensive-copy versus
allocation-free hot-path rules.

The canonical artifact body/file SHA-256 is
`bb19948d6bcb2c9976eddc6358955407f8b4a3c4cd54fb7dce1165e22ed8edca` /
`23a05d2115fb6d3a1b286e09a17847793e23fc0a23817ade8ce8b812875d1b3c`.
Its full run scanned all 49,980,561 columns twice in independent seven-shard
fleets and passed representative PUC/LuaJIT parity. The durable review is
[wp40-simple-map-r4-review.md](wp40-simple-map-r4-review.md). No production
callback is enabled yet; R5 remains a disabled planner stage.

### R5 — pure typed planner and disabled consolidated map adapter

Implement the short typed operation priority and the single VoxelManip
transaction against native v7 cave/ore/dungeon/stratum substrate. R3 `H`/`T`
is the sole final surface and operation authority. Broad authored runs start at
y = -37 and are clipped per vertical owner slice through the upper mapgen owner
edge; no global per-column voxel array or physical rewrite-band guard exists.
The planner is independent of native heightmap and VM content. The adapter may
read the current slice's pre-cave native heightmap only to preserve ordinary
cave air/liquid at or below that local datum; exact authored operations retain
their owned replacement rights, project-native content at/on/above the final
surface is replaceable where R3 height/water requires it, and deep dungeons
remain y-disjoint. The new callback remains provably disabled. Native-
preservation, owner-slice, mapchunk-order and dirty/light/liquid gates run
without allowing it to coexist with a legacy writer in a production
configuration.

The pure typed Planner, consolidated Adapter, disabled construction seam and
canonical exhaustive artifact were independently accepted on 2026-08-29. The
canonical artifact body/file SHA-256 is
`a0e7241dabf71833c490d574cbbf4702cdd2c63289277bcc3f49255039a78e1b` /
`0ffd8cd5c0133645c330703b8e4ea581a21fe6e5891ddcd987236b26a7d07ca0`;
the immutable input-manifest SHA-256 is
`8eaef1d05557655552d845f4a281bf65d0066ceda562eb7736b995c3c174237a`.
The durable evidence and review are recorded in
[wp40-simple-map-r5-review.md](wp40-simple-map-r5-review.md). R5 remains
private and disabled: it registers no mapgen callback and writes no world.
The engineering brief is itself an R5 artifact-bound input and therefore keeps
its pre-acceptance status header byte-for-byte; this plan and the R5 review are
the successor authority for the accepted-stage status and R6 handoff.

### R6 — surface, resources and final varying-seed evidence

Map frozen logical biome IDs to content, place deterministic decorations and
resources, and retain WP43 material/depth APIs. No catalog reopens zone, land
or biome-selection authority. Produce the 32-representative-seed G1/G2,
cultural-resource, natural-density-parity, ordinary-camp-equality, practical
opposing/deep/island-access and 24-apex-slot ledgers. Export R2's fixed-layout
housing portfolio, bounds and
capacity result for WP24. R6 also freezes the invisible cultural-opportunity
slot API: every accepted slot owns the exact centred 5 by 5 by 9 reservation
from `surface_y - 1` through `surface_y + 7`, without world mutation, movement,
retry or fallback search. The accepted surface/decorations, exact six
concentrated frontier zones, land-plus-planned-water resource eligibility,
sampled natural-density parity rule and separate ordinary-camp equality live
in the design documents and the reviewed R6 contract rather than in
implementation defaults.

After R6 acceptance, WP33 registers every cultural source against that frozen
slot API while the writer remains disabled. A registration outside the
reservation fails closed. The lower-two-level replacement question is decided
by WP33's own reviewed contract; it is not an R6 implementation choice.

### R7 — atomic production cutover and consumer migration

In one reviewed cutover gate:

- require the accepted WP33 cultural-source registrations before enabling the
  writer, so no production/fresh-world interval can create permanently empty
  reservations;
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
- Intermediate executable checks use LuaJIT only; no intermediate PUC runtime
  is scheduled. After final Lua bytes freeze, exactly one compact representative
  micro-KAT runs once under PUC 5.1 and once under LuaJIT, and their canonical
  bytes and digest must be identical. A relevant final-byte change replaces
  that pair rather than adding another PUC run.
- Runtime-capable harnesses with nontrivial cost support `WP40_LUA_BIN` and
  default to LuaJIT.
- Independent seed/shard workers run at idle scheduling priority, use immutable
  inputs and separate outputs, and never exceed the workstation-wide
  seven-process cap. One deterministic final step orders and combines them.
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
5. **Determinism/Lua/performance:** verify the fixed warp, fixed-point power score,
   index, fixed-anchor provenance and interpreter/test budget are feasible under
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
- weakening the B+ local-cave, supporting-solid or unconditional dungeon
  preservation rule without explicit user approval; or
- inventing player-visible semantics not covered by the folded design.

Source-data corrections and visual parameter edits are expected and are not
stop conditions when they preserve the single simple model.
