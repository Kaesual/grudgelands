# WP40 simple-map R3 vertical contract

**Status (2026-08-25): independently accepted implementation contract,
including the constructive route skeleton and grade-composition clarification.
R2 is accepted; no R3 implementation or artifact is accepted yet.**

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
`feature_id` is the path id for every path grade, the landing id for a landing
grade, or the anchor id for an anchor platform. `interface_id` is the crossing
id inside a named interface and nil for land grades, platforms and unnamed
derived water operations. No per-column or per-span string is constructed.

`kind` is one of `land_grade`, `anchor_platform`, `causeway`, `ford`,
`bridge_deck` or `tunnel_floor`.

- A land grade, a causeway and an anchor platform are solid terrain and
  therefore change `terrain_height_at` to their final surface.
- A named ford changes the bed/road surface to the final route grade. Its
  centre pin is exactly `water_surface - 1`; the remainder of the footprint is
  the one-node-per-step ramp constructed in Section 5.3. The same ford id owns
  the minimal adjacent approach runs required to meet ordinary water without
  breaking that exact centre pin.
- A named bridge is always a `bridge_deck`, leaves the water bed untouched and
  stays at least four nodes above its local clearance datum.
- A named causeway is always solid `causeway` terrain and stays at least one
  node above its local clearance datum. It may rise as a graded causeway ramp;
  its authored kind does not silently change to a bridge.
- On unnamed locally owned planned water, a final path surface exactly one
  node above its clearance datum is a solid derived `causeway`; a higher
  surface is a derived `bridge_deck` and leaves the water bed untouched.
- A tunnel floor leaves the overlying terrain height untouched. Its exact y is
  constructed by the route-skeleton rule below so R5 can later cut a
  four-node-high lumen with proved overburden.
- Every selected non-capital anchor receives a dry `anchor_platform` at least
  one node above the water surface on each planned-water column inside its
  complete fitting square. Capital civic water is the explicit exception and
  remains water. Analytic water policy remains planned water under an anchor
  platform, just as it remains planned water after a player fills it.

The current transition-profile numbers are constraints on this simple grade,
not a second slab generator: `minimum_clearance_nodes = 3` sets the named
bridge minimum, `deck_y_offset_from_W = 1` sets the named causeway minimum,
and `road_y_offset_from_bed = 0` fixes the named ford centre to its one-deep
bed. The surrounding ford authorization footprint is deliberately the graded
approach rather than an incompatible flat plate. Its automatically derived
outside approach is bounded by the exact slope cone in Section 5.3. This
contract defines the vertical interpretation of those R2-retained inputs.

For each named non-tunnel water interface, the operation footprint is the
matching route's visible `surface_width` intersected with its authorization
polygon and the named hydrology mask. Its columns contribute the exact
clearance constraints defined in Section 5.3; bridge and causeway footprints
are not flat slabs and do not create conflicting endpoint pins.

Each named tunnel occupies exactly 33 canonical route-axis nodes centred on
its exact interface position: 16 before, the centre and 16 after. Its complete
footprint is those nodes' visible route surface. A missing centre, too-short
route, overlap with any named non-tunnel operation or overlap between tunnels
is a validation failure; there is no larger nominal span, clipping or hidden
portal extension.

Tunnel pins are constructed after the endpoint and ford-centre pins but before
water-clearance grading. First evaluate the piecewise-linear skeleton at the
tunnel centre without a tunnel pin (`baseline_y`). Scan every column of the
complete 33-run visible-surface footprint using terrain height before any path
grade and let `interior_min` be their minimum. The feasible floor interval
starts with an upper bound of `interior_min - 5`. Intersect it with
`[pin_y - d_before, pin_y + d_before]` for the closest fixed pin strictly
before the tunnel, where `d_before` is the distance from that pin to the first
tunnel node, and with the analogous interval for the closest fixed pin after
the tunnel. A missing pin on either side or an empty interval is a violation.
Clamp `baseline_y` into the interval and add equal-height pins at the first and
last tunnel nodes. Thus nodes `floor+1..floor+4` are the future lumen, every
interior column retains at least one solid overburden node at `floor+5`, and
both approaches can satisfy the adjacent-step gate without a route optimizer.

R3 freezes only these heights, ids, masks and kinds. Culvert blocks, bridge
supports, tunnel walls, liquid faces and seals are R5 typed planner operations.

## 5. Functional grading

### 5.1 One small precedence

On an ordinary land column the high-to-low functional precedence is:

1. start fitting grade;
2. capital fitting grade;
3. guaranteed coastal-housing-core grade;
4. land route or selected POI-spur grade;
5. island landing grade;
6. selected-anchor fitting grade; and
7. natural relief and landmark result.

This makes the existing design phrase “start, capital, housing, route and
selected-anchor” explicit rather than dependent on loop order. Start, capital,
coastal-core, landing and anchor grades are owner-clipped. A frozen
route/spur/island grade follows its accepted complete route footprint across
whatever land owners R2 classifies there; it is not clipped to `zone_a`,
`zone_b` or a two-zone assumption. Planned-water columns preserve their hydrology bed except
for a named/derived route operation or a required selected-anchor platform.
Start and coastal-core footprints are already proven dry; civic water inside a
capital is therefore preserved rather than silently filled by the capital
grade.

This precedence is compositional, not a winner-takes-all jump between masks.
Scalar land grades are evaluated from the lowest row upward. At any collar,
`incoming` means the complete result of every lower-priority stage at that
column, including a lower route or landing grade; full weight still replaces
it with the higher stage's target. A start, capital or coastal collar therefore
blends smoothly back to an intersecting graded route rather than hiding the
route until a discontinuous mask edge. Planned-water bed/deck exceptions keep
the explicit Section 4.3 semantics and are not turned into scalar land by this
composition rule.

### 5.2 Starts, capitals, coastal cores and selected anchors

Every zone has one seed-independent skeleton height:

```
zone_station_y = water_level + primary_relief.min_above_water
```

This uses the already-authored relief band rather than a new height table. A
start uses its owning zone's `zone_station_y` as `reference_y`. Every selected
non-start/non-capital anchor, including the fixed dragon and apex anchors,
uses the fixed band midpoint
`water_level + floor((primary_min + primary_max) / 2)`. On planned water it
raises that reference to at least its local clearance datum plus one. The
midpoint keeps small highland/mountain fitting squares from becoming needless
deep cuts without making route endpoints depend on the seed.

A capital scans all civic-water columns in its full fitting square and uses
`zone_station_y` when that set is empty; otherwise it uses the larger of
`zone_station_y` and one plus the set's maximum clearance datum. This keeps its
land terrace flood-safe while preserving the authored civic water. A capital
centre in water is a source violation; current R2 centres are dry.

A capital-zone hub uses that capital's `reference_y`. Any other zone hub on
planned water uses `max(zone_station_y, local clearance datum + 1)`; every
other hub uses `zone_station_y`. A missing clearance datum at any scanned
planned-water column is a violation. Section 5.3 defines the one clearance
datum used by hubs, anchors and paths.

All 17 current anchor-profile rows, containing 13 distinct shape tags, use one
R3 fitting primitive: a flat plateau at `reference_y` over the centred
half-open square of `fitting_width`, with smootherstep return to the incoming
height before the edge of `blend_width`. The shape tag remains a later
structure/dressing tag. This deliberately rejects the old generic template
DSL: later walls, roots, buildings and stairs may dress this resolved ground,
but may not introduce a second terrain-height authority. The source `max_cut`
and `max_fill` fields are retained only because R2 is
immutable; the first construction proved them incompatible with the selected
anchors and route endpoints, so R3 binds them as `consumed=false` and does not
use them as vertical limits. Observed cut/fill extrema remain evidence, not a
rejection or reselection rule. The complete fitting square and collar are one
explicit authored functional-grade volume for R4 preservation purposes; they
do not authorize terrain changes outside that bounded volume.

Both widths must be positive even integers with `blend_width > fitting_width`.
For either axis, a total width `t` around centre `c` has integer full bounds
`[c-t/2, c+t/2)`. With `half = fitting_width/2`, define the integer axis
excess as `c-half-p` below the lower bound, `p-(c+half)+1` at or above the
upper bound, and zero inside. `outside` is the maximum x/z axis excess and
`collar = (blend_width-fitting_width)/2`. The full square has weight 65536;
outside the full square but before `outside >= collar`, weight is
`65536 - smootherstep(qfrom_ratio(outside, collar))`; at or beyond that point
it is zero. The final land height is the Q16 mix
`incoming*(65536-weight) + reference_y*weight`, divided by 65536 and rounded
once half away from zero. The same primitive and endpoint conventions apply to
all 17 rows.

For a planned-water column inside a non-capital selected anchor's full-weight
fitting square, the `anchor_platform` surface is
`max(reference_y, local clearance datum + 1)`. The platform does not extend
into the outside collar. Capital civic-water columns are excluded from both
the grade and platform and remain water.

The six starts and six capitals use their existing fixed anchor/profile rows.
Capital grading applies only to its land columns, so the currently authored
civic river/lake/cenote water remains water. Routes meet every hub and selected
anchor at the same skeleton/reference target; natural relief never becomes a
second endpoint-height authority.

Each guaranteed coastal core has one seed-specific target equal to its natural
height at the capsule centre and one dedicated 64-node-cell gentle lattice.
Its root uses section 3.1 with domain
`coastal-core-gentle-v1:<coastal-core-id>`; each corner uses the same mixer with
octave ordinal one and maps by `floor(s * 13 / P) - 6`. Smootherstep bilinear
interpolation is rounded once and remains in `[-6,+6]`. Thus every exact
capsule column is in one closed 12-node natural-height band. A 64-node
owner-clipped outside collar returns to the complete lower-priority incoming
height. This grade is not a promise for the complete ten housing masks and
does not pre-grade future player claims.

### 5.3 Routes and POI spurs

R3 uses no path search and no earthwork optimizer. It first expands every
sparse source segment `a -> b` into one canonical 8-connected DDA raster. With
`steps = max(abs(dx),abs(dz))`, node `k` for `k=0..steps` is
`a + (round_half_away(dx*k/steps), round_half_away(dz*k/steps))`. The first
node of every later segment is omitted. The major axis changes on every step,
so joins are the only possible duplicates; any other duplicate is a
violation. Array order is the canonical cumulative L-infinity node run.

The endpoint target for a land route is the Section 5.2 target of its frozen
zone-hub station. The selected candidate's POI spur runs from its selected
anchor `reference_y` to that same zone-hub target. Unselected candidate spurs
do not enter height evaluation. Its R2 claim-exclusion width is the corridor
width; width 12 uses the secondary-road surface width 5 and width 8 uses the
trail surface width 3.

Island routes use their R2 width 12 and surface width 5. Each landing endpoint
is fixed at `water_level + 1`, each shared island junction is fixed at the
owning mountain zone's `zone_station_y`, and each dragon/apex endpoint uses
its selected anchor `reference_y`. Every island-owned land column inside the
matching boat path's exact width-96 corridor is a flat landing grade at
`water_level + 1`; water and mainland columns are unchanged. The five-node
island route wins where it leaves that landing grade and climbs toward the
junction, so no ungraded water-to-mountain wall remains. Boat paths do not
grade the ocean.

The first skeleton pins are all path endpoints and the centre node of every
named ford. A ford-centre pin is exactly its local `water_surface - 1`.
Between adjacent pins, skeleton y is linear in raster index and rounded half
away from zero. Conflicting pins at one node are a violation. Section 4.3 then
adds the two equal tunnel-end pins and rebuilds this piecewise-linear baseline.
Every pin interval must already be able to change by at most one vertical node
per raster step; the later clearance pass may raise the baseline but may not
move an exact endpoint, ford-centre or tunnel pin.

R3 next scans every column in the complete visible surface of the path and
projects it to its nearest canonical raster run by the exact rule below. A
locally owned planned-water column contributes one lower bound to that run:

- ordinary unnamed water and a named causeway require
  `clearance datum + 1`;
- a named bridge requires `clearance datum + 4`;
- a named ford requires at least `water_surface - 1` and is exempt from the
  ordinary-water lower bound; and
- a named tunnel is land-only and contributes no water lower bound.

An exact ford centre also caps an ordinary unnamed-water lower bound on the
same path and with the same classified hydrology id to
`ford_pin_y + abs(run - ford_run)`. With multiple matching fords, use the
minimum cap and break an exact tie by stable crossing id. The cap is active
only where it is lower than the ordinary bound; another hydrology id and named
bridge/causeway bounds are never capped. Thus a one-deep ford can rise through
the mathematically minimal submerged approach and rejoin the ordinary
`clearance + 1` rule as soon as the one-Lipschitz cone reaches it. Every column
projected to an active cap is part of that named ford's derived approach and
returns `kind = ford` with its crossing id.

The clearance datum is `water_surface_at` when non-nil. On a waterfall
transition-only column, where the scalar water surface deliberately remains
nil, it is `max(upper_y, lower_y)` from
`hydrology_transition_values_at`. Any other planned-water column without
either datum is invalid and requires a named operation or horizontal source
correction. This fallback affects only traversable clearance; it never changes
analytic hydrology or invents a water surface.

For each run, start with the larger of its piecewise-linear baseline and all
projected lower bounds. For `i = 2..n`, the left-to-right pass sets
`value[i] = max(value[i], value[i-1] - 1)`. For `i = n-1..1`, the
right-to-left pass sets
`value[i] = max(value[i], value[i+1] - 1)`. These two passes construct the
unique minimal integer one-Lipschitz majorant of the baseline and lower bounds.
Validation fails if the result changes an exact pin. It also checks every final
adjacent pair, rather than treating the construction as its own proof.

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
a target slope. The route's fixed skeleton, one water-footprint scan and two
linear closure passes replace the superseded 1:12/1:8/1:4 route DP; there is
no search, optimization state or seed-dependent endpoint height.

Inside a named ford, bridge or causeway footprint, the authored operation kind
wins and uses the final projected path y. A column under an active ford cap is
the same named ford's derived approach. Inside the exact tunnel footprint, the
frozen tunnel floor wins and scalar terrain remains ungraded. On remaining
unnamed locally owned planned water, a final path column exactly one above its
local clearance datum is a derived causeway; a higher column is a derived
bridge deck. On ordinary land, the same final y is a scalar `land_grade`.

Named footprints never grant a route-wide water exception. Shelf, deep ocean
and dragon channels remain unconditionally forbidden. Every complete visible
path surface is rescanned after composition for its clearance, functional kind
and final step; an undeclared or off-axis crossing cannot silently pass.

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
- the complete station/reference table, capital civic-water maxima, anchor
  footprint/collar counts, observed cut/fill extrema, explicit
  `source_cut_fill_limits_consumed=false` and zero rejected/reselected anchors;
- all frozen route/spur/island centreline baselines and final grades, every
  exact pin, projected two-dimensional water lower-bound counts and witnesses,
  maximum step and overlap witnesses;
- every named water operation keyed by crossing id, plus for unnamed derived
  water the per-path/per-run kind counts, lexicographically first witnesses and
  one canonical digest of the complete visible-surface classification. Derived
  output has no invented component or span identity;
- every active ford-approach cap with its ford pin, uncapped/capped lower
  bound, distance and first run where the ordinary lower bound resumes;
- a supporting lower-bound witness for every run raised above its baseline,
  plus independent equality checks for every unchanged exact pin;
- the four width-96 island landing grades and their water-to-junction route
  approaches;
- for both tunnels, the exact 33-node run and complete two-dimensional
  footprint, pre-path interior minimum, feasible interval, baseline, floor,
  overburden and both approach-pin witnesses;
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
profile/mask owner escape, anchor reference or owner-clip mismatch, route step
above one, non-minimal route envelope, changed exact pin, missing clearance,
forbidden exterior path, broken named interface, insufficient tunnel
overburden, disconnected unequal-level water contact without an interface,
coastal relief above 12, or nondeterministic artifact.

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
0 Low. Total contract fix-round count was four at that acceptance.

The first real seed-zero construction then proved that a single flat 512 by
512 capital plane was impossible without violating the frozen cut/fill limits:
Dur Brannoc ranged from y 100 to 177, making the old global interval 153 to
116. The same construction exposed a natural-height/causeway conflict at the
planned-water Gravesalt hub. The fifth correction round replaced the global
plane with the per-column centre-referenced clamp and made planned-water hub
stations exactly `water_surface + 1`. Its focused review returned
**ACCEPTED**, 0 Critical / 0 High / 0 Medium / 0 Low. Total contract fix-round
count is five. This acceptance covers the contract only; the implementation,
artifact and production integration still require their own gates and
independent review.

The first full route construction then proved that seed-dependent natural
endpoint pins were incompatible with the uniform adjacent-step gate: seed zero
had 9 infeasible intervals and 137 bad steps, while the four contract seeds
together implicated 16 paths. A focused in-memory redesign replaced those
pins and the flat derived-water slabs with a seed-independent station/anchor
skeleton, complete two-dimensional water lower bounds and the minimal
two-pass one-Lipschitz envelope. Restricting each authored tunnel to its actual
central 33-node lumen removed the nominal-span overlap machinery. The final
V2c axis prototype had zero pin conflicts, zero bad steps and both tunnels
feasible for all four contract seeds; the island follow-up also fixed each
landing at `water_level + 1` and retained the same axis result. A later
complete projected-surface scan found one off-axis conflict on every seed:
ordinary water at
`route_050` run 707 required y 10 and would raise the adjacent exact
`broken_ford` pin at run 708 from y 8 to 9. The final amendment adds the
generic minimal ford-approach cap; at distance one the effective lower bound is
9 and at distance two the ordinary y 10 rule resumes. The same complete scan
proved both 33-run tunnels feasible over their full visible footprints. This
constructive amendment was then submitted to a fresh independent full review;
the prototype results alone did not accept it.

The fresh independent full review of that amendment initially found 1 High,
5 Medium and 0 Low issues: the empty capital-water set, derived-operation
evidence identity, exact envelope assignments, tunnel evidence terminology,
anchor-platform scalar semantics and fitting-collar arithmetic. All were
closed without adding a solver or changing R2. The final rereview returned
**ACCEPTED**, 0 Critical / 0 High / 0 Medium / 0 Low. Total contract
fix-round count is six. This acceptance covers the contract only; the
implementation, artifact and production integration still require their own
gates and independent review.

The first integrated seed-zero query then exposed a composition seam on
`route_001` run 131: a start-fitting collar calculated independently against
natural relief yielded y 33 and hid the y 12 route until the next raster node.
The seventh correction made the existing precedence explicitly bottom-up and
compositional, so every higher collar blends to the complete lower-priority
result at that column. Its focused independent review returned **ACCEPTED**,
0 Critical / 0 High / 0 Medium / 0 Low. Total contract fix-round count is
seven. This acceptance still covers the contract only; implementation,
artifact and production integration remain separately gated and reviewed.
