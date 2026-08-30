# WP40 Simple Map R6 Exact Contract

Status: frozen review candidate; no implementation GO until the dedicated
hard-lens and mandatory independent full review both accept it
Contract date: 2026-08-30 (Europe/Berlin)
Branch: `wp40-simple-map-r6`
Accepted base: `e6fe00a4fdf52ad2c10e02128d8b367fda73f662`

## 1. Outcome and boundary

R6 adds the complete deterministic P7 surface, P8 natural-resource and P9
decoration/cultural-slot model to the accepted disabled R5 planner/adapter. It
also freezes the content manifest, the WP33 cultural registration seam and the
32-seed evidence/ledger format. R6 remains disabled, registers no mapgen
callback and writes no world. R7 alone supplies the production context and
activates the one writer after every accepted WP33 cultural registration is
present.

This contract consumes, without reopening:

- the R2 fixed layout, owner grid, 100 anchors, ten housing masks, packing
  witnesses and 24 apex sockets;
- the R3 height, water, hydrology and fixed-payload semantics;
- the R4 logical-biome choice and policy payload; and
- the R5 P2-P6 opcode tuples, conflict rules, replacement matrix, owner
  slices, immutable native inputs and one-transaction adapter.

R6 does not turn R4 weights into quotas, change a selected logical biome,
repair a missing biome, move any anchor, add a second writer, place a
schematic through an engine helper or use callback/blockseed order as random
input. It does not implement WP33 visible cultural sources, ordinary-camp
socket nodes, apex socket nodes, gathering drops or the R7 activation seam.

The accepted decisions in
`docs/research/wp40-simple-map-r6-decisions.md` and the binding target tables in
`docs/design/biomes_mobs.md` section 2.1 and
`docs/design/world_zones.md` section 11 are normative. The preparatory TSV
status columns are historical provenance; a word such as `pending` in one of
those frozen columns cannot reopen an accepted value.

## 2. Frozen inputs and construction

### 2.1 Required input identities

Construction validates the accepted identities recorded in
`docs/research/wp40-simple-map-r6-preflight.md` section 2. In addition, the
implementation contract manifest contains complete-file SHA-256 rows for:

```text
AGENTS.md
docs/design/biomes_mobs.md
docs/design/world.md
docs/design/world_zones.md
docs/design/items_crafting.md
docs/research/luanti-lua.md
docs/research/wp40-simple-map-r6-decisions.md
docs/research/wp40-simple-map-r6-surface-content.tsv
docs/research/wp40-simple-map-r6-decoration-draft.tsv
docs/research/wp40-simple-map-r6-resource-density.tsv
docs/research/wp40-simple-map-r6-cultural-opportunities.tsv
docs/research/wp40-simple-map-r6-seed-corpus.tsv
docs/research/wp43_wp40_handoff.md
mods/ITEMS/grug_materials/registry.lua
mods/ITEMS/grug_nodes/init.lua
mods/ITEMS/grug_trees/init.lua
mods/MAPGEN/grug_mapgen/wp43_handoff.lua
reference_projects/luanti/src/mapgen/mg_schematic.h
reference_projects/luanti/src/mapgen/mg_schematic.cpp
reference_projects/luanti/src/mapnode.cpp
reference_projects/luanti/src/script/lua_api/l_mapgen.cpp
reference_projects/luanti/doc/lua_api.md
mods/BASE/default/schematics/acacia_bush.mts
mods/BASE/default/schematics/acacia_tree.mts
mods/BASE/default/schematics/apple_log.mts
mods/BASE/default/schematics/apple_tree.mts
mods/BASE/default/schematics/aspen_tree.mts
mods/BASE/default/schematics/blueberry_bush.mts
mods/BASE/default/schematics/bush.mts
mods/BASE/default/schematics/emergent_jungle_tree.mts
mods/BASE/default/schematics/jungle_tree.mts
mods/BASE/default/schematics/large_cactus.mts
mods/BASE/default/schematics/papyrus_on_dirt.mts
mods/BASE/default/schematics/pine_bush.mts
mods/BASE/default/schematics/pine_tree.mts
mods/BASE/default/schematics/small_pine_tree.mts
mods/BASE/default/schematics/snowy_pine_tree_from_sapling.mts
```

The implementation artifact records both the reviewed contract-file hash and
those actual final input hashes. A mismatch is `fail_manifest`; it is never
normalized or accepted by regenerating an expected value during the same run.

### 2.2 Exact modules and disabled public status

R6 adds these production modules under `mods/MAPGEN/grug_mapgen/wp40/`:

```text
r6.lua
r6_content.lua
r6_hash.lua
r6_planner.lua
r6_settlement.lua
r6_templates.lua
```

Tool-only witnesses live below `tools/wp40/r6/`. `r6.lua` is a factory, has no
`core` reference at file scope and exposes exactly:

```lua
status() -> "disabled_r6_surface_resource_content"
new(full_seed_string, configured_water_level, manifest_values,
    content_contract, mapgen_context, wp43_projection, template_source,
    cultural_registrations) -> session
cultural_slot_api() -> registration_validator
```

The constructed session exposes exactly `plan_slice`, `apply_fixture`,
`metrics` and `status`. `status()` returns the same disabled scalar.
`template_source` has the exact read-only API `read(filename) -> schematic`
and is called only during construction; production injects the pinned engine
reader and fixtures inject immutable tables. Production callback registration,
a `production` call mode, settings reads and a hidden enable boolean are
forbidden. R6 may construct only the accepted R5 source/planner lineage and
must retain the same opaque construction identity across its planner,
settlement and adapter.

### 2.3 Construction-time validation

Before a session exists, construction:

1. validates the R5 manifest and all accepted R2-R5 identities;
2. copies the WP43 projection through the existing handoff, validates every
   registered stratum/resource identity and converts published decimal deep
   multipliers exactly to `5/4` and `3/2`;
3. validates the closed surface, decoration, resource and cultural catalogs;
4. parses every distinct `.mts` file exactly once, applies each definition's
   replacements to a private copy and freezes the canonical template records;
5. validates all target CIDs, classification properties, param2 modes and the
   ordinary/river water registrations; and
6. seals the counting allocators before any `plan_slice` or fixture apply.

No callback, plan or apply call may register content, parse a schematic, add a
catalog row, grow a retained buffer or consult `core.registered_*` again.

## 3. Hash and integer contract

### 3.1 Canonical frame

All authored R6 randomness is a pure SHA-256 function of the complete seed
string and explicit domain fields. It never converts the seed string to a Lua
number.

`canon(v)` is the raw UTF-8 byte string when `v` is a catalog ID or full seed.
Every SHA-256/digest field, including the accepted R2 layout body digest in
`evidence_cell_rank_v1`, is exact lowercase 64-character ASCII hex. For an
integer it is minimal signed ASCII decimal: zero is `0`, positives have no sign
or leading zero and negatives have one leading `-`. A field frame is
`canon(byte_length) .. ":" .. canon(v)`. The hash input is the concatenation:

```text
frame("grug_wp40_r6_hash_v1")
frame(domain)
frame(full_seed_string)
frame(field_1) ... frame(field_n)
```

Field count and order are fixed by each call site. A missing field, nil/false
substitution, non-integer number, non-minimal numeric text or unlisted domain
is `fail_hash`. Hash bytes compare unsigned lexicographically.

The closed domains are:

```text
resource_budget_remainder_v1
resource_root_rank_v1
resource_frontier_rank_v1
cultural_budget_remainder_v1
cultural_candidate_rank_v1
decoration_budget_remainder_v1
decoration_candidate_rank_v1
decoration_rotation_v1
decoration_simple_height_v1
template_probability_v1
evidence_cell_rank_v1
evidence_substrate_v1
```

The artifact prints this list in unsigned-ASCII order. Reusing a digest across
domains or using one domain with a different field list fails review.

The exact fields after domain and full seed are:

| Domain | Ordered fields |
|---|---|
| `resource_budget_remainder_v1` | resource, cell x/y/z, host, depth tier, deep band |
| `resource_root_rank_v1` | resource, cell x/y/z, host, depth tier, deep band, candidate x/y/z |
| `resource_frontier_rank_v1` | resource, cell x/y/z, host, depth tier, deep band, vein index, candidate x/y/z |
| `cultural_budget_remainder_v1` | cultural key, cell x/z, denominator |
| `cultural_candidate_rank_v1` | cultural key, cell x/z, denominator, candidate x/z |
| `decoration_budget_remainder_v1` | decoration ID, cell x/z |
| `decoration_candidate_rank_v1` | decoration ID, cell x/z, candidate x/z |
| `decoration_rotation_v1` | decoration ID, root x/y/z |
| `decoration_simple_height_v1` | decoration ID, root x/y/z |
| `template_probability_v1` | definition ID, root x/y/z, rotation index 0..3, trial kind, then local y for `slice` or local x/y/z for `node` |
| `evidence_cell_rank_v1` | accepted R2 layout body digest, race ID, lower/frontier bucket, cell x/z; its canonical full-seed field is the exact empty string |
| `evidence_substrate_v1` | candidate x/y/z |

Every rank compares the complete 32-byte digest first and the stated
coordinate tie-break second. There is no digest truncation for ordering.

### 3.2 Digest words and exact modular reduction

Bytes 1..4 and 5..8 of a digest form unsigned big-endian words `hi` and `lo`.
Each is in `0..4294967295` and is exactly representable in Lua doubles. For a
positive integer denominator `q <= 48000`, reduce the first 64 digest bits by:

```text
p = 4294967296 mod q
r = ((hi mod q) * p + (lo mod q)) mod q
```

The largest intermediate is below `48000^2 + 48000`, far below `2^53`.
The trial passes exactly when `r < remainder`. This direct reduction has at
most `q / 2^64 < 2^-48` absolute probability skew for `q <= 48000`; the
implementation and artifact call it bounded finite modulo bias, never perfect
unbiasedness.

Mandatory arithmetic KATs include:

```text
q=512, hi=0, lo=1000                 -> r=488
q=12000, hi=1, lo=0                  -> r=11296
q=12000, hi=0, lo=2147483648         -> r=11648
q=48000, hi=4294967295, lo=4294967295 -> r=15615
```

The last value is independently derived from `(2^64 - 1) mod 48000`.

### 3.3 Exact floor/remainder budget

For an eligible count `E`, density `a/b` and positive multiplier `m/n`, all in
lowest positive integer terms, compute:

```text
numerator   = E * a * m
denominator = b * n
base        = floor(numerator / denominator)
remainder   = numerator - base * denominator
budget      = base + (remainder trial passes and 1 or 0)
```

Catalog fills use `m/n = 1/1`. Resource density uses `a=1`, `b` from the
closed tier table and deep multiplier `1/1`, `5/4` or `3/2`. Current maxima
are `E <= 4096`, `a <= 3`, `m <= 5`, `b <= 12000`, `n <= 4`; construction
proves every intermediate below `2^53`. An input which violates the stated
bounds is `fail_bound`, not a reason to switch to floating point.

## 4. R6 successor representation

### 4.1 Why P7-P9 are refinements

R5 validates and resolves only P2-P6, with lower numeric priority winning.
Appending a P7, P8 or P9 run to that resolver would make it lose beneath the
P5 terrain intent and is forbidden. R6 therefore preserves the R5 base plan
byte-for-byte in a nested handle, then settles reviewed refinements against
the prospective result of that base plan. A refinement can replace only the
explicit predecessor/class row listed below. It never defeats a P2-P4 intent,
never changes P6 water and never adds a last-writer-wins path.

The phase order is:

```text
P2-P6 accepted R5 prospective result
P7 biome material and dust refinement
accepted invisible cultural-reservation occupancy
P8 exact-host natural resources
P9 accepted visible cultural features, templates, simple trunks, ground cover
```

Candidate conflict validation for every phase runs even when an earlier phase
would hide the candidate. Settlement produces at most one final write intent
per voxel.

### 4.2 Public plan handle

`plan_slice(minp,maxp)` returns a generation and one reused exact-field handle
with schema `grug_wp40_r6_refinement_plan_v1`:

```text
schema, construction_identity, generation, valid,
min_x, min_y, min_z, max_x, max_y, max_z,
r5_plan, r5_generation,
column_values, column_count,
candidate_cell_values, candidate_cell_count,
candidate_values, candidate_count,
stable_refs
```

The bounds and identity equal the nested R5 plan exactly. `column_values` is a
dense fixed-stride array in increasing z then x. Its stride 12 is:

```text
water_class_id, zone_numeric_id, logical_biome_ref, race_region_ref,
terrain_y, water_y_or_sentinel, surface_kind_id, top_content_ref,
filler_content_ref, shore_or_bed_content_ref, filler_depth, dust_content_ref
```

`water_y_or_sentinel` uses the exact accepted R5
`native_heightmap_sentinel = -31007`. `surface_kind_id` is dry top `1`, dry
shore `2` or wet bed `3`. Wet means the accepted R5 tuple has a non-nil
`water_y` above `terrain_y`. R6 owns the dry-shore trigger: it means a dry
column whose logical biome is exactly `grug_beach`; every other dry column is
dry top. These sets are total and disjoint. Filler depth is 2 or 3 exactly as
the binding design table states. Dust ref is nonzero only for
`grug_crags_snowy`.

`candidate_cell_values` lists every globally anchored 16-by-16 x/z cell whose
closed extent intersects the central x/z owner or its computed discovery
halo. Its stride 4 is `cell_x, cell_z, first_candidate, after_candidate` and
is ordered cell z then cell x. Negative cells use mathematical
`floor(coordinate/16)`.

The indexed `candidate_values` array has stride 14:

```text
kind_id, catalog_ref, group_parameter,
root_x, root_y, root_z,
rank_word_1, rank_word_2, rank_word_3, rank_word_4,
rank_word_5, rank_word_6, rank_word_7, rank_word_8
```

Kind is cultural `1` or decoration `2`; resources are VM-data-dependent and
use a separate private settlement buffer. `group_parameter` is the cultural
density denominator or decoration class. Rank words are the eight unsigned
big-endian digest words. Within a cell, cultural candidates precede decoration
candidates; cultural order is candidate rank then cultural ID, and decoration
order is class, candidate rank, then decoration ID. The cell's first/after
span indexes exactly this array, and the last cell's `after_candidate` equals
`candidate_count + 1`.

Stable refs are unique nonempty IDs in unsigned-ASCII order. No instance ID is
interned: instance identity is its domain plus coordinates and catalog ID.
The handle and every retained buffer are invalidated before the generation is
advanced and cannot be retained across a later plan call.

### 4.3 Final internal runs

After immutable VM data is read, settlement writes a private successor run
buffer using R5's unchanged nine-cell stride:

```text
y_min, y_max, priority, opcode, role, policy,
feature_ref, interface_ref, aux
```

Columns remain z/x ordered and runs y ordered, disjoint and coalesced only
when all seven semantic fields match. Bounds are 80 runs per column, 512,000
runs per 80-by-80 slice and 4,608,000 scalar cells. Exceeding a bound is fatal
before a setter.

R5 opcode IDs 1..32 never move. The successor admits:

| ID | Token | Priority | Generic role | Policy |
|---:|---|---:|---|---|
| 1 | `BIOME_BED` | 7 | `R6_CONTENT` | `SURFACE_EXACT` |
| 2 | `BIOME_FILLER` | 7 | `R6_CONTENT` | `BIOME_FILLER_EXACT` |
| 3 | `BIOME_SHORE` | 7 | `R6_CONTENT` | `SURFACE_EXACT` |
| 4 | `BIOME_TOP` | 7 | `R6_CONTENT` | `SURFACE_EXACT` |
| 12 | `DECORATION` | 9 | `R6_CONTENT` | `DECORATION_CELL` |
| 24 | `RESOURCE_EXACT_HOST` | 8 | `R6_CONTENT` | `DEEP_EXACT_HOST` |
| 33 | `BIOME_DUST` | 7 | `R6_CONTENT` | `DECORATION_CELL` |
| 34 | `CULTURAL_SOURCE` | 9 | `R6_CONTENT` | `CULTURAL_CELL` |

IDs 33 and 34 are compatibility appendices, not a renewed ASCII ordinal of
the 1..32 R5 vocabulary. R6 adds role ID 17 `R6_CONTENT`, policy ID 8
`DECORATION_CELL`, policy ID 9 `CULTURAL_CELL` and policy ID 10
`BIOME_FILLER_EXACT`; it does not renumber or reinterpret the R5 role/policy
IDs. The two cultural lower-level choices refine policy 9's closed predecessor
set and never create another numeric policy.

For these rows, `aux = (content_ref - 1) * 256 + param2`. `content_ref` is
1..1024 and param2 is 0..255, so aux is 0..262143. Every R5 run still requires
aux zero. `feature_ref` is the catalog resource/decoration/cultural ID;
`interface_ref` is zero for surfaces/resources/simple nodes and the immutable
template ref for template cells. Role, aux and target classification are
validated before VM setters. Every P7 material/dust row has `feature_ref=0`
and `interface_ref=0`.

The injected content contract has schema
`grug_wp40_r6_content_contract_v1` and exactly these fields:

```text
schema, r5, ignore_cid,
ordinary_water_family_id, river_water_family_id,
content_names, content_cids, content_kind_masks,
resolve_r6(content_ref, param2), classify(cid, param2), metrics()
```

`r5` is an exact `grug_wp40_r5_content_contract_v1` table and is passed
unchanged to the nested R5 adapter. Its ignore CID, family IDs and classifier
results must equal the outer values on repeated pure calls. The three content
arrays are dense, have identical length 1..1024, and are ordered by unique
registered node name in unsigned ASCII. `resolve_r6` returns exactly five
scalars:

```text
target_cid, target_kind, param2_mode, param2_value, target_role_mask
```

`target_kind` retains the R5 air `0` / solid `1` / water-source `2` enum;
`param2_mode` is exact `1` and `param2_value` equals the function's second
argument. `target_role_mask` is the separate R6 bitmask below. Repeated calls
must agree on all five scalars.

R6 preserves the R5 old-content class IDs 1..11 exactly and adds no old-content
class. `content_kind_masks` is a separate target-role bitmask: P7 material bit
`1`, dust bit `2`, WP43 resource bit `4`, decoration bit `8`, cultural bit
`16`. A registered node may carry any nonzero combination, so for example
`grug_nodes:mud` can be both P7 material and a post-replacement decoration
cell. Every target validates the required bit without excluding additional
bits. P7 material targets must classify as natural host, natural surface or
WP43 stratum; dust as natural vegetation; P8 as the exact WP43 resource. A
decoration/cultural target must be a registered non-liquid, non-ignore solid
with its respective bit. Authored occupancy is tracked by settlement, not
inferred by changing the CID classifier. No R5 matrix cell becomes
replaceable.

### 4.4 Refined predecessor matrix

The only legal refinements are:

| Phase | Candidate | Required prospective predecessor |
|---|---|---|
| P7 | top/shore/bed/filler | an R5 P5 `TERRAIN_SURFACE` or `TERRAIN_FILL` intent at that voxel; no P2-P4 winner |
| P7 | snow dust | prospective air immediately above an accepted dry `BIOME_TOP`; the only covering lower phase may be ordinary P5 `TERRAIN_CLEAR` |
| P8 | resource | no P2-P7 content change and immutable old CID equals the exact WP43 host for y |
| P9 | cultural | accepted registration-specific predecessor set, always excluding P2-P6 engineering, water, resource, other cultural and decoration output |
| P9 | template/simple | exact accepted P7 support plus registration-specific clearance; no P2-P6 engineering/water, P8 resource, cultural reservation or earlier decoration |

P7 top/shore/bed uses R5 `SURFACE_EXACT` unchanged. The successor-only
`BIOME_FILLER_EXACT` writes natural host/surface/vegetation, native ore,
WP43 resource and WP43 stratum; it no-ops on air and every liquid so a P7
filler does not fill a preserved native cave, and rejects foreign, unknown or
ignore. P8 retains the reserved R5 exact-host behavior:
immutable `CONTENT_IGNORE` rejects the transaction, exact host writes, and
every other old CID is a counted no-op. P9 never uses `force` to bypass an
exclusion.

P7 spans are global analytic spans and clip independently into every vertical
owner exactly like the R5 continuation runs. A P7/P9 predecessor or support
voxel outside the current central owner is evaluated only from the immutable
column scalars and already-settled analytic intents, never by reading the VM
halo. In particular, a dust voxel at the lower row of the slice above its top,
or a decoration root at `minp.y` supported at `minp.y-1`, derives the accepted
P7 support analytically. It never requires the neighboring callback to have
run and never reads a non-lighting old-content byte outside `minp..maxp`.

## 5. Surface and content manifest

### 5.1 Exact P7 spans

For each column, `surface_y` is defined to mean its exact R3/R4 `terrain_y`;
let `T=surface_y` and let `d` be the binding filler depth.
Only voxels whose R5 winner is ordinary P5 terrain are refined:

- at `T`, emit `BIOME_BED` for wet bed, `BIOME_SHORE` for dry shore and
  `BIOME_TOP` otherwise;
- from `T-1` through `T-d` inclusive, emit `BIOME_FILLER`;
- a higher-priority P2-P4 run subtracts its entire overlap before P7
  emission; and
- for snowy crags, emit `BIOME_DUST` at `T+1` only when the column is dry,
  the accepted top was written/equal, no P2-P4/P6 intent covers that voxel and
  the prospective P5-clear target is air.

The shore/bed material is the one value in the design table; no second depth
is inferred from the preparatory TSV. R5 P6 ordinary/river water remains
unchanged and maps respectively to `default:water_source` and
`default:river_water_source`.

### 5.2 Closed surface catalog

The 16 rows and every node/depth value are exactly the table in
`docs/design/biomes_mobs.md` section 2.1. Construction copies them into a
private array ordered by logical-biome ID, validates the set against the R4
logical-biome vocabulary and requires exactly 16. No fallback biome, inherited
engine top, alias, group lookup or missing-content skip exists.

Every named material target must be registered and classify as
`NATURAL_HOST`, `NATURAL_SURFACE` or `WP43_STRATUM` as applicable. Dust must
be `NATURAL_VEGETATION`, all water must be a compatible source and every
target's actual light/param2 properties enter the same transaction audit.

## 6. Natural resources

### 6.1 Closed catalog and eligibility

The resource set is exactly the 15 keys in
`wp40-simple-map-r6-resource-density.tsv`: the eight ordinary universal rows,
three regional G1 rows, three regional G2 rows and universal
`abyssal_crystal`. Construction validates every overlapping node, harvest
tier, scope, regional assignment, density and deep multiplier against the
live WP43 projection. The accepted R6 placement-start tier, density and vein
cap are exact additional inputs; disagreement is `fail_resource_manifest`.

A voxel is an eligible host for resource `r` exactly when all are true:

1. its x/z horizontal class is `land` or zone-owned `planned_water`;
2. its exact zone has a non-nil race region for regional resources and that
   region's WP43 assignment equals `r`; universal resources skip this test;
3. the WP43 depth tier at y is at or above the row's first placement tier and
   that depth-tier density is nonempty;
4. immutable old CID equals `wp43.stratum_node_for(y)` exactly;
5. the prospective P2-P7 result leaves that CID unchanged;
6. it is outside every analytic hard-protected, route, fixed-anchor and
   24-apex-socket volume and every accepted cultural-reservation voxel; and
7. the CID is not `CONTENT_IGNORE`.

`coastal_shelf`, `deep_ocean` and `immutable_dragon_channel` are ineligible.
Native ore, an already placed WP43 resource, water, bed material, a P7 surface,
air and vegetation are not exact hosts. Each eligible position is counted once
in the Section 10.3 census host denominator `H(r,s)` even if several resources
can use it; the Section 6.2 `resource_host` count remains independently
per-resource.
Native dungeon content needs no invented geometric exclusion: the retained R5
Section 10.2 exact-host rule excludes it because a dungeon CID cannot
byte-equal `wp43.stratum_node_for(y)`.

### 6.2 Sub-band key and budget

For every resource, partition immutable eligible hosts by the exact key:

```text
resource_key, cell_x, cell_y, cell_z, exact_host_node,
depth_tier, deep_band
```

Cells are globally anchored 16-cubes using mathematical floor on x/y/z.
`deep_band` is `ordinary` for y >= -1499, `deep_1500_1999` for
-1999..-1500 and `deep_2000_floor` for -31000..-2000. No group crosses a
cell, host, depth-tier or multiplier boundary. Group order is cell z, cell x,
cell y, resource key, host node, tier, deep band; all string comparisons use
unsigned ASCII.

For exact eligible-host count `H`, denominator `D` and multiplier `m/n`, use
Section 3.3 with fields
`resource_key,cell_x,cell_y,cell_z,host,tier,deep_band` for the remainder
digest. The budget `B` must satisfy `0 <= B <= H`; otherwise construction or
settlement fails. No cap is applied after this calculation: the displayed
`max_nodes_per_vein` is a split cap, not a clamp on group budget.

### 6.3 Vein split, roots and growth

If `B=0`, planned vein count is zero. Otherwise, for cap `c`:

```text
v = floor((B + c - 1) / c)
small = floor(B / v)
large_count = B - small * v
target_size(i) = small + (i <= large_count and 1 or 0)
```

Thus targets differ by at most one, sum to B and never exceed c. Original
eligible hosts are ordered by the full `resource_root_rank_v1` digest, then z,
x,y. For vein i, scan that order and choose the first position not already
claimed by any earlier P8 resource/vein. If none exists, record
`rejected_no_root`; do not retry outside the group.

The chosen root is node one. Repeatedly form the deduplicated set of unclaimed
eligible six-neighbors of any node already in this vein, restricted to the
same exact sub-band. Rank each frontier coordinate by
`resource_frontier_rank_v1` with fields group key, vein index, x,y,z, then
z,x,y as tie-break. Add the least member. Stop at target size or an empty
frontier. A short vein records `short_frontier` and its exact missing node
count. Missing nodes are never transferred to a later vein, resource, cell,
band or seed. A vein is an accepted deposit opportunity iff its root is
placed; a short nonempty vein remains one accepted opportunity.

Resource keys settle in unsigned-ASCII order. A host claimed by an earlier
resource is unavailable to a later root/frontier and is counted as
`collision_resource`; there is no per-seed resource-order shuffle.
Every accepted vein is attributed to the exact `race_region` of its root x/z
column; nil remains nil. Growth may reach another race-region column inside
the same 16-cell, but never changes that one deposit-opportunity attribution.

## 7. Cultural opportunity slots

### 7.1 Candidate groups

The six exact cultural rows, biome allowlists and concentrated zone IDs are
those in `docs/design/world_zones.md` section 11. An eligible root column:

- belongs to the row's race region and listed logical biome;
- is dry, has `surface_y >= 1` and has an accepted P7 top/shore support;
- is outside fixed/protected/route/water/apex exclusions; and
- lies in an exact zone. Battlegrounds never receive the concentrated rate.

Group by cultural key, globally anchored x/z cell and density denominator. The
denominator is 1024 only for columns in the row's one concentrated zone and
4096 otherwise; ordinary eligible zones/biomes in the same cell share the
4096 group rather than receiving independent rounding trials. Use Section 3.3
and the cultural remainder domain. Rank group columns by
`cultural_candidate_rank_v1`, then z,x, and take the first B. Those are
candidate slots; later rejection does not select rank B+1.

### 7.2 Reservation settlement

Candidate order is cell z, cell x, candidate rank and cultural key. A candidate
reservation is the centered x-2..x+2, z-2..z+2 square and y
`surface_y-1..surface_y+7`, exactly 225 voxels. It is accepted only if every
voxel is inside the finite authored extent, inside the same 80-cube owner as
the root, available under the fixed exclusions and not reserved by an earlier
cultural candidate. A failure records exactly one primary reason in this
precedence:

```text
clipped_owner, fixed_or_protected, route_or_water, content_ignore,
wrong_support, cultural_collision
```

There is no movement, retry, fallback scan or world mutation. The accepted
reservation blocks every later P8/P9 candidate; the P8 eligibility pass
therefore consumes accepted reservations before resources settle even though
their visible priority is P9.

### 7.3 WP33 registration API

The module-level `cultural_slot_api()` returns an immutable validator with
exactly:

```lua
required_keys() -> copied six-key array
validate(cultural_key, definition) -> canonical_record, sha256
```

It retains no registration state and never writes a repository or world. At
module level it validates only record schema, footprint, simple/template shape
and canonical field bytes; it cannot resolve CIDs. The R6 constructor later
validates every registered record's CID, target-role mask and param2 through
its injected content contract before accepting the zero-or-six record array. A
definition has exact fields:

```text
id, template_or_simple_kind, immutable_content,
footprint_min_x, footprint_max_x,
footprint_min_y, footprint_max_y,
footprint_min_z, footprint_max_z,
lower_two_policy
```

The footprint is relative to the slot root and must be a subset of x/z -2..2
and y -1..7. `lower_two_policy` is exactly `preserve_p7` or
`replace_exact_p7`; WP33's reviewed contract chooses it. The immutable content
uses the same template/simple cell schema as decorations. Construction applies
the same target validation as decorations. The returned record is a private
deep copy and its digest covers every field.

The R6 constructor accepts a dense array of zero or six previously validated
canonical records ordered by cultural key. Any other population, duplicate,
unknown key or digest mismatch fails. R6 fixtures may inject a synthetic
complete six-record array. R6 production status remains disabled with zero
visible `CULTURAL_SOURCE` rows when the array is empty. R7 refuses activation
unless the constructor receives the exact six accepted WP33 record digests.

## 8. Decorations

### 8.1 Closed definitions and classes

The exact definitions, fills, host nodes and special parameters are the
binding table and prose in `docs/design/biomes_mobs.md` section 2.1. Variant
ranges expand to independent definitions: grass 1..5, ordinary fern 1..3,
deep-forest fern 1..3, Elf grass 1..3 and savanna dry grass 1..5. Construction
requires exactly 48 expanded decoration IDs and prints them in unsigned-ASCII
order. Deferred flowers,
boulders, gathering nodes, foods, optional flora, battlefield dressing and
waterholes are absent, not zero-density definitions.

Every definition has one settlement class:

```text
1 emergent_or_large_template
2 ordinary_tree_template
3 simple_multi_node_trunk
4 ground_cover
```

Emergent jungle tree, fallen apple log, large cactus, papyrus and every
template with a rotated x/z span above five belong to class 1; other template
trees/bushes belong to class 2; gravewood belongs to class 3; all single-node
simple definitions belong to class 4. Construction records the computed
classification and fails if a design definition would change class without a
contract revision.

### 8.2 Candidate budgets and order

Group eligible roots only by decoration ID and globally anchored 16-column
cell. `E` counts all columns in that definition's complete logical-biome
allowlist whose accepted P7 support equals the exact host, whose
`surface_y >= 1` and whose special y predicate passes. A definition spanning
two logical biomes does not receive two independent rounding trials. Use
Section 3.3 and the decoration remainder domain. Rank roots by
`decoration_candidate_rank_v1`, then z,x, and take the first B; a rejection
does not select another root.

A preparatory ID ending `_1..N` expands by replacing the complete `1..N`
suffix with each minimal decimal integer from 1 through N. Its node name
expands by the same rule. Thus the 48 final IDs are fully spelled by the 34
literal TSV rows plus that one mechanical rule; no range token enters a hash
or artifact row.

All cultural reservations settle first. Decoration order is class, cell z,
cell x, candidate rank, decoration ID. Every slice discovers the exact halo of
candidate cells whose largest rotated closed footprint could intersect its
central owner. The halo in cells is derived from the frozen templates, offsets
and maximum simple height, rounded up by 16 independently on each face; it is
printed in the artifact and cannot use the old `sidelen=80`.

The root cell is the unique settlement owner. Neighbor cells are read-only
inputs to collision discovery and never settle that root a second time. A
candidate is accepted only when its entire rotated footprint lies inside the
same 80-by-80-by-80 central owner cube as its root. This makes the R5 rule
literal: the one callback writes only its central owner, never the emerged
halo. Owner clipping is a counted rejection and has no retry.

This geometric loss is expected and may be material; it is not a zero-count
gate. In owner-local coordinates, a centred 5-by-5-by-9 cultural reservation
accepts roots only at x/z `2..77` and surface y `1..72`. Thus its geometry alone
excludes 9.75% of uniformly distributed x/z roots, 10% of uniformly distributed
surface-y residues, or 18.775% under an independent uniform combination; the
real artifact reports measured candidate and `clipped_owner` counts and their
exact ratio instead of assuming uniform terrain. Decoration footprints use
their actual parsed and rotated x/y/z bounds; large templates are expected to
show visibly larger owner-clipping counts, and the `template` rows expose the
exact dimensions needed to interpret them.

Because the accepted owner minimum is congruent to zero modulo 16 and
`80=5*16`, every 16-cell nests in exactly one 80-owner. Whole-footprint owner
containment therefore makes neighbor-owner candidates outcome-inert: the
computed discovery halo is retained as diagnostic coverage/proof of the
largest rotated footprint, but settlement never imports or re-settles a root
from another 80-owner.

### 8.3 Immutable templates

Each distinct `.mts` is parsed once at construction through exact
`core.read_schematic(path, {write_yslice_prob = "all"})`. The reader behavior is
pinned by the Luanti source files in Section 2.1. A per-definition deep copy
then applies replacements before validation. The private record contains only:

```text
size_x, size_y, size_z,
y_slice_probabilities,
node_name, probability, param2, force_place for every dense x/y/z cell
```

Bounds are x/z 1..16, y 1..64 and total cells <=16384. Arrays are dense,
metatable-free and unreachable from callers. Exact node name `air` is the sole
manifest-membership exception because such a cell emits nothing; it receives
no content ref and can never be a written target. Every other name must
resolve and occur in the content manifest with the decoration bit; `ignore`,
an unknown node, a forbidden liquid or a missing required bit is fatal.
Rotation-specific coordinates and param2 are materialized once for all four
quarter turns. `facedir`, `wallmounted`, `colorfacedir` and
`colorwallmounted` use fixed lookup tables byte-identical to the pinned engine.
Exact `4dir`, `color4dir`, `degrotate` or `colordegrotate` in any non-air
template cell is `fail_template` rather than an invented partial rotation.
Every other param2 is unchanged. The canonical template digest includes the
post-replacement cells and all four rotations. The lookup-table authority and
the rejected additional rotation kinds are pinned by `src/mapnode.cpp`.

The pinned reader masks the stored node probability with `0x7f`, separates the
stored `0x80` force-place bit into the boolean field and returns probability
multiplied by two. With `write_yslice_prob = "all"`, it likewise returns one
dense ordered y-slice record for every local y. Construction therefore accepts
only even integer node and y-slice probabilities `0,2,...,254`, rejects a
missing/duplicate slice or any other value, and normalizes an absent returned
`force_place` field to false. There is no implicit missing-slice default.

Template node/y-slice probabilities are not delegated to engine randomness.
Returned probability 0 omits, 254 includes and 2..252 includes exactly when
the first digest byte from `template_probability_v1` is below the returned
probability. The slice trial fields end with `slice,local_y`; node trial fields
end with `node,local_x,local_y,local_z`. This is the exact documented `p/256`
trial over the reader's even output domain and has no modulo bias. A template
node is included only when both its y-slice trial and its own node trial include
it.

Rotation index is `floor(first_digest_byte / 64)` from
`decoration_rotation_v1`, mapped exactly 0 to 0 degrees, 1 to 90, 2 to 180 and
3 to 270. Centering and offsets are exactly the design prose:
blueberry/fallen log +1, emergent -4, all other y offsets zero; fallen log is
x-centered only, all other templates are x/z-centered. Silverwood and papyrus
replacements and fallen-log mushroom-to-air replacement are exact.

### 8.4 Simple content

Simple roots start at `surface_y+1`. Gravewood height is
`2 + (first_digest_byte mod 3)` from `decoration_simple_height_v1`; residue 0
has probability 86/256 and residues 1 and 2 each 85/256. This small finite
modulo bias is explicit and stable. Its vertical footprint is the closed
height and every node is the same trunk with param2 zero. Dry shrubs use exact
param2 4. All other simple nodes use param2 zero and height one. Variant
definitions are independent candidates, not one hash-selected variant.

### 8.5 Settlement and replacement

The candidate root support must equal the definition's exact accepted P7 host
after P7 settlement. Every footprint cell is checked in canonical local y,z,x
order after rotation. Template air cells emit nothing. A non-air cell may:

- retain an equal target CID and repair exact param2;
- replace prospective air or natural vegetation when `force_place` is false;
- when the parsed template cell has `force_place = true`, additionally replace
  an exact P7 top/filler cell whose target kind mask contains P7 material; or
- otherwise reject the whole candidate.

No cell may replace P2-P6 engineering/water, P8 resource, a cultural
reservation/source, an earlier decoration, `CONTENT_IGNORE`, foreign/unknown
content or a WP43 resource. All cells and targets are validated before any of
them are committed to the private final-run buffer. Primary rejection reason
precedence is:

```text
clipped_owner, content_ignore, fixed_or_protected, route_or_water,
wrong_host, insufficient_clearance, cultural_collision,
resource_collision, decoration_collision, forbidden_old_class
```

Reason assignment is first-match in that list. `wrong_host` is only root
support mismatch. `insufficient_clearance` owns every non-force footprint cell
whose prospective old content is neither air, natural vegetation nor the
equal target, including ordinary P5 natural solid above/beside a root.
`forbidden_old_class` is reached only for a remaining old-content class which
is not already an earlier exclusion/collision category. Cultural reasons use
the same first-match rule in their displayed order.

There is no partial template, movement, retry, rank refill, fallback search,
`core.place_schematic`, `register_decoration` or second VM writer.
An accepted decoration reserves its complete rotated closed footprint against
later decorations, including template-air and probability-omitted cells; only
included non-air cells emit write intents.

## 9. One transaction and failure boundary

R6 retains R5's complete VM method allowlist, full buffers, central owner,
dirty-column representation, result codes, liquid rules and one-setter limits.
For a nonempty successor plan, exact order is:

1. validate disabled status, fixture call mode, identities, manifest, schemas,
   generation, bounds, nested R5 plan and all catalogs/registrations;
2. validate the emerged area and heightmap exactly as R5;
3. read data and param2 once each;
4. derive the immutable prospective P2-P6 result and P7 refinements without
   mutation;
5. settle cultural reservations, then P8 and P9 into private bounded buffers,
   validating every candidate, target, old class, collision and ledger total;
6. perform a second read-only replay which proves the private final runs and
   every canonical ledger agree with the same immutable input;
7. derive dirty content/param2/liquid sets;
8. if light relevant, call `get_light_data` before deriving the final light
   seed plan, then validate that plan;
9. after no semantic failure remains possible, replay final runs into the
   retained data/param2 buffers;
10. use at most one data setter, one param2 setter, the one R5 light
    transaction and at most one liquid update; and
11. return an existing interned R5 result code and release all borrowed input.

The Task-C correction is binding: only semantic validation against a
conforming VM is promised before setters. A defensive failure caused by a VM
method throwing or returning malformed post-setter data can occur later and is
`fail_vm_contract`; it is not described as rollback. `get_light_data` always
precedes final light seed-plan derivation.

New failure prefixes are `fail_hash`, `fail_resource_manifest`,
`fail_content_manifest`, `fail_template`, `fail_settlement`,
`fail_cultural_registration` and `fail_ledger`. Every old R5 prefix retains
its meaning. Evidence records only the prefix before the first colon.

## 10. Canonical ledgers and parity

### 10.1 Row encoding

The artifact is UTF-8 TSV with LF endings, no BOM, one header and rows ordered
by `row_type` then each type's keys below. Text is length-safe: tab, LF, CR and
NUL are forbidden in scalar fields. Integers are minimal decimal; booleans are
`true`/`false`; ratios are `numerator/denominator` in lowest positive terms.
The artifact body hash excludes only the final `artifact_body_sha256` row; the
file hash includes it.

### 10.2 Required row families

The closed families are:

```text
identity, input_sha256, vocabulary, content, template,
fixed_projection, seed, census_cell, substrate_class, surface_coverage,
resource_host, resource_budget, resource_vein, resource_node, region_host,
cultural_candidate, cultural_slot,
decoration_candidate, decoration_settlement,
region_denominator, region_opportunity, region_parity,
access, rejection, allocation_metric, vm_metric, kat, gate
```

Every artifact uses this one exact header:

```text
row_type k1 k2 k3 k4 k5 k6 k7 k8 k9 k10 v1 v2 v3 v4 v5 v6 v7 v8 v9 v10 v11 v12
```

The displayed spaces stand for TSV separators. Unused key/value cells are the
empty string. Data rows sort by unsigned-ASCII byte order over
`row_type,k1..k10`;
duplicate key tuples within one family fail. The following table closes the
key tuple, payload tuple and aggregation of every family. Names in parentheses
are the meanings of consecutive cells, not extra serialized labels.

| Family | Key tuple `k1..` | Payload tuple `v1..` | One row per |
|---|---|---|---|
| `identity` | name | value | identity scalar |
| `input_sha256` | repository path | sha256, byte count | frozen input file |
| `vocabulary` | vocabulary kind, numeric ID | exact name | vocabulary entry |
| `content` | content ref | node name, CID, target-role bitmask | content entry |
| `template` | template ref, definition ID, rotation index | digest, size x, size y, size z, dense cell count | post-replacement rotated template |
| `fixed_projection` | projection name | body sha256, file sha256, population | projected R2/R3/R4/R5 authority |
| `seed` | seed slot | label, full seed string, derivation, source digest | fixed corpus entry |
| `census_cell` | race ID, bucket, cell z, cell x | rank digest, zone ID, level min, level max | selected x/z cell |
| `substrate_class` | seed slot, race ID, bucket, cell z, cell x, cell y, substrate class | voxel count, canonical digest | class in one census cube |
| `surface_coverage` | seed slot, zone ID, logical-biome ID, status | column count | occurring pair or `catalog_zero` pair |
| `resource_host` | seed slot, race ID, resource key, cell z, cell x, cell y, host node, depth tier, deep band | eligible H | exact Section 6.2 sub-band |
| `resource_budget` | same as `resource_host` | numerator, denominator, floor budget, remainder, remainder digest | exact Section 6.2 sub-band |
| `resource_vein` | same as `resource_host` | planned veins, accepted veins, collision count, shortfall | exact Section 6.2 sub-band aggregate, never one row per vein |
| `resource_node` | same as `resource_host` | target nodes, placed nodes | exact Section 6.2 sub-band aggregate, never one row per node |
| `region_host` | seed slot, race ID, cell z, cell x, cell y, depth tier, deep band | union eligible H | one census sub-band, counted once across resources |
| `cultural_candidate` | seed slot, cultural key, rate class | eligible columns, budget, ranked candidates | whole horizontal population aggregate |
| `cultural_slot` | seed slot, cultural key, rate class | accepted slots, reserved voxels | whole horizontal population aggregate, never one row per slot |
| `decoration_candidate` | seed slot, definition ID, settlement class | eligible columns, budget, ranked candidates | whole horizontal population aggregate |
| `decoration_settlement` | seed slot, definition ID, settlement class | accepted instances, emitted nodes, reserved cells | whole horizontal population aggregate, never one row per instance |
| `region_denominator` | race ID | census hosts | 32-seed race aggregate |
| `region_opportunity` | race ID | accepted census veins, ordinary-camp sockets, camp-equality pass | 32-seed race aggregate; the two opportunity kinds remain separate |
| `region_parity` | lowest-rate race ID, highest-rate race ID | low natural veins, low census hosts, high natural veins, high census hosts, left product, right product, pass | one six-race sampled-natural extrema comparison |
| `access` | access gate ID, race/faction/island ID, resource/cultural key, witness discriminator | pass, seed slot, zone ID, root x, root y, root z, route/socket witness ID | required witness or explicit failed witness |
| `rejection` | seed slot, subsystem, catalog ID, primary reason | count | horizontal population or resource census aggregate |
| `allocation_metric` | run ID, phase, metric name | observed value, accepted ceiling, pass | measured allocation metric |
| `vm_metric` | run ID, phase, metric name | observed value, accepted ceiling, pass | measured VM/runtime metric |
| `kat` | engine ID, KAT ID | input digest, output digest, pass | one KAT result |
| `gate` | gate ID | pass, detail digest | mandatory gate |

`rate class` is exact `ordinary` or `concentrated`; a cultural key has both
rows even when one is zero. Every catalog row required by the table is
materialized, including zeros. The artifact contains no per-column, per-voxel,
per-candidate, per-vein, per-node, per-slot or per-decoration-instance row.
At most 900,000 data rows and 512 MiB including the header and trailer are
accepted; either bound being exceeded is `fail_ledger`. After every data row
has been sorted, the trailer is appended and takes no part in that sort. This
last line has
`row_type=artifact_body_sha256`, empty `k1..k10`, the lowercase digest in
`v1` and empty `v2..v12`; it is excluded from the body hash and no other
trailer row exists.

For `access`, the witness discriminator is exact `ordinary` or `concentrated`
for cultural witnesses, socket ordinal `1` or `2` for island-apex witnesses,
and the empty string otherwise. The island ID occupies k2 for island-apex rows.
The complete k1..k4 tuple is the uniqueness key, so all 12 cultural and all 24
island-apex witnesses remain independently representable.

The closed `gate` IDs, and no others, are:

```text
input_manifest, vocabulary_manifest, p7_p9_schema_fixture,
r2_r5_projection, complete_ledgers,
region_natural_density_parity, ordinary_camp_equality,
access_native_region, access_opposing_frontier,
access_deep_cross_border, access_island_apex, access_cultural,
content_coverage, apex_nonoverlap, fixed_housing_projection,
allocation_bounds, disabled_single_writer, static_gates,
micro_kat_parity, not_owned_not_evaluated
```

Construction requires exactly one row for every ID and rejects any missing,
duplicate or unknown gate before computing the trailer.

Resource rows report exact H, budget, planned veins, accepted veins, target
nodes, placed nodes, collision count and shortfall for every sub-band.
Cultural/decoration rows report eligible E, budget, candidates, accepted,
every primary rejection count and placed node count. A zero denominator,
missing catalog row, missing rejection bucket or aggregate/detail mismatch is
`fail_ledger`, never an omitted row.

`surface_coverage` has one row for every actually occurring
`seed,logical_biome,zone` pair and a separate catalog-zero row for an allowed
pair with no occurrence. It may not claim that a positive R4 biome weight must
occur.

R6 exports the accepted fixed R2 housing portfolio/capacity and 24 apex socket
identities by digest projection once. Every seed row references those exact
digests and proves no R6 operation overlaps an apex socket. R6 does not rerun
the fixed packing proof per seed.

### 10.3 Census host denominator and separate parity gates

For race region r and seed s, `H(r,s)` counts each exact Section 11.2
resource-census voxel that satisfies every Section 6.1 eligibility condition
for at least one of r's counted resources. It is counted exactly once
regardless of how many counted resources can use it. The counted set is all
universal resources plus r's assigned G1 and G2. `V_r` counts an accepted
census vein only under the root-region attribution in Section 6.3.

Across exactly 32 seeds:

```text
H_r = sum_s H(r,s)
V_r = sum accepted census veins of counted resources in r
natural_rate_r = V_r / H_r
C_r = 32 * 12 = 384 ordinary-camp sockets
```

Each `region_host` row is the exact per-seed/per-race/per-census-sub-band union
count implementing `H(r,s)`. Each `region_denominator` row equals the exact sum
of that race's `region_host` payloads across all 32 seeds. It is never computed
by summing the per-resource `resource_host` rows.

Every H_r must be positive. Compare natural rates only by exact cross
multiplication. Select `lo` and `hi` by natural rate, breaking an exact tie by
race ID. Natural-density acceptance is:

```text
20 * V_hi * H_lo <= 21 * V_lo * H_hi
```

The exact census below gives `H_r <= 8,388,608`. Global P8 occupancy gives
`V_r <= H_r`; the largest comparison side is therefore bounded by
`21 * 8,388,608 * 8,388,608 = 1,477,743,627,730,944 < 2^53`. The
implementation proves those same bounds dynamically. If a proof fails, the
ledger fails rather than using float division or a mean-relative tolerance.

Camp equality is separate and exact: all six `C_r` values must equal 384.
`C_r` never enters the census natural-rate numerator or denominator. The
census proves sampled per-host natural-vein density, not whole-world native-v7
accessible volume; the equal camp gate proves the approved renewable-socket
quantity without mixing populations. Apex sockets enter neither gate. Placed
natural nodes are reported separately and never substitute for accepted
veins.

The corresponding mandatory `gate` IDs are exactly
`region_natural_density_parity` and `ordinary_camp_equality`. The first hashes
all `region_host` rows, the six `region_denominator`, six `region_opportunity`
and one `region_parity` row. The second hashes the `input_sha256` rows for
`docs/design/world.md` and
`docs/design/world_zones.md` plus the six `region_opportunity` rows. Each race
row derives `C_r = 32 corpus seeds * 1 ordinary camp * 12 sockets = 384` from
those exact design authorities. It proves the frozen equal budget, not a
not-yet-implemented WP13/WP34 socket-identity roster.

The paired leather/cloth/silk/feather/herb/spice/reagent ledger contains zero
R6-owned opportunity rows and an explicit `not_owned_not_evaluated` gate. Zero
is not reported as a ±10% pass.

## 11. Evidence and interpreter schedule

### 11.1 Fixed corpus

The implementation first updates the executable seed corpus to the exact 32
ordered strings in `wp40-simple-map-r6-seed-corpus.tsv`, including values
above `2^53` as strings. It removes the old exact-T2 slot-28..32 rules and
requires `#fixed == 32`. Corpus file, in-memory sequence and artifact seed rows
must be byte-identical in order and text.

### 11.2 Exact evidence populations

The long R6 evidence has two distinct populations. Neither is silently read as
a full 3D census of the 49,980,561-column world.

The **horizontal population** scans every integer x/z in the accepted R4 query
bounds x `-3740..3740`, z `-3340..3340` for each of the 32 seeds: exactly
49,980,561 columns per seed and 1,599,377,952 column evaluations total. It owns
surface coverage, cultural candidates/reservations and decoration
candidates/settlement. Its canonical surface fixture begins with the exact
WP43 stratum below the analytic R3 surface and air above, then applies the
accepted R5 P2-P6 prospective result and R6 refinements. Native-cave,
foreign/ignore and malformed-VM behavior remain targeted VM KATs rather than
invented surface-population frequencies. Horizontal artifact rows are
aggregates by seed, zone, logical biome and catalog ID; no per-column row is
written.

The **resource census** is exactly bounded. For each of the six race regions,
enumerate every global 16-by-16 x/z cell wholly inside the R4 query bounds for
which all 256 columns:

- have that same non-nil race region;
- lie in one and the same exact zone and have admitted `land` or zone-owned
  `planned_water` horizontal class; and
- avoid every analytic fixed/protected/route/apex x/z exclusion.

Split candidates into `lower` when the exact zone has `level_max <= 30` and
`frontier` when it has `level_min >= 31`; any other interval is a manifest
error. Rank each bucket by the complete SHA-256 digest of canonical frames
domain `evidence_cell_rank_v1`, accepted R2 layout body digest, race ID,
bucket, cell x and cell z, then cell z/x. Select exactly the first four cells
from each bucket. Fewer than four fails. The roster is therefore exactly eight
x/z cells per race region, 48 total, seed-independent and printed in
`census_cell` rows.

Cross every selected x/z cell with these exact eight global cell-y values:

```text
-4, -13, -26, -38, -53, -78, -100, -188
```

Their 16-node spans respectively sample depth tiers T1, T2, T3, T4, T5,
ordinary T6, T6 y -1500..-1999 and T6 y <= -2000 without crossing a listed
tier/deep boundary. This is exactly 384 16-cubes and 1,572,864 voxels per seed,
50,331,648 voxel classifications across 32 seeds. It is the sole population
used for `H_r`, `V_r`, placed-node density and the strict sampled-natural
parity comparison. Ordinary-camp equality is derived from the frozen Section
10.3 design-authority budget and does not use this census denominator.

The resource census uses a closed, native-compatible **evidence substrate
proxy**, not an unstated v7 world. For each census voxel, hash domain
`evidence_substrate_v1` with full seed and x, y, z. First digest byte
0..15 yields fixture AIR, 16 yields fixture NATIVE_ORE, 17 yields compatible
fixture LIQUID and 18..255 yields the exact WP43 stratum at y. Param2 and all
class/light properties are fixed by the fixture manifest. P2-P7 analytic
effects and every real exclusion are then applied before host eligibility.
The artifact reports each substrate class count and digest. This population
proves deterministic density/settlement/parity arithmetic against varying
immutable substrate; it does not claim to reproduce native v7 cave/ore/dungeon
statistics. Actual native-v7/headless and fresh-world validation remains the
already assigned R8 release/runtime gate after R7 activation.

The practical `access` ledger is closed as follows:

- `native_region` requires accepted G1 and G2 roots for every race in its own
  eight-cell census;
- `opposing_frontier` requires Ruby in at least one Throng frontier census
  cell reachable in the fixed route graph from an Accord start, and Sapphire
  in at least one Accord frontier cell reachable from a Throng start;
- `deep_cross_border` requires each faction's opposing assigned G2 at y <=
  -701 in an opposing race-region census cell whose accepted territory rule is
  contested at that y;
- `island_apex` projects the fixed proof that each island has two reachable,
  diggable sockets for all six gems and proves no R6 overlap; and
- `cultural` requires at least one accepted ordinary and one accepted
  concentrated slot for each of the six keys in the full horizontal
  population.

Every row carries its fixed route/zone/root/socket witness IDs. A missing
witness is a failed gate, not an omitted family.

### 11.3 Development and final runs

Before the 32-seed fleet, one mandatory scratch-only cost pilot runs seed slot
1 over the complete horizontal population and its complete 48-cell/eight-depth
resource census. It uses seven deterministic balanced shards, the final worker
code and immutable inputs under `chrt --idle 0` and `ionice -c3`; its
deterministic combine must match a targeted single-process digest before its
timing is accepted. The pilot records wall seconds, summed user seconds, peak
RSS per worker, scratch bytes, combined-row count and combined bytes. Because
the final fleet's busiest worker executes five whole seeds while the pilot
shards one seed seven ways, it conservatively projects full-fleet wall time as
`pilot_wall_seconds * 35`. It projects summed CPU time and scratch bytes by
factor 32, fleet peak RSS per worker as `pilot_peak_rss * 7`, and final artifact
bytes from the pilot's exact aggregate row sizes plus the closed 32-seed
multiplication. Those measurements and projections enter
`vm_metric`/`allocation_metric` rows.

The pilot is an unconditional stop boundary: its coordinator turn ends after
reporting the measured and projected cost. The 32-seed fleet requires explicit
user approval of that projection and cannot start in the pilot invocation.
Changing the population or accepting an estimate derived from partial pilot
bytes requires a reviewed contract revision.

LuaJIT owns all exhaustive fixed-layout, full VM and 32-seed runs. The 32
seeds execute as an immutable seven-worker fleet under `chrt --idle 0` and
`ionice -c3`; six workers receive five seeds and one receives two according to
contiguous slot ranges 1-5, 6-10, 11-15, 16-20, 21-25, 26-30, 31-32. Each
worker writes only its own scratch directory. A single deterministic combine
step verifies hashes, rejects duplicate/missing slots and orders canonical
rows. Seven is the workstation-wide cap across agents and packages, not an R6
entitlement when another Lua process is active.

After final Lua bytes freeze, exactly one compact micro-KAT fixture runs once
under LuaJIT and once under `tools/bin/lua51`. It covers negative cells, all
three deep bands, remainder denominators 512/12000/48000, a short vein, a
resource collision, all P7 opcodes including dust, one cultural reservation,
all four decoration classes, all rotations, owner clipping, ignore, lighting
and liquid dirtiness. Canonical bytes and SHA-256 must match exactly. Any final
Lua-byte change replaces both runs.

Every Lua change also receives `tools/bin/luac51 -p`, the changed-mod
`SETGLOBAL` check, all five repository sweeps and explicit checks for Lua under
`tools/wp40/r6/`. The final independent reviewer verifies promoted immutable
logs/artifacts/hashes and the PUC/LuaJIT pair; it does not duplicate the long
fleet.

### 11.4 Mandatory gates

Acceptance requires:

- exact frozen input and vocabulary hashes;
- complete P7-P9 schema/fixture coverage and zero unknown records;
- R2-R5 projection parity and no changed P2-P6 plan/run;
- complete 32-seed surface/resource/cultural/decoration ledgers;
- strict six-race sampled-natural density parity, exact 384-socket equality for
  every race and separate node counts;
- all five practical `access` witness gates;
- exact content coverage or explicit catalog-zero rows;
- no overlap with 24 apex sockets and exact fixed housing projection;
- bounded allocator metrics with zero hotpath growth;
- no mapgen callback, production mode, schematic/decoration/ore registration
  or second writer; and
- clean static gates plus the final byte-identical micro-KAT pair.

## 12. Review, deliverables and stop conditions

The exact R6 contract is reviewed in this order:

1. a dedicated read-only hard-lens of hash arithmetic, P7-P9 representation,
   owner/halo semantics, resource settlement, cultural reservations, template
   expansion and ledger denominators;
2. correction of every substantiated finding;
3. a mandatory independent full contract review under
   `docs/process/agent-model-policy.md`; and
4. correction and fresh review of every affected finding until accepted.

Only then may R6 Lua implementation begin. The implementation, artifact,
review record and promoted logs are one coherent milestone commit. R6's
completion message still ends with a later post-merge runtime plan, while
actual production world/GUI evidence remains R8-owned.

Stop and return to contract review if implementation would need to:

- reinterpret or renumber any R5 opcode/role/policy;
- change R2-R4 geometry, height, logical biome or selected zone;
- place a P7-P9 candidate through the R5 base conflict resolver;
- use floating-point probability/parity arithmetic or a new hash domain;
- write outside the central owner, retry a rejected candidate or refill a
  short resource vein;
- enlarge a cultural reservation or decide WP33 lower-two replacement;
- read a new registry/configuration value after construction;
- add another content transaction or engine placement helper; or
- activate a production callback before R7.
