# WP40 terrain, POI and inland-water geometry contract

Status: frozen implementation contract for the 2026-09-13 R8 visual-quality
follow-up. The reference world is fresh. This note changes no horizontal V1e
layout, route, zone, anchor or hydrology footprint.

## 1. Terrain frequency balance

The six relief classes retain their elevation bands and their relative
identity: `wetland_delta` and `lowland` remain lowest, while `highland` and
`mountain` retain the largest vertical range. The existing profile octaves are
reweighted toward their shorter authored period. No octave, per-column noise
pass or second height authority is added. The already shared 64- and 32-node
detail lattices contribute equally, and profile detail amplitudes become
3/6/9/10/12/16 nodes from wetland through mountain.

An authored landmark still changes the relief class within its footprint, but
its maximum replacement weight is 3/4. Its existing 64-node natural collar and
owner-affinity fade remain. This keeps named ridges, bowls and terraces legible
without allowing a large primitive to erase all intermediate terrain from its
zone. Start, capital, housing, route, hydrology and fixed-anchor grading retain
their later precedence.

## 2. Ordinary POI fitting

Starts retain their fixed station height. Capitals retain their established
96-node civic core, terrace rules and bounded cut/fill contract. Every other
anchor profile declares a smaller even `building_core_width` inside its
existing fitting and blend envelope:

| Profile | Building core |
| --- | ---: |
| village | 40 |
| outpost, bandit, mirefolk, clash | 28 |
| mine | 32 |
| dragon, apex mine | 48 |
| rare route | 16 |

For each ordinary POI, construction scans the owner-valid columns of that
building core. Dry columns contribute their natural height. Planned-water
columns contribute a lower bound of water clearance plus one. The preferred
flat height is the lower median of dry natural heights, clamped into the common
`natural-max_cut .. natural+max_fill` interval when that interval is feasible.
If it is infeasible, the deterministic minimax midpoint of the conflicting
bounds is used. Water clearance is then applied as a final lower bound.

Only the building core is flat. Between the building-core edge and the
existing outer blend edge, one smootherstep collar returns to natural terrain.
The authored fitting width remains metadata for the later structure package
and water-platform audit. This is intentionally a
single-building/compact-camp foundation contract. WP13 may fit later city
pieces individually; this pass does not flatten a whole future city.

Evidence records the preference, feasible interval, minimax excess and maximum
core/collar cut and fill. Acceptance compares all 88 ordinary anchors on seeds
`0` and `4655649881628627392` against the pre-change source bytes and requires
lower aggregate and worst absolute core displacement without any owner escape.

## 3. Inland and coastal water

The public 20-value planner column tuple is unchanged. Its existing classified
depth scalar becomes the actual depth for that column.

Ordinary inland reaches vary their bed using the existing shared detail field:
depth 1 profiles stay depth 1; depth 2 profiles vary 1..3; depth 4 profiles vary
2..6; depth 8 profiles vary 5..11; depth 12 profiles vary 8..15. The variation
is deterministic and spatially continuous. A column in any named transition,
ford, bridge/causeway water operation or contact-face waterfall keeps its
authored profile depth. Thus transition beds, bridge clearance, ford elevation,
three-layer bed seals and two-node bank seals remain exact.

The four continental bays use the same field for depths 6..10 instead of one
constant eight-node plane. The coastal shelf retains its monotone 1..8-node
offshore slope and gains at most one node of bounded local variation away from
its land contact. Deep ocean and immutable dragon channels remain exactly 24
nodes deep.

Wet beds select deterministic patches from the biome's authored bed material,
sand, gravel and stone, with mud retained as the dominant swamp bed. Dry beach
shore selects mostly sand with sparse gravel patches. Deep-ocean and immutable
channel columns retain the authored biome bed unchanged. Surface selection uses
its existing integer lattice arithmetic and introduces no new hash or noise
construction.

The height session is the sole depth authority. `zones.lua` publishes that
depth in the existing tuple; R5/R6 planners and analytic settlement/seal paths
consume it unchanged. Evidence must cover transition and junction invariants,
wet-bank seals, cave clipping, two representative seeds and genuine before/
after timings over identical queries. A cost statement is made only from those
measurements.
