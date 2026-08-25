# WP40 simple-map R3 vertical contract

**Status (2026-08-25): independently accepted implementation contract. R2 is
accepted; no R3 implementation or artifact is accepted yet.**

This contract turns the accepted `wp40-simple-map-v1d` horizontal layout into
one small, deterministic vertical model. It deliberately does not resurrect
the retired exact-topology compiler, boundary gates, route DP, generic CSG or
template DSL. The binding game rules remain in `docs/design/world_zones.md`,
`docs/design/world.md` and `docs/design/housing.md`; this document makes the R3
implementation and evidence boundary exact.

## 1. Outcome and non-goals

R3 owns four results for one canonical full seed:

1. a globally queryable integer ground/bed field
   `H(full_seed_string, x, z)` exposed internally as `terrain_height_at`;
2. water-surface and exceptional traversable-surface values required to turn
   that scalar into rivers, causeways, bridges, fords and tunnels;
3. final x/y/z anchor records plus their already-authored hard-protection
   volumes; and
4. immutable evidence that the accepted R2 paths, hydrology, anchor choices
   and coastal housing cores can be realized vertically.

R3 does not write map nodes, register engine callbacks, choose biomes or
resources, generate decorations, preserve native content, or expose the final
`grug_zones` API. Those remain R4-R6 work. R3 also does not choose player
claims: R2's housing masks and packing portfolio stay fixed, while R3 proves
the promised natural-relief property of the four guaranteed coastal cores.

There is no absolute per-query or per-mapchunk timing gate in R3. Timings are
reported with host and interpreter evidence. A binding budget may be added
only after measuring the complete mapchunk transaction; the former informal
`5 ms` number is not authority.

## 2. Authority and fixed constants

- The horizontal evaluator and R2-frozen source remain the sole authority for
  water class, macro region, zone owner, selected x/z anchor, route geometry,
  hydrology identity, housing eligibility and hard x/z footprints. R3 never
  reimplements ownership or moves a horizontal feature.
- R3 does not edit any of the 14 `input_sha256` files bound by
  `wp40-simple-map-r2-artifact.tsv`. Its schema, implementation, offline
  adapter, validator and runner are new files. The accepted R2 artifact remains
  immutable with body digest
  `73165e1ad9e9dd03bc608b544e5906a10df2bf7b2c23779b311ad3cbdadf4f7b`
  and complete-file SHA-256
  `02585d6644265e8889edb3311045d76c2dd7152700dff33563bd8daabc13c339`.
  R3 verifies both before doing vertical work. A later need to edit a bound
  input stops R3 and requires a refreshed R2 artifact plus focused independent
  R2 rereview first.
- The project water level is the integer `1`. R4 must fail closed if the
  engine's `water_level` differs; height never reads the setting at query time.
- R3 evaluates the finite bounds already returned by
  `horizontal_session.warp_proof()`, with one lattice-cell halo. Outside those
  bounds it returns the fixed deep-ocean bed and no zone-specific operation.
- All public or artifact coordinates and heights are safe integer Lua numbers.
  Internal interpolation is Q16.16 through `deterministic.lua`; no native
  integer, LuaJIT-only syntax or floating-point random source is allowed.
- Height domains use schema `grug_wp40_simple_map_height_v1`. Changing the
  water level, lattice construction, mixer, precedence, grade rules or output
  meaning is a reviewed world-format change.

## 3. Relief without per-column hashing

### 3.1 Seeded lattice construction

The current six source relief profiles and their ordered octave periods and
amplitude fractions remain the compact vertical inputs. Their elevation bands
remain exactly:

| Profile | Minimum above water | Maximum above water |
|---|---:|---:|
| `wetland_delta` | 2 | 24 |
| `lowland` | 8 | 56 |
| `rolling_hills` | 24 | 96 |
| `plateau` | 56 | 144 |
| `highland` | 96 | 224 |
| `mountain` | 160 | 360 |

Session construction hashes each `(schema, full seed, relief noise domain)`
once. The exact byte input is:

```
"GRUGWP40HEIGHT" .. byte(0)
  .. canonical(text("grug_wp40_simple_map_height_v1"))
  .. canonical(text(full_seed_string))
  .. canonical(text(domain))
```

The unsigned big-endian first digest word modulo `P = 2147483647` is the
31-bit root; zero becomes one. Every octave corner then uses the following
contract-frozen arithmetic mixer, where `mod` is mathematical modulo, octave
ordinals start at one, and x/z are signed lattice indices reduced modulo `P`:

```
B = 32768
mulmod(a,b):
  a = a1*B+a0; b = b1*B+b0
  r = (a1*b1) mod P
  r = (r*B + a1*b0 + a0*b1) mod P
  r = (r*B + a0*b0) mod P

x = ix mod P; z = iz mod P
s = (root + mulmod(x,73856093) + mulmod(z,19349663)
     + octave*83492791) mod P
s = (mulmod((s+104729) mod P,(s+130363) mod P)+12345) mod P
s = (mulmod((s+mulmod((x+37) mod P,(z+53) mod P)) mod P,48271)+1) mod P
s = (mulmod((s+32452843) mod P,(s+49979687) mod P)+86028121) mod P
corner_q = floor(s * 131073 / P) - 65536
```

The base-`2^15` decomposition keeps every intermediate inside the exact-double
integer range. Corner construction does not call SHA-256 and maps
deterministically to the inclusive signed Q16 interval
`[-65536,+65536]`. The exact formula is independently KAT-bound; the
implementation may not substitute a visually similar PRNG.

Each profile octave is precomputed only over the finite query bounds plus its
four-corner halo. A raw profile query performs smootherstep bilinear
interpolation per octave, applies the authored amplitude fraction, clamps the
sum to `[-65536,+65536]`, and maps it inclusively into the profile's elevation
band:

```
water_level + minimum
  + floor((clamped_noise_q + 65536) * (maximum - minimum) / 131072)
```

This salvages the small proven Q16 and inclusive-band mathematics, but not the
old `geometry/relief.lua` session, its per-query SHA cache, old landmark
priority fields or global composition.

### 3.2 Smooth zone transitions

A final base-height lattice has 64-node cells. At every vertex R3 asks the
horizontal evaluator for the owning zone and evaluates that zone's primary
profile there. A vertex without an owner uses `lowland` solely as a coast-side
transition value; exterior classes later replace it with their fixed bed.

`base_height_at(x,z)` is smootherstep bilinear interpolation between the four
integer vertex heights, rounded once to an integer. Consequently an ordinary
zone boundary blends over at most one 64-node cell and cannot create a raw
vertical seam. R3 stores and reports a canonical digest of the relief-corner
lattices and the final base-height lattice. It does not construct polygonal
zone boundaries or a second owner classifier.

### 3.3 Landmark masks

Every current landmark keeps its R2-frozen id, owner, rectangle/ellipse/
capsule mask and secondary relief profile. R3 uses one 64-node outside collar.
The exact mask has full weight; the collar falls to zero with Q16
smootherstep. Rectangle uses Chebyshev excess. Ellipse and capsule use the
small safe-integer signed-distance formulas adapted from the old relief
module, including a far-collar rejection before unsafe squares.

Landmarks are owner-clipped through the horizontal evaluator and composed in
ascending numeric id; the later numeric id wins only through its explicit
mask weight. A contribution replaces the incoming natural height with the
secondary profile height through Q16 interpolation. It never changes zone,
water or route identity.

This is intentionally the whole generic landmark-height language. Names such
as `chasm`, `terrace`, `rootway` or `arch` remain stable content/dressing
intent, not hidden procedural operators. Explicit hydrology transitions and
the functional grades below are the only additional vertical shapes in R3.

## 4. Ground, water and non-scalar surfaces

### 4.1 Meaning of the scalar

`terrain_height_at(x,z)` returns the top authored solid ground or water bed at
that column after scalar terrain grading. It does not pretend that one number
can simultaneously describe a river bed and a bridge deck, or a hilltop and a
tunnel floor. Those exceptional traversable surfaces are returned by the
small `functional_surface_values_at` seam below.

The scalar is total inside the safe coordinate range:

| Horizontal class | Ground/bed rule | Water surface |
|---|---|---|
| ordinary land | natural relief plus applicable scalar grade | none |
| wet named hydrology | `reach water surface - profile depth`, with bank collar | reach surface |
| dry channel (`depth = 0`) | dry datum plus bank collar | none |
| landward bay | `water_level - 8` | water level |
| coastal shelf | depth 1..8, increasing monotonically across its 80-node band | water level |
| deep ocean | `water_level - 24` | water level |
| immutable dragon channel | `water_level - 24` | water level |

For the shelf, the horizontal evaluator's monotone
`expanded_land_at(x,z,radius)` predicate determines the smallest integer
radius `d` in 1..80 by binary search. Depth is
`1 + floor(7 * (d - 1) / 79)`. This is a query over existing horizontal
authority, not a stored coast or boundary.

The four bay-mouth transitions may step from the 8-node bay bed to the
24-node deep-ocean bed at their accepted R2 cut. That continental drop is not
a river waterfall and receives no traversable route.

### 4.2 Named hydrology

For a wet reach, `water_surface_at` is exactly project water level plus the
reach's current `water_surface_offset`. Its interior bed is exactly that value
minus the referenced profile depth. In the profile's outside
`bank_blend_width`, the natural land is blended toward a dry bank at
`water_surface + 1`; the classified wet interior retains its exact bed.

The bank calculation is deliberately integer and exact. For each indexed
candidate segment it obtains the exact point-to-segment squared-distance
ratio, chooses the nearest ratio with lower reach order then lower segment
order as ties, and computes `axis_distance` as the greatest non-negative
integer whose square times the ratio denominator does not exceed the
numerator. The segment half-width is linearly interpolated at the clamped
projection and rounded half away from zero. With
`outside = max(0, axis_distance - half_width)`, the collar weight is full at
zero, zero at or beyond `bank_blend_width`, and otherwise
`65536 - smootherstep(qfrom_ratio(outside, bank_blend_width))`.

A dry channel is selected explicitly from the indexed source rows whose
referenced profile has `depth = 0`; it is not expected from the horizontal wet
selector. Its authored offset is the dry bed datum, the same collar formula
returns to natural land, and `water_surface_at` returns nil.

If masks overlap, the horizontal session's classified `hydrology_id` selects
the interior wet reach. Outside-bank and dry-channel candidates are
owner-clipped by comparing the horizontal query owner with the source reach
owner; the distance rule above selects among them. No R2-bound evaluator seam
or ownership code is added.

Every current concrete confluence, bridge, ford, causeway, rapid and waterfall
interface is validated against its referenced reaches. Concrete rapid and
waterfall `upper_level_offset`, `lower_level_offset`, `run` and `drop` values
win over the normalized transition-profile descriptor.

A rapid uses the first non-coincident outgoing lower-reach segment
`(dx,dz)` as its direction, with `m = max(abs(dx),abs(dz))`. It has exactly
`run` ordered nodes and therefore `axis_steps = run - 1`,
`upstream_steps = floor(axis_steps/2)` and
`downstream_steps = axis_steps - upstream_steps`. Its exact endpoints are:

```
upstream = position - round_half_away((dx,dz) * upstream_steps / m)
downstream = position + round_half_away((dx,dz) * downstream_steps / m)
```

Section 5.3's DDA between those endpoints must contain the interface position
at index `upstream_steps + 1` and exactly `run` nodes or validation fails. This
places the extra node downstream when `run` is even. The occupied x/z mask is
the exact polyline corridor of total `width`. Water surface and bed interpolate
linearly, half away from zero, from the concrete upper values at the first
axis node to the concrete lower values at the last. This transition operation
has precedence over ordinary reach selection throughout its occupied mask;
the current overlapping source order may otherwise classify a downstream
rapid node as its upper reach.

A waterfall requires the upper reach's last point and lower reach's first
point to be distinct on one cardinal axis, with their midpoint equal to the
interface position and their L-infinity run equal to `drop_mask_length`. Its
canonical raster between those points is the fall axis; the occupied x/z mask
is its exact corridor of total `drop_mask_width`. The plunge footprint begins
at the lower point and is one downstream, cardinal, half-open rectangle of
total cross-axis `plunge_width` and along-axis `plunge_length`. The scalar bed
interpolates from upper bed to lower bed along the fall axis, while
`water_surface_at` is nil on transition-only columns. Allocation-free
`hydrology_transition_values_at` returns
`kind, interface_id, upper_y, lower_y, progress_q` so R5 can write the vertical
water face. The referenced lower reach remains the plunge-pool footprint;
its profile must equal `plunge_profile_id`, and its mask at the lower point
must lie inside the plunge rectangle or validation fails.

R3 does not invent a fall from ordinary height differences. Physically
adjacent reaches with different water levels must either have a named
interface or be proven separate by the R3 grid gate.

### 4.3 Exceptional traversable surfaces

`functional_surface_values_at(x,z)` returns scalar values, not an allocated
record:

```
kind, surface_y, feature_id, interface_id
```

It returns four nil values where no functional surface overrides ordinary
terrain. `feature_id` and `interface_id` are existing interned stable strings;
`interface_id` is nil for land grades and anchor platforms. A derived causeway
precomputes the interned id `derived:<path-id>:<one-based-span-ordinal>` during
session construction. An anchor platform returns its anchor id as
`feature_id`.

`kind` is one of `land_grade`, `anchor_platform`, `causeway`, `ford`,
`bridge_deck` or `tunnel_floor`.

- A land grade and a causeway are solid terrain and therefore also change
  `terrain_height_at`.
- A ford changes the bed/road surface to exactly `water_surface - 1`.
- A bridge deck leaves the water bed untouched and has surface y exactly
  `water_surface + 4`, leaving the required three clear nodes.
- A causeway changes solid terrain to exactly `water_surface + 1`.
- A tunnel floor leaves the overlying terrain height untouched. Its exact y is
  constructed by the two-pass route rule below so R5 can later cut a
  four-node-high lumen with proved overburden.
- Every selected non-capital anchor receives a dry `anchor_platform` at least
  one node above the water surface on each planned-water column inside its
  complete fitting square. Capital civic water is the explicit exception and
  remains water. Analytic water policy remains planned water under an anchor
  platform, just as it remains planned water after a player fills it.

For each named water interface, the operation footprint is the matching
route's visible `surface_width` intersected with its authorization polygon and
the named hydrology mask. Its first and last canonical route-axis nodes become
equal-height grade pins with the exact ford/bridge/causeway y above. Each
tunnel footprint is derived without changing R2: take the 65 canonical route
axis nodes centred on its exact interface position (32 before, the centre and
32 after). Remove axis nodes occupied by a named non-tunnel operation, then
take the one remaining contiguous run containing the tunnel centre and use
its visible route surface minus the union of every named non-tunnel operation
footprint; the named non-tunnel operation wins on each subtracted column. The
central 33 axis nodes, centre plus 16 on each side, may not be removed; a
removed central node, a split central run or an overlap between two tunnel
interfaces is a validation failure. This exact two-dimensional clipping lets a
portal meet an already-authored bridge, ford or causeway without pretending
that one column has two exceptional traversable surfaces.

Tunnel pins are constructed after every endpoint and non-tunnel operation pin.
First evaluate the route's piecewise-linear y at the tunnel centre without a
tunnel pin (`baseline_y`). Then scan the central 33 axis nodes, centre plus 16
on each side, using terrain height before any path grade. With
`interior_min` equal to their minimum, form one feasible floor interval. Its
upper bound begins at `interior_min - 5`. For the closest already-frozen pin
strictly before the clipped tunnel run, let `d_before` be the first tunnel-run
index minus that pin's index and intersect with
`[pin_y - d_before, pin_y + d_before]`; do the same for the closest pin after
the run with `d_after` equal to that pin's index minus the last tunnel-run
index. A missing pin on either route side, or an empty
intersection, is a validation failure. Clamp `baseline_y` into the resulting
closed interval and make both ends of the clipped tunnel run equal-height pins
at that floor. Thus nodes `floor+1..floor+4` are the future lumen, every
central interior column retains at least one solid overburden node at
`floor+5`, and both portal approaches are constructively able to satisfy the
ordinary adjacent-step gate.

R3 freezes only these heights, ids, masks and kinds. Culvert blocks, bridge
supports, tunnel walls, liquid faces and seals are R5 typed planner operations.

## 5. Functional grading

### 5.1 One small precedence

On an ordinary land column the high-to-low functional precedence is:

1. start fitting grade;
2. capital fitting grade;
3. guaranteed coastal-housing-core grade;
4. land route or selected POI-spur grade;
5. selected-anchor fitting grade; and
6. natural relief and landmark result.

This makes the existing design phrase “start, capital, housing, route and
selected-anchor” explicit rather than dependent on loop order. Start, capital,
coastal-core and anchor grades are owner-clipped. A frozen route/spur/island
grade follows its accepted complete route footprint across whatever land
owners R2 classifies there; it is not clipped to `zone_a`, `zone_b` or a
two-zone assumption. Planned-water columns preserve their hydrology bed except
for a named/derived route operation or a required selected-anchor platform.
Start and coastal-core footprints are already proven dry; civic water inside a
capital is therefore preserved rather than silently filled by the capital
grade.

### 5.2 Starts, capitals, coastal cores and selected anchors

All 17 current anchor-profile rows, containing 13 distinct shape tags, use one
R3 fitting primitive: a flat centred half-open square of `fitting_width`, with
smootherstep return to the incoming height before the edge of `blend_width`.
The shape tag remains a later structure/dressing tag. This deliberately
rejects the old generic template DSL.

The fitting target is constructed once, not guessed from the centre. For every
land column with natural height `h` in the selected fitting square, accumulate
`lower = max(h - max_cut)` and `upper = min(h + max_fill)`. Planned-water
columns of a non-capital selected anchor additionally raise `lower` to their
maximum `water_surface + 1`; the same columns become `anchor_platform` across
the full-weight fitting square, not its outside collar. Capital civic-water
columns are excluded from both the target bounds and the grade.
When `lower <= upper`, clamp the natural centre height into that closed
interval; when it is empty, R3 reports a source violation. It never rejects or
reselects the anchor. This target makes every fitting-square land column obey
the authored cut/fill limits. Every collar result is additionally clamped to
`[incoming - max_cut, incoming + max_fill]`, so a very different height just
outside the fitting square cannot violate the same limits. A qualifying
planned-water part is reported as an anchor platform.

The six starts and six capitals use their existing fixed anchor/profile rows.
Their routes share the same target at the common hub. Capital grading applies
only to its land columns, so the currently authored civic river/lake/cenote
water remains water.

Each guaranteed coastal core has one seed-specific target equal to its natural
height at the capsule centre and one dedicated 64-node-cell gentle lattice.
Its root uses section 3.1 with domain
`coastal-core-gentle-v1:<coastal-core-id>`; each corner uses the same mixer with
octave ordinal one and maps by `floor(s * 13 / P) - 6`. Smootherstep bilinear
interpolation is rounded once and remains in `[-6,+6]`. Thus every exact
capsule column is in one closed 12-node natural-height band. A 64-node
owner-clipped outside collar returns to ordinary relief. This grade is not a
promise for the complete ten housing masks and does not pre-grade future
player claims.

### 5.3 Routes and POI spurs

R3 uses no path search and no earthwork optimizer. It first expands every
sparse source segment `a -> b` into one canonical 8-connected DDA raster. With
`steps = max(abs(dx),abs(dz))`, node `k` for `k=0..steps` is
`a + (round_half_away(dx*k/steps), round_half_away(dz*k/steps))`. The first
node of every later segment is omitted. The major axis changes on every step,
so joins are the only possible duplicates; any other duplicate is a
violation. Array order is the canonical cumulative L-infinity node run.

Each route station has one integer target: the matching start/capital target
where applicable, otherwise the natural height at the frozen zone hub, raised
to `water_surface + 1` if needed. The raster receives ordered grade pins at
both endpoints and at every named operation footprint. Scanning the raster's
horizontal classification also creates a derived-causeway span for every
maximal run of locally owned planned water not covered by a named interface;
a change of hydrology id or water-surface y starts a new span. Its first and
last nodes are equal-height pins at `water_surface + 1`.

Between adjacent pins, route y is linear in raster index and rounded half away
from zero. Conflicting pins at one node are a violation rather than a priority
guess. The route is valid only if every adjacent raster node changes by at
most one vertical node.

The selected candidate's POI spur uses the same raster/pin rule from the
selected anchor target to its zone-hub station target. Unselected candidate
spurs do not enter height evaluation. Its R2 claim-exclusion width is the
corridor width; width 12 uses the secondary-road surface width 5 and width 8
uses the trail surface width 3. Island routes use their R2 width 12 and surface
width 5, pin their authored vertices to the natural or landing surface and use
the same raster/piecewise-linear rule. Boat paths do not grade the ocean.

For an off-axis column, consider every indexed source segment whose exact
continuous corridor contains it. Clamp the exact dot-product projection to
that segment and convert it to a rational canonical raster-run position:
`segment_first_run + dot * segment_steps / segment_length_squared`. Select the
nearest integer run, with an exact half tie choosing the lower run, and use
that already-frozen axis node's y. Consequently an internal interface or
causeway pin affects the complete neighboring road surface rather than only
the axis. Lowest exact squared-distance ratio wins between paths; ties use
land route, selected POI spur, island route, then stable string id and lower
segment order.

Within `surface_width` the chosen scalar path target has full weight. Between
`surface_width` and `corridor_width`, let `n/d` be exact squared distance and
compute
`t_q = qfrom_ratio(4*n - surface_width^2*d,
                   (corridor_width^2-surface_width^2)*d)`.
The weight is `65536 - smootherstep(t_q)` and returns to the incoming height.
The stage-local 128-node buckets are private acceleration only; R4 may discard
or absorb them into its separately assigned consolidated sparse-feature
index. Every losing path axis is still checked after final composition, so an
undeclared crossing cannot silently break it.

The one deliberately uniform R3 slope rule is therefore “no more than one
vertical node per one horizontal centreline node.” It is a safety limit, not
a target slope: the broad relief and long routes normally produce much gentler
grades. The superseded 1:12/1:8/1:4 route DP is not restored.

Where a route crosses locally owned planned water without a named interface,
the derived operation is the pinned causeway span defined above. Its complete
footprint is that path's visible surface intersected with columns carrying the
same classified hydrology id and water-surface y as the axis span. Named
bridge/ford/causeway/tunnel spans win only inside their exact footprints.
Shelf, deep ocean and dragon channels remain unconditionally forbidden.

## 6. R3 module and frozen payload

`mods/MAPGEN/grug_mapgen/wp40/height.lua` is engine-free and returns a module
factory. Dependencies are the current simple-map source, canonical encoder,
deterministic helpers, raw SHA-256 and one already-created horizontal session
for the same canonical full seed. The height schema constant is local to this
new module so `schemas.lua` remains byte-identical to its accepted R2 hash. It
registers no globals or hooks.

The height session exposes at least:

- allocation-free scalar `terrain_height_at(x,z)` and
  `water_surface_at(x,z)`;
- allocation-free scalar-tuple `functional_surface_values_at(x,z)` and
  `hydrology_transition_values_at(x,z)`;
- defensive-copy `selected_anchor_3d_by_id(anchor_id)` and
  `hard_protection_volumes()`;
- `relief_lattice_digest()`, `canonical_kat()` and
  `canonical_kat_digest()`; and
- read-only metrics proving that query-time SHA calls and query-time lattice
  construction are zero.

An anchor record stores the frozen selected x/z, ground y, placement mode,
candidate index and platform/path kind where applicable. Hard-protection rows
retain the exact R2 x/z footprint and their existing y policy (`-700`
inclusive upward without limit). Anchor squares and socket columns add their
resolved centre surface y. An ingress corridor retains nil for that scalar and
continues to reference its two graded route ids; it does not falsely collapse
a varying route to one height. No chunk, native heightmap or callback can
change these results.

## 7. Required evidence and gates

The R3 artifact is one canonical TSV whose body digest and complete file hash
are recorded in the R3 review. It binds every executable input hash and at
least:

- the accepted R2 artifact body digest and complete-file hash, verified before
  the R3 run;
- schema, layout id, seed and project water level;
- relief-root, octave-lattice and final base-lattice digests;
- min/max counts and witnesses for all six primary profiles and all 70
  owner-clipped landmark masks;
- all 100 selected x/y/z anchors and 42 hard-protection volumes;
- anchor cut/fill extrema and zero rejected/reselected anchors;
- all frozen route/spur/island centreline grades, maximum step, overlap
  witnesses and every derived or named water operation;
- all 25 hydrology reaches and 12 concrete interfaces, including exact
  surface/bed values and rapid/waterfall offsets;
- shelf, bay, deep-ocean and dragon-channel bed witnesses;
- complete-capsule natural-height min/max for each coastal core and the count
  of its wholly contained eligible 101 by 101 reservations. The global
  capsule range at most 12 proves every such reservation without rescanning
  every 101 by 101 window; and
- deterministic construction/query operation counts and the query-time SHA
  count. Host/interpreter wall-clock timings are emitted in the run log as
  unbound evidence only; they never enter the canonical artifact because that
  would make byte-identical reproduction impossible.

The exhaustive fixed-layout/seed-zero scan runs under LuaJIT. It checks the
complete accepted R2 x/z extent, all route axes/corridors, every selected
anchor envelope, all hydrology masks/interfaces and the complete four-core
reservation population. It fails on an unsafe integer, missing height,
profile/mask owner escape, cut/fill overflow, route step above one, forbidden
exterior path, broken named interface, disconnected unequal-level water
contact without an interface, coastal relief above 12, or nondeterministic
artifact.

Targeted PUC 5.1 KATs cover seeds `0`, `1`, `2^63` and `2^64-1`, negative
coordinates, all relief-profile families, lattice corners/interiors, every
mask primitive, all six functional grade kinds, dry/wet hydrology, shelf/deep
ocean, one rapid and one waterfall. Their canonical bytes/digests must be
byte-identical to LuaJIT. PUC does not repeat the exhaustive scan or a 32-seed
population. The broader 32-seed height/content/resource evidence remains R6,
as assigned by the accepted rebase plan.

Every Lua change also runs `tools/bin/luac51 -p`, the `SETGLOBAL` inspection
and all five Lua 5.1/sandbox sweeps explicitly over changed production and
tool Lua. The R3 runner supports `WP40_LUA_BIN` and defaults expensive work to
LuaJIT.

## 8. Review stop conditions

R3 does not proceed to production integration if any of these occurs:

- a second owner, zone, water or anchor-selection evaluator appears;
- SHA-256, feature-list construction or lattice construction occurs in a
  height query;
- an old compiler, boundary graph, route DP, generic CSG/template DSL or
  engine height becomes a dependency;
- a selected 2D anchor is moved, rejected or reselected for height;
- one scalar is used dishonestly for both a water bed and bridge deck or both
  a hilltop and tunnel floor;
- a planned-water crossing is globally exempted instead of receiving a local
  deterministic operation;
- any of the 14 accepted R2 artifact input hashes changes without a refreshed
  R2 artifact and focused independent R2 rereview; or
- a performance number becomes a pass/fail gate without a measured complete
  mapchunk budget and written justification.

## 9. Independent review record

The independent contract review used GPT-5.6 Sol at xhigh effort in a fresh,
read-only context. The initial review returned **REJECTED** with 0 Critical,
4 High, 6 Medium and 1 Low findings. The first correction round made route
raster/projection semantics, named water-interface footprints, cut/fill
feasibility, the immutable R2 boundary, bank and dry-channel math, coastal-core
proof, stable feature identity and the private R3 index exact. Its focused
rereview returned **REJECTED** with 0 Critical, 2 High, 1 Medium and 0 Low:
off-axis route heights did not yet bind internal pins, tunnel overburden was
not constructive, and rapid extension geometry was ambiguous.

The second correction round bound off-axis columns to frozen axis-node
heights, constructed tunnel floors from the ungraded interior minimum, and
defined rapid endpoints and raster length exactly. The focused rereview
returned **ACCEPTED**, 0 Critical / 0 High / 0 Medium / 0 Low. Fix-round count
was two at that acceptance.

A subsequent full frozen-source audit exposed one real tunnel/causeway overlap
and clarified timing evidence, cross-owner routes, rapid precedence,
planned-water anchor platforms and the source's 17 profile rows/13 shape tags.
The first focused amendment review returned **REJECTED** with 0 Critical,
1 High, 0 Medium and 0 Low because clipping only the tunnel axis left a
possible off-axis surface overlap. The correction subtracts every named
non-tunnel operation footprint from the tunnel's complete visible surface.
Its focused rereview returned **ACCEPTED**, 0 Critical / 0 High / 0 Medium /
0 Low. Total contract fix-round count is four. This acceptance covers the
contract only; the implementation, artifact and production integration still
require their own gates and independent review.
