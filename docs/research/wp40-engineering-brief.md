# WP40 Named-Zone World Foundation — Engineering Brief

Status: **Final pre-code engineering contract; independently reviewed
2026-08-13; not an implementation or shipped-WP claim.**

This brief freezes the engineering contract that must be reviewed before any
WP40 mapgen implementation begins. It consumes the decided game design in
`docs/design/` and the engine research in `docs/research/mapgen-control.md`;
it does not replace either authority. Numerical results that require a
prototype, a 32-seed audit, or runtime measurement remain mandatory WP40
implementation outputs and are not invented here.

WP40 is fresh-world-only. Production uses native v7 with one emerge thread and
must produce identical Grudgelands-authored output for arbitrary chunk-request
order. Native v7 remains subject to its signed-low-32-bit seed limitation; the
full decimal seed controls every Grudgelands-authored random field.

## Authority and verified engine basis

The target geometry and policy come from
[world_zones.md](../design/world_zones.md),
[world.md](../design/world.md), and [housing.md](../design/housing.md).
[items_crafting.md](../design/items_crafting.md) owns the target material and
resource taxonomy; [biomes_mobs.md](../design/biomes_mobs.md) remains a content
catalog while `world_zones.md` supersedes its legacy ring/coordinate placement.
[mounts.md](../design/mounts.md) supplies the later consumer constraints for
the common ocean/channel classifier. [BACKLOG.md](../../BACKLOG.md) supplies
WP staging: WP43 owns final material APIs, WP13 realizes settlements/camps,
WP24 owns live claims, WP34 owns deep refill/multipliers, and WP40 owns their
immutable terrain, masks, semantic slots, and query seams.

The WP43 contract was verified after its merge at `e7f393c` against
[wp43_wp40_handoff.md](wp43_wp40_handoff.md),
[`registry.lua`](../../mods/ITEMS/grug_materials/registry.lua), and
[`mining.lua`](../../mods/ITEMS/grug_materials/mining.lua). Those runtime
tables/functions, rather than names anticipated during planning, are binding.

The full evidence and current-code inventory are maintained in
[mapgen-control.md](mapgen-control.md); Lua-language and sandbox constraints are
in [luanti-lua.md](luanti-lua.md). The primary pinned-engine facts this brief
depends on are:

- native v7 stage order and its 2D/3D terrain split:
  `reference_projects/luanti/src/mapgen/mapgen_v7.cpp:299-381,390-573`;
- intentional native u64-to-s32 seed truncation and the exact decimal-string
  API: `reference_projects/luanti/src/mapgen/mapgen.cpp:91-113` and
  `reference_projects/luanti/doc/lua_api.md:7104-7116`; raw SHA-256 is exposed
  in every emerge state by
  `reference_projects/luanti/src/script/lua_api/l_util.cpp:587-602,862-895`;
- one isolated Lua state per emerge thread, the unfinished v7 slice warning,
  and generation/main-callback order:
  `reference_projects/luanti/src/script/scripting_emerge.cpp:29-80` and
  `reference_projects/luanti/src/emerge.cpp:175-226,545-770`;
- central mapchunk versus emerged border ownership and the final whole-VM
  blit: `reference_projects/luanti/src/servermap.h:172-175` and
  `reference_projects/luanti/src/servermap.cpp:200-350`;
- chunksize-five containing-chunk lattice and its negative-coordinate fixture:
  `reference_projects/luanti/src/emerge.cpp:339-345` and
  `reference_projects/luanti/src/unittest/test_map_settings_manager.cpp:255-267`;
- v7 central/full node ranges, dungeon-stage eligibility, full-VM DungeonGen
  call, and dungeon setting/noise reads:
  `reference_projects/luanti/src/mapgen/mapgen_v7.cpp:150-193,309-318`,
  `reference_projects/luanti/src/mapgen/mapgen.cpp:890-952`, and
  `reference_projects/luanti/src/mapgen/mapgen_v7.h:30-41`;
- full-volume VoxelManip copy costs, content-only `set_data`, and mapgen-state
  liquid/lighting calls:
  `reference_projects/luanti/src/script/lua_api/l_vmanip.cpp:35-55,92-228,308-355,499-518`
  and `reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:1980-2016`;
- native-dungeon order, internal working flags, room-center-only notification,
  and the absence of any Lua provenance/flag accessor:
  [`mapgen_v7.cpp`](../../reference_projects/luanti/src/mapgen/mapgen_v7.cpp):353-363,
  [`dungeongen.cpp`](../../reference_projects/luanti/src/mapgen/dungeongen.cpp):65-120,127-189,
  [`mapgen.h`](../../reference_projects/luanti/src/mapgen/mapgen.h):44-51,
  [`l_mapgen.cpp`](../../reference_projects/luanti/src/script/lua_api/l_mapgen.cpp):40-48,676-710,
  and [`l_vmanip.cpp`](../../reference_projects/luanti/src/script/lua_api/l_vmanip.cpp):92-114,499-518;
- native surface decoration's prior use of the native heightmap/biomemap:
  `reference_projects/luanti/src/mapgen/mg_decoration.cpp:125-256`; and
- IPC copy/unpack semantics and blocking warning:
  `reference_projects/luanti/src/script/lua_api/l_ipc.cpp:17-63` and
  `reference_projects/luanti/doc/lua_api.md:7826-7870`.

Those are engine facts, not selectable architecture preferences. This brief's
new numerical limits and algorithms are pre-code engineering decisions; its
capacity, supply, initialization, and runtime timings remain measurements.

The implementation cutover is one pipeline replacement:

```text
current
native v7 -> grug_mapgen ocean_mask mapgen-state pass -> engine blit
          -> main-environment structures.lua terrain/POI VoxelManip writes

WP40 target
native v7 -> one mapgen-state classify/compose/commit/liquid/light pass
          -> engine blit -> sparse main-environment metadata/entity handoff
```

The target deletes first-writer height persistence and broad second-pass main-
environment voxel work. It does not replace native v7 itself.

## 1. Analytical target heights and chunk independence

### 1.1 Authoritative height source

**Decision (2026-08-12): use a project-owned full-seed macro-relief field.**

Native v7 remains the C++ substrate generator. WP40 does not reimplement the
v7 terrain algorithm in Lua. Every stable anchor, route interface, mandatory
terrain envelope, and housing-relevant grading surface derives its elevation
from one project-owned macro-relief function:

```text
H(geometry_schema, full_seed_string, x, z)
```

`H` is a pure function of immutable inputs. It combines the owning zone's
decided primary and secondary relief profiles with domain-separated authored
noise, shared-boundary gate control points, and the named landmark components
classified as base terrain. Planned hydrology, routes, foundations, structures,
housing smoothing, and other anchor grading transform this common `H` into
their later target `T`; they are not hidden inside `H`. Its output is the
authoritative terrain-derived height;
"terrain-derived" refers to this authored macro-relief field, not to generated
nodes or to whichever mapchunk first reaches an anchor.

`H` has one value per world column. A caller may not supply its own anchor or
feature ID and obtain a different natural surface. Internally, stable zone,
landmark, coast, and relief-layer IDs select domain-separated components only
through the exact authored classification at `(x, z)`. Anchor/route/template
IDs affect their later candidate, solver, or shaping records, never the common
ungraded relief queried by another feature at the same column.

The implementation must derive every authored random lane from the complete
decimal seed string with a schema- and domain-separated hash. It must never
convert the complete seed to a Lua number. The same geometry module and inputs
must yield identical results in the main Lua state, every mapgen Lua state, and
offline audit tooling. Caching or transfer of derived data may optimize this
function, but may not become a second source of truth; Chapter 5 freezes that
strategy after its required initialization and memory measurements.

The canonical binary grammar is byte-exact. It uses these one-byte type tags:
`0x01` raw bytes, `0x02` UTF-8 text, `0x03` signed two's-complement integer,
`0x04` unsigned integer, `0x05` array, and `0x06` map. Bytes/text carry a four-byte
unsigned big-endian length. Integers carry exactly four big-endian bytes.
Arrays carry a four-byte element count followed by elements. Maps carry a
four-byte pair count followed by key/value encodings sorted lexicographically
by complete encoded key; duplicate encoded keys are invalid. Booleans are
unsigned 0/1. Nil is never encoded. All lengths/counts and signed/unsigned
values must fit their 32-bit type. The dataset encoder uses only this grammar;
schema source replaces an outgrown type rather than adding an implicit variant.

Every authored random field hashes this exact ordered byte sequence:

```text
ASCII bytes "GRUGWP40HASH" followed by 00
text(geometry schema) · text(random-field domain) · text(full seed)
text(stable feature/resource/decoration ID, or empty text)
array(signed x[, signed y], signed z)
unsigned(candidate index) · unsigned(hash block) · unsigned(rejection counter)
```

For requested logical lane `j`, require integer `0 <= j <= 2^32 - 1`, set
`hash_block = floor(j / 8)`, hash with `core.sha256(data, true)`, and read digest
word `j % 8` as an unsigned big-endian 32-bit integer. A rejection rehashes the
same block with only its counter incremented; counter overflow is fatal. This
defines lane selection and exhaustion rather than leaving them to an adapter.
Conversion to a signed engine-noise seed subtracts `2^32` only when the word is
at least `2^31`.

For an integer range of size `n`, require integer `1 <= n <= 2^32`. Set
`limit = floor(2^32 / n) * n`; accept only `word < limit` and return
`word % n`, otherwise rehash as above. A unit variate is exactly
`word / 2^32`. No modulo-biased shortcut, textual concatenation without type/
lengths, ambient PRNG state, or native block seed is permitted.

All geometry arithmetic uses signed integer nodes plus `Q16.16` with
`Q = 65536`. Authored fractions are source numerator/denominator pairs, never
binary floating literals. `qmul(a,b)` is half-away-from-zero rounding of
`a*b/Q`; `qdiv(a,b)` is the same rounding of `a*Q/b`, with non-zero `b`.
For exact integer numerator `p` and positive denominator `d`, that rounding is
`floor(p/d + 1/2)` when `p >= 0` and `-floor((-p)/d + 1/2)` otherwise.
Every source and intermediate magnitude is validated so its exact integer
product stays within Lua's `2^53 - 1` range. Normalized values clamp to
`[0,Q]`. `smootherstep(q)` computes q2, q3, q4 and q5 with `qmul` after every
multiplication, then clamps `6*q5 - 15*q4 + 10*q3`; interpolation is
`a + qmul(b-a, t)`. Final node heights use the same half-away rule.

Project-owned 2D value noise uses integer lattice periods from the checked
source. Mathematical floor/floor-mod gives lattice coordinates and Q16.16
fractions; four corner values come from the field's hash domain and map
uniformly to signed `[-Q,Q]`; both axes interpolate with the fixed
smootherstep/lerp above. Octave periods and rational Q16.16 amplitudes are
explicit catalog arrays accumulated in canonical order. Geometry membership
uses integer cross products/squared distances and the greatest-integer
`isqrt`; blend distance is an integer node distance converted with `qdiv`.
No `math.random`, engine noise wrapper, host `math.sqrt`, unordered sum, or
floating comparison belongs to authored geometry.

Golden vectors cover every type, zero/min/max and negative integers, map
sorting, zero/negative coordinates, every corpus seed, all eight digest-word
positions, rejection/rehash, fixed-point signs and ties, noise corners and
seams, and main/mapgen/offline identity before any geometry consumer is
enabled.

The native v7 heightmap and a bounded scan of a native-only audit VoxelManip
are observation inputs only. In the dedicated audit worlds, before any WP40
overlay runs, they may be used to:

- measure native `N` in the one validation-owner slice and prove the
  `N`-to-`H` displacement budget;
- detect liquids, exposed caves, dungeon or foreign structure nodes, and other
  conflicts covered by Chapter 2;
- validate the frozen rewrite limits; and
- record native-versus-authored benchmark counters.

They must never select, modify, or persist a shared anchor height, route grade,
mandatory envelope, shell bound, or target operation. No rendered result may
depend on generated neighboring chunks, main-environment map reads, callback
order, a first-writer storage decision, or the observed `N` value.
`core.get_spawn_level` is not a height authority or fallback.

For each x/z column, the audit validation owner is the unique half-open
vertical mapchunk whose central y range contains `H(x, z)`. With the WP40
overlay disabled, the harness generates that owner plus its immediate upper and
lower vertical neighbors in bottom-up and top-down order in two independently
created disposable worlds, then reads only their completed central mapblocks.
This avoids treating the emerge halo as generated native data. In each
combined result it selects the highest exposed registered native
natural-ground/resource/stratum surface candidate in
`H - 16 .. H + 16`, after excluding decorations and liquids. The node directly
above a candidate must not be another registered natural solid/resource/
stratum node. No candidate, multiple ambiguous exposed candidates, continuation
of natural terrain above `H + 16`, or a result below `H - 16` fails validation.
Both vertical orders must report the same `N`. The callback-local heightmap may
accelerate rejection, but the post-generation central-mapblock oracle is
authoritative for this audit.

Production callbacks neither need nor attempt to recover `N` as a height input;
they render the analytic Chapter 2 envelope from `H` and `T`. This separation
is mandatory:
an emerged halo can already contain a neighboring WP40-owned slice, so a later
runtime scan would not be a reliable native snapshot under arbitrary vertical
request order. Before rollout, the native-only disposable audit therefore
validates every integer x/z column in the complete finite authored mainland,
island, planned-water, route, anchor, and decoration extent, plus every named
feature-envelope column, for the production seed. Exterior deep ocean outside
that finite extent follows Section 2.9 and does not use the `N`-to-`H` premise.
The Section 6.2 native-v7 control schedules cover this complete finite audit
extent for the production seed, not merely the smaller rendering feature
corpus; native horizontal or vertical request-order instability therefore
invalidates the same manifest before any observed `N` is accepted.

Production retains one failure-only guard that cannot influence an authored
answer: for an ordinary column, if the current callback's central heightmap
reports any native base-terrain walkable node above `shell_ceiling`, the
manifest is invalid and generation fails before commit. The guard never
changes `H`, `T`, a bound, a candidate, or a node operation, and it never reads
a neighboring halo as native evidence. Runtime otherwise classifies only the
current central owner slice's pre-overlay nodes for Chapter 2's typed
replacement/veto rules; it never treats a reconstructed surface height as
authority.

If the native-only audit observes terrain that would require a rewrite outside
Chapter 2's limits, it rejects the rollout manifest. If two immutable geometry
inputs disagree, compilation or production generation fails loudly. Either
diagnostic must identify at least the geometry schema and dataset checksum,
full-seed hash, stable feature ID, world coordinates, authored target, observed
native value or conflict class, and the violated limit. It must not silently
choose a local fallback height.

The fresh-world geometry manifest verifies the full-seed hash, geometry and
algorithm schema, authored dataset checksum, exact `mgv7_spflags` bitset,
every active v7 noise parameter, chunksize, engine pin, and production
emerge-thread setting. It binds `water_level = 1`, `chunksize = 5`, one emerge
thread, `mgv7_dungeon_ymin = -31000`, `mgv7_dungeon_ymax = -193`, the exact
active `mgv7_np_dungeons`, and the critical derived constant
`broad_content_y_min = -37`. The production special-flag bitset is
`mountains`, `ridges`, and `caverns`; `floatlands` is disabled. The normal
mapgen flags retain dungeons, biomes, caves, ores, decorations, and light.
Stage 1 and Stage 3 compare these values to the running mapgen settings rather
than accepting defaults.

The same manifest binds the complete registered biome dungeon wall/alternate/
stair triples, the six exact final WP43 stratum-host node names, and every
authored natural-resource output registration needed by the typed deep path.
A missing dungeon triple, a fallback to an inferred biome stone/cobble alias,
an overlap between a dungeon registration and an eligible host name, or an
output without `is_ground_content = true`, `grug_natural`, and
`grug_resource` is fatal before mapgen callback registration. This registration
check proves typed-operation closure; it is never used to infer whether an
individual node came from DungeonGen.

The lower bound is derived, not calibrated. `world_zones.md` fixes the six
relief bands at `W + 2..24`, `W + 8..56`, `W + 24..96`, `W + 56..144`,
`W + 96..224`, and `W + 160..360`; therefore the global land minimum is
`H_min = W + 2 = 3`. The largest ordinary/template cut is the capital's 24
nodes. Applying Section 2.1's exact shell formula gives the deepest broad
surface/template/foundation result:

```text
T_min                   = H_min - 24
broad_content_y_min     = min(H_min - 16, T_min) - 16
                        = W - 38 = -37
```

Every other Section 2 lower extreme is enumerated against that constant. The
32-node exterior bed plus three seals reaches `W - 35 = -34`. Current planned
water reaches use offsets at least `W + 8`; their deepest offset/depth/seal
combination is `W + 8 - 8 - 3 = -2`; the named 12-node Raincall plunge and
Kezamba cenote bottoms are respectively `W + 44 - 12 - 3 = 30` and
`W + 64 - 12 - 3 = 50`. A tunnel route can cut eight nodes below `H`, and its
two backing nodes reach only `W + 2 - 8 - 2 = -7`; the named Mirefolk
causeway's three-node backing reaches `W + 2 - 8 - 3 = -8`. The troll basin's
12-node subtraction remains inside the capital's binding 24-node maximum cut.
Decorations, every other template/foundation/road mask, every waterfall
drop/seal, and every exact
resolver occupancy are Stage-2-enumerated by their final voxel coordinates and
must satisfy `y >= broad_content_y_min`; a new T2--T7 operation kind that does
not satisfy it rejects the schema and requires a new Reality Check. Exterior
air continuing upward to the map limit does not change this lower bound.

Only exact eligible-host-typed authored underground resource operations may
exist at `y < broad_content_y_min`. They may replace only the registered final
stratum node for that exact y, never cave air, liquid, generic native ore,
dungeon wall/stair/air, `CONTENT_IGNORE`, unknown content, or foreign content.
They do no lighting, liquid, or `param2` work. Their registered natural outputs
remain ground content so a later native DungeonGen pass treats them exactly as
the host it replaced; if DungeonGen writes the position, the same native
dungeon final node wins in either callback order.

The engine lattice makes that content rule global without a world hard border.
For `chunksize = 5`, `getContainingChunk` yields mapblock minima `-2 + 5k`.
With 16-node mapblocks and the engine's one-mapblock emerge border, the central
and full-VM y ranges are therefore:

```text
central(k) = [-32 + 80k,  47 + 80k]
full(k)    = [-48 + 80k,  63 + 80k]
```

The first owner slice that can contain broad content at y = -37 is `k = -1`:
central `[-112,-33]`, full VM `[-128,-17]`. Dungeon eligibility compares the
central `node_min`/`node_max` to the configured limits and then passes the full
VM to DungeonGen. With `mgv7_dungeon_ymax = -193`, slice `k = -2` is disabled
because its central minimum is -192. The highest eligible slice is `k = -3`,
central `[-272,-193]`, full VM `[-288,-177]`. Thus every dungeon-writing VM,
including a later horizontal or vertical neighbor's complete blit, ends below
the first broad callback's full influence area. Nodes -176 through -129 form a
48-node gap. The smaller content-only cutoff -113 would be unsound because its
dungeon VM would overlap the broad callback's lighting/emerge collar.

This y-disjointness, not a finite dungeon-event corpus, is the global native-
dungeon preservation authority. Enabling floatlands or changing water level,
chunksize, either dungeon y bound/noise, dungeon/biome flags or registrations,
stratum/resource registrations, another active v7 noise, or any derived lower
extreme is a world-format change that requires recompilation, the complete
native-only audit, and this proof to pass again. The exact handling of cached
height products is frozen with the registry/IPC decision in Chapter 5; they
remain derivatives of `H`, never persistent first-writer decisions.

### 1.2 Exact envelope fitting

**Decision (2026-08-12): evaluate complete integer-column footprints with a
constraint-first median solver.**

A bounded mandatory feature may not derive its elevation from its centre point
or from a coarse sampling lattice. The geometry compiler evaluates `H` at every
integer world-coordinate column in the feature's fitting footprint. It first
proves that one base elevation satisfies every column's feature-specific cut
and fill limits, and only then chooses the robust base elevation.

For a flat template at natural authored height `H_i`, maximum cut `C_i`, maximum
fill `F_i`, and integer base elevation `b`, each column contributes:

```text
H_i - C_i <= b <= H_i + F_i
```

For a shaped feature with stable local offset `shape_i`, the same constraint is
applied to the residual `R_i = H_i - shape_i`:

```text
R_i - C_i <= b <= R_i + F_i
```

The feasible interval is therefore the intersection of every per-column
interval:

```text
lower = max(R_i - C_i)
upper = min(R_i + F_i)
```

An empty interval (`lower > upper`) is a hard geometry failure. Otherwise the
compiler selects the deterministic lower median of all integer `R_i` values and
clamps it to `[lower, upper]`. The lower median is the element at sorted index
`floor((n + 1) / 2)` under one-based indexing. This definition keeps the result
integer and permits a bounded streaming histogram instead of retaining or
sorting every sampled column. The selected value and feasibility bounds are
derived products covered by the geometry dataset checksum and manifest.

The fitting footprint chooses the base elevation; the compiler then evaluates
and validates every integer column of the complete terrain-blend envelope.
Stable template and blend functions return to the ungraded `H` field at the
outer edge. A valid median never excuses a slope, local rewrite, water, landmark,
or conflict violation elsewhere in that full envelope.

Feature classes use the solver as follows:

- starts and ordinary camp envelopes use their stable flat or gently graded
  templates;
- capitals use race-specific terrain templates rather than one universal flat
  512-by-512 slab;
- other bounded mandatory structure envelopes use their stable feature
  templates;
- road and bridge interfaces use exact endpoint envelopes, while the route
  between them uses a separately frozen global longitudinal-profile solver; and
- housing land is not collapsed to one pad elevation. Its natural authored
  relief and the four guaranteed gentle-core grading fields are validated with
  the complete 101-by-101 reservation footprint.

Feature earthwork is measured against `H` at each integer column. A cut is
`H_i - target_y` and a fill is `target_y - H_i`; only the positive quantity
applies. The following inclusive maxima are binding inside each template's
full-weight fitting footprint:

| Feature class | Maximum cut | Maximum fill |
| --- | ---: | ---: |
| capital build surface | 24 nodes | 16 nodes |
| start build surface | 8 nodes | 8 nodes |
| bounded mandatory POI, mine, or camp surface | 8 nodes | 6 nodes |
| primary road or any fixed route interface | 8 nodes | 6 nodes |
| secondary road | 6 nodes | 4 nodes |
| trail | 3 nodes | 2 nodes |
| four guaranteed coastal housing cores | 6 nodes | 6 nodes |

The housing limit does not replace the decided audit: every complete 101-by-101
reservation contained in a guaranteed core must still expose no more than 12
nodes of generated natural-ground relief and meet all water, cliff, ravine, and
exclusion rules.

Inside a blend region, the effective per-column limits taper with the exact
Section 1.4 template weight `w`: `C_i = round_half_away(C_max * w)` and
`F_i = round_half_away(F_max * w)`. Thus both limits are exactly zero on the
outer blend boundary, and the same rounding used to obtain the final integer
`target_y` cannot make the template reject its own tapered output. Validation
uses that final integer target against the equally rounded integer limits. A more
specific named feature may use a lower limit but may exceed the table only
through a separately named, bounded force-authored envelope frozen in Chapter
2, such as a tunnel excavation or water channel; it may not silently widen an
ordinary terrain template's authority.

These limits constrain feature shaping relative to the analytic authored
terrain, not reconciliation between native v7 terrain and `H`, and not the
vertical reach of the rewrite shell. Those are separate Chapter 2 contracts.
An infeasible complete footprint is a hard seed or geometry-dataset failure;
mapgen does not raise a limit, clip an envelope, or retry against generated
nodes.

This evaluation reads no generated node, native heightmap, mod storage, or
neighboring chunk. Runtime VoxelManip inspection later validates and executes
the already selected authored result; it cannot change it.

### 1.3 Anchor validity and fallback candidates

**Decision (2026-08-12): distinguish immovable fixed anchors from explicitly
relocatable candidate sets.**

Every stable anchor definition declares exactly one placement mode. Flexibility
is an explicit registry property, never an implicit mapgen recovery behavior:

- `fixed` anchors retain their exact authored x/z coordinates and complete
  reserved envelopes on every accepted seed. This class includes the six
  starts, six capitals, fixed gates and route interfaces, island and channel
  geometry, and every other coordinate that the design marks exact. Failure of
  the exact-envelope solver or any static validity rule rejects the seed or
  geometry dataset; the anchor never moves.
- `candidate_set` anchors are permitted only for POI slots whose design allows
  placement within an already reserved envelope. Ordinary camps and other
  explicitly flexible POIs may use this class. The geometry compiler evaluates
  a finite, stable, ordered candidate sequence and selects the first candidate
  that passes every rule. If none passes, the seed or dataset is rejected.

Every candidate and its complete fitting/blend envelope must remain inside its
reserved zone and exclusion envelope and must satisfy the exact solver in
Section 1.2. Candidate order is derived from immutable authored data, the full
seed domain for that stable feature ID where seed variation is permitted, and a
canonical candidate index. It may not depend on Lua table iteration, callback
order, native terrain observations, or previously accepted features. The
selected candidate, base height, feasibility interval, and template version are
immutable derived geometry covered by the dataset checksum and world manifest
before any mapchunk is generated.

Static rejection includes at least a wrong zone or race region, overlap with
planned water where dry terrain is required, overlap with a forbidden named
cliff/ravine/landmark or reserved feature, failed setback/corridor rules, or an
empty cut/fill feasibility interval. A deliberately compatible landmark or
water interface must be named by the feature definition rather than inferred.

Incidental native v7 surface water is not an anchor-selection input and does
not move a candidate. Chapter 3 normalizes it according to the authored water
mask. The bounded VoxelManip observation may still discover a native terrain or
foreign-node conflict outside the frozen rewrite contract; that condition uses
Section 1.1's diagnostic hard failure and never triggers a second candidate or
a persisted runtime fallback.

Neither placement mode reads generated nodes, native heightmaps, main-state map
data, or mod storage to select geometry. The current camp/outpost first-writer
and chunk-local fallback schemes are retired by WP40.

### 1.4 Declarative feature templates and one blend operator

**Decision (2026-08-12): use a versioned declarative template catalog and one
shared analytic blend operator.**

Authored grading does not use one universal flat platform and does not permit
feature-specific executable terrain algorithms. A stable feature definition
selects versioned, parameterized primitives from one reviewed catalog. The
initial catalog must cover at least planes and tilted planes, terraces, raised
plateaux, basins with rims, road/causeway cross sections, and constrained
smoothing for guaranteed housing terrain. Complex named terrain forms compose
these primitives through a canonical, data-driven order.

For a feature whose Section 1.2 solver selected `base_y`, the template evaluates
a stable local offset and the common operator evaluates:

```text
natural = H(x, z)
shaped = base_y + template(feature_id, local_x, local_z)
target_real = natural + weight(x, z) * (shaped - natural)
target_y = round_half_away_from_zero(target_real)
```

The feature geometry supplies one canonical normalized distance `q` across its
blend region: `q = 0` on the fitting-footprint boundary and `q = 1` on the outer
blend-envelope boundary. It is clamped to `[0, 1]`. Template weight is one in
the fitting footprint, zero outside and at the outer boundary, and otherwise:

```text
smootherstep(q) = 6*q^5 - 15*q^4 + 10*q^3
weight(q) = 1 - smootherstep(q)
```

The zero first and second derivatives at both boundaries avoid an artificial
crease where authored grading begins or returns to `H`. Distance evaluation,
local coordinates, primitive composition, half-away-from-zero rounding, and
all boundary tie rules are implemented once in the shared pure geometry module.
They may not be redefined by feature code or an offline exporter.

The complete fitting and blend envelopes are evaluated in world coordinates
before generation and are rendered only as central-owner-chunk slices. The
Section 1.2 feasibility calculation uses the template's full-weight fitting
footprint; its subsequent validation covers every integer column of the blended
result. Template ID, template-schema version, parameters, selected base height,
and envelope geometry are immutable derived dataset fields covered by the
manifest checksum.

Feature classes use the catalog without losing their distinct contracts:

- starts and ordinary camps use stable flat or gently tilted compositions;
- each capital uses a race-specific composition matching its decided terrain
  form, never a universal 512-by-512 slab;
- a globally solved road or bridge longitudinal profile supplies the shaped
  centreline height, while catalog cross sections and the common operator grade
  it laterally into `H`;
- guaranteed housing cores use constrained smoothing that retains authored
  natural relief and satisfies the complete 101-by-101 relief audit; they are
  not feature pads; and
- named landmarks may use catalog primitives only inside their stable authored
  masks and may not override a fixed anchor or corridor implicitly.

Terrain templates, visible structures, claim-exclusion envelopes, and hard
protection are separate products. Choosing or composing a terrain primitive
grants no protection and does not make an ordinary mutable structure immutable.

### 1.5 Global longitudinal route profiles

**Decision (2026-08-12): solve one immutable constrained height profile for
every stable route before map generation.**

No road, bridge approach, ford, tunnel interface, or mandatory route derives
its grade independently per chunk. Once the complete world-coordinate x/z
centreline and its fixed interfaces are known, the geometry compiler builds a
canonical station sequence at one-horizontal-node resolution. Exact endpoints,
crossing interfaces, and chunk-boundary intersections are retained as named
stations even where centreline rasterization would otherwise skip them.

Each station receives a finite interval of integer height candidates derived
from `H`, the route class and cross section, the fixed endpoint/interface data,
and the applicable cut/fill and feature-envelope constraints. A deterministic
dynamic-programming solver selects the complete station sequence. Transitions
that violate an endpoint, maximum grade, grade-change/curvature, cut/fill,
crossing, structure, planned-water, or reserved-corridor rule do not exist in
the solver graph.

Among valid complete profiles, the solver minimizes this lexicographic cost:

1. maximum absolute earthwork at any station;
2. total absolute earthwork across the evaluated route cross sections;
3. total grade change/curvature; and
4. the canonical integer-y sequence in station order.

The final element is a deterministic tie-break, not a terrain objective. If no
complete profile exists, the seed or geometry dataset fails; generation does
not adjust an endpoint, select a profile from local nodes, or retry after a
neighboring chunk appears. Any earlier x/z route-candidate choice must itself
have completed before this solver runs and remains governed by the static
geometry contract.

The selected station heights, route/profile schema, fixed interfaces, and
solver-input checksum are immutable derived dataset records covered by the
world manifest. Mapgen performs no route search. It interpolates the already
selected profile by the one shared rule, applies the route-class cross section
and Section 1.4 blend, and writes only the central owner chunk's slice. The
analytic claim-exclusion corridor follows the same centreline independent of
later edits to visible road nodes.

The maximum longitudinal grades are class-specific:

| Route surface or interface | Maximum grade |
| --- | ---: |
| primary road | 1 vertical node per 12 horizontal centreline nodes (`1:12`) |
| secondary road | `1:8` |
| trail | `1:4` |
| start or capital approach | `1:12`, regardless of the incoming route class |
| bridge approach or deck interface | `1:12`, regardless of route class |
| ford approach or tunnel portal interface | `1:12`, regardless of route class |

These ratios constrain the discrete staircase profile, not the vertical face
of an individual full node. Every elevation transition changes by exactly one
node. Consecutive transition stations, whether they continue or reverse the
grade, must be separated by at least the class ratio's horizontal run along the
centreline. A fixed endpoint/interface also stores its grade phase; a flat
interface reserves the same run before the first transition and after the last
one. A stricter interface limit wins over the surrounding route-class limit.
The profile validator rejects a multi-node jump, an under-spaced transition,
or a short alternating sawtooth rather than smoothing it during generation.

Luanti's ordinary player step height is below one full node. The visible road
renderer must therefore realize every accepted one-node elevation transition
with a registered climbable stair or ramp transition; it may not expose a
full-cube riser and call the averaged profile traversable. The exact target
material nodes and orientation rules are frozen against WP43's final registry
in Chapter 2. Absence of a compatible transition for any road column is a
dataset validation failure.

WP40's external profile ends at each fixed capital gate. WP13 may author the
visible road and structure inside the reserved civic envelope, but it must meet
the same fixed gate position, elevation, direction, width, and grade interface;
it may not recalculate the external route.

### 1.6 Closed height-validity contract

There is no additional runtime-selected generic slope or cliff threshold.
Height validity is the conjunction of the owning zone's authored relief band
and named abrupt-feature masks, the complete-footprint cut/fill constraints in
Section 1.2, the route grades in Section 1.5, exact water/landmark/exclusion
masks, full blend-envelope continuity, and the Chapter 6 housing and route
oracles. Native v7 slope is only an observed displacement input under Section
2.2; it never changes an analytic anchor decision.

The initial primitive parameters and race-/feature-specific compositions are
checked source records implementing the forms and envelopes already bound by
`world_zones.md`. They must be complete and independently reviewed before the
geometry compiler accepts a schema; a missing composition is a Stage-1
validation failure. They are implementation data, not a runtime calibration or
an invitation to redesign a capital. Their canonical records, together with
all cut/fill and hard-failure thresholds in Sections 1.2 and 2, are covered by
the source and compiled-dataset checksums.

## 2. Terrain rewrite band and cut/fill

### 2.1 Ordinary surface rewrite shell

**Decision (corrected by engine reality check 2026-08-12): use an `N`-free
analytic shell derived from `H`, `T`, the 16-node accepted native-displacement
budget, and 16 nodes of repair/clearance.**

For an ordinary land column, let `H` be the common analytic macro-relief and
`T` the immutable final integer target. The accepted native surface can lie
only in `[H - 16, H + 16]`. The inclusive authorization shell is therefore the
worst-case envelope of the originally selected 16-node repair/clearance rule:

```text
native_low    = H - 16
native_high   = H + 16
shell_floor   = min(native_low, T) - 16
shell_ceiling = max(native_high, T) + 16
```

These bounds are pure and identical in every vertical owner slice. Observed
native `N` validates the premise only in Section 1.1's validation owner; it
does not move a bound or select a node operation. This is required because a
v7 heightmap/VM scan is local to the current vertical mapchunk and cannot
reconstruct a distant surface after another slice has generated
(`reference_projects/luanti/src/mapgen/mapgen_v7.cpp:320-324`,
`reference_projects/luanti/src/mapgen/mapgen.cpp:276-288`).

The exact ordinary owned volumes are the solid-support interval
`shell_floor .. T` and the clearance interval `T + 1 .. shell_ceiling`.
Together they reconstruct the logical-biome top/filler stack, provide complete
substrate for every accepted native/final displacement, and clear known native
terrain/decorations above the final surface. Every node at `y < shell_floor`
remains byte-identical to native v7 output for an ordinary column, including
content, `param1`, and `param2`.

The Section 2.6 lighting algorithm may include such nodes in a temporary dirty
calculation because light has a bounded neighborhood, but their final `param1`
must still equal the native snapshot byte-for-byte. The no-new-sky/cave-path
rule exists in part to make that possible. Any final light difference below an
ordinary floor is a preservation failure; lighting is not a hidden permission
to deepen the content shell. Named deeper envelopes declare and test their own
content floor and derived-light closure explicitly.

The analytic upper allowance covers the highest accepted native surface plus
16 nodes of native surface-decoration clearance. It is not permission to erase
an arbitrary node: ordinary replacement remains restricted to the frozen
natural-content/liquid/native-decoration categories in Chapters 2--4;
dungeon, foreign-structure, and other non-replaceable content uses the explicit
conflict table instead of being classified as surface clutter.

The shell describes authorization, not unconditional work. The no-op path
does not rewrite, relight, or queue liquids for an unchanged column. Each
callback writes only the central owner chunk's intersection with the global
shell, so crossing a vertical or horizontal chunk edge neither widens the
shell nor gives the first-requested chunk ownership of its neighbor's nodes.

Tunnel excavations, rivers and lakes, exterior ocean and shelf construction,
dragon channels, capital or other structure volumes, and accepted authored
decoration occupancy footprints that extend outside the ordinary shell require
separately named and bounded envelopes with their own replacement rules.
Merely intersecting the ordinary shell does not grant such an envelope.
Conversely, a named envelope may not be used as an unbounded escape from the
ordinary rule.

This is a fresh-generation transaction, not an existing-world migration. For
the same native pre-overlay VoxelManip snapshot, manifest, and central owner
chunk, planning and rendering are byte-identical on every replay; applying the
already composed operation set twice changes nothing the second time. The
engine does not invoke WP40 to reinterpret an already generated block, and no
LBM or load-time repair may approximate the lost native snapshot. Neighboring
owner slices may repeat derived halo calculations only where Sections 2.5/2.6
prove the same settled liquid/light bytes.

### 2.2 Native-to-authored displacement

**Decision (2026-08-12): cap ordinary reconciliation from native v7 surface
`N` to analytic ground relief `H` at 16 nodes in either direction.**

The cap is inclusive and applies before any Section 1 feature shaping:

```text
native cut  = max(0, N - H) <= 16
native fill = max(0, H - N) <= 16
```

Feature shaping then transforms `H` into final target `T` under the
class-specific Section 1.2 limits. These permissions compose; they do not
replace or independently enlarge one another. The resulting inclusive
worst-case native-to-final limits are:

| Feature class | Maximum total cut `N - T` | Maximum total fill `T - N` |
| --- | ---: | ---: |
| ordinary ground without feature shaping | 16 nodes | 16 nodes |
| capital build surface | 40 nodes | 32 nodes |
| start build surface | 24 nodes | 24 nodes |
| bounded mandatory POI, mine, or camp surface | 24 nodes | 22 nodes |
| primary road or any fixed route interface | 24 nodes | 22 nodes |
| secondary road | 22 nodes | 20 nodes |
| trail | 19 nodes | 18 nodes |
| four guaranteed coastal housing cores | 22 nodes | 22 nodes |

The table states maxima, not required work: opposite native and feature
adjustments cancel in the actual column delta. Every column must pass both the
`N`-to-`H` cap and its `H`-to-`T` feature limit independently; passing only the
total delta is insufficient.

An observed native surface outside the `N`-to-`H` cap is a hard native-only
seed-audit failure and blocks the rollout manifest. Production mapgen may use
only Section 1.1's central heightmap violation guard; it may not recover `N`,
clamp `H` to `N`, widen the rewrite shell, or persist a first observed surface
as replacement authority. Before the world-format manifest is frozen, the
implementation team may revise the
authored height schema or the pinned v7 settings as an explicit reviewed input
change and rerun the complete 32-seed and chunk-order corpus. After that
freeze, either change is a world-format change rather than runtime recovery.

### 2.3 Intersected caves and generic native ores

**Decision (2026-08-12): give the exact changed surface volumes authority over
native cave air and generic native ores, while preserving both everywhere else.**

Membership in the Section 2.1 shell authorizes only its two explicit analytic
volumes. No decision uses an observed native top:

- in `shell_floor .. T`, the exact top/filler layers are mandatory. At other
  support positions, an existing registered natural solid or generic native
  ore remains byte-identical; cave air or native liquid is filled with
  `grug_materials.stratum_node_for(y)`, and known misplaced native surface
  decoration is replaced by the appropriate ground/rock result; and
- in `T + 1 .. shell_ceiling`, known native natural terrain, generic native
  ore, native surface decoration, and incidental surface liquid are cleared to
  final air. Existing air remains air.

Thus shallow cave air wholly captured by the solid-support volume is
deliberately filled, while a generic ore already in valid support survives
unless an exact top/filler layer requires its voxel. A cave component that
crosses the support-volume boundary is forbidden by the common boundary rule
below; it is neither partially sealed nor followed outside the shell.

Every native cave-air and generic-ore node outside the two exact owned volumes
remains byte-identical. WP40 does not move an ore or regenerate one elsewhere.
All newly constructed rock is selected by the final WP43
`grug_materials.stratum_node_for(y)` contract. WP40 does not call the native
ore generator again: added rock therefore contains no generic native ore unless
Chapter 4 assigns it to a separate exact authored resource pass.

Every boundary face is classified first from the immutable global operation
plan. If both voxels are analytically owned, their expected final categories
decide the cave/opening interface even when the other voxel belongs to another
owner slice. If the adjacent voxel is analytically unowned, its native cave-air
state is evidence only in the native-only preflight; production never treats a
halo node as a native snapshot. The preflight rejects any owned solid/air
change that would open, close, or divide a preserved cave-air component across
such a face. Put more conservatively: preserved cave air may not be
face-adjacent to an ordinary solid-support fill or newly opened clearance
voxel. A wholly enclosed cave-air component inside the owned support volume may
be filled.

At runtime, native cave/liquid/dungeon/foreign-content classification is valid
only for a voxel inside the callback's central owner slice before WP40 commits
it. A halo voxel may be native-overgenerated data, an already committed
neighbor slice, or `CONTENT_IGNORE`; all three are ignored as native evidence.
`CONTENT_IGNORE` in any position where central native evidence is required is
a hard incomplete-input failure. Named tunnel portals, planned-water openings,
and other intentional connections require their own exact resolver and bounded
lighting/liquid contract. This analytic-plus-preflight rule prevents both
arbitrarily deep new sunlight and arbitrarily deep removal of existing
sunlight without introducing an order-dependent runtime veto.

The implementation records changed cave-air and generic-ore node counts by
seed, feature class, zone, cut/fill/top-filler reason, and depth band. The
terrain-preservation corpus asserts byte identity and cave connectivity below
and outside the exact owned volumes. A counter is audit evidence, not a quota
that permits widening an envelope.

Liquid nodes are not cave air, and dungeon, structure, or otherwise
non-replaceable nodes are not ordinary rock. Sections 2.4--2.10 define their
bounded handling, and Section 4.3 closes the cross-category conflict matrix and
transaction order.

### 2.4 Native dungeons and non-replaceable structures

**Decision corrected by focused Reality Check (2026-08-13): preserve native
dungeons unconditionally. On the pinned Luanti engine, Lua cannot derive a
node-exact positive native-dungeon provenance mask, so
`force_native_dungeon = true` is a fail-closed manifest error until a verified
provenance API exists. Never classify or replace a dungeon by content name.**

This is a fresh-world mapgen-contract change, not merely a stricter candidate
veto. Pinned v7 defaults both dungeon limits to the mapgen extremes
([`mapgen_v7.h`](../../reference_projects/luanti/src/mapgen/mapgen_v7.h):40-41),
and the pre-WP40 game did not override that default: its current baseline has
`mgv7_dungeon_ymin = -31000` and `mgv7_dungeon_ymax = 31000`
([baseline map metadata](../../tools/wp40/evidence/t0-post-wp43-wp18-wp36/70adabd28401e820ec86e8786bf0da368225c8624e42ed02dd3bce175fd3cafc/raw/run-001.map_meta.txt):175,206).
WP40 instead binds `mgv7_dungeon_ymin = -31000` and
`mgv7_dungeon_ymax = -193`. Under the
chunksize-five lattice, `-193` leaves `k = -3` as the highest eligible central
slice (`[-272,-193]`, with full DungeonGen VM `[-288,-177]`) and prevents
dungeon attempts in `k = -2` and every shallower slice. Players therefore get
fewer native dungeons and no native dungeon attempts near the authored surface;
the team explicitly accepts that visible world-generation consequence in
exchange for unconditional native-dungeon preservation without an engine
patch. Existing generated worlds are not migrated; creating a WP40 world with
the old vertical setting or later changing this setting is a fatal
world-format/manifest mismatch.

The pinned Luanti 5.17-dev sources are authoritative. Native v7 runs the
dungeon stage after ores and before decorations
([`mapgen_v7.cpp`](../../reference_projects/luanti/src/mapgen/mapgen_v7.cpp):353-363),
and the mapgen-state callback runs only after the complete native `makeChunk`
([`emerge.cpp`](../../reference_projects/luanti/src/emerge.cpp):727-750).
DungeonGen clears and uses private `DUNGEON_INSIDE`/`DUNGEON_PRESERVE` working
flags ([`dungeongen.h`](../../reference_projects/luanti/src/mapgen/dungeongen.h):12-15;
[`dungeongen.cpp`](../../reference_projects/luanti/src/mapgen/dungeongen.cpp):65-105),
but Lua's complete mapgen-object list contains no dungeon mask
([`mapgen.h`](../../reference_projects/luanti/src/mapgen/mapgen.h):44-51;
[`l_mapgen.cpp`](../../reference_projects/luanti/src/script/lua_api/l_mapgen.cpp):40-48)
and its complete VoxelManip method list contains no flag accessor
([`l_vmanip.cpp`](../../reference_projects/luanti/src/script/lua_api/l_vmanip.cpp):499-518).
`get_data()` returns content IDs, exposing only `VOXELFLAG_NO_DATA` as
`CONTENT_IGNORE`, not the dungeon flags
([`l_vmanip.cpp`](../../reference_projects/luanti/src/script/lua_api/l_vmanip.cpp):92-114).

`gennotify.dungeon` exports positions only
([`l_mapgen.cpp`](../../reference_projects/luanti/src/script/lua_api/l_mapgen.cpp):676-710),
specifically each room's bottom center
([`lua_api.md`](../../reference_projects/luanti/doc/lua_api.md):5775-5788;
[`dungeongen.cpp`](../../reference_projects/luanti/src/mapgen/dungeongen.cpp):181-189).
It omits room dimensions, walls, floors, corridors, stairs, and every changed
voxel. The generator derives its count, shape parameters, and C++ random state
internally ([`mapgen.cpp`](../../reference_projects/luanti/src/mapgen/mapgen.cpp):890-952;
[`dungeongen.h`](../../reference_projects/luanti/src/mapgen/dungeongen.h):70-107),
and Lua sees only the later post-dungeon/post-decoration buffer. Reimplementing
that generator in Lua would therefore be an unverified parallel generator, not
engine provenance. Content-name inference is additionally unsound because the
alternative-wall pass scans every matching wall content in its full range
without an origin test
([`dungeongen.cpp`](../../reference_projects/luanti/src/mapgen/dungeongen.cpp):107-120),
and current biomes use the ordinary shared names `default:cobble`,
`default:mossycobble`, and `stairs:stair_cobble`
([`biomes.lua`](../../mods/MAPGEN/grug_mapgen/biomes.lua):112-115).

The reproducible probe documented in
[`dungeon_probe/README.md`](../../tools/wp40/dungeon_probe/README.md) and run by
[`run_dungeon_probe.sh`](../../tools/wp40/run_dungeon_probe.sh) checks these
source contracts under plain Lua 5.1 and optionally builds a fresh isolated
Flatpak world under a temporary `LUANTI_USER_PATH`. The accepted manifest-bound
host run on Luanti 5.16.1, seed `40200517`, completed exactly 81 requested
mapchunks with zero emerge errors and observed 31 positive dungeon callbacks;
content/node/param2/emerged-area accessors were functions, while `get_flags`,
`get_voxel_flags`, and `get_dungeon_flags` were all `nil`. Its raw log and
machine summary are retained below the probe's manifest-digest evidence
directory. An earlier exploratory run under the old unrestricted dungeon-y
setting observed 38 positive callbacks. Both counts are non-portable
observations rather than golden values. Host runs corroborate but do not replace
the 5.17-dev source pin.

The native-only preflight enables dungeon gennotify and, for every callback
with at least one positive dungeon event, marks that callback's complete
`VoxelManip:get_emerged_area()` as a conservative `native_dungeon_uncertain`
guard. For every positive callback that it actually observes, this complete-
area mark is a sound over-approximation: the accessor is part of the pinned
VoxelManip surface
([`l_vmanip.cpp`](../../reference_projects/luanti/src/script/lua_api/l_vmanip.cpp):377-386,499-518),
and DungeonGen is called with that full VM range
([`mapgen.cpp`](../../reference_projects/luanti/src/mapgen/mapgen.cpp):951-952).
The preflight unions all such areas offline, projects the union onto canonical
owner slices, and rejects the seed or geometry dataset if any audited target
operation intersects it. This is deliberately a sound over-approximation and
a veto, not a positive per-node classifier.

The guard is a finite corpus/proof oracle, not a global runtime safety
authority. It proves only the explicitly emerged native-only audit extent and
cannot close over first exploration of arbitrary exterior ocean or every
future neighbor-overgeneration schedule. Global preservation instead comes
from Section 1.1's manifest-bound vertical separation: no broad WP40 callback
full VM can overlap any dungeon-writing VM, and the only deeper authored
operations are exact final-stratum-host-typed resource writes. Those writes
skip dungeon air/walls/stairs and all non-host content, perform no lighting,
liquid, or `param2` mutation, and leave a later DungeonGen write authoritative.

The finite guard and raw native observations are release evidence, never
production IPC or mod-storage authority. Production does not inspect a halo,
a room center, a guard bit, or a content name to make a placement decision.
An observed ID matching a manifest-registered dungeon-node name may be counted
only as `registered_dungeon_name_collision_non_provenance`; it does not identify
a dungeon voxel and is never reported as dungeon clipping.
Within the frozen corpus, one plan/guard intersection rejects the seed or
geometry exactly as before. `force_native_dungeon = true` is rejected during
source, compiled-data, and manifest validation and never reaches runtime as
replacement permission. Every native dungeon remains byte-identical under the
combined vertical/typed proof, independent of whether its callback was in the
finite preflight. WP40 neither cuts, repairs, relocates, nor replaces one.

An exact future replacement path requires an independently reviewed engine API
or project-owned origin channel that exposes node-exact writer provenance for
walls, floors, interiors, corridors, and stairs; exposing the current working
flags alone is not automatically sufficient. If the conservative finite guard
makes the complete fixed corpus unsatisfiable, or any new operation cannot
meet the vertical/typed separation contract, the team performs a new Reality Check
instead of removing a seed/case, narrowing the guard without proof, enabling a
name heuristic, or weakening an acceptance gate.

A `candidate_set` POI does not select another candidate after native
generation: candidate choice remains an immutable pre-generation result, so a
dungeon-uncertainty collision fails the frozen seed or geometry dataset.

Sections 2.5--2.10 define liquid, lighting, and named deeper-envelope behavior;
Section 4.3 supplies their common precedence and transaction rules.

### 2.5 Liquids intersecting terrain rewrites

**Decision (2026-08-12): make planned surface hydrology authoritative while
preserving underground liquids outside exact changed volumes.**

Surface water is legal only inside a registered planned-water or landmark mask.
Each such mask supplies analytic water level, bed, bank, sealed-ground, and
hydrology-envelope geometry independently of native nodes and callback order.
Every generated surface-water source uses the single decided identity
`default:water_source`; native `river_water_source` and other v7 surface-water
identities are not retained as surface metadata.

On dry authored land, the exact Section 2.3 cut, fill, and top/filler volumes
remove intersecting native water and `river_water_source`. A solid authored
fill likewise replaces any intersecting water or lava source inside its owned
volume. Those replacements are counted by original liquid identity, seed,
zone, feature class, depth, and reason.

Underground liquid outside an exact changed or separately named hydrology
volume remains byte-identical, including lava and cave water. The global
operation plan classifies both sides of every analytically owned boundary face.
For a face leading to analytically unowned content, the native-only preflight
proves that a final dry air voxel does not become face-adjacent to preserved
liquid and that a solid fill does not cut off a preserved liquid/air connection.
Production consults native content only for changed voxels in its central owner
slice; it never fails from an observed halo neighbor or treats
`CONTENT_IGNORE` as air, solid, or liquid. WP40 does not need or claim access to
native content elsewhere along a multi-chunk feature, invent a retaining wall,
drain a larger cave, delete the preserved source, or defer geometry validity to
the liquid simulator.

The compiler proves the complete analytic bed/bank/lining seal and every named
opening without native nodes. Runtime native collision checks are confined to
the central owner slice and never use halo content; native leak/connectivity
checks at analytically unowned faces belong to the native-only preflight. There
is no impossible promise to inspect a whole 128-node tunnel or river's native
boundary atomically during production. The complete production-seed headless
preflight is a separate run from that native-only preflight: it renders and
validates every relevant owner slice with the WP40 overlay enabled in another
disposable world before rollout. An unexpected later central-input failure
invalidates the manifest as described in Section 1.1 rather than rewriting
prior slices.

Planned water applies its analytic bed, bank, water column, and sealing rules
inside its named envelope, so this conservative leak failure does not replace
or weaken authored hydrology. Exterior shelf, deep ocean, and dragon channels
use the same single water node and shared coast/channel geometry but retain
their separately bounded seabed and water-column envelopes.

All terrain, water, surface, and decoration content edits are composed in one
ordered transaction and committed once. `VoxelManip:update_liquids()` is called
exactly once after that commit if and only if the transaction changed liquid
topology; it scans the VM and queues candidates but does not itself settle the
liquid before the following Lua statement
(`reference_projects/luanti/src/script/lua_api/l_mapgen.cpp:1980-1998`). It is
skipped on the no-op path and is never used to decide whether planned geometry
is valid. `finishBlockMake` later performs engine liquid transformation and any
engine-owned node-light updates
(`reference_projects/luanti/src/servermap.cpp:275-307`). Chunk-order tests
drive that queue to the frozen quiescence limit and
compare settled content/liquid/light boundaries for vertical and horizontal
orders.

### 2.6 Lighting completion

**Decision (corrected by engine reality check 2026-08-12): preserve every
external cave-air component symmetrically, then recalculate the bounded
15-node non-sunlight neighborhood of owned changes.**

Sunlight is not a 15-node effect: Luanti propagates level 15 vertically without
attenuation until a blocker
(`reference_projects/luanti/src/mapgen/mapgen.cpp:476-507`). Section 2.3
therefore forbids an ordinary rewrite
from either opening or closing/dividing any preserved cave-air component
across its owned boundary. A surface cut/fill may change the analytic open-sky
column only down to its final solid surface; it cannot extend that effect into
preserved air below or beside the owned volume. Named portals/openings require
their own complete bounded vertical-light contract. This symmetric rule, not a
false sunlight range assumption, prevents arbitrarily deep repair.

The composed transaction records every voxel whose old and final nodes differ
in `light_propagates`, `sunlight_propagates`, or `light_source`, together with
every newly opened or closed air/water voxel. The union of those voxels,
expanded by 15 nodes on each world axis and clipped only at the emerged
VoxelManip boundary, is the light-dirty region. Every changed content voxel
must be central-owner-chunk content and must have the complete 15-node
neighborhood available inside Luanti's 16-node emerge border. Otherwise the
transaction fails rather than accepting a truncated correction.

The pass snapshots the original emerged `param1` buffer. After the single
content commit, it performs all lighting work on that same mapgen
VoxelManip, without an intervening map write or second light transaction:

1. uses zero or more bounded, mapgen-only `VoxelManip:set_lighting` preparation
   calls to set both day and night `param1` banks to zero throughout the
   canonical light-dirty boxes;
2. uses only further bounded `set_lighting` preparation calls to set day light
   15 and night light 0 on final-air boxes that the analytic geometry proves
   open to sky through the available upper border; it never stamps water or an
   inferred cave opening;
3. calls `VoxelManip:calc_lighting` exactly once with
   `propagate_shadow = true`, using the complete emerged x/z extent and the
   central owner chunk's y range as its sunlight-propagation range. Luanti's
   spread phase then covers the complete emerged VoxelManip and rediscovers
   final registered light-source nodes; and
4. reads the calculated light buffer, restores the snapshotted `param1` byte
   outside the analytically allowed dirty/owned light result, and performs
   exactly one final full-buffer `VoxelManip:set_light_data` upload. Any
   computed difference outside the allowed result is also reported as a
   preservation failure.

The preparation-call count is the canonical bounded box count produced for
that dirty set; it is not a second upload count. The pinned API validates every
`set_lighting` box against the emerged VM and writes the requested packed
day/night value directly into that VM
([`l_vmanip.cpp`](../../reference_projects/luanti/src/script/lua_api/l_vmanip.cpp):231-256;
[`l_mapgen.cpp`](../../reference_projects/luanti/src/script/lua_api/l_mapgen.cpp):2019-2028).
`set_light_data` then replaces the complete VM `param1` array from the restored
Lua buffer
([`l_vmanip.cpp`](../../reference_projects/luanti/src/script/lua_api/l_vmanip.cpp):259-305).
There is still exactly one later engine blit of this VM.

This reset is required because `set_data` changes content without clearing old
`param1`, and Luanti's spreading pass does not reliably reduce stale light.
Resetting more than the exact changed nodes is intentional: ordinary emitted
light can propagate across the complete 15-step light domain. Light writes in
the emerge halo are the sole derived-state exception to central content
ownership; they may not alter content or `param2`, and the resulting values
must be idempotent when a neighboring owner chunk is later generated.

After authored lighting, Section 2.5's one conditional `update_liquids()` call
queues engine transformation. That later engine phase may perform its own node-
light updates; those are engine-owned liquid settlement work, not a second
WP40 `calc_lighting` call. The settled hash gate includes them.

If the transaction has no light-relevant content change, it performs zero
`set_lighting`, `calc_lighting`, and `set_light_data` calls. The chunk-order
corpus compares final `param1` hashes for row-major, reverse, random, vertical,
anchor-first/last, and sparse requests. Named tunnels and other deeper
envelopes must finish all lighting effects within the same complete
neighborhood or declare and prove a separate bounded strategy before they are
accepted.

### 2.7 Strata in changed volumes

**Decision (2026-08-12): select every changed natural rock node from its exact
world y through WP43; never normalize unchanged rock merely because it lies in
the rewrite shell.**

Every natural rock node newly constructed by a fill, foundation, hydrology
bed, or other authorized volume, and every natural rock node replaced as part
of an exact top/filler repair, obtains its registered content identity only
from the final WP43 `grug_materials.stratum_node_for(y)` API. The lookup is
performed for each integer world y. One vertical authored volume may therefore
contain several visual strata when it crosses a decided band boundary.

An existing natural rock node outside an exact changed volume remains
byte-identical even when it lies inside the wider Section 2.1 authorization
shell. WP40 does not sweep a shell merely to make its bands visually uniform,
and it does not overwrite an otherwise preserved ore or dungeon in the name of
stratum correction. Section 2.3 and Chapter 4 remain the only authorities for
resource intersections and authored resources.

Stratum identity is cosmetic. Neither the height field nor the terrain pass
uses it to infer mining permission, maximum pick depth, harvest tier, resource
eligibility, territory, or political ownership. Those queries remain separate
WP43/runtime contracts.

Registry initialization validates that every y reachable by any WP40 changed
volume resolves to a registered node carrying WP43's final stratum contract.
A missing API, nil/unknown result, or invalid registration is a hard startup
error before generation. There is no fallback to `default:stone`, WP25's
Emberstone names, non-zero node `level`, pick `maxlevel`, or `leveldiff`.

### 2.8 Planned inland-water envelopes

**Decision (2026-08-12): assign every planned inland-water reach one typed,
analytic depth profile with a three-node bed seal and two-node bank seal.**

Each connected hydrology reach stores an integer water-surface elevation `W`
and exactly one registered profile. Its ordinary water depth `D` is:

| Profile | `D` |
| --- | ---: |
| ford or shallow marsh | 1 node |
| stream, spring, or shallow pond | 2 nodes |
| river or delta arm | 4 nodes |
| ordinary lake or planned mainland bay | 8 nodes |
| explicitly deep cenote or waterfall plunge pool | 12 nodes |

For a water column, the bed surface is at `bed_y = W - D`; the exactly `D`
water-source nodes occupy `bed_y + 1 .. W` inclusive. The bed node at `bed_y`
uses the active logical-biome or named-landmark bed material. Three complete
solid sealing layers occupy `bed_y - 1 .. bed_y - 3`, selected by the final
stratum/landmark contract.

The analytic bank profile defines an integer bank crest for every shoreline
column. A two-horizontal-node sealing skirt outside the final water mask is
part of the same named envelope and remains solid from the local bank crest
through `bed_y - 3`. Bank and bed blends return to `H` at their declared outer
edge; they may not widen in response to a native cave or liquid.

A reach has one level `W`. A change in water level is legal only at a
registered rapid or waterfall interface whose upper/lower levels, drop mask,
plunge-pool profile, and sealed transition volume are immutable registry data.
Mapgen may not infer a level, depth, or waterfall from native v7 terrain or
current liquids.

The decided `raincall_falls` landmark uses several such registered waterfall
interfaces to join its monsoon pools. At each waterfall, the complete upstream
reach and its final lip row are authored `default:water_source`; the drop mask
below the lip is authored air, never a vertical wall of source nodes. The
ordinary liquid engine derives the falling `default:water_flowing` column from
that lip. The receiving component uses the 12-node plunge-pool profile, and the
two-node bank plus three-node bed seals form one closed chute/catchment envelope
outside the intended open top and fall face. No other apparent terrain drop is
promoted to a waterfall implicitly.

Inside the exact bed, water-column, and seal mask, planned hydrology may replace
native natural rock, generic native ore, cave air, and native liquid. Native
dungeon and unknown/foreign-structure handling still follows Section 2.4; an
ordinary water profile grants no force authority. The complete seal must pass
the pure analytic boundary/leak/light-interface checks before rendering; the
native-only preflight then checks every analytically unowned native boundary
face, while production checks only native collisions inside each central owner
slice before it is written.

All surface water remains `default:water_source`; the profile changes only
geometry and dressing. A landmark may choose a non-ordinary depth only through
an explicit registered profile/parameter covered by the manifest. It may not
derive an override from observed nodes. Audit exports include profile, `W`,
bed/seal extents, replaced-content counts, component connectivity, and every
road/bridge/ford crossing.

### 2.9 Exterior shelf, deep ocean, and dragon channels

**Decision (2026-08-12): grade every exterior shore analytically from one node
of water depth to a 32-node seabed over the exact 80-node shelf.**

Let `W` be the configured mapgen water level. The exact fixed-point signed
distance is zero on the final mainland or island perimeter and positive
outside it. An exterior water column's one-based outward band is
`d = max(1, ceil(positive_distance))`; perimeter/land columns have no exterior
`d`. Exactly `1 <= d <= 80` is `coastal_shelf`, and `d >= 81` is
`deep_ocean`. For the shelf, define:

```text
u = (d - 1) / 79
D = 1 + round_half_away_from_zero(31 * smootherstep(u))
bed_y = W - D
```

The smootherstep is the shared Section 1.4 function. Thus the first exterior
water band is one node deep, shelf depth increases monotonically, and the 80th
band reaches 32. Every ordinary `deep_ocean` column beyond the shelf has
`D = 32`. This half-open land/exterior rule prevents `d = 0` from becoming an
81st shelf band. Planned mainland bays remain zone-owned eight-node inland-
water profiles under Section 2.8 and never enter this calculation.

An `immutable_dragon_channel` overrides policy classification but uses the same
terrain profile from each final mainland or island shore. Its local `d` is the
one-based outward band derived from the nearest incident final shore. Where
that band is at least 80, channel depth is 32. The two fixed 96-node approach
corridors and landing beaches are constraints on the same continuous profile,
not separately sampled seabeds.

The bed at `bed_y` uses the stable `coast_source_zone_id` logical-biome palette;
three solid sealing layers occupy `bed_y - 1 .. bed_y - 3`. Nearest-perimeter
projection with the shared exact tie rule supplies that dressing-only source
for open sea. It does not create zone membership, a race region, territory, or
land adjacency.

For every generated vertical slice of an exterior water column, the final
content rule is analytic:

- registered bed/seal content at `bed_y .. bed_y - 3`;
- `default:water_source` at `bed_y + 1 .. W`; and
- air above `W`, replacing known native natural terrain and native surface
  decoration wherever v7 produced it.

This rule extends upward to the map limit, but the no-op prefilter performs no
write in already-correct air. It does not require the surface-containing chunk
to generate first and cannot leave a high native island or other high-terrain
remnant in a later vertical request. Native content below `bed_y - 3` remains byte-identical;
generation stops there even though runtime `deep_ocean` and
`immutable_dragon_channel` policy remains immutable for the full x/z column at
every y.

Deep-ocean and dragon-channel definitions carry no native-dungeon replacement
authority. Their deepest content is `W - 35 = -34`, above the manifest's -37
broad-content floor; every callback capable of applying them is therefore
full-VM-disjoint from native DungeonGen. This remains true for first exploration
at arbitrary deep-ocean x/z coordinates and for a later neighbor callback,
without a finite world border or a runtime halo veto. Section 2.4's finite
native-only guard still rejects any audited seed/geometry intersection as a
proof-oracle failure, but it is not claimed to cover the exterior through the
map limit. The same typed central-slice hard failure applies to unknown or
foreign structure content in every class. Each class reports cut/fill/water/
seal volume, replaced native categories, finite dungeon-guard intersections,
liquid and lighting calls, continuous channel components, approach depth, and
below-seal byte preservation for all 32 seeds.

### 2.10 Road-tunnel envelopes

**Decision (2026-08-12): use a closed two-node lining around a five-node-high
route-class lumen, with 1:12 grade, 16-node portals, and 128-node maximum
length.**

The global Section 1.5 route profile supplies each tunnel station's integer
road-surface y and direction. The cross-section catalog is:

| Route class | Visible road width | Clear lumen width | Clear height |
| --- | ---: | ---: | ---: |
| primary | 7 | 9 | 5 |
| secondary | 5 | 7 | 5 |
| trail | 3 | 5 | 5 |

At a straight station, the clear air lumen occupies five nodes above the road
surface and extends one node beyond either visible-road edge. The structural
mask is the exact two-node morphological dilation of that lumen except at the
two registered portal openings. It supplies two solid nodes beneath the
visible road/floor, two-node side walls, and a two-node ceiling. Curves use the
union of the same world-coordinate cross sections with the catalog's canonical
round join; chunk-local axis selection may not create gaps or thicker seams.

Every tunnel profile, including its interior, obeys maximum grade `1:12`. Each
portal has a 16-centreline-node analytic terrain/road blend between the open
approach and the first complete lining ring. Portal position, direction,
surface elevation, grade phase, and lining interface are fixed route records.
A contiguous tunnel may span at most 128 centreline stations. If the complete
route cannot meet that bound, the pre-generation route candidate is invalid;
mapgen neither extends the bore nor converts it to an open cut.

The lining is closed against native caves and liquids. The exact lumen, lining,
road backing, and portal masks may replace native natural rock, generic native
ore, cave air, and native liquid. The pass does not preserve an accidental cave
door or water inflow through the lining. Boundary validation must prove a
complete analytic two-node seal everywhere except the declared portals before
rendering begins. The native-only preflight verifies the complete unowned
native boundary; each production owner slice checks only native content inside
its central slice and resolves every cross-slice interface from the global
operation plan. No callback interprets a halo observation as native or claims
atomic access to the whole tunnel's native boundary.

Every tunnel stays above the global broad-content floor and therefore outside
every dungeon-writing callback collar. It also fails the seed or geometry
dataset when its audited exact operation mask intersects Section 2.4's finite
dungeon-uncertainty proof guard. Route criticality, lack of an adequate
alternate, claim exclusion, or runtime hard protection never grants dungeon
replacement authority. `force_native_dungeon = true` remains a fail-closed
validation error, and unknown or foreign structures remain non-replaceable in
all tunnels.

Tunnel excavation and lining participate in the single content, liquid, and
lighting transaction. Each portal is the only intentional connection to
surface air; any other connection beyond the exact lumen/portal mask fails.
The corpus traces lumen continuity, headroom, width, grade, seals, portal
lighting, route-class surface, maximum length, and chunk-boundary identity.

This completes the ordinary and named rewrite-envelope decisions. Chapter 4.3
binds their final precedence with Chapter 3's surface and decoration ownership.

## 3. Decorations and surface water

### 3.1 Closed placement-owner table and legacy cutover

Every generated category has exactly one target owner and one placement path:

| Category | Target owner and path | WP40 treatment |
| --- | --- | --- |
| v7 base terrain, caves, and fine detail | native C++ v7 before Lua | retained as substrate; only exact Chapter 2 volumes may override it |
| generic clay/dirt/gravel geology blobs | native engine ore registrations | retained where final host survives; staging-biome filters are not logical-zone authority |
| universal depth-only ores | native engine ore registrations using WP43 definitions | retained where final host survives; never rerun in new fill |
| six cosmetic strata | last native engine stratum registrations from WP43 | retained in unchanged rock; every new/changed rock asks `stratum_node_for(y)` |
| G1/G2 and cultural regional veins | consolidated authored WP40 resource phase | removed from native climate/biome placement |
| native dungeons | native C++ dungeon stage | unconditionally preserved by manifest-bound vertical/typed separation; Section 2.4's finite offline full-emerged-area guard remains a proof oracle |
| pure cave/underground decorations | native engine decoration stage | retained outside exact changed volumes; mixed surface/cave definitions must be split |
| native surface biome top/filler and dust | v7 staging input, then consolidated authored WP40 surface phase | final surface always follows logical zone biome; native biomemap is not public authority |
| trees, shrubs, ground cover, and other natural surface dressing | consolidated authored WP40 decoration phase | native surface registrations disabled; suitable assets migrate, native placement rolls do not |
| planned inland water, shelf, deep ocean, channels, and waterfall source lips | consolidated authored WP40 hydrology phase | generated only from analytic masks with the single water family |
| waterfall flowing columns | Luanti liquid simulator after authored source placement | derived state only; bounded and hashed after settlement |
| capital/start/POI/camp terrain and route foundations | consolidated authored WP40 terrain phase | fixed envelopes and semantic slots only; no first-writer platform height |
| visible settlements, camps, civic interiors, and ordinary structures | WP13 through WP40 anchors/interfaces | not placed by WP40; large later schematics must use deterministic owner slices |
| POI/entity metadata after generation | sparse main-environment consumer via custom gennotify | no broad scan and no second terrain write |
| WP33 cultural woods, herbs, spices, and surface gatherables | WP33 through WP40 zone/biome/source masks | WP40 supplies opportunity geometry, not unregistered nodes |
| WP34 refill and deep multipliers | WP34 through semantic camp/depth seams | WP40 reserves geometry only |

The current `grug_mapgen` files cut over as follows:

- `geometry.lua` and the radial/cuboid authority are replaced by the compiled
  38-zone geometry and public API;
- `biomes.lua` may retain only minimal native-v7 staging registrations; its
  ring/cuboid result is never a logical-biome result;
- `ores.lua` retains reviewed generic geology blobs, WP43's universal native
  resources, and the intentional last-registered strata; regional G1/G2
  placement moves to Chapter 4's authored phase, while cultural source masks
  hand off to WP33;
- `decorations.lua` is split into retained cave-only registrations and the
  authored surface catalog;
- `ocean_mask.lua`, `ocean_mask_mapgen.lua`, and their healing LBM are retired
  after the consolidated pass proves the new coast/water contract; and
- `structures.lua` loses platform-height selection, persistent POI choice, and
  broad main-environment VoxelManip work. WP40 retains stable terrain/slot
  records; WP13 later owns visible structures.

The existing `mods/BASE/default/mapgen.lua` suppression of duplicate upstream
biome/ore/decoration registration remains a documented vendor patch; WP40
changes project-owned registrations rather than re-enabling a second upstream
placement path. A legacy pass is deleted only after its target owner, consumer
cutover, and hash/preservation tests pass in the same reviewed change.

### 3.2 Surface-decoration ownership

**Decision (2026-08-12): author every natural surface decoration from the
logical zone biome; retain only explicitly cave/underground decoration as
native.**

Inside the authored world, trees, shrubs, grasses, flowers, surface fungi,
loose surface rocks, and comparable natural surface dressing have exactly one
owner: the consolidated WP40 authored pass. Selection uses
`grug_zones.biome_at`, the owning zone's decided weighted palette, the complete
decimal seed, and stable decoration/candidate IDs. Engine climate, the native
biomemap, and `core.get_biome_data` are not placement authorities.

Native surface-decoration registrations are omitted or disabled rather than
allowed to run and then guessed away from node names. Existing suitable tree,
plant, schematic, and ground-cover assets may be migrated into the authored
catalog, but migration does not retain their native coordinate or biome roll.
A decoration definition that can currently place both at the surface and in a
cave must be split into two explicit registrations/categories before WP40; one
placement event may never have both owners.

Pure cave and underground decorations remain in the native v7 pipeline. They
stay byte-identical outside Sections 2.3--2.10's exact changed volumes. If a
changed volume owns their location, the explicit terrain conflict category
applies; WP40 does not move the decoration to a nearby cave or rerun the native
decoration generator.

The composed authored order is terrain and strata, planned water, route and
structure terrain masks, logical top/filler, then surface dressing. Ordinary
surface dressing rejects every road surface/corridor rule that forbids it,
planned water or bank exclusion, POI/structure envelope, protected arrival
area, housing exclusion, and named landmark mask that supplies its own
dressing. A landmark's registered decoration set has priority over ordinary
vegetation only inside its exact mask; it gains no territory or protection
authority from that priority.

WP40 owns the placement architecture, logical palette coverage, deterministic
candidates, and future semantic source/slot geometry. It does not register or
place WP33's herbs, spices, cultural woods/material gatherables, or other later
surface content. Those consumers must use the stable zone, biome, landmark,
and exclusion queries rather than restore a native climate/ring placement.

Every authored placement records its zone ID, logical biome ID, decoration ID,
candidate ID, rejection reason, and owning owner-chunk. The 32-seed audit
checks the decided post-road/structure palette shares, absence outside the
zone palette, complete exclusions, and no floating or buried result.

### 3.3 Deterministic surface candidates

**Decision (2026-08-12): place authored surface decoration through a
world-aligned stratified cell catalog with finite local-priority exclusion.**

Every decoration definition stores a schema-versioned cell size, finite
candidates-per-cell count, density gate, complete occupancy footprint,
collision group, compatibility layer, allowed logical biomes/zones, and stable
decoration ID. Cells are half-open world-coordinate boxes aligned to integer
multiples of the cell size. Cell coordinates use mathematical floor division
for negative x/z; implementation-language truncation toward zero is forbidden.

For an accepted candidate, its exact oriented per-voxel occupancy footprint is
a named authored-decoration envelope and part of the immutable global operation
plan. That envelope, including a crown or schematic above `shell_ceiling`, owns
only its listed final-air/replaceable-surface intersections; it does not widen
the terrain shell or authorize replacement of native dungeon, foreign
structure, planned water, route, or other non-replaceable content. Every
intersecting owner chunk renders only its central slice of this same envelope,
and the preservation oracle treats it as an exact owned volume.

For each cell and candidate index, domain-separated full-seed hashes determine
the integer in-cell x/z offset, density admission, stable priority, variant,
rotation, and any optional per-voxel schematic choices. Hash-to-range uses one
shared unbiased integer rule. No candidate consumes a mutable PRNG stream, Lua
table iteration order, callback block seed, or another candidate's random
result.

A candidate is statically valid only when its complete footprint, trunk/root
support, crown/headroom, slope and logical palette satisfy the immutable final
terrain and exclusion queries. Within a collision group it is accepted only if
its priority tuple is the strict minimum among all statically valid candidates
whose complete occupancy footprints overlap it. The tuple ends with stable
decoration ID, cell x/z, and candidate index, so no tie is unresolved. This
local-minimum rule is deliberately conservative rather than a sequential
greedy fill: the finite neighbor radius follows from catalog cell sizes and
maximum footprints, and no first writer or transitive global walk is needed.

Compatibility between canopy, understory, and flat ground-cover layers is an
explicit symmetric table. Candidates in compatible layers may coexist;
otherwise the same overlap rule applies. Definition order and callback order
never imply compatibility or priority.

One accepted large tree or schematic is one global placement record. Every
intersecting owner chunk recomputes that decision and renders only its central
slice, including deterministic per-voxel probability and `param2`. The chunk
containing the root does not write the crown into neighbors. If runtime content
inside the required slice contradicts the prevalidated authored inputs, the
pass raises the relevant conflict rather than clipping, burying, floating, or
silently omitting part of the placement.

Catalog density values are calibrated in implementation but frozen into the
world manifest before rollout. The 32-seed audit reports candidates, density
rejections, static-invalid reasons, overlap rejections, accepted counts,
coverage, and edge-biased cases by zone/logical-biome/decoration. Calibration
may not alter the decided zone-biome shares or introduce a decoration outside
its content palette.

### 3.4 One surface-water family and v7 normalization

**Decision (2026-08-12): expose one universal surface-water family: authored
`default:water_source` plus only its engine-derived
`default:water_flowing` companion.**

The two registered nodes are one Luanti liquid family, not two geographic or
gameplay water types. Every WP40-authored water voxel initially written into a
planned inland-water, shelf, deep-ocean, or dragon-channel water column is
`default:water_source`. `default:water_flowing` may appear only as derived
liquid-simulator state, notably below a registered waterfall source lip or
after later player edits. It carries no water class, zone, salinity, ownership,
or persistent authored identity.

Vendored `default` registers `default:river_water_source` and its flowing mate
unconditionally and binds the `mapgen_river_water_source` alias because some
core mapgens with sloping rivers require a short-range, non-renewable liquid
(`mods/BASE/default/mapgen.lua:9`, `mods/BASE/default/nodes.lua:2296-2390`).
The pinned `mapgen_v7.cpp` contains no river-water-node use, and no current
Grudgelands pass places either node. They are therefore registered legacy
"ghosts" in the shipped v7 configuration, not expected WP18/WP36 v7 output.

Both nodes nevertheless remain explicit invalid-input categories so a future
registration/helper drift, imported schematic, or diagnostic fixture cannot
silently create a second surface liquid family. Inside every authoritative
surface volume, the pass removes or replaces any observed
`default:river_water_source`, `default:river_water_flowing`, native ordinary
water, and native ordinary flowing water according to final analytic geometry.
The baseline audit normally reports zero river-water observations; a non-zero
count identifies provenance rather than being attributed to v7 automatically.

Only a registered `planned_water`, `coastal_shelf`, `deep_ocean`, or
`immutable_dragon_channel` x/z mask may produce authored surface water. Outside
those masks the final analytic surface is dry: incidental v7 pools or ridge
channels inside the exact cut/fill/top-filler volume become air or final ground
and never create a water classifier, logical biome, claim exclusion, or
landmark. Underground liquids outside exact changed volumes retain Section
2.5's byte-preservation rule and are not reclassified from their node name.

Water art is independent of liquid identity. The universal source/flowing pair
may later receive one globally chosen coherent texture/animation set, including
adapted existing river-water art if desired, without retaining the river-water
nodes or introducing regional liquid variants.

All authored sources and waterfall lips participate in the one composed
content transaction and the one conditional `update_liquids()` call from
Section 2.5. Waterfall acceptance records the authored pre-simulation hash,
runs the engine liquid queue to the suite's frozen quiescence limit, and then
compares the settled source/flowing content and `param2` hashes across chunk
orders. It also asserts a continuous fall into the registered plunge pool, no
flow beyond the sealed hydrology envelope, no river-water nodes, and stable
repeat settlement. Failure to settle within the frozen limit is a hard test
failure, not permission to widen the chute.

Chapter 4.3 binds the final precedence table for this surface-water family,
authored terrain, resources, structures, and decorations.

## 4. Resource placement

### 4.1 Native versus authored ownership

**Decision (2026-08-12): retain universal depth-only resources in v7's native
ore pass and place every zone- or race-region-dependent resource in the exact
authored pass.**

After WP43, the native C++ ore pipeline continues to own every entry in
`grug_materials.RESOURCES` whose `scope == "universal"`: Coal, Copper, Tin,
Iron, Quartz, Gold, Silver, Emberglass, and Abyssal Crystal. Code obtains each
node through `grug_materials.resource_node(key)` and its registry row; this
list is an audit statement, not a second runtime roster. WP43 owns identity,
host/resource registration and harvest tier. WP40 owns the final native
placement literals and calibrates them from the retained generic scatter
baseline plus final accessible-volume audits. `CURRENT_SCATTER_RESOURCES` is
explicitly transitional and may not be filtered into the target roster.

Abyssal Crystal consumes `DENSITY.abyssal_crystal` and must retain its decided
T5-entry availability before T6 access. Native v7's signed-low-32-bit seed
behavior for these generic deposits is accepted and recorded; it does not
become the seed behavior of authored geometry.

The WP40 authored resource pass exclusively owns:

- each race region's exact G1 and G2 natural-node species and depth curve,
  selected through `grug_materials.RACE_REGIONS`; and
- any registered future underground natural resource whose species or
  eligibility explicitly names an authored zone, landmark, stable resource
  slot, or `race_region`.

WP40 does not fabricate a natural node for a cultural item. It compiles the
ordinary surface and concentrated contested-T4 opportunity masks for the
`CULTURAL_MATERIALS` and `SIGNATURE_WOODS` keys selected by the same race row;
WP33 later owns their registered surface source and placement. Ordinary/apex
camp source records likewise remain semantic reservations for WP13/WP34.

Those candidates use the complete decimal seed and immutable authored
geometry. `race_region` selects culture and resource species but grants no
territory, PvP, claim, or mining right. Exact y and WP43's independent harvest
tier remain separate eligibility tests.

The ordinary authored-vein host at world y is exactly the registered node
returned by `grug_materials.stratum_node_for(y)` in the already composed final
terrain plan. The broad `grug_natural` group is not sufficient: it also covers
dirt, sand, beaches, and other generated ground that must not become a vein.
At `y < broad_content_y_min`, an eligible final stratum node is the only
replaceable category. A generic native ore is not an eligible host and remains
unchanged; supply is calibrated against the actually surviving exact-host
volume rather than granting a second replacement category.

Within an accepted exact authored vein mask, the regional G1/G2 resource may
replace only that exact final stratum host. It may not replace generic native
ore, cave air, liquid, top/filler or constructed surface nodes, native dungeon,
`CONTENT_IGNORE`, unknown, or foreign structure content. The runtime test is a
closed content-ID allowlist resolved from the manifest-bound WP43 host set,
never `grug_natural`, `is_ground_content`, or a negative name list. An invalid
mandatory vein follows its frozen candidate/failure rule instead of widening
its mask.

New rock created by terrain fill is intentionally sterile for universal native
ores because WP40 never reruns the C++ ore registrations. It may host an exact
authored G1/G2 natural resource when all final geometry, y, region, and WP43
host rules pass at or above the broad floor. Below that floor the native input
itself must already be the exact final stratum host; a broad terrain fill cannot
create it there. The supply audit measures actual accessible eligible-host
volume, native-ore clipping, and changed-volume sterility rather than assuming
gross x/z area.

WP33 remains the owner of actual surface herb, spice, cultural wood/material,
and other gatherable registrations and placements. WP40 supplies their stable
zone/biome/landmark source masks, exclusions, candidate geometry, and semantic
slots only. Likewise, WP40 reserves and validates the two island apex camps and
24 semantic G1/G2 socket positions, but WP13 realizes the camp/socket structure
and WP34 owns renewable refill behavior and deep multipliers.

No WP25 legacy item/node name, Emberstone identity, non-zero node `level`, pick
`maxlevel`, `leveldiff`, or `level_for_tier` helper is authoritative. The
verified WP43 handoff below is the final runtime contract.

### 4.2 Deterministic authored veins

**Decision (2026-08-12): generate authored regional resources from
world-aligned 16-by-16-by-16 candidate cells and short deterministic chains of
ellipsoid segments.**

Each authored resource has its own half-open 3D grid aligned to integer
multiples of 16. Cell x/y/z use mathematical floor division at negative
coordinates. A cell has exactly one stable candidate anchor and one admission
roll derived from domain-separated hashes of the complete decimal seed,
resource ID, and cell coordinates. The resource's exact depth band supplies
the admission threshold; no native mapgen block seed or mutable PRNG stream is
used.

An admitted candidate contains two through five overlapping ellipsoid
segments. Each segment has an integer major radius in `[2, 4]` and two integer
minor radii in `[1, 2]`; stable hash lanes determine count, orientation,
offsets, radii, and the candidate priority. The catalog's canonical integer
ellipsoid membership and segment-composition rules are shared by mapgen and
offline audits. One global mask may cross any number of chunk boundaries, and
each owner chunk writes only its central slice.

The mask is decided before native-content inspection. Rendering replaces only
the exact final stratum host from Section 4.1. Cave air, liquid, dungeon,
surface/constructed nodes, or unknown/foreign structure clips the intersecting
part; it does not move the anchor, change the shape, or trigger a new roll.
Generic native ore also clips the vein and remains native. Production reports
an encountered ineligible target only as the provenance-neutral deep-skip
category `non_host`. It may additionally report
`registered_dungeon_name_collision_non_provenance` when the observed content ID
matches one of the manifest-bound biome dungeon-node registrations, but that is
diagnostic name collision only: it is never a `dungeon` category, writer
provenance, or placement input. A controlled offline fixture may retain its own
authored provenance label for an oracle; production cannot derive that label
from the node.

When two authored resource masks claim the same eligible voxel, an immutable
resource-priority rank wins; equal rank resolves by candidate priority, stable
resource ID, cell x/y/z, then segment index. The complete ordering is symmetric
data generated with the resource registry, never Lua registration or callback
order.

Admission thresholds are calibrated against actual eligible and practically
accessible host volume across the fixed corpus, then frozen in the world
manifest. G2 targets approximately one node per 12,000 eligible hosts in T4,
one per 6,000 in T5, and one per 3,000 in ordinary T6. G1 thresholds consume
`grug_materials.DENSITY.g1` and the decided regional-equality model; cultural
opportunity masks are audited separately and do not invent an ore-density row.
The 32-seed audit verifies natural veins plus the one semantic ordinary camp
per region within the decided normalized +/-5 percent balance, as well as
practical enemy-exclusive G2 access paths.

Failure of a measured threshold before rollout requires an explicit catalog
revision and complete rerun. Runtime generation never adds a compensating vein,
changes admission after observing a sparse region, or enforces a global quota.

### 4.3 Typed conflict resolution and execution order

**Decision (2026-08-12): resolve authored intersections through a closed typed
matrix before rendering, then execute one fixed transaction pipeline.**

Every analytic feature is first planned in complete world coordinates without
writing nodes. Two mandatory authored masks may overlap only when their pair
has a named resolver and the intersection satisfies that resolver's complete
interface contract. The initial closed resolver set is:

| Feature pair | Required resolver |
| --- | --- |
| route and planned water | registered bridge, ford, or tunnel interface |
| route and capital/start civic envelope | fixed gate/arrival interface |
| planned water and capital civic envelope | registered civic-water composition |
| island/mainland coast and immutable dragon channel | shared fixed shore and approach profile |

The resolver owns the exact overlap mask, final heights, cross sections,
seals, materials, protection/exclusion fields, and tie rules. It may not be
synthesized from feature priority at runtime. An unlisted pair overlap, or a
listed pair that lacks its required interface record, is a hard geometry
failure. There is no universal numeric "higher feature wins" fallback.

After authored geometry resolves to at most one target operation per voxel,
production applies native-content precedence only to pre-overlay nodes in the
current central owner slice. Cross-owner content categories come from the
global operation plan; native facts at analytically unowned boundary faces come
from the completed native-only preflight. Halo content and `CONTENT_IGNORE`
never participate in the following runtime precedence:

1. unknown or foreign structure content always vetoes replacement;
2. native dungeon content is never replaceable; global preservation follows
   the manifest-bound vertical/typed proof, while the finite offline
   `native_dungeon_uncertain` guard rejects every audited target-operation
   intersection before production manifest freeze;
3. an exact resolved terrain, planned-water, foundation, road, or tunnel volume
   replaces the natural rock, cave air, generic native ore, native decoration,
   or liquid categories its own contract explicitly permits;
4. an authored regional G1/G2 vein replaces its exact final stratum host under
   Chapter 4 and nothing else; generic native ore clips it and remains native;
5. registered landmark dressing resolves before ordinary authored surface
   dressing; and
6. every native node not claimed by one of those exact operations remains
   byte-identical.

At `y < broad_content_y_min`, items 1, 3, and 5 admit no operation at all.
Item 4 is the sole possible authored content change and uses the manifest-
resolved exact host ID. A wrong host is a typed skip, not a fatal production
collision; production counters distinguish only `eligible_host_replacement`
from provenance-neutral `non_host` skips. The optional
`registered_dungeon_name_collision_non_provenance` diagnostic may identify a
registered-name collision but must never be aggregated or described as dungeon
clipping. Positive native-dungeon evidence remains confined to Section 2.4's
isolated native-only callback/emerged-area guard and finite offline
intersection proof. Missing or drifted host/output registrations are fatal at
startup. No deep typed operation sets
`param2`, changes liquid topology/light behavior, or schedules metadata or an
entity. These restrictions are part of the operation type, so a plugin catalog
cannot request a deep broad write through a nominal resource record.

Hard protection, territory, PvP, and claim exclusion are parallel analytic
outputs, not extra voxel priorities. A terrain resolver cannot acquire or
weaken any of them by winning a content conflict.

The consolidated pass uses this fixed execution pipeline:

1. build and validate all immutable geometry, authored overlaps, and named
   resolver interfaces;
2. observe the bounded native VoxelManip input and classify conflicts without
   changing the authored decisions;
3. compose final terrain, strata, planned-water, top/filler, foundation,
   route, tunnel, and surface operations into the per-voxel target plan;
4. compose authored regional G1/G2 resource operations against that final
   host plan;
5. compose landmark and ordinary surface-decoration operations against every
   prior exclusion and occupancy result;
6. upload final content exactly once with `set_data()` when the content dirty
   set is nonempty, and upload final `param2` exactly once with
   `set_param2_data()` when its separate dirty set is nonempty, both on the same
   mapgen VoxelManip and inside the one transaction before the engine blit;
7. if and only if light-relevant content changed, perform Section 2.6's
   canonical bounded `set_lighting` preparation calls, exactly one
   `calc_lighting`, snapshot restore, and exactly one final `set_light_data`
   upload on the same VM;
8. call `update_liquids()` once if and only if liquid topology changed, thereby
   queuing the later engine-owned transform rather than settling it in Lua; and
9. emit only compact custom gennotify records required for later metadata,
   entity initialization, diagnostics, or main-environment consumers.

“One content commit” means at most one `set_data()` upload; it does not conflate
the engine's distinct content and `param2` arrays or permit a second VoxelManip
transaction. No phase rereads uploaded nodes to make a new placement decision,
invokes another content upload/transaction, or relies on another callback's
registration order. The no-op path skips both buffer uploads, liquid call,
lighting work, and gennotify output. Tests enumerate every matrix pair, every
legal resolver, every veto class, and content-only/param2-only/combined/no-op
dirty sets, including chunk-edge intersections and reversed feature
registration order.

### 4.4 Verified WP43 runtime handoff

**Verified (2026-08-12): the merged WP43 contract at `e7f393c` supplies every
material identity and placement datum WP40 is allowed to consume.**

In the main environment, the handoff adapter iterates `grug_materials.TIERS`
and uses `TIER_BY_KEY`, `tier_at(y)`, `stratum_node_for(y)`,
`max_depth_for_pick_tier(tier)`, and `can_mine_natural_at(pick_tier, y)` as
appropriate. It never copies a depth boundary, stratum node, depth-access rule,
or harvest tier into WP40 source. WP40 does not replace the mining transaction
or its protection-first ordering.

Natural-resource identity comes from `RESOURCES`, `RESOURCE_BY_KEY`,
`RESOURCE_BY_NODE`, `resource`, `resource_for_node`, and `resource_node`.
`scope == "universal"` selects the native-placement roster; `scope ==
"regional"` plus `grade == "G1"` or `"G2"` selects the authored roster. The
per-column species and semantic surface supply come from `RACE_REGIONS`,
`GEM_GRADES`, `CULTURAL_MATERIALS`, and `SIGNATURE_WOODS`. Placement/audit
inputs come from `DENSITY`. Its `deep_bands` records remain a checked handoff
to WP34: WP40 may project them in the supply ledger but does not apply the
later `1.25`/`1.50` production multipliers early.

Any generated ground, filler, beach, shelf, seabed, or authored rock node that
WP40 adds must also be added to `NATURAL_GROUND_NODES` and registered through
`natural_groups(groups)`, yielding `grug_natural = 1`. Crafted or decorative
nodes must not receive that group. The WP43 startup audit must remain green;
`is_ground_content` is explicitly not a substitute classifier.

`CURRENT_SCATTER_RESOURCES`, `LEGACY_ALIASES`, `STORAGE_DERIVATIVES`, and
`canonical_name` are baseline/migration surfaces, never target placement data.
WP40 emits no upstream Mese/Diamond natural node and no name containing a
`FORBIDDEN_RUNTIME_STEMS` entry. In particular, canonical Diamond placement
uses the regional resource row, not `default:stone_with_diamond`.

After WP43's own validation has run, the main-state compiler copies a
canonical, immutable projection of only the fields above and hashes it as the
WP43 registry checksum used by the world manifest and IPC readiness gate. It
does not mutate or expose WP43's public tables, transfer functions over IPC, or
create a shadow material registry.

Normal mod globals do not cross into an emerge Lua state. The mapgen adapter
therefore iterates the checked IPC projection through one shared lookup module;
it does not assume a main-state `grug_materials` table exists, and it contains
no literal y boundary, tier, resource, or node ID. Main-state golden vectors at
every WP43 band boundary and every resource/race key prove that this projection
returns the same results as the public APIs. Each environment resolves semantic
keys to registered content IDs locally and fails before generation on any
missing or disagreeing registration.

## 5. Registry, initialization, IPC, and memory

### 5.1 One checked immutable transfer

**Decision (2026-08-12): compile the compact seed-derived world dataset once
in the main Lua state and transfer it once into each mapgen state.**

After all registrations are available and before mapgen states begin serving
chunks, the main state validates the authored source and WP43 handoff, then
compiles exactly one immutable dataset containing the 38-zone registry,
canonical/displaced shared boundaries, land and boat graphs, anchor/candidate
records, selected heights and route profiles, hydrology and coast/channel
geometry, typed resolver records, protection/exclusion geometry, and the
prebuilt spatial acceleration grid.

The payload is compact analytic data. It never contains a whole-world height
raster, voxel map, decoration/resource placement list, generated native-node
observation, function, closure, userdata, or metatable. Pure evaluators are
loaded from the same project source files in every environment; IPC carries
only their immutable inputs and compiled indices.

Section 2.4's native-dungeon uncertainty guards do not weaken this rule. They
are native-only preflight/release evidence used to accept or reject a candidate
seed and compiled geometry within the finite audit corpus before manifest
freeze, not production inputs or global coverage. The release evidence retains
their canonical owner-slice projection and digest; neither IPC nor mod storage
carries per-callback areas, room centers, or generated native observations.
The compact dataset instead carries the critical vertical-separation constants
and exact registered host/output/dungeon sets needed for each consumer to
revalidate Section 1.1 locally.

The main state publishes the dataset under one schema-versioned IPC key. Each
mapgen state performs exactly one `core.ipc_get` during initialization, checks
the schema, complete-seed hash, source checksum, compiled-dataset checksum,
record counts, and critical mapgen manifest fields, and retains the unpacked
value locally. A missing payload or mismatch is a fatal startup error before a
chunk callback is registered. There is no IPC access in `H`, `id_at`, a spatial
query, column loop, candidate loop, or generated-chunk callback.

This readiness order follows the pinned server lifecycle: main-state mods load
and execute before `initMapgens` creates the emerge states
(`reference_projects/luanti/src/server.cpp:534-577`), and each emerge state
registers the IPC API during its initialization
(`reference_projects/luanti/src/script/scripting_emerge.cpp:55-80`). The
publishing main mod therefore fails startup before mapgen initialization if it
cannot compile/set the payload; an emerge consumer never polls or waits for a
value that might appear later.

IPC is a transport rather than shared Lua memory: Luanti stores a packed value
and every `ipc_get` unpacks a distinct table graph. The packed IPC value remains
available for every configured mapgen state and any state reinitialization; a
consumer cannot mutate it by changing its local result. Internally, each state
keeps its local graph private and treats it as immutable. Public accessors
return scalar values or defensive copies and never expose a mutable definition,
polygon, profile, candidate array, or index table.

Payload records use canonical arrays and explicitly sorted key/value sequences,
not unspecified Lua table iteration. Registered node names and semantic WP43
resource/material IDs cross IPC; each Lua state resolves and validates its own
numeric content IDs during adapter initialization. Content IDs and environment-
specific API objects are not manifest data.

The required initialization benchmark compares the accepted transfer against
a retained test-only per-state compiler path. It records at least:

- main compiler wall time, allocation/GC activity, and peak memory;
- canonical and engine-packed payload size;
- each state's IPC unpack, checksum, index/adaptor initialization time, and
  retained local size;
- total RSS and startup latency with one production and explicit two-/four-
  state diagnostic configurations; and
- first-chunk and steady-chunk cost after initialization.

Production remains one v7 emerge thread. Measurements do not permit switching
to per-state construction silently: a strategy change alters the reviewed
initialization contract and requires the determinism and benchmark corpus to be
rerun. IPC is never a cache-miss or runtime recovery channel.

Main-environment mod storage contains only the canonical world-geometry
manifest and sparse later runtime records. It never stores anchor heights,
route profiles, polygons, generated-node observations, per-chunk completion,
or a cache used to answer geometry. The manifest records the full-seed hash,
source/compiled checksums, schema and algorithm versions, engine/game pins,
critical mapgen settings, WP43 registry checksum, accepted native-only evidence
digest, and rollout state. Its bytes are compared before the IPC payload is
published.

A missing manifest may be created only through the explicit fresh-world
initialization path before any WP40 chunk callback is enabled. A missing
manifest in an existing/unknown world, a checksum mismatch, or an interrupted
initialization state is fatal; WP40 does not infer safety from loaded nodes or
reconstruct a first-writer manifest. Mapgen states cannot read mod storage and
do not need it: their one checked IPC snapshot contains the immutable inputs.
Dynamic claim/ACL data later owned by WP24 uses separate storage and never
mutates this geometry manifest.

### 5.2 Shared 128-node spatial index

**Decision (2026-08-12): accelerate every hot authored-geometry lookup through
one world-aligned 128-by-128 x/z grid backed by exact boundary tests.**

The compiled grid covers the finite interesting extent containing the mainland
frame, both island envelopes, the complete shelves, channels, approaches, and
the maximum footprint halo of any indexed authored feature. A coordinate
outside that extent takes a constant direct `deep_ocean` path without indexing
or polygon work. Grid coordinates use mathematical floor division for negative
x/z and cells are half-open.

Each cell contains separate sorted layers for zone/coast classification,
logical-water masks, routes, hydrology, anchors/POIs, hard-protection masks,
and claim-exclusion geometry. A homogeneous classification cell stores its
direct scalar result. A boundary cell stores only the candidate polygon/edge
IDs and integer/fixed-point bounding boxes that can intersect it. It never
stores an approximate sampled answer.

`id_at(x, z)` first takes the O(1) cell path and invokes the common exact
point-in-polygon/side-of-shared-edge evaluator only for that boundary cell's
short sorted candidate list. Each ordinary shared land edge is compiled once
for both incident zones; an exact point tie belongs to the lower canonical zone
ID. Outer coasts, Holy endpoints, channel overrides, water-ownership seams, and
other exceptional boundaries carry their explicit half-open ownership rule in
the shared edge record rather than inheriting a generic tie accidentally.

The grid is an acceleration product, not geometry authority. Mapgen, runtime,
and offline tools use the same exact evaluator and compiled records. AreaStore,
engine biomemap, generated nodes, and a second main-state approximation cannot
replace it.

Hot scalar queries, including `id_at`, `biome_at`, `race_region_at`,
`faction_at`, `surface_level_at`, water class, boundary distance, and route
distance/ID, allocate no result table and never scan all 38 definitions.
Definition-oriented `get`, `at`, `neighbors`, and `anchor` return defensive
copies. Their convenience allocations are forbidden inside per-column and
per-voxel loops.

For every corpus seed, a slow full-polygon/feature oracle checks the complete
grid over all cells plus dense edge, vertex, junction, negative-coordinate,
coast, Holy, island, and channel samples. It asserts identical classifications
and tie results, records maximum candidates tested per layer, and fails on an
unindexed intersecting feature or a homogeneous-cell false classification.

### 5.3 Public API and scalar 3D policy

**Decision (2026-08-12): return stable scalar policy IDs from hot 3D queries
and keep dynamic claim authorization outside the immutable zone registry.**

`grug_zones.territory_rule_at(pos)` returns exactly one of these IDs:

| Rule ID | Static construction/mining meaning |
| --- | --- |
| `immutable_ocean` | no player modification at any y |
| `contested_deep` | both factions may modify, subject to tools and later non-geographic rules |
| `holy_grounds` | no player modification in the shallow Holy volume |
| `hard_protected` | no player modification in the exact bounded world-content volume |
| `contested_land` | both factions may modify, subject to tools and later non-geographic rules |
| `home_faction` | owning faction may modify; enemy faction may not |

The immutable rule catalog stores the complete flags behind each ID. A rare
definition accessor returns a defensive copy; the hot query returns only the
interned string and allocates no table.

Zone-definition vocabulary and effective-query vocabulary are intentionally
distinct. Authored peaceful rows retain the exact source values `accord_home`
or `throng_home`; Stage 1 accepts and validates those values. At query time
both map to effective `home_faction`, while `faction_at(pos)` supplies the
corresponding `accord` or `throng` owner. `contested_land` and `holy_grounds`
retain their names until a stronger 3D precedence rule replaces them. No source
zone row stores `home_faction`, `contested_deep`, `hard_protected`, or
`immutable_ocean` as if those effective results were horizontal zone identity.

The static precedence is exact:

1. `deep_ocean` or `immutable_dragon_channel` at any y returns
   `immutable_ocean`;
2. every other classified land, planned-water, or shelf column at `y <= -701`
   returns `contested_deep`;
3. Holy Grounds at `y >= -700` returns `holy_grounds`;
4. an intersecting shallow hard-protection volume returns `hard_protected`;
5. an ordinary level-31--60 surface zone returns `contested_land`; and
6. an ordinary level-1--30/capital surface zone or its inherited peaceful
   planned-water/shelf policy returns `home_faction`.

WP24's active claims are dynamic runtime authorization, not a seventh static
geography ID. The runtime authorizer checks them after hard protection but
before applying `contested_land` or `home_faction`. It never checks or honors a
claim after an `immutable_ocean`, `contested_deep`, or `holy_grounds` result.
Permanent claim exclusion is a separate allocation-free static predicate over
roads, water, POIs, boundaries, and housing masks. Thus mutable road terrain
can return `home_faction` or `contested_land` while remaining permanently
unclaimable.

The public surface is at least:

- `get(id)`, `at(pos)`, `neighbors(id)`, and `anchor(zone_id, slot_id)` return
  defensive copies; an absent zone/slot returns `nil`;
- `id_at(x, z)`, `biome_at(pos)`, `race_region_at(pos)`, `faction_at(pos)`,
  `territory_rule_at(pos)`, `pvp_rule_at(pos)`, and `surface_level_at(pos)`
  return allocation-free scalar values;
- `water_class_at(x, z)` returns `land`, `planned_water`, `coastal_shelf`,
  `deep_ocean`, or `immutable_dragon_channel`; and
- `coast_source_zone_id_at(x, z)` returns the nearest exact perimeter-zone ID
  for an exterior shelf/deep/channel dressing or inheritance query, and `nil`
  where that projection is not defined; it does not confer zone membership; and
- static distance/ID/exclusion queries for boundaries, routes, hydrology, and
  claim eligibility consume the same index and exact tie rules.

The only stable anchor-slot families are `start`, `capital`, `village_n`,
`outpost_n`, `bandit_n`, `mine`, `mirefolk`, `clash_n`, `dragon`, `apex_mine`,
and `rare_<id>`. Their per-zone cardinalities come from the authoritative
catalog. An absent slot returns `nil`; the API never synthesizes a coordinate
from a caller-provided suffix.

`id_at` and `at(pos)` return a named zone only for its land and zone-owned
planned water. Every exterior-ocean class, including editable shelf, returns
`nil`; inherited shelf behavior uses `coast_source_zone_id_at` and does not
create a 39th zone. `faction_at(pos)` returns `accord` or `throng` only when
the effective 3D position is peaceful faction territory or peaceful inherited
shelf; contested land, contested depth, Holy Grounds, deep ocean, and channels
return `nil`. `race_region_at(pos)` remains independent: it projects down every
non-ocean zone column and across an inherited shelf until a deep-ocean/channel
override, and never grants ownership.

`pvp_rule_at(pos)` returns `peaceful`, `contested`, or `outside`. Non-ocean
`y <= -701` and every contested/Holy/island surface zone return `contested`;
peaceful zone water and shelf inherit their owning surface zone; deep ocean and
immutable channels return `outside`. WP41 owns player tag transactions but may
not reinterpret this geography.

The compatibility `open_sea_at` is true only for `deep_ocean`, not planned
water, shelf, or channel. Existing `grug_core` difficulty, mob/guard level,
protection, PvP-geography, and open-sea entry points become consumers of this
API before old ring/rectangle fields are removed. Surface level remains
separate from depth; consumers compose mob level as
`max(surface_level_at(pos), depth_level_at(pos.y))`.

### 5.4 Three-stage fail-fast validation

**Decision (2026-08-12): reject an invalid source, compiled dataset, or IPC
copy before registering any generated-chunk callback.**

Stage 1 validates the authored source before compilation. It proves at least:

- exactly 38 unique canonical string and numeric zone IDs, with every required
  field, one valid `race_region`, valid policy IDs, and complete allowed
  logical-biome palettes;
- exact symmetric land adjacency, a separate exact boat/travel graph, no
  duplicate/self edge, and no boat edge promoted to polygon adjacency;
- legal stable anchor-slot names, required/absent slot cardinality, six starts,
  six capitals, and the binding POI budgets;
- `water_level = 1`, `chunksize = 5`, both dungeon y limits, dungeon noise/
  flags, `broad_content_y_min = -37`, and an always-false
  `force_native_dungeon` in the critical source manifest;
- closed, consistently oriented, non-self-intersecting authored polygons and
  one shared source record for every incident boundary; and
- exact Holy, start, capital, island, channel, coast, water, route-class, and
  road-interface constants required by the design source.

Stage 2 validates the complete compiled seed dataset. It proves at least:

- no land gap or overlap except the explicit half-open/tie ownership rule;
- every displacement, core width, travel neck, boundary buffer, coast/channel
  clearance, envelope, and minimum route constraint;
- complete feasible anchor heights, feature templates, route profiles,
  hydrology components, tunnel/water seals, and typed resolver interfaces;
- enumeration of every final T2--T7 content-operation coordinate, proving all
  non-resource operations stay at y >= -37 and every deeper operation is the
  exact-host-only typed resource kind;
- exact graph/polygon agreement, all anchors inside their intended zone and
  no-jitter clearance, and no orphan/unreachable compiled record; and
- the Section 5.2 grid agrees with the slow complete oracle for all exhaustive
  compiler checks.

Stage 3 runs independently in every IPC consumer before its adapter becomes
available. One schema-versioned canonical encoder writes fixed tags,
length-prefixed strings/arrays, explicitly sorted maps, and exact integer/
fixed-point fields. `core.sha256` of those bytes supplies separate source and
compiled-dataset digests. The consumer verifies both digests, full-seed hash,
schema and algorithm versions, all record counts, critical manifest settings,
and every local node/material/resource registration resolved by its adapter.
That last check compares all explicit biome dungeon triples, six final stratum
hosts, natural resource outputs/groups/ground-content behavior, and their
pairwise disjointness; it does not classify generated nodes by name.

Any failure is fatal before `register_on_generated` or public runtime consumers
are enabled. There is no partial registry, missing-zone substitution,
synthesized anchor, stale checksum acceptance, per-query polygon-scan fallback,
or warn-and-continue mode. Diagnostics identify the validation stage, schema,
seed hash, record/feature ID, invariant, expected value, and observed value
without logging the full world seed unnecessarily.

Startup validates the current production seed only. The complete fixed
32-seed, chunk-order, capacity, supply, and performance suites are build and
release gates; they do not run at every server start.

## 6. Benchmark corpus and acceptance thresholds

### 6.1 Fixed stratified 32-seed corpus

**Decision (2026-08-12): use a fixed stratified corpus containing numeric
boundaries, same-low-32 pairs, deterministic broad samples, four measured noise
extremes, and the selected production seed.**

The first 20 entries are these exact unsigned decimal strings, in order:

```text
0
1
2
42
1013
20260812
2147483647
2147483648
2147483649
4294967295
4294967296
4294967297
6442450943
6442450944
8589934591
9007199254740991
9007199254740992
9007199254740993
18446744073709551615
1181064378178512398
```

They cover 0/1, values around `2^31`, `2^32`, and `2^53`, maximum unsigned
64-bit input, ordinary short seeds, the current visual baseline, and at least
five same-low-32/different-upper-bit pairs. Every consumer treats these as
decimal strings and never converts a full value through a Lua number.

Entries 21--27 are the unsigned big-endian values of the first eight SHA-256
bytes of `grudgelands-wp40-seed-01` through `-07`:

```text
9219515541647461526
7258015152932567000
9703954825944019383
7072879937603433753
6987984790047262299
8118839283201131377
14570731025329063210
```

T1 records each label, complete raw SHA-256 digest, first-eight-byte hex value,
and decimal value as a known-answer golden vector. An independent offline
SHA-256 implementation verifies the checked literals, while main and mapgen
Lua verify the same raw digest through `core.sha256`; any mismatch rejects the
corpus before an authored random field is tested.

Entries 28--31 are selected reproducibly from candidates 0--4095. Candidate
`n` is the unsigned big-endian value of the first eight SHA-256 bytes of
`grudgelands-wp40-extreme-` followed by exactly four zero-padded decimal digits.
Duplicates of an earlier corpus value are skipped. For each candidate, the
geometry oracle evaluates every canonical integer sample on every variable
outer coast and every variable non-coast shared boundary. It computes:

- mean signed coast displacement divided by that sample's allowed amplitude;
  and
- mean signed non-coast displacement divided by that sample's allowed
  amplitude.

The four slots take, in order, greatest coast score, least coast score,
greatest non-coast score, and least non-coast score. A candidate already chosen
for an earlier extreme slot is skipped; equal scores choose the numerically
lower unsigned decimal seed. This selection rule is part of the pre-code
corpus, while its four resulting numbers are measured compiler outputs checked
into the final corpus file before rollout.

T2 owns and freezes those four measured outputs. Its authoritative geometry
corpus therefore contains entries 1--31: the 27 T1 values plus the four T2
extremes. T2 also performs one explicitly staging-only 32-entry run so that no
32-seed geometry/topology/route/anchor gate waits for production-seed selection.
The staging entry is the next unique broad-sample label beginning at
`grudgelands-wp40-seed-08`, converted by the same unsigned first-eight-SHA-256-
bytes rule as entries 21--27 after skipping every value already present in
entries 1--31. Its label, digest, decimal value, staging status, and the complete
32-run result are checked fixtures, but the staging entry is not the final
corpus slot and has no production-seed authority.

Entry 32 is the production seed selected only after it passes the complete
geometry, capacity, supply, headless, performance, and disposable visual-world
audits. If it already occupies another slot, entry 32 instead uses the next
unique broad-sample label beginning at `grudgelands-wp40-seed-08`; the
production seed remains represented at its existing position. T9 owns this
selection. It replaces T2's staging-only entry, then reruns the unchanged
complete geometry, topology, route, and anchor oracle over all 32 final entries.
No T2 coordinate, extreme selection, seed case, or oracle is dropped or
reselected during that replacement.

Before the world-format freeze, the exact 32 newline-terminated decimal strings
and their SHA-256 are checked into the repository and copied into the release
manifest. The selection output may not change silently after that point. A
separate optional fuzz suite may test additional seeds but never substitutes
for a corpus entry or weakens a fixed-seed failure.

Every seed executes the complete `world_zones.md` Section 14 contract, not a
representative subset. The oracle covers exactly 38 IDs and the closed land/
boat graphs; polygon/displacement/core/corridor integrity; three outer prongs,
two open bays per mainland, capital belt and closed frontier; independent
non-reflected continents; Holy coordinates/crossings; island envelopes,
separation, dual approaches, landing access and route parity; all anchor,
fallback, no-jitter and dry-start envelopes; exact one-neighbor start/home
topology; relief bands/landmarks; route graph/classes/interfaces; planned-water,
closed coast, shelf/deep/channel classes; logical-biome shares; housing masks;
and full-seed sensitivity. A failure rejects that seed or source dataset rather
than becoming a visual-inspection exception.

### 6.2 Chunk-order and canonical hash gate

**Decision (2026-08-12): require identical canonical mapblock output across
nine fixed request schedules in the supported one-thread configuration.**

Every schedule begins from an empty disposable world with one v7 emerge thread
and identical manifest-pinned game, engine, seed, `chunksize = 5`, mapgen
flags/noise, `water_level = 1`, `mgv7_dungeon_ymin = -31000`,
`mgv7_dungeon_ymax = -193`, `broad_content_y_min = -37`, registration digests,
and liquid settings. The requested mapchunk set is the same; only request order
changes:

1. canonical z-major rows, then x, then y;
2. the complete reverse of schedule 1;
3. a deterministic permutation ordered by SHA-256 of schema, seed string, and
   signed mapchunk x/y/z;
4. every anchor, fixed interface, crossing, and feature-root mapchunk first,
   followed by the canonical remainder;
5. the same distinguished mapchunks last;
6. each x/z column of requested mapchunks from lowest y slice to highest;
7. the same columns from highest y slice to lowest;
8. alternating sides of every shared boundary, coast, resolver interface, and
   chunk-crossing feature before filling the remainder; and
9. sparse distant teleport targets first, followed by deterministic filling of
   every gap between them.

The pure geometry/compiler/renderer suite exercises the complete authored-world
extent for all 32 seeds. The more expensive headless Luanti schedules exercise
a frozen feature corpus containing homogeneous inland and deep no-op chunks,
every boundary/junction type, coasts/shelf/deep ocean, Holy boundaries, all
anchor/envelope classes, all route classes and bridge/ford/tunnel interfaces,
planned hydrology and waterfalls, both islands/channels/approaches, dense
surface decoration, authored veins, native dungeon/cave/liquid intersections,
and vertical slices across the surface shell and every relevant depth boundary.
The native-dungeon cases include positive callbacks whose room centers lie in
the central slice, positive callbacks whose rooms/corridors reach the emerged
border, the `k = -3/-2/-1` vertical-separation boundaries, later horizontal and
vertical neighbor influence collars, planned masks near but outside the finite
conservative guard, and deliberate finite-guard intersections that must reject
the seed/geometry before production.

Database bytes, compression order, timestamps, and block serialization layout
are not compared. After the frozen liquid-settling procedure, each generated
mapblock is decoded and serialized canonically by signed position and ascending
local voxel index. It receives separate SHA-256 hashes for:

- content IDs mapped back to canonical registered node names;
- `param2` bytes;
- low-nibble day light;
- high-nibble night light;
- the combined canonical node tuple;
- authored source plus settled source/flowing liquid state; and
- sorted compact custom-gennotify records attributable to that mapblock.

The harness also hashes the immutable geometry records and the complete sorted
pre-commit target-operation plan separately. Thus a final-node difference can
be localized to authored geometry, native observation/conflict handling,
transaction rendering, liquid settlement, or lighting.

All one-thread schedule hashes must match bit-for-bit. On failure, the harness
reports the first canonical differing mapblock, first differing local voxel or
event, both node names/`param1`/`param2` values, authored operation/category,
native observation category, feature/resolver ID, and request schedules. A
single mismatch fails the seed; aggregate equality cannot hide compensating
differences.

Each one-thread schedule also has a WP40-disabled native-v7 control world with
the same frozen seed, settings, and request order. For the production seed,
these controls additionally generate the complete finite Section 1.1
native-only audit extent rather than only the frozen feature corpus. This
localizes order effects caused by v7's own overgenerated cave border writes,
but does not waive them:
if either the native controls or the WP40 worlds differ across schedules, the
rollout manifest fails. A native-only mismatch must be corrected by changing
and re-auditing the frozen engine/settings contract; WP40 must not mask it,
persist a first result, or weaken the bit-for-bit gate.

For every native-only schedule, the harness records each positive dungeon
callback's complete emerged VM area, unions those areas, projects the result
onto canonical owner slices, and hashes both the event/area evidence and final
guard. All nine schedules must produce the same canonical guard for an
accepted seed within the frozen requested extent. Every audited pre-commit
target operation is intersected with that guard offline; one overlap is a
seed/geometry failure even when the source declares
`force_native_dungeon = true`. This finite oracle does not claim unexplored
exterior coverage. The production run never reconstructs or consults it from
runtime halo observations.

An independent mathematical/source harness enumerates all chunksize-five y
lattice boundary cases. It proves the Section 1.1 formulas from pinned engine
source, verifies that the highest eligible dungeon central/full ranges are
`[-272,-193]`/`[-288,-177]`, verifies the first broad central/full ranges are
`[-112,-33]`/`[-128,-17]`, and checks both vertical-neighbor directions plus
the horizontal same-y collar. Runtime schedules include deep typed resources
before and after every native neighbor case: a dungeon result must win in both
orders, while non-dungeon generic ore, air, liquid, unknown, and foreign nodes
remain unchanged because none is an exact final-stratum host.

Explicit two- and four-emerge-thread runs are diagnostic only because pinned
v7 does not promise arbitrary parallel slice independence. Their authored
geometry and pre-commit operation-plan hashes must still match the one-thread
authority exactly. Final native/final-mapblock differences are recorded and
localized separately; they do not broaden the supported production profile or
waive an authored-layer race.

Each schedule also keeps a native-v7 pre-overlay snapshot. The preservation
oracle asserts byte identity below every ordinary/named content floor and
outside every exact owned envelope; correct final stratum for new rock; cave
connectivity and generic ore/stratum counts below/outside; byte-identical native
dungeons everywhere, zero audited target-operation intersections with the
finite conservative dungeon guard, and the global vertical/typed invariant;
no floating/buried/colliding native surface decoration; closed liquid/light
boundaries; and the one content/optional-param2/liquid/light transaction
contract. This is evaluated as final nodes and light, not inferred from write
counters alone.

### 6.3 Exact housing mask and packing portfolio

**Decision (2026-08-12): enumerate the exact radius-50 center mask and report a
deterministic portfolio of constructive, adversarial, and bounded packing
results without inventing a capacity quota.**

For every seed and each of the ten eligible housing-zone IDs, the audit tests
every integer x/z center. A center is statically eligible only if all 10,201
integer columns in its inclusive `x - 50 .. x + 50`,
`z - 50 .. z + 50` reservation pass the positive housing mask and every
boundary, route, POI/candidate, hard-protection, planned-water, shelf/deep,
coast, sight-line, arrival, and other static exclusion. Center/corner sampling
or gross polygon area is never accepted as an equivalent test.

Two maximum reservations conflict exactly when both absolute center-coordinate
differences are at most 110. A legal packing therefore has at least one axis
with center separation of 111 or more, leaving the decided ten full free nodes
between two inclusive 101-node footprints.

The following deterministic portfolio runs on each exact center mask:

- every one of the 111-by-111 possible origin offsets of a regular 111-node
  square center lattice;
- a best-first and a worst-first greedy run over the conflict graph induced by
  the centers still under consideration;
- 16 full-seed SHA-256 priority sequences domain-separated by
  `housing-pack-00` through `housing-pack-15`;
- separate distance-ranked edge-, route-, and POI-biased sequences, each in
  near-first and far-first order with canonical ties; and
- canonical z/x row-major and reverse orders.

For either greedy run, `U` initially contains every eligible center and an
edge joins exactly the conflicting pairs defined above. Best-first chooses a
vertex of minimum degree in the current induced graph `G[U]`; worst-first
chooses one of maximum degree. Equal degrees choose canonical z/x order. The
chosen center is accepted, then it and all its current neighbors are removed
from `U`, degrees are recomputed, and the process repeats until `U` is empty.
Thus "current conflicts" does not mean conflicts with already accepted
reservations, which would be zero for every still-legal candidate.

The implementation uses a spatial conflict index, but its result is checked
against a slow pairwise oracle on bounded fixtures. No sequence mutates the
static mask or changes a later candidate's geography; it only removes centers
that conflict with a reservation accepted in that simulation.

For an auditable upper bound, every 111-by-111 grid offset also partitions all
eligible centers into half-open 111-node cells. At most one center from any
such cell can occur in a legal packing, so the minimum non-empty-cell count
over all offsets is a valid upper bound. The audit reports that bound, the
largest constructively achieved packing from the portfolio, the smallest
adversarial result, the distribution across hash orders, connected-component
and bottleneck fragmentation, and rejection reasons per zone, race region,
faction, and seed.

For each of the four guaranteed coastal cores, the audit additionally proves
at least 600 continuous shoreline nodes and 300 usable inland nodes after all
static exclusions. It slides every completely contained 101-by-101 footprint
and proves no more than 12 nodes of final natural-ground relief, no forced
cliff/ravine/river/lake, and no shelf intersection. These geometry guarantees
do not substitute for the packing portfolio.

WP40 has no fixed claim-count quota. In particular, the retired 150-claims-per-
faction suggestion and gross-area division are not acceptance targets. The
measured report is a required WP40 output used to set later live-Stone defaults
below physical capacity. The fixed mainland frame, coast, routes, POIs, or
exclusions may not be altered merely to improve a reported count. After the
world-format freeze, any capacity change requires an explicit geometry/version
change and complete corpus rerun.

WP24 later owns dynamic reservations, simultaneous placement, active claims,
ACLs, expansion, abandonment/recovery, persistence, and AreaStore rebuilds.
Those tests consume this exact immutable mask but are not WP40 mapgen work.

### 6.4 Realized supply and access ledger

**Decision (2026-08-12): audit realized final resources and practical access
for every seed; never accept theoretical placement probability as supply.**

The canonical ledger counts final generated resource nodes after native v7,
terrain rewrites, clipping, authored-vein precedence, and all protection/water
rules. For each seed, resource, race region, zone, and depth band it records:

- eligible final host volume before resource replacement;
- practically accessible host volume after immutable/protected, liquid,
  dungeon, cave, route/tool, and final-terrain constraints;
- admitted authored candidates, theoretical mask voxels, final placed nodes,
  generic ore preserved/clipped, and every other clipping reason;
- native final nodes for universal resources, including changed-volume sterile
  host; and
- graph/tool route, travel class, earliest legal pick tier, and whether the
  source is native, contested, cross-border deep, semantic camp/apex, or trade.

G2 calibration reports realized accessible rates against approximately one
node per 12,000 eligible hosts in T4, one per 6,000 in T5, and one per 3,000 in
ordinary T6. G1 uses `DENSITY.g1`; cultural sources use their separately
audited opportunity masks. For each gem species, the corpus-level rate sums
final nodes and accessible host volume across all 32 seeds before division;
the six race-region normalized natural supplies plus
their identical one-unit semantic ordinary-camp budgets must meet the decided
plus/minus 5 percent equality. Individual-seed rates, minima, maxima, and
outliers are still published, and no accepted seed may lose every practical
source or a mandatory route merely because the aggregate passes.

Abyssal Crystal is measured from the final native result independently of G1/
G2. For every seed, the accessible `y = -701 .. -1000` T5 entry band must meet
WP43's final material demand for obtaining an Abyssal Steel pick without first
entering T6. Its initial approximately 1/2,048 eligible-host calibration is
reported rather than substituted for that practical demand test.

The route oracle proves, for every faction-exclusive G2 species and every
seed, the native-region route, enemy-contested route, cross-border editable
depth route from `y = -701`, and a practical T4 route before level-60 island
access. Both island camp envelopes and all 24 semantic apex slots are reachable
through their fixed approach geometry, and each island reserves exactly two
slots for each of the six species. Trade is recorded as an alternative and
never accepted as the only route.

WP40's camp result is staged geometry: each race region has one equivalent
semantic ordinary-camp supply reservation, while each island has the exact
semantic apex layout. WP13 later realizes camp/socket structures and WP34 owns
refill and the target `+25%`/`+50%` deep multipliers. Until those WPs land, the
ledger must label their budgets `reserved`, not count imaginary generated
nodes, functional anchors, refill yield, or diggability as shipped. The literal
post-WP13/WP34 socket gate remains a downstream integration gate.

For WP33 surface supply, WP40 measures the stable source-mask opportunity and
reachable area for cultural woods/materials, herbs, spices, and paired base
resource families. Each paired faction opportunity within a level bracket must
be within plus/minus 10 percent, with the exact named-zone source assignments
from `world_zones.md`. Unregistered later nodes are semantic opportunities,
not synthetic WP40 placements.

The same ledger validates exact POI/rare/loot source slots and requires every
`zone ID x logical biome ID` spawn cell to have an ambient spawn row or an
explicit `civic/no-hostiles` declaration. Spawn-density comparisons state
whether they use shipped WP36 values; WP37's future surface `chance = 0.75`
with unchanged `aoc` is a separate projection. WP44 later owns money rebasing,
so this audit freezes no copper price or income value.

No failed seed receives a compensating runtime vein, moved POI, raised drop
rate, enlarged mask, or hidden trade-only exception. A calibration/input change
before rollout reruns the full corpus; after manifest freeze it is an explicit
world-format/economy input change.

### 6.5 Performance corpus and merge thresholds

**Decision (2026-08-12): gate WP40 against the post-WP43 WP18/WP36 baseline
with relative generation budgets, absolute hot-path and memory guardrails, and
an evidence-controlled reality-check correction process.**

The baseline is the merged post-WP43 `main` immediately before WP40 changes
mapgen behavior. It therefore contains WP43's final material contract but the
actually shipped WP18/WP36 mapgen. Candidate and baseline runs use the same
recorded target host, engine build, Lua runtime, mapgen settings, exact request
trace, cache class, and disposable-world state. A comparison against a
different checkout, host, or cache class is diagnostic only.

The designated target host is the current project machine: AMD Ryzen 7 9800X3D
(8 physical/16 logical CPUs online), 58 GiB OS-visible RAM, and the
WD_BLACK SN850X 2 TB NVMe containing the encrypted ext4 project filesystem.
It runs Fedora Linux 44 with the CPU governor fixed to `performance`; the exact
kernel, firmware, free-memory/swap state, filesystem mount, temperatures, and
background-load check are captured for every run. Baseline and candidate use
the same logical-CPU affinity. Replacing this physical host requires an
explicit reviewed rebaseline; merely recording an arbitrary later machine
does not satisfy the gate.

The fixed micro-corpus contains signed mapchunk coordinates for each of these
classes:

1. deep no-op;
2. ordinary inland surface;
3. ordinary shared-zone boundary;
4. coast, shelf, and deep-ocean transition;
5. Holy boundary at both the surface and shallow-floor transition;
6. capital and start blend envelopes;
7. primary/secondary/trail road, hydrology, bridge/ford, and tunnel slices;
8. a large mandatory-structure-envelope slice;
9. dragon island, landing approach, and immutable channel;
10. the densest authored surface-decoration slice; and
11. the densest exact-region resource slice.

T2 freezes the versioned micro-corpus schema, the deterministic selection rule,
and exact geometry-only coordinates plus stable feature IDs for classes 1--9.
It also freezes the complete 100-requester JSON trace below. T6 appends class 10
deterministically only after the authored surface catalog is frozen, and T7
appends class 11 deterministically only after the exact-region resource catalog
is frozen. Those append-only steps use the T2 selector and compiled geometry;
they may not move, replace, or conveniently reselect any T2 class-1--9
coordinate after timings are known.

T9 selects the production seed under Section 6.1, materializes the combined
11-class fixture for that seed and the other required timing seeds, and runs the
complete benchmark. The generation micro-corpus therefore runs for the visual-
baseline seed, unsigned-64 maximum, the four measured extreme seeds, and the
selected production seed only after all owning catalogs exist. Registry
initialization is measured for all 32 final fixed seeds. The complete 32-seed
geometry, route, housing, and supply audits remain acceptance runs and publish
their own wall time and peak memory, but their capacity and supply results are
not replaced by this smaller timing corpus.

Every result records at least CPU model and effective core configuration, RAM,
storage/filesystem, OS and kernel, power/governor state where available,
engine build/commit/compiler, game and baseline commits, LuaJIT or bundled Lua
5.1, `chunksize = 5`, v7 flags and noise settings,
`mgv7_dungeon_ymin = -31000`, `mgv7_dungeon_ymax = -193`, `water_level = 1`,
`broad_content_y_min = -37`, registration digests, lighting/liquid settings,
one production emerge thread, full seed string and manifest digest.
The same relative gates are evaluated against the corresponding baseline for
both Lua runtimes; two- and four-state runs are explicitly labelled memory and
determinism diagnostics, never production-throughput evidence.

Cold runs use a new process and empty disposable world. Filesystem page-cache
state is either controlled by the harness or explicitly labelled `unknown`;
unknown-cache data may not be presented as cold-cache proof. Warm runs retain
the initialized process and registry but generate previously unseen chunks.
For every case/runtime/cache class, two unrecorded warm-up rounds precede 40
recorded paired baseline/candidate rounds. Initialization additionally uses ten
independent cold processes. Paired run order alternates to expose thermal or
background drift. For `n` sorted observations, every reported percentile uses
the nearest-rank definition `sample[ceil(p * n)]` with one-based indexing and
no interpolation; p50 and p95 of 40 samples are therefore observations 20 and
38. Paired ratios divide candidate by the baseline observation from the same
alternating pair before their median is taken.

No statistical outlier is silently removed. Raw samples, p50, p95, maximum,
median paired ratio, and every failed sample remain in the report. A run may be
invalidated only for a recorded external harness/host failure and must be
repeated in full. A maximum is merge-blocking when it reproduces in at least
two of three isolated confirmation runs; the original observation remains in
the raw output.

On the designated target host, for each Lua runtime and cache class:

- steady generated-mapchunk wall-time p50 is at most `1.50x` and p95 at most
  `2.00x` the paired WP18/WP36 baseline;
- the worst reproducible corpus case is at most `3.00x` its paired baseline;
- aggregate sustained generated-mapchunk throughput is at least `60%` of the
  paired baseline;
- the deep no-op path has at most `1 ms` p95 WP40 Lua callback time and makes
  no VoxelManip data transfer, content write, lighting call, or liquid call;
- sparse main-environment generation work adds at most `2 ms` to main-step
  p95, `5 ms` to p99, and `20 ms` to the reproducible maximum relative to the
  paired trace; broad voxel work in the main environment is an unconditional
  failure;
- one-state main compilation takes at most `5 s`, while IPC unpack, checksum,
  validation, index/adaptor initialization, and readiness take at most `1 s`
  per mapgen state;
- the canonical packed IPC payload is at most `16 MiB`, retained compiled Lua
  data at most `64 MiB` per mapgen state, and one-state candidate peak RSS at
  most `256 MiB` above the paired baseline; and
- repeated complete warm-corpus cycles show no monotonic retained-heap or RSS
  growth after explicit supported GC/settling points. A positive trend outside
  recorded measurement noise is a leak failure, not an allowable peak.

Every changed chunk performs at most one `VoxelManip:set_data` content upload
and at most one `VoxelManip:set_param2_data` upload in that same sole VM
transaction. Light-dirty chunks perform the canonical bounded number of
mapgen-only `VoxelManip:set_lighting` preparation calls, exactly one WP40
`VoxelManip:calc_lighting` call, and exactly one final full-buffer
`VoxelManip:set_light_data` upload; non-light-dirty chunks perform all three
lighting categories zero times. `VoxelManip:update_liquids` is called at most
once and only for a nonempty liquid-topology dirty set. Completely unchanged
chunks perform every content, `param2`, lighting, and liquid call zero times.
Engine liquid transforms and any light-node updates they trigger later
in `finishBlockMake` are measured and reported separately; they neither count
as extra WP40 API calls nor disappear from settled latency/light evidence.
Modified-voxel count has no invented gross cap: it must equal the
analytic expected dirty set, with every modification inside its typed
envelope/replaceable set and every excess or missing write a correctness
failure. The report records full-buffer gets/sets by content and `param2`,
classified columns, scanned and modified voxels, candidates considered/
accepted, positive native-dungeon callbacks, emerged guard volume, owner-slice
finite-guard volume and rejected intersections, deepest broad-operation y,
typed-deep eligible-host replacements and provenance-neutral `non_host` skips,
optional `registered_dungeon_name_collision_non_provenance` diagnostics,
liquid-changing voxels, lighting volume plus preparation/calculate/final-upload
calls, Lua allocation/GC, process RSS, callback and total chunk time, chunks per
second, main-step latency, and emerge-queue depth. No production counter may
label an encountered node as a dungeon or dungeon clipping.

The deterministic 100-requester exploration trace is a separate synthetic
mapgen/system gate, not a substitute for the micro-corpus and not a claim to
simulate client networking or every gameplay callback of 100 real players.
The server pins `dedicated_server_step = 0.09`, `chunksize = 5`, one emerge
thread, `max_block_generate_distance = 5`, `max_block_send_distance = 5`, and
`active_block_range = 4`; every other setting is in the common manifest.

The checked trace compiler creates exactly 100 indexed requester records from
the final T2 route/anchor manifest:

- requesters 0--14 traverse sorted road profiles back and forth at 4 nodes/s;
- 15--29 do so at 6 nodes/s and 30--44 at 8 nodes/s;
- 45--59 traverse the same sorted legal-land profiles at analytic
  `surface + 48` and 7 nodes/s, and 60--74 at 10 nodes/s; and
- 75--99 jump every ten seconds through the canonical sorted stable-anchor
  list, starting at list offset equal to their requester index.

Profiles are assigned round-robin by requester index; multiple requesters on
one profile start at equal rational arc-length phases in index order. Ground
height follows the compiled profile, flight is rejected if any sampled column
is not flight-legal, and a rejected fixture fails rather than silently choosing
a new path. Positions are advanced in Q16.16 at each rational `9/100`-second
tick and floored to integer node coordinates for requests. On the first tick
and whenever a requester enters a new 16-node mapblock, the harness queues the
inclusive axis-aligned integer box at plus/minus 80 nodes on all three axes
around that floored position. Independently, each active tick calls the same
four shipped compatibility consumers for every requester:
`grug_core.zone_at`, `grug_core.surface_level_at`,
`grug_core.mob_level_at`, and `grug_core.open_sea_at`. The baseline executes
their WP18/WP36 implementations and the candidate executes their WP40-backed
adapters, giving the main environment an exact 400-query load per step without
calling a function absent from the baseline.

Each fresh-world run has a simultaneous cold burst at tick zero, 300 seconds
of movement/jumps, then exactly 180 seconds with no new emerge request or
geometry query. It records every server step, request, completion, queue depth,
generated mapchunk, process sample, and recovery tick. The gate uses nearest-
rank p99 over all 300-second active-phase steps, the already frozen main-step
deltas, an absolute active-phase main-step p99 no greater than the configured
90 ms server-step interval, no positive queue-depth slope over the final 60
active seconds, and a zero emerge queue by the end of the 180-second recovery.
Baseline and candidate each run three complete alternating repetitions per Lua
runtime; all raw runs remain visible and any failure is merge-blocking.

T2 writes the resulting per-tick positions and request boxes as canonical
JSON, plus its SHA-256 and source-manifest digest, before the baseline trace is
run. Baseline and candidate consume that identical file; they do not recompute
positions from their own geography. This checked fixture, the durations and
the zero-extra-load rule replace manual play observations and leave no later
choice of convenient positions or recovery window.

An immediately preceding reviewed WP40 checkpoint is a second regression
baseline. After the prescribed repeats, no gated p95, throughput, or RSS
metric may regress by more than `10%` while still hiding inside the looser
WP18/WP36 envelope unless the change and its evidence are explicitly accepted.

The implementation supplies one documented command that builds disposable
worlds and reproduces the complete benchmark, plus separately selectable cold,
warm, micro-corpus, 32-seed audit, and 100-requester runs. Machine-readable raw
samples, harness logs, environment/settings manifest, exact commands, corpus
coordinates, summary tables, failures, and SHA-256 checksums are retained under
a manifest-digest result directory. Generated worlds and caches are disposable
and are not accepted as the only evidence. No number in this section claims a
successful measurement; initialization, capacity, supply, and performance
results are mandatory WP40 implementation outputs before integration.

#### Reality-check correction rule

These algorithms and thresholds are pre-code engineering guardrails, not
permission to ignore contrary engine behavior or measurements. When a focused
prototype, independent code review, or target-host evidence exposes a wrong
assumption, the team first reproduces the deviation and determines whether the
brief, implementation, harness, baseline, target host, or threshold is at
fault. An engine-contract or correctness mismatch blocks the affected work and
is corrected in this brief with cited evidence before code proceeds. A WP40
defect or avoidable cost is corrected before any threshold is reconsidered.

The 2026-08-13 native-dungeon prototype triggered this rule. The pinned
5.17-dev engine exposes room-center notifications but neither its private
dungeon working flags nor node-exact writer provenance to Lua; the isolated
5.16.1 target-host run confirmed the same public surface. Before this Reality
Check, v7's default and the current pre-WP40 baseline admitted dungeons through
`mgv7_dungeon_ymax = 31000`
([baseline map metadata](../../tools/wp40/evidence/t0-post-wp43-wp18-wp36/70adabd28401e820ec86e8786bf0da368225c8624e42ed02dd3bce175fd3cafc/raw/run-001.map_meta.txt):175,206);
the corrected fresh-world manifest changes that
critical value to `-193`, retaining `mgv7_dungeon_ymin = -31000`. The root cause
is the impossibility of proving node-exact positive provenance in Lua while the
broad WP40 rewrite must remain exact and order-independent.

The review rejected all narrower-looking alternatives: room centers,
content-name inference, and a deterministic parallel rerun do not prove writer
provenance; a finite full-emerged-area audit cannot prove arbitrary unexplored
exterior or future neighbor influence; a map-limit preflight or hard world
border contradicts the unbounded analytic exterior contract; a runtime halo
veto is request-order dependent; disabling the broad terrain/water/route rewrite
would abandon WP40's authored-world requirements; and a Luanti engine patch or
project-owned dungeon replacement is outside WP40. The finite native-only guard
remains a conservative corpus proof oracle, but global safety comes from the
new vertical separation plus exact-final-stratum-host-only deep writes.

The explicit player/server and world-format consequence is fewer native
dungeons: the highest eligible central slice is `[-272,-193]` (its full VM can
reach `-177`), and v7 makes no dungeon attempt in `k = -2` or any shallower
slice. The team accepts the loss of shallow native dungeons as the stronger
preservation/architecture tradeoff. No corpus seed, request schedule,
performance threshold, or preservation gate is weakened. Existing generated
worlds are not rewritten, and any world created with the old setting is
incompatible with the corrected WP40 manifest. If the complete corpus becomes
unsatisfiable, a new reviewed Reality Check is required; only a verified
node-exact provenance API/origin channel can reopen replacement authority or
justify revisiting the vertical cutoff.

The same 2026-08-13 review found two narrower documentation ambiguities. First,
the earlier supply/performance wording asked production to report deep skips by
an encountered `dungeon` category even though the engine evidence above proves
that only content IDs, not writer provenance, are visible there. The corrected
runtime categories are `eligible_host_replacement` and provenance-neutral
`non_host`; a manifest-registered dungeon-node-name match may be emitted only
as `registered_dungeon_name_collision_non_provenance`. Positive dungeon events,
full-emerged-area guards, and plan intersections remain isolated native-only
finite proof evidence, so neither replacement behavior nor its zero-
intersection gate changes. Second, “one final light-buffer commit” did not state
the API call boundary precisely. The pinned engine supports zero or more
bounded mapgen-only `set_lighting` range preparations on one VM
([`l_vmanip.cpp`](../../reference_projects/luanti/src/script/lua_api/l_vmanip.cpp):231-256;
[`l_mapgen.cpp`](../../reference_projects/luanti/src/script/lua_api/l_mapgen.cpp):2019-2028),
then one `calc_lighting`, followed by one restored full-buffer
`set_light_data` write
([`l_vmanip.cpp`](../../reference_projects/luanti/src/script/lua_api/l_vmanip.cpp):259-305).
This clarifies the existing bounded-light algorithm; it adds no second light or
VoxelManip transaction and changes no numerical threshold, seed, case,
preservation rule, or acceptance gate.

The 2026-08-13 corpus-staging review also triggered this rule. Reproduction is
direct: the checked T1 fixture has 27 fixed entries and deliberately assigns
slots 28--31 to T2 but slot 32 to T9
([seed-corpus fixture](../../mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua):1-42),
while the pre-correction T2 task row required all 32 final seeds and the
pre-correction Section 6.5 assigned T2 a micro-corpus that already included the
surface- and resource-density cases whose authoritative catalogs belong to T6
and T7. T2 could therefore satisfy the old wording only by inventing a future
production seed and future content-authority outputs. The root cause was task
staging, not the geometry, seed-selection, corpus, or performance design.

The correction keeps every case and gate: T2 freezes final entries 1--31,
classes 1--9, and the complete requester trace, and runs the full 32-entry pure-
geometry corpus with one explicit non-production staging entry. T6 and T7 append
classes 10 and 11 only after their catalogs freeze. T9 replaces only the staging
entry with final slot 32, reruns the unchanged complete 32-seed geometry,
topology, route, and anchor corpus, materializes all 11 micro-corpus classes,
and executes the full benchmark. No T2 coordinate is reselected and no seed,
case, numerical threshold, or final Chapter 6 gate is removed or weakened.

A numerical guardrail may change before final integration only when paired raw
measurements show that the original value was technically miscalibrated or
conflicts with a stronger correctness/operability requirement. The reviewed
change records the old and new value, root cause, implementation alternatives
tried, player/server consequence, and explicit acceptance. It may not remove a
seed or case, relabel a warm result as cold, hide a tail, create a feature-
specific exemption, or use the candidate alone as its new baseline. Every such
correction reruns the full affected corpus and all aggregate gates. After the
rollout manifest is frozen, benchmark-contract changes use the normal reviewed
compatibility process rather than silently weakening the release record.

## 7. Implementation decomposition

The later WP40 orchestrator may subdivide tests, but it must preserve these
ownership boundaries and dependency gates. No task may introduce a second
geometry evaluator, placement path, or VoxelManip transaction for convenience.

| Task | Owned result | Requires | Completion gate |
| --- | --- | --- | --- |
| T0 — WP43 handoff and baseline | exact material/resource API adapter, designated-host/harness manifest, post-WP43 WP18/WP36 fixed-corpus baseline and raw capture | merged WP43 `main` | every symbol/registration resolved; benchmark host/harness reproducible; no WP25 identity in target data |
| T1 — deterministic foundation | full-seed hash lanes, fixed-point/tie rules, canonical encoder, schemas, manifest including the Section 1.1 vertical constants/registrations, three-stage validation, IPC transport, 128-node index | T0 | identical main/mapgen/offline fixtures; fail-fast corruption and mapgen-setting/registration-drift tests |
| T2 — compiled world geometry | 38-zone source, shared edges, `H`, templates, fixed/candidate anchors, route profiles, hydrology, coast/shelf/channel/island geometry, measured corpus slots 28--31, staging-only slot-32 run, exact geometry-only micro-corpus classes 1--9, complete 100-requester JSON trace | T1 | final entries 1--31 plus the explicit staging entry pass the complete pure geometry/topology/route/anchor oracles; extreme selection, staging identity/status, class-1--9 fixtures, requester trace JSON, and digests frozen |
| T3 — public geography and policy | immutable `grug_zones` APIs, water/mount classifier, territory/PvP fields, hard-protection and claim-exclusion masks, compatibility consumers | T1, T2 | scalar hot paths agree with slow oracle; no 38-definition scan or dynamic-claim coupling |
| T4 — pure content planner | closed typed resolver matrix and one final per-voxel operation plan, independent of VoxelManip mutation; enumerate every non-resource operation at/above `broad_content_y_min`; exact-host-only deep resource type with provenance-neutral production skips; finite offline intersection oracle for Section 2.4's owner-sliced dungeon guard | T0, T2 | exhaustive resolver/veto/owner-slice fixtures, derived-bound/lattice proof, zero dungeon-guard intersections, rejected `force_native_dungeon = true`, `eligible_host_replacement`/`non_host` deep outcomes with no production dungeon label, and exact dirty sets |
| T5 — consolidated terrain adapter | central-slice native observation, surface rewrite, strata, planned/exterior water, roads/tunnels, one content plus optional `param2` upload in the sole VM transaction, bounded liquids/lighting with canonical `set_lighting` preparation, one `calc_lighting`, and one final restored `set_light_data`; validate vertical/registration manifest; no runtime dungeon/guard/halo inference | T3, T4 | unconditional dungeon preservation across `k=-3/-2/-1` and later-neighbor orders, fail-closed force/settings drift, provenance-neutral deep typed order, seam, no-op and exact API operation-count gates |
| T6 — authored surface catalog | logical biome top/filler, deterministic decoration candidates/slices, native-surface cutover and water normalization/falls settlement, deterministic micro-corpus class 10 | T4, T5 | palette/share, collision, tree-boundary, water-family and settled-hash gates; class-10 fixture appended through the frozen T2 selector without moving a T2 coordinate |
| T7 — resource placement | universal-native adapter, exact-final-stratum-host-only authored G1/G2 veins, cultural opportunity masks, semantic ordinary/apex supply records, deterministic micro-corpus class 11 | T0, T4, T5 | host/clipping/final-node counts, deep order fixtures, all Section 6.4 access routes across 32 seeds, and class-11 fixture appended through the frozen T2 selector without moving an earlier coordinate |
| T8 — consumer migration and legacy retirement | start/respawn, POI slots, protection, level/mob/spawn/gathering/rare-route/map/mount consumers moved to stable queries; old ring/height/storage/ocean passes and any live dungeon-force authority removed | T3, T5, T6, T7 | compatibility suite and complete repository search show no live legacy authority, no content-name dungeon classifier, no accepted true dungeon-force flag, and no callback/settings path bypassing the vertical/typed contract |
| T9 — release evidence and rollout | final slot-32 replacement and 32-seed corpus, canonical hash/order suite, finite native-only dungeon event/emerged-area/owner-guard artifacts, vertical-lattice/source proof, housing/supply exports, combined 11-class micro-corpus, microbenchmarks, 100-requester trace, disposable visual world, frozen production manifest | T1--T8 | staging entry alone replaced; unchanged complete geometry/topology/route/anchor oracle passes all 32 final entries; reproducible pinned-source/probe evidence, zero finite plan/guard intersections, global vertical/typed invariant, every Chapter 6 gate, full diff review, runtime test plan, and fresh-world rollout checklist pass |

T3's API signatures, adapters, and slow-oracle test scaffolding may proceed in
parallel with T2 after T1; no T3 authoritative answer or completion gate may
run before T2 freezes the compiled geometry.
T6 and T7 may build separate pure catalogs after T4 freezes the resolver
interface, but only T5 owns the VoxelManip adapter and transaction. T8 deletes
legacy authority only after the corresponding target path and consumer tests
are green. T0 owns the measurement harness and initial baseline; T2 freezes the
geometry-derived class-1--9 fixtures, corpus slots 28--31, the staging-only
32-entry run, and the complete requester trace, which are then replayed against
the preserved baseline checkout before terrain cutover. T6 and T7 append their
catalog-dependent classes without reselecting T2 coordinates. T9 replaces only
the staging entry, reruns the complete final 32-seed pure-geometry corpus, and
materializes the combined 11-class benchmark. The native-only dungeon guard
remains finite offline evidence: T4 tests audited plan intersection against it,
while T5 production neither receives it over IPC nor derives it from halo
content. T1/T4/T5 instead enforce the global vertical/typed contract. T9 reruns
and freezes both proofs but owns no early harness work or production terrain
logic.

WP13, WP17, WP24, WP33, WP34, WP37, WP41, WP42, WP44, and later mount/boat work
remain separate work packages. WP40 supplies their stable IDs, masks, terrain
interfaces, and semantic reservations without implementing their structures,
waypoint lifecycle, claims, content, spawn-rate change, transactions, schedules,
economy, vehicles, or refill behavior.
