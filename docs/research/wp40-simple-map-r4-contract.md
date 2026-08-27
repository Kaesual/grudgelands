# WP40 simple-map R4 geography and policy contract

**Status (2026-08-27): accepted. The R4 implementation, exhaustive canonical
artifact and independent implementation review are accepted. R2 and R3 remain
the sole accepted horizontal and vertical authorities consumed by R4. R4
remains deliberately disabled and does not generate or publish a Luanti world;
R5 is next.**

R4 combines the accepted fixed horizontal layout and pure vertical evaluator
into the first complete `grug_zones` geography/policy payload. It adds the
logical-biome selector, exact public policy precedence, defensive registry
records, final static housing and protection queries, sparse-feature indexes
and disabled compatibility adapters. It does not change the map approved in
R2/R3 and it does not write a node.

The binding game rules remain in `docs/design/world_zones.md`,
`docs/design/world.md`, `docs/design/housing.md` and
`docs/design/combat_stats.md`. This document makes only the R4 implementation,
API and evidence boundary exact.

## 1. Outcome and non-goals

For one canonical full seed, R4 owns one pure session with:

1. all 38 stable zone records and their land-neighbor and boat-travel graphs;
2. one allocation-free scalar policy surface over the accepted horizontal and
   vertical evaluators;
3. the complete seeded logical-biome field;
4. all 100 final 3D anchors and 42 bounded hard-protection volumes;
5. the final static 101 by 101 housing-centre predicate;
6. exact 128-node sparse indexes for route, hydrology and hard-protection
   candidates; and
7. pure compatibility functions needed for the later atomic R7 migration.

R4 does **not**:

- register `grug_zones` globally or replace any `grug_core` function;
- register an engine callback, VoxelManip writer, node, biome, ore,
  decoration, protection handler or setting;
- enable a compatibility adapter;
- materialize terrain, water, bridge decks, tunnels, POIs or structures;
- map logical biome ids to content nodes;
- choose the final production seed or run the 32-seed R6 content population;
- change a zone, owner, path, reach, anchor, protection footprint, height,
  water result, housing exclusion or accepted R2/R3 digest; or
- revive the retired exact-topology compiler, public boundary identity,
  route DP, generic CSG or template DSL.

R4 is therefore testable offline but intentionally invisible to ordinary
gameplay. R5 first consumes the disabled payload in a typed map planner. R7 is
the only package allowed to publish it and remove the legacy geography
writers.

## 2. Authority, schemas and immutable inputs

### 2.1 Accepted inputs

R4 must verify the following authority before loading executable source:

- V1e R2 artifact body SHA-256
  `1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b`;
- V1e R2 complete-file SHA-256
  `ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b`;
- R3 artifact body SHA-256
  `09b4ac762b9e6dc7d088d5f39c306d0dc80b9769d3bf8b6c35ea8a8a6bc282d2`;
- R3 complete-file SHA-256
  `c1090c5a9169c9fe449ad1b0f560b9a5b5b4a486c744445083ee05fbaa219e65`;
- source schema `grug_wp40_simple_map_source_v2`;
- horizontal schema `grug_wp40_simple_map_v1`;
- height schema `grug_wp40_simple_map_height_v1`;
- geometry/hash layout id `wp40-simple-map-v1d`; and
- accepted source revision `wp40-simple-map-v1e`.

The R4 preflight verifies every `input_sha256` row embedded in both accepted
artifacts against the current checkout before any `dofile` of a bound input.
The following accepted production inputs are especially visible and must stay
byte-identical:

| Input | Accepted SHA-256 |
|---|---|
| `source/simple_map.lua` | `5d4e2726dabbb900e47e7a8bef2a225011e6b003f48de485f752cde88fc7c17f` |
| `simple_map.lua` | `55e507a6e5b2d73bf23233d9ab5e515ad150dbce77c6dc6c158a6133f4e27dfc` |
| `height.lua` | `f69fcd006af40f2f473d592c412508c3d7043403b15c07bfedcb311fe6faee97` |
| `schemas.lua` | `1f3825d1b77972637c850fad32a56a3a0fe08962b14b6c1b107846b7b0004166` |

If R4 appears to need an edit to any artifact-bound input, implementation
stops. The change requires a focused refresh and independent rereview of the
affected accepted stage; R4 may not silently absorb it.

`index128.lua` is not an R2/R3 artifact input. R4 may extend it, but its
existing scalar compile/attach/query behavior remains backward-compatible and
its existing tests remain green. R4 does not edit `schemas.lua`; its new
schema tokens live in the new R4 module and tools:

```text
grug_wp40_zones_v1
grug_wp40_sparse_feature_index_v1
grug_wp40_simple_map_r4_artifact_v1
```

### 2.2 Fixed constants and vocabulary

- Project water level is the integer `1`.
- Horizontal query bounds are the inclusive rectangle
  x = `-3740..3740`, z = `-3340..3340` (49,980,561 integer columns).
- The sparse index cell size is exactly 128 nodes, aligned to mathematical
  floor division in world coordinates.
- The static housing reservation is exactly 101 by 101 nodes.
- Hard protection starts at y = `-700`, inclusive, and is upward-unbounded.
- The independent contested-depth override starts at y = `-701`, inclusive.
- The compatibility underground bucket starts at y `< -40`.
- Canonical representative seeds are, in this order, `0`, `1`,
  `9223372036854775808` and `18446744073709551615`.

The five horizontal water classes remain exactly:

```text
land
planned_water
coastal_shelf
deep_ocean
immutable_dragon_channel
```

The accepted source policy tokens remain exact. The internal token and macro
key `holy_grounds` stay stable for compatibility; their visible name is
Battlegrounds and their ordinary terrain is shared and mutable for both
factions:

```text
territory: accord_home | throng_home | contested_land | holy_grounds
pvp:       peaceful | contested
```

R4 adds only the two scalar results `hard_protected` and `immutable` where
3D precedence requires them. It does not rename source ids.

## 3. Construction and loader boundary

### 3.1 Pure production module

New production file `mods/MAPGEN/grug_mapgen/wp40/zones.lua` has the same
factory style as the accepted evaluators:

```lua
local zones_module = dofile(directory .. "/zones.lua")({
    source = source,
    schemas = schemas,
    canonical = canonical,
    deterministic = deterministic,
    index128 = index128,
    horizontal_factory = dofile(directory .. "/simple_map.lua"),
    height_factory = dofile(directory .. "/height.lua"),
    raw_sha256 = raw_sha256,
})
local session = zones_module.new(full_seed_string, configured_water_level)
```

The dependency table is exact: missing, extra-authoritative or incompatible
dependencies fail construction. `zones_module.new` validates canonical
unsigned 64-bit decimal seed text and requires `configured_water_level` to be
the exact integer `1`. Any other/missing value fails before construction. It
then builds one horizontal session, gives that same session to one height
module/session, and constructs every R4 table and index once. A query never
constructs another evaluator.

The engine path injects `core.sha256(data, true)` through the existing
`raw_sha256_from_core` seam. Offline tools inject the existing raw binary
SHA-256 implementation. Both paths execute the same `zones.lua`,
`simple_map.lua`, `height.lua`, `canonical.lua`, `deterministic.lua` and
`index128.lua` code; there is no reduced engine evaluator or independent
offline policy evaluator.

### 3.2 Disabled foundation loader

`mods/MAPGEN/grug_mapgen/wp40/init.lua` stops loading the historical compiler
and returns a foundation with at least this R4 activation boundary:

```text
enabled = false
disabled_reason = "WP40 R4 payload is validated but not published until R7"
new_session(full_seed_string, raw_sha256, configured_water_level) -> pure R4 session
new_engine_session(full_seed_string, core_api) -> pure R4 session
raw_sha256_from_core(core_api) -> raw SHA-256 function
```

The loader retains the existing `schemas`, `canonical`, `deterministic`,
`validation`, `index128` and `seed_corpus` foundation fields. It removes the
retired `compile` wrapper together with the compiler load; no old compiler
field remains as hidden authority. The two existing foundation/schema tests
are updated only for this deliberate loader transition and the new disabled
reason, while their surviving foundation, capture and mutation guarantees
remain live.

`new_engine_session` requires both `core_api.sha256` and
`core_api.get_mapgen_setting`, reads `water_level` exactly once, parses it as a
finite integer and fails unless it equals `1`; it then calls the same pure
factory used offline. Offline tools pass the explicit integer `1` to
`new_session`. This closes R3's assigned engine-setting obligation without a
query-time setting read.

Loading the mod may load pure factories, but it does not call `new_session`.
Normal `grug_mapgen/init.lua` therefore still assigns a disabled foundation to
`grug_mapgen.wp40`, while the legacy writers remain the only active writers.
R4 defines no global `grug_zones`, calls no adapter installer, and mutates no
`grug_core`, `core` or source table. Tools call `new_session` explicitly.

Construction either returns one complete immutable-by-contract session or
raises a fail-closed programmer error. It returns no partially usable payload.

## 4. Coordinate normalization and result ownership

### 4.1 Node coordinates

Every node-addressed public query validates every required coordinate as a
finite Lua number inside the exact safe-double integer range before and after
normalization. It then rounds to the nearest integer, ties away from zero.
The exact implementation avoids unsafe `value + 0.5` arithmetic:

```text
value >= 0:
  base = floor(value)
  result = base + 1 if value - base >= 0.5, otherwise base
value < 0:
  base = ceil(value)
  result = base - 1 if base - value >= 0.5, otherwise base
```

An x/z query validates x and z. A position query requires a table with numeric
x, y and z and validates all three. Malformed, non-finite or unsafe input is a
programmer error; it is never coerced, clamped or interpreted as absence.
Unknown well-formed ids and absent slots return the absence values specified
below.

The normalized x/z pair is computed once per public call and its horizontal
classification is reused. Vertical-column consumers are expected to cache the
same classification through the later R5 internal batch seam; R4 does not
change a public signature to expose mutable internal records.

Coordinates outside the finite R2/R3 query bounds are already accepted deep
ocean. R4 short-circuits them to owner nil, immutable/deep-ocean policy and
the fixed R3 exterior bed `water_level - 24` (`-23`) without passing a very
large safe coordinate into R3's narrower internal lattice-coordinate seam.
This is the accepted R3 exterior result, not a second height evaluator.

### 4.2 Allocation and defensive copies

These scalar hot-path calls allocate no result table, perform no SHA-256 call,
construct no lattice/feature list and do not scan a full feature catalog:

```text
id_at
biome_at
race_region_at
faction_at
territory_rule_at
pvp_rule_at
surface_mob_level_at
mob_level_at
guard_level_at
terrain_height_at
water_class_at
```

`get`, `at`, `neighbors`, `travel_links`, `anchor`, `nearest_route_at` and
`nearest_hydrology_at` may allocate their documented return records. Every
returned table is a deep defensive copy: changing a result, nested hub,
palette, centreline or anchor field cannot alter a later result or internal
query. The session, source and compiled indexes are never returned directly.

`housing_eligible_at` is a separate cold-path exact predicate. It delegates to
the accepted horizontal implementation and may inspect all 10,201 columns of
one 101 by 101 reservation per call; it is not an allocation-free scalar
hot-path promise and must not be called once per generated node. Housing
placement invokes it for an actual candidate centre, while batch validation
uses the accepted R2 evidence and bounded parity corpus in §12.

## 5. Zone, ownership and graph records

### 5.1 Horizontal ownership

R4 asks `horizontal_session.classification_values_at` exactly once for an
x/z classification and applies this table:

| Water class | Public zone owner | Zone-derived biome/race/faction/policy |
|---|---|---|
| `land` | accepted horizontal owner | yes |
| `planned_water` | accepted local zone owner | yes |
| `coastal_shelf` | accepted nearest-hub zone owner | yes |
| `deep_ocean` | none | no |
| `immutable_dragon_channel` | none | no |

Construction fails if land, planned water or shelf lacks a valid owner, or if
deep ocean/channel carries one. R4 never finds an owner by rescanning zone
shapes and never treats a geometric route crossing as ownership.

### 5.2 Public zone record

`get(id)` accepts one stable text zone id and returns nil for an unknown id.
`neighbors(id)` and `travel_links(id)` have the same text-id rule. A non-string
id is malformed input and raises a programmer error rather than behaving like
an unknown id.
`at(pos)` returns the same defensive record as `get(id_at(pos.x,pos.z))`, or
nil on ownerless exterior water. The record has exactly:

```text
numeric_id
id
display_name
macro_region
race_region
faction                 -- "accord", "throng" or nil
territory_rule
pvp_rule
level_min
level_max
primary_relief_id
difficulty_target
civic_no_hostiles
hub = {x, z}
biomes = ordered array of {id, share}
```

All 38 records preserve source order and values except for the source's Lua
sentinel `faction = false`, which is normalized to nil in every public record
and scalar result. Palette shares are positive integers and total exactly 100
per zone. A share is an exact palette-roll weight, not a realized surface-area
quota: over the inclusive integer roll domain 0..99, each authored entry owns
exactly `share` values in source order. Internal source fields such as ownership
bias and selector/hash implementation data are not public.

The accepted R2 source bytes retain the legacy metadata fields
`logical_biome_selector.share_audit_domain` and
`logical_biome_selector.share_audit_tolerance_percentage_points`. R4
explicitly supersedes only those two audit semantics: they remain byte-bound
historical R2/R3 input metadata, but they are non-operative in R4 and later
work. Production `zones.lua` must not read either field. R4 validation binds
their retained identities, proves that production has zero reads of them and
applies the roll-partition and realized-evidence rules in Section 6 instead.
This narrow supersession does not reopen any R2 geometry, palette entry,
weight, selector hash input or accepted R2/R3 artifact byte.

### 5.3 Land neighbors, boat travel and anchors

`neighbors(id)` returns a sorted, unique array of stable zone ids connected by
the 57 accepted `source.routes`. It returns an empty array for an unknown id.
Only authored route endpoints define this graph. Third-zone passage,
geometric surface contact, POI spurs, island roads and boats add no neighbor.

`travel_links(id)` returns those of the four accepted boat paths that are
incident to that zone, sorted by link id, or an empty array for an unknown id
or a zone with no boat link. Each caller-relative defensive record has exactly:

```text
id
kind = "boat"
from_zone_id
to_zone_id
destination_zone_id
landing_id
width
centreline = ordered array of {x, z}
```

The destination is the opposite endpoint from the queried id. No land route
appears in `travel_links`; no boat appears in `neighbors` or
`nearest_route_at`.

`anchor(zone_id, slot_id)` requires two strings and returns nil for an unknown
zone or absent slot. Otherwise it returns exactly the matching R3
`selected_anchor_3d_by_id` record, defensively copied, including its stable
anchor id, numeric id, zone numeric id, slot id, template id, selection mode,
approved candidate index, x/y/z, platform kind, path kind and functional
feature id. There are exactly 100 records and no synthesized fallback slot.

## 6. Logical biome query

### 6.1 Construction

R4 implements `source.logical_biome_selector` literally. Construction creates
the finite 192-node cell lattice needed by the complete query bounds plus one
neighbor-cell halo. For every cell `(cell_x,cell_z)`, the retained T1
`deterministic.new_hash` grammar uses:

```text
schema:       grug_wp40_geometry_source_v1
seed:         canonical full seed string
domain:       logical_biome_patch_v1
feature id:   empty text
coordinates:  signed cell_x, cell_z
candidate:    0
lanes:        site_x=0, site_z=1, palette=2
```

The site coordinates are
`cell_x*192 + 32 + unbiased_range(site_x_lane,128)` and
`cell_z*192 + 32 + unbiased_range(site_z_lane,128)`. The palette roll is
unbiased range 100 on the palette lane.
All hashes and rejection work occur during session construction. The lattice
stores only integer site x/z and roll and has a canonical digest.

### 6.2 Query

`biome_at(x,z)` first resolves the accepted zone owner. Ownerless exterior
water returns nil. Otherwise it computes mathematical-floor cell coordinates,
examines the own cell and eight adjacent cells, and chooses the site with the
smallest squared Euclidean distance. A tie chooses lowest `cell_x`, then
lowest `cell_z`. It maps the winning cell's roll through **only the owning
zone's** authored ordered palette: the first cumulative share strictly greater
than the roll wins.

Thus land, local planned water and owner-inherited shelf may have a logical
biome, while deep ocean and dragon channels do not. Engine heat/humidity,
another zone's palette, height, decorations and native biome ids never enter
this query. R6 later maps the logical id to content.

Construction proves the ordered cumulative mapping for every roll 0..99 in
every zone: each positive authored entry receives exactly its stated number of
roll values, the intervals are disjoint and exhaustive, and no roll escapes the
owning palette. One roll labels one jittered Voronoi patch whose realized and
zone-clipped area varies, so no seed guarantees an authored entry's presence in
each zone or any per-zone surface-area percentage.

The full seed-zero ordinary-land population proves that every observed result
belongs to its owning zone's palette, that no foreign id appears and that all 16
accepted logical biome ids occur globally. It records deterministic per-zone
ordinary-land counts and their exact realized count/zone-total shares as
evidence. The population is not a query-time correction; R4 never rerolls or
repairs a result. R6's faction resource audit remains the binding distribution
gate for playable content and supply.

## 7. Scalar policy and level precedence

### 7.1 Direct horizontal scalars

For normalized x/z:

- `id_at(x,z)` returns the stable owner zone id or nil;
- `race_region_at(x,z)` returns the owning zone's cultural region or nil;
- `faction_at(pos)` returns the owning zone's `accord`/`throng` value or nil;
- `water_class_at(x,z)` returns exactly one of the five classes;
- `surface_mob_level_at(x,z)` returns the accepted rounded integer difficulty
  for land and planned water, and nil for every exterior class, including
  shelf, deep ocean and channel; and
- `terrain_height_at(x,z)` returns the accepted R3 scalar ground/bed integer
  for every safe coordinate, including its fixed exterior bed.

`faction_at` does not grant construction rights and does not change below
y = -701. A nil faction on contested land is not ocean and is not immutable.
`surface_mob_level_at` is gameplay difficulty, never elevation.

### 7.2 Territory and PvP

Hard-protection membership uses the normalized x/y/z point and the exact 42
R3 volumes. Construction independently proves every hard volume is disjoint
from deep ocean and immutable dragon channels. The public scalar precedence
is then:

`territory_rule_at(pos)`:

1. if the point is in an active hard volume at y >= -700, return
   `hard_protected`;
2. if water class is `deep_ocean` or `immutable_dragon_channel`, return
   `immutable` at every y;
3. if y <= -701 on zone-owned land, planned water or shelf, return
   `contested_land`;
4. otherwise return the owning zone's exact source territory token.

`pvp_rule_at(pos)`:

1. ownerless deep ocean/channel returns nil;
2. y <= -701 on zone-owned land, planned water or shelf returns `contested`;
3. otherwise return the owning zone's exact source PvP token.

Hard protection changes terrain mutation, not combat status. In particular a
capital remains peaceful inside its protected build volume, while a protected
capital ingress through contested terrain remains contested. At y = -701 the
depth override wins because every hard volume ended at y = -700.

The four source zones with internal `holy_grounds` return that token at
y >= -700 outside bounded hard volumes. The token means the visible
Battlegrounds rule: ordinary terrain is mutable by both factions and PvP is
contested. At y <= -701 they return `contested_land`, with the same shared
mutation result. R4 adds no blanket Battlegrounds protection or corridor.

### 7.3 Mob and guard levels

The exact independent depth floor is:

```text
depth_level(y) = min(60, max(1, round_half_away_from_zero(-3*y/50)))
```

It is evaluated only after y normalization and only where the rules below use
it. To retain exact arithmetic across the full safe-coordinate contract, an
implementation returns the already-clamped value 60 directly for y <= -992;
it does not first form an unsafe `-3*y` product.

`mob_level_at(pos)` returns:

| Horizontal class | y >= 0 | y < 0 |
|---|---|---|
| land / planned water | surface level | max(surface level, depth level) |
| coastal shelf | nil | depth level |
| deep ocean / dragon channel | nil | nil |

`guard_level_at(pos)` returns nil for coastal shelf, deep ocean and dragon
channel. On land or planned water:

- inside one of the six capital 532 by 532 hard footprints and y >= -700,
  return exactly 60;
- otherwise return
  `min(70, max(20, surface_mob_level_at(x,z)))`.

The generic guard result does not use `depth_level`. The fixed level-65 king
and level-100 Kraken Guard remain explicit entity rules outside R4.

Boundary KATs include y = `1, 0, -1, -40, -300, -301, -500, -501, -700,
-701, -1000, -1001` at representative home, contested, Battlegrounds,
capital, ingress, planned-water, shelf, deep-ocean and channel coordinates.

## 8. Hard protection and housing

### 8.1 Exact hard membership

The 42 R3 records are complete and active:

- six 128-wide centered half-open start squares;
- six 532-wide centered half-open capital squares;
- six 128-wide capital-ingress polyline corridors; and
- 24 exact apex-socket columns.

R4 compiles their **complete footprint bounds** into a separate 128-node hard-
footprint candidate layer. A start/capital bbox is the exact centered half-open
square from its recipe width. An ingress bbox is the union of its two joined
route centrelines expanded on every side by
`floor((total_width + 1) / 2)`; the maximum included integer coordinate is
converted to a half-open bbox by adding one. A socket bbox is
`[x,x+1) x [z,z+1)`. These are the accepted horizontal `polyline_bounds`
conventions, not bare centreline-segment bounds.

The candidate layer is not geometry authority. Exact membership reuses the
accepted half-open-square rule, the horizontal evaluator's exact polyline-
corridor predicate and exact x/z equality for socket columns, followed by the
R3 y policy. An empty candidate cell returns false without scanning all 42
records.

Every record returned by the height session must match the corresponding
source id, recipe and geometry. All 42 records and exact membership counts are
bound in the R4 artifact. Any hard/immutable overlap is a construction error.

### 8.2 Static housing centre

`housing_eligible_at(x,z)` is exactly the accepted horizontal session's
unconditional static result after normalization. `true` means the complete
101 by 101 reservation passed its owning mask, land ownership and all 314
static claim exclusions. It never checks dynamic player claims, capacity,
faction limits or a y interval. R4 neither reimplements nor weakens the
whole-footprint predicate.

Planned water, shelf, every path corridor, every active hard footprint and all
ordinary Battlegrounds terrain remain claim-ineligible under that accepted
predicate.

## 9. 128-node sparse-feature index

### 9.1 Indexed populations

R4 extends `index128.lua` with backward-compatible sparse-segment and
footprint-layer compilers plus an exact nearest query. It compiles exactly:

- 139 traversable graded paths for `nearest_route_at`: 57 land routes,
  74 fixed POI spurs and eight island routes;
- 25 named hydrology centrelines for `nearest_hydrology_at`; and
- the separate 42-record hard-footprint candidate layer from §8.1.

The four boat paths are excluded from `nearest_route_at`. Each non-degenerate
polyline segment has a stable feature id, the raw one-based source point-pair
ordinal (`points[k] -> points[k+1]`) and half-open integer bbox
`[min_x,max_x+1) x [min_z,max_z+1)`. It is inserted into every 128-node cell
intersected by that bbox. Degenerate source segments fail construction rather
than being silently renumbered. Route cell candidate arrays are sorted by
feature id then segment ordinal; hydrology arrays are sorted by source reach
order then segment ordinal. All contain no duplicates.

Route profile is exact:

- a source route uses its authored `primary`, `secondary` or `trail` class
  and 7/16, 5/12 or 3/8 surface/corridor widths;
- a POI spur whose anchor template is `bandit_home`, `bandit_frontier`,
  `mirefolk` or `clash` is `trail` with 3/8 widths;
- every other POI spur is `secondary` with 5/12 widths; and
- every island route is `secondary` with 5/12 widths.

### 9.2 Exact nearest rule

An indexed nearest query outside the finite horizontal query bounds returns
nil. Inside, it scans the query cell and then increasing Chebyshev cell rings.
Segments already encountered are deduplicated by their compiled segment
identity. The exact point-to-segment squared distance is represented as:

- endpoint projection: integer squared distance over denominator 1; or
- interior projection: squared cross product over segment squared length.

Fractions need not be reduced. They are compared with the accepted
overflow-safe Euclidean/continued-fraction rational comparator already used by
the horizontal/height evaluators; multiplying two arbitrary numerator and
denominator pairs is forbidden. Equal route distance chooses lowest feature
id, then lowest raw segment ordinal. Equal hydrology distance chooses lower
source reach order, then lowest raw segment ordinal, exactly matching R3's
accepted bank-selection tie convention.

After a ring, the query computes the exact minimum squared distance from the
query point to any still-unscanned finite grid cell. It may stop only when
that lower bound is **strictly greater** than the current best rational
distance. Equality continues so an unseen higher-priority feature cannot lose
a tie. With no result it continues until the finite grid is exhausted. A
production query may never fall back to scanning all source records.

`nearest_route_at(x,z)` returns nil outside bounds or this fresh record:

```text
route_id
path_kind              -- land_route | poi_spur | island_route
route_class            -- primary | secondary | trail
segment                -- one-based
distance_numerator
distance_denominator
distance_squared       -- numerator / denominator
surface_width
corridor_width
```

`nearest_hydrology_at(x,z)` analogously returns:

```text
hydrology_id
segment
distance_numerator
distance_denominator
distance_squared
```

The index is acceleration only. R4's validator independently compares it with
a brute-force exact oracle at every grid-cell corner/centre/edge midpoint,
every source vertex, policy KAT points and deterministic interior samples. It
binds candidate counts, maximum ring radius and canonical result digests.

## 10. Exact public session API

The R4 session exposes exactly these public queries:

| Function | Input | Result |
|---|---|---|
| `get` | stable zone id | defensive zone record or nil |
| `at` | `{x,y,z}` | defensive owning zone record or nil |
| `neighbors` | stable zone id | defensive sorted id array |
| `travel_links` | stable zone id | defensive sorted boat-record array |
| `anchor` | zone id, slot id | defensive R3 anchor record or nil |
| `id_at` | x, z | stable zone id or nil |
| `biome_at` | x, z | logical biome id or nil |
| `race_region_at` | x, z | cultural region id or nil |
| `faction_at` | `{x,y,z}` | `accord`, `throng` or nil |
| `territory_rule_at` | `{x,y,z}` | exact policy token |
| `pvp_rule_at` | `{x,y,z}` | `peaceful`, `contested` or nil |
| `surface_mob_level_at` | x, z | integer level or nil |
| `mob_level_at` | `{x,y,z}` | integer level or nil |
| `guard_level_at` | `{x,y,z}` | integer level or nil |
| `terrain_height_at` | x, z | integer ground/bed height |
| `water_class_at` | x, z | one of five water classes |
| `nearest_route_at` | x, z | indexed defensive nearest record or nil |
| `nearest_hydrology_at` | x, z | indexed defensive nearest record or nil |
| `housing_eligible_at` | x, z | boolean |

`territory_rule_at` is total for every valid coordinate: ownerless exterior
water (deep ocean and dragon channels) maps to `immutable`; owner-bearing
classes, including shelf, map through §7.2. Construction rejects an unknown
class/owner combination.

No public boundary id, coast component, macro owner, mutable source record,
hash object, internal classification, functional-surface table or index handle
is exported.

### 10.1 Validation-only session seams

The offline/engine-shaped R4 session also provides the same small evidence
pattern as R2/R3:

```text
canonical_kat()          -> immutable canonical byte string
canonical_kat_digest()   -> lowercase SHA-256 hex
artifact_evidence()      -> defensive evidence table
metrics()                -> defensive construction/query metrics table
```

These four seams and `compatibility` are not part of the future game-facing
`grug_zones` registry. R7 publishes only the API table in §10. Evidence
contains accepted records/results; it does not expose live source, evaluator
or index tables.

## 11. Disabled compatibility payload

The session contains one separate `compatibility` table of pure functions.
R4 does not copy these functions into `grug_core`, register protection or
activate a consumer. R7 either installs or deletes each adapter explicitly.

### 11.1 Direct adapters

```text
surface_level_at(x,z)  -> terrain_height_at(x,z)
mob_level_at(pos)      -> session.mob_level_at(pos)
guard_level_at(pos)    -> session.guard_level_at(pos)
open_sea_at(pos)       -> water_class_at(pos.x,pos.z) == "deep_ocean"
difficulty_at(pos)     -> nil mob level ? 1 : (level - 1) / 59, clamped 0..1
```

`open_sea_at` is false for planned water, shelf and dragon channels.
`surface_level_at` never returns gameplay difficulty.

### 11.2 Lossy transitional adapters

`territory_at(pos)` returns `faction_at(pos)` when non-nil and otherwise
`ocean`. This is intentionally lossy: R7 must migrate construction and
cultural consumers to the direct APIs and may retain this adapter only for an
audited old caller that accepts the loss.

`zone_at(pos)` derives the old spawn vocabulary in this order:

1. y `< -40` -> `underground`;
2. `deep_ocean` -> `ocean`;
3. `immutable_dragon_channel` -> `strait`;
4. `coastal_shelf` -> `coast`;
5. owner zone with `pvp_rule == contested` -> `war_coast`;
6. peaceful `surface_mob_level_at(x,z) <= 5` -> `core`;
7. peaceful `surface_mob_level_at(x,z) <= 15` -> `inner`;
8. remaining peaceful owner zone -> `outer`.

This bucket mapping is disabled transitional compatibility, not new zone
authority. Spawn/content rows migrate to named zones, logical biomes and
levels in R7; no R4 or later design may rely on an exact old `strait` shape.
The `5` and `15` thresholds deliberately do not preserve the retired `10` and
`25` core/inner boundaries. R7 must re-decide every migrated spawn row against
the named-zone and level APIs rather than infer parity from these temporary
buckets.

### 11.3 Pure protection decision

`world_protected_for_faction(pos, actor_faction)` contains no engine/player
lookup. An actor other than exact `accord` or `throng` returns true as a safe
default. Otherwise:

| Territory result | Protected? |
|---|---|
| `hard_protected` / `immutable` | true |
| `accord_home` | actor is not Accord |
| `throng_home` | actor is not Throng |
| `contested_land` / `holy_grounds` | false |

An unknown result is a programmer error. The function proves that ordinary
Battlegrounds terrain is mutable for both factions at y = -700 and -701 while
the exact ingress/hard footprints remain protected at y = -700 only. R7 wraps
this pure result with `protection_bypass`, empty-name handling and the previous
`core.is_protected` handler; R4 does none of those engine actions.

## 12. Canonical artifact and gates

### 12.1 Deliverables

R4 implementation is limited to this planned production surface and its
dedicated tools/evidence:

```text
mods/MAPGEN/grug_mapgen/wp40/zones.lua
mods/MAPGEN/grug_mapgen/wp40/index128.lua
mods/MAPGEN/grug_mapgen/wp40/init.lua
tools/wp40/simple_map_r4_common.lua
tools/wp40/simple_map_r4_offline.lua
tools/wp40/simple_map_r4_validate.lua
tools/wp40/simple_map_r4_artifact.lua
tools/wp40/simple_map_r4_kat.lua
tools/wp40/simple_map_r4_selftest.lua
tools/wp40/run_simple_map_r4.sh
tools/wp40/t1_foundation_test.lua
tools/wp40/t2_schema_core_test.lua
docs/research/wp40-simple-map-r4-artifact.tsv
docs/research/wp40-simple-map-r4-review.md
```

Tests may add narrowly named R4 fixtures only when the canonical artifact
cannot carry the same evidence. Any extra production file or change outside
this list requires a contract amendment or an independently justified
integration-only documentation update. R4 does not update BACKLOG/README to
completed until independent review accepts the artifact.

Changes to the two existing tests are limited to the new disabled reason,
retention of the six pure foundation fields above and removal of assertions
that require the retired `compile` wrapper. The live T1 source audit remains
unchanged and forbids the literal standalone token `grug_zones` anywhere in a
Lua file below `mods/MAPGEN/grug_mapgen/wp40/`, including comments and strings;
R4 production code must not introduce it.

### 12.2 Canonical seed-zero artifact

`docs/research/wp40-simple-map-r4-artifact.tsv` is the sole live R4 artifact
candidate. Its canonical body and complete-file hashes bind:

- both accepted artifact body/file hashes and every verified embedded input;
- every new/changed R4 executable input, including the runner;
- exact schema/layout/source-revision/full-seed/water-level/query-bounds rows;
- the 38 complete public zone records and logical palettes;
- all 57 sorted land-neighbor edges and four boat travel links;
- all 100 public anchor records and 42 hard-protection records;
- logical-biome site-lattice, exact 0..99 roll partitions, full ordinary-land
  population digests, global observed-id coverage and deterministic per-zone
  counts plus exact realized count/zone-total shares;
- full x/z owner/class/scalar counts and policy counts at y = -700/-701;
- hard-index versus exact membership evidence, the accepted R2 housing-result
  digest and bounded R4-wrapper parity corpus described below;
- 139 route and 25 hydrology index populations, bucket metrics and exact
  indexed-versus-brute result digests;
- all scalar boundary KATs and compatibility/protection KATs;
- defensive-copy mutation results;
- normal disabled-loader/no-global/no-callback evidence; and
- construction/query SHA-256, lattice-construction, feature-scan and
  allocation counters required below.

Wall/CPU timings, host details and interpreter versions are printed as
unbound evidence or a separate unbound timing section. They are never included
in a byte-repeat identity digest. R4 has no invented 5 ms or other absolute
performance gate.

### 12.3 Full LuaJIT validation

The authoritative seed-zero run uses LuaJIT and:

1. verifies R2/R3 authority before load;
2. constructs the engine-free and engine-shaped loader sessions from the same
   immutable inputs and requires identical canonical results;
3. scans all 49,980,561 x/z columns for water/owner/id/race/faction/surface
   level/biome validity and exact classification reuse;
4. scans the complete relevant hard-protection footprints and y boundary
   planes, including capitals, starts, ingresses, sockets and immutable-water
   disjointness;
5. proves every ordered logical-biome palette's exact 0..99 roll partition,
   scans the realized ordinary-land population for owner-palette/no-foreign
   validity and global coverage of all 16 ids, and records deterministic
   per-zone counts and exact count/zone-total shares without imposing an area
   quota;
   verifies the accepted R2 housing-result digest
   `4e5676d86ba5226642476751509f78c5152ecbc429a8d1f4bb94e415289f26ec`
   without rerunning the packing portfolio; and compares the direct R4
   housing wrapper with horizontal authority on a bounded canonical corpus:
   all first/last placement witnesses in the 230 accepted `housing_order`
   rows, every mask vertex and bbox centre where each centre axis is
   `floor((minimum + maximum) / 2)`, every 32nd node of the accepted
   R3-common canonical DDA raster of each closed mask edge with dx and dz each
   chosen from `{-51,-50,-1,0,1,50,51}`, the complete 21 by 21 lattice in each mask bbox
   where axis sample `i` is `min + floor(i*(max-min)/20)` for i = 0..20,
   and every coordinate-normalization KAT point;
6. independently reconstructs all registry, graph, travel, anchor and hard
   identities from accepted inputs;
7. compares each sparse nearest query sample with a separate brute-force exact
   oracle and proves the production query never invokes that oracle/catalog
   fallback;
8. verifies R3 terrain, anchor and hard records are passed through without
   horizontal or vertical re-evaluation;
9. mutates every defensive-copy result family and proves later queries are
   unchanged; and
10. runs twice to byte-identical canonical artifact bytes.

The full result requires zero violations, `query_sha256_calls == 0`,
`query_lattice_constructions == 0`, `query_feature_list_constructions == 0`
and `query_unindexed_catalog_scans == 0` for the production API. Construction
counts and index size are evidence, not hidden.

### 12.4 Cross-interpreter and static gates

Long and exhaustive populations run under LuaJIT. Plain PUC 5.1 runs targeted
representative KATs for the four canonical seeds. The LuaJIT and PUC KAT bytes
must be identical in canonical seed order and cover at least:

- positive/negative half ties, safe extrema and malformed coordinates;
- explicit/offline and engine-shaped water level `1`, plus fail-closed
  missing/non-integer/non-`1` water-level cases;
- every water and owner class;
- every territory/PvP branch, including Battlegrounds and y = -700/-701;
- depth/mob/guard boundary arithmetic;
- logical-biome site, cell-edge and distance-tie selection;
- a nearest-route and nearest-hydrology same-distance id/segment tie;
- each hard-protection recipe and an adjacent outside point;
- known/unknown zone, known/absent anchor and both travel directions;
- defensive-copy mutation; and
- disabled engine loader/no-publication behavior.

All changed Lua files, including `tools/wp40`, pass
`tools/bin/luac51 -p`, the SETGLOBAL listing check and all five explicit
Lua-5.1/escape/sandbox sweeps from `docs/research/luanti-lua.md`. The shell
runner passes `bash -n`. Inputs are hashed before and after all worker fleets.

Independent workers may run at idle scheduling priority up to the global
seven-process Lua cap, with immutable inputs, separate scratch/output paths
and deterministic canonical merge. No exhaustive PUC run is scheduled. A
failure leaves only untrusted scratch output and never promotes a partial
artifact.

## 13. Independent review and acceptance

After local gates are green, one fresh independent reviewer reads the complete
contract, accepted R2/R3 contracts/artifacts/reviews, all R4 production/tool
diffs and the canonical R4 artifact. Review checks at minimum:

- no second horizontal, water, height or housing authority;
- exact public signatures, return ownership and nil/error behavior;
- exact 3D policy precedence, particularly capital/ingress/Battlegrounds,
  shelf and y = -700/-701;
- complete logical-biome hash/selection parity, exact 0..99 roll partitions,
  global observed-id coverage and deterministic realized per-zone counts;
- complete path/hydrology/hard index populations and a sound strict nearest
  stopping proof;
- no hidden full-catalog hot-path fallback;
- no active global, adapter, protection hook or map writer;
- no live old-compiler/exact-topology dependency;
- complete artifact inputs without a hash cycle; and
- plain Lua 5.1 compatibility.

Any Critical, High or Medium finding rejects R4. Low findings are fixed or
explicitly dispositioned and rereviewed according to project policy. Only a
green canonical run plus accepted independent review may change this
contract's status to accepted and mark R4 complete. The completion commit also
updates the R4/R5 status in the rebase plan, BACKLOG, ROADMAP and README as
required by repository policy.

## 14. Stop conditions

Implementation stops and returns to contract/design review if it would:

- change an accepted R2/R3 artifact-bound input or result;
- add a second ownership, water, terrain-height, anchor or housing evaluator;
- infer logical biome from engine climate or a foreign zone palette;
- expose a boundary/coast identity or treat geometric contact as adjacency;
- merge boat travel into the land-neighbor/nearest-route graph;
- make deep ocean/channel look like ordinary zone terrain or make ordinary
  Battlegrounds terrain hard-protected;
- derive construction rights from race region or faction alone;
- use depth level as terrain height or alter generic guard level by depth;
- hash, build a lattice/list or scan all sparse features per scalar query;
- silently fall back from the sparse index to a full catalog scan;
- enable a compatibility adapter, global registry or production callback;
- run the retired exact-T2 topology/partition suites as live authority;
- add an exhaustive PUC population; or
- invent an absolute runtime threshold without a measured complete mapchunk
  transaction and separately reviewed justification.

These are contract failures, not opportunities for an implementation-local
approximation.

## 15. Contract review record

### Planning review

The binding §§1-14 contract content was independently reviewed with Claude
Code 2.1.228, Opus at xhigh effort, in a read-only `Read,Grep,Glob` profile.
The final reviewed complete-file SHA before this administrative status/record
addition was
`f3f356b7d8cc7c2898a947a7c140ee8575478b44a36117f1d8b18d18226461c7`.
The final focused verdict was **ACCEPTED**, with 0 Critical, 0 High, 0 Medium
and 0 Low findings and no user decision required.

Review progression:

| Round | Reviewed SHA-256 | Verdict/counts |
|---|---|---|
| Initial | `17b58b16ad7e3bd04b2d435d034944ea859ae9aca0466cc0100e5d09c15f0c56` | rejected; 0C/0H/4M/4L |
| Correction 1 | `246fd6fb4f5dccdfec105e1e99eef2937fe6f88b0cd62c40a9a85d530332af71` | rejected; 0C/0H/1M/3L |
| Correction 2 | `6214d750ad6b23e10ad8e4ba123e866eb4faee21d9ff7f9fb5d201f0c2fd8330` | accepted; 0C/0H/0M/1L |
| Final Low fix | `f3f356b7d8cc7c2898a947a7c140ee8575478b44a36117f1d8b18d18226461c7` | accepted; 0C/0H/0M/0L |

The final Low-fix prompt SHA-256 was
`b41772a2cfce96f40cc4232216488de534d3b0d522b703dd9e4165a63f983a7a` and
the JSONL SHA-256 was
`bd634e848454ba52696a3ceac648af4bec014bcb581b86967115b8e87d0737d5`.
The Claude help SHA-256 was
`71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`;
the process exited 0 with empty stderr. Calibration: Sol implementer, Opus
reviewer, three fix rounds, elapsed time not recorded.

### Implementation review and acceptance

The complete R4 candidate was independently reviewed after the canonical full
run. The reviewed base was
`3a7afc978733be0d16f04ad02073992a5beaea55`. The sorted SHA-256 manifest of
the 16 reviewed contract/design/research, production, tool and artifact files
was
`f090f2da954f50ae83b74b5cf2664156da99b0bddb21659fa36d4cbdafd7ace0`.
The exact pre-closeout `git status --porcelain` snapshot SHA-256 was
`3e49e539793a072965ac436cd235da165e42a945d15f5ff711003d05fc4b87f9`.
The reviewed contract file SHA-256 was
`6f9763b97a230dc875e8b038e21c797b9f0f68d3e5dd86caedb4b67833c2063b`;
this status and review-record addition is administrative and therefore occurs
after that reviewed snapshot.

Before the full run, a fresh focused Opus `xhigh` review accepted the corrected
logical-biome roll-weight semantics and the explicit non-operative treatment
of the two retained R2 share-audit metadata fields. It returned **START** with
0 Critical, 0 High, 0 Medium and one dispositioned Low requiring this later
review-record update. Its immutable evidence was:

- reviewed four-file correction diff SHA-256:
  `96fdf4b7de206997e8fca7f062a98a55ef095c7b249648993bff4559df0f74c6`;
- prompt SHA-256:
  `454fe102ecaab9484b06a7d56ae24186bb2826aced05bf5c8f9a6f3f11aa5b23`;
- JSONL SHA-256:
  `5254bd55c9ee094724eb462a019b5831dd316ad4f5f43365713ea04d642068ea`;
  and
- extracted verdict SHA-256:
  `b69ea262540c76e2e9bb4a0db63c7834791d1bc1dbf5f5628aa2beb1e0bb064a`.

The final implementation review used a second fresh Claude Opus context at
`xhigh` effort through the repository's read-only `Read,Grep,Glob` profile.
It reviewed the complete candidate, the canonical artifact and the successful
full-run log. It returned **ACCEPT** with 0 Critical, 0 High, 0 Medium and
three dispositioned Low findings. Its immutable evidence was:

- prompt SHA-256:
  `78963ceae6f430545fcb072118a37139382397a6f478d4f0656c8367d8d5d0bb`;
- JSONL SHA-256:
  `6b5dc3de749206862e801ac99f9a164b5f337e9bb915bd7da92aa6eb00a695b1`;
- extracted verdict SHA-256:
  `bd67757f881b3a2e1952214870f60b71ab3907022153edd26f99f23a0528f130`;
- CLI-version capture SHA-256:
  `6e530049604112045b613648e16c32a1b32dc006ad76ccac829b476fd2038157`;
- Claude Code version `2.1.228` and help SHA-256
  `71ad650f59e08ae40ede14c534db4f49d8590ee5a4f92f6da2882d3a5560fea6`;
  and
- empty stderr SHA-256
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

The three Low findings are explicitly dispositioned. Two query-cost metrics
are literals rather than independent instruments, but the accepted code has no
corresponding query path and the exhaustive nearest metrics independently
exclude a catalog fallback. Five foundation/T2 negative-test dependencies are
outside the 35-file artifact manifest, but none participates in the private R4
payload and the accepted golden tests bind their observable behavior. One
unused local `sorted_keys` helper has no execution path. Editing any of these
artifact-bound files would invalidate the accepted bytes and require another
full run without changing one produced R4 value, so they are retained as
reviewed. R5/R7 planning carries the separate observation that the complete
42-footprint construction proof needs a measured engine world-load budget.

The canonical full run completed two independent seven-shard LuaJIT scans of
all 49,980,561 columns, produced byte-identical artifacts, compared four
targeted seed shards byte-for-byte between LuaJIT and PUC 5.1, and promoted
only after the immutable input check. Bound evidence:

- artifact body/file SHA-256:
  `bb19948d6bcb2c9976eddc6358955407f8b4a3c4cd54fb7dce1165e22ed8edca` /
  `23a05d2115fb6d3a1b286e09a17847793e23fc0a23817ade8ce8b812875d1b3c`;
- targeted KAT body/file SHA-256:
  `72b9bd0e2d21cb82c4b1627031434eda1b83a2d8b8223fae22eb8f0e377ab5de` /
  `14463a99810351439fdf5d65a02436e367db69df1c2efebaeb8bc1b495a90b39`;
- immutable input-state SHA-256 before/after:
  `7ab21a34a39c01b7b1fb244f46d4685c9fc5f4e3fdba45fdac50c70330109790`;
  and
- full-run log SHA-256:
  `9feeb509897753f52fbf5df5c5752b395f5df32bc0c6db83095e0c9faf59bbd5`.

Calibration: non-trivial deterministic map-generation implementation;
implementing/coordinating model GPT-5.6 Sol with delegated implementation and
audit lanes; reviewing model Claude Opus at `xhigh` effort in fresh read-only
contexts; initial/final Critical and High counts 0/0; final complete-review
counts 0 Critical / 0 High / 0 Medium / 3 dispositioned Low; final-review fix
rounds 0; package elapsed wall time not recorded across sessions; canonical
full runner wall time 3,766 seconds.
