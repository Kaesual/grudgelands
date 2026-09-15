# WP13: WP40's routes end at the capital gates

Wave 2 of the playtest, lane R. What shipped, what was measured, what a review
should look at, and what is open.

## 1. The defect and the ruling

WP40's route graph predates the WP13 cities. A capital anchor sits ON its
zone's hub (`source/simple_map.lua`, `anchor_rows` against `source.zones`), and
every route that names that zone ran to the hub. Four long-distance roads were
therefore graded straight across each capital's 512-node build envelope and out
the far side.

Playtest round 4, 2026-09-15, is what that looks like on the ground: in Dur
Brannoc the incoming route is cut by the curtain wall at (-1847,-1756) while
the gate stands at (-1801,-1756). The road ends in masonry and the gate leads
nowhere.

**The user's ruling: every incoming route ends at a planned point of the city
boundary (a gate) and no longer runs into the interior; inside, the WP13
streets take over.** The consequence the user drew and the coordinator
confirmed: no WP40 bridge decks inside the 512 envelope any more, so the
wave-1 lane-crossing rule ([wp13-lane-routes.md](wp13-lane-routes.md)) becomes
a safeguard, not a feature, inside capitals.

The ruling is folded into the capitals contract as
[§2.1.1 Routes and gates](wp13-capitals-pois-contract.md).

## 2. What the authored graph already gave, and what had to be written

Two facts of the shipped route graph carry the whole change, and both are
asserted rather than assumed:

* **Each capital is reached by exactly four routes, one per side.** Dur Brannoc
  (zone 3) is route_002 from the south, route_003 to the north, route_019 to
  the west and route_020 to the east; the other five are the same shape. So
  every gate takes exactly one road and there is no tie-break to decide. The
  brief expected two routes per capital, from `capital_ingresses`' `route_ids`;
  that field is a different thing (§6).
* **Each of those routes' authored via pin already lies ON that gate's axis,
  exactly 144 nodes outside the envelope.** All twenty-four of them. The
  approach therefore needs no easing and no bow to bound: the gate leg IS the
  leg, dead straight, normal to the wall it passes through.

So the change in `source/simple_map.lua` is small:

1. `source.capital_gates` -- twenty-four rows, `(ax ± 256, az)` and
   `(ax, az ± 256)`, derived from `capital_core`'s 512 and not from a literal,
   each also appended to `source.route_stations` as
   `station:<zone id>:gate_<side>` with `kind = "gate"`. Publishing them as
   STATIONS is what keeps the compiled centreline, its claim exclusion
   `exclude:route:<id>` and its ingress corridor describing the same road: the
   compiled validator already requires a route's first and last point to BE its
   station's position.
2. A capital route pins to its gate instead of the hub, and its gate leg is the
   same bowed leg with the **amplitude taken out**. That is the whole of it: the
   leg still contributes its three points, so the centreline keeps its length,
   `pinned_point_index` keeps its value (4), and `whitebridge_bridge`, the one
   authored crossing that sits on a capital route (route_021's via pin at
   (-400,-1500)), keeps its index.
3. `simple_map.lua` (the compiled artefact) validates all of it: the gate
   geometry against `capital_core`, four gates per capital against the capital
   anchors, each capital route's station and terminal against its side's gate,
   the last leg axial, and **no centreline point strictly inside any envelope**
   -- the ruling's own sentence, checked against the points.

### 2.1 The height, which is the half that is not geometry

A capital's hub station carries the anchor's platform height
(`height.lua`, `route_station_target`: `capital.reference_y`), because the hub
IS the anchor column: a road that ended there had to arrive at the level the
city stands on. A GATE is 256 nodes out, where the capital fitting has already
spent its cut-24/fill-16 and the ground is whatever the blend left.

Pinning a gate to the platform height is wrong and visibly so. Measured at Dur
Brannoc's west gate on seed 531802985935182545 before this was fixed: the
ground at the gate is 97, the anchor is at 149, and the road built a **52-node
embankment** to the gate and then fell off a cliff four columns inside the
wall (local 248: 97, 249: 105, 250: 129, 251: 145, 252: 149).

A gate station is therefore a FREE TERRAIN junction: `junction_target` with no
fixed height takes `scalar_before_paths`, which is the fitted and blended
ground the WP13 avenue will pave at that same column. The junction's owner is
the zone the gate column classifies into and not the capital's own zone --
`junction_target` asserts the two agree and 256 nodes out through a warped
boundary is far enough that they need not. With that, the same profile is flat:
97 at local 240 through 257, then the road descends one node per column.

`route_station_target` and `route_station_junction` are keyed by ZONE INDEX for
a hub and by STATION ID for a gate, in one pair of tables rather than two,
because `height.lua`'s construction function stands at Lua 5.1's 200-local
ceiling and two more names do not fit (`luac51 -p` says so).

## 3. The measurements

`tools/wp13/route_gates.lua <repo> <seed> [out.tsv] [--full]` builds WP40's
height session offline (ten seconds, no engine) and answers six questions per
capital and seed. The sweep below is all six capitals on the nine seeds of
`tools/wp13/capital_anchor_fixture.lua`, run once on main 922bfd92 and once on
this branch.

| measurement | before | after |
| --- | --- | --- |
| route end to its gate point (216 approaches) | up to 256, total 55296 | **0 everywhere** |
| route columns graded strictly inside an envelope (54 capital × seed) | 395757, worst 7330 | **3240, worst 60** |
| bridge-deck columns strictly inside an envelope | 11994, worst 1210 | **0** |
| gate columns where the route grade and the built avenue differ by more than one | 23 of 216, worst 30 | **4 of 216, worst 6** |
| entry runs with a walk break, 64 nodes outside the avenue in to the core | 84 of 216, 616 breaks, worst 30 | **5 of 216, 5 breaks, worst 7** |
| water columns under the four avenues | 26586 over 63 wet runs | 26586 over 63 wet runs (unchanged) |
| avenue positions left unpaved / climbing more than a node | 0 / 0 | 0 / 0 |

Reading the two that are not zero:

* **60 route columns per capital** is 15 per route: the road is seven wide and
  ends AT the gate, so its own end cap rounds three nodes past the terminal
  (7, 5 and 3 columns at one, two and three nodes in). Those fifteen columns
  lie inside the curtain's own seven-node thickness, under the gate passage,
  and the avenue -- which runs out to 261 and is written by the settlement
  successor after WP40 -- paves over them. Zero is only reachable by ending the
  road short of the gate, which is the thing the ruling forbids.
* **All five remaining walk breaks and all four remaining gate steps are Nhal
  Veyr's north gate**, on five of the nine seeds, and they are a fact about
  that capital's terrain rather than about the routes (§5).

`--full` scans all 261121 columns of an envelope instead of a band around the
route polylines. The two agree exactly (seed 531802985935182545, all six
capitals: 7330/7330/7323/7330/7330/7330 route columns and 0/1159/436/0/0/0 deck
columns either way), which is what licenses the band.

### 3.1 Water under the avenues, and why it is not a fault

With no route inside the envelope there is no WP40 bridge inside it either, so
the four avenues carry themselves. Seven of the twenty-four avenue runs stand
in water on every one of the nine seeds -- Highcourt west/east/north, Lethariel
east/north, Kezamba east/north, up to 549 of an avenue's 1070 columns -- and
none of that is new or changed by this lane.

It needs neither a deck nor a dried corridor, and the reason is already in
`wp40/r7_settlement.lua`'s `walkable_values`: the seam hands the overlay the
WATER surface where there is water, and the settlement writer overwrites, "so
the result is a solid causeway across the water and not paving floating on it".
The tool checks the property that follows rather than the count: over all 216
avenue runs of the sweep, **zero positions are left unpaved and zero climb more
than one node**. Every wet avenue is a causeway, and every gate is an entrance.

### 3.2 The engine

`tools/wp13/run_capital.sh`, ports 31000-31099, one server at a time under
`nice -n 19`:

| run | result |
| --- | --- |
| `dur_brannoc full 531802985935182545` | exit 0, 0 `ERROR`, 0 `ModError`, `event=complete`, 0 `audit_terrain` |
| `dur_brannoc full 8675309` | same |
| `dur_brannoc full 15912857179583385436` (the user's world) | same |
| `run_highcourt.sh full 531802985935182545` | same, avenue road digest matches its re-frozen value |
| `run_highcourt.sh full 8675309` | same |
| `run_highcourt.sh edge 15912857179583385436` | same -- the chunk-edge case, Highcourt's anchor root at y 48 on a chunk's lowest layer |

Per-mapchunk cost, the capital's own 85 (Dur Brannoc) and 94 (Highcourt)
chunks, steady mean, same host, `nice -n 19`:

| capital | before | after |
| --- | --- | --- |
| Dur Brannoc | 587772 µs | 583202 µs |
| Highcourt | 559080 µs | 520179 µs (−7.0 %) |

Highcourt is cheaper because the four routes no longer grade 7330 columns
inside its envelope. `core_cells` is identical in both capitals (42163 and
43075) and `worst_plot_fall` is 6 in both, before and after.

### 3.3 The user's own proof

`tools/wp13/evidence/20260915-route-gates/dur-brannoc-south-gate-user-seed.png`
is the user's finding, before and after, on the user's seed: the road crossing
the envelope 47 nodes west of the gate and running on into the city, beside the
same road coming up the avenue's centre line and stopping in the gate passage.
The wide view is `dur-brannoc-gates-user-seed.png`.

**The gate the user saw.** The user reported the gate at (-1801,-1756), one
node west of the anchor's own x. That is not an off-by-one in the geometry:
read out of the finished map (`dur_brannoc-gate.tsv`, the east gate, seed
15912857179583385436) the passage is pavement from local -6 to +6 with
`castle_stonewall` at ±7, so it is **13 nodes wide and centred exactly on the
anchor's axis**. -1801 is a position inside it, one node off centre.

## 4. Two frozen expectations that described the old world

The engine pass found both, and neither is optional.

* **`r7_manifest.lua` required a capital anchor's functional feature to be a
  ROUTE** -- `route_%03d` at `(numeric - 7) * 3 + 2`, i.e. route_002, 005, 008,
  011, 014, 017, the first route of each capital's four. Nothing but the
  capital's own fitting reaches the anchor column now, so the feature is the
  fitting's id, which is the anchor's.
* **`r7_anchor_activation.lua` required the cell UNDER an anchor root to carry
  no intent at all.** That held only because a route suppressed R6's surface
  pass on those six columns. Measured at anchor_007 and anchor_009 on seed
  531802985935182545: `0/0/0/0/0/0/0` before, `393/0/0/4/0/0/19456` after --
  a biome TOP (opcode 4) with its material in `aux`, which is ordinary ground.
  `occupancy`, `feature` and `interface` are the CLAIM fields and still must be
  zero; `opcode` may now also be 3 (shore) or 4 (top), and `aux` may be
  non-zero only with one of those. That is not a new idea: it is exactly the
  support rule `r6_settlement.lua` already applies to a cultural root
  (`wrong_support`, `intent_opcode ~= 3 and ~= 4`). A decoration (opcode 12), a
  deck, a path surface and an `aux` with no opcode all stay refused.

### 4.1 Every digest that moved, and why

| digest | before | after | why |
| --- | --- | --- | --- |
| WP40 route graph (all 57 centrelines, KAT row `route_gate_all_routes`) | `9b1cf862…` | `5f8f6443…` | the twenty-four gate legs |
| `anchor_roster_sha256`, and with it the per-seed R7 mapgen manifest (dur_brannoc, seed 531802985935182545) | `f6c633a0…` | `a02a3816…` | a capital anchor's functional feature is its own fitting |
| Dur Brannoc built avenue / rampart / gate, both gate seeds | see the files | re-frozen in `tools/wp13/evidence/20260915-capital-terrain/dur_brannoc/` | the road now arrives at the gate; the diff is confined to local x 248-260 plus subsurface fill material |
| Highcourt built east avenue, both gate seeds | see the files | re-frozen in `tools/wp13/evidence/20260915-highcourt-fill/highcourt/` | same |
| WP13 micro pair output | `8e2ca809…` | `641e868b…` | the new `route_gates_kat` row |

Every digest that did **not** move, checked rather than assumed:

* the six start identities, `0bbf87a7…` exactly as wave 1 recorded them;
* the six start route centrelines, `e57867fb…`, frozen in the KAT;
* `tools/wp13/capital_anchor_fixture.lua`, `981a0353…` over all nine seeds --
  no capital anchor's y, terrain, functional kind or surface y moved;
* every WP13 blueprint identity: the micro pair's digest moved only by the
  added KAT row, and `tools/wp13/highcourt_identities.lua` is untouched;
* `core_cells` at both capitals in the engine.

## 5. What is open, and whose it is

* **Nhal Veyr's north gate.** Five of the nine seeds leave one step of 2 to 7
  nodes at local 261, the avenue's own outer end, where the WP13 road stops and
  the WP40 road takes over. The cause is Nhal Veyr's terrain and not its
  routes: the capital's fitted plateau stops twelve nodes short of its own
  north envelope edge (seed 531802985935182545: local 248 is at 106, 252 at
  94), and `wp13/avenue.lua`'s one-Lipschitz envelope carries the plateau's
  level eight columns out past that drop while the route arrives at the ground.
  Before this lane the same gate had 30 breaks with a worst of 9 on that seed,
  so this is a 30 → 1 improvement and not a regression, but it is not zero.
  The fix belongs to whoever owns Nhal Veyr's terrain -- the capital's own
  fitting should reach its four gates -- or to its wall, which could ramp the
  five nodes between the curtain and the field. **Not this lane's to fix**, and
  named here so it is not lost.
* **`capital_ingresses`' `route_ids` are not the routes that reach a capital.**
  `ingress_dur_brannoc` names route_003 and route_043; route_043 runs from zone
  5 to zone 34 and never touches Dur Brannoc. Read as a two-hop chain it is the
  corridor from the capital out to the front line, which is a sensible thing to
  protect and is what the 128-wide `hard_capital_ingress_corridor_v1` does.
  This lane left the field alone; the corridors rebuild from the new
  centrelines automatically, so each now stops at its gate. The KAT checks the
  consequence: no ingress corridor covers its capital's anchor column any more,
  and each covers exactly one gate.

  **What it protects, measured.** Within 400 nodes of each capital anchor the
  corridor's footprint goes from 59951 columns to 25086. Of the 40285 columns
  it gives up, **36627 are inside `hard_capital_build_plus_apron_v1`** (532
  wide, centred on the anchor), which protects them anyway -- so nothing inside
  a city lost protection. The other **3658 per capital** lie outside the apron
  along the old bowed approach and are now ordinary land, which is correct:
  protection follows the road and the road moved. 5420 columns are newly
  protected, along the new straight approach.

  Whether the ingress should instead name all four of a capital's routes is a
  question for whoever owns the protection policy.
* **The 15-column end cap** (§3). If a reviewer wants literal zero inside the
  envelope, the endpoint would have to move three or four nodes out and the
  route would no longer end at the gate. The cap is measured, bounded and
  overwritten; leaving it is a choice, not an oversight.
* **A route that is added or moved.** The KAT's "exactly four routes, one per
  gate" assertion is what stops a future route from silently taking a gate that
  already has a road, and the "no point inside an envelope" assertion is what
  stops one from being drawn through a city. Both fail loudly.

## 6. What a review should look at

* **The straight leg is amplitude zero, not a special case.** `curved_route`
  takes `straight_first`/`straight_last` and passes amplitude 0 for that leg.
  Everything that depends on a centreline's SHAPE (the point count, the pinned
  index, the crossing pins, the minimum of seven points) is untouched by
  construction rather than by repair. Worth checking that the reviewer agrees
  that is what the code does.
* **The gate station's owner.** `junction_target` is called with the zone the
  gate column classifies into, not the capital's zone, because the function
  asserts the two agree. That is the right call for a junction 256 nodes out
  through a warped boundary, and it means a gate junction can belong to a
  neighbouring zone. Nothing in the sweep failed on it, on nine seeds.
* **The activation support rule** (§4). It is the one safety check this lane
  widened. The precedent is `r6_settlement.lua`'s own `wrong_support`; the KAT
  carries both the two new accepting cases and the nine refusing ones it
  already had.
* **The re-frozen built-road digests.** Four files, two capitals, two seeds.
  The diff behind them was inspected and is confined to the gate band (local x
  248-260, where the road now arrives) and to subsurface fill material turning
  from the route's engineered stone back into natural dirt and gravel at
  y = -2 and below. No blueprint cell moved; `core_cells` is identical.

## 7. The gates

* `tools/wp13/route_gates_kat.lua`, in the WP13 micro pair under both
  interpreters, byte-identical output (`641e868b…`): the twenty-four gate
  points derived independently of the table that publishes them, one route per
  gate with no collision, the 144-node straight approach, not one route or spur
  point strictly inside any envelope, the six start route centrelines frozen,
  and the ingress corridors clear of the anchor columns.
* `tools/wp13/route_gates.lua <repo> <seed>` exits non-zero on any of its six
  faults, so the terrain half is a gate too.
* `tools/wp40/r7/run.sh unit` -- the anchor activation KAT, with its two new
  cases.
* `tools/wp13/capital_anchor_fixture.lua` -- unchanged digest over nine seeds.
* The engine table of §3.2.
