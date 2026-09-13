# WP40 quality geometry revision

**Status:** implemented phase-one semantic record, 2026-09-13. This record
supersedes the production vertical choices in the historical simple-map R3
contract. It does not alter or rewrite the R3 evidence artifacts.

## Scope and authority

The horizontal R2 authority remains fixed: extent, land and water masks, zone
ownership, routes, hydrology, anchor coordinates, housing policy, protection
volumes and claim exclusions do not move. The vertical schema is
`grug_wp40_simple_map_height_v2`, selected by source revision
`wp40-height-quality-v2`. Fresh-server development does not retain a fallback
to the former height schema.

Phase one changes natural relief, landmark edge composition, capital grading
and route grades. Surface materials, resources and the separately planned
surface-cave operation consume the resulting final height; they do not define
a second scalar height.

## Natural relief

The six accepted profile octave sets and their periods remain the broad
relief authority. Their values are sampled on the existing 64-node,
owner-selected base lattice. The base lattice now uses linear Q16 bilinear
interpolation. This removes the second smootherstep that formerly rounded an
already smootherstep-interpolated profile back through the 64-node lattice.

Two common, seed-derived detail lattices are evaluated after the base and
landmark composition, at periods 64 and 32. Their normalized contributions
have weights 2/3 and 1/3 and are clamped to `[-65536,65536]` before the
profile amplitude is applied. Detail amplitudes in nodes are:

| Relief | Amplitude |
|---|---:|
| wetland delta | 2 |
| lowland | 4 |
| rolling hills | 6 |
| plateau | 7 |
| highland | 9 |
| mountain | 12 |

The amplitude itself is linearly interpolated from the four existing owner
vertices. This keeps relief continuous at a zone edge without changing the
authoritative owner of any column. The detail fields are never stored in and
resampled through the 64-node base lattice.

Landmark shape weight is multiplied by the owning zone's Q16 affinity. The
affinity is the bilinear interpolation of four values that are 65536 when the
base-lattice vertex belongs to the landmark owner and zero otherwise. A
landmark can therefore feather vertically across at most the adjacent
64-node owner cell. Zone identity and every policy query still use the exact
horizontal owner. Construction rejects a landmark whose centre has zero
owner affinity and records feathered and zero-affinity columns separately.

## Capital terrain

The 512 by 512 capital build envelope, its 704-node blend envelope and all
protection volumes remain fixed in x/z. Only the dry, capital-owned part of
the central 96 by 96 civic core is forced to one elevation. Water and route
operations keep their existing precedence.

For every dry civic column with natural height `N`, the desired cut/fill
interval is `[N - 24, N + 16]`. Planned-water civic columns add a lower bound
of `water clearance + 1`. Let `L` be the maximum lower bound and `U` the
minimum upper bound. When `L <= U`, the reference is the natural centre
height clamped to `[L,U]`. When the fixed 96-node core makes `L > U`, the
unconstrained minimax reference is `round_half_away((L + U) / 2)`. The final
reference is at least the former zone-station height because that station
floor is part of the already feasible route/water gate envelope. The record
reports the resulting unavoidable limit excess; it does not claim that 24/16
is a universal hard bound.

Outside the civic core, local incoming height `N` is quantized about the
reference:

```text
terrace(N) = reference + step * round_half_away((N - reference) / step)
```

Steps are four nodes for dwarf and orc capitals, two for the human capital,
and three for elf, undead and troll capitals. The core-to-terrace transition
uses smootherstep over the next 32 nodes. Terraces cover the remainder of the
512-node build envelope and blend back to incoming terrain across the
96-node outer collar. Outside the exact civic core, the authored 24/16 target
limits clamp the shaped value before the outer blend.

Routes through a civic core sample this flat grade as their preferred land
height. Exact route pins and water clearance remain harder constraints, so a
wet gate approach may ramp through a dry edge column rather than violate the
water contract. This exception remains an explicit route functional surface.

## Route fitting

The source x/z centreline, widths, endpoint pins, ford and tunnel pins,
crossing policy and maximum adjacent grade of one node are unchanged. Linear
pin interpolation remains only a diagnostic baseline and the provisional
tunnel-floor input.

For each final route run, the preferred height is the rounded mean of
`scalar_before_paths` across all land columns in the complete route surface.
Runs without land retain the linear baseline as their preference. Existing
water clearance supplies lower bounds; exact pins supply equal lower and
upper bounds. A forward pass intersects each run with the previous reachable
interval expanded by one node. An empty interval is a construction error that
names the route, run, bounds, pin and water bound. Starting at the final run,
a reverse pass clamps every preferred height to both its reachable interval
and the next selected height expanded by one node.

This is a deterministic projection of local terrain into the already accepted
pin/water/grade envelope. It does not invent a universal road cut/fill limit.
Evidence records the preferred range, maximum preference deviation and the
actual maximum land cut and fill for every route.

## Bounded evidence

`tools/wp40/quality_geometry_fixture.lua` constructs only seed `0` and the
reported visual-review seed `13191094842853985814` under LuaJIT. It verifies
the six 96-node cores, non-flat 512-node envelopes, repeat-query order and the
road area around `(1000,1000)`. The old road sample spanned y=9..40 on the
visual-review seed; the revised five-point sample spans y=16..17. Seed `0`
spans y=9..10.

Five capitals have feasible 24/16 core intervals on both seeds. Kezamba is
the explicit fixed-core exception:

| Seed | L and witness | U and witness | Reference | Excess |
|---|---|---|---:|---:|
| `0` | 66 at `(1839,1493)` | 27 at `(1752,1452)` | 57 | 30 |
| `13191094842853985814` | 66 at `(1839,1493)` | 26 at `(1752,1527)` | 57 | 31 |

In both cases the minimax terrain result is raised to the existing station
floor of 57. The fixture prints the interval, witnesses, rule and excess for
all six capitals on both seeds.

Any accepted phase-one byte change replaces the current production height,
route, planner and generated-content digests. Historical R3-R7 artifacts stay
unchanged. Development and exhaustive checks use LuaJIT.
`tools/wp40/quality_geometry_micro_kat.lua` loads the changed production
height module and exercises the exact capital-reference, terrace and route
backtracking helpers without constructing a seed population. Frozen final
bytes use that compact fixture in one PUC 5.1 process and once under LuaJIT,
with byte-identical output, following `docs/research/luanti-lua.md`.
