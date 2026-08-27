# WP40 simple-map R5 typed-planner and disabled-adapter contract

**Draft status (2026-08-27): contract draft only. R4 is still an unaccepted
implementation, artifact and review candidate. This draft creates no accepted
authority, supersedes no artifact or status, activates no map writer and records
no review verdict. Every placeholder in Section 3 must be replaced from the
accepted R4 completion record before R5 implementation begins.**

This contract defines R5 of the simple-map rebase: one pure, bounded typed
planner and one disabled consolidated VoxelManip adapter over native mapgen v7.
It consumes the accepted R2 horizontal and R3 vertical authorities and, after
R4 acceptance, one private scalar seam backed by the exact same R4 horizontal
and height sessions. It does not reopen geometry, ownership, height, crossing,
anchor or logical-biome selection.

The binding game rules remain in `docs/design/world_zones.md`. The mapgen and
engine evidence remains in `docs/research/mapgen-control.md`, the R5 scope in
`docs/research/wp40-simple-map-rebase-plan.md`, and the architectural priority
in `docs/research/wp40-engineering-brief.md`. This document freezes the smaller
implementation boundary needed to turn those decisions into a reviewable R5
candidate.

## 1. Outcome and non-goals

R5 owns exactly four results:

1. a private allocation-free scalar seam from the one future accepted R4
   session pair;
2. a bounded canonical column/Y-run plan for operation priorities 1 through 6;
3. one engine-shaped VoxelManip transaction that can apply such a plan when a
   complete semantic content contract is injected; and
4. immutable evidence for lineage, bounded construction, operation ordering,
   owner slices, native preservation, `CONTENT_IGNORE`, lighting, liquids and
   disabled production state.

R5 does not:

- alter R2 or R3 inputs, results, public APIs or artifacts;
- alter the public R4 session API, public R4 canonical KAT bytes, public R4
  disabled reason or public R4 loader behavior;
- expose a global, compatibility adapter, protection hook or mapgen callback;
- install a mapgen script or change a setting, `game.conf` or production
  configuration;
- map logical biomes to final nodes, place authored resources or decorations,
  or decide their content probabilities;
- interpret authored biome `share` values as realized-area quotas or consume
  them as planner input;
- run a second ownership, geometry, height, route, hydrology or boundary
  evaluator;
- provide CSG, arbitrary voxel programs, repair searches, flood fills,
  post-transaction healing or per-voxel Lua operation objects;
- remove a legacy writer or migrate a consumer; or
- claim a Luanti runtime world, visual result or production cutover.

Operation families 7 through 9 are reserved tokens in the closed schema only.
R5 emits exactly zero such operations. R6 supplies their content-owned
producers and mappings. R7 alone performs the atomic writer and consumer
cutover.

There is no absolute runtime threshold in R5. Construction counts, peak record
counts, logical allocation counts, full-buffer sizes, elapsed measurements,
host and interpreter are recorded. Any future binding timing limit requires a
measured whole-mapchunk budget and a documented derivation.

## 2. Authority and fixed inputs

### 2.1 Accepted R2 and R3 inputs

R5 retains the accepted simple-map authorities:

- R2 artifact body SHA-256
  `1a819192fa40254aa6da1ebf5f3fa5286790ef907abe09750455e5e24c881a8b`;
- R2 complete-file SHA-256
  `ba6e684b232e963251c3582e521c46a9364d602256eba9b6115bd0575e4c9c4b`;
- R3 artifact body SHA-256
  `09b4ac762b9e6dc7d088d5f39c306d0dc80b9769d3bf8b6c35ea8a8a6bc282d2`;
- R3 complete-file SHA-256
  `c1090c5a9169c9fe449ad1b0f560b9a5b5b4a486c744445083ee05fbaa219e65`;
- source schema `grug_wp40_simple_map_source_v2`;
- horizontal schema `grug_wp40_simple_map_v1`;
- height schema `grug_wp40_simple_map_height_v1`;
- layout id `wp40-simple-map-v1d`; and
- source revision `wp40-simple-map-v1e`.

The accepted production input hashes remain exactly those embedded in the R2
and R3 artifacts. In particular, R5 must not edit:

| Input | Accepted SHA-256 |
|---|---|
| `mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua` | `5d4e2726dabbb900e47e7a8bef2a225011e6b003f48de485f752cde88fc7c17f` |
| `mods/MAPGEN/grug_mapgen/wp40/simple_map.lua` | `55e507a6e5b2d73bf23233d9ab5e515ad150dbce77c6dc6c158a6133f4e27dfc` |
| `mods/MAPGEN/grug_mapgen/wp40/height.lua` | `f69fcd006af40f2f473d592c412508c3d7043403b15c07bfedcb311fe6faee97` |
| `mods/MAPGEN/grug_mapgen/wp40/schemas.lua` | `1f3825d1b77972637c850fad32a56a3a0fe08962b14b6c1b107846b7b0004166` |

R2 remains the sole horizontal authority. R3 remains the sole terrain, water,
functional-surface and transition-height authority. The R5 planner samples
those results; it never reconstructs a source polyline, polygon, raster run,
height lattice, water mask or fitting envelope.

### 2.2 Required future accepted R4 biome semantics

R4 remains an unaccepted candidate while this draft is written. R5 may begin
only after the accepted R4 completion record has bound all of these semantics:

- each authored logical-biome `share` is an exact weight in the unbiased
  integer palette roll `0..99`, and the positive shares for one zone sum to
  exactly 100;
- cumulative source order partitions those 100 roll values exactly, with no
  gap, overlap or foreign palette value;
- a positive weight does not promise realized presence or a realized surface
  percentage for any particular zone or seed;
- `biome_at(x,z)` is the sole authoritative logical-biome value for one
  column; and
- the accepted R4 gate covers all 16 logical-biome IDs globally, while its
  realized seed-zero per-zone counts and percentages are evidence only.

R5 binds only the resulting `biome_at(x,z)` scalar. Authored `share`, palette
weights, roll values and cumulative partitions are not fields of the R5
planner-source, plan or content contract. R5 performs no quota check, minimum-
presence check, redistribution, reroll or missing-biome repair. It neither
recomputes the R4 roll nor substitutes another allowed value from the same
zone. Resource and faction parity remains a binding R6 audit, not an R5
planner rule.

### 2.3 Pinned engine facts

The local Luanti reference commit is
`df04879066de6eb94ca43996822a6dfacc74feca`. R5 binds these verified facts:

- v7 finishes terrain, biomes, caves, ores, dungeons, decorations and native
  lighting before the mapgen-environment Lua callback;
- that callback receives the live mapgen VoxelManip and central `minp`/`maxp`
  before the final engine blit;
- a callback error cancels generation rather than accepting a deliberately
  partial result;
- `get_data`/`set_data` cover the complete emerged array, while
  `CONTENT_IGNORE` is the Lua representation of no data and is not written;
- `set_data` changes content but not param2 or light;
- mapgen VoxelManip forbids explicit `read_from_map` and `write_to_map`;
- `calc_lighting` propagates sunlight through the requested range and spreads
  light through the emerged VM; and
- mapgen `update_liquids` appends to the current emerge liquid queue.

R5 may use no engine behavior inconsistent with those pinned sources. An
engine-pin change stops the package and requires focused source reverification.

### 2.4 Exact R5 constants

```text
R5_SCHEMA                         grug_wp40_simple_map_r5_v1
R5_STATUS_SCHEMA                  grug_wp40_simple_map_r5_status_v1
R5_PLANNER_SOURCE_SCHEMA          grug_wp40_r5_planner_source_v1
R5_PLAN_SCHEMA                    grug_wp40_r5_column_run_plan_v1
R5_CONTENT_CONTRACT_SCHEMA        grug_wp40_r5_content_contract_v1
R5_MANIFEST_SCHEMA                grug_wp40_r5_mapgen_manifest_v1
R5_ARTIFACT_SCHEMA                grug_wp40_simple_map_r5_artifact_v1
project_water_level               1
chunksize                         5
max_central_axis_nodes            80
max_central_columns               6400
broad_content_y_min               -37
ordinary_shell_down               16
ordinary_shell_up                 16
functional_headroom_nodes         4
hydrology_bed_seal_layers         3
hydrology_bank_seal_nodes         2
causeway_culvert_radius_squared   1
max_candidate_runs_per_column     16
max_resolved_runs_per_column      31
run_stride                        9
max_stable_refs                   512
force_native_dungeon              false
emerge_threads                    1
```

`emerge_threads` is the canonical manifest field. It maps to the engine
setting `num_emerge_threads`, whose canonical decimal value must be exactly
`1`. R5 validates this offline and never writes the setting.

The ordinary rewrite shell is one exact 16-node band below the R3 terrain/bed
and above the higher of that terrain/bed or its non-nil R3 water surface,
clipped at `broad_content_y_min`. Named interface envelopes may own the
additional exact runs in Section 8; no generic operation may escape that
shell.

Changing a schema, a bound, the shell, any mask, an opcode, a priority, a
replace policy or the meaning of a result is a reviewed R5 contract change.

## 3. R4 lineage and acyclic supersession

### 3.1 Mandatory unresolved R4 placeholders

R4 is not accepted when this draft is written. These tokens are deliberate
placeholders, not values to infer from the current working tree:

```text
<R4_ACCEPTED_IMPLEMENTATION_COMMIT>
<R4_ACCEPTED_ARTIFACT_BODY_SHA256>
<R4_ACCEPTED_ARTIFACT_FILE_SHA256>
<R4_ACCEPTED_PUBLIC_KAT_SHA256>
<R4_ACCEPTED_REVIEW_FILE_SHA256>
<R4_ACCEPTED_REVIEW_VERDICT_SHA256>
```

Before any R5 implementation edit, one contract-only preflight change replaces
all six tokens with values copied from the accepted R4 completion record. That
change does not alter R4, declare R5 accepted or update project status. A
literal `<R4_` token in this contract or an R5 tool is a fail-closed gate.

### 3.2 Three distinct lineage facts

R5 keeps three concepts separate:

1. **Historical R4 acceptance.** The accepted R4 artifact at
   `docs/research/wp40-simple-map-r4-artifact.tsv`, its body/file digests, its
   accepted review and the Git tree at
   `<R4_ACCEPTED_IMPLEMENTATION_COMMIT>` remain immutable historical evidence.
2. **Public R4 semantics.** The exact public session fields, signatures,
   error/nil behavior, defensive ownership, public `canonical_kat()` bytes and
   public disabled-loader behavior must remain byte-identical after the R5
   private seam is added.
3. **Current R5 implementation bytes.** Because R5 may extend `zones.lua` and
   mechanically refactor `index128.lua` for the shared scalar nearest seam in
   Section 5.3, the accepted R4 artifact's historical `input_sha256` rows for
   those files are not current-checkout hashes. The new R5 artifact binds both
   modified files and every R5 production/tool input as the current
   implementation-byte set.

R5 never edits or regenerates the accepted R4 artifact to make its historical
input rows match new bytes. It never calls a historical R4 artifact invalid
merely because a documented R5 successor changes a bound implementation file.

### 3.3 Historical preflight

The R5 runner performs these steps in order before loading current executable
WP40 source:

1. require a clean, full 64-hex replacement for every Section 3.1 digest and a
   full 40-hex implementation commit;
2. hash the accepted R4 artifact file and body and compare the two accepted
   placeholders;
3. hash the accepted R4 review file and its extracted canonical verdict and
   compare the review placeholders;
4. use Git object reads, never checkout mutation, to hash every historical R4
   artifact `input_sha256` path at
   `<R4_ACCEPTED_IMPLEMENTATION_COMMIT>` and compare the embedded row;
5. create an isolated read-only historical R4 KAT input tree from that commit,
   run only the bounded R4 public canonical KAT path, verify
   `<R4_ACCEPTED_PUBLIC_KAT_SHA256>`, and retain its exact byte string in the
   runner's private scratch output;
6. verify the current R2 and R3 artifact body/file hashes and all their current
   checkout input rows; and only then
7. hash the current R5 contract and every current production/tool input before
   any current `dofile`.

The historical tree is evidence input only. Current R5 never loads a mixture
of historical and current modules into one session.

### 3.4 Public parity and current-byte successor

The unaccepted R4 candidate presents this exact expected session field
allowlist:

```text
get
at
neighbors
travel_links
anchor
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
nearest_route_at
nearest_hydrology_at
housing_eligible_at
canonical_kat
canonical_kat_digest
artifact_evidence
metrics
compatibility
```

The exact expected `compatibility` subfield allowlist is
`surface_level_at`, `mob_level_at`, `guard_level_at`, `open_sea_at`,
`difficulty_at`, `territory_at`, `zone_at` and
`world_protected_for_faction`. This list is planned interface authority, not an
acceptance statement. If final R4 acceptance differs, R5 does not silently
adjust its parity test: this contract must be amended and reviewed before its
placeholders are resolved.

After current preflight, the runner constructs the modified current session
through both `zones_module.new` and the public side of
`zones_module.new_with_planner_source`. For every canonical seed it requires:

- the two current public KAT byte strings are identical;
- those bytes are byte-identical to the historical accepted R4 KAT string;
- their SHA-256 equals `<R4_ACCEPTED_PUBLIC_KAT_SHA256>`;
- the exact public field allowlist is unchanged;
- public return ownership and malformed-input errors are unchanged; and
- normal loader evidence retains the exact disabled reason and no-publication
  result in Section 4.1.

The R5 artifact records the historical R4 artifact body/file hashes and public
KAT digest as parent evidence. It separately records current hashes for
`zones.lua`, the unchanged public loader, all new R5 modules and all R5 tools.

On R5 acceptance, the R5 artifact becomes the current-byte preflight authority
for the files it binds. The R4 artifact remains the accepted historical and
public-semantic parent. This is implementation-byte succession, not a rewrite
or rejection of R4's accepted meaning.

### 3.5 Artifact DAG

The lineage is strictly acyclic:

```text
accepted R2 artifact ----+
                         |
accepted R3 artifact ----+--> frozen R5 contract
                         |          |
accepted R4 artifact ----+          v
accepted R4 review ------+--> R5 implementation + tools
accepted R4 Git tree ----+          |
                                    v
                         R5 canonical artifact
                                    |
                                    v
                         independent R5 review
                                    |
                                    v
                         acceptance/status closeout
```

The frozen contract may be an `input_sha256` of the R5 artifact. The R5
artifact never lists itself, its later review, a later status edit or an
acceptance commit as an input. The review cites the contract and artifact
hashes but is not retroactively inserted into either. Status closeout cites
the accepted review and does not regenerate the artifact. This ordering
prevents every hash and authority cycle.

## 4. Modules, construction and disabled status

### 4.1 Public R4 loader remains byte-identical

R5 does not edit `mods/MAPGEN/grug_mapgen/wp40/init.lua`. In particular these
public bytes remain exact:

```text
enabled = false
disabled_reason = "WP40 R4 payload is validated but not published until R7"
```

The expected public foundation field allowlist is exactly `enabled`,
`disabled_reason`, `schemas`, `canonical`, `deterministic`, `validation`,
`index128`, `seed_corpus`, `raw_sha256_from_core`, `new_session` and
`new_engine_session`. Final R4 acceptance must confirm it; the same
contract-amendment rule in Section 3.4 applies if it differs.

The public loader retains the exact future accepted R4 fields and behavior.
R5 does not append an R5 status, planner, adapter or constructor to that
foundation table. Its public KAT and loader fixtures compare raw expected
bytes, not only a semantic boolean.

### 4.2 New production modules

R5 adds only:

```text
mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua
mods/MAPGEN/grug_mapgen/wp40/planner.lua
mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua
mods/MAPGEN/grug_mapgen/wp40/r5.lua
```

`r5.lua` is an explicitly loaded internal factory. Normal
`mods/MAPGEN/grug_mapgen/init.lua` and the public WP40 loader do not load it.
It returns no global and registers no callback.

Its exact internal status accessor is:

```lua
r5_module.status() -> {
    schema = "grug_wp40_simple_map_r5_status_v1",
    planner_available = true,
    adapter_available = true,
    production_enabled = false,
    callback_registered = false,
    disabled_reason =
        "WP40 R5 planner and adapter are internal and disabled until R7",
}
```

Every call returns a defensive table. Those bytes are R5-internal evidence and
do not replace, annotate or reinterpret the public R4 disabled reason.

### 4.3 Exact factories

```lua
local r5_module = dofile(directory .. "/r5.lua")({
    zones_factory = dofile(directory .. "/zones.lua"),
    planner_factory = dofile(directory .. "/planner.lua"),
    adapter_factory = dofile(directory .. "/map_adapter.lua"),
    manifest_module = dofile(directory .. "/mapgen_manifest.lua"),
    -- the same accepted dependencies used by the R4 factory
    source = source,
    schemas = schemas,
    canonical = canonical,
    deterministic = deterministic,
    index128 = index128,
    horizontal_factory = horizontal_factory,
    height_factory = height_factory,
    raw_sha256 = raw_sha256,
})

local session, planner_source, planner, adapter =
    r5_module.new(full_seed_string, configured_water_level,
        manifest_values, content_contract)
```

The dependency allowlist is exact. Missing, extra-authoritative or
schema-incompatible dependencies fail construction. The content contract may
be the R5 fixture contract only in offline/engine-shaped tests. There is no
production content contract in R5; ordinary construction without one fails
closed before a plan or VM read.

Construction creates exactly one horizontal session and passes that same
session to exactly one height session. The public session and private planner
source close over that same pair. The planner source must not create, receive
or lazily construct another evaluator.

Construction also builds one immutable relational lookup from the accepted
`source.hydrology_interfaces` rows. Each non-nil `route_interface_id` maps to
exactly one `hydrology_id`; every transition ID maps to its declared
upper/lower reaches and their already-registered profiles. Duplicate/conflicting
keys, an unknown crossing/reach/profile or an incomplete lower-face relation
fail construction. This lookup relates already-accepted stable IDs; it
evaluates no geometry and is bound by a canonical digest in the R5 artifact.

## 5. Private R4 planner-source seam

### 5.1 Module API

R5 may change `mods/MAPGEN/grug_mapgen/wp40/zones.lua` only to share the
existing constructor and add this module-level private seam:

```text
zones_module.new(full_seed_string, configured_water_level)
  -> exact public R4 session

zones_module.new_with_planner_source(full_seed_string, configured_water_level)
  -> exact public R4 session, private planner source
```

`new` and `new_with_planner_source` call one common constructor. The latter
does not call `new`, reconstruct a height session or reopen source tables. The
public session returned by both calls has the exact R4 field allowlist; the
planner source is a second private return value only.

### 5.2 Exact scalar API

The private source has exactly these fields:

```text
schema
column_values_at(x, z)
hydrology_metric_values_at(x, z)
metrics()
```

`schema` is the immutable string `grug_wp40_r5_planner_source_v1`.

`column_values_at(x,z)` returns, in this exact order:

```text
water_class,
zone_numeric_id,
zone_id,
logical_biome_id,
race_region_id,
terrain_y,
water_y,
functional_kind,
functional_y,
functional_feature_id,
functional_interface_id,
transition_kind,
transition_interface_id,
transition_upper_y,
transition_lower_y,
transition_progress_q,
transition_face_mask,
hard_foundation
```

It returns eighteen scalar values and allocates no table or string. IDs are
existing interned source strings or nil; no per-column string is constructed.
For every accepted query, `logical_biome_id` is byte-for-byte the value from
the same public R4 session's `biome_at(x,z)` call. The seam does not receive or
derive `share`, a palette roll or a replacement biome, and the planner may not
change this scalar because of another column, zone population or seed
population. This is the complete R5 logical-biome pass-through; R5 emits no
biome material operation.
`hard_foundation` is exactly whether the already-constructed R4 hard index
contains `{x=x,y=terrain_y,z=z}`. It is a boolean derived from accepted policy,
not a new envelope evaluator.

`hydrology_metric_values_at(x,z)` returns:

```text
hydrology_id, source_segment, distance_numerator, distance_denominator,
profile_id, profile_depth, bed_seal_layers, bank_seal_nodes
```

The metric query reuses the R4 sparse hydrology index and existing source row.
It exposes no point arrays, polylines, mutable source row, index bucket or
floating `distance_squared`. Nil identity returns all nil values. Numerator
and positive denominator are safe integers and retain the accepted exact
rational comparison.

`metrics()` returns a defensive table binding construction counts and proving:

```text
horizontal_session_count = 1
height_session_count = 1
planner_source_count = 1
query_table_allocations = 0
query_sha256_calls = 0
query_lattice_constructions = 0
query_feature_list_constructions = 0
query_unindexed_catalog_scans = 0
```

The source owns no mutation method. It is internal to `r5.lua`, planner tools
and later R6/R7 implementation; it is not published through `grug_zones`.

### 5.3 Shared allocation-free nearest seam

R5 may refactor `mods/MAPGEN/grug_mapgen/wp40/index128.lua` only to put the
existing sparse-nearest loop behind one private core and add:

```text
index128.nearest_segment_values(compiled, x, z, scratch)
  -> feature_id, feature_order, segment,
     distance_numerator, distance_denominator,
     rings_scanned, cells_scanned, candidates_scanned
```

`scratch` is one construction-owned dense seen-generation array plus scalar
state. The query clears it by advancing a safe generation counter, with a
bounded full reset before counter overflow. It allocates no table, closure or
result object. The existing `index128.nearest_segment` calls the same core and
builds its existing defensive result table, preserving the future accepted R4
public return bytes and metrics exactly.

The refactor may not duplicate point/segment distance, ring traversal, stopping
or tie logic. `zones.lua` uses the scalar seam only for its private hydrology
tuple. Exact public R4 KAT parity and dedicated scalar-versus-public nearest
KATs gate the change. No other `index128.lua` behavior is in R5 scope.

## 6. Bounded canonical planner representation

### 6.1 No operation object per voxel

The exact planner API is:

```text
planner_module.new(planner_source, validated_manifest, counting_allocator)
  -> planner

planner:plan_slice(minp, maxp)
  -> ephemeral plan handle

planner:metrics()
  -> defensive scalar metrics table
```

`planner_module.new` validates the complete source/manifest/allocator
allowlists before retaining them. `plan_slice` accepts finite safe-integer
inclusive bounds, requires positive axis lengths within the limits below and
does not accept a VM, node registry, CID table, native heightmap or blockseed.

The planner never constructs `{x=..., y=..., z=..., ...}` tables for voxels or
runs. It represents the central owner slice as row-major x/z columns and
inclusive Y runs in reusable flat numeric arrays.

For production manifest chunksize 5, `x_count == 80` and `z_count == 80`.
Small offline fixtures may use positive axis counts no greater than 80; an
`engine_fixture` requires the production dimensions. In every case:

```text
x_count = maxp.x - minp.x + 1
z_count = maxp.z - minp.z + 1
column_count = x_count * z_count
column_index = (z - minp.z) * x_count + (x - minp.x) + 1
1 <= column_index <= column_count <= 6400
```

The plan object is a retained internal handle with:

```text
schema              immutable schema string
generation          monotonically increasing safe integer
minp/maxp            six validated scalar fields
column_start         flat numeric array, logical length column_count + 1
run_values           flat numeric array
run_count            scalar
stable_refs          construction-owned immutable id array
metrics              construction-owned scalar counters
```

`column_start[i]` is the one-based run ordinal of column `i`; the sentinel at
`column_start[column_count + 1]` is `run_count + 1`. A run uses exactly nine
consecutive safe integers:

```text
1  y_min
2  y_max
3  priority
4  opcode
5  target_role_id
6  replace_policy_id
7  feature_ref
8  interface_ref
9  aux
```

X and Z are derived from the owning column and are not repeated. `feature_ref`
and `interface_ref` are zero for nil or indexes into one construction-owned,
lexicographically sorted stable-reference array. `aux = 0` means no param2 or
operation-specific scalar. No run owns a nested table.

The handle is valid only until the same planner begins another `plan_slice`
call. The adapter checks object identity and `generation`; retaining a stale
plan is an error. This permits storage reuse without mutable plan aliasing
across calls.

### 6.2 Exact bounded construction

Planner construction allocates and retains all array tables. `plan_slice`
clears logical lengths and reuses them. It allocates no Lua table, source list,
candidate object or per-column object.

For one column, operation families append at most sixteen candidate runs into
a fixed scratch area:

| Contributor | Maximum candidate runs |
|---|---:|
| hard foundation | 3 |
| exactly one interface or path kind | 5 |
| base terrain/shell | 3 |
| hydrology, seal and explicit water | 5 |
| **Total** | **16** |

Candidate interval endpoints are sorted in a fixed 32-entry scalar scratch
array. At most 31 nonempty elementary intervals result. Each interval selects
one winner under Section 7, and adjacent equal winners coalesce. Therefore:

```text
candidate_runs <= 16 * 6400 = 102400
resolved_runs <= 31 * 6400 = 198400
run_values cells <= 9 * 198400 = 1785600
```

Candidates are resolved one column at a time; 102,400 candidate records are
never retained together. Only the 16-run scratch and final flat run buffer
coexist. A bound breach fails construction before VM access.

The stable-reference array is limited to 512 accepted source IDs. Construction
sorts and interns them once. Query-time interning, concatenated IDs and a
per-chunk source-table copy are forbidden.

### 6.3 Allocation and peak metrics

All deliberate planner/adapter table creation goes through an injected
counting allocator used by production and tools. It may allocate only during
`r5_module.new` or first retained-buffer growth. The same code path records:

```text
construction_table_allocations
construction_array_tables
construction_map_tables
retained_numeric_capacity
stable_ref_count
plan_slice_table_allocations
peak_candidate_runs_per_column
peak_resolved_runs_per_column
peak_resolved_runs_per_slice
peak_run_value_cells
plan_buffer_growth_events
plan_buffer_reuse_calls
```

Acceptance requires:

- `plan_slice_table_allocations == 0`;
- at most 24 retained array tables and 8 retained map tables;
- no candidate/run/voxel table allocation;
- the mathematical bounds in Section 6.2;
- a second equal-or-smaller plan after warm-up causes zero buffer growth; and
- the artifact binds actual seed-zero and worst-fixture peaks.

These are logical allocations made by the implementation, not claims about
undocumented Lua allocator bytes. Peak RSS and elapsed time are unbound
measurements with host/interpreter provenance.

### 6.4 Canonical plan order

Columns are always emitted by increasing absolute Z, then increasing absolute
X. Runs within one column are increasing `y_min`. Equal-start candidates use:

```text
priority, opcode, target_role_id, replace_policy_id,
feature_ref, interface_ref, aux, y_max
```

as a lexicographic diagnostic order. Winner selection still follows Section
7.3 and never uses incidental insertion order. Canonical evidence encodes
absolute x/z and all nine run fields as length-prefixed/signed canonical
scalars; Lua table iteration order is irrelevant.

## 7. Closed operation schema

### 7.1 Priority and opcode families

Lower priority number wins:

| Priority | Family | R5 opcodes |
|---:|---|---|
| 1 | native/foreign preservation | implicit adapter veto; no stored write run |
| 2 | fixed hard foundations | `FOUNDATION_FILL`, `FOUNDATION_SURFACE`, `FOUNDATION_CLEAR` |
| 3 | interfaces and engineering | `BRIDGE_DECK`, `BRIDGE_SUPPORT`, `BRIDGE_CLEAR`, `FORD_BED`, `CAUSEWAY_FILL`, `CAUSEWAY_SURFACE`, `CAUSEWAY_CULVERT`, `TUNNEL_FLOOR`, `TUNNEL_LUMEN`, `TUNNEL_WALL`, `TUNNEL_ROOF`, `HYDROLOGY_BED_SEAL`, `HYDROLOGY_BANK_SEAL` |
| 4 | typed paths | `PATH_FILL`, `PATH_SURFACE`, `PATH_CLEAR` |
| 5 | base terrain/shell | `TERRAIN_FILL`, `TERRAIN_SURFACE`, `TERRAIN_CLEAR` |
| 6 | explicit water | `ORDINARY_WATER`, `RIVER_WATER`, `RECEIVER_OPEN` |
| 7 | biome surface material | reserved: `BIOME_TOP`, `BIOME_FILLER`, `BIOME_SHORE`, `BIOME_BED` |
| 8 | resources | reserved: `RESOURCE_EXACT_HOST` |
| 9 | decorations | reserved: `DECORATION` |

The implementation owns one numeric constant per token. For the complete
opcode vocabulary in this table, numeric opcode is the one-based ordinal after
strict unsigned-ASCII byte sorting of the unique token strings. Target-role
and replace-policy IDs use the same rule within their respective complete
vocabularies. The artifact prints every derived `id -> token` row. Numbers,
names and priorities are therefore exact and never inferred from Lua table
iteration order.

### 7.2 R5 emission boundary for families 7 through 9

R5's planner must report all of these as exact zero:

```text
priority_7_emitted_runs = 0
priority_8_emitted_runs = 0
priority_9_emitted_runs = 0
```

The R5 content contract contains no production role mapping for those
opcodes. If an R5 plan contains one, if a fixture omits its explicitly injected
test role, or if any plan references an unknown role, the adapter fails before
`get_data`. There is no skip-unmapped behavior.

The names and family positions are reserved, but
`grug_wp40_r5_column_run_plan_v1` accepts only P2-P6 stored runs. P7-P9 are not
valid unmapped records in an R5 plan. R6 must define a reviewed successor plan
schema and exact overlay/host semantics before it can emit a reserved opcode;
it may not silently reinterpret an R5 opcode, role, conflict or replace
policy.

Priority 7 reserves typed material intents only; it does not reserve, accept
or encode a biome `share`, quota, roll, realized-area target or repair opcode.
The sole R5 biome datum is the private scalar `logical_biome_id` in Section
5.2, unchanged from R4 `biome_at(x,z)`. Consequently an R5 planner cannot emit
an allowed-but-different palette value, require a positive-weight biome to
occur, redistribute columns, reroll a column or repair a missing biome. R6 may
map that exact scalar to reviewed node/CID roles, but may not change the R4
selection while doing so.

### 7.3 Conflicts

For every elementary Y interval in one column:

1. implicit priority-1 Preservation runs first in the adapter and may veto the
   selected write;
2. the lowest numeric planned priority wins;
3. two candidates at the same priority are identical only when opcode, target
   role, replace policy, feature ref, interface ref and aux are all equal;
4. identical candidates coalesce; and
5. any non-identical same-priority overlap is a construction error.

Stable IDs order diagnostics but never break a semantic conflict. There is no
last-writer-wins rule, callback-order rule or arbitrary `force` bit.

### 7.4 Semantic target roles

R5 opcodes reference semantic roles, never registered node names or CIDs. The
closed R5 fixture vocabulary is:

```text
AIR
STRATUM_AT_Y
FOUNDATION_CORE
FOUNDATION_SURFACE
PATH_CORE
PATH_SURFACE
BRIDGE_DECK
BRIDGE_SUPPORT
FORD_SURFACE
CAUSEWAY_CORE
CAUSEWAY_SURFACE
TUNNEL_FLOOR
TUNNEL_WALL
HYDROLOGY_SEAL
ORDINARY_WATER_SOURCE
RIVER_WATER_SOURCE
```

`STRATUM_AT_Y` is a semantic provider call keyed by integer Y, not a node name
inside the planner. R5 tools inject a complete deterministic fixture mapping.
R5 production supplies none. R6 later binds final registered content and
validates every role and property before activation.

### 7.5 Replace policies

The numeric replace-policy vocabulary is:

| Policy | Handled old classes | Rule |
|---|---|---|
| `FILL_VOID` | air, compatible liquid, natural vegetation, natural host/surface, WP43 stratum, native ore, WP43 resource | Writes void/vegetation; handled solid is retained as a no-op; foreign/unknown reject |
| `CUT_NATURAL` | air, natural host/surface, natural vegetation, WP43 stratum, incidental surface liquid | Air is a no-op; other handled classes write AIR; native ore/WP43 resource/foreign/unknown reject |
| `SURFACE_EXACT` | air, compatible liquid, natural host/surface, natural vegetation, WP43 stratum | Writes the exact surface role; native ore/WP43 resource/foreign/unknown reject |
| `SEAL_VOID` | air, compatible liquid, natural host/surface, WP43 stratum, native ore, WP43 resource | Writes void/liquid; handled solid is retained as a no-op; foreign/unknown reject |
| `WRITE_WATER` | air, compatible source/flowing liquid, natural host/surface, natural vegetation, WP43 stratum | Writes the exact water-source role inside an accepted water envelope; native ore/WP43 resource/foreign/unknown reject |
| `OPEN_ENGINEERED` | air, natural host/surface, natural vegetation, WP43 stratum, compatible liquid | Air is a no-op; other handled classes write AIR inside an exact interface envelope; native ore/WP43 resource/foreign/unknown reject |
| `DEEP_EXACT_HOST` | exact final registered stratum host for Y | Reserved for R6 priority 8; every other class is `non_host` no-op |

An old CID already equal to the resolved target CID is always a successful
no-op before class policy is considered. `ignore` is never an allowed class.
An unknown CID is `unknown`, not natural. Native generic ore and a registered
WP43 resource are never replaced by ordinary terrain, but may remain as an
explicit successful supporting-solid no-op under `FILL_VOID`/`SEAL_VOID`.
A foreign/protected or unknown node is never such a no-op. A rejected class
aborts the whole transaction.

The content contract resolves each CID to exactly one class and supplies its
liquid family, `floodable`, `paramtype`, `light_propagates`,
`sunlight_propagates` and `light_source` properties. Missing or contradictory
classification is fatal before mutation.

### 7.6 Exact content-contract seam

The injected content contract has exactly these fields:

```text
schema
ignore_cid
resolve(role_id, y, aux)
classify(cid)
metrics()
```

`schema` equals `grug_wp40_r5_content_contract_v1`; `ignore_cid` is the exact
engine/fixture `CONTENT_IGNORE` integer. `resolve` returns this scalar tuple:

```text
target_cid, param2_mode, param2_value
```

`param2_mode` is `0` for preserve or `1` for exact. Exact mode requires an
integer byte `0..255`; preserve mode requires nil `param2_value`.
`classify(cid)` returns:

```text
class_id, liquid_family_id, liquid_kind, liquid_level,
floodable, paramtype_light, light_propagates,
sunlight_propagates, light_source
```

`liquid_kind` is the closed integer enum none/source/flowing. Liquid family
zero means none; positive IDs are contract-interned families. Booleans are
actual booleans and `light_source` is an integer `0..14`. Both queries allocate
no table or string.

The closed content classes, again numbered by strict unsigned-ASCII byte
ordinal, are:

```text
AIR
FOREIGN
IGNORE
LIQUID
NATIVE_ORE
NATURAL_HOST
NATURAL_SURFACE
NATURAL_VEGETATION
UNKNOWN
WP43_RESOURCE
WP43_STRATUM
```

`liquid_kind` uses exact numeric values none `0`, source `1`, flowing `2`.
`IGNORE` is accepted only as the classification of `ignore_cid` and is never a
replace-policy input.

Where registered groups overlap, classification uses this exact strongest-
first precedence:

```text
IGNORE > FOREIGN > WP43_RESOURCE > NATIVE_ORE > WP43_STRATUM >
LIQUID > NATURAL_VEGETATION > NATURAL_SURFACE > NATURAL_HOST >
AIR > UNKNOWN
```

The content-contract constructor rejects contradictions that are not one of
the explicitly expected registered-group overlaps. Native dungeon provenance
is absent from this vocabulary and is never inferred by classification.

Before `get_data`, the adapter resolves and classifies every unique planned
`(role_id,y,aux)` target through reused flat scratch arrays. Any nil result,
unknown role, unknown target CID, inconsistent param2 tuple or missing target
property fails there. Old native CIDs are classified after `get_data`; a
missing old-CID classification remains fatal before the first setter.

`metrics()` returns defensive construction/query counters. R5 fixture
contracts must report zero query table allocations. R5 has no Production
instance of this contract; R6 owns the registered-node-backed implementation.

## 8. Exact column and interface masks

### 8.1 Common column facts

For each absolute `(x,z)`, let:

```text
T  = terrain_y
W  = water_y, possibly nil
K  = functional_kind, possibly nil
F  = functional_y, possibly nil
C  = W when W is non-nil; otherwise the maximum non-nil transition
     upper/lower datum, possibly nil
```

from the private planner source. `T` is always the R3 ground/bed scalar. R3
already folds solid land grades, anchor platforms, causeways and fords into
`T`. A bridge deck and tunnel floor remain exceptional `F` values with the R3
meaning.

Let `surface_cap = max(T, C)` when C is non-nil and `surface_cap = T`
otherwise. The ordinary shell is:

```text
shell_low  = max(-37, T - 16)
shell_high = surface_cap + 16
```

Global runs are clipped to the current vertical owner slice. The slice that
owns `shell_low` examines `shell_low - 1`; the slice that owns `shell_high`
examines `shell_high + 1`. Intermediate slices examine the one-node halo on
each side of their clipped run. Every required guard must lie in the emerged
area and be non-ignore; the algorithm never widens ownership to obtain it.

The lower guard must be a known supporting solid or a preserved solid
ore/resource/stratum. Air or liquid proves that the requested fill exceeds
the contracted shell and rejects. The upper guard must satisfy the final
analytic model: normally air/removable vegetation, or an explicitly planned
higher-priority named operation at that coordinate. A remaining unplanned
solid or liquid proves that the requested cut exceeds the shell and rejects.
Named bridge/tunnel operations use their exact guards below and do not relax
this ordinary check.

### 8.2 Base terrain

Every R5 surface column emits:

```text
TERRAIN_FILL     shell_low .. T-1   STRATUM_AT_Y   FILL_VOID
TERRAIN_SURFACE  T .. T             STRATUM_AT_Y   SURFACE_EXACT
TERRAIN_CLEAR    surface_cap+1 .. shell_high  AIR  CUT_NATURAL
```

The clear interval is omitted when empty. `SURFACE_EXACT` owns the exact
solid-versus-void branches for the one surface node, so the plan still carries
one run and one policy rather than duplicate candidates.

Unchanged eligible solid nodes below `T` remain their native CID, including a
registered stratum or native ore. Air, compatible surface liquid and natural
vegetation holes inside the owned fill interval receive `STRATUM_AT_Y`.
Consequently R5 seals only caves intersecting the exact shell and preserves
every byte below it.

Above `T`, only known natural terrain, vegetation and incidental surface
liquid may be cut. Encountering native ore, a registered resource, foreign,
unknown or `ignore` rejects rather than leaving a contradictory protrusion.

### 8.3 Hard foundations

When `hard_foundation` is true and `K == "anchor_platform"`, priority 2
replaces the corresponding base runs over the same shell:

```text
FOUNDATION_FILL     shell_low .. T-1  FOUNDATION_CORE     FILL_VOID
FOUNDATION_SURFACE  T .. T            FOUNDATION_SURFACE  SURFACE_EXACT
FOUNDATION_CLEAR    T+1 .. T+4        AIR                 CUT_NATURAL
```

R5 does not turn an arbitrary hard-protected column into construction. The
operation requires R3's `anchor_platform` fact. Ingresses and hard policy
volumes with varying route surfaces remain P4 path columns, not flat P2 pads.

An `anchor_platform` that is not hard-protected uses the same geometric mask
at P4 with `PATH_CORE`/`PATH_SURFACE`; the public protection decision remains
unchanged.

### 8.4 Typed land paths

For `K == "land_grade"`, and for a non-hard mutable `anchor_platform`:

```text
PATH_FILL     shell_low .. T-1  PATH_CORE     FILL_VOID
PATH_SURFACE  T .. T            PATH_SURFACE  SURFACE_EXACT
PATH_CLEAR    T+1 .. T+4        AIR           CUT_NATURAL
```

The R3 functional footprint already equals the winning visible path surface.
R5 neither expands it to the corridor width nor reconstructs the route axis.
Outside that footprint only P5 terrain applies.

### 8.5 Ford

For `K == "ford"`, non-nil `W` and `F == T` are required. R5 emits:

```text
FORD_BED  T .. T  FORD_SURFACE  SURFACE_EXACT
```

P5 supplies the supporting fill and clear shell. P6 supplies named river
water for `T+1..W`; R3 requires the exact centre pin `T == W-1` and may return
the already-frozen graded approach elsewhere. No flat ford slab, new ramp or
route-wide water exception is added.

### 8.6 Bridge

For `K == "bridge_deck"`, R3 `T` remains the bed and `F` is the deck. Require
non-nil `C` and `F >= C + 4` exactly as R3 proved. Emit:

```text
BRIDGE_CLEAR    max(T+1, C+1) .. F-2  AIR             OPEN_ENGINEERED
BRIDGE_SUPPORT  F-1 .. F-1            BRIDGE_SUPPORT  SEAL_VOID
BRIDGE_DECK     F .. F                 BRIDGE_DECK     SURFACE_EXACT
BRIDGE_CLEAR    F+1 .. F+4             AIR             CUT_NATURAL
```

An empty clear interval is omitted. The one-node complete underside across
the already-frozen visible deck footprint is the exact R5 support mask. R5
adds no pier-spacing rule, axis reconstruction or water-blocking support
column. The underside leaves at least two clear nodes above the local
clearance datum because the deck minimum is four.

P5 continues to own the bed and P6 continues to own water through `W`.
The slice owning `F+4` additionally validates `F+5` as air/removable
vegetation or another explicitly planned higher-priority result. An unplanned
solid, liquid, unknown or ignore node there rejects instead of extending the
bridge clearance.

### 8.7 Causeway and culvert

For `K == "causeway"`, non-nil `C`, `F == T` and `T >= C + 1` are required.
P5 creates the solid causeway and P3 assigns its surface role:

```text
CAUSEWAY_FILL     shell_low .. T-1  CAUSEWAY_CORE     FILL_VOID
CAUSEWAY_SURFACE  T .. T            CAUSEWAY_SURFACE  SURFACE_EXACT
PATH_CLEAR        T+1 .. T+4        AIR               CUT_NATURAL
```

The displayed fill interval is the non-culvert case. The exact culvert-column
replacement below narrows it to `W+1..T-1`; an empty narrowed interval is
omitted.

A causeway column is an exact culvert column if all are true:

- its functional interface has exactly one accepted
  `source.hydrology_interfaces` row whose `route_interface_id` equals the
  functional interface ID, and the current hydrology identity equals that
  row's `hydrology_id`;
- its exact hydrology metric denominator is positive;
- `distance_numerator <= distance_denominator`, meaning squared distance no
  greater than one node from that accepted hydrology centreline; and
- its bed `B = W - profile_depth` and `W` are non-nil with `B < W`.

For those columns, P3 replaces the causeway fill over:

```text
CAUSEWAY_CULVERT  B+1 .. W  RIVER_WATER_SOURCE  WRITE_WATER
```

The P3 engineering run wins over the overlapping P5 terrain fill. Ordinary P6
water is absent because the causeway scalar has `T > W`; the culvert opcode is
therefore the sole owner of its water role. On a culvert column,
`CAUSEWAY_FILL` is restricted to `W+1..T-1`; on a non-culvert causeway column
it retains the complete `shell_low..T-1` interval. The solid causeway remains
from `W+1` through `T`. This is a deterministic closed radius-one lattice tube
around the accepted continuous hydrology centreline; it requires no inferred
flow direction or search. A named causeway with no such culvert column
anywhere in its complete accepted footprint is a validation failure.

### 8.8 Tunnel floor, lumen, walls and roof

For `K == "tunnel_floor"`, R3 leaves `T` unchanged and provides floor `F`.
The exact 33-axis-node visible footprint is already represented by R3's
functional result. For every footprint column emit:

```text
TUNNEL_FLOOR  F .. F      TUNNEL_FLOOR  SURFACE_EXACT
TUNNEL_LUMEN  F+1 .. F+4  AIR           OPEN_ENGINEERED
TUNNEL_ROOF   F+5 .. F+5  TUNNEL_WALL   SEAL_VOID
```

The roof operation succeeds without replacement when the existing node is an
eligible known solid, ore or stratum. Air or compatible liquid is sealed.
An already solid registered resource is retained as the same explicit
supporting-solid no-op as other known solid content. Foreign, unknown or
`ignore` rejects.

The side-wall collar is the exact four-neighbor dilation of the tunnel
footprint by one column, excluding every tunnel column. For one collar column,
collect its cardinally adjacent tunnel samples. Require one shared interface
ID. Let `Fmin` and `Fmax` be their minimum and maximum floor values; emit:

```text
TUNNEL_WALL  Fmin+1 .. Fmax+4  TUNNEL_WALL  SEAL_VOID
```

If adjacent tunnel samples carry different interface IDs, or if the collar
overlaps another non-tunnel functional surface, planning fails. This exact
one-node cardinal collar is the complete side-wall mask; no diagonal collar,
portal extension, cave flood fill or ornamental lining exists in R5.

P5 still owns ordinary terrain around and above the tunnel. No operation
touches below the floor except the ordinary shell if it independently owns
that Y.

### 8.9 Hydrology bed and bank seals

Every current wet hydrology profile must report exactly
`bed_seal_layers == 3` and `bank_seal_nodes == 2`. For a wet column with bed
`B = W - profile_depth`, emit:

```text
HYDROLOGY_BED_SEAL  B-2 .. B  HYDROLOGY_SEAL  SEAL_VOID
```

Existing eligible solid nodes remain unchanged; only air or compatible liquid
holes are sealed. The run must remain at or above `-37`; otherwise planning
fails instead of silently clipping a named surface-water profile.

Before candidates are appended, a bed/bank seal interval subtracts every
already-defined P3 solid interface interval. The interface solid itself is an
equivalent seal. Thus a ford bed owns `B` while its bed seal owns only
`B-2..B-1`; a non-culvert causeway's complete solid fill replaces its bed-seal
candidate; and a culvert retains the disjoint `B-2..B` seal below its
`B+1..W` water lumen. If subtraction encounters a P3 open interval other than
that exact culvert relationship, planning fails rather than resolving a
same-priority conflict by order.

The bank collar is the exact Manhattan-distance-two dilation of the wet named
hydrology footprint, excluding wet columns. The planner samples the fixed
twelve offsets with `abs(dx) + abs(dz)` in `1..2`. For a bank column, collect
all wet samples. They are compatible only if they have one hydrology ID or all
appear in one accepted confluence/transition relation in the construction
lookup from Section 4.3. Otherwise planning fails. Define:

```text
seal_low  = minimum(sample_bed_y - 2)
seal_high = min(T, maximum(sample_water_y))
```

If `seal_low <= seal_high`, emit:

```text
HYDROLOGY_BANK_SEAL  seal_low .. seal_high
    HYDROLOGY_SEAL  SEAL_VOID
```

The bank seal fills only void/liquid holes and never cuts or raises the scalar
terrain surface. Compatible samples are aggregated before one candidate is
appended; its diagnostic feature ref is the unsigned-ASCII-smallest
contributing hydrology ID. The fixed subtraction above may split a seal into
at most three intervals and is ordinary inclusive-interval clipping, not a CSG
language. Incompatible role/identity overlap fails.

### 8.10 Ordinary and named water

Where `W` is non-nil and `T < W`, emit one inclusive source-water run:

```text
named wet hydrology:
  RIVER_WATER     T+1 .. W  RIVER_WATER_SOURCE     WRITE_WATER
other planned water:
  ORDINARY_WATER  T+1 .. W  ORDINARY_WATER_SOURCE  WRITE_WATER
```

Every node in the interval is a source role. R5 authors no flowing-water
column; `update_liquids` owns subsequent flow. Mainland/island land with nil
water emits no water. Incidental native surface liquid outside an accepted
water mask is removed only through P5 `TERRAIN_CLEAR` and its bounded shell.
Native subsurface liquid below the shell is untouched.

For an orthogonal contact face, R3 returns nil `W`, a nonzero face mask and
upper/lower values. Let the lower bed be `lower_y - lower_profile_depth`.
Emit:

```text
RIVER_WATER   lower_bed+1 .. lower_y-1  RIVER_WATER_SOURCE  WRITE_WATER
RECEIVER_OPEN lower_y .. lower_y         AIR                 OPEN_ENGINEERED
```

An empty water interval is omitted. Exactly the top source at `lower_y` is
absent. No falling-water run is emitted. Cardinal rapid/waterfall columns use
their ordinary non-nil R3 water scalar and the same river-water rule.

## 9. Owner slices, halo and mapchunk order

### 9.1 Central ownership

The callback's inclusive `minp..maxp` is the sole normal write box. The owner
of a voxel is exactly the central mapchunk containing it. Planner runs are
clipped to all three central axes before they enter the plan.

The emerged `emin..emax` halo may be read only for:

- the fixed shell guards;
- the 12-sample hydrology bank collar;
- the four-neighbor tunnel wall collar;
- content/light properties needed by the transaction; and
- temporary lighting seeds that are restored before the final light buffer.

Content and param2 outside `minp..maxp` must be byte-identical before and after
the adapter. No x/z shell cleanup, neighbor feature write or anchor-owner
cross-chunk write is permitted.

### 9.2 Pull rendering

Every global feature is evaluated analytically at the current absolute
columns, then clipped to the central owner slice. A bridge, tunnel, causeway,
path, foundation or water feature crossing a chunk boundary is rendered by
each owning chunk for its own voxels. The chunk containing an anchor or source
record has no special write authority.

Vertical slices use the same absolute R2/R3 facts. They never persist a height
observed from a prior chunk, inspect a neighbor-generated flag or use a native
heightmap as authority.

### 9.3 Order independence

The plan is a pure function of:

```text
full seed, W=1, manifest, absolute minp/maxp,
accepted R2/R3 facts, accepted R4 private seam semantics
```

Native-buffer policies may preserve or reject current content but may not
select alternative geometry. Acceptance compares complete central content,
param2 and light digests after ascending, descending and deterministic random
x/z and vertical chunk-request orders. Every order uses one emerge thread.
Unsupported multiple-v7-thread determinism is not claimed.

## 10. Mapgen manifest and native preservation

### 10.1 Exact offline manifest

`mapgen_manifest.lua` is pure and does not call `core.set_mapgen_setting`,
write configuration or register anything. It validates an injected exact
table with:

```text
schema                     grug_wp40_r5_mapgen_manifest_v1
engine_commit              df04879066de6eb94ca43996822a6dfacc74feca
mg_name                    v7
water_level                1
chunksize                  5
emerge_threads             1
engine_emerge_setting      num_emerge_threads
mg_flags                   biomes,caves,decorations,dungeons,light,ores
mgv7_spflags               caverns,mountains,ridges
mgv7_dungeon_ymin          -31000
mgv7_dungeon_ymax          -193
broad_content_y_min        -37
force_native_dungeon       false
```

Its exact API is:

```text
manifest_module.validate(values) -> validated manifest
manifest_module.canonical_bytes(validated_manifest) -> byte string
```

`validate` requires the exact field allowlist above and returns a fresh
immutable-by-contract scalar/set representation. `canonical_bytes` accepts
only that validated identity and allocates no mapgen evaluator or engine
object.

Flag lists are canonical lexicographically sorted sets. Missing, extra or
duplicate tokens fail. The absence of `floatlands` is significant. R5's
headless-shaped fixtures inject these values; R5 does not change `game.conf`,
world metadata or engine settings. R7 must enforce the same manifest before it
registers the adapter.

### 10.2 Dungeon preservation

Production has no node-name or content-class dungeon detector. The proof is
vertical and typed:

- chunksize 5 gives central ranges `[-32 + 80k, 47 + 80k]` and full emerged
  ranges `[-48 + 80k, 63 + 80k]`;
- dungeon eligibility stops at `mgv7_dungeon_ymax = -193`;
- the highest eligible dungeon slice is central `[-272,-193]`, full
  `[-288,-177]`;
- the first broad authored slice is central `[-112,-33]`, full
  `[-128,-17]`; and
- the complete emerged ranges are disjoint by 48 nodes.

No P2-P7 operation may have `y_min < -37`. Below -37, only the reserved R6
`RESOURCE_EXACT_HOST` operation may ever exist, and its
`DEEP_EXACT_HOST` policy cannot match dungeon, air, liquid, generic ore,
resource, `ignore`, unknown or foreign content. `force_native_dungeon = true`
is always fatal.

The existing finite native-only dungeon callback corpus remains an additional
offline proof oracle. It unions the complete emerged VM area of every positive
dungeon notification and rejects any audited target intersection. It is never
queried by production and never narrows the global vertical proof.

### 10.3 Cave, ore and stratum preservation

- Content below every owned run is byte-identical.
- Cave air may be filled only by `FILL_VOID` or `SEAL_VOID` inside an exact P2,
  P3, P4 or P5 run.
- Cave air below the ordinary shell or outside a named interface/seal mask is
  untouched.
- Native ore and registered WP43 resources are never cut or redressed. A
  solid ore may serve as an unchanged support/seal no-op; a requested cut
  through it rejects the transaction.
- Existing registered WP43 stratum hosts remain byte-identical outside exact
  cut/water/interface runs. Inside a `CUT_NATURAL`, `OPEN_ENGINEERED`,
  `WRITE_WATER` or `SURFACE_EXACT` run they are an explicitly replaceable
  typed host; inside fill/seal runs they remain supporting-solid no-ops. R5
  fixtures prove the class rule, not Production node names.
- Unknown and foreign nodes are never guessed natural.

This qualifies cave/ore/stratum preservation by exact owned runs while keeping
dungeon preservation unconditional.

## 11. One VoxelManip transaction

### 11.1 Adapter API

```lua
adapter_module.new(validated_manifest, content_contract, counting_allocator)
    -> adapter

adapter.apply(vm, minp, maxp, plan, call_mode) -> result_code
```

`call_mode` is exactly `"offline_fixture"` or `"engine_fixture"` in R5. Any
production/registered mode fails before VM access. R7 must add a separate
reviewed activation capability; R5 contains no hidden boolean that enables it.
Native callback `blockseed` is not an adapter input and cannot influence an
authored plan; the canonical full seed closed over by R4/R5 construction
remains the only authored random domain.

Adapter construction validates and closes over the manifest, content contract
and allocator. `apply` cannot substitute a different role/CID mapping for an
existing adapter.

The adapter requires the listed callable VM methods and routes every call
through an exact invocation allowlist. The engine object may expose other
methods, but R5 may call only:

```text
get_emerged_area
get_data
get_param2_data
get_light_data
set_data
set_param2_data
set_lighting
calc_lighting
set_light_data
update_liquids
```

An empty plan returns `noop_empty_plan` after manifest/plan validation and
without any buffer method call.

### 11.2 Exact precommit order

For a nonempty plan:

1. validate internal R5 status, call mode, manifest, plan schema/generation,
   bounds, run canonicality, stable refs, opcodes, priorities, roles, policies
   and all content-contract CID/property tables;
2. call `get_emerged_area()` exactly once and verify the expected central box
   lies inside it with all required guard/lighting rows present;
3. call `get_data(data_buffer)` exactly once into a retained full-size buffer;
4. call `get_param2_data(param2_buffer)` exactly once only when at least one
   resolved role/aux policy can change param2;
5. classify the immutable content snapshot, validate every planned target and
   required context cell, resolve target CIDs, mutate only retained Lua content
   and param2 buffers, and collect exact dirty sets;
6. if a light-relevant content change exists, construct and validate the
   complete light box/seed-run plan from Section 12.3, then call
   `get_light_data(light_original)` exactly once before any setter;
7. if no content or param2 value changed, return `noop_equal_content` with no
   setter, lighting or liquid call;
8. call `set_data(data_buffer)` exactly once iff content changed;
9. call `set_param2_data(param2_buffer)` exactly once iff param2 changed;
10. perform the single light transaction in Section 12.3 iff light dirty;
11. call `update_liquids()` exactly once iff liquid dirty, after the final
    light setter; and
12. return a closed scalar result code and update retained metrics.

All fatal validation precedes step 8. The adapter performs no second content
read or content setter. It never calls a direct node API, schematic, ore or
decoration generator.

### 11.3 Full buffers and ownership proof

`get_data`, `set_data`, param2 and light arrays always have the complete
emerged volume length. The adapter may modify retained Lua entries only for
central owner voxels, except temporary light entries that Section 12 restores.

Evidence hashes separately bind:

- complete pre/post content;
- central pre/post content;
- read-only halo content;
- complete pre/post param2;
- central pre/post param2; and
- complete final light plus central final light.

Every no-op path binds exact VM call counts.

## 12. Ignore, dirty columns, lighting and liquids

### 12.1 `CONTENT_IGNORE`

The content contract receives the engine's exact `CONTENT_IGNORE` value.

- A planned target equal to `ignore` rejects the entire transaction.
- A shell guard, tunnel neighbor, hydrology bank sample or light seed required
  for a decision and equal to `ignore` rejects the entire transaction.
- Unneeded `ignore` in a read-only emerged halo is allowed and remains
  byte-identical.
- A target role may never resolve to `ignore`.
- The adapter never converts `ignore` to air or treats it as unknown natural
  content.

The failure occurs before `set_data` and is recorded as
`fail_content_ignore`, without a coordinate-dependent recovery path.

### 12.2 Dirty representation

Dirty state uses fixed 6,400-entry scalar/boolean arrays indexed by central
column, plus min/max bounds. It has exactly these categories:

```text
content_dirty
param2_dirty
light_dirty
liquid_dirty
```

A voxel is content dirty only if old CID differs from resolved target CID.
Param2 is dirty only if old byte differs from the resolved aux/role result.

Content is light dirty if old and new nodes differ in any of:

```text
paramtype_light
light_propagates
sunlight_propagates
light_source
```

Content is liquid dirty if:

- old or new node belongs to a liquid family;
- source/flowing family or liquid level changes; or
- old and new `floodable` differ, including solid-to-air openings beside
  retained liquid.

Dirty arrays are reset and reused without per-call table allocation. The
artifact records dirty column/voxel counts and bounding boxes by category.

### 12.3 Single light transaction

For a nonempty light-dirty set, steps 1 through 4 execute during precommit
step 6 in Section 11.2; steps 5 through 10 execute after the content/param2
setters:

1. construct the central dirty voxel bounding box;
2. expand each axis by 15 nodes, clip x/z to the emerged area and y to a range
   whose top plus one seed row remains inside the emerged area;
3. require every context cell used by that box and seed row to be non-ignore,
   and construct the complete canonical seed-run list;
4. retain `light_original` from the pre-setter call in Section 11; after this
   point no R5 validation may fail;
5. call `set_lighting({day=0, night=0}, light_min, light_max)` exactly once;
6. use the prevalidated analytically sky-open seed columns derived from R3
   `T`/`W` and the authored clear interval, grouped as maximal increasing-X
   runs for each increasing Z row, and call
   `set_lighting({day=15, night=0}, seed_min, seed_max)` once per run on the
   single row `light_max.y + 1`;
7. call `calc_lighting(light_min, light_max, true)` exactly once;
8. call `get_light_data(light_final)` exactly once;
9. restore from `light_original` every entry outside the central owner light
   box, including every temporary seed entry whether it lies in central or
   halo coordinates; and
10. call `set_light_data(light_final)` exactly once.

There are no other `calc_lighting` or `set_light_data` calls. Seed runs are
bounded by the 6,400 central columns and are represented by reused flat scalar
arrays, not voxel objects. Their actual and peak counts are artifact metrics.

The central owner light box is the intersection of the expanded light box and
`minp..maxp`. The adapter never claims ownership of persistent halo light.
Order fixtures must prove that this rule converges for opened sky, sealed
caves, water, chunk tops and reversed vertical request order. Any counterexample
rejects R5; implementation may not widen persistent light ownership as a fix.

A non-light-dirty transaction performs zero `get_light_data`, `set_lighting`,
`calc_lighting` and `set_light_data` calls.

### 12.4 Liquid queue

`update_liquids()` is called exactly once if and only if `liquid_dirty` is
nonempty. It occurs after `set_data`, optional param2, and the final
`set_light_data`. There is no per-column call and no call for an equal-content
water run.

R5 authors source-role water only. Native liquid simulation owns flowing
water, falling contact faces and later settling. The adapter neither polls nor
waits for that simulation.

## 13. Disabled callback and writer mutual exclusion

### 13.1 Constructive disabled proof

R5 production and tools must contain zero calls to:

```text
core.register_mapgen_script
core.register_on_generated
core.set_mapgen_setting
core.set_mapgen_params
core.register_lbm
VoxelManip:write_to_map
```

No R5 file is referenced by normal `grug_mapgen/init.lua`, `game.conf` or a
mapgen script path. No R5 field is installed on `grug_mapgen`, `grug_core` or a
new global. The only construction path is explicit `dofile` by R5 tools.

### 13.2 R5 production state

The only supported R5 repository state is:

```text
legacy ocean/structure writers: unchanged and potentially active
R5 planner/adapter modules: present but unreachable from production loaders
R5 mapgen callback: absent
R5 production content contract: absent
R5 settings mutation: absent
```

Therefore no production configuration can activate both writer generations in
R5. A user-editable boolean, setting, environment variable, IPC flag or hidden
installer that can enable the adapter is forbidden.

R7 must remove/disable all legacy writer registrations and healing paths,
validate the production content contract and exact manifest, and register the
new adapter in one reviewed atomic change. It may not land an intermediate
configuration in which both callbacks can run.

## 14. Canonical artifact and evidence

### 14.1 Path and schema

The sole canonical R5 artifact candidate is:

```text
docs/research/wp40-simple-map-r5-artifact.tsv
```

Its first row is:

```text
schema	grug_wp40_simple_map_r5_artifact_v1
```

Its newline-terminated body ends immediately before:

```text
artifact_sha256	<lowercase SHA-256 of the complete body>
```

The complete-file SHA-256 is recorded by the later review, never embedded in
the artifact itself.

### 14.2 Required lineage rows

The artifact includes exactly one row for each:

```text
r2_body_sha256
r2_file_sha256
r3_body_sha256
r3_file_sha256
r4_historical_body_sha256
r4_historical_file_sha256
r4_public_kat_sha256
r4_accepted_implementation_commit
r4_review_file_sha256
r4_review_verdict_sha256
contract_sha256
```

It includes `input_sha256` rows for every current R5 executable production and
tool input, including the modified `zones.lua`, unchanged public `init.lua`,
contract, runner and manifest. Paths are unique, sorted and repository-
relative. It does not include itself, the future R5 review, BACKLOG, ROADMAP,
README or a future acceptance/status commit.

### 14.3 Required semantic rows

The artifact binds at least:

- all Section 2 schemas/constants and the complete manifest;
- opcode/priority/role/policy numeric tables;
- stable-reference population and digest;
- exact historical/current public R4 KAT parity;
- exact public R4 field allowlist and disabled reason bytes;
- private planner-source scalar KAT digest, including ordered
  `(x,z,biome_at,logical_biome_id)` pass-through rows whose last two values are
  identical for every sampled column;
- exact absence of `share`, palette-roll, quota, minimum-presence,
  redistribution, reroll and missing-biome-repair fields or counters from the
  R5 source, plan and content-contract schemas;
- canonical seed-zero plan digest and operation counts by opcode/priority;
- zero P7/P8/P9 emission;
- every exact mask population: foundations, paths, ford, bridge support,
  causeway culvert, tunnel lumen/wall/roof, bed/bank seals and receiver opens;
- candidate/resolved run peaks and all allocation metrics;
- shuffled-candidate and repeated-plan canonical parity;
- owner-slice and read-only-halo content/param2/light digests;
- ascending/descending/permuted horizontal and vertical order digests;
- content class and replace-policy outcome matrix;
- exact dungeon vertical proof rows and finite-oracle nonintersection;
- cave/ore/stratum/resource/foreign/unknown preservation fixtures;
- ignore target/context/unneeded-halo fixtures;
- no-op/content/param2/light/liquid dirty matrices and exact VM call counts;
- sky-open, sealed-cave, water and chunk-top light fixtures;
- source audits for no callback/global/registration/settings mutation; and
- input hashes before and after every worker fleet.

### 14.4 Construction and VM metrics

Bound canonical metrics include:

```text
horizontal_session_count
height_session_count
planner_source_count
planner_construction_count
construction_table_allocations
construction_array_tables
construction_map_tables
retained_numeric_capacity
stable_ref_count
plan_slice_table_allocations
peak_candidate_runs_per_column
peak_resolved_runs_per_column
peak_resolved_runs_per_slice
peak_run_value_cells
plan_buffer_growth_events
plan_buffer_reuse_calls
classified_columns
planned_columns
modified_voxels
content_dirty_columns
param2_dirty_columns
light_dirty_columns
liquid_dirty_columns
vm_get_data_calls
vm_set_data_calls
vm_get_param2_calls
vm_set_param2_calls
vm_get_light_calls
vm_set_lighting_calls
vm_calc_lighting_calls
vm_set_light_data_calls
vm_update_liquids_calls
```

Elapsed time, CPU time, peak RSS, host, interpreter and full-buffer byte
estimates are printed in an explicitly unbound section. They do not
participate in canonical byte-repeat identity and establish no absolute gate.

## 15. Validators, KATs and runner

### 15.1 Planned tools

R5 implementation is limited to these dedicated tools unless the contract is
amended:

```text
tools/wp40/simple_map_r5_common.lua
tools/wp40/simple_map_r5_offline.lua
tools/wp40/simple_map_r5_validate.lua
tools/wp40/simple_map_r5_kat.lua
tools/wp40/simple_map_r5_vm.lua
tools/wp40/simple_map_r5_artifact.lua
tools/wp40/simple_map_r5_selftest.lua
tools/wp40/run_simple_map_r5.sh
```

The VM proxy presents exact engine-shaped method signatures, complete emerged
buffers, `CONTENT_IGNORE` and injected content properties. It rejects any
method not in Section 11.1 and records call order and count.

### 15.2 Full LuaJIT evidence

Long and exhaustive work runs only under LuaJIT. The authoritative R5 run:

1. performs the historical/current lineage preflight before executable load;
2. proves current public R4 KAT bytes equal historical accepted bytes;
3. validates the complete private scalar seam against the same R2/R3/R4
   sessions, including byte-identical `logical_biome_id == biome_at(x,z)`
   pass-through for every sampled column;
4. scans all R3 functional/interface and transition footprints for exactly one
   closed R5 mask result;
5. proves the sixteen/31 run bounds over the complete seed-zero relevant
   layout;
6. runs the complete class/policy/conflict/ignore matrix;
7. runs labeled native cave, ore, stratum, resource, unknown and foreign
   substrate fixtures;
8. runs owner-slice and horizontal/vertical order populations;
9. runs every dirty/light/liquid VM-call fixture;
10. shuffles candidate production order without changing canonical plan bytes;
11. runs twice to byte-identical artifact bytes; and
12. verifies immutable input hashes before and after all workers.

The retired exact-T2 W/PCC/F1/F2/compiler/topology populations do not run.
R5 validates the simple accepted geometry and its own bounded plan only.
It does not gate or report realized biome area shares. The global all-16-ID
coverage gate, exact `0..99` roll partition and seed-zero realized-share
evidence belong to the accepted R4 lineage; R5 re-proves only deterministic,
unchanged scalar pass-through.

### 15.3 PUC Lua 5.1 KATs

PUC 5.1 runs only targeted representative KATs, in canonical seed order,
covering at least:

- all planner-source tuple nil/non-nil branches;
- representative logical-biome columns whose private scalar is byte-identical
  to the same public R4 `biome_at(x,z)` result; this KAT makes no population,
  presence or realized-area assertion;
- every P2-P6 opcode and every replace policy;
- same-priority conflict and cross-priority winner;
- shell lower/upper guards and `-37` boundary;
- bridge support, culvert radius boundary, tunnel collar and roof;
- bed/bank seal boundaries and receiver omission;
- ignore target, ignore required context and unneeded halo ignore;
- no-op/content/param2/light/liquid call matrices;
- a horizontal and reversed vertical owner/order fixture;
- stale plan generation and missing content role; and
- exact public R4 KAT and disabled-loader parity.

LuaJIT and PUC KAT byte strings and canonical digests must be identical. PUC
does not run the exhaustive layout, 32-seed population or full order fleet.

### 15.4 Parallel execution

At most seven Lua processes run concurrently across the workstation. Every
worker receives immutable inputs, writes to a separate scratch/output path and
runs at `chrt --idle 0` plus `ionice -c3`. A deterministic single merge orders
all shards and refuses missing, duplicate or unexpected outputs.

Jobs that share mutable outputs or depend on execution order are not
parallelized. Historical eight-worker measurements grant no eighth slot.

### 15.5 Static gates

When implementation exists, every changed Production and tool Lua file passes:

- `tools/bin/luac51 -p`;
- changed-mod `SETGLOBAL` inspection;
- the five explicit Lua 5.1/sandbox/escape sweeps;
- separate equivalent sweeps over every changed `tools/wp40/*.lua` file; and
- source audits proving the disabled and no-second-evaluator rules.

The runner first proves `rg` exists and passes `bash -n`. This draft task runs
none of those gates because it creates no implementation.

## 16. Deliverables and owned files

The eventual R5 candidate may change only:

```text
docs/research/wp40-simple-map-r5-contract.md
docs/research/wp40-simple-map-r5-artifact.tsv
docs/research/wp40-simple-map-r5-review.md
mods/MAPGEN/grug_mapgen/wp40/zones.lua
mods/MAPGEN/grug_mapgen/wp40/index128.lua
mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua
mods/MAPGEN/grug_mapgen/wp40/planner.lua
mods/MAPGEN/grug_mapgen/wp40/map_adapter.lua
mods/MAPGEN/grug_mapgen/wp40/r5.lua
tools/wp40/simple_map_r5_common.lua
tools/wp40/simple_map_r5_offline.lua
tools/wp40/simple_map_r5_validate.lua
tools/wp40/simple_map_r5_kat.lua
tools/wp40/simple_map_r5_vm.lua
tools/wp40/simple_map_r5_artifact.lua
tools/wp40/simple_map_r5_selftest.lua
tools/wp40/run_simple_map_r5.sh
```

The R5 implementation must not change:

```text
mods/MAPGEN/grug_mapgen/wp40/init.lua
mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua
mods/MAPGEN/grug_mapgen/wp40/simple_map.lua
mods/MAPGEN/grug_mapgen/wp40/height.lua
mods/MAPGEN/grug_mapgen/init.lua
mods/MAPGEN/grug_mapgen/ocean_mask.lua
mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua
mods/MAPGEN/grug_mapgen/structures.lua
game.conf
```

It also makes no R5 status edit to BACKLOG, ROADMAP or README before accepted
review. A required file outside the allowlist stops implementation and returns
to contract amendment.

## 17. Preflight, review and acceptance sequence

The exact sequence is:

1. accept and close R4 independently, including final artifact, review and
   implementation commit;
2. replace only the Section 3.1 placeholders in this contract from that
   accepted record;
3. verify the placeholder-resolution diff, obtain the policy-required fresh
   independent contract review, close its findings, and freeze the resulting
   R5 contract before implementation;
4. implement the private seam, planner, manifest, adapter and tools in the R5
   worktree without changing public R4 bytes;
5. pass the lineage preflight and exact historical/current public KAT parity;
6. pass static gates, full LuaJIT evidence and targeted PUC digest parity;
7. generate the canonical R5 artifact twice to byte-identical bytes;
8. freeze the candidate diff, status snapshot and immutable evidence;
9. obtain one fresh independent review selected under
   `docs/process/agent-model-policy.md`, applying the complete checklist in
   `docs/process/wp-workflow.md` and `docs/research/luanti-lua.md`;
10. fix every Critical, High or Medium finding; Critical/High fixes receive a
    focused fresh rereview, and Low findings are fixed or explicitly
    dispositioned under policy;
11. only a clean final verdict may create the R5 review record and acceptance
    closeout; and
12. only then update the rebase plan, BACKLOG, ROADMAP and README current
    state as one coherent completion change.

No review is performed by the drafting task that creates this document. The
contract does not name a local preferred reviewer model; project model policy
is the sole routing authority.

The review checks at minimum:

- correct historical/current artifact lineage without a hash cycle;
- exact public R4 KAT and disabled-loader byte parity;
- exact logical-biome scalar pass-through with no `share` input, population
  quota, reroll or repair behavior;
- exactly one horizontal and one height session;
- no per-voxel operation objects, CSG or unbounded recovery;
- sound 16/31 run bounds and measured allocation counters;
- exact masks and same-priority conflict failure;
- zero P7-P9 emission and fail-closed unmapped roles;
- one VM content transaction and exact call order;
- owner-only content/param2 plus restored halo light;
- dungeon vertical separation and cave/ore/stratum preservation;
- ignore, dirty, lighting and liquid correctness;
- no callback, global, setting change or legacy-writer coexistence path; and
- plain Lua 5.1 compatibility and compliant interpreter scheduling.

## 18. R6 and R7 boundaries

### 18.1 R6 owns content and resources

R6 may consume the private planner source and reserved opcode vocabulary, but
must first define the reviewed successor plan schema required by Section 7.2.
R6 owns:

- final role-to-node/CID mappings;
- logical-biome top/filler/shore/bed material, mapped from the exact unchanged
  per-column R4 `biome_at(x,z)` value;
- authored resource eligibility, cell candidates and exact-host placement;
- deterministic decorations and their conflict candidates;
- final ordinary/river-water registered names and properties;
- WP43 registered-material manifest validation; and
- 32-seed content/resource/supply evidence.

The binding R6 audit, not R5, owns resource and faction parity. R6 receives no
license to turn the R4 weights into realized quotas: its material/resource
mapping consumes the selected logical-biome ID and may not redistribute,
reroll or repair biome selection.

R6 does not reopen R2/R3/R4 geometry, change R5 priority or add another VM
transaction. Any R6 role absent from its complete content contract fails
before VM access; reserved does not mean optional at runtime once emitted.

### 18.2 R7 owns activation and consumers

R7 alone:

- validates and enforces the exact production mapgen manifest, including
  `num_emerge_threads = 1`;
- removes or disables every legacy ocean/structure/healing writer path;
- installs exactly one mapgen-environment callback/script for the consolidated
  adapter;
- supplies the accepted production content contract;
- migrates geography consumers and publishes the selected R4 APIs; and
- proves no repository/configuration path can enable both writer generations.

R5's disabled internal status is not an R7 activation mechanism. R7 must add
and review the activation boundary explicitly.

## 19. Stop conditions

Implementation stops and returns to contract or design review if it would:

- begin before R4 implementation/artifact/review acceptance or with an
  unresolved Section 3 placeholder;
- edit an accepted R2/R3 artifact input or result;
- change a public R4 API field, KAT byte, disabled reason or loader behavior;
- treat the historical R4 artifact's `zones.lua` hash as a current hash after
  the documented private-seam edit, or regenerate the historical artifact;
- create a cyclic artifact/review/status dependency;
- build a second horizontal, height, ownership, path, hydrology, anchor,
  boundary or logical-biome evaluator;
- accept biome `share` as planner input, test realized-area quotas or minimum
  presence, redistribute columns, reroll, repair a missing biome or replace
  the exact `biome_at(x,z)` pass-through value;
- allocate a Lua operation table per voxel/run or exceed a Section 6 bound;
- add generic CSG, flood fill, repair, late selection or unbounded search;
- weaken a same-priority conflict into stable-id/last-writer selection;
- emit P7, P8 or P9 in R5, skip an unmapped role, or hardcode R6 nodes/CIDs;
- write content or param2 outside the central owner slice;
- persist temporary halo light or make geometry depend on chunk request order;
- infer dungeon origin from content names, enable dungeon force placement, or
  violate the `-37`/`-193` vertical proof;
- replace ore/resource/foreign/unknown/ignore as ordinary terrain;
- use more than one content read/set transaction, a direct node writer,
  schematic, ore/deco generator or later healing pass;
- register a callback/global, change settings/configuration or expose an R5
  activation flag;
- disable a legacy writer or migrate a consumer before R7;
- schedule an exhaustive PUC run or exceed seven concurrent Lua processes; or
- invent an absolute performance threshold without a measured derivation.

A source-data correction or player-visible geometry change is not an R5
implementation detail. It returns to the relevant accepted stage and, where it
changes decided design or preservation, to the user before code continues.
