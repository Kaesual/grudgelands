# WP13: where a capital's streets meet WP40's routes

Round 3 of the playtest, lane 3. What shipped, what was measured, and what a
review should look at.

## 1. The defect

WP40 builds long-distance routes across the whole world, including across the
rivers that run through a capital's 512-node envelope. Where a route crosses a
river on a BRIDGE, the planner writes three courses at that column
(`wp40/planner.lua`, the `bridge_deck` branch):

| y | what |
| --- | --- |
| `functional_y` | the deck, the route's own walking surface |
| `functional_y - 1` | the support |
| down to the clearance datum | open air |

So the UNDERSIDE of a deck whose surface is `d` is `d - 1`, and a street
walked at `t` has `d - 1 - t - 1` blocks of air over it.

WP13's capital streets — the four avenues, the four sides of the ring street
and the seven district lanes — are a surface overlay (`wp13/avenue.lua`): they
pave whatever column surface the seam hands them, and the seam hands them the
WALKABLE surface, which over water is the water. A street therefore crosses a
river as a causeway at water level, and a WP40 bridge over the same river sits
a few nodes above it. The playtest screenshot is that: a deck directly over a
district lane with one block of air between them, which is a lane no player
can walk and therefore a lane that DEAD ENDS at the route.

The street's one-Lipschitz envelope makes it worse than the raw ground
suggests. The road's walking level is the lowest height field at or above the
ground that never changes by more than a node per column, so a terrace up to
forty columns away lifts the street — and a street lifted under a bridge can
end up level with the deck's support, i.e. paved INSIDE the bridge.

## 2. The ruling (playtest round 3)

Bridges stay where they are; the rule is on the WP13 side.

* at least **three** blocks of air between the street's surface and the deck's
  underside → the street passes under the route unchanged;
* fewer → the street is raised in one-block ground steps up to route grade and
  CROSSES AT GRADE, joining the route's surface and continuing down the far
  side;
* a street never simply ends at a route.

Three is the number twice over: a player is two nodes tall, so two is a
crawlspace and three is a corridor; and a lamp standard is a footing plus
three courses of post and torch, so a verge with three blocks of air is
exactly a verge that can still be lit. It is also WP40's own bridge rule —
`source/simple_map.lua`'s `bridge_clearance` profile carries
`minimum_clearance_nodes = 3`.

## 3. What the WP13 side can learn about a route, and where

Nothing had to be published. `wp40/r7_settlement.lua`'s overlay already holds
`planner_source.column_values_at`, whose twenty values include the functional
kind and the functional height of the column. A column a bridge spans reports
`bridge_deck` and the deck's own `functional_y`; every other functional kind —
a land grade, a causeway, a ford — is written INTO the ground and is therefore
already the surface the seam returns. So the seam now answers two numbers per
column instead of one, **out of the same single query**, and the crossing rule
costs no extra column read.

This is deterministic and available before anything is stamped: it is the same
pure height session the writer projects every plot with, and the same one
`tools/wp13/terrain_fixture.lua` builds with no engine at all.

What is NOT available: `grug_zones` (the published world authority in
`mods/CORE/grug_core/zone_authority.lua`) has `nearest_route_at`, which gives a
route's id, class and corridor width but no height and no bridge. A consumer
outside the mapgen seam — the engine probe, for instance — cannot ask where a
deck is. That is why the probe's crossing region is handed to it as a setting
rather than found by it (section 6).

## 4. The rule, in one place

`wp13/avenue.lua`. One new optional callback in the run spec,
`overhead(x, z)`, returning the deck surface over a column or nil; one
constant, `M.MIN_CLEAR = 3`; and the carriageway's profile becomes a FIXED
POINT instead of a single pass:

1. read each lane's ground and each lane's deck, once per column, in the order
   the module already read them;
2. compute every lane's one-Lipschitz envelope;
3. for each POSITION along the run, if any lane of it cannot pass under its
   own deck, take the highest such deck as that position's grade and raise
   EVERY lane of the position to it;
4. repeat until nothing is raised.

Three things follow from expressing it as a change of the column's GROUND and
nothing else:

* the approach ramps itself. The envelope lifts the neighbours one node per
  column on both sides, which is the ruling's "one-block ground steps up to
  route grade", built out of the climb the road already uses for a terrace —
  no new stair rule and no new geometry;
* the road does not fill the river. A raised column that has a deck stands ON
  the deck, so it writes one course there; a raised column that has NOT —
  a bridge narrower than the five-node carriageway — fills from its own ground
  as an abutment, because a road beside the deck would otherwise hang in the
  air. That distinction is the `base` local in the write loop;
* it is monotone. Raising can only raise, a raised column is never lowered,
  and a column raised onto its deck never conflicts again, so the iteration
  stops. Measured: `ring_west` needs none (nothing is raised),
  `ring_north`/`lane_northwest_cross` on seed 531802985935182545 take two
  passes each — the raise pulls their neighbours into the deck as well —
  and `ring_north` on seed 8675309 takes one.

The decision is taken ACROSS the carriageway and not per lane, which is the
one place the crossing rule departs from this module's per-lane profiling. A
lane is profiled on its own because a terrace crossing the road at an angle
reaches the five lanes in five different columns and the difference is a node
or two. A bridge is six nodes over the water: the first version of this lane
decided per lane and produced a street with three lanes on the bridge, two
under it and a six-node wall down the middle. A crossing is a crossing of the
whole road.

The verge is held to the same threshold without an envelope, because a lamp
standard is a footing and three courses: a verge that cannot clear the deck
carries its standard on the deck instead.

`wp40/r7_settlement.lua` is the other file: `walkable_height` became
`walkable_values`, returning the surface and the deck out of one
`column_values_at`, both memoised per session in the run's existing ground
memo, and the overlay's per-piece spec gained `overhead`.

## 5. The measurements

`tools/wp13/lane_routes.lua <repo> <seed> [--legacy] [out.tsv]` builds WP40's
height session offline (seven seconds, no engine), runs every avenue, ring
side and district lane of both capitals through the real `avenue.run`, and
reports the air over the BUILT road at every column a deck spans. `--legacy`
is the same roads with no route geometry, i.e. the road before this lane.

### 5.1 Every crossing on the two gate seeds

Carriageway columns a bridge deck spans, and the blocks of air over the road:

| seed | capital | run | columns | before | after |
| --- | --- | --- | --- | --- | --- |
| 531802985935182545 | Highcourt | `ring_north` (route_006) | 37 | 10 illegal, 1 at grade, 26 clear | 37 at grade |
| 531802985935182545 | Highcourt | `lane_northwest_cross` (route_006) | 35 | 7 illegal, 28 clear | 35 at grade |
| 531802985935182545 | Highcourt | `ring_west` (route_021) | 38 | 38 clear (exactly 3) | unchanged, 38 clear |
| 8675309 | Highcourt | `ring_north` (route_006) | 1 | 1 illegal | 1 at grade |
| both | Dur Brannoc | — | 0 | — | — |

"illegal" is the ruling's own line: fewer than three blocks of air and the
road not at or above the deck.

Clearance histogram, seed 531802985935182545, all 110 spanned columns:

| air over the road | before | after |
| --- | --- | --- |
| road inside the bridge (−2) | 1 | — |
| −1 | 2 | — |
| 0 | 1 | — |
| 1 | 4 | — |
| 2 | 10 | — |
| 3 | 49 | 38 |
| 4 | 43 | — |
| at or above the deck | — | 72 |

Seed 8675309 has one spanned column because WP40 crosses those rivers as
CAUSEWAYS there — at grade, no overhead — which is why the same capital on the
other gate seed barely has the problem. That is the reason the rule is
computed from the actual heights and not from a table of positions.

### 5.2 What moved, and what did not

Built with no route geometry, this module's roads are **byte-identical** to
the module before the change, on all 23 runs of both capitals and both seeds
(`parity` in the evidence). With the route geometry, exactly the runs above
move:

| seed | run | cells before | cells after | cells differing |
| --- | --- | --- | --- | --- |
| 531802985935182545 | `ring_north` | 1283 | 1373 | 250 |
| 531802985935182545 | `lane_northwest_cross` | 1576 | 1721 | 231 |
| 8675309 | `ring_north` | 1224 | 1229 | 13 |

Dur Brannoc's twelve overlay runs are unchanged on both seeds, and so are all
four Highcourt avenues.

**Digests.** No blueprint identity moves. The overlay's identity is its
SPECIFICATION — schema, carriageway, lamp rhythm, look-around, runs, reach box
and palette (`wp40/r7_settlement.lua`, `prepare_overlay`) — and none of those
changed, so Highcourt's and Dur Brannoc's published overlay identities, all 36
district plot identities, the two capital cores and the six start identities
are untouched. The engine pass's `avenue_road_digest` gate, which digests the
EAST AVENUE as read back out of the map, also matches its committed value on
both seeds: the east avenue is not one of the runs a route spans. Its
expectation file therefore stays where the districts package put it
(`tools/wp13/evidence/20260915-highcourt-districts/highcourt/`); the
convention is that it moves with the lane that moves the VALUE, and this lane
does not.

### 5.3 The road is still a road, and still a per-mapchunk function

`lane_routes.lua` also walks the built road and cuts it:

* every lane climbs at most one node per column, end to end, on every run of
  both capitals — zero faults;
* every carriageway column is one unbroken stack starting on its own ground or
  on the deck that carries it — zero faults, which is the abutment property;
* the carriageway is flat across at every column a deck spans — zero faults;
* a run cut in two at a crossing is, cell for cell, the run built whole: 49
  cuts on seed 531802985935182545 and 3 on seed 8675309, zero differences. A
  piece that could not see the deck would climb differently, and a mapchunk
  border is exactly where that would leave a wall.

## 6. The engine

`tools/wp13/run_highcourt.sh <out> full <seed>`, both gate seeds, ports
31200-31299: exit 0, zero `ERROR`/`ModError`, `event=complete`, the avenue road
digest matching its committed value, and **zero `audit_terrain` warnings** (the
`r7_settlement` diagnostic that says a plot does not stand on this world's
ground).

The runner gained an optional `WP13_HIGHCOURT_CROSSING` — one to four
anchor-relative `min_x,max_x,min_z,max_z` boxes, `;`-separated — and the probe
dumps each as `highcourt-crossing-N.tsv`, read back out of the FINISHED MAP.
The box is given rather than found because `grug_zones` publishes no
route-surface query (section 3); if one is ever added, the probe can find its
own crossings.

`tools/wp13/run_capital.sh` had its port guard widened from the round-2 block
`31300-31399` to `31000-31999`, because the runner named one lane's block and
therefore refused every other lane's. The brief pins the block; the runner
holds the thousand.

## 7. The KAT

`tools/wp13/lane_crossing_kat.lua`, six cases, both interpreters, identical
output:

1. no route geometry, and a deck the road already clears, are the same road;
2. the playtest case — one block of air — joins the route at grade, ramps one
   block per column on both sides, comes back down to its own ground, and does
   not fill under the deck;
3. the fixed point: a deck with exactly three blocks over the GROUND and none
   over the ROAD, because a terrace thirty columns away lifted the envelope
   into it. A rule that asked the ground would pass this one;
4. a bridge narrower than the carriageway: every lane at the same grade, the
   carried lanes standing on the deck, the outer lanes solid from their own
   ground;
5. the verge: a standard that cannot clear the deck is carried on it, one that
   can stays on its own ground;
6. the rule never lowers the road, on any of those profiles.

Every case also cuts its run at the crossing and checks the pieces against the
whole, and the built crossing is digested so a silent change shows as a moved
value.

It bites: with the rule disabled at its seam (`local overhead = nil` in place
of `spec.overhead`), the KAT fails in `verify` on the playtest case rather
than passing quietly. `tools/wp13/lane_routes.lua` is the same gate against
real terrain — it exits non-zero on an illegal column, which is why the
`--legacy` half of `measure.sh` reports a non-zero exit on both gate seeds.

## 8. What a review should look at

* **The threshold is a property of the ruling, not of the geometry.** Three
  blocks is what the user asked for and what a lamp needs; a player fits in
  two. If the review wants the road to squeeze under more bridges, `MIN_CLEAR`
  is the one place.
* **The road-wide decision.** It is the deliberate departure from per-lane
  profiling (section 4). The alternative — per lane — was measured and it
  splits the street.
* **`reach`.** The envelope's look-around is 40 columns, justified by WP40's
  own cut-24/fill-16 terracing. A raise adds at most the height of a deck over
  its water, and on the gate seeds that never exceeded the terrain amplitude
  the 40 already covers — which is what the 52 cut tests measure. It is
  measured, not proved.
* **A lamp beside a raised crossing** stands on its own verge, which can now
  be several nodes below the carriageway beside it. Nothing breaks (the
  standard is solid and its footing is written), but it is buried. It was
  already possible beside a terrace; the crossing makes it likelier. Left
  alone deliberately: the fix belongs to whoever revisits the lamp rhythm.

## 9. Open

* No route-surface query on `grug_zones`, so nothing outside the mapgen seam
  can ask where a deck is (section 3).
* The capitals contract (`docs/research/wp13-capitals-pois-contract.md`
  section 2.1) still describes an avenue as "pavement at surface, one stair
  node at each terrace rise, lamp posts every 8 nodes, no height queries". All
  four clauses still hold — the module queries nothing of its own, and the
  overhead arrives through a second caller-owned callback exactly as the
  surface does — but the contract does not yet say what the road does at a
  route. Folding that sentence in belongs to whoever next edits the contract;
  this lane deliberately did not touch it.
* The crossing rule is not part of the overlay's identity bytes, for the same
  reason the envelope rule is not: the identity is the road's specification
  and the rule is the module's code. A change to either moves the built road
  and is caught by the engine pass's road digest and by this lane's KAT
  digest, not by a manifest.
* Only bridge decks create overhead today. If WP40 ever gains another spanning
  structure, `walkable_values` in `wp40/r7_settlement.lua` is the one place
  that decides what counts.
