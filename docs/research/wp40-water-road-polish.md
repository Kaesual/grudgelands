# Water containment, hillside roads and banner faces — 2026-09-13

The user authorized this follow-up on fresh worlds after reviewing screenshots
from `test_mapgen`, seed `531802985935182545`. Branch
`wp40-water-road-polish` starts at `76576e3`. Classification: non-trivial
(map geometry, water safety and regression authority). No Rehearsal VM is used.

## Kezamba water escape

The camera at `(1862,72,1477)` faces the Troll capital's lake. Exact geometry
sampling found 226 wet/dry contacts where dry ground was below the neighboring
water surface: 221 owned by civic grading and five by `route_017`. For example,
water at `(1863,1492)` has surface y65 and bed y55, while the dry neighbor
`(1862,1492)` was cut to y62. In the real engine `(1862,65,1492)` became
`default:river_water_flowing`, reproducing the screenshot rather than merely
inferring a leak from the height field.

The capital reference solver treated water clearance as part of its soft
cut/fill interval. When the interval was infeasible, its midpoint could fall
below the required water level. The civic water minimum is now applied as a
hard floor after that compromise, just as the route-station floor is. Terrain
cut/fill excess remains reported rather than silently removing this constraint.

A second boundary closes subsequent cuts: dry land within the existing two-node
Manhattan seal neighborhood cannot be graded below the neighboring named-water
surface. A conservative hydrology-segment grid prunes distant columns; exact
classified neighbors decide the actual floor. The bound is applied after civic
and POI composition and enters the road solver before its grade constraints
are resolved. Authored fords retain their matching hydrology's exact bed and
one-step approach; a generic water bound must not dam a designed ford.
The planner's three-layer bed and two-node bank seals remain unchanged.
A per-constructor cache holds at most 4,096 bank queries, including dry results.
Exact coordinate tags prevent collision errors; all paths with authored fords
bypass it because their clearance depends on path and run. It adds no persistent
state and does not grow with exploration.

The 2026-09-17 shore-height amendment supersedes the lower-bound-only rule at
the first dry contact. Every first cardinal dry-land column beside exposed
surface water is now exactly level with that water surface; the wider named-
water seal, authored bridge/causeway/ford and route-deck grades, and culvert
floors remain unchanged because those surfaces are functional crossings or cut
rims rather than dry-land banks.

Actual checked runtime construction and dense shore sampling find zero low
wet/dry contacts in the tested Kezamba rectangle for both the reported seed
and seed 0. All route axes pass the existing final height/grade validation in
both constructions. The real engine then generates nine adjacent basin owners
plus one deep owner, finds stone at all four pinned shore witnesses and reloads
1,250 stored mapblocks with zero mapgen callbacks and equal persisted output.
This is a targeted basin regression, not a complete continent-wide liquid audit.

## Hillside roads and small pits

Each road run now prefers the lowest sampled pre-path land height across its
surface footprint, replacing the mean. This biases ordinary hillside roads
toward cutting into the slope, while the same exact pins, water clearances and
one-node grade constraints remain authoritative. No route is moved horizontally.

The isolated road-only comparison over all 139 paths of the reported seed lowers
the maximum fill on 72 paths, leaves 67 unchanged and increases none. The sum of
per-path maximum fill heights falls from 1,853 to 1,741 nodes; this is a sum of
maxima, not fill volume. The global maximum changes only from 70 to 69 nodes.
Cuts increase as intended: the sum of per-path maxima rises from 2,618 to 2,805,
while the global maximum remains 291. All 139 exact-pin and water-bound digests
match in that isolated comparison; all maximum steps are at most one node.

The archived road-only source was reconstructed from the verified baseline and
the isolated patch, then rerun. All 146 geometric rows match the first road-only
result after excluding construction time.

That identity statement applies to the road preference change alone. The
integrated water correction intentionally raises Kezamba's unsafe civic
reference and adds shore-related road bounds. High embankments imposed by
fixed endpoints or grade limits can remain; this modest change is not a general
route redesign or a universal cut/fill bound.

No independent smoothing was added for the small pits near `(-1013,54,958)`.
Their cause was not proven by the screenshot, and a separate correction to the
interpolated road collar would broaden the geometry changes. This respects the
user's request to handle that cosmetic item only if an isolated fix is simple.

## Banner rear face

The pinned engine mirrors X for the back face of a nodebox in
`reference_projects/luanti/src/client/content_mapblock.cpp:355–366`.
The banner atlas is opaque on columns 10..14, but its back face sampled the
transparent columns 1..5. Per-face textures now flip X for the rear and use an
opaque existing pole-color crop on the narrow top/bottom faces. There is no
new texture, mesh or runtime callback.

The regression loads the actual registered node, checks 3,072 face samples and
requires matching front/back artwork at the same world position. The original
node fails the opacity check. The shipped PNG's alpha matches the existing
ASCII texture generator; the final input manifest binds both the generator and
the pinned engine UV source in addition to the shipped texture.

## Validation, evidence and remaining limits

The [evidence directory](wp40-water-road-polish-evidence/) retains the actual
engine failure/success, source patch, shore rows, isolated road measurements,
static gates and final interpreter parity. Plain-5.1 parsing covers all own
production Lua and changed tool Lua; SETGLOBAL has no new global writes and the
five sweeps contain only existing prose/string matches. Fresh-server auditing
and reference pins remain clean.

The standard quality micro now includes the actual banner fixture and the
production low-edge preference, bank-neighbor, hard civic-water and ford helpers.
The final PUC/LuaJIT pair passes all 264 canonical rows with equal SHA-256
`936a0e440d7ef22bea9ceb76a59a4bb5d29ae3e206f693babb1a15118b845b22`,
preceded by a passing actual manifest constructor. An earlier final pair was superseded when the measured performance concern
led to the bounded cache; the archived pair binds the final cached bytes. No
intermediate PUC development suite was run. Standalone interpreter equality does not replace the user's real
fallback-engine or GUI tests. R8 remains open.

Performance controls use the same ten-owner seed-0 engine workload. Combined
planner/writer time was 6.50 seconds before, 7.74 seconds on the first corrected
run (overlapping compact quality checks), 6.96 seconds on the uncached repeat
and 6.80 seconds with the final bounded cache. These are single runs, not a
throughput population or proof of a precise regression percentage. The fixes
may still add some work; this package does not claim a speedup.

Full output is byte-identical with and without the cache on both engine fixtures:
5,120,000 voxels each for seed 0 and the reported seed. Final cached shore scans
also find zero low contacts for both seeds. Engine archives bind their source
snapshots; the final parity archive binds shipped files, tools and design inputs.

## Calibration and runtime test

Coordinator/water implementation: GPT-6 session identity. Bounded road and banner
implementation: inherited agent session identities. Independent reviewer:
`/root/gravewood_review`, visible GPT-6 session identity, no implementation
ownership in this package. Final independent review: 0 Critical / 0 High /
0 Medium / 0 Low, zero review fix rounds; elapsed wall time is unknown. The
[evidence receipt](wp40-water-road-polish-evidence/review.md) records the verified
inputs and acceptance limits.

After syncing main, create a fresh world with seed `531802985935182545`.
Revisit `(1862,72,1477)` and the nearby lake shore, then compare hillside roads
at `(1315,75,1435)` and `(1580,104,1540)`. Walk a crossing and a ford if encountered.
At Gor Drazhak `(0,94,1500)`, inspect the banner from both sides and above.
Restart once and revisit the lake. Report errors from debug.txt or remaining
water escape; ordinary road walls may remain where required by the route grade.
