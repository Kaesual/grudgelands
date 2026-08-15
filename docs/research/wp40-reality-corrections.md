# WP40 T2 Reality corrections R7--R19

Status: **evidence history. Not a contract.**

Each entry records one correction to the compiled-geometry Source: what a
prototype, review or compiler reproduction exposed, why the alternatives were
rejected, and what evidence was retained. The rules these corrections
established are the authority in
[wp40-source-authority.md](wp40-source-authority.md); the process that governs
them is the reality-check correction rule in
[wp40-engineering-brief.md](wp40-engineering-brief.md) section 6.5. This file
is why, not what.

Every statement below is as of the correction that recorded it. That includes
status claims, not only line numbers: where an entry says the 4,096-candidate
pool "has not been measured and must be generated anew", that was true when
written. It was measured on 2026-08-16 (commit `527b3a5`, artifact
`5b5241b3...`), and it reproduced the same four winners as the pre-R16 pool.
Line numbers likewise are as of the recording commit, not of current HEAD. The harness files were renumbered on
2026-08-15; locate cited code by symbol name rather than by line.

Extracted from the engineering brief 2026-08-15, verbatim. The brief had grown
from 134 KB to 314 KB in three days, almost entirely through these entries.

Their classification and the bound on what remains are in
[wp40-t2-degeneracy-completeness.md](wp40-t2-degeneracy-completeness.md).

---

**R7--R9 corrected Stage-1 source evidence (not T2b or 32-seed
completion).** The next checksum-covered replacement source is
`f38332e77ada4bf8b3215bfc79da7e5822beb6f6269fbd3679b089ede508e188`.
Its boundary-displacement policy checksum is
`913b0d4184a9a51125413f69621e78e4643c84d2af545362b308f56ad01ba1a4`,
world-partition policy checksum is
`eb70c52d82fbb0d93ab53cf2d6d276b59f69c4fbf387b56311acfd9a0820c1e2`,
and extreme-selector policy checksum is
`3c87964998f48fc71d92aa361c0584cd6dc0ddd04ccc8992214775df138c132a`.
The preceding `5f0cd9...` source and its policy hashes remain historical
evidence for the superseded pre-R7 (R1--R6) state. The replacement keeps the 38 zones,
61 land edges, original 57 routes and all seeds, cases and thresholds. Stage 1
covers exact normal, damping, clip, component, reraster, reversal, equality,
rational-distance and selector-identity mutations/KATs. Seed-zero and full-
corpus displaced geometry, partition, attachment, topology, capacity, supply
and performance remain mandatory Stage-2/release work and are not claimed
here.
The executable R7 source policy begins at the sole boundary-displacement
record ([boundary policy](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):286),
while R8/R9 share the one partition record
([partition policy](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):585).
The independent Stage-1 harness exercises the displacement pipeline
([R7 oracle](../../tools/wp40/t2_source_test.lua):1794), classification
precedence ([R8 oracle](../../tools/wp40/t2_source_test.lua):2249), exact coast
inheritance ([R9 oracle](../../tools/wp40/t2_source_test.lua):4319), and the
source-identity selector overlap rule
([selector KAT](../../tools/wp40/t2_source_test.lua):4555). The static audit
pins all four current checksums and bans a floating square-root path
([checksum audit](../../tools/wp40/t2_source_audit.sh):208;
[floating-square-root ban](../../tools/wp40/t2_source_audit.sh):254).

**R11 Bay-bank Reality correction (Stage 1 only; Stage 2 remains pending).**
The first T2b face compiler demonstrated that the Base-Bay/Wing classifier is
a water-membership authority, not an ordered polygon shoreline. All eight raw
land-edge incidences at `land_001:to`, both ends of `land_004`,
`land_007:from`, `land_010:to`, both ends of `land_013` and
`land_016:from` are strict planned water. Substituting literal Base-Bay arc
endpoints therefore left different terminal coordinates on the edge and face,
and concrete face closure failed. A continuous rational contour would require
a doubled-lattice polygon/schema change; selecting dry boundary columns by an
unqualified Moore walk can be thick, branched or tied. Neither is accepted by
the current integer-station face contract.

The focused correction replaces every literal Bay-shore component with exactly
20 coordinate-free `bay_bank_components`, five per Bay. Each closed record
contains one component ID, Bay ID, canonical direction, water-right side, two
structured terminals and their one face-arc incidence; it contains no point,
control, width or copied geometry. The only terminal variants are aperture-dry
before/after, one of the eight declared land-edge endpoint transitions, and a
signed Wing-J tail. `face_arcs` project their ordered source references exactly
from their ordered perimeter-span, Bay-bank or fixed-literal components, and
the component kind must agree with the arc kind. Holy and island arcs remain
the only literal face components. Terminal resolution and component
materialization each happen once. Consumers bind the same IDs and byte-exact
canonical x/z encodings; alias-free defensive payload copies are permitted,
but no consumer may retrace, snap, infer a connector or copy a private shape.
The executable policy and roster are the checksum-covered
[Bay-bank policy](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):637
and [20 component records](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):1399.

The aperture terminal is its adjacent dry station found by coordinate in the
deduplicated final authored/declared perimeter order. This Bank-only terminal
order is separate from, and changes none of, the canonical mouth-aperture
membership indices/payload or Attachment tie. A land-edge terminal is the
once-resolved terminal of the final clipped dry edge raster. R11 originally
required the raw retained endpoint itself to be a candidate and recorded an
unretained exploratory offset-zero probe. R16 below supersedes that claim after
the fixed extreme slot 19 produced a strict-dry noncandidate endpoint next to
same-Bay water only diagonally. The replacement is the checksum-covered direct-
candidate-or-same-Bay-diagonal-elbow authority, never an inward scan, arbitrary
shift or unowned retained dry tail. The
previous half-edge at an edge start is the immediately adjacent retained
final edge station away from the resolved endpoint; at an aperture it is the next dry perimeter
station away from the aperture in the authored order. Every start half-edge
must be 8-connected and candidate-valid, but supplies rotation only and has no
water-side requirement.

A general Bay-bank candidate is a column classified dry by the final common
classifier, including permitted dry perimeter equality, with a cardinal
neighbour owned as final water by the same Bay's Base or Wing union. Search is
limited to that Bay's Base/Wing bounding-box union expanded by one and clipped
to the final mainland footprint. The directed state is
`(previous,current,seen directed-state set)`. Its fixed clockwise neighbourhood
is E, SE, S, SW, W, NW, N, NE, rotated immediately after the
current-to-previous direction clockwise for water-left or counterclockwise for
water-right. A successor must be an unseen 8-neighbour candidate, not
`previous`, and its proposed materialized step `current -> successor` must have
at least one cardinal same-Bay water neighbour on the declared strict cross
side; cross zero is not a side witness. In the fixed Moore order, select the
first successor from which the already-resolved target has a complete valid
path; later reachable successors are permitted. Each reachability DFS counts
every pushed frame including its start and rejects above eight times the
finite envelope-column count; stack depth is at most the envelope-column count
and the main trace is at most that count minus one steps. No reachable
successor, a repeated state or column, X-cross, foreign/nonreferenced water
contact, malformed half-edge, undeclared endpoint or any bound exhaustion
rejects. Reverse output is only the byte-exact reverse of the once-selected
canonical chain and never retraces.

Pure candidate tracing still cannot reach a Wing terminal: every one of the
eight zero-width `J` columns is dry and has zero of four cardinal same-Bay
water neighbours. Giving the Wing nonzero terminal width would change the
accepted water mask, and a generic Bresenham connector would create a second
geometry authority. Independent per-side `K -> J` Bresenham tails were also
rejected: six of eight Wings overlapped before `J` and crossed the wrong
declared side. R11 instead selects `K` independently of the Moore trace and
solves both Wing sides jointly.

For each signed side, enumerate all final-dry columns in the referenced Wing
box which have a cardinal neighbour in that Wing's own strict-interior water,
satisfy `0 <= N < L`, and have strict negative or positive
`X = cross(J-A,P-A)` as declared. Existing Wing dot/cross bounds guard
`abs(N)`, `abs(X)` and every product below `2^53`; greatest exact `N`, then
least `(x,z)`, selects `K`, and an empty set rejects. This selection is
trace-independent and therefore supplies a noncircular target even for a
Wing-to-Wing head-bank component.

From the negative and positive `K`, build the two complete finite
8-neighbour distance-layer DAGs of dry strict-side columns whose Chebyshev
distance to `J` decreases by exactly one per edge. Select the lexicographically
least *complete pair*, negative sequence before positive sequence, comparing
coordinates by `(x,z)` and making a shorter exact prefix less, only after
filtering for interior-disjoint paths, distinct `J` predecessors, strict side
outside the common `J`, and no intra- or inter-path diagonal X-cross. This is
a complete pair search/DP, not separate greedy walks. Each path has at most
`ceil(isqrt(L)) + 1` stations, and the current source requires
`Chebyshev(K,J) <= 4`. An exploratory unretained 8-Wing design probe reported
negative/positive station counts `4/3, 4/5, 5/4, 3/4, 2/3, 5/4, 4/5, 5/4`
in source Wing order, with only `J` shared and distinct predecessors there.
Those values establish design feasibility only. Stage 2 must reproduce and
retain the exact K selection, pair paths, counts, predecessors and rejection
mutations before they become acceptance evidence.

A negative Wing terminal is always the component start and emits the selected
tail byte-exact as `J -> K`; its final two stations become Moore
`(previous,current=K)` as a rotation-only anchor; its first outgoing Bank step
passes the water-right test. A positive terminal
is always the component end: `K` is the independently fixed Moore target, the
selected `K -> J` tail is appended with the join deduplicated, and reversal
never reruns selection. Both tails are chosen before any component trace. This
also preserves the common dry `J` identity across the Wing and its two
incident land edges without creating a new land adjacency.

Stage 1 now validates the closed 20-record roster, all three terminal schemas,
their incidence and exact source projection, the 20-to-20 component use, the
eight edge and all Wing-J symbolic identities, the complete 38-face abstract
cycles, forbidden copied controls and targeted malformed-field/type/mutation
cases. Its pre-H55 R15 source checksum was
`0bbdb29abf46b07bc9d57327e5d9faa513df80a728f4d46bfa3e6c40a21ad16b`;
the world-partition policy checksum is
`e5c17a5a084b0f13a5779b7c84aa823c8dae64e711020be5f46087db80a24693`.
The retained Stage-1 bindings are the
[exact roster and terminal validation](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):2526,
[component incidence and central identity](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):3032,
[record/component mutation KATs](../../tools/wp40/t2_source_test.lua):5442,
[policy mutation KATs](../../tools/wp40/t2_source_test.lua):5840, and
[R11 static audit](../../tools/wp40/t2_source_audit.sh):34.
These are source/schema evidence only. T2b must still materialize the exact
chains for all 32 seeds; prove every transition, reverse, branch/X/repeat and
edge offset gate; consume each chain by common ID/bytes; and prove exactly one
water or dry-face owner per mainland column plus all 38 concrete faces closed,
counterclockwise and simple. No Stage-2 or final WP40 completion claim follows
from R11.

**R12 Bank trace Reality correction (Stage 1 policy; Stage 2 remains
pending).** The first retained T2b materialization exposed two assumptions that
the R11 source had frozen too strongly. For Elandor-west Hearthpine the
current authored Bank start anchor is
`previous=(-1341,-2920), current=(-1340,-2921)`; the first materialized Bank
step goes to `(-1340,-2920)`. An earlier canonical-order anchor diagnostic is
superseded and is not current geometry evidence. The resolver had followed the
then-frozen canonical aperture order exactly; the error was the authority, not
a compiler flip. Mouth-aperture membership, indices and payload therefore stay
canonical, while Bank aperture terminals use the separate final authored/
declared perimeter order. The start anchor is checked only for 8-connectivity
and candidate validity and supplies rotation only. Water-right begins on the
first actual `current -> successor` Bank step.

The same run then found a genuine convergence branch in that component:
after `previous=(-1320,-2833), current=(-1319,-2832)`, both
`A=(-1319,-2831)` and `B=(-1320,-2831)` can reach the fixed target; the A path
enters B one step later. Rejecting multiple reachable successors is therefore
not a topology proof. R12 evaluates successors in the checksum-covered Moore
order and selects the first with a complete valid suffix. The complete
reachability search, not discovery or pair order, decides eligibility. Each
per-successor DFS counts every pushed frame including the start, has the exact
cap `8 * envelope column count`, and has stack depth at most the envelope
column count; the selected main trace has at most `envelope columns - 1`
steps. Reverse consumption only reverses the selected bytes.

An exploratory, unretained Seed-0 audit of all 20 components found 79 states
with multiple admissible successors, 78 with two terminal-reachable choices,
maximum two reachable choices, 47,296 total DFS frame visits, maximum 775
pushed frames in one call, and no terminal/repeat/X/foreign/water-side failure.
Those numbers justify the finite policy but are not acceptance evidence.
Stage 2 must retain the full 20-component/32-seed oracle, including the
Hearthpine first-divergence fixture, frame/stack/trace bounds and mutations.
The retained Stage-1 authority is the
[R12 policy](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):644;
its rollback mutations begin at the
[partition-policy KATs](../../tools/wp40/t2_source_test.lua):5856.

**R13 digital-junction Reality correction (Stage 1 base proof; Stage 2 final
proof remains pending).** After R12 materialized all Bay banks, the first
Ashenward face was non-simple because two incident boundary rasters shared a
one-edge prefix beyond their declared junction. A complete exploratory audit
of all 38 junctions and 102 unordered incident-edge pairs found exactly four
Seed-0/base cases and no opposing diagonal X-cross:
`land_032/035` share `(-1399,-1100)` after `J=(-1400,-1100)`,
`land_033/036` share `(401,-1100)` after `J=(400,-1100)`,
`land_038/041` share `(-1399,1100)` after `J=(-1400,1100)`, and
`land_039/042` share `(401,1100)` after `J=(400,1100)`. The former Stage-1
continuous-control planarity gate allowed a common endpoint and did not prove
pairwise digital raster separation.

R13 keeps all original 57 land-edge control arrays and route source/payload
unchanged. Four closed coordinate-free `junction_departure` records bind the
`from` endpoint of `land_035`, `land_036`, `land_041` and `land_042`. Given
that endpoint `J` and its adjacent original authored control `C`, both axis
deltas must be nonzero and
`D=J+(sign(C.x-J.x),sign(C.z-J.z))`. The exact derived stations are
`(-1399,-1099)`, `(401,-1099)`, `(-1399,1099)` and `(401,1099)`. The compiler
selects each sign by ordered coordinate comparison without subtracting the
coordinates, requires the adjacent source control inside the exact mainland
frame, and checks each `J +/- 1` sum in the safe integer range. It then
copies the control array, inserts fixed zero-jitter `D` at position two and
passes only that effective copy through the existing displacement/reraster
pipeline. It does not mutate source controls, add a second displacement or
change a route. Consequently those four compiled boundary rasters are not
claimed byte-identical to the pre-R13 result.

Stage 1 now rerasterizes the effective `C=0` controls and retains the exhaustive
102-pair proof: after orientation from each common `J`, only `J` may coincide,
with no shared nonterminal station/segment and no opposing diagonal X-cross.
Missing, duplicate, malformed, nonincident, nonendpoint, nondiagonal, wrongly
derived or overlapping departures reject; there is no shared trunk, snap,
connector or joint-ceiling retry. Stage 2 must run the same exhaustive proof on
every selected R7/effective-control displacement raster across all 32 seeds,
after its final canonical reraster but before R11 planned-water clipping or
perimeter-attachment selection. It must then prove the separate
post-partition topology and all 38 faces closed, counterclockwise and simple
before a new Source/Compiler freeze.
The retained R13 bindings are the
[coordinate-free records](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):1250,
[Stage-1 exact4 and 102-pair validator](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):2184,
[independent old/effective 102-pair oracle](../../tools/wp40/t2_source_test.lua):1528,
[targeted mutations](../../tools/wp40/t2_source_test.lua):5214, and
[static audit pins](../../tools/wp40/t2_source_audit.sh):258.
The pre-H55 boundary-displacement policy checksum was
`d36ce91c175cd7949385850c11f4e17f5480561ffb00f9a891d524cb92e236bd`.

**R14 junction-stage Reality clarification (documentation authority; compiler
acceptance pending).** The first post-clipping gate exposed that R13's phrase
"selected final raster" had conflated the final raster of the displacement
stage with the later post-partition land-edge payload. The exhaustive R13 gate
is pre-partition 38/102: all 38 authored `relief_junctions` and all 102 unordered
incident-edge pairs are checked on the selected displacement rasters before
any R11 clip. The source roster is retained at
[relief junctions](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):1196.

Post-partition H33 uses three disjoint topology categories. Four degree-two
source junctions are fully dissolved by Bay water:
`(-1050,-2250)` (`land_001:to`, `land_004:from`), `(+950,-2250)`
(`land_004:to`, `land_007:from`), `(-970,+2260)` (`land_010:to`,
`land_013:from`) and `(+1020,+2250)` (`land_013:to`, `land_016:from`). Their
four old edge pairs do not survive; the eight incidences instead use the
once-resolved direct-candidate-or-same-Bay-diagonal-elbow transition identities
in the [Bay-bank](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):1399
and [transition records](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):1430.
The other 34 relief junctions retain exactly 98 ordinary pairs. The eight
[perimeter attachments](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):1313
are separate endpoint authorities outside the relief-junction roster and keep
their final edge/perimeter/span identity gates. A mixed transition/ordinary
junction, an attachment endpoint that also claims relief-junction authority,
or any category/count drift rejects as a new Reality case. All 38 assembled
faces must still be closed, counterclockwise and simple. This clarification is
authority only; reproducible compiler acceptance for the categorized final
gate remains pending.

**R15 Wing-tail dry-wedge Reality correction (Stage-1 policy and source KAT;
compiler acceptance pending).** R11's joint-tail solver proved structural
separation but then chose the lexicographically least structural pair. That is
not enough to prove that the closed head wedge is water-owned: the old choices
left 15 non-tail integer columns dry inside four southern and two northern
wedge analyses. R15 keeps the existing K sets, distance-layer DAGs and
structural constraints, enumerates every structurally valid pair, and applies
one additional exact analysis before lexicographic selection.

For a structural pair, form an analysis-only polygon by following the negative
tail `K- -> J`, reversing the positive tail to follow `J -> K+`, and closing
with the direct exact chord `K+ -> K-`. The polygon must be simple and have
nonzero signed area. Set `R = 1 + max(Chebyshev(K-,J), Chebyshev(K+,J))`; scan
the inclusive `J +/- R` integer box and retain every column whose exact polygon
class is inside or on the boundary. Only coordinates present in either exact
tail, including `K-`, `K+` and `J`, are exempt. Every other retained column must
be strict water of that referenced Wing. The chord is a rational analysis edge:
it is never rastered, materialized, serialized or used for ownership. Choose
the lexicographically least wedge-valid pair under the existing negative-path-
then-positive-path order. Multiple wedge-valid pairs are legal; none rejects.
The current hard bound is `R <= 5`, and reversal remains only the byte-exact
reverse of the once-selected tails. The checksum-covered authority begins at
the [Wing-wedge policy](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):670.

The retained Stage-1 golden is keyed by Wing ID while iterating the existing
source Wing order. Positive sequences below are shown in their stored
`K+ -> J` direction; the polygon uses their byte-reverse.

| Wing | raw / wedge / selected raw rank | R | len− / len+ | old dry → new dry | negative `K- -> J` | positive `K+ -> J` |
|---|---:|---:|---:|---:|---|---|
| `bay_wing:elandor_west:left` | 4 / 1 / 1 | 4 | 4 / 3 | 0 → 0 | `(-1397,-1900),(-1398,-1900),(-1399,-1900),(-1400,-1900)` | `(-1398,-1901),(-1399,-1901),(-1400,-1900)` |
| `bay_wing:elandor_west:right` | 18 / 1 / 10 | 5 | 4 / 5 | 1 → 0 | `(-403,-1901),(-402,-1901),(-401,-1901),(-400,-1900)` | `(-404,-1900),(-403,-1900),(-402,-1900),(-401,-1900),(-400,-1900)` |
| `bay_wing:elandor_east:left` | 18 / 1 / 2 | 5 | 5 / 4 | 1 → 0 | `(404,-1900),(403,-1900),(402,-1900),(401,-1900),(400,-1900)` | `(403,-1901),(402,-1901),(401,-1901),(400,-1900)` |
| `bay_wing:elandor_east:right` | 4 / 1 / 1 | 4 | 3 / 4 | 0 → 0 | `(1398,-1901),(1399,-1901),(1400,-1900)` | `(1397,-1900),(1398,-1900),(1399,-1900),(1400,-1900)` |
| `bay_wing:kragmar_west:left` | 2 / 1 / 2 | 3 | 2 / 3 | 1 → 0 | `(-1399,1901),(-1400,1900)` | `(-1398,1900),(-1399,1900),(-1400,1900)` |
| `bay_wing:kragmar_west:right` | 18 / 1 / 17 | 5 | 5 / 4 | 4 → 0 | `(-404,1900),(-403,1900),(-402,1900),(-401,1900),(-400,1900)` | `(-403,1901),(-402,1901),(-401,1901),(-400,1900)` |
| `bay_wing:kragmar_east:left` | 18 / 1 / 9 | 5 | 4 / 5 | 4 → 0 | `(403,1901),(402,1901),(401,1901),(400,1900)` | `(404,1900),(403,1900),(402,1900),(401,1900),(400,1900)` |
| `bay_wing:kragmar_east:right` | 18 / 1 / 17 | 5 | 5 / 4 | 4 → 0 | `(1396,1900),(1397,1900),(1398,1900),(1399,1900),(1400,1900)` | `(1397,1901),(1398,1901),(1399,1901),(1400,1900)` |

The exact former dry vectors were Elandor-west-right `(-402,-1901)`,
Elandor-east-left `(402,-1901)`, Kragmar-west-left `(-1399,1900)`,
Kragmar-west-right `(-402,1899),(-403,1900),(-402,1900),(-401,1900)`,
Kragmar-east-left `(402,1899),(401,1900),(402,1900),(403,1900)`, and
Kragmar-east-right `(1398,1899),(1397,1900),(1398,1900),(1399,1900)`;
the two remaining Wings had none. The new vector is zero for every Wing.

R15 also corrects the raw dry-face multiplicity statement. Outside final
planned water, at least one raw dry face is required; multiplicity is legal
only on a declared shared edge or junction, where the half-open rule chooses
the owner. Inside final planned water there is no raw dry-face requirement,
because water precedence owns the column. The retained bindings are the
[exact policy validator](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):1481,
[independent eight-Wing oracle and goldens](../../tools/wp40/t2_source_test.lua):806,
[policy mutations](../../tools/wp40/t2_source_test.lua):5868, and
[static pins](../../tools/wp40/t2_source_audit.sh):80.

An exploratory plain-PUC script under `/tmp` first established feasibility at
100 structural pairs, eight wedge-valid pairs and 15-to-zero dry columns. That
temporary output is not acceptance evidence. The retained repository source
KAT now proves the same Stage-1 arithmetic, including long-chord dry/pass,
self-intersection, no-valid-pair and multiple-valid-pair mutations. The first
repository compiler run subsequently reproduced all eight rows and exact
selected bytes. That did not freeze Partition: the later H55 closure witness
below reopened Source before the exhaustive whole-footprint gates. No 32-seed
or final WP40 acceptance claim follows from the R15 run.

**H55 fixed-Holy mainland-closure Reality correction (Stage-1 correction;
compiler refreeze pending).** The post-R15 perimeter-equality gate found
`(-2392,-251)` on Elandor's final closing segment, while the declared Holy
contact edge is fixed at `z=-250`. The source polygon's 27th base segment was
geometrically the same boundary as the six zero-displacement Holy-contact land
edges, but R7 had treated all mainland stations as movable coast. Its earlier
no-jitter roster froze only the authored controls and their neighborhoods, not
the complete 5,001-station edge. Therefore the former R15 Source freeze was
wrong: the ordered-component claim and final R7 raster could disagree by one
column. A compiler-owned snap, replacement or owner fallback is forbidden.

Each planned-mainland source row now has one structured `r7_fixed_closure`
containing only six ordered directed land-edge references. Elandor resolves
`land_048` through `land_043`, all reverse; Kragmar resolves `land_054` through
`land_049`, all reverse. No record stores a coordinate or an authored perimeter
segment index. The sole route raster materializes each referenced max-zero edge
and concatenates the six byte sequences with consecutive join deduplication.
Exactly one complete authored perimeter base segment must equal that full union;
the current source has 26 other segments. For every equivalent closed control
rotation or reversal the resolver must geometrically rediscover the match, then
tag that authored segment membership before canonical calculation. It never
matches arbitrary points merely because they lie on the fixed union.

Tagged closure rows pass through the ordinary R7 local-scalar loop with
`local_scalar_q=0`. The two closure-to-ordinary-coast ring joins are
independently zero under the existing Holy-corner no-jitter rule; all five
internal six-edge union joins are closure-tagged zero rows. The one existing record-wide topology
ceiling `C`, candidate validity and sole final reraster still cover the complete
closed record: displaced 26-segment coast plus fixed closure. The selected
closure must be byte-identical to the same six-edge union in declared perimeter
order. Its refs project exactly to the existing
`ordered_outer_components` suffix; the 18 Coast-span source definitions and the
22-component coast-source roster are unchanged. There is no post-raster splice,
second ceiling, second noise query, snap or ownership repair.

Stage 1 independently resolves both 5,001-station unions and the unique full
source segment under forward, rotated and reversed definitions. It verifies
identical canonical station/scalar bytes with all union rows zero and rejects
ref reorder, direction flip, deletion, duplication, wrong or moving edge,
changed union geometry, split/no-full and duplicate-full source segments,
unknown fields, Holy-row scope and ordered-component projection drift. The
retained 18-row source-span-definition hash is
`bf7880fea20624378a8c177e513af637b61b8f169be6cf1e03a45a86fe538534`.
That metadata hash is not final Coast-geometry evidence. The first compiler
rerun must separately bind both pre/post-H55 record-wide `C` values and the full
selected bytes of all 18 Coast components, prove only the closure changed, and
rerun the complete perimeter/partition/face gates before a new freeze.

The provisional H55 source checksum is
`9516083203f23eb0f90b3cd87bd95d28483e8420ec0718e68831ebf175a9cc68`;
its boundary-displacement policy checksum is
`3d1e6e39f5c2f6f140f40277ebe2af8886a9a58cf4679a7804e05ee354b3c140`.
The world-partition checksum remains
`e5c17a5a084b0f13a5779b7c84aa823c8dae64e711020be5f46087db80a24693`.
The retained bindings are the [R7 closure policy](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):346,
[structured refs](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):1264,
[closed resolver validator](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):703,
[independent resolver](../../tools/wp40/t2_source_test.lua):2097,
[mutations](../../tools/wp40/t2_source_test.lua):4971,
and [static audit](../../tools/wp40/t2_source_audit.sh):219. This is Stage-1
source/schema evidence only; compiler refreeze and the final 32-seed result
remain pending.

**R16 Bay-edge terminal Reality correction (Stage-1 authority and retained
Source oracle; compiler acceptance pending).** After the H55 compiler gates had
closed, extreme selector slot 19 (`18446744073709551615`) reached
`bay_bank:kragmar_west:stillgrave` with the old start half-edge
`(-1141,2241) -> (-1140,2241)`. The latter column was strict dry and inside the
finite Bay envelope, but was not a Bank candidate: its cardinal same-Bay and
foreign-water bitsets were both `0000`. The immediately discarded provisional
`land_010` station toward the Bay was `W=(-1139,2242)`, exactly diagonal from
`E=(-1140,2241)` and final water owned only by `bay_kragmar_west`. Both exact
orthogonal elbows were strict-dry same-Bay candidates:
`(-1139,2241)` and `(-1140,2242)`. A private compiler shift would contradict
the frozen terminal authority, while rejecting this seed would make the
already-selected extreme corpus non-compilable. R16 therefore consciously
reopens Source and replaces the false all-seed offset-zero claim.

The source now contains exactly eight coordinate-free `bay_edge_transitions`
rows. Each row binds the Bay, edge ID and endpoint plus its two incident Bank
component IDs in existing Source component order; it contains no station,
control, polygon or copied shape.

| Transition | Bay | Incident Banks in Source order |
|---|---|---|
| `land_001:to` | `bay_elandor_west` | Hearthpine, Copperfell |
| `land_004:from` | `bay_elandor_west` | Goldmead, Dawnmere |
| `land_004:to` | `bay_elandor_east` | Dawnmere, Goldmead |
| `land_007:from` | `bay_elandor_east` | Starbough, Silverleaf |
| `land_010:to` | `bay_kragmar_west` | Stillgrave, Mournfen |
| `land_013:from` | `bay_kragmar_west` | Redtusk, Sunscar |
| `land_013:to` | `bay_kragmar_east` | Sunscar, Redtusk |
| `land_016:from` | `bay_kragmar_east` | Raincall, Kapok |

The sole resolution policy is
`direct_candidate_or_same_bay_diagonal_elbow_v1`. Let `E` be the declared
first or last retained dry provisional edge station. If `E` is a final
same-Bay candidate, select it unchanged. Otherwise all of the following are
mandatory: `E` is final strict dry; none of its four cardinal neighbours is
same-Bay or foreign planned water; `W` is the immediate adjacent discarded
provisional station toward the Bay; `E -> W` is an exact diagonal step; and
`W` is final water owned only by the referenced Bay's Base/Wing union. Form the
two orthogonal elbows `(W.x,E.z)` and `(E.x,W.z)`. They must be distinct,
strict-dry in-footprint same-Bay candidates. The least `(x,z)` wins. A missing,
mixed or duplicate row, wrong Bay/edge/Bank incidence, failed predicate,
foreign water, invalid elbow, repeat, X-cross or final edge validation failure
rejects with no fallback.

The selected elbow is inserted as the terminal control after provisional
prefix/suffix selection and before the existing sole final edge reraster. It is
not a post-raster connector, append or snap. The edge and both declared Banks
consume one once-resolved terminal station ID and byte-exact x/z; alias-free
defensive copies may carry that identity without a second resolution. The
immediately adjacent final edge station away from the terminal is `previous`
(`E` itself in the diagonal case), while the resolved candidate is `current`.
The anchor remains rotation-only; water-right begins on the first emitted Bank
step. `E`, `W` and the derived elbow are resolved strictly after the immutable
extreme-scalar records and never enter or change their identities or values.
The complete 4,096 pool and selected four winners are generated once, only
after the R16 Source freeze; there is no pre-R16 pool or before/after winner
claim.

Stage 1 closes the seven authored fields (plus generated `numeric_id`) and
projects all 16 embedded land-edge terminal incidences from the 20 Bank records.
It requires exactly eight unique edge/endpoint keys, two distinct same-Bay
Banks in Source order and exactly one start plus one end terminal per row. Its
targeted mutations independently reach field, incidence-array, exact-contract,
projection, reference, Bank-incidence and terminal-side diagnostics. The
retained Source oracle does not load the Partition or raster implementation: it
reconstructs max-seed `land_010` and both final R7 mainland perimeters from
Source and T1 arithmetic, including H55 closure, orientation, final footprint
equality and aperture-only Base water. It independently builds the expanded
Base/Wing union boxes, counts the final-footprint-clipped Kragmar-west envelope
and runs its own water-right Moore/DFS trace with exact `8N`, `N` and `N-1`
frame, stack and main-step caps. Outside-envelope, outside-footprint and
synthetic foreign-water candidate corruptions reject. It freezes edge `C=3`,
Elandor/Kragmar perimeter `C=3/2`, `N=1,132,870`, `E=(-1140,2241)`,
`W=(-1139,2242)`, selected `T=(-1140,2242)`, the 453-station/451-step Mournfen
path, one reachable-branch decision, 24 total pushed reachability frames
including both per-call start frames, maximum call/stack `23/23`, and path SHA-256
`1f528c5671fe69254049b03c3ef5047093bb743f9ddcfdb3967b73a000740cca`;
the Stillgrave ordering begins at `(-1141,2242)`. These are retained Stage-1
Reality witnesses, not compiler or 4,096-seed acceptance.

The provisional R16 source checksum is
`27c40804ad83b22d3c9e88bc48fddfdc4e44c7d2e8d78d1c6d28792691b59940`;
the boundary-displacement checksum is
`888037c92c4176cf55f8638452fcd92e66fe2b5fd909f5e3a3d2e574b303dd1c`;
the world-partition checksum is
`4ad284848e09cdbcdb7c578a3e5b8dd30b48d6180dc7c3b6af7a2a93b5bb69f2`.
The retained bindings are the [structured transition
roster](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):1430,
[closed Stage-1 projection](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):2587,
[independent Slot-19 oracle](../../tools/wp40/t2_source_test.lua):2341,
[targeted mutations](../../tools/wp40/t2_source_test.lua):5355 and
[static audit](../../tools/wp40/t2_source_audit.sh):57. The R16 Source/Reality
candidate is refrozen only after the Source/PUC-5.1 gates and the compiler's
Slot-19/all-eight transition gates reproduce these pins. Only then may the one
complete 4,096-selector run and selected-four Whole/no-fallback run execute
against that immutable commit/archive pin. Those later measurements do not
reopen or silently mutate their input; any new Reality defect is recorded and
reviewed separately. T2/32-seed and WP40 completion remain pending.

**R17 raw-Bay-notch Reality correction (coordinate-free Source authority;
compiler acceptance pending).** The first final max-u64 whole-footprint pass
after R16 reported three dry degree-one leaves and no overlap or invalid
intersection: Elandor-west `(-775,-2349)` with sole dry cardinal connector
`(-774,-2349)`, Elandor-east `(887,-2036)` with connector `(886,-2036)`, and
Kragmar-west `(-1121,2220)` with connector `(-1122,2220)`. Each leaf had the
other three cardinal and all four diagonal neighbours in raw planned water,
each with exactly one actual raw-water Bay owner. Kragmar-east had no leaf.
An owner repair, face inference, Bank-path tie or point-specific snap would be
downstream of the defect and was rejected.

R17 upgrades `world_partition` to
`face_partition_with_bay_capsule_water_v3` and defines
`single_pass_same_bay_raw_mask_degree_one_notch_v1` in the checksum-covered
[partition policy](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):585,
with the complete closed-field contract enforced by the
[Stage-1 validator](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):1350.
The input is the immutable
raw final Bay mask after displaced Base membership, closure Wings, final
footprint clipping and mouth-aperture equality precedence, but before any
fill. For each Bay, enumerate every integer `P` in the deduplicated union of
its expanded Base-segment and two Wing boxes. `P` qualifies only when `P` and
all eight neighbours are strict final-mainland interior, `P` is globally raw
dry, exactly three cardinal and all four diagonal neighbours are raw water
owned only by that Bay, and the remaining cardinal neighbour is globally raw
dry. A foreign/multiple water owner or a second qualifying Bay rejects. All
envelope expansion and neighbour `+/-1` arithmetic is checked inside the safe
integer range; the underlying exact mask predicates retain their existing
product guards.

Every qualification reads the same raw mask. The compiler collects the unique
`(Bay,P)` pairs and unions them simultaneously once; it never iterates or lets
a filled column enable another decision. Each filled `P` becomes planned water
of its qualifying Bay and uses that Bay's existing exact rational Base-owner
projection. It does not copy a neighbour owner and introduces no rank, tie,
snap or fallback. Each compiled Bay carries the policy ID, exact count and one
lexicographically `(x,z)` sorted dense fill array. That once-materialized
payload is consumed byte-for-byte by the final classifier, R16 transitions,
Bank candidates/traces, Faces, partition and water ownership; consumers do not
re-enumerate from a face or path.

The evaluation DAG is binding. Extreme-scalar record identities and values,
including the fixed 4,096 selector inputs, are upstream and unchanged. The raw
mask is materialized next; R17 produces final planned water; then each R16
transition is selected exactly once against that final mask; Banks, Faces and
owners consume the same final payload. Selecting a transition against raw
water and later validating or reselecting it is forbidden. Thus R17 changes no
selector scalar identity or value, but there is still no pre-R17 4,096 pool or
before/after-winner claim: the one final pool is generated only from immutable
R17 pins.

The retained Source/T1-only oracle independently rebuilds the two seed-specific
R7 mainland perimeters, four displaced Base masks, all eight Wings, exact
apertures and finite envelopes without loading the Partition or raster
compiler. Its memoized four-Bay raw owner count exhausts every integer `P` in
each deduplicated envelope. Seed 0 is `0/0/0/0`; max-u64 is `1/1/1/0` in
Elandor-west/Elandor-east/Kragmar-west/Kragmar-east order, with exactly the
three columns and connectors above and a global `P`-to-Bay bijection. Exact
Base-owner results are Goldmead Vale, Goldmead Vale and Mournfen respectively.
The literal finite scan begins at the
[every-P oracle](../../tools/wp40/t2_source_test.lua):3232, and its independent
[row-end equivalence proof](../../tools/wp40/t2_source_test.lua):3257 checks
the complete implementation superset rather than replacing the semantic domain.
Separate corruptions reject a count-one foreign owner, multiple owners, a
non-interior water neighbour, perimeter equality, unsafe neighbour/envelope
arithmetic and recursive second-pass behaviour; a multi-row synthetic payload
binds lexicographic sorting. The max-u64 transition is then resolved once from
the R17 final mask and retains the R16 elbow/path witness. The historical raw-
mask trace has one multi-reachable branch and pushes 24 reachability frames
(23 in its largest call and stack). Filling the Kragmar-west notch removes
that dead alternative before final-mask tracing, so the authoritative final
trace has zero branches and pushes zero reachability frames while retaining
the exact same 453 stations, 451 steps and SHA-256
`1f528c5671fe69254049b03c3ef5047093bb743f9ddcfdb3967b73a000740cca`.
The oracle compares the complete raw/final byte sequences; this is not a
transition reselection or a changed materialized Bank
([raw/final DFS KAT](../../tools/wp40/t2_source_test.lua):3749).

The semantic domain is still every integer `P`; a compiler may enumerate the
complete finite candidate superset formed by `first - 1` and `finish + 1` for
every horizontal raw-water run of the referenced Bay. Every three-of-four
cardinal-water pattern has a horizontal water neighbour, so its raw-dry centre
is immediately outside at least one such run. The retained oracle checks all
four possible dry-cardinal orientations and independently compares that row-
end result with literal every-`P` enumeration for both Seed 0 and max-u64.

The frozen pre-R18 R17 compiler handoff reported the same Seed0/max `0` and
`1/1/1/0` counts, all 20 Bank byte sequences unchanged, unchanged Faces and
whole-footprint `g/o/r/m=0` after the three fills. Its sole raw-mask/fill
implementation and once-serialized Bay payload are visible at the historical
[compiler fill](../../mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua):1412
and [payload projection](../../mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua):3031;
the production payload validator begins at the
[R17 Bay-payload schema](../../mods/MAPGEN/grug_mapgen/wp40/geometry/partition.lua):3305,
and the compiler test retains the
[final-fill transition-consumption KAT](../../tools/wp40/t2_partition_test.lua):3293. Source-side
rollback mutations begin at the
[policy KATs](../../tools/wp40/t2_source_test.lua):5745 and the
[static audit](../../tools/wp40/t2_source_audit.sh):85 binds the policy,
enumeration, final-mask DFS and checksum surfaces. Those R17 Source and compiler
gates froze successfully. The first C1 measurement was then attempted against
those pins, but its Slot-29/30 Reality failures made that measurement
unpromotable and caused R18 below. No pre-R18 pool or winner may be reused.
T2/32-seed and WP40 completion remain pending.

The historical pre-R18 R17 source checksum was
`154cbc31dea35e0aed06f9525ecb3f2d1ac6fa90f0a71e127da591ed16ed067d`;
the then-unchanged boundary-displacement checksum was
`a32f35c4621d84b50f93253fa7e046fe79553796d6b2752f6344ebf4cea1380f`;
and the R17 world-partition checksum was
`b3173a764329c85c501b34c2e71b1d77abab661c931a18ac1e153cd7eebd6994`.

**R18 selected-winner aperture-tail and incidence-complete-run Reality
correction (coordinate-free Source authority; compiler acceptance pending).**
The first C1 measurement attempt found two different failures after all 20
exact PUC candidate-rescore rows had passed. Slot 29
(`seed=16178445837170081103`, selector index
1713) reached `bay_bank:elandor_east:dawnmere` with authored aperture-dry
station `D=(570,-2927)` and away station `A=(569,-2928)`. `D` was dry
footprint equality but not a Bank candidate: it had no cardinal water. The
immediately aperture-included `W=(571,-2926)` was raw and final water owned
only by Elandor-east and diagonal from `D`. Of the two exact orthogonal
shoulders, `(571,-2927)` was exterior and `(570,-2926)` was the sole strict-
footprint same-Bay candidate `T`. The old `A,D` state had no successor. The
new `D,T` anchor reached the declared `land_004:to` target in 760 Moore
stations, SHA-256
`43817ffcbec8fc0b45831582e78157d5e3f3579d9b268c1ccab0c2b8da8dba66`;
the full 761-station Bank including `D` has SHA-256
`033404e04cefb262559aff17308b9fe5eaff29b6b485a8093604332fcdebe45e`,
and its pure byte reverse has SHA-256
`2cee492c4f87bf8122f84ba0da361275cde27f91f2b39b186530fbc119c60d89`.
These are retained diagnostic handoff values, not yet compiler acceptance
evidence.

R18 therefore adds
`aperture_dry_direct_or_same_bay_diagonal_shoulder_tail_v1`. Exactly eight
aperture-dry incidences are projected from the 20 coordinate-free Bank rows,
one before and after each mouth. For each, `D`, `A` and `W` come only from the
existing authored aperture order and membership. A candidate `D` remains the
direct `A,D` anchor. Otherwise `D` must be dry equality with no cardinal own
or foreign water, `W` must be unique same-Bay raw and final water diagonally
adjacent, and exactly one of `(W.x,D.z)` and `(D.x,W.z)` must be a strict-
footprint same-Bay candidate `T`. Zero or two reject; there is no scan, rank or
tie. A start emits `D,T` and begins Moore tracing at `(D,T)`; an end targets
`T` and emits `T,D`. In the actually materialized direction, this non-Moore
tail must keep `W` on the declared strict water side. Ordinary step-side
validation starts only on the adjacent Moore step. `D` remains the shared
perimeter/Bank terminal, `T` is internal, and reverse consumers reverse only
finished bytes. Canonical aperture payload and Attachment identity do not
change.

Slot 30 (`seed=15219119262482319357`, selector index 1047) found two dry
intervals on `land_007`: singleton `P=(1126,-2239)` at station/control index
177 and stations 179--1755 beginning `E2=(1128,-2239)`, separated by raw and
final Elandor-east water `(1127,-2239)`. The 3x3 neighbourhood around `P` had
only five of eight neighbours in that Bay, so extending R17's degree-one fill
was rejected. The selected R7 record remained `C=3`; its 1,941 shifted-control
rows had SHA-256
`49866585cf4e209057b9681d0150704328656856114679f3afb6264b548dd996`
and its scalar projection SHA-256
`a1437c0d9584068211b8f0772da8f7d4cf6bb6237d51ea7d82a69d59577fba3b`.
That projection hashes 1,941 comma-joined rows in the exact field order
`x:z:source_segment:local_station:scalar_q:normal_x_q:normal_z_q:dx:dz`;
its first row is `950:-2250:0:0:0:0:65536:0:0` and its last row is
`2700:-2740:4:390:0:0:65536:0:0`. It is intentionally distinct from the
richer Source identity serialization used by later retained oracles.
`P` is a genuine selected scalar sample (`scalar_q=-196608`, normal
`(0,65536)`), so deleting it upstream or recomputing the ceiling would change
the selector authority.

The coordinate-free correction is
`joint_terminal_incidence_complete_dry_run_v1`. Exactly six transition-bearing
edges are projected in Source order from the existing eight transition rows:
`land_001`, `land_004`, `land_007`, `land_010`, `land_013`, `land_016`. Their
two ordered endpoint obligations are, respectively, attachment/transition,
transition/transition, transition/attachment, attachment/transition,
transition/transition and transition/attachment. For every maximal final-dry
interval independently, its authored from/to station is `E` for that
endpoint's probe. The existing R16 transition, joint Attachment or ordinary
junction resolver is evaluated only against that interval's `E`. Exactly one
interval must satisfy both ordered obligations. Zero or multiple reject;
longest, first and numeric-index selection are forbidden. The other 55 edges
retain the exact-one-interval rule.

After selection, only the nonempty unique contiguous authored subsequence of
already selected R7 shifted controls whose x/z identities belong to the
selected station interval enters the existing transition/Attachment controls
and sole final reraster. Nonselected controls remain unchanged upstream scalar
samples; no re-`C`, rescore, selector change or post-raster splice exists.
Every excluded dry fragment must be owned exactly once by a final Bank or dry
Face and by no final land edge or terminal identity. Reverse authored input
with swapped obligations must select the same world interval and exact byte
reverse.

An unretained in-memory feasibility run selected stations 179--1755 on
`land_007`, producing a 1,577-station final edge from `(1128,-2239)` to
`(2512,-2663)`. The existing Starbough Bank contained the excluded singleton,
its dry detour and the selected endpoint; its 517 stations had SHA-256
`694aa00661b735fc98ab756616c7da96f66d9a2fc2c53ca99ce0a8ca74e3dc1`.
The Silverleaf Bank consumed only the selected endpoint; its 731 stations had
SHA-256
`4786ad54eb2d955adb6f1560346484599f2561a708d34cdfe40f254cbcc91e24`.
The full read-only feasibility pass reported all 20 Banks, all 38 Faces and
Whole `g/o/r/m=0` over 30,316,314 columns. A 6-seed by 61-edge diagnostic
inventory found only this Slot-30 edge with multiple intervals. These values
explain the authority but remain exploratory until independent repo KATs and
the compiler rerun reproduce them.

Stage 1 closes the two policy surfaces, projects the exact eight aperture
incidences and exact six ordered edge-obligation tuples, and carries no new
coordinates. Independent Source-side decision fixtures reject a first/longest
run, zero or multiple complete runs, noncontiguous controls, wrong excluded-
fragment ownership, zero/two shoulders and wrong start/end tail side. The
compiler must additionally reproduce Seed 0, max-u64 and the four pre-R18
provisional C1 witness seeds as non-promotable diagnostic fixtures, with all
20 Banks, 38 closed/CCW/simple Faces and Whole/no-fallback, before R18 can
freeze. R18 is strictly post-scalar: it changes neither extreme scalar
record identity/value nor an already computed R7 `C`. Because the immutable
measurement input hashes the complete Source and compiler files, the final
4,096 pool has not been measured and must be generated anew on the later
frozen pins. The 4,096 run is explicitly withheld until a separate user GO;
this Source correction does not authorize it.

The checksum-covered policy authority is the
[six-edge incidence-run policy](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):382
and the
[eight-incidence aperture policy](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):648.
Stage 1 binds their exact strings at the
[world-partition policy gate](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):1437
and
[boundary-displacement policy gate](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):1807,
then derives the
[six ordered obligation tuples](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):2708
and
[eight aperture incidences](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):2762.
The independent upstream Slot-30 R7 station/scalar digest is retained at the
[R7 identity oracle](../../tools/wp40/t2_source_test.lua):2674; the focused
[shoulder/run algebraic KATs](../../tools/wp40/t2_source_test.lua):4566 and
[targeted transition mutations](../../tools/wp40/t2_source_test.lua):5355 and
[exact-six projection mutations](../../tools/wp40/t2_source_test.lua):5425 do
not claim compiled Bank/Face coverage. The
[aperture-tail pins](../../tools/wp40/t2_source_audit.sh):48 and
[transition/incidence pins](../../tools/wp40/t2_source_audit.sh):69 bind those
surfaces.

The R18 Source/Reality authority froze with source checksum
`17936b6823fff2527a9df86415df0f8f6bc4ec12ba130e6f09763c266dff3efb`,
boundary-displacement checksum
`7f33822c8650e17ea9029666c800e9001876aada32d597212568b94d74eab935`
and world-partition checksum
`8f3459c2a9eae21dd182129d8447063e7ae102e74373bb55fa779d18ab91cd45`.
The subsequent targeted compiler reproduction then exposed the Stillgrave
terminal failure recorded by R19 below. It did not promote a compiler freeze,
the provisional C1 pool or any winner, and it did not retroactively invalidate
the retained R18 Source freeze.

**R19 joint Bay-transition terminal Reality correction (coordinate-free
Source authority; compiler acceptance pending).** After the R18 Dawnmere and
`land_007` corrections, the same provisional C1 Slot-29 diagnostic seed
(`16178445837170081103`) reached
`bay_bank:kragmar_west:stillgrave` at `land_010:to`. R18 had fixed the one dry
interval, and R16 resolved its old authored endpoint `E=(-1134,2242)` directly.
The resulting start state was `previous=(-1135,2242),current=E`, with target
`(-1386,2938)`, but it had zero ordered successors and zero reachable paths.
The only diagonal one-step proposal `(-1133,2241)` put the referenced Bay on
the wrong side and also had no valid continuation. A private scan, backstep,
side flip or point-specific tail would therefore conceal rather than resolve
the missing terminal authority.

R19 leaves the R18 interval, R7 displacement, final Bay mask, R16 candidate
predicate and R11 trace rules unchanged. Its checksum-covered policy is
`joint_bank_incidence_transition_terminal_v1`. After R18 has selected one
interval, every station incidence except the opposite interval endpoint is
eligible at a declared transition side exactly when it has an immediately
adjacent in-interval station away from that side. R16 is evaluated for every
eligible incidence. An edge carries one or two transition endpoints; for a
two-ended edge such as `land_004` or `land_013`, the full Cartesian product is
one joint authority, never two independent endpoint decisions.

Each candidate tuple first takes its nonempty contiguous R7 control
subsequence, applies every R16 `E` then optional elbow `T`, and sends the
combined candidate clip through the sole final edge raster as an unretained
probe. That probe must be unique, 8-connected, X-cross-free, final dry and
inside the record envelope. Its endpoint is the resolved terminal and its
immediately adjacent final byte away from the endpoint is `previous`; neither
value is taken from provisional R7 adjacency. Both declared incident Banks of
every transition must then complete to their already-authorized Aperture or
Wing terminals. Those other Bank terminals are never edge transitions, so the
dependency is finite and acyclic. Exactly one complete tuple is selected by
its complete terminal/previous/probe-byte identity. Duplicate identities,
zero or multiple complete tuples reject. No first, nearest, longest, scan,
rank or iteration-order tie exists, and no unselected probe or Bank path is
serialized. The complete authority strings begin at the [R19 terminal
policy](../../mods/MAPGEN/grug_mapgen/wp40/source/catalog.lua):403 and their
exact mirror begins at the [boundary-policy
gate](../../mods/MAPGEN/grug_mapgen/wp40/validation/t2_source.lua):1849.

The finite bounds are explicit. Each endpoint has at most selected-interval
station count minus one eligible incidences and successful candidates. The
one- or two-endpoint Cartesian product uses checked safe-integer
multiplication, and a tuple runs at most four existing R11 traces. Each trace
retains its current seed's exact per-Bay `8N` reachability-frame, `N` stack and
`N-1` main-step caps. Reversing authored controls swaps the endpoint sides and
re-enumerates all candidates against their own probe rerasters; it must select
the same world terminal and previous station and the exact byte reverse of the
edge. The retained synthetic [Cartesian, subline and reversal
KATs](../../tools/wp40/t2_source_test.lua):4714 include a two-ended joint probe,
checked-product overflow, a Bresenham subline-divergence witness, both R16
direct and diagonal `E,T` control order, and genuine forward `B,K,E` versus
reversed `E,K,B` candidate re-enumeration.

The retained Source/T1-only Slot-29 oracle rebuilds the selected R7 edge,
current-seed final footprint, all four raw/final Bay owners, R17 fills, the
authored-order final-mask Kragmar-west aperture run and the current-seed R15
joint-tail/wedge result without importing Partition. The aperture run is
uniquely contiguous, has 625 stations at authored indices 3602--4226 and
SHA-256
`864ce08d38aacfa028bac35d82435018c721ee3dd6563ac14021741f28f25837`;
its before terminal is `(-1386,2938)`. The current-seed R15 Kragmar-west-left
pair has two structural pairs, one wedge-valid pair at rank 2, radius 3,
negative tail `(-1399,1901),(-1400,1900)` and positive tail
`(-1398,1900),(-1399,1900),(-1400,1900)`. The exact Kragmar-west trace envelope
has `N=1,130,890`, hence caps `9,047,120 / 1,130,890 / 1,130,889`. These
current-seed reconstructions and the exhaustive R16 incidence loop begin in
the [independent Slot-29 oracle](../../tools/wp40/t2_source_test.lua):3764.

That oracle finds exactly two R16-resolved candidates and exactly one complete
tuple: `K=(-1135,2242)` with probe-derived `B=(-1136,2242)`. The resulting
1,601-station `land_010` edge hashes to
`f823d2abac877c13aa03484cb2941c784b16cbc2c15798bc087596caba7a8e70`;
its byte reverse hashes to
`d914e97cde5ee07c8a45c6fa7bafa5422aa7877429b4c04656433da60e030dc1`.
Stillgrave has 794 stations with SHA-256
`f50970d89d04bf992bfb15f898621157e602abf624b09c6dff49fb09bf8d2317`
and reverse SHA-256
`b98009b596c8ed73450523c8a52df9aecfc97a11f32b4babf8377fbd7555617a`;
Mournfen has 456 stations with SHA-256
`457ec6b155f092589972e01d21e6d2c13181a39e26a3eb700fa1e0f4c2071384`
and reverse SHA-256
`7229bcfa7ae0a3aa6f1c6027678abd71168eaba596a0e2971ffc411b85dffff4`.
The old `E` has no selected land-edge identity, occurs in exactly one of those
Banks, and its exact Base owner is `kragmar_mournfen`. Stage 1 deliberately
does not materialize concrete Faces, so it does not upgrade that Base/Bank
fact into a retained Face-membership claim.

R19 is strictly post-selector and post-R7. Slot 29 has zero R17 fills; its
unchanged R7 control SHA-256 is
`c61d4cd4d0152e04b4f3afe4b061ff454ef04f2a5574524da4295b2e49a9c9c9`,
the Source oracle's scalar-only SHA-256 is
`a251f81728b4aa000a1ed279ab055a7ed38fef81f338ab6d99963bf2b5117295`,
and its full 11-field Source identity SHA-256 is
`25d19e716fc9ccee106f8bdd33938ac94a939d4f50609db3d0cead808261f255`.
The computed byte witnesses and invalid repeated/non-8-connected probe
corruptions are bound at the [edge/Bank and upstream-identity
oracles](../../tools/wp40/t2_source_test.lua):4230; the Stage-1 row/policy
rollback mutations begin at the [R19 transition
mutations](../../tools/wp40/t2_source_test.lua):5405 and static pins begin at
the [R19 audit block](../../tools/wp40/t2_source_audit.sh):63.

An independent, unretained compiler feasibility run selected the same `K/B`,
reported all eight direct transitions, all 20 Banks, all 38 simple Faces and
Whole `g/o/r/m=0` over 30,303,110 columns, with Base/planned/dry counts
`1,902,864 / 2,135,396 / 28,167,714` and 275,706 schedule intervals. Those
numbers explain the correction but are not repository acceptance evidence;
the compiler must reproduce them on the immutable R19 Source pins before any
compiler or corpus claim. No pre-R19 C1 pool is promotable. A future complete
4,096 pool is generated only once from separately approved immutable post-R19
Source and compiler pins.

The R19 Source/Reality candidate binds source checksum
`5e8866d1490b508e54a4d503c087fa5265722ecd443dcfe098bc0e672b2d0000`,
boundary-displacement checksum
`3e6209c76325fa7fa7395c7f75f15181f21ca2e81e8e8c26848019221d96e8fe`
and unchanged world-partition checksum
`8f3459c2a9eae21dd182129d8447063e7ae102e74373bb55fa779d18ab91cd45`.
This is a Source/Reality freeze surface only. Compiler, Face, Whole, selected-
winner, 32-seed and WP40 completion remain pending.

