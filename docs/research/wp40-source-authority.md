# WP40 Compiled-Geometry Source Authority

Status: **derived implementation authority. Not game design.**

[world_zones.md](../design/world_zones.md) owns *what the world is* — the
zones, the named places, the distances a designer chose, and the contracts
later work packages consume. This file owns *how the WP40 T2 compiler derives
that world from the coordinate-free authored source*: canonical direction
rules, fixed-point arithmetic, raster topology, trace algorithms and terminal
resolution.

The separation matters because the wrong layer was accumulating detail. The
rules below were written into the design document by the Reality corrections
R7--R19 between 2026-08-13 and 2026-08-15 and are extracted here verbatim, in
compiler-pipeline order rather than in the order they were discovered. No rule
was changed, weakened or removed in the move; the extraction is a relocation,
not a revision.

Consumers: WP40 T2 only. WP13, WP17, WP24, WP41, WP42, WP9 and WP12 read
`world_zones.md` and never need this file. The narrative history of each
correction, with its evidence and digests, stays in
[wp40-engineering-brief.md](wp40-engineering-brief.md).

## 1. Boundary displacement

### 1.1 Canonical station metadata, normals, scalars and local clipping

- Control/sample taper distance is the station-step distance of the canonical
  8-connected raster, equivalently its Chebyshev arclength, not Euclidean
  distance between authored controls. The damping envelope is smootherstep of
  `(d∞-96)/96` for `96 < d∞ < 192`. The final displacement factor is the
  checked Q16 product of control taper and the minimum no-jitter factor.
  Each base station keeps its authored source-segment index, zero-based local
  index and local last index through canonicalization; a deduplicated shared
  control join has taper zero for both incident segments. Open calculation
  chooses the lexicographically lower complete forward/reverse station
  sequence. A closed sequence removes its repeated terminal, rotates each
  direction to the lowest `(x,z)` station and chooses the lexicographically
  lower cycle. These canonical calculation directions alone determine normal
  and signed-scalar direction; authored direction is restored only for output.
  Segment boundaries and taper metadata are remapped, never re-derived from
  the canonical whole sequence.
- For a directed 8-connected step `(dx,dz)`, let
  `len_q=isqrt((dx^2+dz^2)*Q^2)` and its left normal be
  `(qdiv(-dz*Q,len_q), qdiv(dx*Q,len_q))`. An endpoint uses its only step. An
  interior station normalizes the sum of incoming and outgoing left normals;
  a zero step or opposite zero sum rejects the seed. Clamp noise to
  `[-Q,+Q]`, compute `raw_scalar_q=qmul(noise_q,max_displacement*Q)`, and
  compute `damping_q=qmul(control_taper_q,min_no_jitter_q)` followed by
  `damped_scalar_q=qmul(raw_scalar_q,damping_q)`. That damped signed scalar has
  exactly one local clip: first test its exact rounded
  candidate; if outside, test same-sign integer magnitudes descending from
  `min(max_displacement,floor(abs(damped_scalar_q)/Q))` to zero and take the first
  valid probe. The closed envelopes are a base-centered Chebyshev square for
  a land edge, the fixed mainland frame for mainland coast, the authored
  centered closed 600×700 island authoring rectangle, and the exact base
  station for fixed geometry. Base Bays use their separate symmetric-width
  rule, not this polyline clip. Equality is inside every local envelope.

### 1.2 Record-wide topology ceiling

- The locally clipped values are `local_scalar_q`; they are not yet the
  exported scalar. One record-wide topology correction tests integer ceilings
  `C` in strict descending order from that record's `max_displacement` through
  zero. At a candidate `C`, every station uses
  `clamp(local_scalar_q,-C*Q,+C*Q)`: values at or below the ceiling remain
  bit-identical. The ordinary component conversion and sole final reraster are
  then evaluated once for that candidate. A candidate is valid only when all
  shifted controls and final stations remain in the record envelope, stations
  are unique and 8-connected, no diagonal cell contains an X-cross, and a
  closed record is simple with its declared orientation. The first valid
  candidate is the greatest admissible `C`; its scalars and its already-built
  raster are the only exported result. Higher invalid candidates are selection
  probes, never geometry or selector input. The scan does not assume validity
  is monotone and does not use binary search. Stage 1 proves that the
  zero-displacement authored base raster is valid, so the finite scan takes at
  most `max_displacement+1` candidates (currently at most 97); failure at
  `C=0` is invalid source rather than a seed failure or alternate fallback.

### 1.3 Component conversion, final reraster and fixed mainland closure

- The sole component conversion is
  `dx=qround(qmul(normal_x_q,displacement_scalar_q))` and likewise for `dz`,
  with both Q16 and integer half ties away from zero. Every shifted base
  station is then a control—not an emitted answer—for one final canonical
  8-connected reraster between consecutive controls; a closed cycle also
  rasterizes last to first, suppresses consecutive joins and removes a
  repeated terminal. There is no second displacement, clip, snap, noise query
  or scalar interpolation. After the selected record ceiling, any remaining
  final envelope, width or cross-record connectivity failure rejects the seed
  without selecting another ceiling or seed.
- Each planned mainland closes inside that same R7 record through one
  checksum-covered `r7_fixed_closure`. It contains no coordinate or perimeter-
  segment index: Elandor references `land_048` through `land_043` in descending
  order and reverse direction, and Kragmar references `land_054` through
  `land_049` in the same way. All twelve referenced land edges have zero
  displacement. The resolver applies the sole route raster to the six directed
  references, suppresses only their consecutive shared endpoints, and requires
  the resulting 5,001-station union to be byte-identical to exactly one complete
  authored perimeter base segment. The other 26 source segments remain the
  ordinary movable coast. An equivalent authored closed rotation or reversal
  must rediscover that complete geometric match; it may not retain or infer a
  canonical array index.
  The uniquely matched source-segment membership is tagged before closed-cycle
  canonicalization and travels with the station metadata through rotation or
  reversal. Its ordinary local-scalar rows are exactly zero. The two closure-
  to-ordinary-coast ring joins also remain exactly zero through the existing
  Holy-corner no-jitter authority; all five internal six-edge union joins are
  closure-tagged zero rows. The same single record-wide `C`, candidate topology test
  and final reraster cover the displaced 26-segment coast plus this fixed
  closure; there is no post-R7 replacement. The selected closure must equal the
  same directed six-edge union byte for byte. Its six refs are also the exact
  suffix of `ordered_outer_components`, while all 18 Coast spans remain
  unchanged. Missing, reordered, reversed, duplicated, moving, discontinuous,
  repeated or nonmatching refs, a second/full-segment ambiguity, a changed
  component suffix, or any snap, owner fallback, second ceiling or private
  coordinate match rejects.

## 2. Junction separation

### 2.1 Pre-partition junction departure

- Four checksum-covered `junction_departure` records prevent a digital
  one-edge trunk at the Ashenward/Bannerbreak four-way junctions without
  changing an authored land-edge record. They bind `land_035`, `land_036`,
  `land_041` and `land_042` at their `from` endpoints, respectively. For
  endpoint `J` and the adjacent original authored control `C`, both axis
  deltas must be nonzero and the fixed departure is derived exactly as
  `D = J + (sign(C.x-J.x), sign(C.z-J.z))`. The current derived stations are
  `(-1399,-1099)`, `(401,-1099)`, `(-1399,1099)` and `(401,1099)`.
  Each sign is selected by ordered coordinate comparison without evaluating
  the potentially unsafe difference; the adjacent source control must remain
  inside the exact mainland frame and each `J +/- 1` sum is checked inside
  the safe integer range.
  Compilation copies the original control array, inserts `D` at position two,
  and feeds that effective copy into the same sole displacement/reraster
  pipeline. `D` is fixed, zero-jitter and is not a separately displaced
  station. The original 57 source controls, route source and route payload
  remain unchanged; the four compiled boundary rasters intentionally differ
  from the pre-correction result.
  Stage 1 rasterizes the effective `C=0` controls and checks every one of the
  102 unordered incident-edge pairs at all 38 junctions. Stage 2 repeats this
  R13 proof on the selected R7/effective-control displacement rasters after
  their final canonical reraster but before R11 planned-water clipping and
  perimeter-attachment selection. At that pre-partition stage all 38 source
  junctions and all 102 pairs still exist: only `J` may coincide, with no
  shared nonterminal station or segment and no opposing diagonal X-cross.
  Missing, duplicate, malformed, nonincident, nonendpoint, nondiagonal or
  incorrectly derived records and any pair overlap reject. There is no
  shared-trunk, connector, snap or joint-topology-ceiling retry.

### 2.2 Post-partition topology categories

- Post-partition topology has a separate exact gate. The degree-two source
  junctions `(-1050,-2250)`, `(+950,-2250)`, `(-970,+2260)` and
  `(+1020,+2250)` are fully dissolved because their raw `J` columns are Bay
  water; their eight incidences are the declared coordinate-free edge-to-Bank transition
  identities, not four surviving edge pairs. The remaining 34 ordinary
  relief junctions retain exactly 98 unordered incident-edge pairs at their
  raw `J`. All eight perimeter attachments are disjoint terminal authorities
  outside the relief-junction roster and retain their edge/perimeter/span
  identity gates. A junction with a mixture of transition and ordinary
  incidences, an attachment endpoint that also claims relief-junction
  authority, or any roster/count drift rejects as a new Reality case. After
  these three categories resolve, all 38 dry faces must still be closed and
  counterclockwise, and either simple or accepted with window-guarded
  join-local, locally non-crossing self-touches — zero-width filament
  appendixes and interior-beside pinches (the 2026-08-20
  contracts-§11.5-C correction as completed by §11.9; region truth by
  winding).

## 3. Bay Bank components

### 3.1 Component records

- Bay banks are integer-column boundaries derived from the final planned-water
  classifier, not literal shore polylines. The source contains exactly 20
  coordinate-free ordered `bay_bank_component` records, five per Bay. Each
  record names one Bay, two structured terminal references, its one incident
  face arc, canonical direction and water-right orientation; it contains no
  coordinates, controls or copied shape. The compiler resolves every terminal
  and materializes every chain once. All consumers use its one component ID
  and byte-identical canonical stations; defensive table copies are allowed,
  but a private connector, snap, inferred endpoint, second resolution or
  second trace is forbidden.
- The three terminal kinds share one resolution authority. Exactly eight
  `aperture_dry` incidences are projected from the 20 Bank records: one
  `before` and one `after` incidence for each mouth aperture. In the
  deduplicated final **authored/declared** perimeter order, let `D` be the dry
  station adjacent to the aperture, `A` the next dry station away from it, and
  `W` the immediately included aperture-water station toward it. "The next
  dry station away" is a search, not a fixed offset (the D2 decision,
  [wp40-t2-plan.md](wp40-t2-plan.md) section 7.2, decided 2026-08-18): each
  sweep of the aperture extraction admits, per aperture end and per station
  order, at most one detached Base-Bay-passing station separated from the
  aperture run by exactly one non-passing station — recorded on the compiled
  aperture, outside membership, payload and ownership — and the `A` search
  skips it. Every other Base-Bay-passing station outside the mouth run
  remains an aperture reject, measured vacuous over the full `W` census. If `D` is a
  final same-Bay Bank candidate, the direct rotation anchor remains `A,D`.
  Otherwise `D` must be dry footprint equality with no cardinal same-Bay or
  foreign water, while `W` must be raw and final water owned only by the
  referenced Bay and exactly diagonal from `D`. Of the two orthogonal elbows
  `(W.x,D.z)` and `(D.x,W.z)`, exactly one must be a strict-footprint final-dry
  same-Bay candidate `T`; zero or two reject, with no order or tie rule. At a
  component start the canonical Bank begins `D,T` and Moore tracing begins at
  `(previous=D,current=T)`; at an end Moore tracing targets `T` and the Bank
  ends `T,D`. The non-Moore terminal tail, in its actually emitted direction
  (`D->T` at a start, `T->D` at an end), must keep `W` on the declared strict
  water side. Ordinary step-side validation begins only on the adjacent Moore
  step. `D` remains the shared perimeter/Bank terminal and `T` is internal.
  This Bank-only resolution changes neither canonical aperture membership
  indices, compiled aperture payload nor the Attachment tie, and reverse
  consumption reverses only the finished bytes.

### 3.2 Edge-transition terminal resolution

  `land_edge_transition` resolves through exactly eight coordinate-free
  `bay_edge_transitions` records for `land_001:to`, both ends of `land_004`,
  `land_007:from`, `land_010:to`, both ends of `land_013` and
  `land_016:from`. Each record binds one Bay, one edge endpoint and its two
  incident Bank component IDs in Source order; it carries no coordinate or
  shape. For each currently enumerated final-dry edge interval, let `E` be its
  authored `from` or `to` endpoint for this endpoint's probe. If `E` is already
  a same-Bay candidate, it is that interval's terminal result. Otherwise `E` must
  be strict dry with no cardinal planned-water neighbour, and the immediately
  adjacent discarded provisional station `W` toward the Bay must be exactly
  diagonal from `E` and final water owned only by the referenced Bay, including
  any materialized notch fill. Both orthogonal elbows `(W.x,E.z)` and
  `(E.x,W.z)` must be distinct,
  strict-dry, in-footprint same-Bay candidates; the lexicographically least
  `(x,z)` is the terminal. Any failed precondition rejects without fallback.
  A resolved elbow is inserted after `E` as a terminal control in that
  candidate's sole final-edge probe reraster; it is never appended or snapped
  post-raster and is not a scalar sample. R19 below promotes only the selected
  complete joint terminal tuple and its already-probed edge bytes. Extreme-
  scalar record identities and values remain upstream and unchanged. The raw
  mask is built next, the one simultaneous
  fill produces final planned water, and only then is each R16 transition
  selected exactly once against that final mask. Selection against raw water
  followed by validation or reselection is forbidden. (Pool status is recorded
  in [wp40-t2-plan.md](wp40-t2-plan.md), not here; it was measured on
  2026-08-16.) The complete 4,096 pool
  and selected four extreme winners have no before/after identity claim: a
  new complete pool is measured only once on the later explicitly approved
  immutable post-correction pins. The edge and both Banks
  consume the same once-resolved station ID and exact canonical x/z bytes;
  defensive alias-free copies are allowed, but there is no inward scan or
  private shift. `wing_junction_tail_side`
  resolves through the one joint tail-pair result for its Wing; `J` remains
  dry and is the only common terminal of the two sides.

### 3.3 Trace anchors and Moore tracing

- For a non-Wing start, a direct aperture uses `previous=A,current=D`; an
  aperture shoulder tail emits `D` and uses `previous=D,current=T`. At an edge
  transition, `previous` is the immediately adjacent retained
  dry final edge station away from the resolved endpoint (for an elbow this
  is `E`) and `current` is the resolved transition. Each 8-connected,
  candidate-valid Moore anchor supplies rotation only; it has no water-side
  requirement. The separate shoulder-tail side rule above still applies. No
  other start heading is inferred.
- A Moore candidate is a final-classifier dry mainland column, including
  permitted dry perimeter equality, with a cardinal neighbour owned as final
  water by the same Bay's final Base/Wings/notch-fill mask. Search is finite: the
  Base-Bay and two Wing bounding boxes are expanded by one column and clipped
  to the final mainland footprint. Trace state is `(previous,current,seen
  directed states)`. Starting half-edges are 8-connected and candidate-valid;
  they supply rotation only. Every materialized outgoing Bank step is
  water-right compatible. The fixed clockwise base order is east, southeast,
  south, southwest, west, northwest, north, northeast. The first probe is
  immediately clockwise after the current-to-previous direction for
  water-left and immediately counterclockwise for water-right; all 20 current
  records declare water-right. A next column must be an unseen 8-neighbour
  candidate, not `previous`; the proposed materialized Bank step
  `current -> successor`, including the first one, must satisfy the exact
  cardinal-water cross-sign rule. Successors are tested in the fixed Moore
  order, and the first one from which the already-resolved terminal has a
  complete valid path is selected; later reachable successors are permitted.
  Reachability is a bounded DFS over `(previous,current,seen directed states)`.
  Each successor call counts every pushed frame including its start and may
  push at most eight times the finite envelope-column count; its stack depth
  is at most that column count, and the materialized main trace has at most
  envelope columns minus one steps. Zero reachable successors, a repeated
  state/column, X-cross, foreign-water contact, undeclared endpoint or any
  frame/stack/trace/envelope exhaustion rejects. Reversing a component returns
  only the byte-exact reverse of the once-selected canonical station sequence;
  it never reruns reachability.

### 3.4 Wing endpoints, tails and wedge validity

- Wing endpoint `K` is trace-independent. For each signed Wing side, enumerate
  final-dry columns in that Wing's box which have a cardinal neighbour in the
  strict interior water of that specific Wing, satisfy `0 <= N < L`, and have
  the declared strict sign of `X = cross(J-A,P-A)`. Choose greatest exact `N`,
  then lexicographically least `(x,z)`; an empty set rejects. Existing Wing
  dot/cross bounds guard `abs(N)`, `abs(X)` and every product below `2^53`.
  Select the negative and positive tails jointly from the two complete
  8-connected dry distance-layer DAGs whose Chebyshev distance to `J`
  decreases by one at every step. A structurally valid pair is strict-side
  except at `J`, interior-disjoint, has distinct predecessors of `J`, and has
  no intra- or inter-tail diagonal X-cross. Every such pair must then pass the
  inclusive dry-wedge analysis before ranking. Its analysis-only exact polygon
  follows the negative tail `K- -> J`, the byte-reverse of the positive tail
  `J -> K+`, and the direct exact chord `K+ -> K-`. The polygon must be simple
  and have nonzero signed area. Set `R` to one plus the larger Chebyshev
  distance from `K-` or `K+` to `J`; the current hard bound is `R <= 5`.
  Scan every integer column in the inclusive `J +/- R` box whose exact polygon
  class is inside or on its boundary. Only exact negative- or positive-tail
  stations—including `K-`, `K+` and `J`—are exempt; every other such column
  must be strict water of that referenced Wing. The chord is never rastered,
  materialized, serialized or used for ownership. Among all wedge-valid
  pairs, choose the least by negative path then positive path, comparing every
  coordinate by `(x,z)` and treating a shorter exact prefix as less. Multiple
  wedge-valid pairs are permitted; none rejects. Current sources require
  `Chebyshev(K,J) <= 4`; the general finite path bound remains
  `ceil(isqrt(L)) + 1` stations.
- A negative Wing terminal is always a component start: its joint tail is
  emitted byte-exact as `J -> K`, and its last two stations supply the Moore
  `(previous,current=K)` rotation-only start state. Its first outgoing
  `current -> successor` Bank step must pass the water-right rule.
  A positive Wing terminal is always a component end: Moore tracing targets
  its independently selected `K`, then appends `K -> J` with the join `K`
  deduplicated. Tail selection precedes every component trace, so a
  Wing-to-Wing head-bank component has no circular start inference.

## 4. Edge intervals, attachments and joint transition terminals

  A declared edge/perimeter attachment has one joint endpoint, not a connector
  or post-raster snap. After the final displaced perimeter exists, a
  provisional displaced edge raster is split into all maximal consecutive
  final-dry intervals. For each interval independently, its authored `from`
  and `to` endpoints are the two `E` probes: a Bay transition uses the existing
  R16 final-mask resolver, an attachment uses the existing joint-perimeter
  resolver, and an ordinary junction uses its declared endpoint. An interval
  qualifies only if both ordered Source obligations pass; exactly one must
  qualify. Zero or multiple qualifying intervals reject. Longest, first and
  numeric-index selection are forbidden.
  For an attachment probe, on the declared final displaced perimeter segment,
  `A` minimizes the tuple `(Chebyshev(E,A), canonical perimeter station index)`
  and must be at distance at most one. After the complete interval is selected,
  discarded outside prefix/suffix controls are removed, `A` replaces the terminal
  control with zero displacement and is also both incident perimeter-span
  boundaries, and the edge is then emitted by the sole final raster. The
  provisional run is never exported; no `E -> A` segment is emitted. The final
  endpoint equals `A` exactly, every other final station is strict footprint
  interior, and the result is one 8-connected retained run. On the six edges
  carrying the eight Bay transitions (`land_001`, `land_004`, `land_007`,
  `land_010`, `land_013`, `land_016`), the exact ordered from/to obligation
  tuples are projected from the existing transition and attachment records;
  the other 55 edges require exactly one final-dry interval. This is the R18
  provisional interval/control set, not a final transition-terminal claim.
  Ordinary nonattached ends retain their endpoints. At the eight declared Bay-
  edge ends, R19 may select an interior direct incidence or its reviewed
  same-Bay diagonal elbow, and that terminal further clips the candidate's
  probe before the same sole final raster.
  From the already selected R7 shifted controls, an ordinary edge retains
  exactly the nonempty, unique, contiguous authored subsequence whose canonical
  x/z identities belong to its selected interval. An R19 edge instead retains
  the nonempty, unique, contiguous combined subsequence bounded by its selected
  joint terminal incidences. Nonselected controls remain unchanged upstream
  scalar samples but never enter final boundary geometry; there is no re-
  ceiling, rescore, selector change or post-raster splice. Every excluded dry
  fragment must instead be owned exactly once by a
  final Bank or dry Face and by no final land edge or terminal identity.
  Reversing the authored edge and swapping its obligations must select the
  same world interval and exact reversed edge bytes.
  After that R18 interval has been fixed, R19 resolves its declared Bay-edge
  transition terminals jointly. At each declared transition endpoint, every
  station incidence in the selected interval except the opposite endpoint is
  eligible exactly when it has an immediately adjacent in-interval station
  away from that endpoint. The existing R16 resolver is evaluated for every
  eligible incidence. An edge has one or two transition endpoints, and the
  compiler exhaustively evaluates the complete Cartesian product of their
  successful R16 candidates. It applies no first, nearest, longest, scan,
  backstep or private-order pruning.
  For each candidate tuple, the compiler takes the nonempty contiguous R7
  control subsequence for the combined candidate clip, inserts each R16 `E`
  and optional elbow `T` in that order, and runs the sole final edge raster as
  an unretained probe. The probe must be unique, 8-connected, X-cross-free,
  final dry and inside the record envelope. Each resolved terminal must be its
  declared probe endpoint; its `previous` station is the immediately adjacent
  probe station away from it. Both declared incident Banks of every transition
  must then complete to their already-authorized Aperture or Wing terminals
  under the unchanged R11 tracing rules. Those other terminals are never edge
  transitions, so the dependency is finite and acyclic. Two tuples with the
  same resolved terminal, previous and probe-edge byte identity are duplicate
  authority and reject; zero complete tuples reject. Among several complete
  tuples the compiler selects the least under the declared total order of
  [wp40-t2-plan.md](wp40-t2-plan.md) section 7.1 (decided 2026-08-18): total
  retreat from the declared endpoints — the station distance along the
  selected interval from each declared endpoint to its incidence — then
  maximum per-endpoint retreat, elbow-terminal count, the sorted resolved
  terminal set, the sorted `previous` set, and the probe bytes under
  canonical orientation. Tuples equal under the last three keys are
  duplicate authority and were rejected before the order applies, which is
  what makes the order total; every key is invariant under authored
  reversal, so the reversal clause below holds unchanged. The order is
  selection among enumerated complete tuples, never pruning: the
  no-first/nearest/longest/scan/backstep ban on the enumeration stands.
  Only the selected tuple's probe bytes are materialized once. An unselected
  probe, R16 result or Bank path is not serialized. Edges with transitions at
  both endpoints are evaluated as one joint tuple against one combined probe,
  never as two independent terminal choices. Reversing authored controls and
  swapping `from`/`to` obligations must re-enumerate the same world terminals
  and adjacent probe stations and produce the exact byte reverse of the final
  edge; Bank consumers reverse only finished bytes. Per endpoint, eligible
  incidences and candidates are bounded by selected interval station count
  minus one; the one- or two-endpoint Cartesian count uses checked safe-integer
  multiplication. Every tuple uses the existing per-Bay `8N` reachability-
  frame, `N` stack and `N-1` main-trace-step bounds. R19 changes no R7 control,
  scalar, mask, candidate or water-side authority, and the final 4,096 pool may
  be measured only against later approved immutable post-R19 Source and
  compiler pins.
  In the undisplaced literal Stage-1
  baseline, three attachments have `E=A`, five have Chebyshev distance one,
  and `land_016` has no common raw edge/perimeter raster station before this
  joint selection. Those counts are not seed-zero compiled evidence: Stage 2
  must separately validate all eight final displaced attachments at seed zero
  and every corpus seed against the distance-at-most-one contract.

## 5. Extreme-selector scalar input boundary

- The four measured extreme-corpus seeds score only scalar-bearing,
  pre-displacement canonical **source** raster stations after noise, damping,
  local clip and the selected record-wide topology ceiling but before
  component rounding. Mainland coast uses the union
  of eligible outer source-perimeter segments, keyed and ordered by perimeter
  ID, zero-based source-segment index and zero-based local index; overlapping
  `perimeter_span` ranges never double-count a segment or station. Island
  coast uses `(arc_id, segment, local index)`, and positive shared boundaries
  use `(edge_id, segment, local index)` in numeric edge order. At a source
  segment join or closed seam, the stable earlier identity wins. Every
  positive-displacement canonical source station is scored exactly once, even
  when its shifted control or final interval is not selected. Only a derived
  provisional attachment `E`, perimeter `A`, elbow or other final-reraster
  station without a source-station identity is excluded. No selector scalar is
  interpolated, resampled or rehashed; if selected final geometry later fails,
  Stage 2 rejects it without choosing a fallback seed.

## 6. Retained acceptance evidence

### 6.1 Wing tail-pair corpus

- The retained R15 Stage-1 source oracle enumerates the complete structural
  Wing-tail-pair corpus in existing source Wing order while binding each row by
  Wing ID. Current raw-pair counts are
  `4,18,18,4,2,18,18,18`; wedge-valid counts are exactly one each; selected
  raw ranks are `1,10,2,1,2,17,9,17`; radii are `4,5,5,4,3,5,5,5`; and
  negative/positive tail lengths are `4/3,4/5,5/4,3/4,2/3,5/4,4/5,5/4`.
  The former structural-only lexicographic selection left dry-Wing counts
  `0,1,1,0,1,4,4,4`, totaling 15; wedge-valid selection reduces every entry
  to zero. The original `/tmp` PUC run is exploratory feasibility evidence;
  the retained source oracle proves Stage-1 arithmetic only. The first R15
  compiler run reproduced all eight rows and exact selected tail bytes; the
  later H55 perimeter-closure witness reopened Source before any final
  Compiler/Partition freeze. Full per-seed partition/face gates remain open.

### 6.2 Source-versus-compiled staging

- Authored-source validation does not pretend that the seed-independent source
  already contains final concrete face polygons. Before displacement it proves
  one checksum-covered, symbolically closed authority graph: every literal
  component polyline is simple, all shared-edge and perimeter-span references
  have exact orientation and incidence, and the eight shared-edge-to-perimeter-
  span clip attachments are structured references. A heuristic connector,
  coordinate-inferred connector or floating intersection is invalid. Only the
  compiled per-seed stage materializes the canonical integer boundary rasters,
  clips each of the 55 ordinary shared edges by removing at most one prefix and
  one suffix, and selects the unique incidence-complete interval plus
  contiguous authored control subsequence on the exact six transition-bearing
  edges. Each excluded dry fragment must have exactly one Bank/Face owner and
  no land-edge or terminal identity. It then proves every concrete face closed
  and counterclockwise, and either simple or accepted with window-guarded
  join-local, locally non-crossing self-touches — zero-width filament
  appendixes and interior-beside pinches (the 2026-08-20
  contracts-§11.5-C correction as completed by §11.9; region truth by
  winding). It reruns the
  complete footprint `g=0/o=0/r=0` proof for every corpus seed. This staging
  distinction changes neither the final topology nor any acceptance case.

## 7. Planned water, bank width and relief fields

### 7.1 Raw-mask notch fill

- Final planned Bay water applies one coordinate-free
  `single_pass_same_bay_raw_mask_degree_one_notch_v1` pass to that immutable
  raw Base-plus-Wings mask. For a Bay, a raw-dry column `P` qualifies only
  inside the deduplicated union of its Base/Wing boxes when `P` and all eight
  neighbours are strict final-mainland interior, exactly three cardinal and
  all four diagonal neighbours are raw water owned by that Bay alone, and the
  fourth cardinal neighbour is raw dry. Every Bay and every integer `P` in
  that finite union is evaluated against the same raw mask; all unique
  qualifying `(Bay,P)` pairs are unioned simultaneously once. Filled columns
  never feed another decision. Foreign or multiple Bay ownership, multiple
  qualifying Bays, perimeter or mouth-aperture equality, or unsafe envelope/
  neighbour arithmetic rejects. A filled `P` uses its Bay's existing exact
  rational owner policy; no neighbour owner, rank, snap or new tie exists.
  The exhaustive semantic domain remains every `P`; the finite implementation
  may evaluate the complete superset consisting of `first - 1` and
  `finish + 1` for every horizontal run of referenced-Bay raw water. This is
  exact because every three-of-four cardinal-water pattern has at least one
  horizontal water neighbour, so its raw-dry centre is immediately outside
  such a run. All four possible dry-cardinal orientations and literal-every-
  `P` equivalence are acceptance oracles.
  Each compiled Bay stores the policy ID, count and lexicographically `(x,z)`
  sorted fill columns once. Transitions, Banks, Faces, partition and ownership
  consume those exact bytes without reclassification or face inference.

### 7.2 Bay bank width jitter

  For the currently evaluated authored segment, the owner
  chooses the nearest station of its canonical 8-connected centreline raster
  by exact squared Euclidean distance, with the lower canonical station index
  on a tie. In particular, Elandor-west segment 1 at `P=(-1376,-2846)` selects
  zero-based station 2, `(-980,-2938)`, rather than rounded-parametric station
  1. One domain-separated field uses periods 256/512, hash lanes
  0/1 and amplitudes 2/3 + 1/3; it is consumed through one symmetric lane.
  Canonical station-step distance to the nearest authored sample supplies the
  96-station smootherstep taper. With Q = 65536, `delta_nodes =
  qround(qmul(qmul(noise_q, 48*Q), taper_q))`; both banks use `r +
  delta_nodes`, samples and endpoint caps retain zero taper, and strict bank
  equality remains dry. The exact body predicate substitutes
  `E = base_width_num + delta_nodes*L` into `C^2*L < E^2`. Stage 1 proves the
  current maximum `E^2 = 4,243,584,391,840,000`, actual guarded corpus
  `C^2*L = 4,251,571,423,760,000`, and conservative algebraic early-cross
  bound `4,251,754,341,463,400`, all below `2^53 - 1`.

### 7.3 Raw relief profile mapping

  Raw relief first clamps every input `noise_q` to `[-Q,+Q]`, then maps it to a profile with
  `delta = max_above_water - min_above_water` and
  `H = water_level + min_above_water + floor((noise_q+Q)*delta/(2*Q))`.
  Thus `delta` is the inclusive endpoint span, not the count of integer
  results; `-Q`, `0`, and `+Q` map to the lower endpoint, lower midpoint, and
  upper endpoint respectively. A singleton profile remains constant.
  Inputs at `Q+1`, `-Q-1`, `+/-2Q`, and larger magnitudes still map to the
  corresponding exact endpoint; the height product never sees an unclamped
  input.

  Relief `H` is evaluated exactly on zone-owned authored surface columns:
  canonical dry-face ownership, the sorted Section-11.7-B residue intervals
  exported under their owning dry face, and zone-owned Planned Water. The
  residue intervals are dry `H` authority; no consumer reconstructs the Whole
  gate to rediscover them. Exterior coastal shelf, deep ocean and immutable
  dragon channels have no `H` and use their separate `W`/d profile. An
  internal relief query on one of those exterior classes rejects. Where raw
  dry memberships overlap on a declared edge or junction, the canonical
  half-open classifier resolves exactly one owning face before relief
  evaluation.

### 7.4 Relief junctions and shared-boundary blending

  Each of the 38 multi-edge endpoint junctions owns one checksum-covered
  `relief_junction` record with its coordinate and sorted incident edge IDs.
  If all incident edge gate bands intersect, its common `J` is selected from
  that inclusive intersection with the full decimal seed and the exact hash
  tuple domain `relief_junction_v1`, feature `junction:x:z`, coordinates
  `(x,z)`, candidate 0 and lane 2; a singleton uses its sole value. At seed 0,
  `(-1050,-2250)` selects `J=38` from `24..56`. If the intersection is empty, `J` is
  the floor of the midpoint between the maximum lower bound and minimum upper
  bound. Exactly 16 current junctions need that bounded common transition; it
  may temporarily lie outside an incident raw profile band, while remaining
  inside the global safe relief envelope. `(-1400,-1100)` has incident bands
  from `land_003/020/032/035`, empty bounds `96..56`, and `J=76`;
  `(-2200,1900)` has empty bounds `56..24` and `J=40`.
  At a column, the ordinary exact nearest-segment/projection tie produces at
  most one record for each unique land edge, its perpendicular distance `d`,
  and the exact-rational nearest canonical raster station to that projection
  (lower global station index on a tie). Let its zero-based global station be
  `s` and its last station index be `S`. The authored junction `J` applies to
  that edge only if the chosen final raster terminal equals the authored
  junction coordinate exactly and the edge is an authored incidence there.
  Otherwise the endpoint supplies `native_G` and no substitute relief-`J`
  candidate exists. For an eligible junction, the start is supported only for
  `s < 96`, the end only for `S-s < 96`; a supported endpoint supplies
  `qlerp(J, native_G, smootherstep(endpoint_distance/96))`, otherwise the edge
  supplies `native_G`. It never contributes a separate far-end junction pair.
  This preserves the post-partition R14 categories in Section 2.2: 34
  surviving relief junctions contribute 98 ordinary incidences, four dissolved
  degree-two junctions contribute eight Bay-transition incidences, and the
  eight perimeter attachments plus eight perimeter-vertex endpoints remain
  outside the 106-incidence relief-junction roster. Here, 98 counts
  incidences; its equality with Section 2.2's 98 unordered incident-edge pairs
  is coincidental.
  Raw authored controls have minimum endpoint Chebyshev separation 400, while
  the undisplaced attachment-joint raster baseline has minimum 297 station
  steps (`land_034`; `land_031` is 298). Neither Stage-1 fact proves the length after final seeded
  displacement and attachment selection. Stage 2 measures each final edge
  raster and hard-rejects fewer than 192 station steps before endpoint support;
  this runtime gate proves the two strict 96-station supports cannot overlap.
  Each unique edge record has
  weight `1-smootherstep(d/96)` and records are accumulated in land-edge
  numeric order with checked Q16 products. Zero-weight candidates—including the quantized-zero support
  near and at distance 96—are excluded. The common candidate height is the
  ordered weighted result, boundary strength is the maximum positive weight,
  and the final relief is its qlerp from post-landmark `H`. With no positive
  weight, the result is exactly post-landmark `H` and no division occurs.
  Landmark replacement hashes the landmark record's `noise_domain`, its
  `secondary_relief_id` profile's ordered octaves and band, an empty feature
  ID, and candidate 0.

### 7.5 Landmark collar composition

  Resolve the final `surface_owner_at(x, z)` exactly once for each column in
  the Section-7.3 `H` domain, before primary relief and landmark composition.
  The result must be exactly one zone. Zero ownership, multiple ownership or
  an unresolved ownership input inside that domain rejects; exterior shelf,
  deep ocean and immutable dragon channels remain outside the `H` domain and
  never enter landmark evaluation. A landmark's effective exact membership is
  its authored integer mask predicate **and**
  `surface_owner_at(x, z) == landmark.zone_id`. Its effective Q16 collar
  weight is its authored collar weight under that same owner equality and zero
  otherwise. The implementation reuses the one column owner; a second owner
  classifier or a per-landmark owner lookup is forbidden.

  Starting from the owning zone's primary `H`, enumerate every owner-eligible
  landmark with positive effective Q16 collar weight in ascending
  `base_h_priority`; the higher priority therefore applies last. Each record
  qlerps from the `H` composed by all preceding records to that landmark's
  replacement height using its own weight. Zero-weight and foreign-owner
  records are excluded rather than entering an order, a denominator or a one-
  winner selection. Existing shared-edge and junction relief blending follows
  this post-landmark `H`; the complete order is final owner, primary `H`,
  owner-clipped landmark composition, then the existing edge/junction blend.

  The owner clip is a domain guard, not authority for a cliff or other abrupt
  final feature. C-a2 must structurally prove that every cardinally adjacent
  Dry-to-Dry final-owner change maps to a compiled final land-edge or junction
  support and that its two post-landmark heights are consumed by that support's
  existing 96-station blend. An undeclared dry owner seam is a STOP; no numeric
  clip-step allowance can substitute for the structural proof. Adopted residue
  remains an input to its owning dry face and creates no separate dry
  cross-face authority. C-b owns final Planned-Water bed and bank continuity
  across internal Bay and Wing owner seams. D-2 owns every `H`-to-exterior
  coast, shelf and immutable-channel transition. Neither later package may
  treat clipping as proof of its product.

  Exact authored mask membership remains the source integer predicate and is
  independent of the Q16 signed distance used to derive collar weight. The 264
  measured ellipse incidences on which exact membership and signed-distance
  equality differ are retained evidence, not authority and not a license to
  substitute one classifier for the other. C-a1 proves the mask and collar
  arithmetic without claiming final zone containment. C-a2 applies the owner
  clip through the package-local `surface_owner_at(x, z)` projection over the
  accepted integrated `grug_wp40_compiled_world_v2` records: compiled Bay-v3
  Base/notch/connectivity data and owner spans, closure-wing and mouth-
  aperture/perimeter ownership, dry-face-v2 polygon and adopted-residue
  ownership, and the canonical half-open seam tie. Polygon membership remains
  the ordinary-dry input; “not polygons alone” means none of the other owner
  classes or ties may be omitted. The authored mask and collar remain stable
  diagnostic identities even where the effective mask/weight is zero. The
  current Source validator checks landmark `zone_id` referential integrity at
  `validation/t2_source.lua:4024`, plus the exact WARCOAST-SOURCE-1 row and
  route-contact contract at `validation/t2_source.lua:446` and its call at
  `validation/t2_source.lua:4041`; no general geometric-containment check
  exists. Missing ownership payload is a STOP; neither C-a package may rebuild
  the partition classifier. Priority affects height composition only: it never
  deletes exact mask identity. Required-route non-blocking is evaluated against
  the final composed `H` and later route products rather than inferred from
  either a winning mask or the owner clip.

  The checksum-covered
  `geometry_policies.relief_composition.landmark_priority_order` literal, whose
  value is `ascending_base_h_priority_higher_applied_last`, requires greater
  priority to compose later and apply last. It never selects one landmark or
  suppresses another owner-eligible positive collar.

  Capsule mask geometry follows the exact source validator. With
  `short = min(radius_x, radius_z)` and `long = max(radius_x, radius_z)`, its
  closed axis segment has half-length `long - short` on the longer-radius axis;
  x wins an equal-radius tie. Exact membership is distance to that segment
  less than or equal to `short`, and Q16 signed distance is the lower-root Q16
  distance to the same segment minus `short*Q`. Consequently the authored x/z
  radii remain the capsule's total half-extents rather than becoming the bare
  axis-segment extents.

  `WARCOAST-SOURCE-1` applies this invariant symmetrically at the two fixed
  Holy/channel contacts. `gravesalt_warcoast` is centred at `(-2420, 0)` and
  `skyglass_warcoast` at `(2420, 0)`, retaining their `80 x 230` total
  half-extents. Their channel-facing exact boundaries therefore touch the
  closed Holy columns at `x = -2500` and `x = 2500` and never enter strict
  exterior channel columns. The Source validator pins both boundary contacts
  and rejects the former `x = +/-2530` membership; the Source KAT separately
  pins the incident-edge displacement envelope. C-a2 applies the same general
  owner clip to these records, but that safety rule does not revoke or weaken
  the accepted Source correction and its pinned clean boundary contact.

  This mask contact does not own the boat-corridor width. Each approach is the
  exact half-open interval `[approach_z - 48, approach_z + 48)`. At the Holy
  boundary both `z = +/-125` centre lines remain inside; under that chosen
  convention the exact integer mask covers 73/96 southern and 74/96 northern
  columns. The 73/74 split is convention-dependent, while both centre-line
  contacts and complete 96/96 coverage four nodes inland are convention-
  robust. The boat/travel records independently retain the complete 96-node
  approaches. Later route-product validation, not landmark-mask width, proves
  nonblocking access.

  The complete LuaJIT exact-mask census of all 70 authored masks is retained as
  diagnostic acceptance evidence rather than a full-mask-containment gate.
  The exact-mask enumeration and incident-edge-margin geometry do not vary by
  seed. Against the accepted seed-0 compiled ownership payload, it enumerated
  11,441,328 exact-mask columns. Fifteen masks had 274,597 columns outside
  their authored owner: zero Planned-Water columns, 264,197 columns owned by
  another Dry face, and 10,400 nil/exterior columns. Another 10 masks were
  owner-clean at seed 0. Their failures were limited to the former
  incident-edge-margin test, whose geometry is seed-independent. Both corrected
  warcoast masks were owner-clean at seed 0. Their margin geometry was clean
  and seed-independent.
  Movement is a STOP only under the same seed-0 payload comparison; a
  separately authorized payload change requires fresh evidence rather than an
  automatic repin, while an unexpected payload change independently stops.
  No complete positive-collar Planned-Water census exists: an attempted scan
  was aborted after approximately 180 seconds because of an unfiltered Bay
  lookup and retained no output. No canonical digest for the exact-mask census
  was retained, so this document does not manufacture one; the implementation
  package must retain its reproducible rows and bind the digest it actually
  produces when it closes C-a2.

### 7.6 C-a1 primitive boundary conventions

  The shared centred total-width policy includes the negative boundary and
  excludes the positive boundary on both axes:
  `-floor(W/2) <= local_axis < ceil(W/2)`. An even width therefore enumerates
  exactly `-W/2` through `W/2 - 1`. Local coordinates are signed Q16 world-
  column offsets from the anchor centre. The common radial primitive value is
  the lower-root Euclidean
  `radius_q16 = isqrt(local_x_q16^2 + local_z_q16^2)`.

  `primitive_terrace_q16_v2` measures its rings outward from that anchor-
  centre radius. Its offset is
  `min(rings - 1, floor(radius_q16 / (step_run*Q))) * step_height*Q`; the
  fitting-footprint Chebyshev signed distance determines support and the later
  generic feature blend, not the terrace ring number. These statements make
  the existing source policy and retained radius KAT explicit; they do not add
  a new template primitive.

## 8. Exterior coast-source selection

Exterior dressing inherits one `coast_source_zone_id` from the nearest allowed
compiled outer-coast component. Which components are allowed, and the fact that
the value is inheritance only, are design contracts in
[world_zones.md](../design/world_zones.md); what follows is only how the
nearest one is chosen.

- Each final 8-connected compiled segment uses endpoint squared distance over
  one or interior `C^2/L`. All exact rational minima are collected before
  choosing lower zone numeric ID, then stable component ID, then zero-based
  component-segment index.
