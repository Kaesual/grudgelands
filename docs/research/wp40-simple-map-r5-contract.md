# WP40 simple-map R5 typed-planner and disabled-adapter contract

**Draft status (2026-08-28): contract draft only. R4 is accepted historical
authority at commit `948689138c15c291544fe10927683da4183bfd8e`; this draft
creates no accepted R5 authority, supersedes no artifact or status, activates no
map writer and records no R5 review verdict. The user selected B+:
H-authoritative owner-slice normalization with local native-cave preservation.
That decision is contract-frozen below and its corrected contract received a
clean independent review. The user-authorized interpreter-policy amendment in
Sections 15 through 17 and the interpreter stop condition in Section 19
requires one fresh focused independent review before implementation; it opens
no design decision.**

This contract defines R5 of the simple-map rebase: one pure, bounded typed
planner and one disabled consolidated VoxelManip adapter over native mapgen v7.
It consumes the accepted R2 horizontal and R3 vertical authorities and one
private scalar seam backed by the exact same accepted R4 horizontal and height
sessions. It does not reopen geometry, ownership, height, crossing, anchor or
logical-biome selection.

The binding game rules remain in `docs/design/world_zones.md`. The mapgen and
engine evidence remains in `docs/research/mapgen-control.md`, the R5 scope in
`docs/research/wp40-simple-map-rebase-plan.md`, and the architectural priority
in `docs/research/wp40-engineering-brief.md`. This document defines the smaller
implementation boundary needed to turn those decisions and the B+ preservation
decision into a reviewable R5 candidate.

## 1. Outcome and non-goals

R5 owns exactly four results:

1. a private allocation-free scalar seam from the accepted R4
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
counts, logical allocation counts and full-buffer sizes are artifact evidence;
elapsed measurements, host and interpreter are recorded only in runner logs.
Any future binding timing limit requires a measured whole-mapchunk budget and a
documented derivation.

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

### 2.2 Accepted R4 biome semantics

R4 is accepted historical authority and binds all of these semantics:

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
- v7 constructs its current central-chunk heightmap after base terrain and
  before biome replacement, caves, ores, dungeons and decorations;
- `get_mapgen_object("heightmap")` returns a fresh dense array whose index
  order is X fastest inside Z: for the 80 by 80 central chunk,
  `i = (z-minp.z)*80 + (x-minp.x) + 1`;
- a heightmap entry is the highest walkable base-terrain node inside the
  current central Y slice, or `-MAX_MAP_GENERATION_LIMIT = -31007` when none
  exists;
- the pinned `get_mapgen_edges(31007, 5)` formula and its engine unit test both
  yield central owner edges `-30912` and `30927` on every axis;
- that callback receives the live mapgen VoxelManip and central `minp`/`maxp`
  before the final engine blit;
- a callback error cancels generation rather than accepting a deliberately
  partial result;
- `get_data`, `get_param2_data` and `get_light_data` overwrite exactly the
  one-based active prefix `1..VoxelArea:getVolume()` of a supplied Lua table
  and do not delete higher retained numeric keys; the corresponding setters
  consume exactly that active prefix and ignore higher retained keys;
- `CONTENT_IGNORE` is the Lua representation of no data and is not written;
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
R5_MAPGEN_CONTEXT_SCHEMA          grug_wp40_r5_mapgen_context_v1
R5_MANIFEST_SCHEMA                grug_wp40_r5_mapgen_manifest_v1
R5_ARTIFACT_SCHEMA                grug_wp40_simple_map_r5_artifact_v1
project_water_level               1
mapgen_limit                      31007
chunksize                         5
max_central_axis_nodes            80
max_central_columns               6400
central_owner_y_min               -30912
central_owner_y_max               30927
authored_floor                    -37
native_heightmap_entries          6400
native_heightmap_sentinel         -31007
native_heightmap_order            x_fast_z_outer
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
canonical_seed_1                  0
canonical_seed_2                  1
canonical_seed_3                  9223372036854775808
canonical_seed_4                  18446744073709551615
```

The four full-seed strings above are the complete canonical R5 seed roster and
its exact order. They are decimal ASCII strings, not Lua numbers; leading zero,
sign, whitespace, exponent and numeric conversion are forbidden. Every
four-seed merge rejects a missing, duplicate, reordered or additional seed.

`emerge_threads` is the canonical manifest field. It maps to the engine
setting `num_emerge_threads`, whose canonical decimal value must be exactly
`1`. R5 validates this offline and never writes the setting.

`mapgen_limit`, `chunksize` and the two central Y-owner edges are one bound
tuple. Re-evaluating the pinned engine formula is a manifest/preflight gate;
hardcoding the edge values without that equality proof rejects. The full
central-slice roster is `minp.y = -32 + 80*k`,
`maxp.y = 47 + 80*k` for integer `k = -386..386`, whose union is exactly
`-30912..30927`. No central owner slice outside that roster is valid.

R3 `H` and its scalar ground/bed `T` are the sole final surface and operation
authority. The native heightmap is never planner input and may not alter `T`, a
mask, opcode, priority, run bound or canonical plan byte. B+ instead defines
one global analytic broad-fill interval beginning at `authored_floor = -37`
and one global analytic sky-clear interval ending at
`central_owner_y_max = 30927`; Section 8 clips them to the current owner slice.
The adapter alone uses the local pre-cave heightmap datum to preserve ordinary
native cave air/liquid as specified in Section 10.3.

Changing a schema, a bound, the B+ normalization/preservation rule, any mask,
an opcode, a priority, a
replace policy or the meaning of a result is a reviewed R5 contract change.

## 3. R4 lineage and acyclic supersession

### 3.1 Accepted R4 bindings and derived public-KAT bundle

The accepted R4 completion record binds these historical values:

```text
r4_accepted_implementation_commit       948689138c15c291544fe10927683da4183bfd8e
r4_accepted_artifact_body_sha256        bb19948d6bcb2c9976eddc6358955407f8b4a3c4cd54fb7dce1165e22ed8edca
r4_accepted_artifact_file_sha256        23a05d2115fb6d3a1b286e09a17847793e23fc0a23817ade8ce8b812875d1b3c
r4_accepted_review_file_sha256          f0a8a59e43a678d388e92528f9d3bf4b3db49fa659548880ab094a5602070eab
r4_accepted_review_verdict_sha256       bd67757f881b3a2e1952214870f60b71ab3907022153edd26f99f23a0528f130
r4_accepted_targeted_kat_body_sha256    72b9bd0e2d21cb82c4b1627031434eda1b83a2d8b8223fae22eb8f0e377ab5de
r4_accepted_targeted_kat_file_sha256    14463a99810351439fdf5d65a02436e367db69df1c2efebaeb8bc1b495a90b39
r4_seed_0_canonical_kat_sha256          8b5145180dd8a4a6de01de47cbb8fc4560e2947d78cdb281016d5c3414b9b8aa
```

The last three rows are accepted corroborating evidence, not aliases for the
four-seed public-KAT bundle. Let `S[i]` be the exact canonical full-seed ASCII
bytes from Section 2.4 and let `K[i]` be the exact byte string returned by the
historical accepted R4 session's public `canonical_kat()` at that seed. The
bundle is the following byte concatenation in `i = 1..4` order:

```text
ASCII("grug_wp40_r4_public_kat_bundle_v1\n")
for each i:
  ASCII20(#S[i]) || S[i] || ASCII20(#K[i]) || K[i]
```

`#` is the exact byte length. `ASCII20(n)` is the unsigned base-10 form padded
on the left with ASCII `0` to exactly 20 bytes; values outside
`0..99999999999999999999` reject. There are no separators, terminator or
implicit newline beyond bytes already shown or present in `K[i]`. Fixed-width
lengths make the stream uniquely decodable. Its lowercase SHA-256 is called
`r4_public_kat_bundle_sha256`. It is a derived R5 lineage value: the preflight
computes it independently from the immutable accepted Git tree twice, compares
the byte streams, then records the resulting digest in the R5 artifact. It is
not permitted to reuse any accepted single-seed, targeted-KAT-body or targeted-
KAT-file digest under this name.

### 3.2 Three distinct lineage facts

R5 keeps three concepts separate:

1. **Historical R4 acceptance.** The accepted R4 artifact at
   `docs/research/wp40-simple-map-r4-artifact.tsv`, its body/file digests, its
   accepted review and the Git tree at
   `948689138c15c291544fe10927683da4183bfd8e` remain immutable historical
   evidence.
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

1. parse every Section 3.1 literal as exact lowercase 64-hex or, for the
   implementation commit, lowercase 40-hex, and require that accepted commit to
   be an ancestor of the eventual R5 implementation candidate. Require the
   existing R5 draft `8f9472e238626cd8dcb510490f9efe6047cee13c`, audit-fix
   `a4412651a34bfb361e517474c1be702267770709`, accepted-R4 merge
   `d718f020815b77f3c9282364998b6e3bf53ce047` and B+ decision
   `37bd94829d7a8c3d1a59688612a483f449fa63de` commits to retain those exact
   object identities and ancestry. The eventual implementation candidate must
   descend from the B+ commit. Replaying, rebasing, amending or otherwise
   rewriting any of those commits is forbidden;
2. use Git object reads at the accepted implementation commit to hash the R4
   artifact blob and its newline-terminated body, then compare the two accepted
   literals;
3. use a Git object read at that commit to hash the accepted R4 review blob and
   require its `Independent implementation review` section to contain exactly
   one `Extracted verdict SHA-256` value equal to the Section 3.1 literal. The
   historical JSONL is not a Git input and its absence is not reconstructed or
   treated as an acceptance failure. If raw review JSONL is supplied as
   corroborating scratch evidence, canonical verdict extraction requires
   exactly one JSON object with `type == "result"` and a string `.result`; the
   hashed bytes are the UTF-8 bytes of that string followed by exactly one LF
   byte, with no CR, extra blank line or second result object. The extraction is
   byte-equivalent to one successful output record from
   `jq -r 'select(.type == "result") | .result'`;
4. use Git object reads, never checkout mutation, to hash every historical R4
   artifact `input_sha256` path at
   `948689138c15c291544fe10927683da4183bfd8e` and compare the embedded row;
5. create an isolated read-only historical R4 KAT input tree from that commit,
   obtain `K[1]..K[4]` through only the bounded R4 public canonical-KAT path,
   verify seed zero against its accepted digest, construct the length-framed
   bundle twice in independent scratch paths and retain the four exact byte
   strings plus bundle digest in private scratch output;
6. verify the current R2 and R3 artifact body/file hashes and all their current
   checkout input rows; and only then
7. hash the current R5 contract and every current production/tool input before
   any current `dofile`.

The historical tree is evidence input only. Current R5 never loads a mixture
of historical and current modules into one session.

### 3.4 Public parity and current-byte successor

The accepted R4 session has this exact public field allowlist:

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
`world_protected_for_faction`. It is accepted parent authority; R5 does not
silently adjust its parity test. Any change returns to the owning stage and a
reviewed contract amendment.

After current preflight, the runner constructs the modified current session
through both `zones_module.new` and the public side of
`zones_module.new_with_planner_source`. For every canonical seed, paired by its
fixed Section 2.4 ordinal, it requires:

- the two current public KAT byte strings are identical;
- each current byte string is byte-identical to the same-seed historical
  accepted `K[i]` before any aggregate comparison;
- each historical/current per-seed SHA-256 is identical, with seed zero also
  equal to the accepted seed-zero digest in Section 3.1;
- the independently framed historical and current four-seed bundles are byte-
  identical and have the same `r4_public_kat_bundle_sha256`;
- the exact public field allowlist is unchanged;
- public return ownership and malformed-input errors are unchanged; and
- normal loader evidence retains the exact disabled reason and no-publication
  result in Section 4.1.

The R5 artifact records the historical R4 artifact body/file hashes, all four
per-seed public-KAT digests and the derived four-seed bundle digest as parent
evidence. It separately records current hashes for
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

The accepted public foundation field allowlist is exactly `enabled`,
`disabled_reason`, `schemas`, `canonical`, `deterministic`, `validation`,
`index128`, `seed_corpus`, `raw_sha256_from_core`, `new_session` and
`new_engine_session`. The contract-amendment rule in Section 3.4 applies to any
proposed difference.

The public loader retains the exact accepted R4 fields and behavior.
R5 does not append an R5 status, planner, adapter or constructor to that
foundation table. Its public KAT and loader fixtures compare raw expected
bytes, not only a semantic boolean.

### 4.2 New production modules

R5 adds only:

```text
mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua
mods/MAPGEN/grug_mapgen/wp40/counting_allocator.lua
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
    planner_factory = (dofile(directory .. "/planner.lua")),
    adapter_factory = (dofile(directory .. "/map_adapter.lua")),
    manifest_module = dofile(directory .. "/mapgen_manifest.lua"),
    allocator_factory = dofile(directory .. "/counting_allocator.lua"),
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
        manifest_values, content_contract, mapgen_context)
```

The dependency allowlist is exact. Missing, extra-authoritative or
schema-incompatible dependencies fail construction. The content contract may
be the R5 fixture contract only in offline/engine-shaped tests. There is no
production content contract in R5; ordinary construction without one fails
closed before a plan or VM read.

`mapgen_context` is likewise mandatory and fixture-only in R5. Construction
validates its exact Section 11.1 schema before retaining it and passes that
same object to `adapter_module.new`; R5 contains no production context or
fallback context construction. R7 alone injects the reviewed live mapgen
context.

Construction creates exactly one horizontal session and passes that same
session to exactly one height session. The public session and private planner
source close over that same pair. The planner source must not create, receive
or lazily construct another evaluator.

Construction also builds one immutable relational lookup from the accepted
`source.hydrology_interfaces` rows. `r5_module.new` creates it through the same
planner allocator that it later passes to `planner_module.new`; the planner
validates its private allocator identity and closes over it. It consists only
of flat stable-reference/member arrays plus fixed ID-to-ordinal maps, with no
per-row record table or query-time allocation. Each non-nil
`route_interface_id` maps to exactly one `hydrology_id`; every transition ID
maps to its declared upper/lower reaches and their already-registered profiles.
Duplicate/conflicting keys, an unknown crossing/reach/profile or an incomplete
lower-face relation fail construction. This lookup relates already-accepted
stable IDs; it evaluates no geometry and is bound by a canonical digest in the
R5 artifact.
For a confluence row the compatible relation is exactly the set union of its
nonempty `from_ids` array and its non-nil `outgoing_reach_id`; all members must
name registered hydrology reaches and the set must have at least two members.
No proximity, common profile, nearest result or shared prefix creates a
confluence relation.

Before constructing either consumer, `r5_module.new` creates the planner and
adapter allocators from the one injected factory, then mints exactly one opaque
construction identity as the planner allocator's empty retained map
`plan_identity` with maximum key count zero. It passes that same object to the
planner and adapter. The identity has no readable semantic field, is never
mutated and is not returned independently; its sole purpose is `rawequal`
provenance validation of plan handles.

### 4.4 Exact tool-only core witnesses

`planner.lua` and `map_adapter.lua` each return two Lua values from their one
`dofile`. Parentheses around either `dofile` in the production construction
above deliberately select only its first value. Those first values and all
constructed production APIs remain exactly the factories and APIs specified
elsewhere in this contract. The second values are raw functions available only
to the offline validator:

```text
planner_factory, resolve_candidates_fixture = dofile("planner.lua")
adapter_factory, replacement_outcome_fixture = dofile("map_adapter.lua")

resolve_candidates_fixture(candidate_values, candidate_count, permutation)
    -> run_values, run_count

replacement_outcome_fixture(policy_id, class_id, family_id, liquid_kind,
    ordinary_family_id, river_family_id) -> outcome_id
```

`resolve_candidates_fixture` accepts one plain dense candidate array with
exactly `candidate_count * 9` scalar cells in the Section 6.1 run stride,
`0 <= candidate_count <= 16`, and one plain dense permutation containing each
integer ordinal `1..candidate_count` exactly once. Every candidate has
canonical inclusive Y bounds within the central-owner domain, the exact closed
opcode-to-priority/role/policy-set relation below, stable-reference ordinals in `0..512`
and `AUX_NONE = 0`. Malformed, relation-domain or out-of-owner input fails
with the tool-only `fail_fixture` prefix; a non-identical same-priority
overlap fails with the existing `fail_conflict` prefix; and more than 31
resolved runs fails with the existing `fail_bound` prefix. The
result is a fresh defensive plain dense array of exactly `run_count * 9`
canonical resolved cells with `0 <= run_count <= 31`. The wrapper allocates
exactly three transient tool-only tables: that returned output array, one
bounded endpoint array and one permutation-seen table. None is retained,
allocator-counted, created at module load or reachable from a Production
hotpath. The wrapper is never called from `plan_slice`, the R5 constructor or
an engine callback.

The planner's production column resolver and this wrapper invoke the same
private scalar candidate-resolution core. There is no copied validator
resolver in the production module. The permutation changes only the order in
which that core receives candidate ordinals; it cannot change canonical
result bytes or turn a conflict into a winner. For every elementary interval,
that core validates every covering candidate group independently by priority:
all candidates within each priority group must be semantically identical even
when a lower-number priority group will win. Only after all groups pass does
the lowest numeric priority win. A conflicting pair, a conflicting triple
hidden behind a valid lower-number winner and permutations of both cases bind
this order-independent rejection.

The planner has exactly one closed top-level `OP_PRIORITY`/`OP_ROLE`/
`OP_POLICY`/`OP_POLICY_ALT` constant-map set shared by Production candidate
collection and this fixture witness. Together they define a total relation
from every P2-P6 opcode to exactly one priority, one target role and one closed
policy set. `OP_POLICY` contains the primary policy. `OP_POLICY_ALT` contains
exactly one entry: `BRIDGE_CLEAR -> CUT_NATURAL`, beside that opcode's primary
`OPEN_ENGINEERED`; every other opcode has no alternate policy. This set
replaces the former factory-local copies and is a normal immutable module
dependency constructed before `r5_module.new`, under the same exclusion as
the other immutable dependency constants. The second return creates, returns
and publishes no module table and duplicates no relation map. The validator
binds the complete relation and rejects a missing, additional or different
alternate entry.

`replacement_outcome_fixture` accepts policy ID `1..7`, content-class ID
`1..11`, family ID `0..2^53-1`, liquid-kind ID `0..2` and two positive safe-
integer water-family IDs, which may be equal. Liquid kind `none = 0` requires
family zero; source/flowing `1|2` requires a positive family. It adds no
separate class-to-liquid-kind coherence branch: the exact base matrix is
class-driven, while semantic content-contract fixtures supply coherent rows.
The function returns exactly `0 = preserve/no-op`, `1 = write` or `2 = reject`.
It is the same private scalar base-matrix core called by `adapter:apply`; the
ordinary-P5 heightmap override, already-equal CID handling, target validation
and exact-param2 handling remain the adapter's surrounding transaction rules
and are exercised through real adapter fixtures. The wrapper allocates
nothing. Wrong arity or any scalar-domain violation fails with the exact
tool-only `fail_fixture` prefix; diagnostic suffix text is not canonical.

Neither second return creates or publishes a table, global, callback,
registration, setting mutation or activation capability at module load. No
Production constructor retains it, and neither function accepts a VM, source,
planner, plan handle, content contract or mapgen context. A duplicated core,
an offline-only semantic branch or a difference between the core used by the
first and second returns rejects R5.

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
classified_hydrology_id,
classified_profile_depth,
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

It returns twenty scalar values and allocates no table or string. IDs are
existing interned source strings or nil; no per-column string is constructed.
`functional_kind` is nil or exactly `anchor_platform`, `bridge_deck`,
`causeway`, `ford`, `land_grade` or `tunnel_floor`. `transition_kind` is nil,
`rapid` or `waterfall`. A cardinal transition has integer
`transition_progress_q` in `0..65536` and nil face mask; a contact-face
waterfall has nil progress and integer face mask `1..15`. Face bits are exactly
1 for an upper neighbor at `(x-1,z)`, 2 at `(x+1,z)`, 4 at `(x,z-1)` and 8 at
`(x,z+1)`. Outside a transition all six transition values are nil. Any other
combination fails planning.
`classified_hydrology_id` is the hydrology identity from the same already-
constructed R2 horizontal classification used by R3 at `(x,z)`.
`classified_profile_depth` is the exact `profile.depth` of that classified
reach and is non-nil exactly when `classified_hydrology_id` is non-nil. An
unknown ID/profile or a nil/non-nil mismatch is fatal. Neither scalar is
selected or repaired through a nearest-hydrology query.
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
nearest_hydrology_id, source_segment,
distance_numerator, distance_denominator
```

The metric query reuses the R4 sparse hydrology index. It is only a distance-
metric source and, after identity equality is proved, a causeway-culvert radius
source. It never supplies column hydrology classification, profile depth, seal
counts or water ownership. It exposes no point arrays, polylines, mutable source
row, index bucket or floating `distance_squared`. Nil identity returns all nil
values. A non-nil identity requires an accepted source segment, safe-integer
numerator and positive safe-integer denominator and retains the accepted exact
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

`query_table_allocations` counts only the two scalar query methods; the
defensive `metrics()` result table is the explicit Section 6.3 metrics-return
exception and is called only outside planner/adapter hotpaths.

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
builds its existing defensive result table, preserving the accepted R4
public return bytes and metrics exactly.

The refactor may not duplicate point/segment distance, ring traversal, stopping
or tie logic. `zones.lua` uses the scalar seam only for its private hydrology
tuple. Exact public R4 KAT parity and dedicated scalar-versus-public nearest
KATs gate the change. No other `index128.lua` behavior is in R5 scope.
Any later change to nearest distance, rings, stopping, tie order, scratch
generation or the public defensive result requires a reviewed contract
amendment; it is not a mechanical R5 implementation correction.

## 6. Bounded canonical planner representation

### 6.1 No operation object per voxel

The exact planner API is:

```text
planner_module.new(planner_source, validated_manifest, relational_lookup,
    counting_allocator, construction_identity)
  -> planner

planner:plan_slice(minp, maxp)
  -> ephemeral plan handle, plan_generation

planner:metrics()
  -> defensive scalar metrics table
```

`planner_module.new` validates the complete source/manifest/relational-lookup/
allocator allowlists, the lookup's private allocator identity and the exact
opaque construction identity created by `r5_module.new` before retaining them.
`plan_slice` accepts finite safe-integer inclusive bounds, requires positive
axis lengths within the limits below and does not accept a VM, node registry,
CID table, native heightmap or blockseed.

The planner never constructs `{x=..., y=..., z=..., ...}` tables for voxels or
runs. It represents the central owner slice as row-major x/z columns and
inclusive Y runs in reusable flat numeric arrays.

For production manifest chunksize 5, `x_count == 80` and `z_count == 80`.
Small offline fixtures may use positive axis counts no greater than 80; an
`engine_fixture` requires the production dimensions. In every case:

```text
x_count = maxp.x - minp.x + 1
y_count = maxp.y - minp.y + 1
z_count = maxp.z - minp.z + 1
column_count = x_count * z_count
voxel_count = x_count * y_count * z_count
column_index = (z - minp.z) * x_count + (x - minp.x) + 1
1 <= column_index <= column_count <= 6400
```

All three counts are positive safe integers no greater than 80. In
`engine_fixture` mode all three equal 80 and each axis satisfies
`minp.axis = -32 + 80*k`, `maxp.axis = 47 + 80*k` for one integer `k` per
axis. Equivalently, `maxp.axis == minp.axis + 79` and
`(minp.axis + 32) % 80 == 0`. Every axis also lies within the pinned mapgen
owner edges `-30912..30927`; the Y-axis integer is exactly `-386..386`.
The exact emerged area is
`emin = minp - {16,16,16}` and `emax = maxp + {16,16,16}`, hence 112 nodes
per axis. Every small offline fixture uses the same exact 16-node expansion
around its declared central bounds; this is the engine VM halo, not a rewrite
band or write entitlement, and no second fixture-halo shape exists. No plan or
adapter rounds, recentres or infers a chunk from arbitrary bounds.

A reduced x/z fixture is planner-only. Every nonempty plan passed to
`adapter:apply`, in either call mode, has `x_count == z_count == 80` and exactly
6,400 central columns so the current native heightmap seam is engine-shaped.
An `offline_fixture` may reduce only positive `y_count <= 80`; an
`engine_fixture` retains all three production dimensions and alignment rules.

The planner derives each Section 8 global analytic interval from the R3 scalar
tuple and intersects it directly with `minp.y..maxp.y` before appending a run.
It never expands such an interval into a global Y array, stores one record per
voxel, or enumerates the other 772 vertical owner slices. Consequently a broad
interval spanning the complete mapgen height still contributes at most one
short run to one opcode in the current 80-node slice.

The plan object is a retained internal handle with:

```text
schema              immutable schema string
construction_identity construction-owned opaque table reference
generation          monotonically increasing safe integer
valid               boolean
min_x/min_y/min_z    three validated scalar fields
max_x/max_y/max_z    three validated scalar fields
column_start         flat numeric array, logical length column_count + 1
run_values           flat numeric array
run_count            scalar
stable_refs          construction-owned immutable id array
```

Planner metrics live in separately preallocated planner state and are not a
nested/open field of the plan handle.

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
lexicographically sorted stable-reference array. The complete R5 aux enum is
the singleton `AUX_NONE = 0`; every P2-P6 opcode requires it. Param2 is a
content-contract result, not an aux encoding. Any other aux value is an invalid
R5 plan; R6 must use a reviewed successor schema before adding one. No run owns
a nested table.

`plan_generation` is the exact scalar copied from the handle after the call.
The handle is valid only until the same planner begins another `plan_slice`
call. After scalar input/bound validation, each attempt first sets `valid` false,
then increments generation, clears storage and builds; only complete success
sets `valid` true and returns the handle/scalar pair. Any build failure leaves
it invalid. The handle's `construction_identity` is the exact opaque reference
passed to the planner constructor; the planner never accepts or constructs a
second one. Before any VM access, the adapter requires `valid == true` and
`rawequal(plan.construction_identity, adapter_construction_identity)`, then
independently requires the separately supplied generation scalar to equal the
handle's current generation. Retaining the handle with an older returned
scalar is therefore a detectable stale-plan error even when provenance is
valid. Returning a new wrapper or token table is forbidden. Generation starts
at 0, never wraps or resets, and an attempt that cannot increment within the
safe-integer range invalidates the handle before failing. This permits storage
reuse without mutable plan aliasing across calls.

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
| base terrain normalization | 3 |
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
coexist. B+ changes global interval endpoints, not these per-slice bounds: one
ordinary fill, surface and clear candidate still contributes at most one
clipped run each, and removal of physical rewrite-band guards adds no
candidate. Complete-layout evidence measures the actual peaks again; exceeding
16/31 rejects rather than increasing either constant during implementation.
A bound breach fails `plan_slice` before VM access.

The stable-reference array is limited to 512 accepted source IDs. Construction
sorts and interns them once. Query-time interning, concatenated IDs and a
per-chunk source-table copy are forbidden.

### 6.3 Allocation and peak metrics

`counting_allocator.lua` is a pure factory dependency with this exact API:

```text
allocator_factory.new(domain_id) -> allocator
allocator_factory.new(domain_id, candidate_allocator) -> boolean
allocator:new_array(label, maximum_logical_capacity) -> table
allocator:new_map(label, maximum_key_count) -> table
allocator:grow(array, label, old_logical_capacity, new_logical_capacity)
allocator:map_put(map, label, key, value)
allocator:seal_construction()
allocator:enter_hotpath(name)
allocator:leave_hotpath(name)
allocator:metrics() -> defensive scalar metrics table
```

The two-argument form is the private, construction-only provenance check used
by the planner and adapter factories. It returns true exactly when
`candidate_allocator` was created by this same loaded allocator module for the
exact `domain_id`; a factory table that delegates to that module is equivalent.
It returns false for a copied API table, a foreign allocator or a different
domain. The check consults only module-private factory state, allocates and
mutates nothing, and exposes no additional raw field or method. All other
factory arities fail. The one-argument construction form and the raw factory
allowlist `{new}` remain unchanged.

`domain_id`, `label` and hotpath names are fixed interned contract strings.
Capacities/counts are nonnegative safe integers. Labels are unique in one
allocator. `new_array` starts at logical capacity zero; `grow` requires object
identity, exact current logical capacity, strict growth, the declared maximum
and construction phase, and fills every newly owned numeric slot with zero so
later in-capacity overwrite cannot create a new key. `new_map` accepts a
declared maximum no greater than 512. Every new non-nil map key/value pair is
inserted only through `map_put`, which verifies identity/label, construction
phase, uniqueness and capacity; deletion and raw insertion are forbidden.
After construction, direct reads and replacement of already-existing scalar
values are allowed, but no new array/map key is. `seal_construction` is exact-
once. `enter_hotpath`/`leave_hotpath` are balanced and non-nested; `new_array`,
`new_map`, `grow` or `map_put` while a hotpath is active fails immediately.
Planner and adapter receive separate allocator instances made by the one
injected `allocator_factory`; a caller-created substitute is rejected by a
private factory identity token.

All retained relational-lookup/planner/adapter arrays, maps, reusable VM
buffers, position tables, lighting value tables, plan handle and scratch tables
are created through that API during `r5_module.new`. First-use retained growth
is not allowed. Physical capacities are always the closed production maxima in
Sections 6.1, 6.2 and 11.3. A reduced offline fixture declares a smaller
logical active emerged volume, not a smaller retained allocation: the engine-
shaped proxy reads and writes only the exact active prefix, while the remaining declared
capacity is an inactive retained tail. This makes the zero-allocation hotpath
claim testable without relying on undocumented Lua table capacity.

The exhaustive allowlist of table creations not charged as R5 retained tables
is:

- Lua's module/dependency tables that exist before `r5_module.new`;
- injected R2/R3/R4 source/session, manifest, content-contract and VM-proxy
  tables owned by their respective layers;
- the two engine/VM-proxy-owned v3s16 result tables returned by the one
  `vm:get_emerged_area()` call on each nonempty adapter apply, counted as
  `emerged_area_external_table_allocations` and required to be exactly two;
- the one engine-owned heightmap array returned by the injected mapgen context
  on each nonempty adapter apply, counted separately and required to contain
  exactly 6,400 entries;
- the allocator factory's own one API table and one counter-state table per
  allocator, reported separately as bootstrap tables; and
- a defensive table returned by an explicit `metrics()` or `status()` call,
  reported as a result-table allocation and forbidden while a planner/adapter
  hotpath is active.

No other exception exists. `zero_hotpath_table_allocations` means zero
R5-owned Lua table allocations; it does not misreport the two emerged-area
position results or the one heightmap result as project-owned. In particular,
a run, voxel, candidate, dirty entry,
CID resolution, coordinate, result code or callback invocation may not allocate
a table. Static source gates reject table constructors in the transitive
`plan_slice`/`apply` hotpaths except references to the preallocated tables.
Counter ownership and every `metrics()` return allowlist are exact:

- Each `allocator:metrics()` returns exactly `domain_id`,
  `construction_table_allocations`, `construction_array_tables`,
  `construction_map_tables`, `allocator_bootstrap_tables`,
  `retained_numeric_capacity`, `retained_map_key_capacity`,
  `retained_map_key_count`, `allocator_growth_events`, `hotpath_entries`,
  `hotpath_table_allocations`, `metrics_result_table_allocations`,
  `construction_sealed` and `hotpath_active`. `allocator_growth_events` counts
  successful construction-phase `grow` calls only. `hotpath_entries` counts
  successful `enter_hotpath` calls. `hotpath_table_allocations` counts
  R5-owned tables successfully created while that allocator's hotpath is
  active and must remain zero; rejected factory calls do not allocate, while
  the static gate closes unmediated constructors.
- `planner:metrics()` returns exactly `planner_construction_count`,
  `plan_identity_count`, `stable_ref_count`,
  `plan_slice_table_allocations`, `peak_candidate_runs_per_column`,
  `peak_resolved_runs_per_column`, `peak_resolved_runs_per_slice`,
  `peak_run_value_cells`, `plan_buffer_reuse_calls` and
  `metrics_result_table_allocations`. `plan_identity_count` is exactly one and
  its empty map is already included in the planner allocator's construction
  map/table counters. `plan_buffer_reuse_calls` counts completed `plan_slice`
  calls that retain the original `column_start`, `run_values`, scratch and plan
  handle identities. There is no separate plan-buffer growth counter: all
  capacity is installed through allocator construction growth before sealing,
  and any later growth is forbidden rather than recorded under a second name.
- `adapter:metrics()` returns exactly `adapter_apply_table_allocations`,
  `emerged_area_external_table_allocations`, `heightmap_entries_validated`,
  `classified_columns`, `planned_columns`, `modified_voxels`,
  `content_dirty_columns`, `param2_dirty_columns`, `light_dirty_columns`,
  `liquid_dirty_columns`, `light_seed_runs`, `peak_light_seed_runs`,
  `vm_get_emerged_area_calls`, `vm_get_data_calls`,
  `vm_set_data_calls`, `vm_get_param2_calls`, `vm_set_param2_calls`,
  `vm_get_light_calls`, `vm_set_lighting_calls`, `vm_calc_lighting_calls`,
  `vm_set_light_data_calls`, `vm_update_liquids_calls` and
  `metrics_result_table_allocations`. External allocations are observed and
  counted here but are not R5-owned allocator events.

Every return contains scalar copies only and no nested table. No module merges
another module's metrics or iterates an open counter map. The fixture mapgen
context owns only `heightmap_fetch_calls`,
`heightmap_external_table_allocations` and its local
`metrics_result_table_allocations`; the adapter owns entry validation.
All counters start at zero and are monotonic for one constructed owner;
`planner_construction_count` and `plan_identity_count` each become exactly one
during construction. Candidate/resolved/run-value peaks are the maximum actual
logical count observed for one column or slice as named;
`peak_light_seed_runs` is the maximum explicit non-ignore seed-run count for one
apply. `light_seed_runs` is the cumulative number of those explicit runs passed
to `set_lighting` across applies. The remaining adapter dirty, column, voxel,
external-allocation and VM-call counters are cumulative; a fresh fixture
constructs fresh owners before measuring a separate case.

Acceptance requires:

- `plan_slice_table_allocations == 0`;
- `adapter_apply_table_allocations == 0`;
- aggregate allocator `hotpath_table_allocations == 0`;
- `plan_identity_count == 1`;
- every successful nonempty apply observes exactly two emerged-area external
  tables and one heightmap external table;
- at most 24 retained array tables and 8 retained map tables;
- no retained map declares more than 512 keys and total declared map-key
  capacity is at most 4,096;
- exactly two bootstrap tables per allocator instance, excluded from those two
  retained limits but included in total construction table allocations;
- no candidate/run/voxel table allocation;
- the mathematical bounds in Section 6.2;
- every plan after construction causes zero allocator growth, and a second
  equal-or-smaller plan proves reuse of the same array identities; and
- the artifact binds actual seed-zero and worst-fixture peaks.

Every module's `metrics()` returns a fresh table with its exact documented
field allowlist; its owner-local `metrics_result_table_allocations` increments
before the snapshot is copied. The artifact aggregate is the sum of the two
allocator, planner and adapter values after exactly one terminal snapshot call
to each; external fixture-contract/context metric-result tables are excluded
from that R5-owned aggregate and reported by their own proxies. Metrics calls
occur outside measured hotpaths. These are logical allocations made by the
implementation, not claims about undocumented Lua allocator bytes. Peak RSS
and elapsed time are unbound measurements with host/interpreter provenance.

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
| 3 | interfaces and engineering | `BRIDGE_DECK`, `BRIDGE_SUPPORT`, `BRIDGE_CLEAR`, `FORD_BED`, `CAUSEWAY_FILL`, `CAUSEWAY_SURFACE`, `CAUSEWAY_CULVERT`, `TUNNEL_FLOOR`, `TUNNEL_LUMEN`, `TUNNEL_WALL`, `TUNNEL_ROOF`, `HYDROLOGY_BED_SEAL`, `HYDROLOGY_BANK_SEAL`, `CONTACT_FALL_CLEAR` |
| 4 | typed paths | `PATH_FILL`, `PATH_SURFACE`, `PATH_CLEAR` |
| 5 | base terrain normalization | `TERRAIN_FILL`, `TERRAIN_SURFACE`, `TERRAIN_CLEAR` |
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

The canonical artifact contains these exact zero count rows, derived from the
complete independent analytic population rather than from a Planner metric:

```text
priority/7 = 0
priority/8 = 0
priority/9 = 0
```

The reserved opcode count rows for `BIOME_TOP`, `BIOME_FILLER`, `BIOME_SHORE`,
`BIOME_BED`, `RESOURCE_EXACT_HOST` and `DECORATION` are also exact zero from
that same complete population. Production binds those zeros independently:
the sole shared `OP_PRIORITY`/`OP_ROLE`/`OP_POLICY`/`OP_POLICY_ALT` maps contain
exactly the 26 P2-P6 opcode IDs and their 27 primary-or-sole-alternate policy
variants. The sole Production emitter is `add_candidate`; its exactly 28
Production call sites all pass the shared-map tuple guard before any candidate-
buffer write. Reserved opcode IDs `1`, `2`, `3`, `4`, `12` and `24` have no
entry in those maps. The exact second-return resolver fixture must reject each
of those six reserved P7-P9 opcode IDs and priorities 7, 8 and 9 each in an
otherwise valid emitted tuple row. The Validator checks every run in every
materialized plan handle against the closed P2-P6 priority/opcode domain.
`zero_p7_p8_p9` is true only when the complete analytic zeros, closed Production
emitter/fixture relation and every materialized-plan domain check all pass. It
is not inferred from an unowned or nonexistent Planner counter, and it adds no
metric or artifact row.

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
2. covering planned candidates are partitioned by priority and every group is
   validated before a winner is selected;
3. two candidates at the same priority are identical only when opcode, target
   role, replace policy, feature ref, interface ref and aux are all equal;
4. identical candidates coalesce; and
5. any non-identical same-priority overlap is a construction error, including
   one in a higher-number group hidden behind a valid lower-number group; then
6. the lowest numeric validated planned priority wins.

Stable IDs order diagnostics but never break a semantic conflict. There is no
last-writer-wins rule, callback-order rule or arbitrary `force` bit. Candidate
insertion/permutation order cannot change either the winner or whether any
priority group rejects.

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

The numeric policy vocabulary is `CUT_NATURAL`, `DEEP_EXACT_HOST`,
`FILL_VOID`, `OPEN_ENGINEERED`, `SEAL_VOID`, `SURFACE_EXACT` and
`WRITE_WATER`. The total resolver first applies exactly one contextual row:

| Scope | Old class | Valid heightmap condition | Result |
|---|---|---|:---:|
| ordinary P5 `TERRAIN_FILL` / `FILL_VOID` only | `AIR` or any `LIQUID` | non-sentinel `h` and `y <= h` | N |

Every other scope/class/condition continues into the complete old-class matrix
below. There is no second contextual row. This explicit first row is the B+
local native-cave preservation rule; it is not a planner decision or an
implicit policy exception.

The matrix uses `W` = write the
resolved target CID, `N` = successful content no-op, and `R` = reject the whole
transaction before a setter:

| Old class | `FILL_VOID` | `CUT_NATURAL` | `SURFACE_EXACT` | `SEAL_VOID` | `WRITE_WATER` | `OPEN_ENGINEERED` | `DEEP_EXACT_HOST` |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `AIR` | W | N | W | W | W | N | N |
| `FOREIGN` | R | R | R | R | R | R | R |
| `IGNORE` | R | R | R | R | R | R | R |
| `LIQUID` compatible | W | W | W | W | W | W | N |
| `LIQUID` incompatible | R | R | R | R | R | R | N |
| `NATIVE_ORE` | N | W | W | N | W | W | N |
| `NATURAL_HOST` | N | W | W | N | W | W | N |
| `NATURAL_SURFACE` | N | W | W | N | W | W | N |
| `NATURAL_VEGETATION` | W | W | W | W | W | W | N |
| `UNKNOWN` | R | R | R | R | R | R | R |
| `WP43_RESOURCE` | N | W | W | N | W | W | N |
| `WP43_STRATUM` | N | W | W | N | W | W | N |

`DEEP_EXACT_HOST` is reserved and cannot occur in an R5 plan. Its R6 successor
does not use this generic matrix: it writes only when the old CID is byte-
exactly the registered Y-specific host returned by the accepted stratum
provider and otherwise performs `N`; `IGNORE` still rejects. R6 must review
that exact-host seam before emission.

The content contract declares positive `ordinary_water_family_id` and
`river_water_family_id`; they may be equal. A liquid is compatible exactly when
its family equals one of those IDs and its kind is source or flowing. `none`, an
unknown family, lava or any third family is incompatible. `WRITE_WATER` also
requires the resolved target to be a source in one of those same families.
There is no name/group heuristic in the adapter.

Evaluation order is total:

1. validate the role, policy, target kind, target CID properties and param2
   tuple;
2. reject an old `IGNORE` CID;
3. classify the old CID and apply the sole contextual B+ row above;
4. if that row did not return and old CID equals target CID, skip the old-class
   matrix as a successful
   content no-op, then independently apply exact param2 if requested;
5. otherwise evaluate the one matrix cell and either
   reject, retain it for `N`, or write for `W`; and
6. apply param2 only when the resolved mode is exact and the transaction has
   not rejected. Preserve mode keeps the original byte even after a CID write.

Thus equal CID never bypasses target validation or repairs param2 by accident.
`FOREIGN`, `UNKNOWN` and `ignore` cannot reach equal-CID handling because no
role may resolve to them. An unknown CID is `UNKNOWN`, not natural, and these
three classes are unconditional transaction vetoes under every policy,
including the reserved deep-host policy. Vegetation inside an exact
`SEAL_VOID` volume is replaced by the resolved seal material. Native ore and
WP43 resources remain supporting-solid no-ops for fill/seal. They are
explicitly replaceable only through `SURFACE_EXACT`, `CUT_NATURAL`,
`WRITE_WATER` or `OPEN_ENGINEERED`: respectively the exact authored surface,
authoritative sky clear, authored water, or an exact higher-priority authored
opening. The same four policies already replace a registered WP43 stratum.
Every `R` aborts the whole transaction; only `FOREIGN`, `UNKNOWN` and `IGNORE`
are unconditional vetoes across every policy.

The content contract resolves each CID to exactly one class and supplies its
liquid family, `floodable`, exact `paramtype_light` boolean,
`light_propagates`, `sunlight_propagates` and `light_source` properties.
Missing or contradictory classification is fatal before mutation.

### 7.6 Exact content-contract seam

The injected content contract has exactly these fields:

```text
schema
ignore_cid
ordinary_water_family_id
river_water_family_id
resolve(role_id, y, aux)
classify(cid, param2)
metrics()
```

`schema` equals `grug_wp40_r5_content_contract_v1`; `ignore_cid` is the exact
engine/fixture `CONTENT_IGNORE` integer. `resolve` returns this scalar tuple:

```text
target_cid, target_kind, param2_mode, param2_value
```

`target_kind` is the exact integer enum air `0`, solid `1`, water_source `2`.
AIR role requires kind air and class `AIR`; the two source-water roles require
kind water_source and a compatible source-liquid target; every other R5 role
requires kind solid, liquid kind none and class `NATURAL_HOST`,
`NATURAL_SURFACE` or `WP43_STRATUM`. In particular, no planned role may resolve
to `FOREIGN`, `UNKNOWN`, `NATIVE_ORE`, `WP43_RESOURCE`, vegetation, air or an
incompatible liquid. These are semantic fixture classes, not an R6 registered-
node mapping; R6 must review any successor target-class vocabulary.
`CUT_NATURAL` and `OPEN_ENGINEERED` require kind air; `FILL_VOID`,
`SURFACE_EXACT`, `SEAL_VOID` and reserved `DEEP_EXACT_HOST` require kind solid;
`WRITE_WATER` requires kind water_source. Every opcode's policy and role in
Sections 7-8 must satisfy this mapping or the plan is invalid before VM access.
`param2_mode` is `0` for preserve or `1` for exact. Exact mode requires an
integer byte `0..255`; preserve mode requires nil `param2_value`.
`classify(cid,param2)` requires an integer CID and byte `param2` and returns:

```text
class_id, liquid_family_id, liquid_kind, liquid_level,
floodable, paramtype_light, light_propagates,
sunlight_propagates, light_source
```

`liquid_kind` is the closed integer enum none/source/flowing. Liquid family
zero means none; positive IDs are contract-interned families. Booleans are
actual booleans. `paramtype_light` is true exactly when the registered node's
`paramtype` string is `light`, false for every other registered value; it is
never a string, nil or truthy surrogate. `light_source` is an integer `0..14`.
Both queries allocate no table or string.
Both queries are pure for the lifetime of the adapter: repeated equal scalar
arguments return exactly equal scalar tuples, mutate no registry/contract state
other than documented scalar query counters, and perform no engine call.
Construction KATs call every used tuple twice; a difference fails before VM
access.
`liquid_level` is exactly `0` for none/source and the engine-compatible
flowing-liquid level derived from the supplied param2 byte for flowing nodes;
it is therefore never cached by CID alone. Target-property validation may use
param2 zero only for a non-liquid or source CID, whose result is param2-
independent. Every old/new dirty comparison uses the actual old/resolved final
param2 byte.

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
otherwise. The source tuple is valid only when
`authored_floor <= T <= surface_cap <= central_owner_y_max`; every non-nil
height needed by a named operation must also be a safe integer within the
central mapgen-owner edges. A required bound outside those edges is
`fail_bound`; it is never clipped into a different operation.

For inclusive interval `I = [a,b]`, define:

```text
clip_to_owner(I) = [max(a,minp.y), min(b,maxp.y)] when nonempty,
                   otherwise absent
```

Every global run is derived before this clipping. At an intermediate vertical
slice boundary, the planner derives the adjacent Y winner from the same
absolute R2/R3 facts and complete global run set. It requires the expected
analytic continuation token (the same global run, its exact endpoint, or the
exact adjacent higher-priority run) and never inspects a materialized neighbor
CID, param2, light byte or generated-state flag. The first legal broad-write Y
is exactly `authored_floor`; the last legal sky-clear Y is exactly
`central_owner_y_max`. Those are authoritative endpoints, not physical guard
locations, and no cell outside either endpoint is read or inferred.

There is no lower/upper rewrite-band guard and no materialization-dependent
bridge, tunnel or ordinary neighbor guard. Exact named-mask admissibility is
proved analytically from R2/R3 tuples and run winners. Required VM context is
limited to the current owner data used by replace policies and the Section 12
lighting box/seed row; required analytic x/z collar samples remain subject to
the declared halo. Any required context cell outside the emerged/mapgen bounds
or equal to `CONTENT_IGNORE` fails closed under Sections 9, 11 and 12. The
planner never widens ownership to obtain it.

### 8.2 Base terrain

Every R5 surface column derives these global runs and emits only their
`clip_to_owner` result:

```text
TERRAIN_FILL     authored_floor .. T-1  STRATUM_AT_Y  FILL_VOID
TERRAIN_SURFACE  T .. T             STRATUM_AT_Y   SURFACE_EXACT
TERRAIN_CLEAR    surface_cap+1 .. central_owner_y_max  AIR  CUT_NATURAL
```

An empty clipped interval is omitted. `TERRAIN_SURFACE` exists only in the
slice owning `T`. `SURFACE_EXACT` owns the exact solid-versus-void branches for
that one node, so the plan still carries one run and one policy rather than
duplicate candidates. A slice stores only its at-most-80-node clipped runs; no
per-column global array or record for another slice exists.

Unchanged eligible solid nodes below `T` remain their native CID, including a
registered stratum or native ore. Air, liquid and natural vegetation inside the
owned fill interval are presented to ordinary `FILL_VOID`; the local-heightmap
rule may preserve air/any liquid before the matrix, while a write attempt still
requires the matrix's compatible-liquid cell. The adapter's Section 10.3 rule
makes cave air/liquid at or below the native pre-cave height a successful byte-
identical no-op and permits sky-side void/liquid above it to receive
`STRATUM_AT_Y`. The planner and plan bytes do not contain or branch on that
datum.

At `T`, inside authored water above `T`, and above `surface_cap`, known
project-native ore, WP43 resource and WP43 stratum classes are explicitly
replaceable by the total Section 7.5 matrix so R3 height/water remains exact.
Foreign, unknown or `ignore` always rejects rather than leaving a contradictory
surface or protrusion.

### 8.3 Hard foundations

When `hard_foundation` is true and `K == "anchor_platform"`, priority 2
replaces the corresponding base runs over the same B+ owner-slice interval:

```text
FOUNDATION_FILL     authored_floor .. T-1  FOUNDATION_CORE     FILL_VOID
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
PATH_FILL     authored_floor .. T-1  PATH_CORE     FILL_VOID
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

P5 supplies the supporting fill and authoritative sky clear. P6 supplies named river
water for `T+1..W`; R3 requires the exact centre pin `T == W-1` and may return
the already-frozen graded approach elsewhere. No flat ford slab, new ramp or
route-wide water exception is added.

### 8.6 Bridge

For `K == "bridge_deck"`, R3 `T` remains the bed and `F` is the deck. A
**named bridge interface** is exactly a non-nil `functional_interface_id` that
equals `route_interface_id` on one accepted `source.hydrology_interfaces` row
whose `kind == "bridge"`; the row's hydrology ID must equal the classified
column hydrology ID. Require non-nil `C` and `F >= C + 4` for those named
interfaces. Every other R3-derived bridge-deck column requires non-nil `C` and
`F >= C + 2`. A non-nil interface not resolving by that rule fails. Emit:

```text
BRIDGE_CLEAR    max(T+1, C+1) .. F-2  AIR             OPEN_ENGINEERED
BRIDGE_SUPPORT  F-1 .. F-1            BRIDGE_SUPPORT  SEAL_VOID
BRIDGE_DECK     F .. F                 BRIDGE_DECK     SURFACE_EXACT
BRIDGE_CLEAR    F+1 .. F+4             AIR             CUT_NATURAL
```

An empty clear interval is omitted. The one-node complete underside across
the already-frozen visible deck footprint is the exact R5 support mask. R5
adds no pier-spacing rule, axis reconstruction or water-blocking support
column. The underside leaves at least two clear nodes above the local clearance
datum for named bridges. A derived `C+2` bridge has the exact one-node support
at `C+1` and no `BRIDGE_CLEAR` below it; its lower clear interval is empty and
omitted. R5 does not strengthen the already accepted derived threshold.

P5 continues to own the bed and P6 continues to own water through `W`. The
exact bridge headroom is the four emitted AIR nodes `F+1..F+4`: the planner
requires `F+4 <= central_owner_y_max` and emits that complete interval as
`BRIDGE_CLEAR/CUT_NATURAL`. It does not sample or constrain `F+5`. A solid P5
winner at or above `F+5` is a valid roof and neither rejects nor reclassifies
the R3 bridge nor extends its P3 clearance. The headroom bound reads no VM CID,
generated-state flag or committed neighbor byte. If `F+4` lies beyond the
central mapgen-owner edge, planning fails closed.

### 8.7 Causeway and culvert

For `K == "causeway"`, non-nil `C`, `F == T` and `T >= C + 1` are required.
P5 supplies the ordinary terrain candidate. The two `CAUSEWAY_*` P3 runs
replace its core and surface over the exact causeway mask; the `PATH_CLEAR` run
retains its schema-defined P4 priority:

```text
P3 CAUSEWAY_FILL     authored_floor .. T-1  CAUSEWAY_CORE     FILL_VOID
P3 CAUSEWAY_SURFACE  T .. T            CAUSEWAY_SURFACE  SURFACE_EXACT
P4 PATH_CLEAR        T+1 .. T+4        AIR               CUT_NATURAL
```

The displayed fill interval is the non-culvert case. The exact culvert-column
replacement below narrows it to `W+1..T-1`; an empty narrowed interval is
omitted.

A causeway column is an exact culvert column if all are true:

- its functional interface has exactly one accepted
  `source.hydrology_interfaces` row whose `route_interface_id` equals the
  functional interface ID, and the classified column hydrology identity equals
  that row's `hydrology_id`;
- the nearest-metric hydrology ID equals that already-proved classified ID and
  its exact metric denominator is positive;
- `distance_numerator <= distance_denominator`, meaning squared distance no
  greater than one node from that accepted hydrology centreline; and
- its bed `B = W - classified_profile_depth` and `W` are non-nil with `B < W`.

For those columns, P3 replaces the causeway fill over:

```text
CAUSEWAY_CULVERT  B+1 .. W  RIVER_WATER_SOURCE  WRITE_WATER
```

The P3 engineering run wins over the overlapping P5 terrain fill. Ordinary P6
water is absent because the causeway scalar has `T > W`; the culvert opcode is
therefore the sole owner of its water role. On a culvert column,
`CAUSEWAY_FILL` is restricted to `W+1..T-1`; on a non-culvert causeway column
it retains the complete `authored_floor..T-1` interval. The solid causeway remains
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

Every `TUNNEL_ROOF` and `TUNNEL_WALL` `SEAL_VOID` uses the total Section 7.5
matrix: eligible known solid, native ore, registered resource and stratum
remain unchanged; air, compatible liquid and `NATURAL_VEGETATION` are replaced
by the resolved tunnel-wall seal material. Foreign, unknown, `ignore` or an
incompatible liquid rejects the transaction.

The side-wall collar starts as the exact four-neighbor dilation of the tunnel
footprint by one column. For one candidate collar column, collect its
cardinally adjacent tunnel samples and require one shared interface ID **and**
one shared `functional_feature_id` (the accepted route ID). Exclude every
tunnel column. Also exclude a non-tunnel column whose
`functional_feature_id` equals that same route ID: those are the route's own
portal/approach columns and remain open under their P4/P5 mask. For every other
retained collar column, let `Fmin` and `Fmax` be the adjacent tunnel samples'
minimum and maximum floor values; emit:

```text
TUNNEL_WALL  Fmin+1 .. Fmax+4  TUNNEL_WALL  SEAL_VOID
```

If adjacent tunnel samples carry different interface or feature IDs, or if a
retained collar overlaps a functional surface from another route/feature,
planning fails. The excluded same-route portal is a required KAT and may never
receive `TUNNEL_WALL`. This exact one-node cardinal collar is the complete side-
wall mask; no diagonal collar, portal extension, cave flood fill or ornamental
lining exists in R5.

P5 still owns ordinary terrain around and above the tunnel. No operation
touches below the floor except the B+ ordinary fill if it independently owns
that Y.

### 8.9 Hydrology bed and bank seals

Every classified current wet hydrology profile must report exactly
`bed_seal_layers == 3` and `bank_seal_nodes == 2`. Its exact seal-water datum
`S` is ordinary/rapid non-nil `W`, or `transition_lower_y` for a contact-face
waterfall; a cardinal waterfall has nil `S`. The contact-face profile and
identity are the accepted lower reach from the transition relation, while an
ordinary/rapid column uses its classified identity/profile. A non-nil `S`
requires positive profile depth and bed `B = S - profile_depth`; emit:

```text
HYDROLOGY_BED_SEAL  B-2 .. B  HYDROLOGY_SEAL  SEAL_VOID
```

Existing eligible known solid, native ore, registered resource and stratum
remain unchanged; air, compatible liquid and `NATURAL_VEGETATION` are replaced
by the resolved hydrology-seal material. Foreign, unknown, `ignore` or an
incompatible liquid rejects. The run must remain at or above `authored_floor`;
otherwise planning fails instead of silently clipping a named surface-water
profile.

Before candidates are appended, a bed/bank seal interval subtracts every
already-defined P3 solid interface interval. The interface solid itself is an
equivalent seal. Thus a ford bed owns `B` while its bed seal owns only
`B-2..B-1`; a non-culvert causeway's complete solid fill replaces its bed-seal
candidate; and a culvert retains the disjoint `B-2..B` seal below its
`B+1..W` water lumen. If subtraction encounters a P3 open interval other than
that exact culvert relationship, planning fails rather than resolving a
same-priority conflict by order.

The bank collar is the exact Manhattan-distance-two dilation of the wet named
hydrology footprint (`S` non-nil), excluding those wet columns. The planner
samples the fixed twelve offsets with `abs(dx) + abs(dz)` in `1..2`. For a bank
column, collect all wet samples. One hydrology ID is directly compatible. For
mixed IDs, the planner first searches the construction lookup from Section 4.3
and selects the unsigned-ASCII-smallest accepted confluence/rapid/waterfall
relation containing every sampled ID. This relation takes precedence even
when every sampled `S` is equal. Only when no such relation exists does exact
equality of every sampled `S` admit the accepted R2 level-contact fallback with
a nil diagnostic interface ref. Mixed unequal-`S` samples without one accepted
relation fail. Define:

```text
seal_low  = minimum(sample_bed_y - 2)
seal_high = min(T, maximum(sample_S))
```

If `seal_low < authored_floor`, planning fails under the global broad-write
bound. If
`seal_low <= seal_high`, emit:

```text
HYDROLOGY_BANK_SEAL  seal_low .. seal_high
    HYDROLOGY_SEAL  SEAL_VOID
```

The bank seal applies the same total `SEAL_VOID` rule: eligible known solid,
native ore, registered resource and stratum remain unchanged, while air,
compatible liquid and `NATURAL_VEGETATION` are replaced by the resolved
hydrology-seal material. It never cuts or raises the scalar terrain surface.
Compatible samples are aggregated before one candidate is appended; its
diagnostic feature ref is the unsigned-ASCII-smallest contributing hydrology
ID. Its diagnostic interface ref is nil for a one-ID bank or the no-relation
equal-`S` fallback, and is the selected accepted relation ID for every related
mixed-ID bank regardless of level equality. The fixed subtraction above may
split a seal into at most three intervals and is ordinary inclusive-interval
clipping, not a CSG language. Incompatible role/identity overlap fails;
foreign, unknown, `ignore` or incompatible liquid still rejects through the
total matrix.

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
water mask is removed only through P5 `TERRAIN_CLEAR`. Ordinary native cave or
flooded-cave liquid at or below the current slice's validated pre-cave
heightmap datum is untouched by P5 fill.

For an orthogonal contact face, R3 returns nil `W`, a nonzero face mask and
upper/lower values. `lower_profile_depth` comes from the accepted lower reach
in the transition relation, never from nearest hydrology. Let the lower bed be
`lower_y - lower_profile_depth`. Emit:

```text
RIVER_WATER   lower_bed+1 .. lower_y-1  RIVER_WATER_SOURCE  WRITE_WATER
RECEIVER_OPEN lower_y .. lower_y         AIR                 OPEN_ENGINEERED
CONTACT_FALL_CLEAR lower_y+1 .. central_owner_y_max AIR       OPEN_ENGINEERED
```

An empty water interval is omitted. `RECEIVER_OPEN` is exactly one voxel deep:
it removes only the would-be top source at `lower_y`. The disjoint
`CONTACT_FALL_CLEAR` opens the complete fall room above it through the upper
mapgen owner edge, clipped independently into every owning vertical slice; it
never widens x/z ownership or constructs a global voxel array. No falling-
water run is emitted.

Rapids and cardinal waterfalls are distinct. A rapid transition retains its
ordinary non-nil R3 `W` and uses the ordinary named river-water rule
`T+1..W`. A cardinal waterfall transition has nil `W`, nil contact-face mask
and emits no `RIVER_WATER`, `RECEIVER_OPEN`, `CONTACT_FALL_CLEAR` or other
authored falling-water column; only independently applicable base/seal masks
remain. Native liquid simulation may later flow into that already-authored
geometry, but R5 does not encode or place falling water.

## 9. Owner slices, halo and mapchunk order

### 9.1 Central ownership

The callback's inclusive `minp..maxp` is the sole normal write box. The owner
of a voxel is exactly the central mapchunk containing it. Planner runs are
clipped to all three central axes before they enter the plan.

The emerged `emin..emax` halo may be read only for:

- lighting context needed by the transaction; and
- temporary lighting seeds that are restored before the final light buffer.

The twelve-offset bank collar and four-neighbor tunnel collar query only the
pure planner source at absolute x/z positions within the declared halo; they do
not read a halo VM CID, param2 or light byte. If a required analytic sample lies
outside the declared fixture/emerged halo, planning fails with `fail_halo`
before VM data access.

Content and param2 outside `minp..maxp` must be byte-identical before and after
the adapter. No x/z cleanup, neighbor feature write or anchor-owner
cross-chunk write is permitted.

### 9.2 Pull rendering

Every global feature is evaluated analytically at the current absolute
columns, then clipped to the central owner slice. A bridge, tunnel, causeway,
path, foundation or water feature crossing a chunk boundary is rendered by
each owning chunk for its own voxels. The chunk containing an anchor or source
record has no special write authority.

Vertical slices use the same absolute R2/R3 facts. They never persist a height
observed from a prior chunk, inspect a neighbor-generated flag or use a native
heightmap as authority. The planner derives global B+ intervals and clips only
the current owner slice; the adapter fetches a heightmap only after plan bytes
are complete and uses it solely for the local ordinary-P5 preservation test.

### 9.3 Order independence

The plan is a pure function of:

```text
full seed, W=1, manifest, absolute minp/maxp,
accepted R2/R3 facts, accepted R4 private seam semantics
```

Neither native heightmap nor any VM byte appears in this function domain.
Native-buffer policies may preserve or reject current content but may not
select alternative geometry. Within each fixed initial VM/halo state,
acceptance compares complete central content, param2 and light digests after
ascending, descending and deterministic random x/z and vertical chunk-request
orders. Every order uses one emerge thread. Unsupported multiple-v7-thread
determinism is not claimed.

Every seam fixture runs in two initial-halo states: pristine native v7 neighbor
buffers and the exact already-committed result of each adjacent owner chunk.
The current central plan bytes, success/failure outcome and final central
content/param2 digest must match between the two states. Central light and the
canonical light seed-run list are not required to match across those different
initial states: pinned `spreadLight` reads the complete emerged VM, and a
legitimate original halo-light difference may therefore produce a different
central light result without changing ownership or geometry. Each state must
independently match the exact Section 12.3 algorithm, bounds, pre-state-derived
seed list, call order and halo restoration. For repeated runs and ordinary
request-order permutations that begin from the same initial state, the seed
list and complete final light remain byte-deterministic. Halo content/light may
never select a different mask, guard, winner, transaction result, central
content or central param2. A violation rejects R5; no preferred request order
is documented as a workaround.

In particular, Section 12.2 computes a boundary floodable-change liquid trigger
from central bounds and the actual central change alone. It reads no halo
content/param2, so its `q` result-code suffix is identical in the pristine and
already-committed halo fixtures.

For equal full seed, absolute x/z and vertical slice, a second fixture changes
only the valid native heightmap array. Canonical plan bytes and plan digest must
remain identical; only the adapter's permitted P5 void/liquid no-op/write
outcome and the consequent dirty/light/liquid result may differ. A plan-byte or
mask difference is a height-authority violation.

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
mapgen_limit               31007
chunksize                  5
central_owner_y_min        -30912
central_owner_y_max        30927
heightmap_entries          6400
heightmap_sentinel         -31007
heightmap_order            x_fast_z_outer
emerge_threads             1
engine_emerge_setting      num_emerge_threads
mg_flags                   biomes,caves,decorations,dungeons,light,ores
mgv7_spflags               caverns,mountains,ridges
mgv7_dungeon_ymin          -31000
mgv7_dungeon_ymax          -193
authored_floor             -37
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

Manifest validation independently evaluates the pinned
`get_mapgen_edges(mapgen_limit,chunksize)` integer formula from
`reference_projects/luanti/src/mapgen/mapgen.cpp` and requires its Y pair to
equal the two bound owner edges. The pinned engine unit-test witness in
`src/unittest/test_mapgen.cpp` must bind the same pair. A source-pin, formula,
constant or result mismatch is `fail_manifest`; R5 neither changes nor queries
the live engine setting.

The bound arithmetic is exact: `MAP_BLOCKSIZE = 16` gives effective block
limit `floor(31007/16) = 1937`, node limits `-30992..31007`, central chunk
`-32..47`, full central extent `-48..63`, and
`floor(30944/80) = 386` complete chunks on each side. Therefore the returned
owner edges are `-32 - 386*80 = -30912` and
`47 + 386*80 = 30927`, exactly matching the pinned engine unit test. Separately,
`MAX_MAP_GENERATION_LIMIT` is `31007`, so `findGroundLevel`'s no-ground return
is exactly `-31007`; this derivation does not alter the independent v7 dungeon
minimum `-31000` in the manifest.

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

No P2-P7 operation may have `y_min < authored_floor`. Below the authored floor,
only the reserved R6
`RESOURCE_EXACT_HOST` operation may ever exist, and its
`DEEP_EXACT_HOST` policy cannot match dungeon, air, liquid, generic ore,
resource, `ignore`, unknown or foreign content. `force_native_dungeon = true`
is always fatal.

The existing finite native-only dungeon callback corpus remains an additional
offline proof oracle. It unions the complete emerged VM area of every positive
dungeon notification and rejects any audited target intersection. It is never
queried by production and never narrows the global vertical proof.

That corpus is frozen by the directory digest
`256d0ff33ce6748b056287d5ca056e95893d313ae7bbca243eda07dd0f33c8c7`
and these exact canonical authority inputs:

```text
tools/wp40/dungeon_probe/evidence/256d0ff33ce6748b056287d5ca056e95893d313ae7bbca243eda07dd0f33c8c7/raw.log
  5af86febe5bd509121df2ce46b2714e8d0c400cf2f37f219645c284e93adc7a4
tools/wp40/dungeon_probe/evidence/256d0ff33ce6748b056287d5ca056e95893d313ae7bbca243eda07dd0f33c8c7/summary.json
  047f74d4ae891e5e62dc5389a494ac44a9a925c680ad3d53f0966bd68ce911f6
```

The offline loader may read those bytes only through the manifest-verifying
Section 15.1 authority method. It does not execute or load either input.

The dungeon oracle parses `summary.json` as one JSON object and consumes
exactly these fields by exact key and JSON scalar type, never by substring:

```text
schema                    2
status                    PASS
json_validation           complete-jq
manifest_digest           256d0ff33ce6748b056287d5ca056e95893d313ae7bbca243eda07dd0f33c8c7
record_count              34
requested_mapchunks       81
complete_records          1
emerge_errors             0
positive_callbacks        31
positive_count_is_golden  false
mg_name                   v7
chunksize                 5
water_level               1
mg_flags                  caves,dungeons,light,decorations,biomes,ores
mgv7_spflags              mountains,ridges,nofloatlands,caverns
mgv7_dungeon_ymin         -31000
mgv7_dungeon_ymax         -193
```

`schema`, `record_count`, `requested_mapchunks`, `complete_records`,
`emerge_errors`, `positive_callbacks`, `chunksize`, `water_level`,
`mgv7_dungeon_ymin` and `mgv7_dungeon_ymax` are exact JSON integer numbers;
`positive_count_is_golden` is the JSON boolean; every other consumed value is
an exact JSON string. A duplicate consumed key, wrong type or missing consumed
key rejects.

Other summary fields remain byte-bound by the file SHA-256 but grant no R5
semantic authority. The five scalar mapgen values `mg_name`, `chunksize`,
`water_level`, `mgv7_dungeon_ymin` and `mgv7_dungeon_ymax` must compare exactly
to the corresponding Section 10.1 validated-manifest values.

For both flag strings the oracle splits on commas, trims ASCII whitespace from
each token and rejects an empty or duplicate token. `mg_flags` compares as an
order/whitespace-independent positive set exactly equal to the Section 10.1
set. For `mgv7_spflags`, the only accepted engine-style negated token is exact
`nofloatlands`; it normalizes to the significant absence of positive
`floatlands`, and the simultaneous presence of `floatlands` rejects. Any other
or additional `no...` token rejects. After removing that sole normalized
negation, the positive set must equal the Section 10.1 set exactly; missing or
extra positives reject.

The raw log must contain exactly 34 `DUNGEON_PROBE_JSON` records: one
`main_api`, one `mapgen_api`, exactly 31 positive `dungeon_event` records and
one `complete` record. Both requested-mapchunk values equal 81, the complete
count and event count equal their summary scalars, and the oracle unions every
one of those 31 event emerged boxes before testing nonintersection. The false
`positive_count_is_golden` value means 31 is provenance for this frozen corpus,
not a Production claim that another engine run must reproduce that count.

### 10.3 Local native-heightmap preservation

The adapter obtains the current native mapgen heightmap through the exact
Section 11 context seam once per nonempty apply. It validates one plain table
with no metatable, exactly 6,400 numeric keys `1..6400`, no hole and no other
key; validation uses raw access and iteration rather than `#`/`rawlen`. Index

```text
i = (z - minp.z) * 80 + (x - minp.x) + 1
```

binds absolute central column `(x,z)`: X changes fastest and Z is the outer
engine loop. Each entry `h` must be exactly
`heightmap_sentinel = -MAX_MAP_GENERATION_LIMIT = -31007` or an integer in
`minp.y..maxp.y`. Nil, boolean, non-integer, NaN/infinity, an in-range hole, an
out-of-range extra key or any other numeric value is `fail_native_heightmap`
before `get_data` or any setter. The table is discarded from adapter state when
`apply` returns or raises; it is never cached across slices or callbacks.

This datum affects exactly one matrix entry site: ordinary priority-5
`TERRAIN_FILL` with policy `FILL_VOID`, and only when the immutable old class is
`AIR` or `LIQUID`. At/below `h`, the preservation no-op applies to every liquid
family/kind/level; compatibility matters only when a write is attempted above
`h` or under the sentinel case.

- If `h == -31007`, eligible void/liquid in the owned clipped fill run is above
  the native pre-cave terrain represented by this slice and proceeds through
  the ordinary `FILL_VOID` matrix cell.
- If `minp.y <= h <= maxp.y`, air/liquid proceeds through that matrix only for
  `y > h`; an incompatible liquid there retains the matrix's transaction veto.
- At `y <= h`, ordinary P5 air/liquid is a successful byte-identical
  preservation no-op, including param2 and light input. In particular,
  `h == maxp.y` preserves every ordinary P5 air/liquid voxel in the slice.

The special no-op is evaluated after target/old-CID classification and
`CONTENT_IGNORE` veto but before the ordinary `FILL_VOID` matrix result is
recorded. It never applies to natural vegetation or a solid class. It never
applies to P5 `TERRAIN_SURFACE`/`TERRAIN_CLEAR`, or to an exact P2, P3, P4 or P6
foundation, path, interface, tunnel, seal or water operation even if that
operation uses `FILL_VOID`, `SEAL_VOID`, `OPEN_ENGINEERED`, `SURFACE_EXACT`,
`CUT_NATURAL` or `WRITE_WATER`. Those operations retain exactly the replacement
rights in the total Section 7.5 matrix and may override cave preservation only
inside their bound owned volumes.

The heightmap never changes `T`, `surface_cap`, any mask, priority, opcode,
target role, run endpoint, conflict result or plan byte. It is per-slice local
preservation evidence, not a global native surface, geometry input, operation
selector or planner input.

### 10.4 Ore, resource and stratum preservation

- No P2-P7 operation exists below `authored_floor`, and native dungeon
  preservation remains unconditionally y-disjoint under Section 10.2.
- Strictly below final authored surface `T`, a native ore, registered WP43
  resource or registered WP43 stratum remains byte-identical unless an exact
  higher-priority P2/P3/P4 authored operation owns that voxel. An ordinary P5
  fill/seal sees the existing solid as a supporting no-op.
- At exactly `T`, inside authored water above `T`, or above `surface_cap` in the
  authoritative P5 sky-clear run, those three project-native solid classes are
  explicitly replaceable through `SURFACE_EXACT`, `WRITE_WATER` or
  `CUT_NATURAL`. Otherwise R3 height/water could not remain authoritative.
- An exact P2/P3/P4 `SURFACE_EXACT`, `OPEN_ENGINEERED` or `CUT_NATURAL`
  operation may likewise replace those classes only in its owned volume;
  fill/seal remains a supporting-solid no-op.
- `FOREIGN`, `UNKNOWN` and `CONTENT_IGNORE` are unconditional transaction
  vetoes under every policy. Native/foreign provenance is never guessed from a
  node name.

These rules are complete and derive only from the total Section 7.5 matrix plus
the one explicitly scoped ordinary-P5 heightmap no-op above. No adapter branch
may add an implicit replacement or preservation exception outside them.

## 11. One VoxelManip transaction

### 11.1 Adapter API

```lua
adapter_module.new(validated_manifest, content_contract, mapgen_context,
    counting_allocator, construction_identity)
    -> adapter

adapter:apply(vm, minp, maxp, plan, plan_generation, call_mode) -> result_code
```

The closed successful result-code enum is:

```text
noop_empty_plan
noop_equal_content
applied_p
applied_pq
applied_c
applied_cp
applied_cl
applied_cpl
applied_cq
applied_cpq
applied_clq
applied_cplq
```

The suffixes mean content (`c`), param2 (`p`), light transaction (`l`) and
liquid queue (`q`). `l` requires `c`; `q` requires `c` or `p`; at least one of
`c`/`p` is present on an applied result. The implementation constructs no
result string: it
returns the corresponding interned constant. A fatal case raises an error whose
prefix is the closed failure code `fail_status`, `fail_call_mode`,
`fail_manifest`, `fail_plan`, `fail_bounds`, `fail_halo`, `fail_role`,
`fail_target`, `fail_old_class`, `fail_replace_policy`,
`fail_native_preservation`, `fail_native_heightmap`, `fail_content_ignore`,
`fail_required_context`,
`fail_lighting_context`, `fail_vm_contract` or `fail_stale_plan`. Planner
construction/planning separately uses `fail_source`, `fail_mask`, `fail_guard`,
`fail_conflict`, `fail_bound` or the shared `fail_halo`. Evidence extracts only
the prefix before the first ASCII colon. The two Section 4.4 tool-only wrappers
add exactly `fail_fixture`, and every wrapper-validation error they emit uses
that prefix: Adapter arity/scalar-domain failures and Planner scalar,
container, permutation and relation-domain failures. Shared-core conflicts and
bounds retain `fail_conflict` and `fail_bound`. `fail_fixture` is not emitted
by either Production constructor or hotpath. Missing, additional or
differently spelled codes reject.

`call_mode` is exactly `"offline_fixture"` or `"engine_fixture"` in R5. Any
production/registered mode fails before VM access. R7 must add a separate
reviewed activation capability; R5 contains no hidden boolean that enables it.
Native callback `blockseed` is not an adapter input and cannot influence an
authored plan; the canonical full seed closed over by R4/R5 construction
remains the only authored random domain.

Adapter construction validates and closes over the manifest, content contract,
mapgen context, allocator and exact opaque construction identity supplied by
`r5_module.new`. `apply` cannot substitute a different role/CID mapping,
native-data source or plan-identity domain for an existing adapter. The context
has the exact field allowlist/API:

```text
schema = grug_wp40_r5_mapgen_context_v1
get_heightmap() -> current native heightmap table
metrics() -> defensive scalar metrics table
```

R5 accepts only fixture contexts and contains no `core` reference or production
context. The R7 callback must inject the reviewed Production context whose one
`get_heightmap()` call invokes
`core.get_mapgen_object("heightmap")` exactly once and returns that sole value.
Nil or multiple-use access fails; the context may not expose biomemap,
blockseed, settings or a second native-height query. Fixture context metrics
return exactly `heightmap_fetch_calls`,
`heightmap_external_table_allocations` and
`metrics_result_table_allocations`. The first two values are exactly `1`, `1`
for a successful nonempty apply. The adapter separately reports exactly 6,400
`heightmap_entries_validated`.

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
without a heightmap fetch or any buffer method call.

### 11.2 Exact precommit order

For a nonempty plan:

1. validate internal R5 status, call mode, manifest, `rawequal` equality of the
   plan's construction identity with the adapter's retained construction
   identity, exact separately supplied `plan_generation`, plan schema,
   bounds, run canonicality, stable refs, opcodes, priorities, roles, policies
   and all content-contract CID/property tables;
2. call `get_emerged_area()` exactly once, count its two engine-owned v3s16
   result tables, and require them to equal the exact Section 6.1 16-node
   expansion, with all required lighting context rows present;
3. call the context's `get_heightmap()` exactly once, validate the exact dense
   6,400-entry order/domain from Section 10.3 and retain that returned table
   only through this apply;
4. call `get_data(data_buffer)` exactly once into a retained full-size buffer;
5. call `get_param2_data(param2_buffer)` exactly once. Old-CID classification,
   including actual flowing-liquid level, always consumes the corresponding
   immutable param2 byte even when every planned target preserves param2;
6. execute two bounded passes over the canonical disjoint resolved runs: first,
   read only the immutable content/param2 buffers, validate every planned target
   and required context cell, apply the exact ordinary-P5 local heightmap rule,
   resolve targets and collect exact dirty sets. Every non-lighting content or
   param2 read in this pass is restricted to `minp..maxp`; the Section 12.2
   liquid rule never indexes the emerged halo;
   then, after that pass can no longer fail, replay the same runs once and
   mutate only their central-owner entries in those retained buffers. The
   replay recomputes the already-validated scalar matrix cell from the still-
   original value at that not-yet-written voxel; it reads no context cell and
   stores no per-voxel decision object;
7. if a light-relevant content change exists, construct and validate the
   complete light box/seed-run plan from Section 12.3, then call
   `get_light_data(light_original)` exactly once before any setter;
8. if no content or param2 value changed, release the heightmap reference and
   return `noop_equal_content` with no setter, lighting or liquid call;
9. call `set_data(data_buffer)` exactly once iff content changed;
10. call `set_param2_data(param2_buffer)` exactly once iff param2 changed;
11. perform the single light transaction in Section 12.3 iff light dirty;
12. call `update_liquids()` exactly once iff liquid dirty, after the final
    light setter; and
13. release the heightmap reference, return a closed scalar result code and
    update retained metrics.

All fatal validation precedes step 9. The adapter performs no second content
read or content setter. It never calls a direct node API, schematic, ore or
decoration generator.

### 11.3 Full buffers and ownership proof

`get_data`, `set_data`, param2 and light calls always use the complete active
emerged volume. The four retained Lua buffers nevertheless keep their full
production capacity. Let `C = 112*112*112` be that physical capacity, let
`ex = emax.x-emin.x+1`, `ey = emax.y-emin.y+1` and
`ez = emax.z-emin.z+1`, and let `N = ex*ey*ez` be the current active volume.
Every buffer is dense on `1..C`, has no numeric key outside that range and
exposes `1..N` as its exact active prefix. Production has `N = C`; a reduced
offline fixture may have `N < C`. Its inactive tail `N+1..C` is retained only
to prove capacity:
the adapter never reads, classifies or modifies it, and the fixture binds that
tail byte-identically before and after every call.

At least one nonempty-plan `matrix` VM case has `y_count < 80` in
`offline_fixture` mode, so its inactive tail is nonempty. The proxy retains
each supplied full-buffer reference and requires every zero-initialized tail
cell to remain zero before and after each `get_data`, `get_param2_data`,
`get_light_data`, `set_data`, `set_param2_data` and `set_light_data` call and
again after `adapter:apply` returns. Exact active volume, tail length and
comparison results enter the existing `vm_call_matrix` digest and
`one_vm_transaction` proof.

The adapter may modify active retained entries only for central owner voxels,
except temporary light entries that Section 12 restores. The exact one-based
active buffer index is
`((z-emin.z) * ex * ey) + ((y-emin.y) * ex) + (x-emin.x) + 1`:
X is fastest, then Y, then Z, matching the pinned VoxelArea layout. Central
dirty-column indexing remains Section 6.1's Z-then-X order and is not reused as
a voxel index. The existing `vm_call_matrix` digest and
`one_vm_transaction` proof bind active-prefix exactness and inactive-tail
immutability; this clarification adds no second artifact row.

Evidence hashes separately bind:

- the exact validated native heightmap input bytes in engine index order;
- complete pre/post content;
- central pre/post content;
- read-only halo content;
- complete pre/post param2;
- central pre/post param2; and
- complete final light plus central final light.

Every no-op path binds exact VM call counts.

Idempotence is an adapter property, not only repeated planner-byte parity. The
double-apply fixture applies one nonempty plan to one mutable VM proxy, retains
that proxy's committed buffers, then applies the same still-current plan and
the same returned generation scalar again without resetting native input. The
second call performs its required one
`get_emerged_area`, one native-heightmap fetch, one `get_data` and one
`get_param2_data`, returns
`noop_equal_content`, and performs zero content, param2, lighting or liquid
setters/calls. Its complete buffers equal the first post-state byte for byte.
Rebuilding a fresh VM for the second call is not the double-apply KAT.

## 12. Ignore, dirty columns, lighting and liquids

### 12.1 `CONTENT_IGNORE`

The content contract receives the engine's exact `CONTENT_IGNORE` value.

- A planned target equal to `ignore` fails target validation before
  `get_emerged_area` with `fail_target`, as specified in Section 7.6.
- A current-owner replace-policy/light-context/seed cell, or a non-seed halo
  light-context cell, required for a decision and equal to `ignore` rejects the
  entire transaction. An overtop candidate that lies in the read-only halo is
  the sole lighting exception and follows the exact engine rule in Section
  12.3. Analytic vertical continuation and bridge headroom bounds read no VM
  cell.
- Analytic tunnel/hydrology collar samples contain no CID and therefore cannot
  reinterpret `ignore`; their declared-halo bound is checked separately.
- Unneeded `ignore` in a read-only emerged halo is allowed and remains
  byte-identical.
- A target role may never resolve to `ignore`.
- The adapter never converts `ignore` to air or treats it as unknown natural
  content.

Every other failure in this subsection occurs before `set_data` and is
recorded as `fail_content_ignore`, without a coordinate-dependent recovery
path.

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
Param2 is dirty only when `param2_mode == 1` and the old byte differs from the
resolved exact `param2_value`; preserve mode is never param2 dirty.

Content is light dirty if old and new nodes differ in any of:

```text
paramtype_light
light_propagates
sunlight_propagates
light_source
```

A voxel is liquid dirty only when its resolved final CID or param2 byte
actually differs from the old value and at least one of these exact relevant
conditions holds:

- old or new node belongs to a positive liquid family;
- source/flowing kind, family or actual old/final-param2 liquid level differs;
  or
- old and new `floodable` differ and the owner-local/conservative boundary test
  below succeeds.

The floodable-change test iterates exactly these six face-neighbour offsets in
the listed order and no others:

```text
(-1,0,0)
(1,0,0)
(0,-1,0)
(0,1,0)
(0,0,-1)
(0,0,1)
```

For each offset, if the neighbour lies inside `minp..maxp`, the adapter may
inspect only that central-owner neighbour's immutable old and resolved-final
CID/param2. A retained compatible-liquid neighbour means those old/final bytes
are equal and classify as one compatible liquid; finding one marks the changed
voxel liquid dirty. If any tested face neighbour lies outside `minp..maxp`, the
changed owner-boundary voxel is marked liquid dirty conservatively without
reading that halo coordinate. No liquid-dirty branch reads or classifies a VM
halo CID or param2 byte.

The conservative boundary trigger depends only on the central bounds and the
actual central floodable change. It is therefore identical for pristine and
already-committed halo bytes: plan, outcome/result code, final central content
and final central param2 remain cross-halo identical. Lighting retains its
separate Section 9.3 per-state rule.

An unchanged voxel is never liquid dirty merely because its old/final class is
liquid. In particular, an equal-CID water operation whose final param2 byte is
also equal produces no liquid-dirty entry of its own and, when no other actual
relevant change exists, no `update_liquids` call.

Dirty arrays are reset and reused without per-call table allocation. The
artifact records dirty column/voxel counts and bounding boxes by category.

### 12.3 Single light transaction

For a nonempty light-dirty set, steps 1 through 4 execute during precommit
step 7 in Section 11.2; steps 5 through 10 execute after the content/param2
setters:

1. construct the central dirty voxel bounding box;
2. expand each axis by 15 nodes, clip x/z to the emerged area and y to a range
   whose top plus one seed row remains inside the emerged area;
3. require every used light-box context cell to be non-ignore except an
   overtop candidate at `light_max.y + 1` that lies outside `minp..maxp` in the
   read-only halo, and retain `light_original` from the pre-setter call in
   Section 11. An ignore value in that exact exception is valid and remains
   byte-identical; an ignore overtop inside the current owner still rejects;
4. classify each candidate at `seed_y = light_max.y + 1` from the immutable
   pre-state plus already-resolved post-plan CID where the current owner writes
   that cell:
   - a non-ignore candidate joins the explicit canonical maximal-X seed-run
     list only when its validated post-plan CID has
     `sunlight_propagates == true` and its original packed light byte is exactly
     `15` (`day=15`, `night=0`);
   - a read-only halo candidate whose CID is `CONTENT_IGNORE` never joins a
     `set_lighting` run and is not rejected. Pinned `propagateSunlight` treats
     that ignore overtop as a sunlight seed exactly when
     `water_level < light_max.y`; equality means underground and does not seed.
     The overtop row's `+1` coordinate does not enter this threshold;
   - every other candidate does not seed. No R3 analytic sky predicate narrows
     or widens either engine-derived case. After this point no R5 validation
     may fail;
5. call `set_lighting({day=0, night=0}, light_min, light_max)` exactly once;
6. use only the prevalidated non-ignore post-plan-CID/original-light seed runs
   and call
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
arrays, not voxel objects. Their actual and peak counts are adapter/artifact
metrics. Lists and final light are bound deterministically per initial halo
state; they may differ between pristine and already-committed states only as
permitted by Section 9.3.

The central owner light box is the intersection of the expanded light box and
`minp..maxp`. The adapter never claims ownership of persistent halo light.
Order fixtures must prove that this rule converges for opened sky, sealed
caves, water, chunk tops, opaque and sunlight-propagating canopy columns, and
reversed vertical request order. The opaque-canopy KAT requires an analytically
open column with original light below 15 to produce no seed; a transparent
sunlight-propagating CID with original packed light 15 must seed. Any
read-only halo `CONTENT_IGNORE` overtop KAT must remain ignore, must not abort,
must seed when `water_level < light_max.y`, and must not seed when
`water_level == light_max.y`; this equality case closes the engine off-by-one
boundary. Each pristine/committed halo state independently binds its seed list,
final light, restored halo bytes and call trace. Any counterexample rejects R5;
implementation may not widen persistent light ownership as a fix.

A non-light-dirty transaction performs zero `get_light_data`, `set_lighting`,
`calc_lighting` and `set_light_data` calls.

### 12.4 Liquid queue

`update_liquids()` is called exactly once if and only if `liquid_dirty` is
nonempty. It occurs after `set_data`, optional param2, and the final
`set_light_data`. There is no per-column call and no call for an equal-content
water run when no other actual relevant change exists. The conservative
owner-boundary trigger from Section 12.2 requires the same single call without
reading or depending on the neighbouring owner buffer.

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

The file is canonical TSV bytes, not a loosely parsed report. It uses UTF-8,
LF (`0x0a`) after every row including the trailer, no BOM and no CR. A row is
fields joined by one TAB (`0x09`). Empty fields are forbidden. Row tags, keys,
fixture IDs, domains and enumerated tokens are literal unsigned ASCII from
their closed allowlists. Integers use minimal base-10 ASCII
(`0` or `-?[1-9][0-9]*`; `-0` and `+` reject); count and metric values are
additionally nonnegative safe integers. Booleans are exactly `true`/`false`;
SHA-256 and Git values are exact lowercase 64-/40-hex.

Only the repository-relative path field is percent encoded. Bytes in
`A-Z a-z 0-9 . _ / : + -` are literal; every other UTF-8 byte, including `%`,
TAB, LF, CR, space and non-ASCII bytes, is `%HH` with uppercase hex. Decoding
must produce valid UTF-8 without NUL. Encoding a byte that could have been
literal, lowercase hex, invalid UTF-8, an empty/`.`/`..` path component, a
leading slash or a trailing slash rejects. No other artifact field uses
percent encoding.

The complete scalar type-token vocabulary is `ascii`, `boolean`, `git40`,
`integer`, `seed` and `token_set`. `ascii` values match
`[A-Za-z0-9_./:+-]+`; `token_set` is a nonempty comma-joined list of unique
`[a-z0-9_]+` members in strict unsigned-ASCII order. `seed` is one of the four
exact Section 2.4 decimal strings and is never parsed as a Lua number. These
type tokens appear only where the row grammar supplies a type field; rows with
an implicit type reject an inserted type column.

The exact row-tag grammar, arity and cardinality is:

| Tag | Fields after tag | Cardinality |
|---|---|---|
| `schema` | literal schema token | exactly 1, first row |
| `lineage` | key, bound value | exactly one per lineage key below |
| `constant` | key, type, value | exactly one per Section 2.4 constant |
| `manifest` | key, type, value | exactly one per Section 10.1 manifest field |
| `vocabulary` | domain, integer ID, token | exactly one per closed numeric-vocabulary token below |
| `input_sha256` | encoded repo-relative path, SHA-256 | exactly one per canonical input-set member |
| `seed_kat` | ordinal, seed text, historical SHA-256, current SHA-256 | exactly 4 |
| `digest` | fixture ID, digest key, SHA-256 | exactly one per digest key below |
| `count` | fixture ID, count key, nonnegative integer | exactly one per count key below |
| `proof` | fixture ID, proof key, boolean | exactly one per proof key below |
| `metric` | fixture ID, metric key, nonnegative safe integer | exactly one per Section 14.4 bound metric/key pair |
| `artifact_sha256` | body SHA-256 | exactly 1, final row |

No comment, blank, timing, host, note, unknown tag or additional row is
canonical. Unbound measurements are written only to runner logs, never the
artifact. After the first row, row tags use the table's displayed rank;
`artifact_sha256` is forced last. The within-tag sort tuple is exactly:

| Tag | Sort tuple |
|---|---|
| `lineage` | key bytes |
| `constant` | key bytes |
| `manifest` | key bytes |
| `vocabulary` | domain bytes, numeric ID, token bytes |
| `input_sha256` | encoded path bytes |
| `seed_kat` | numeric ordinal |
| `digest` | fixture-ID bytes, digest-key bytes |
| `count` | fixture-ID bytes, count-key bytes |
| `proof` | fixture-ID bytes, proof-key bytes |
| `metric` | fixture-ID bytes, metric-key bytes |

Byte comparisons are unsigned ASCII. A duplicate complete sort tuple rejects;
`seed_kat` ordinals must be exactly `1,2,3,4` and carry the corresponding exact
seed text from Section 2.4.

For `constant` rows, the exact key-to-type partition is:

```text
ascii:
  R5_SCHEMA R5_STATUS_SCHEMA R5_PLANNER_SOURCE_SCHEMA R5_PLAN_SCHEMA
  R5_CONTENT_CONTRACT_SCHEMA R5_MAPGEN_CONTEXT_SCHEMA R5_MANIFEST_SCHEMA
  R5_ARTIFACT_SCHEMA native_heightmap_order
boolean:
  force_native_dungeon
seed:
  canonical_seed_1 canonical_seed_2 canonical_seed_3 canonical_seed_4
integer:
  project_water_level mapgen_limit chunksize max_central_axis_nodes
  max_central_columns central_owner_y_min central_owner_y_max authored_floor
  native_heightmap_entries native_heightmap_sentinel
  functional_headroom_nodes hydrology_bed_seal_layers
  hydrology_bank_seal_nodes causeway_culvert_radius_squared
  max_candidate_runs_per_column max_resolved_runs_per_column run_stride
  max_stable_refs emerge_threads
```

The value is exactly the corresponding Section 2.4 literal. For `manifest`
rows the partition is `ascii` for `schema`, `mg_name`, `heightmap_order` and
`engine_emerge_setting`; `git40` for `engine_commit`; `token_set` for
`mg_flags` and `mgv7_spflags`; `boolean` for `force_native_dungeon`; and
`integer` for every remaining Section 10.1 field. The value is exactly the
corresponding Section 10.1 literal. A wrong type token rejects even if the value
could be parsed under both types.

The exact numeric `vocabulary` domains are:

```text
opcode         every unique opcode token in Section 7.1, including P7-P9
target_role    every token in Section 7.4
replace_policy every policy token in Section 7.5
content_class  every class token in Section 7.6
aux            AUX_NONE=0
target_kind    air=0 solid=1 water_source=2
param2_mode    preserve=0 exact=1
liquid_kind    none=0 source=1 flowing=2
```

The first four domains use the one-based ordinal after strict unsigned-ASCII
sorting within that domain, exactly as Section 7 specifies. The last four use
the displayed fixed IDs. No result, failure, call-mode, dirty-category or other
string enum gains a numeric vocabulary row; its exact bytes remain bound by the
closed schema and the relevant canonical matrix digest.

Its first row is:

```text
schema	grug_wp40_simple_map_r5_artifact_v1
```

Its newline-terminated body ends immediately before:

```text
artifact_sha256	<lowercase SHA-256 of the complete body>
```

The body is every byte through the LF immediately before the trailer. The
complete-file SHA-256 is recorded by the later review, never embedded in the
artifact itself.

### 14.2 Closed lineage and input rows

The exact lineage keys are:

```text
r2_body_sha256
r2_file_sha256
r3_body_sha256
r3_file_sha256
r4_historical_body_sha256
r4_historical_file_sha256
r4_public_kat_bundle_sha256
r4_seed_0_canonical_kat_sha256
r4_accepted_targeted_kat_body_sha256
r4_accepted_targeted_kat_file_sha256
r4_accepted_implementation_commit
r4_review_file_sha256
r4_review_verdict_sha256
contract_sha256
```

`r4_accepted_implementation_commit` is the sole `git40` lineage value. Every
other lineage value is `sha256`. Each value is the exact Section 2/3 literal or
the mechanically derived current value defined there; no lineage row accepts a
path, label, placeholder or alternate digest domain.

The canonical input set is the union of: every accepted R2/R3 artifact
`input_sha256` path used by a current R5 construction; the current public R4
production dependency closure (`canonical.lua`, `deterministic.lua`,
`schemas.lua`, `validation.lua`, `index128.lua`, `simple_map.lua`, `height.lua`,
`zones.lua`, `seed_corpus.lua`, `source/simple_map.lua` and `wp40/init.lua`);
all R5 production modules and tools in Section 16 except the artifact/review;
every Section 16 must-not-change production/configuration file inspected by the
disabled/legacy-writer audit; the B+ authority bytes in
`docs/design/world_zones.md`, `docs/research/wp40-engineering-brief.md` and this
contract; the R2/R3/R4 artifacts and accepted R4 review read by preflight; and
the runner; and the two exact Section 10.2 dungeon-corpus authority inputs.
Set union is by exact repository-relative path and is sorted after percent
encoding. A canonical set member missing from the checkout or an
`input_sha256` path outside that set rejects. The artifact does not include
itself, the future R5 review, BACKLOG, ROADMAP, README, the rebase plan or a
future acceptance/status commit.

### 14.3 Closed semantic rows

The exact `digest` keys are:

```text
r4_public_kat_bundle
planner_source_scalar
planner_source_relations
stable_refs
seed_0_plan
worst_fixture_plan
candidate_shuffle
repeat_plan
mask_population
replace_matrix
conflict_matrix
preservation
ignore_matrix
dirty_matrix
vm_call_matrix
light_matrix
liquid_matrix
mapgen_edge_formula
native_heightmap_matrix
plan_heightmap_invariance
bplus_materialization
owner_slice_matrix
committed_neighbor_matrix
order_ascending
order_descending
order_permuted
adapter_double_apply
dungeon_oracle
disabled_source_audit
```

The exact `count` keys are `opcode/<every closed R5 opcode>`,
`priority/2` through `priority/9`, `mask/foundation`, `mask/path`,
`mask/ford`, `mask/bridge_clear`, `mask/bridge_support`,
`mask/bridge_deck`, `mask/causeway`, `mask/culvert`, `mask/tunnel_floor`,
`mask/tunnel_lumen`, `mask/tunnel_wall`, `mask/tunnel_roof`,
`mask/bed_seal`, `mask/bank_seal`, `mask/receiver_open`,
`mask/contact_fall_clear`, `mask/terrain_fill`, `mask/terrain_surface` and
`mask/terrain_clear`. Every key appears once with fixture ID `seed_0`. In
particular, every opcode token in Section 7.1 receives exactly one count row,
including `BIOME_TOP`, `BIOME_FILLER`, `BIOME_SHORE`, `BIOME_BED`,
`RESOURCE_EXACT_HOST` and `DECORATION`; every one of those reserved P7-P9
opcode counts and the three reserved priority counts must be zero.

The exact `proof` keys, each required `true`, are:

```text
public_r4_fields_equal
public_r4_disabled_bytes_equal
public_r4_per_seed_bytes_equal
public_r4_bundle_bytes_equal
logical_biome_passthrough
no_biome_share_input
one_horizontal_session
one_height_session
plan_identity_exact
bounded_candidate_runs
bounded_resolved_runs
zero_hotpath_table_allocations
zero_p7_p8_p9
all_masks_closed
same_priority_conflicts_reject
foreign_unknown_ignore_reject
project_native_policy_total
native_caves_locally_preserved
native_dungeons_disjoint
native_strata_typed
mapgen_edges_equal
native_heightmap_exact_once
native_heightmap_domain_closed
native_heightmap_plan_independent
ordinary_native_cave_air_preserved
ordinary_native_cave_liquid_preserved
ordinary_sky_void_filled
exact_masks_override_local_cave_preservation
topmost_authored_ground_solid_exact
authored_water_exact
no_unplanned_project_native_above_surface_cap
no_operation_below_authored_floor
owner_content_param2_only
halo_content_param2_unchanged
vertical_continuation_analytic
committed_neighbor_plan_outcome_content_param2_equal
adapter_double_apply_equal
light_halo_restored
canopy_seed_rule
ignore_overtop_sunlight_exact
per_state_lighting_exact
liquid_owner_boundary_exact
nonlighting_halo_unread
liquid_queue_exact
one_vm_transaction
callback_absent
global_publication_absent
settings_mutation_absent
legacy_writer_unchanged
emerge_threads_offline_validated
```

`fixture_id` for digests/proofs is exactly assigned as follows:

| Fixture ID | Exact digest/proof keys owned |
|---|---|
| `historical_r4` | `r4_public_kat_bundle`; the four `public_r4_*` proofs |
| `seed_0` | `planner_source_scalar`, `planner_source_relations`, `stable_refs`, `seed_0_plan`, `mask_population`; `logical_biome_passthrough`, `no_biome_share_input`, `one_horizontal_session`, `one_height_session`, `zero_p7_p8_p9`, `all_masks_closed`, `vertical_continuation_analytic` |
| `worst_fixture` | `worst_fixture_plan`; `bounded_candidate_runs`, `bounded_resolved_runs`, `zero_hotpath_table_allocations` |
| `matrix` | `candidate_shuffle`, `repeat_plan`, `replace_matrix`, `conflict_matrix`, `preservation`, `ignore_matrix`, `dirty_matrix`, `vm_call_matrix`, `light_matrix`, `liquid_matrix`, `adapter_double_apply`; `plan_identity_exact`, `same_priority_conflicts_reject`, `foreign_unknown_ignore_reject`, `project_native_policy_total`, `native_strata_typed`, `adapter_double_apply_equal`, `canopy_seed_rule`, `ignore_overtop_sunlight_exact`, `liquid_owner_boundary_exact`, `liquid_queue_exact`, `one_vm_transaction` |
| `native_heightmap` | `mapgen_edge_formula`, `native_heightmap_matrix`, `plan_heightmap_invariance`, `bplus_materialization`; `mapgen_edges_equal`, `native_heightmap_exact_once`, `native_heightmap_domain_closed`, `native_heightmap_plan_independent`, `native_caves_locally_preserved`, `ordinary_native_cave_air_preserved`, `ordinary_native_cave_liquid_preserved`, `ordinary_sky_void_filled`, `exact_masks_override_local_cave_preservation`, `topmost_authored_ground_solid_exact`, `authored_water_exact`, `no_unplanned_project_native_above_surface_cap`, `no_operation_below_authored_floor` |
| `owner_order` | `owner_slice_matrix`, `committed_neighbor_matrix`, `order_ascending`, `order_descending`, `order_permuted`; `owner_content_param2_only`, `halo_content_param2_unchanged`, `committed_neighbor_plan_outcome_content_param2_equal`, `nonlighting_halo_unread`, `light_halo_restored`, `per_state_lighting_exact` |
| `dungeon` | `dungeon_oracle`; `native_dungeons_disjoint` |
| `disabled` | `disabled_source_audit`; `callback_absent`, `global_publication_absent`, `settings_mutation_absent`, `legacy_writer_unchanged`, `emerge_threads_offline_validated` |

The common module contains this literal key-to-fixture table and the artifact
validator compares it exactly. The following prose defines
what those closed rows summarize; it does not authorize more row tags or keys:

- all Section 2 schemas/constants and the complete manifest;
- the total P2-P6 opcode-to-priority/role/closed-policy-set relation as one
  canonical `candidate_shuffle` witness row per opcode, including exactly the
  sole `BRIDGE_CLEAR -> {OPEN_ENGINEERED,CUT_NATURAL}` two-policy set and no
  other alternate; the Validator derives and compares the Planner and Adapter
  relations independently rather than copying either module's table;
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
- every exact mask population: foundations, paths, ford, bridge clear/support/
  deck, causeway and culvert, tunnel floor/lumen/wall/roof, bed/bank seals,
  receiver opens, contact-fall clears and B+ terrain fill/surface/clear;
- candidate/resolved run peaks and all allocation metrics;
- shuffled-candidate and repeated-plan canonical parity, including a
  non-identical same-priority pair, a non-identical same-priority triple hidden
  behind a valid lower-number winner, and deterministic rejection under every
  exercised permutation;
- owner-slice and read-only-halo content/param2 digests, plus deterministic
  per-initial-state seed-run/final-light digests without cross-state light
  equality;
- ascending/descending/permuted horizontal and vertical order digests;
- content class and replace-policy outcome matrix;
- total seal outcomes for tunnel roof/wall and hydrology bed/bank operations,
  including vegetation replacement;
- exact dungeon vertical proof rows and finite-oracle nonintersection;
- mapgen-edge derivation and the exact 6,400-entry heightmap order/domain/call
  count;
- B+ cave/ore/stratum/resource/foreign/unknown preservation fixtures, including
  plan-byte independence from the heightmap and final top/water/sky assertions;
- ignore target/context/unneeded-halo fixtures;
- no-op/content/param2/light/liquid dirty matrices and exact VM call counts,
  including all six owner-local liquid faces, every owner boundary face and
  zero non-lighting halo classification, plus a reduced-Y active-prefix case
  with a nonempty, zero-initialized inactive tail verified before and after
  every buffer call and after adapter return;
- sky-open, sealed-cave, water and chunk-top light fixtures, including the exact
  `CONTENT_IGNORE` overtop inequality and equality boundary;
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
allocator_bootstrap_tables
retained_numeric_capacity
retained_map_key_capacity
retained_map_key_count
allocator_growth_events
hotpath_entries
hotpath_table_allocations
plan_identity_count
stable_ref_count
plan_slice_table_allocations
adapter_apply_table_allocations
emerged_area_external_table_allocations
heightmap_fetch_calls
heightmap_entries_validated
heightmap_external_table_allocations
metrics_result_table_allocations
peak_candidate_runs_per_column
peak_resolved_runs_per_column
peak_resolved_runs_per_slice
peak_run_value_cells
plan_buffer_reuse_calls
classified_columns
planned_columns
modified_voxels
content_dirty_columns
param2_dirty_columns
light_dirty_columns
liquid_dirty_columns
light_seed_runs
peak_light_seed_runs
vm_get_emerged_area_calls
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

The first three session/source counts are owned by `r5_module.new` evidence.
The construction/capacity, `allocator_growth_events`, `hotpath_entries` and
`hotpath_table_allocations` rows are exact sums of the two allocator snapshots.
Planner ownership begins at `planner_construction_count` and separately covers
`plan_identity_count`, `stable_ref_count`, `plan_slice_table_allocations`, all
four plan peaks and `plan_buffer_reuse_calls`. The mapgen context owns
`heightmap_fetch_calls` and `heightmap_external_table_allocations`; the adapter
owns `heightmap_entries_validated`,
`emerged_area_external_table_allocations`, `adapter_apply_table_allocations`
and every counter from `classified_columns` through
`vm_update_liquids_calls`. `metrics_result_table_allocations` is only the exact
Section 6.3 terminal-snapshot aggregate bound by this Section 14.4. No metric
has two owners or an implicit alias.

Every listed key has exactly one `metric` row with fixture `seed_0`. In
addition, `worst_fixture` has exactly one row for
`construction_table_allocations`, `construction_array_tables`,
`construction_map_tables`, `allocator_bootstrap_tables`,
`retained_numeric_capacity`, `retained_map_key_capacity`,
`retained_map_key_count`, `allocator_growth_events`, `hotpath_entries`,
`hotpath_table_allocations`, `plan_slice_table_allocations`,
`adapter_apply_table_allocations`, `metrics_result_table_allocations`,
`peak_candidate_runs_per_column`, `peak_resolved_runs_per_column`,
`peak_resolved_runs_per_slice` and `peak_run_value_cells`; `matrix` has exactly
one additional row for `emerged_area_external_table_allocations`,
`light_seed_runs`, `peak_light_seed_runs` and each `vm_*_calls` key; and
`native_heightmap` has exactly one additional row for `heightmap_fetch_calls`,
`heightmap_entries_validated` and `heightmap_external_table_allocations`. The
successful nonempty matrix fixture binds
`emerged_area_external_table_allocations = 2` and
`vm_get_emerged_area_calls = 1`; the successful nonempty native-heightmap
fixture binds its three values to `1`, `6400` and `1`. Failure fixtures bind
their exact validated-prefix count in the
`native_heightmap_matrix` digest rather than gaining metric rows. No other
fixture/key pair is allowed.

Elapsed time, CPU time, peak RSS, host, interpreter and full-buffer byte
estimates are printed only in the runner log's explicitly unbound section, not
as artifact rows. They do not participate in canonical byte-repeat identity
and establish no absolute gate.

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
buffers, `CONTENT_IGNORE` and injected content properties. The first `dofile`
return of `simple_map_r5_vm.lua` remains the exact raw module table
`{new = function}`. Its exact second, tool-only `dofile` return is:

```text
new_paired_context_fixture(heightmap_source)
  -> mapgen_context, trace_token
```

`heightmap_source` is one plain Validator-owned mutable table. The fixture does
not validate or copy its entries at construction: each real
`mapgen_context.get_heightmap()` call makes the one defensive external table
copy from its then-current keys and values, including deliberately malformed
values, holes or extra keys which the Adapter itself must reject. The returned
context retains the exact Section 11.1 three-field allowlist and owns only its
documented fetch/external-allocation metrics. `trace_token` is an opaque
function capability with no fields and no callable public command: only the
VM module's private unexported authority may bind it. The Validator receives
no trace append function and never receives the VM-owned live trace table.

The exact VM constructor forms are:

```text
vm_module.new(spec) -> vm, mapgen_context, observer
vm_module.new(paired_spec, trace_token) -> vm, mapgen_context, observer
```

The one-argument form and its exact ten-field `spec` remain unchanged. The
two-argument form requires the same exact fields except that `heightmap` is
absent; its heightmap authority is the source retained by the already-created
paired context. It authenticates and binds the live token, returns that exact
pre-created context by `rawequal`, and advances a private binding generation.
Binding a later VM proxy to the same token makes every method of an older
proxy reject before recording or buffer access; repeated applies to the
currently bound same VM remain valid. The context's real heightmap fetch calls
the current VM's private recorder, so each successful nonempty apply records
the direct prefix `get_emerged_area`, `get_heightmap`, `get_data`,
`get_param2_data` in that exact order. Empty-plan and pre-VM failure paths add
no entry. Observer call counters remain VM-owned and context counters remain
context-owned; neither aliases the Adapter's validation metrics.

These paired fixtures reject any method outside Sections 10.3/11.1 and record
exact cross-seam call order and count. Their request, context, private state,
opaque token and defensive result tables are tool-only allocations made
outside the two R5 counting allocators. They do not change or enter the exact
Production construction/hotpath allocation totals in Sections 6.3 and 14.4.

The offline-loader object contains exactly these ten callable fields:

```text
raw_sha256
sha256_call_count
preflight
input_manifest
verify_input_manifest
read_bound_input
read_current_input
loaded
load_public
load_r5
```

`load_r5(full_seed_string, manifest_values, content_contract,
mapgen_context_or_request)` keeps exactly four arguments. Its fourth argument
is either the exact existing Section 11.1 context or this exact plain two-field
tool request:

```text
schema = grug_wp40_r5_paired_context_request_v1
heightmap = heightmap_source
```

For the request form, Offline captures the VM file's exact second `dofile`
function, constructs the paired context/token before the one R5 construction,
passes only the resulting real context to `r5_module.new`, and returns exactly
`loaded_record, mapgen_context, trace_token`. For the ordinary context form it
returns only `loaded_record` as before. The request object itself never reaches
Production. The loader fails closed on a metatable, missing/additional field,
non-table heightmap source, wrong VM second return, non-context result or
non-function token.

`read_bound_input(relative_path) -> byte_string` accepts only the two exact
Section 10.2 paths and the nine exact Section 16 must-not-change paths. In both
full and manifest-gated loader modes it first verifies the complete frozen
current input manifest and contract digest, then requires the selected
manifest digest and the freshly read current-file digest to equal the
corresponding literal SHA-256 from Section 10.2 or Section 16. Any other path,
missing file, digest difference or incomplete manifest rejects. The method
performs only a binary read; it never calls `dofile`, `loadfile`, `load`,
`require` or a shell parser on those bytes.

`read_current_input(relative_path) -> byte_string` is the separate cyclic-
manifest-safe current-source audit seam. It accepts only a plain safe
repository-relative path present in the frozen canonical input-manifest
roster. It immediately calls `verify_input_manifest()`, obtains the exact
lowercase SHA-256 from `manifest.digests[relative_path]`, freshly reads the
current file and requires its digest to equal that manifest value. A path
outside the frozen roster, an encoded/unsafe path, missing or malformed digest,
missing file or byte difference rejects. This method also performs only a
binary read and never calls `dofile`, `loadfile`, `load`, `require` or a shell
parser.

Common exports defensive copies named `R5_MODIFIED_PARENT_PATHS`,
`R5_PRODUCTION_PATHS`, `R5_TOOL_PATHS`, `R5_OFFLINE_METHODS`,
`MUST_NOT_CHANGE_PATHS` and `MUST_NOT_CHANGE_SHA256`.
`R5_MODIFIED_PARENT_PATHS` contains exactly
`mods/MAPGEN/grug_mapgen/wp40/index128.lua` and
`mods/MAPGEN/grug_mapgen/wp40/zones.lua`. `R5_OFFLINE_METHODS` contains the
exact ten displayed callable names in displayed order; the Validator requires
that exact plain loader-table keyset and every value callable. The digest map's
exact keyset equals the duplicate-free must-not-change path array in both
directions. Common deliberately does not pin any R5 current source, including
itself: the disabled audit reads the exact set union of modified-parent,
Production and tool rosters through `read_current_input`, while only the two
dungeon inputs and nine immutable legacy/configuration inputs use
`read_bound_input` and literal authority digests. This separation creates no
self-hash cycle and no second canonical input roster.

The exact first `load_r5` result allowlist gains only
`planner_candidate_fixture` and `adapter_replacement_fixture`. They are the
raw second `dofile` functions from Section 4.4. All existing return fields and
the constructed production session/planner/adapter remain unchanged; no
authority, context or token field is added to this return record. The paired
form's two additional Lua return values are the exact tuple above and are not
record fields.

### 15.2 Full LuaJIT evidence

Long and exhaustive work runs only under LuaJIT. The authoritative R5 run:

1. performs the historical/current lineage preflight before executable load;
2. proves per-seed current public R4 KAT bytes equal the corresponding
   historical bytes, then proves the exact four-seed framed bundle parity;
3. validates the complete private scalar seam against the same R2/R3/R4
   sessions, including byte-identical `logical_biome_id == biome_at(x,z)`
   pass-through for every sampled column;
4. scans all R3 functional/interface and transition footprints for exactly one
   closed R5 mask result;
5. proves the pinned mapgen-edge formula, B+ analytic interval endpoints,
   `authored_floor`, complete central Y-slice roster and sixteen/31 per-slice
   run bounds over the seed-zero relevant layout;
6. runs the complete class/policy/conflict/ignore matrix, including project-
   native solids below `T`, at `T`, in authored water and above `surface_cap`;
7. runs the exact native-heightmap and B+ fixture matrix in Section 15.3;
8. runs owner-slice and horizontal/vertical order populations from both
   pristine and already-committed neighbor halos, requiring identical
   plan/outcome/central-content/central-param2 results across states while
   validating each state's seed list and lighting result independently;
9. runs every dirty/light/liquid VM-call fixture, including all six in-owner
   retained-liquid faces and all six conservative owner-boundary faces with
   non-lighting halo classification forbidden;
10. shuffles candidate production order without changing canonical plan bytes;
11. applies representative nonempty plans twice to the same VM proxy and proves
    exact second-apply no-op behavior;
12. runs twice to byte-identical artifact bytes; and
13. verifies immutable input hashes before and after all workers.

The full seed-zero layout lane has one canonical horizontal population. Let
`owner_min(v) = -32 + 80 * floor((v + 32) / 80)`. For accepted `source.extent`,
the relevant inclusive rectangle is exactly
`x = owner_min(extent.min_x) - 80 .. owner_min(extent.max_x) + 159` and the
same formula for Z. This is the complete owner-aligned covering rectangle plus
one outer owner chunk on every side. Its source-scan rectangle is that
rectangle dilated by exactly two columns on every side. The Validator
traverses this one expanded rectangle in
absolute Z then absolute X order. For each absolute `(x,z)` it calls
`column_values_at(x,z)` exactly once. It calls
`hydrology_metric_values_at(x,z)` at most once and only when the scalar tuple
requires the Section 8.7 exact rational hydrology test. A per-owner-chunk
rescan, overlapping collar scan or second scalar query for witness selection
rejects.

One rolling, independent scalar oracle consumes that scan and owns the full
analytic clipped-run, opcode, priority and mask counts across every affected
vertical owner slice. It derives intervals and their owner clipping directly
from the accepted scalar tuples and Section 8 rules; it never obtains a count
from a Planner plan, run buffer or materialized event population. The full
analytic counts and the plan-digest population are therefore distinct evidence
domains even though selected plan receipts must equal the oracle.

The bounded materialized population uses exactly these internal witness keys,
which are digest-preimage receipts and add no artifact row or key. Its relation
key grammar is
`relation/<OPCODE_TOKEN>/<POLICY_TOKEN>/<POSITION>`, with exact closed
uppercase vocabulary tokens and `POSITION` exactly `start`, `end` or
`continuation`. The closed relation population is the 26 emitted primary
opcode/policy pairs plus the sole `BRIDGE_CLEAR/CUT_NATURAL` alternate, exactly
27 variants. `start` and `end` are required for every analytically present
variant. `start` selects the owner slice containing the first Y of the resolved
interval and `end` selects the owner slice containing its last Y; each uses the
canonical-least eligible occurrence under the tuple below. `continuation` is
required if and only if at least one resolved interval for that variant crosses
a complete strict-interior owner slice; it
selects the first such interior slice for the canonical-least occurrence.

The eleven fixed keys are exactly:

```text
fixed/owner_min
fixed/owner_max
fixed/below_floor_owner
fixed/authored_floor
fixed/equal_surface_mixed_bank
fixed/terrain_y
fixed/surface_cap
fixed/first_sky_clear
fixed/roofed_bridge_headroom
fixed/peak_candidate
fixed/peak_resolved
```

For every key, canonical-least selection compares the exact five signed safe-
integer tuple `(chunk_min_z, chunk_min_x, absolute_column_z,
absolute_column_x, owner_min_y)` numerically from left to right. Plan groups and
their digest rows sort by `(chunk_min_z, chunk_min_x, owner_min_y)` numerically
ascending; attached witness keys within one plan sort by unsigned-ASCII bytes.
One receipt is either `run/<the nine exact Section 6.1 run scalars>` or the
literal `absent`. `fixed/owner_min` selects `y = -30912` and
`fixed/below_floor_owner` selects `y = -38` in owner slice `-112..-33`; both
require `absent`. Every relation receipt and the other nine fixed receipts
require the exact selected run. When a fixed peak column/owner slice contains
more than one run, its receipt selects the run with the numerically lowest
`y_min`; canonical plan order breaks no additional tie. `fixed/owner_max`
selects `y = 30927`, and
`fixed/authored_floor` selects `y = -37`. `fixed/terrain_y` selects `T` at its
canonical-least eligible column. `fixed/surface_cap` and
`fixed/first_sky_clear` select respectively `max(T,C)` and `max(T,C) + 1` at
their canonical-least eligible columns, each of which requires `C ~= nil`.
`fixed/roofed_bridge_headroom` selects the exact upper
`BRIDGE_CLEAR/CUT_NATURAL` run at `F+4` for the canonical-least R3-derived
unnamed bridge with `surface_cap >= F+5`. On the accepted seed-zero layout that
canonical tuple is exactly `x = -1916`, `z = -2071`, `T = 61`, `W = C = 19`,
`K = bridge_deck`, `F = 39`, `functional_feature_id = poi_spur_025` and
`functional_interface_id = nil`; its selected Y is therefore `43`. This
receipt proves that the four emitted headroom nodes remain clear while the P5
solid roof beginning at `F+5` remains valid.
`fixed/equal_surface_mixed_bank` has the singleton eligible coordinate
`x = -456`, `z = -1490` on the accepted seed-zero layout. Its fixed twelve-
offset population has exactly three wet samples: two
`hydro_whitebridge_main` samples and one `hydro_whitebridge_ford` sample. All
three have `S = 17`; the main and ford profile depths are respectively `4`
and `1`, so `seal_low = 11`, `seal_high = min(T,17)`, the diagnostic feature
ref is `hydro_whitebridge_ford`, and the diagnostic interface ref is nil. The
fixed P3 subtraction is applied before witness selection. The receipt requires
the surviving resolved `HYDROLOGY_BANK_SEAL/SEAL_VOID` run with the numerically
lowest `y_min`; no surviving run or an attached interface rejects. It never
reports the unsubtracted `11..min(T,17)` interval as a resolved run unless its
endpoints actually survive unchanged.
`fixed/peak_candidate` and
`fixed/peak_resolved` use the canonical first column/owner-slice attaining the
independently derived per-owner-slice maximum, never an unclipped global
candidate total.

Identical `(chunk_min_z, chunk_min_x, owner_min_y)` groups share one real
`plan_slice`; no witness causes a duplicate call. There are at most
`27 * 3 + 11 = 92` keys and therefore at most 92 deduplicated real
`plan_slice` calls. Plan digests cover only this sorted materialized corpus;
canonical counts remain the independent oracle's complete analytic
population. All existing artifact keys, row cardinalities and fixture ownership
remain unchanged. This is the exact proof of the per-slice formula without an
unnecessary 773-fold plan-slice population.

The retired exact-T2 W/PCC/F1/F2/compiler/topology populations do not run.
R5 validates the simple accepted geometry and its own bounded plan only.
It does not gate or report realized biome area shares. The global all-16-ID
coverage gate, exact `0..99` roll partition and seed-zero realized-share
evidence belong to the accepted R4 lineage; R5 re-proves only deterministic,
unchanged scalar pass-through.

### 15.3 PUC Lua 5.1 KATs

For R5 interpreter scheduling, Sections 15 through 17 and the interpreter stop
condition in Section 19 supersede the older intermediate/targeted-PUC wording
in `docs/research/wp40-simple-map-rebase-plan.md` Section 8,
`docs/research/wp40-engineering-brief.md` Sections 5 and 8 and
`docs/design/world_zones.md`. Those statements remain historical R1-R4
evidence only; no game-design, map or validation semantics are superseded.

After every relevant final R5 Lua byte is frozen, exactly one executable PUC
Lua 5.1 process runs one compact canonical micro-KAT at canonical seed `0`.
The fixture loads every R5-changed Production module and covers exactly the
following required case families; one process and one KAT may carry multiple
labeled assertions:

- all planner-source tuple nil/non-nil branches;
- representative logical-biome columns whose private scalar is byte-identical
  to the same public R4 `biome_at(x,z)` result; this KAT makes no population,
  presence or realized-area assertion;
- one route and one hydrology column comparing the private scalar nearest tuple
  with the corresponding public `nearest_segment` result, including feature
  id, raw segment ordinal and rational squared-distance numerator/denominator;
- every P2-P6 opcode and every replace policy through a real
  Planner-to-Adapter KAT; for each opcode the Adapter must accept exactly the
  Planner relation's priority, role and closed policy set, including both
  `BRIDGE_CLEAR` policies and no other alternate policy;
- same-priority conflicting pair, hidden conflicting triple and their
  permutations, plus a conflict-free cross-priority winner;
- `authored_floor = -37`, lower/upper mapgen owner edges and analytic
  continuation without physical rewrite-band guards;
- derived `C+2` and named `C+4` bridge support; the exact accepted seed-zero
  roofed derived-bridge plan at `x = -1916`, `z = -2071`, whose upper
  `BRIDGE_CLEAR/CUT_NATURAL` run includes `F+4 = 43` while a P5 solid roof may
  begin at `F+5`; culvert radius boundary, same-route tunnel portal exclusion,
  tunnel collar and roof;
- tunnel roof/wall and hydrology bed/bank seal rows proving known solid/ore/
  resource/stratum preservation, air/compatible-liquid/vegetation replacement
  and matrix vetoes; the exact equal-`S` mixed bank at `x = -456`, `z = -1490`
  with two `hydro_whitebridge_main` samples, one `hydro_whitebridge_ford`
  sample, `S = 17`, depths `4/1`, `seal_low = 11`,
  `seal_high = min(T,17)`, smallest feature `hydro_whitebridge_ford` and nil
  interface, with its receipt selected only from the post-P3-subtraction
  surviving bank-seal runs; plus an equal-`S` related bank that retains its
  accepted relation, an unequal-`S` related bank and an unequal-`S` unrelated
  rejection, rapid/cardinal-waterfall distinction, full contact-face fall clear
  and the exact one-source receiver omission;
- native top at `T-17` and `T+17`, plus native top exactly on a vertical owner-
  slice boundary;
- heightmap sentinel `-31007`, an internal height, `h == maxp.y`, every invalid
  value class, a hole, and an extra key;
- ordinary native cave air and flooded-cave content at/below `h` preserved,
  while sky-side void above `h` fills through `T`;
- ore/resource/stratum retained strictly below `T`, replaced at `T`, replaced
  inside authored water above `T`, and removed above `surface_cap`;
- exact foundation/path/interface/tunnel/seal/water masks overriding local cave
  preservation only inside their owned volumes;
- multi-slice ascending, descending and deterministic shuffled generation,
  including a native top on the boundary;
- equal seed/x/z/slice plan bytes and digest under different valid native
  heightmaps, with only the adapter preservation result allowed to differ;
- final topmost authored ground solid exactly `T`, exact authored water, no
  unplanned project-native solid above `surface_cap`, no P2-P7 operation below
  `authored_floor`, and the disjoint dungeon oracle. A bridge deck or other
  explicit higher-priority functional solid remains its separately bound R3
  `F` result and is not misclassified as scalar ground;
- ignore target, ignore required context and unneeded halo ignore;
- no-op/content/param2/light/liquid call matrices, including opaque and
  sunlight-propagating canopy seeds plus a read-only halo ignore overtop on
  both sides of the exact `water_level < light_max.y` boundary;
- each of the six exact liquid face offsets for an interior floodable change
  with/without a retained compatible liquid, each of the six owner-boundary
  faces with deliberately different pristine/committed halo CIDs that are never
  classified, and equal-CID/equal-param2 water with no other actual change;
- a horizontal and reversed vertical owner/order fixture in both pristine and
  committed-neighbor halo states, with cross-state equality limited to plan,
  outcome, central content and central param2 and exact per-state lighting;
- a true same-VM adapter double apply;
- stale plan generation, foreign construction identity, foreign/copied/wrong-
  domain allocator provenance and missing content role; and
- exact seed-zero public R4 KAT and disabled-loader parity.

The compact Micro constructs exactly one R5 session/planner/adapter tuple and
therefore invokes `r5_module.new` exactly once. That construction uses one
paired context request and the same authenticated context/token is rebound
sequentially to every Micro VM; it is never replaced by a second context or a
second R5 construction. The sole fixture content contract copies and retains
exactly two immutable exception tuples at construction:

```text
missing:       target_role_id = 14 (STRATUM_AT_Y), y = 30927, aux = 0
               -> nil
target-ignore: target_role_id = 2 (BRIDGE_DECK), y = 30927, aux = 0
               -> ignore_cid, target_kind = SOLID (1),
                  param2_mode = PRESERVE (0), param2_value = nil
```

The Section 8.6 bridge headroom rule `F + 4 <= central_owner_y_max`
structurally implies every real bridge-deck Y is at most `30923`; therefore the
target-ignore tuple cannot collide with positive bridge evidence. Every
positive Micro plan is required to exclude both exact exception tuples. One
terminal missing-content-role KAT
rewrites one real canonical `TERRAIN_FILL` run at the missing tuple. The other
terminal negative KAT rewrites one real upper-owner canonical opcode-6
`BRIDGE_DECK` run at the target-ignore tuple. Each supplies a real currently
bound VM proxy, requires `fail_target` before `get_emerged_area`, and retains
an empty observer trace. The contract's resolver fixture compares the six
copied exception scalars and does not expose or consult a mutable toggle. A
second `load_r5`, second `r5_module.new` or post-construction mutation of
either exception semantics rejects the Micro.

The same micro-KAT fixture runs exactly once under LuaJIT. Its complete
newline-terminated canonical byte string and canonical digest must be
byte-identical to the PUC result. The fixture constructs no four-seed R4
foundation fleet, full layout population, 32-seed population, full VM/order
fleet or exhaustive scan; Section 15.2 owns those proofs under LuaJIT. The
single real accepted-session exercise is the seed-zero public R4 KAT above.

If any relevant final Lua byte changes after this pair, both old results are
invalid acceptance evidence and the corrected frozen candidate receives one
replacement PUC process and one replacement LuaJIT process. More than one PUC
runtime on the same final bytes requires either a concrete interpreter-specific
finding or an explicitly identified uncovered plain-5.1 risk. Seed count,
intermediate milestones and reviewer duplication are not such reasons. Exactly
one successful PUC result for the finally reviewed bytes remains current
acceptance evidence.

### 15.4 Interpreter selection and parallel execution

`WP40_LUA_BIN` may select the authoritative executable for development,
selftest, quick and full-evidence LuaJIT lanes. Those lanes start no PUC runtime.
If unset, the runner uses `/usr/bin/luajit` when executable, otherwise the first
`luajit` on `PATH`, and fails if neither exists. Before any long/full work it
executes a bounded identity probe and requires
`type(rawget(_G,"jit")) == "table"`; an override that is PUC or another Lua
interpreter fails rather than running the exhaustive population. The targeted
PUC executable is exactly repository-owned `tools/bin/lua51` and is never
selected through `WP40_LUA_BIN`. Both interpreters' version strings and
executable digests are logged.

The distinct final-conformance lane starts exactly one PUC micro-KAT process
and exactly one matching LuaJIT micro-KAT process against the same immutable
input manifest. Each writes a separate LF-canonical output and status file;
the runner requires exit zero, byte identity and digest identity before any R5
artifact promotion. It records both executable/version digests, the complete
fixture input manifest digest, both output file/body digests and both exit
statuses. The final review record binds those values. The lane schedules no
PUC seed, shard or population fleet. A relevant input-byte change invalidates
the pair as specified in Section 15.3.

At most seven Lua processes run concurrently across the workstation. The two
final micro-KAT processes may run concurrently and consume two of those slots.
Every worker receives immutable inputs, writes to a separate scratch/output
path and runs at `chrt --idle 0` plus `ionice -c3`. A deterministic single
merge orders all shards and refuses missing, duplicate or unexpected outputs.
Jobs that share mutable outputs or depend on execution order are not
parallelized. Historical eight-worker measurements grant no eighth slot.

### 15.5 Static gates

When implementation exists, every changed Production and tool Lua file passes:

- `tools/bin/luac51 -p`;
- changed-mod `SETGLOBAL` inspection;
- the five explicit Lua 5.1/sandbox/escape sweeps;
- separate equivalent sweeps over every changed `tools/wp40/*.lua` file; and
- source audits proving the disabled/no-second-evaluator rules and that every
  content/param2 index used by liquid-dirty adjacency is within the central
  owner bounds; an out-of-owner face is tested by coordinates only.

The runner first proves `rg` exists and passes `bash -n`. This draft task runs
none of those gates because it creates no implementation.

## 16. Deliverables and owned files

The pre-implementation B+ decision commit is the first exact authority-bundle
exception: it changes only `docs/design/world_zones.md`, this contract,
`docs/research/wp40-engineering-brief.md` and
`docs/research/wp40-simple-map-rebase-plan.md`. It creates no implementation,
artifact, review or status claim. After that decision receives a clean
independent contract review, the user-authorized pre-implementation
interpreter-policy amendment is the second exact authority-bundle exception.
It changes only `AGENTS.md`, `docs/research/luanti-lua.md`,
`docs/process/wp-workflow.md` and this contract. It preserves all R1-R4
historical PUC evidence, creates no implementation, artifact, acceptance or
status claim and requires one clean focused independent review. After both
exceptions receive their required clean reviews, R5 implementation/review work
may change only:

```text
docs/research/wp40-simple-map-r5-contract.md
docs/research/wp40-simple-map-r5-artifact.tsv
docs/research/wp40-simple-map-r5-review.md
mods/MAPGEN/grug_mapgen/wp40/zones.lua
mods/MAPGEN/grug_mapgen/wp40/index128.lua
mods/MAPGEN/grug_mapgen/wp40/mapgen_manifest.lua
mods/MAPGEN/grug_mapgen/wp40/counting_allocator.lua
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

Before these literals were admitted, every current file was verified byte-
equal to both the accepted R4 commit
`948689138c15c291544fe10927683da4183bfd8e` and the contractual R5 branch
starting point `544f0aba5f7e96a783e1bc0de2d0d01fd9855778`. Their exact complete-file
SHA-256 authority is:

| Repository-relative path | SHA-256 |
|---|---|
| `mods/MAPGEN/grug_mapgen/wp40/init.lua` | `b3ac5bf31bcf52e5f1534b2521f7c3b1d18a9930fe6582cfddb8217e5c1c8951` |
| `mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua` | `5d4e2726dabbb900e47e7a8bef2a225011e6b003f48de485f752cde88fc7c17f` |
| `mods/MAPGEN/grug_mapgen/wp40/simple_map.lua` | `55e507a6e5b2d73bf23233d9ab5e515ad150dbce77c6dc6c158a6133f4e27dfc` |
| `mods/MAPGEN/grug_mapgen/wp40/height.lua` | `f69fcd006af40f2f473d592c412508c3d7043403b15c07bfedcb311fe6faee97` |
| `mods/MAPGEN/grug_mapgen/init.lua` | `4e89d6e5975f0f511e5107737c29694b8b6b19a44f50b69cc74ad7d0dbb95fd4` |
| `mods/MAPGEN/grug_mapgen/ocean_mask.lua` | `39658372e8525265e1be6289f48c2b329325bc6744f5a2119c3f62edecc1ce61` |
| `mods/MAPGEN/grug_mapgen/ocean_mask_mapgen.lua` | `15572acfe6bd26f331220bbcb037c678cceb0ba7318f350099316fd5f20df16d` |
| `mods/MAPGEN/grug_mapgen/structures.lua` | `f02fef7b233a001ce5fec081d3a46c514aecbe990fe56f9ab8e0b19bb90c92de` |
| `game.conf` | `1c778404a49e1ecf48cbcd3c0a05a4868586a5126ace081a09ba9089e2dfc0f6` |

The disabled fixture first reads these nine files in the exact displayed path
order through `read_bound_input` and requires each fresh complete-file digest
to equal this table before calling `load_public`, `load_r5` or emitting any
disabled-fixture digest/proof. It then reads every path in the exact defensive
set union of the `R5_MODIFIED_PARENT_PATHS`, `R5_PRODUCTION_PATHS` and
`R5_TOOL_PATHS` rosters through `read_current_input` for the static callback,
global, settings and legacy-writer call-pattern audit.
`legacy_writer_unchanged` is true only after both the nine literal comparisons
and that current-source audit pass; manifest equality alone is not the proof.

It also makes no R5 status edit to BACKLOG, ROADMAP or README before accepted
review. A required implementation/evidence file outside the allowlist stops
implementation and returns to contract amendment.

Only after a clean accepted R5 review, the separate mechanical closeout commit
may change exactly `docs/research/wp40-simple-map-rebase-plan.md`, `BACKLOG.md`,
`ROADMAP.md`, `README.md` and this package's final review record. It may not
change a reviewed implementation, contract or artifact byte; such a need
returns to implementation review. No other design/research/status file is in
the R5 closeout allowlist without a contract amendment.

## 17. Preflight, review and acceptance sequence

The exact sequence is:

1. verify the accepted R4 literals and derived four-seed KAT lineage in Section
   3 without changing historical R4 bytes;
2. verify that the accepted R4 commit is an ancestor of the contract branch,
   that the exact draft `8f9472e238626cd8dcb510490f9efe6047cee13c`, audit-fix
   `a4412651a34bfb361e517474c1be702267770709`, merge
   `d718f020815b77f3c9282364998b6e3bf53ce047` and B+
   `37bd94829d7a8c3d1a59688612a483f449fa63de` objects retain their identities
   and ancestry; no replay, rebase, amend or historical-byte rewrite is
   permitted;
3. retain the clean independent contract review of the B+ decision, obtain one
   fresh focused independent review of the exact interpreter-policy amendment,
   close its findings, and freeze the resulting R5 contract before
   implementation;
4. implement the private seam, planner, manifest, adapter and tools in the R5
   worktree without changing public R4 bytes;
5. pass the lineage preflight and exact historical/current public KAT parity;
6. pass the static gates and full LuaJIT evidence, then on unchanged frozen
   candidate bytes run exactly one final PUC micro-KAT process and one matching
   LuaJIT process and pass byte/digest parity;
7. generate the canonical R5 artifact twice to byte-identical bytes;
8. freeze the candidate diff, status snapshot, full LuaJIT evidence and the
   final micro-KAT manifest/output/status evidence;
9. obtain one fresh independent review selected under
   `docs/process/agent-model-policy.md`, applying the complete checklist in
   `docs/process/wp-workflow.md` and `docs/research/luanti-lua.md`;
10. fix every Critical, High or Medium finding; Critical/High fixes receive a
    focused fresh rereview, and Low findings are fixed or explicitly
    dispositioned under policy; a fix that changes a relevant Lua byte returns
    to step 6;
11. only a clean final verdict may create the R5 review record and acceptance
    closeout; and
12. only then update the exact Section 16 closeout allowlist as one coherent
    completion change.

No review is performed by the drafting task that creates this document. The
contract does not name a local preferred reviewer model; project model policy
is the sole routing authority.

The durable R5 completion record created only after the clean final review must
carry these named calibration values: `implementing_model`, `reviewing_model`,
`critical_findings`, `high_findings`, `fix_round_count` and
`observed_elapsed_wall_time`. Finding and fix-round counts cover all independent
R5 contract and implementation review attempts before acceptance; elapsed wall
time is the coordinator-observed R5 delivery interval or the literal
`unknown`. The final review record and BACKLOG closeout summary must carry
identical values; omission or disagreement blocks closeout.

The review checks at minimum:

- correct historical/current artifact lineage without a hash cycle;
- exact public R4 KAT and disabled-loader byte parity;
- exact logical-biome scalar pass-through with no `share` input, population
  quota, reroll or repair behavior;
- exactly one horizontal and one height session;
- exact construction-private plan provenance plus independent stale-generation
  rejection;
- no per-voxel operation objects, CSG or unbounded recovery;
- sound 16/31 run bounds and measured allocation counters;
- exact B+ owner-slice runs, mapgen-edge derivation, heightmap order/domain and
  planner-byte independence from native content;
- exact masks, the sole closed opcode-policy alternate and order-independent
  same-priority conflict failure in every covering priority group;
- zero P7-P9 emission and fail-closed unmapped roles;
- one VM content transaction and exact call order;
- owner-only content/param2 plus restored halo light;
- dungeon vertical separation, local ordinary-cave preservation and the total
  ore/resource/stratum policy;
- ignore, dirty, lighting and liquid correctness;
- no callback, global, setting change or legacy-writer coexistence path; and
- plain Lua 5.1 compatibility and compliant interpreter scheduling.

## 18. R6, R7 and R8 boundaries

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
  `mapgen_limit = 31007`, `chunksize = 5`, their derived owner edges and
  `num_emerge_threads = 1`, `mgv7_dungeon_ymin = -31000` and
  `mgv7_dungeon_ymax = -193`, without changing a setting at R5;
- removes or disables every legacy ocean/structure/healing writer path;
- installs exactly one mapgen-environment callback/script for the consolidated
  adapter and supplies its reviewed one-call current-heightmap context;
- supplies the accepted production content contract;
- migrates geography consumers and publishes the selected R4 APIs; and
- proves no repository/configuration path can enable both writer generations.

R5's disabled internal status is not an R7 activation mechanism. R7 must add
and review the activation boundary explicitly. Before registering the adapter,
R7 reads the live effective `mg_name`, `water_level`, `mapgen_limit`,
`chunksize`, `num_emerge_threads`, `mg_flags`, `mgv7_spflags`,
`mgv7_dungeon_ymin` and `mgv7_dungeon_ymax` values and proves exact equality
with their Section 10.1 validated-manifest counterparts, then re-proves the
derived owner edges and pinned engine identity. A missing, malformed or unequal
value fails closed before registration. R5 validates fixture/offline manifest
bytes only and remains settings-read-only.

### 18.3 R8 owns runtime and rollout evidence

R5's VM proxy and offline engine-shaped fixtures are not a claim about an
actual Luanti world. After the accepted R7 atomic cutover, R8 owns focused real-
engine release evidence: deterministic world-seed generation, vertical native-
preservation checks, operation/owner order, measured whole-mapchunk performance,
capacity/supply, visual-world inspection and user-run Flatpak runtime gates.
R8 records the accepted R5/R6/R7 artifact lineage and the exact production
manifest, including one emerge thread. It does not reopen R2-R6 geometry,
biome/content or resource authority merely to fix rollout evidence; a semantic
failure returns to the owning accepted stage. R5 schedules no real-engine run,
changes no world and does not mark that handoff complete.

## 19. Stop conditions

Implementation stops and returns to contract or design review if it would:

- begin before every Section 3 accepted/derived lineage check, the clean B+
  independent contract review pass and the focused interpreter-policy
  amendment review pass;
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
- read a VM halo CID/param2 for liquid-dirty adjacency instead of using the
  owner-boundary trigger;
- persist temporary halo light or make geometry depend on chunk request order;
- read native heightmap in the planner, use it as global height/geometry/
  operation authority, fetch it other than exactly once per nonempty adapter
  apply, or accept a noncanonical 6,400-entry value/order;
- create a physical rewrite-band guard, materialized-neighbor vertical guard,
  per-column global Y array or operation below `authored_floor`;
- infer dungeon origin from content names, enable dungeon force placement, or
  violate the `authored_floor = -37`/`-193` vertical proof;
- replace supporting ore/resource/stratum below `T` through ordinary P5 fill,
  fail to replace project-native content at/on/above the authored surface where
  the total matrix requires it, or ever replace foreign/unknown/ignore;
- use more than one content read/set transaction, a direct node writer,
  schematic, ore/deco generator or later healing pass;
- register a callback/global, change settings/configuration or expose an R5
  activation flag;
- disable a legacy writer or migrate a consumer before R7;
- schedule an intermediate PUC runtime, PUC seed/shard/population fleet,
  exhaustive PUC run or more than one final PUC micro-KAT on unchanged bytes
  without a concrete interpreter-specific finding or identified uncovered
  plain-5.1 risk, or exceed seven concurrent Lua processes; or
- invent an absolute performance threshold without a measured derivation.

A source-data correction or player-visible geometry change is not an R5
implementation detail. It returns to the relevant accepted stage and, where it
changes decided design or preservation, to the user before code continues.
