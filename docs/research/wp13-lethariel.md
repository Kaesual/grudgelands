# WP13: Lethariel, the elf capital and the first one built round a lake

Increment record, 2026-09-15, written against `main` at `922bfd92` ("Extend the
socket vocabulary for the wave-2 capitals"), rebased onto `c8050057` ("Merge the
wave-2 NPC vocabulary"), which is what makes this capital's four wave-2
profession vendors resolve to real entities, and then onto `f5583e13` ("Merge the
Dur Brannoc upgrade to the Highcourt standard"), which carries Lane R's routes
ending at the capital gates and Lane D's `run_capital.sh` fixes. It is the fifth increment of the
capitals contract's section 3 order — the second of "the other five capitals,
one lane each" — the third capital of the game and the first OPEN one to ship
(the user's ruling of 2026-09-14: open edges for Highcourt, Lethariel and
Kezamba; the round-3 plan later moved Highcourt to the walled side and left
Lethariel and Kezamba open).

Contracts implemented:
[wp13-capitals-pois-contract.md](wp13-capitals-pois-contract.md) (2.1 what a
capital is, 2.3 the budgets, 2.4 the elf row of the race table, 4 the rulings on
the king's hall, the sockets and the walls) and
[wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md) (2 the socket
field, 6 spares, 7 the `door` tag, 8 work sockets, the 80/20 rule and the
profession vendors, including the wave-2 vocabulary). The seam it plugs into is
[wp13-seam-generalisation.md](wp13-seam-generalisation.md); the standard it is
measured against is [wp13-highcourt-fill.md](wp13-highcourt-fill.md) and
[wp13-highcourt-districts.md](wp13-highcourt-districts.md); the recipe for
adding a capital is [wp13-dur-brannoc.md](wp13-dur-brannoc.md).

**Fix round, 2026-09-16.** An independent review found one blocker and two
should-fixes, and all three are in the tree: the threshold's lintel could sit on
the avenue's deck and on one seed sealed a gate shut (section 4 rule 3); a
threshold generator that shipped in no composition (deleted); and the road
causeways damming the mere into six lakes (section 4b, the bridge). Six smaller
findings went with them — a crown that could overwrite a trunk, a crown that
could reach over the water, a piece-independence guard one factor short, a
legal-position table nobody could reproduce, two stale comments and a pair of
miscounts in the prose. Each is named where it is fixed.

Evidence: `tools/wp13/evidence/20260915-lethariel/`.

## 1. What shipped

| File | Change |
| --- | --- |
| `wp13/elf_parts.lua` | **new**: the two capital palette handles this race needed — the four green roles (hedge, water, tilled soil, crop) and the pale civic masonry — and two parts no library had: the **tree platform** and the **shrine** |
| `wp13/elf_grove.lua` | **new**: the GROVE EDGE, an open capital's boundary as an overlay — `wall.lua`'s place in the composition with the masonry taken out of it — and the four THRESHOLDS on the gate axes |
| `wp13/elf_bridge.lua` | **new**: the road over the mere as a deck on piers, so a water body stays ONE body (section 4b) |
| `wp13/lethariel.lua` | **new**: the 96 × 96 civic core, the avenue, ring and edge run specifications, the overlay dispatch and the committed shore of the mere |
| `wp13/lethariel_plot.lua` | **new**: the plot builder, `highcourt_plot.lua`'s job for this race |
| `wp13/lethariel_quadrants.lua` | **new**: the lot grids, the fill lots, the district lanes and the permutation over **three** quarters |
| `wp13/lethariel_districts.lua` | **new**: the four rosters and the resolve |
| `wp40/r7_lethariel_blueprint.lua` | **new**: the capital source the seam reads — core, 44 plots, one overlay of nineteen runs |
| `wp40/r7_settlement.lua` | one roster row; nothing else |
| `tools/wp13/lethariel_kat.lua` | **new**: acceptance for the core, every plot, the lots, the permutation, the avenues and the grove edge |
| `tools/wp13/lethariel_plots.lua` | **new**: the lot predicate — and the first WP13 terrain tool that needs no engine dump (section 3) |
| `tools/wp13/final_micro.lua` | the new KAT joins the interpreter pair |
| `docs/design/settlements.md` | two paragraphs: open capitals, and the capital on a lake |

Not touched: the six start compositions, `highcourt*.lua`, `dur_brannoc*.lua`,
`avenue.lua`, `wall.lua`, `capitals.lua`, `buildings.lua`, `parts.lua`,
`palette.lua`, `dressing.lua`, `layout.lua`, `interiors.lua`, `roofs.lua` and
every WP40 file but the roster row.

## 2. THE MERE: what WP40 leaves inside this capital, and what the city does about it

**Measured, and the measurement is the whole design.** WP40 fits and flattens
the 96 × 96 civic core at the anchor's own height — and leaves the planned lake
that was already there. Inside the core's ±47 pad, **1 393 of the 9 409 columns
are `planned_water`**, in ONE contiguous wedge whose tip is at (0, 22) and which
widens northward to the pad's north-east corner; the lake surface stands at
y ≈ 27 against a civic terrace at y ≈ 41 on the user seed, thirteen nodes below
it. Across the whole ±256 envelope the lake is **9 625 of 66 049 columns**
sampled every two nodes.

**It is the same lake on every seed.** A planned water body is a property of the
static world plan (`wp40/source/simple_map.lua`) and not of the fitted terrain,
so `water_class_at` gives the identical mask on all nine seeds of
`capital_anchor_fixture.lua`. `tools/wp13/lethariel_plots.lua --shore` is the
gate: it reads the same `water_class_at` the engine's `grug_zones` does, over
every column of the pad, on every one of those seeds, and asserts the shipped
core writes on none of them.

```
seed                  wet_in_core  covered  silent_dry
531802985935182545           1393        0          55
8675309                      1393        0          55
15912857179583385436         1393        0          55
0 / 1 / 2 / 42 / 12345 / 999999999   (identical on all six)
```

**What the composition does.** It writes nothing there. A pad laid across the
wedge would hang a one-node slab of turf thirteen nodes over open water, and no
blueprint can reach down to meet it — the core's authorized volume starts at
y = −2. So the shore is committed as a table with one node of natural margin,
everything the core lays is masked against it, and the city meets the water with
a **marble quay** instead: a promenade three wide that follows the diagonal,
kerbed on the water side and lit from its own landward row.

**The avenues cross it, and how they cross it is section 4b.** The seam hands a
road the WATER surface where water stands rather than the bed under it
(`r7_settlement.lua`, `walkable_values`, the rule Highcourt's river bought), so
`avenue.lua` builds a solid CAUSEWAY at the water line. That is the right answer
for Highcourt's rivers and the wrong one here, and the first version of this
package shipped it: **six road runs crossing the mere dammed it into six
lakes**. What ships now is a bridge on piers.

Two consequences the composition had to author rather than inherit:

- **the north avenue starts at z = 22, not at 48.** Every other capital's runs
  start one node clear of the core's own edge because the core paves the ground
  inside it. This one cannot: the axis is under water from z = 22. The run
  therefore starts where the pad's paving stops, and the core reserves the run's
  seven-lane band from that row northward — the seam forbids a core cell and an
  overlay cell in the same place, which `tools/wp13/integration_fixture.lua`
  asserts for every settlement and which it caught here twice;
- **the king's hall stands west of the throne approach, not north of the
  crossing.** Highcourt's and Dur Brannoc's halls look south down their own
  avenue from the north quarter. At Lethariel the dry ground on that axis runs
  out at z = 21 and the hall's own footprint is 32 × 36. So the approach is the
  SOUTH avenue and the hall looks across it from the west.

## 3. THE LOTS: three quarters of nine and one of three

### 3.1 Why the permutation is over three quarters and not four

The capitals contract's section 2.1 says the four district roles are "assigned
to quadrants by a deterministic permutation from the world seed". That sentence
assumes four quarters a district can be moved BETWEEN. Held to the same lot
envelope every other capital's lots are held to — dry footprint and margin,
perimeter fall at most the skirt, rise under the airspace the plot clears, clear
of the core, the gate corridors and every street run, inside its own quarter, a
lane clear of its neighbours — the quarters are not comparable.
`tools/wp13/lethariel_plots.lua --census [reach]` counts every position on a
four-node grid that passes the whole predicate on all nine seeds:

| reach | south-east | **north-east** | north-west | south-west |
| --- | --- | --- | --- | --- |
| 13 (Highcourt's) | 536 | **50** | 545 | 666 |
| 11 (this capital's) | 858 | **77** | 825 | 924 |

An order of magnitude, whichever reach is asked. A greedy packing at reach 11
puts three lots in the north-east and twenty-six to twenty-eight in each of the
others. Four interchangeable quarters do not exist at this capital.

An earlier draft of this note quoted 1 297 / 110 / 1 313 / 1 448, taken with a
throwaway script over the two gate seeds. The independent review could not
reproduce them and said so; the numbers above come from a committed mode of the
committed predicate and anyone can re-run them. The qualitative claim — and with
it the 30/14 shortfall against Highcourt's 36/16, and the fixed mere precinct —
survived the correction unchanged, which is the point of having asked.

**The design decision** — this lane's, not a user ruling and not contract text:

- the **north-east quarter is THE MERE**, and the lore and spiritual district
  stands there and only there: three lots on the far shelf, the shrine, the
  mourning grove and the fishing stages. A precinct built round a lake cannot be
  moved to a quarter that has no lake in it;
- the **other three roles permute over the other three quarters**, by the same
  R6 construction Highcourt's permutation uses with a prefix of its own, reduced
  modulo 3! = 6 instead of 4! = 24.

What that keeps is the property the permutation exists for: which district a
player walks into out of the south, the west or the north-west gate is the world
seed's and not the author's. What it gives up is that the lore district could
have stood anywhere, and the ground is what took that away.

### 3.2 The reach is 11 and not Highcourt's 13

Measured, for the reason above. It is still four nodes inside the contract's own
±15 plot volume, and it suits this race: "tall narrow halls" and "groves between
plots" is a smaller footprint with more green round it, not a wider one.

### 3.3 The lots were derived on NINE seeds, after two were shown not to be enough

The first version derived them on the two gate seeds, exactly as Highcourt's and
Dur Brannoc's are. The nine-seed verification then refused **seventeen of the
forty-four** — fourteen for a rise over the airspace the plot clears and three
for a fall past the foundation skirt — on seeds no earlier capital had ever
been measured against. A lot that is flat on two worlds is not a lot that is
flat: the terrace the fitting lays over the relief moves with the seed. The
committed tables are the nine-seed derivation, and
`tools/wp13/lethariel_plots.lua` with no argument re-checks all forty-four on
all nine.

**This is a finding for the other capitals**, not only for this one: Highcourt's
36 + 16 lots and Dur Brannoc's 9 were derived and are re-checked on two seeds,
and nothing in the tree has ever asked the other seven of them the same
question.

## 4. THE GROVE EDGE: an open capital's boundary

`wp13/elf_grove.lua` is `wall.lua`'s place in the composition with the masonry
taken out. It is an OVERLAY for the same reason a wall is — an anchor blueprint
is bounded at ±47 and a reference plot at ±15, while an envelope side is 513
nodes long and stands 250 nodes further out — and it is authored in the SAME
overlay as the avenues, because the successor's cross-run arbitration only
exists within one overlay and the road has to win the cells of the threshold it
runs through.

| Piece | Geometry |
| --- | --- |
| belt | two clipped rows of silverwood hedge on lanes ±2, three courses, each row following its OWN lane's ground, with kept turf between them |
| standard | a silverwood tree on the centre lane every twelve columns, crown reach two |
| lantern | a marble plinth carrying the palette's glowing block on the city-side lane every thirty-two columns |
| corner grove | standards on both belt lanes every third column for six either side of each envelope corner, and no hedge: a corner reads as a wood, not as a hedge turning a right angle |
| **threshold** | at each gate axis: two pairs of marble pillars, a lintel carried across the road on the centre lane and a lantern hung under it, with the seven middle columns left clear from the ground to the lintel for the road |

Three rules it is held to, and two of them the KAT found:

1. **No cell leaves the seam's activation band.** `bind_plan` offers a mapchunk
   a run when the chunk meets `at ± (half + 1)`, which is three either side of
   the centre line, so `M.HALF` is 3 and the KAT asserts no piece leaves it.
2. **A piece of a run is exactly that stretch of the whole run.** The first
   version wrote a standard's whole crown from its centre column, so a tree
   near a piece's edge had cells in the NEXT piece and the next piece never
   wrote them. The integration fixture found it as *"lethariel wrote 353 606 of
   353 834 cells"*. Every cell is emitted for the column it lands in now: a
   standard centred at `p0` is asked what it puts in column `p`, and every
   column asks every standard within two of it. The KAT cuts a 121-column
   stretch at every single column and compares the union with the whole, cell
   for cell.
3. **The arch clears the ROAD, not the ground.** This is the package's one
   blocker, found by the independent review of 2026-09-16, and it is worth the
   space because the mistake was a whole class of mistake and not a number.

   A threshold springs from one level so that it is one piece of architecture.
   The first two versions took that level from the GROUND: `lowest + 7`, then
   `max(lowest + 7, highest + 4)`. But `avenue.lua` does not lay its deck on the
   ground. It lays it on the ONE-LIPSCHITZ UPPER ENVELOPE of the surface over
   `REACH = 40` columns, so on ground that climbs towards the envelope line the
   road is already several nodes up when it reaches the gate. Measured over all
   four gates on all nine fixture seeds, driving the shipped `avenue.run` and
   the shipped `elf_grove.run` against WP40's own height session: **five of the
   thirty-six gate/seed pairs had less air over the carriageway than the road's
   own `MIN_CLEAR` of three, and on fixture seed 42 the north gate was ROOFED
   SHUT** — marble laid one node over the deck, across the whole five-wide
   carriageway, at exactly the column Lane R ends a route at.

   The threshold reads the same envelope the road reads now, from the same
   surface callback: the greatest `surface(q) − |centre − q|` within the
   look-around, over the seven positions of the gate point, taken along the
   ROAD's axis — which is this run's LANE axis, because the road crosses it.
   Kezamba's gate module reached the same answer from the same kind of render.
   The level is the highest of three rules: `lowest + RISE`, `highest + 4` and
   `road + MIN_CLEAR + 1`.

   **Two gates now measure it.** `tools/wp13/lethariel_kat.lua` section 6 builds
   the ROAD and the THRESHOLD over the same CLIMBING profile and compares the
   lintel with the road's top cell — the old section compared it with bare
   ground, which is why nothing was red; and
   `tools/wp13/lethariel_plots.lua --gates` re-measures all thirty-six pairs
   against the real height session (`evidence/gates.txt`). Worst air after the
   fix: **3**, which is `MIN_CLEAR` exactly; none below.

**THE BELT HAS NO WALK, and that is why it needs no walk-continuity gate.** A
curtain wall's hard property is that its rampart is walkable end to end over
stepped ground, which is what `wall.lua`'s one-Lipschitz envelope buys and what
a corner-tower step can break. This belt is a hedge and a line of trees standing
on the ground, each column written from its OWN lane's ground, so there is
nothing to walk and nothing to step.

The one piece with a level of its own is a threshold, and what it has to clear
is the ROAD. The clearance is therefore MEASURED and not argued: thirty-six
gate/seed pairs, `evidence/gates.txt`, worst 3 against a `MIN_CLEAR` of 3.

| seed | west | east | south | north |
| --- | --- | --- | --- | --- |
| 531802985935182545 | 6 | 6 | 3 | 5 |
| 8675309 | 6 | 4 | 3 | 4 |
| 15912857179583385436 | 6 | 4 | 3 | 5 |
| 0 | 6 | 4 | 3 | 4 |
| 1 | 5 | 4 | 3 | 3 |
| 2 | 6 | 3 | 4 | 4 |
| 42 | 5 | 5 | 3 | **3** |
| 12345 | 5 | 3 | 3 | 3 |
| 999999999 | 4 | 4 | 5 | 3 |

The bold 3 is seed 42's north gate, which before the fix was air **0** — the
gate sealed shut. An earlier draft of this note claimed the clearance held "on
any terrain whatever"; it did not, and the claim is gone.

**The belt stops at the water.** A run carries the spans of itself that stand
over planned water and writes nothing there, because a hedge floating on a lake
is not an edge and the lake already is one. Measured by
`lethariel_plots.lua --edge` over the seven lanes of each line: the west line
has one span, `z −143..−80`, the other three have none, and the answer is
identical on all nine seeds.

That used to be true by arithmetic accident. The standards are refused in wet
columns, but a standard's CROWN reaches two columns, and the column pass that
emits crowns ran over every column of a piece including the wet ones — so a dry
standard one or two columns from a span's end would have hung leaves over the
lake. On the committed west span the nearest dry standards happen to be three
columns clear, which is why nothing landed there and the KAT passed. The
independent review pointed it out; the column pass skips wet columns now, and
the property is a rule rather than a coincidence.

## 4b. THE BRIDGE: a water body stays one body

**The measurement first.** `tools/wp13/lethariel_plots.lua --bodies` floods the
planner's own water class over the ±266 window and counts connected bodies, then
counts them again with every column the overlay blocks at or below its water
surface knocked out. On the first version:

```
planned-water columns in +-266 = 39161
bodies BEFORE the roads: 2   sizes 38527 634    (the mere, and a separate pond)
columns the road runs pave:  2410
bodies AFTER  the roads: 7   sizes 26700 4954 2060 972 799 634 632
```

Six road runs cross the mere — the north and east avenues, the north and east
sides of the ring street, the mere precinct's shore walk and one north-west lane
— and between them they cut the lake into six. The north avenue alone sheared a
two-thousand-column bay off the main water. The independent review of 2026-09-16
measured it; **the coordinator's ruling is that a water body stays one body**,
and that where an avenue crosses water it runs as a bridge with the water
continuous beneath. Kezamba had just done the same thing with junglewood on
basalt piers.

**What ships.** `wp13/elf_bridge.lua` is a pure post-process on the piece
`avenue.run` returns. For every column the committed water plan calls wet:

| piece | what it is |
| --- | --- |
| the causeway | DROPPED — every cell the road wrote in that column, the verge's lamp standard included, because it stood on the water |
| the deck | `max(the road's own top cell, water + lift)`. The water is the LOWEST of the carriageway's own five lanes, and the lift RAMPS: nothing at a span's first and last column, a node a column inwards up to 1. See "two corrections" below |
| its width | seven lanes — the five of the carriageway in the road's own paving and kerb, and a plank verge either side under a **rail**, so a walker cannot step off into the mere |
| the piers | marble, on the two VERGE lanes and nowhere else, every 8 columns, reaching 4 nodes under the water surface |
| the lanterns | one on the deck every 16 columns, because the road's own standards went with the causeway |

**The piers are on the verge on purpose.** It is the whole of why the lake stays
one lake: the five-wide carriageway is open water underneath, along the run and
across it, so the water flows under the bridge and past every pier. The blocked
columns are the piers and the abutments alone.

```
planned-water columns: 39161
columns the overlay takes out of the water surface: 152
    (152 paved solid, 0 cleared to air)
per run: avenue_north=34 avenue_east=19 ring_east=21 ring_north=38
         lane_northeast_shore=24 lane_northwest_cross=16
bodies BEFORE: 2  sizes 38527 634
bodies AFTER:  2  sizes 38375 634
```

**One body before, one body after.** The mere loses 152 of its 38 527 columns to
piers, abutments and the four quay-side runs, and stays a single sheet of water
a boat can cross.

### 4b.1 Two corrections the rebase onto Lane R forced, and one the built map did

The first version of this bridge passed its own KAT and its own `--bodies`, and
was still wrong twice over. Both faults were found by MEASURING THE SHIPPED
COMPOSITION rather than the model of it, which is the lesson worth keeping.

**(1) The deck read the bank instead of the water, and the lift did not ramp.**
Lane R's `route_gates.lua` walks a traveller from sixty-four nodes outside a gate
into the city and refuses any position that climbs more than a node. Its
question, asked of this composition by the new `lethariel_plots.lua --routes`,
found six such places — all of them the first plank of a bridge:

```
BREAK at p=151 36 -> 38 (wet)
   p=150 centre=36 surface=36 dry
   p=151 centre=38 surface=36 wet
```

The deck took the MAXIMUM surface over all seven lanes and added the lift. At the
shore a column has wet lanes and dry ones, and the dry bank stands above the
water, so the maximum read the bank: the bridge started two nodes over the road
it continues. The fix is in the table above — the water is the MINIMUM over the
carriageway's own five lanes, and the lift RAMPS from nothing at the span's first
and last column. Both terms are 1-Lipschitz in the column, so the deck still is.
After it, `--routes` reports **36 gate/seed pairs, worst step 0 against a limit
of 1, and no walk-in position that climbs more than a node**.

**(2) The bridge was not damming the mere — it was EMPTYING it.** The first
version cleared the cell one under the deck unconditionally, to say in the piece
itself that nothing of the road stands between the deck and the water. With a
lift of one node that cell IS the water surface. The seam's writer takes water
out as willingly as it puts it in, so the built map carried a five-wide trench of
AIR down the middle of the mere under every crossing — 2172 cells of it — and the
water surface inside the avenue's own corridor came apart into two sheets. The
`--bodies` model could not see it because it only counted SOLID cells, and the
KAT could not see it because it only asserted "not one solid cell at or under the
water line". Both now count air, and the negative control is recorded:

```
with the old clear:  152 paved solid, 2389 cleared to air
                     bodies 2 -> 7   sizes 26647 6997 962 789 634 622 1
with the fix:        152 paved solid,    0 cleared to air
                     bodies 2 -> 2   sizes 38375 634
```

The clear now runs from one node OVER the lane's own surface up to one under the
deck, and is empty for a lift of one. The built map on seed 531802985935182545
says the same thing from the other side (`evidence/built-map-*.txt`): **368
carriageway columns over the lake, 368 of them open water at the surface, 0
solid, 0 holes**, 19 piers on the verges, and the avenue corridor's own water one
connected sheet of 1826 columns. `renders/bridge-piers.png` is that cut at the
water line: two rows of pier tops, and nothing else between them.

**Why a committed water plan and not a water query.** An overlay is handed
`surface(x, z)` and nothing else — there is no water predicate at that seam, and
inventing one would be a second authority for where the lake is. The spans are
measured from WP40's own `water_class_at` by `--water`, which also proves they
are identical on all nine fixture seeds, and they live in `M.water_plan` beside
the runs they belong to. `evidence/water.txt` is that measurement.

**Four KAT rules hold it** (`lethariel_kat.lua` section 7, over a synthetic
lake): not one solid cell at or under the water line on the whole carriageway;
NOT ONE CELL OF ANY NAME there, air included, so the water under the deck is the
terrain's own and the bridge leaves it alone; the deck present for every column
of the span, over the water, never stepping more than a node, and no more than a
node from the bank it lands on; and the span cut at every column with the union
compared to the whole, cell for cell — the piece-independence property the seam
needs. The two "not one cell" rules both allow exactly TWO columns, the span's
own first and last: those take no lift, lie flush with the road they continue,
and are the bridge's abutments. Put the old clear back and the KAT says *the
bridge writes into 138 carriageway columns at or under the water line, and not
just its two abutments*.

## 4c. THE GATE POINTS: where Lane R's routes end and this city's road begins

The rebase onto `f5583e13` brought WP40's routes to a stop at the twenty-four
published gate points (`source.capital_gates`, ±256 on the axes). Four of them
are this capital's, and the seam between them and this city is a number: the
height the route's own graded surface reaches at that column, against the height
the avenue is BUILT at there. A two-node kerb at a gate is a city you jump into.

**Measured on the shipped composition, all four gates × nine seeds**
(`lethariel_plots.lua --routes`, `evidence/routes.txt`):

```
36 gate/seed pairs, worst step 0 against a limit of 1
every avenue meets its route end, and the walk in never climbs more than a node
```

Thirty-six pairs, **every one of them step 0**, and the walk from sixty-four
nodes outside the gate in to the core edge — route surface where only the route
is, built avenue where the overlay covers the column — breaks nowhere.

**Why this lane has its own tool for it.** `tools/wp13/route_gates.lua` asks the
same question for all six capitals, and it builds the CONTRACT's generic avenue
to do it: `avenue.run` over 48..261 in the race's plain palette. That was the
right call when four of the six blueprints did not exist, and it cannot see two
things about this one — its north avenue starts at z = 22, not 48, because the
civic pad ends at the mere, and its north and east avenues carry a bridge. So
`--routes` asks it again of `capital.overlay_run`, which is the composition that
actually ships.

**Lane R's own tool agrees**, run `--strict` on the nine fixture seeds and on
seed 7 (`evidence/route-gates-strict.txt`): for `elandor_lethariel`, **gate step
0 at all 40 gate/seed pairs, entry 0 breaks at all 40, avenue discontinuities 0
(with 368 wet columns on the east avenue and 549 on the north), and not one
Lethariel fault of any kind.** The nine `FAULT` lines those runs print are all
`kragmar_nhal_veyr`'s north gate, which is another lane's capital; that is why
the loop's overall exit is 1 while every Lethariel row is clean.

**The one number Lane R's note raises about this city** is its question 7, the
TERRAIN step over the eight columns just inside the gate: it lists Lethariel
north as 6. The forty measured values here are 0 (×3), 1 (×6), 2 (×18), 3 (×10),
4 (×2) and 6 (×1, seed 42 north), against the tool's limit of twice the largest
terrace rise — 12 for a step-3 capital. So the worst of them is half the limit,
and it is not a fault. It is also not the road: the avenue's own envelope crosses
it at a constant deck, which is what question 6 measures and passes. It is the
natural bank the grove edge stands on, and the honest description is that on one
seed of nine the ground beside the north threshold falls away in two terraces
rather than one.

## 5. The core, and the socket table

96 × 96, bounds x/z [−47, 47] and y [−2, 31] inside the contract's [−2, 40].
Two palette handles: `elf`, the Silverleaf palette with this capital's four
added roles (water, hedge, tilled soil, crop), and `pale`, the same under the
silver-sandstone civic roof AND the silver-sandstone civic masonry.

**The second rebinding is the render's doing.** Every capital part in
`wp13/capitals.lua` builds its structure out of `castle_wall`, and the elf
palette binds that to `castle_stonewall` — the brown rubble wall five other
races use. The first render of this capital's king's hall was a brown castle
with pale trim: Dur Brannoc's material in Lethariel's plan, and not the
contract's "silverwood and marble, tall narrow halls". The civic handle binds
the pale cut of the same silver sandstone its roof and its pillars are already
made of, so the CIVIC quarter is pale stone and the city round it stays
silverwood and slate. The market square, the houses, the groves, the road and
the grove edge all take the PLAIN handle — `r7_lethariel_blueprint.lua` hands
the overlay `elf.handles().elf` and nothing else — so no cell of any street
changed by construction.

The probe's `avenue` digest moved with the rebinding all the same, and the
reason is worth writing down because it is easy to read as a road that moved:
the probe dumps a BOX of the finished map, `x 40..260, z ±12`, and the first
seven columns of that box are inside the civic core, where the east gatehouse
stands. The digest is of a region, not of a road.

`elf_parts.lua` is the only place either handle is made, which is what lets the
KAT read both of them when it asks whether an open capital's boundary carries a
curtain (section 6(a)): reading one handle would make that rule vacuous the
moment a handle rebinds the role — which is exactly what happened here.

| Quarter | What stands there |
| --- | --- |
| South-west | the **Hall of the Silver Boughs**, the king's hall: the library's 31 × 27 basilica on its podium, its great door east onto the throne approach |
| South-centre | the throne approach from the south gate, the two **colonnades** flanking it — the contract's own word for this race |
| South-east | the **market square** (21 × 21), the two royal booths on the market walk, the **travel plaza** reserved for WP17, a bough house and two cottages |
| West | the **Hall of Stars** (the library's temple, carrying the capital's core quest shell), the **fountain court** and two houses on the quay walk |
| East | the **sacred grove** — seventeen nodes of standing silverwood inside the civic core, which is what the WP40 profile `terraced_grove` means when a city is built in it — the **shrine** at the head of its walk, and the **shore works** |
| North | the **mere**, the marble **quay** along its edge and the head of the causeway |
| The boundary | no parapet and no wall: a clipped silverwood **hedge** walked round the whole ring, breaking by itself at every gate, plot and street |

Eighteen plots, 27 silverwood standards, 25 lantern pillars, 171 columns of
hedge, 100 columns of quay.

**The core edge is measured, not asserted.** The KAT does not test "no masonry
on the boundary" — the three inner gatehouses stand on it and are masonry — but
that **no unbroken run of castle masonry on the boundary rings is longer than a
gatehouse**. The longest is 4.

### 5.1 The socket table

The settlement registers **253** sockets, which is the Highcourt standard's 256
within three.

| Role | Count |
| --- | --- |
| `king` | 1 |
| `waypoint` | 1 |
| `quest` | 2 (the Hall of Stars' and the mere shrine's) |
| `vendor` | 9 |
| `guard_post` | 14 |
| `guard_patrol` | 43, in **8 loops**, each 1..n with no gap |
| `work` | 53 |
| `idle` | 130, of which **24 are SPARE** (`spawn = false`, no tag) |

**Residents 159, walkers 22**, which is 138 per mille. Three bands, all met:
the contract's own 10–30 per cent walker share (section 8.3); the coordinator's
wave-2 ceiling of 150–170 residents and at most 25 walkers per capital
(Highcourt's 144 / 22 is the reference); and section 8.3's arithmetic rule of at
least one `idle` spawn socket per `work` socket — 106 against 53, a factor of
two to spare.

**Thirteen activities**: `brew` 4, `carve` 3, `chop` 4, `farm` 4, `fish` 3,
`forage` 3, `mourn` 2, `pray` 6, `sit` 8, `spar` 5, `stall` 4, `sweep` 1,
`tend` 6. Every one of them faces the feature its activity names within three
nodes, by the same search `highcourt_kat` runs: the socket's own course and the
one either side of it, stopping at the first solid node on the course.

Two of those sets are NARROWER here than in `highcourt_kat`, both on purpose:

- **`tend` accepts a flower, a flower pot or a crop and nothing else** (the
  contract's "a plant or a flower", and the coordinator's wave-2 ruling). All
  six `tend` sockets face a cell `dressing.plant` wrote, which breaks the kerb
  of a raised bed at the one cell the gardener reaches into and grows the
  palette's own flower there. A hedge, a leaf or a tuft of grass would have
  passed the wider set and does not pass this one;
- **`spar` accepts a fence post or a wool node**, which is what the contract's
  wave-2 table says. The training dummies are authored as exactly that rather
  than taken from `dressing.drill_post`, whose post is a LOG — which is
  `chop`'s feature and not `spar`'s.

**Nine vendor kinds**, at most one each: `race` and `general` in the core,
`bowyer`, `tailor` and `baker` in the market district, `armourer` in the
martial, `herbalist` and `fishmonger` in the mere precinct, `brewer` in the
residential. Four of them — bowyer, armourer, herbalist, brewer — are wave-2
kinds whose entities the traders mod has not registered yet; section 6(e)
records exactly what the engine says about that.

## 6. Verification

### (a) The KAT, both interpreters

`tools/wp13/lethariel_kat.lua` is Highcourt's acceptance for the core, every
plot and the avenues — envelope and budget, canonical unique cells in canonical
order, the byte-sorted palette, every emitted name registered, the bounds equal
to the real extent, every light on the support its wallmount names, the socket
contract with `dir` derived from the facing, feet and head air over walkable
ground, the closed activity vocabulary, the feature under `dir`, one vendor per
kind across the whole capital, every loop 1..n, the spare shape, the 80/20
arithmetic, per plot the reference column, the skirt to −6, the published
`clear_to` and the lot it fits in — **plus four sections of its own**:

- **the mere**: the core's silent columns form one contiguous run per row, the
  run never narrows northward, its tip is at z = 22, it covers exactly 26 rows,
  and the causeway's seven lanes are inside it on every one of them;
- **the open edge**: the longest unbroken run of castle masonry on the boundary;
- **the lots**: all 44 against the envelope, the core, the gate corridors, every
  street run, the quarter rule and the lane, plus every plot inside the lot it
  stands on;
- **the permutation**: all six indices are distinct bijections, the fixed role
  never moves, and three seeds reproduce themselves;
- **the threshold over the road** (section 6, added by the fix round): the ROAD
  and the THRESHOLD built over one CLIMBING profile, the lintel compared with
  the road's own top cell, `MIN_CLEAR` asserted, and nothing of the threshold's
  in the road's headroom. `grove.CLEAR == avenue.MIN_CLEAR` is asserted too, so
  the two modules cannot drift apart on the number itself;
- **the bridge over the water** (section 7): over a synthetic lake, not one
  solid cell and not one cell OF ANY NAME — air included — at or under the water
  line on the whole carriageway, except at the span's own two abutment columns;
  a deck for every column of the span, over the water, never stepping more than
  a node and never more than a node from the bank it lands on; and the span cut
  at every column with the union compared to the whole.

```
WP13 FINAL MICRO PAIR BYTE-IDENTICAL   (on f5583e13, 2026-09-16)
83b500d34fd477fe1f8255d07f94325b09f80405b833f7a3bfede632dea940b4  micro-luajit.tsv
83b500d34fd477fe1f8255d07f94325b09f80405b833f7a3bfede632dea940b4  micro-puc51.tsv
```

The KAT's own nine rows are byte-identical under LuaJIT and PUC 5.1 as well
(`evidence/kat.txt`).

That is the whole WP13 fixture set in one process under each interpreter, this
KAT among them. Its own rows are `lethariel_core`, `lethariel_district`,
`lethariel_sockets`, `lethariel_activities`, `lethariel_lots`,
`lethariel_overlay`, `lethariel_edge`, `lethariel_gates` and
`lethariel_bridge` — the last two added by the fix round of 2026-09-16.

### (b) The six starts, Highcourt and Dur Brannoc are untouched

`identity.txt`: the identity digests `r7_settlement` computes for all six starts
and for both earlier capitals, from `tools/wp13/integration_fixture.lua` on this
tree — the fixture that also proves every mapchunk writes exactly the cells the
blueprints claim, for every settlement including this one, and which found two
defects in this package while it was being written.

This lane changed no shared module. The diff against the base is THREE files,
and two of them are one appended row each: `r7_settlement.lua`'s roster entry
and `final_micro.lua`'s KAT line. The third is `docs/design/settlements.md`.
`highcourt_kat`, `dur_brannoc_kat`, `library_kat` and `blueprint_kat` all run
green inside the micro pair on this tree.

### (c) Build time and budget

| Subject | Cells |
| --- | --- |
| core | 91 332 of the contract's 150 000 |
| 44 plots | 219 253, largest 7 978 of 12 000 |
| overlay on the KAT's synthetic terrace | 52 671 (road and bridges 24 558, grove edge 28 113) |
| **whole capital** | **363 256 of 400 000** |

Engine-side build times, from the probe's own `build_us` on gate seed
531802985935182545: module load 17.5 ms, the core 126.2 ms, the 44 plots 460.6
ms together. The contract's "builds in a few seconds under LuaJIT when first
touched" is **0.60 s** for the whole capital, and it is paid once, lazily, on
the first mapchunk that touches the envelope.

### (d) Per-mapchunk cost

`probe-531802985935182545.txt`, one cold boot, the tree this package ships.
The corpus is the mapchunks the capital's blueprints, avenues and edge actually
touch, derived from the real geometry, plus two kinds of control.

| Kind | chunks | first | steady mean | worst |
| --- | --- | --- | --- | --- |
| warm-up (not counted) | 1 | 25.7 s | — | — |
| **Lethariel** | 100 | 0.78 s | **0.57 s** | 1.08 s |
| a capital with no WP13 cells (control) | 8 | 12.9 s | 2.51 s | 15.1 s |
| open land and a start (control) | 3 | 0.82 s | 0.75 s | 1.49 s |

The warm-up mapchunk carries the emerge environment's whole one-time R7
construction, which is why it is emerged first and not counted. The capital
control is the honest one: WP40 fits, flattens, terraces and protects it exactly
like Lethariel and it has no WP13 blueprints at all.

Against the contract's "no more than 2× the ~0.5 s Dawnmere chunk": **0.57 s**.
Lethariel's mapchunks are **four times cheaper than the control capital's** and
sit BELOW the open-land control's own mean, so this settlement's contribution —
grove edge included — is inside the noise of the terrain work around it.

100 mapchunks against Highcourt's 33 and Dur Brannoc's 85: four district lanes
and a 513-column edge belt on each side touch every mapchunk on the ring.

### (e) Engine

**NINE SEEDS, not three** (the coordinator's wave-2 rule of 2026-09-15, after
the first two capital reviews found lots and a tower step on seeds a lane had
skipped). `tools/wp13/run_capital.sh <out> lethariel full <seed>` on the two
gate seeds and the user's seed — the whole emerge, the timings, the socket
inventory and the read-back digests — and `... surface <seed>` on the other six,
which is a cold boot each and is what runs the seam's load-time `audit_terrain`
against the world that boot has and samples every plot's fall, rise and
submerged columns on it.

All nine: **`exit=0`, `complete=1`, NO FINDING from the terrain audit, and no
plot submerged on any world.** The three full passes additionally emerged the
capital one mapchunk at a time and placed the NPC roster.

The three full passes:

| | 531802985935182545 | 8675309 | 15912857179583385436 |
| --- | --- | --- | --- |
| mapchunks requested / completed | 112 / 112 | 104 / 104 | 104 / 104 |
| the capital's own mapchunks | 100 | 92 | 92 |
| steady mean per mapchunk | 0.52 s | 0.55 s | 0.58 s |
| sockets registered | 253 | 253 | 253 |
| loops | 8 | 8 | 8 |
| residents / walkers / spare | 159 / 22 / 24 | same | same |

And all nine, which is what `evidence/audit-nine-seeds.txt` is
(`worst_plot_fall` against the foundation skirt of 6):

| seed | mode | worst plot | fall | submerged | Lethariel audit findings |
| --- | --- | --- | --- | --- | --- |
| 531802985935182545 | full | `market_fountain` | 6 | 0 | **0** |
| 8675309 | full | `market_fountain` | 5 | 0 | **0** |
| 15912857179583385436 | full | `market_paddock` | 6 | 0 | **0** |
| 0 | surface | `martial_woodyard` | 6 | 0 | **0** |
| 1 | surface | `market_paddock` | 6 | 0 | **0** |
| 2 | surface | `market_close` | 5 | 0 | **0** |
| 42 | surface | `mere_walk` | 5 | 0 | **0** |
| 12345 | surface | `market_close` | 4 | 0 | **0** |
| 999999999 | surface | `mere_lore_hall` | 6 | 0 | **0** |

The seeds touch different numbers of mapchunks and their worst plot is a
different plot, because they draw different permutations and a district in a
different quarter is a different set of chunks. On every one of them the fall
stays inside the skirt and no plot has a wet column.

**THE FIX ROUND'S OWN THREE PASSES** (2026-09-16, on the tree that ships): the
gate seed again, **seed 42** — whose north gate the review found sealed — and
**seed 7**, the edge-coverage seed whose anchor root lands on a mapchunk's
lowest layer. All three `exit=0 errors=0 complete=1`, zero Lethariel audit
findings, 253 sockets, 8 loops, no submerged plot:

| | 531802985935182545 | 42 | 7 |
| --- | --- | --- | --- |
| mapchunks | 112 / 112 | 104 / 104 | **114 / 114** |
| steady mean | 0.53 s | 0.52 s | 0.50 s |
| worst plot fall (skirt 6) | 6 `market_fountain` | 5 `mere_walk` | 5 `homes_longhouse` |

**And the BUILT MAP answers the two questions the fix round exists for**
(`evidence/mapcheck.py` over the probe's own read-back dump,
`evidence/built-map-<seed>.txt`):

```
== the east threshold, x = 256, seed 531802985935182545 ==
  the road's deck at the gate: y = 50
  the threshold's pillars: 6 columns, top course y = 56
  the lintel one course over them:  y = 57
  air over the carriageway: 6  (MIN_CLEAR 3) -> OK

== the mere in the avenue dump ==
  carriageway columns over the lake: 368
    open water at the surface: 368
    solid at the surface:        0
  carriageway deck columns whose surface layer is air (a hole): 0 -> OK
  verge columns over the lake: 149, of which 19 carry a pier
  connected bodies of that surface inside the dump window: 1  sizes [1826]
```

The deck at 50 and the lintel at 57 are exactly what the offline model predicts
for this gate and seed, which is the model's own validation; the dump's ceiling
is one node under the lintel course, so the pillars' top is what the map itself
shows. **Not one solid cell and not one hole stands on the carriageway at the
water line, and the lake under the bridge is one sheet.** The body count in that
dump is the AVENUE CORRIDOR's — seven lanes and their verges — so it says the
strip is continuous, not that the mere is; the mere's own count is `--bodies`
over the whole 533 × 533 window, and it is the number in section 4b. Section
4b.1 is what this same dump said before the fix: 281 open, 0 solid and 93 holes,
two sheets.

**THE REBASE PASS, 2026-09-16, on `f5583e13` and the tree that ships.** One
`full` pass on 531802985935182545, port 31207, `nice -n 19`, with Lane D's fixed
digest loop:

```
exit=0 errors=0 complete=1
avenue overlay digest recorded (no committed value for seed ... yet)
rampart: this capital publishes no such overlay region
gate:    this capital publishes no such overlay region
WP13 capital pass PASS: lethariel full /tmp/grug-w2-leth-r2
```

**`run_capital.sh full` now says PASS for an open capital** — the abort described
in open point 1 is fixed in `main`, and the two "publishes no such overlay
region" lines are the runner saying so out loud instead of exiting. The pass
itself: 112/112 mapchunks, 100 of them the capital's, **steady mean 0.527 s**
(worst 1.14 s, best 0.13 s), 253 sockets, 8 loops, `worst_plot_fall=6`
(`martial_woodyard`), `worst_plot_submerged=0`, and the read-back digests in
`evidence/overlay-digests-531802985935182545.txt`.

**THE AUDIT FINDINGS THOSE BOOTS DID CARRY ARE OTHER CAPITALS'.** Twelve of
them, over six of the nine seeds: eleven Highcourt plots and one Dur Brannoc
plot that "do not stand on this world's ground" — a perimeter fall of up to 14
against a skirt of 6, a rise of 10 against a clear of 8. Both capitals' lots
were derived on the two gate seeds, and these are the seeds nobody asked. The
full list with its numbers is in `evidence/audit-nine-seeds.txt`; it is reported
and not fixed, because those are not this lane's files.

The roster line the placement engine ends on, gate seed 531802985935182545:

```
start npcs elf lethariel: guards 16/22 flair 104/159 vendor 4/9 quest 1/2
                          new 27 pending 67 spare 24 residents 159 walkers 22
```

`pending` is not a failure: a capital is not preloaded, so its roster is placed
as its areas are actually emerged and its outlying district plots fill in as a
player walks up to them (settlements.md). What is reproducible is the
denominators — 159 residents, 22 walkers, 24 spares, and now **9 vendors of 9
distinct kinds** — and they are the KAT's own numbers.

**ALL NINE VENDOR KINDS RESOLVE**, which is what the rebase onto `c8050057`
bought. Before it, the four wave-2 kinds this capital places — `bowyer`,
`armourer`, `herbalist`, `brewer` — produced one `resolves to no registered
entity` ERROR line each on every seed. That is the behaviour the sockets
contract's section 8.4 promises ("an error line at placement and an empty
socket, never a load failure"), and the NPC vocabulary lane has since registered
the entities: `errors=0` on all nine boots.

### (f) Static gates

`static.sh` / `static.txt`: `tools/bin/luac51 -p` and the SETGLOBAL count on
every file this package touched (all PASS, all zero globals), the whole `mods`
and `tools` trees parse under plain 5.1, and the five plain-5.1 sweeps scoped
first to the touched files and then to `mods/*/grug_*` and `tools/wp13`. Two
sweep hits this package contributes, both the same patterns the committed tools
beside it already carry:

- `os.exit` in `lethariel_plots.lua`, the standalone-CLI pattern
  `highcourt_plots.lua` and `capital_plots.lua` have carried since the seam
  package; the file is never loaded by the engine;
- one sweep-4 hit on `table.concat(rows, "|")`, which is a string literal and
  not a bit operator — the sweep's regex cannot tell them apart.

`check_fresh_server.py` PASS.

## 7. Open points

1. **CLOSED on 2026-09-16 by Lane D, kept here because the numbers in section
   6(e) were taken under it.** `run_capital.sh:170` aborted for a capital with
   no rampart and no gate, which is what an OPEN capital is. In `full` mode it
   walks
   `for label in avenue rampart gate` and assigns

   ```sh
   digest="$(grep -o "${label}_road_digest=[0-9a-f]*" "$log" | tail -1 | cut -d= -f2)"
   ```

   Under the script's own `set -euo pipefail` the assignment takes the
   PIPELINE's status; `grep` returns 1 when it matches nothing; so the shell
   exits **before** the `[[ -n "$digest" ]] || continue` guard on line 174 can
   fire. Lethariel's probe publishes `core`, `plot` and `avenue` and no rampart
   or gate, so the run ends after the avenue digest and before the final `PASS`
   line, on a boot whose own report is `exit=0 errors=0 complete=1` with zero
   warnings and zero audit findings. `surface` mode never reaches the loop and
   does print PASS.

   The independent review reproduced it and Kezamba met it independently. Lane
   D's fix is in `f5583e13`, and on that tree this capital's `full` pass ends
   with `WP13 capital pass PASS` and two plain lines saying the capital
   publishes no rampart and no gate region. The `full` rows of section 6(e) that
   predate the rebase are still judged from their own logs, which is why they
   are quoted rather than summarised.

   The gate's OTHER half is fine: before the rebase onto `c8050057` the same
   passes carried four `resolves to no registered entity` ERROR lines for the
   wave-2 vendor kinds, which the sockets contract's section 8.4 sanctions and
   the runner's `grep -c ERROR` could not tell from a defect. The NPC vocabulary
   lane registered those entities and the count is zero now.
2. **`capital_plots.lua` cannot express a four-district capital.** It reads
   `capital.district.plots` (one district), and `capital_probe`'s `scan` mode
   sweeps `x 52..204, z −96..96`, which is the quadrant Dur Brannoc's single
   district stands in. (Lane D has since fixed the probe's district LABELLING —
   it passes the seeded permutation now, so `probe-*.txt` and the renders in
   this package name the quarters the world actually uses; on seed
   531802985935182545 that is `lore_spiritual=northeast`,
   `market_professions=northwest`, `martial_garrison=southwest`,
   `residential_cultural=southeast`, `permutation=2,3,1`. The scan window is
   unchanged.) That is why Highcourt has a tool of its
   own and why `lethariel_plots.lua` exists beside it. **The gap is reported and
   not closed** — Lane D owns those files. The shape this lane suggests is the
   one it used: read `wp40/height.lua` and `wp40/simple_map.lua` directly, as
   `capital_terrain_fixture.lua` already does, and take every seed.
3. **The other capitals' lots have never been measured on more than two seeds,
   and twelve of them are illegal.** This capital's nine-seed engine sweep says
   so from the other capitals' own load-time audit, and the independent review
   reproduced it: **eleven Highcourt plots and one Dur Brannoc plot** "do not
   stand on this world's ground" on six of the nine fixture seeds — perimeter
   falls of 7, 8, 8, 10, 10, 10, 12 and 14 against a skirt of 6, and a rise of
   10 against a clear of 8. The worst is seed 999999999, which alone carries six
   Highcourt findings and the Dur Brannoc one.
   `evidence/audit-nine-seeds.txt` lists every line with its numbers. Both
   capitals need a nine-seed lot pass of their own; section 3.3 is the method
   finding behind it, and `lethariel_plots.lua --derive` is the shape such a
   pass can take.
4. **The edge-coverage seed is 7, and it is clean.** A root lands on a chunk's
   lowest layer exactly when `anchor_y ≡ 47 (mod 80)`. Over the nine seeds of
   `capital_anchor_fixture.lua`, anchor_009's `anchor_y` is **41, 36, 36, 42,
   53, 36, 36, 36, 39** — not one of them qualifies, so the brief's fourth
   engine seed does not exist inside the fixture set. The independent review of
   2026-09-16 went looking outside it and found **seed 7: `anchor_y` 47, root
   48, a mapchunk's lowest layer** (13, 777777, 4242424242 and 99 also give
   roots on or near one). `tools/wp13/lethariel_plots.lua --seeds` lists it
   beside the nine as the edge-coverage seed and this package carries a full
   engine pass on it (section 6(e)). It is deliberately NOT added to
   `capital_anchor_fixture.lua`: that roster is Lane R's.
5. **The mere's shore is committed data.** A blueprint is a fixed cell list
   built once at load with no world to ask, so the wedge is a table and
   `lethariel_plots.lua --shore` is what keeps it honest. The day WP40 moves
   this lake the fixture says so and the table is re-taken — the same
   arrangement the built-road digests have.
6. **The grove edge publishes no NPC sockets.** An overlay has no `landmarks` in
   the seam at all, so nobody stands at a threshold. The city's garrison is the
   core's three inner gatehouses and the districts'. Dur Brannoc's section 9
   records what a manned overlay would need; nothing here changes it.
7. **The three remaining districts of the mere precinct.** It has three plots
   where the others have nine, and the ground is why. If a later WP40 revision
   opens the far shelf, the roster can grow without touching anything else.
8. **The rebase onto Lane R is done and it moved nothing under a lot.** That
   lane ends every WP40 route at the four gate points and leaves no route cell
   or bridge deck inside the 512 envelope; this capital's avenues already ran to
   those exact points and nothing here reads a route cell. Re-run on
   `f5583e13`, `luajit tools/wp13/lethariel_plots.lua .` reports **all 44 lots
   dry, inside the skirt and under their own roof on all nine seeds**, so
   neither table had to be re-derived. `--derive` and `--derive-fill` remain the
   one command each that would re-take them.
9. **Two things the review's eye caught that this lane did NOT change, because
   changing them is a design decision and not a defect.** (a) The core's three
   inner gatehouses are crenellated masonry towers and they dominate
   `core-overview.png`: the city can read as a pale CASTLE rather than an elven
   grove city, which is close to what section 2.4's "no curtain wall,
   colonnades, groves between plots" steers away from. The contract's own
   section 2.1 lists `gatehouse` among a capital's parts and every capital so
   far has them, so replacing them with something lighter — a colonnaded gate,
   a pair of bough towers — wants a ruling rather than a commit. (b)
   `plot.png` is one small house alone on a wide terrace, with no grove, hedge
   or lantern round it; that is one sample of forty-four, and it is the
   "far less finished" complaint Dur Brannoc drew. Both are for the user's eye
   at the playtest.
10. **The user has not walked Lethariel.** Nothing here is accepted until they
   have. On seed 531802985935182545 the crossing of the two great avenues — the
   `arrival` landmark, with the guard banner on it — is at **(1800, 42, −1500)**.
   Walk NORTH from it: the quay is twenty nodes on, and the causeway leaves the
   city across the water from there. The king stands in the hall west of the
   approach; the two traders are on the market walk south-east of the crossing;
   the sacred grove and the shrine are east of it.
