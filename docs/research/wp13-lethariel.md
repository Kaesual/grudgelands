# WP13: Lethariel, the elf capital and the first one built round a lake

Increment record, 2026-09-15, written against `main` at `922bfd92` ("Extend the
socket vocabulary for the wave-2 capitals") and rebased onto `c8050057` ("Merge
the wave-2 NPC vocabulary"), which is what makes this capital's four wave-2
profession vendors resolve to real entities. It is the fifth increment of the
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

Evidence: `tools/wp13/evidence/20260915-lethariel/`.

## 1. What shipped

| File | Change |
| --- | --- |
| `wp13/elf_parts.lua` | **new**: the two capital palette handles this race needed — the four green roles (hedge, water, tilled soil, crop) and the pale civic masonry — and three parts no library had: the **threshold**, the **tree platform** and the **shrine** |
| `wp13/elf_grove.lua` | **new**: the GROVE EDGE, an open capital's boundary as an overlay — `wall.lua`'s place in the composition with the masonry taken out of it |
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

**The avenues need no code at all.** The seam hands a road the WATER surface
where water stands rather than the bed under it
(`r7_settlement.lua`, `walkable_values`, the rule Highcourt's river bought), so
`avenue.lua` builds a solid CAUSEWAY at the water line. The north avenue crosses
the mere as one, and so does the east avenue where the lake's southern arm
reaches it. Over the seven-lane band of each run between the core edge and the
gate station (z or x 48..261, 1 498 lane-columns each): **768 of the north run's
and 517 of the east run's stand over planned water**, and none of the south's or
the west's.

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
lane clear of its neighbours — a greedy packing of Lethariel's four quarters
gives, at Highcourt's own reach of 13:

| quarter | legal positions on a 4-node grid | greedy packing |
| --- | --- | --- |
| south-east | 1 297 | 26 |
| north-west | 1 313 | 26 |
| south-west | 1 448 | 28 |
| **north-east** | **110** | **3** |

At reach 11 the north-east rises to 7 packed and to **3 once the quarter rule is
applied**, and the other three still carry nine each with room to spare. Four
interchangeable quarters do not exist at this capital.

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
3. **The arch clears the road at both ends of its own zone.** A threshold
   springs from one level so it is one piece of architecture, and the first
   version took that level as `lowest + 7`. On ground that climbs across the
   zone the lintel then came down to four courses over the carriageway at the
   high end — head height. The level is the HIGHER of `lowest + 7` and
   `highest + 4` now, and the KAT asserts `avenue.MIN_CLEAR` of air under it at
   every column of the passage.

**THE BELT HAS NO WALK, and that is why it needs no walk-continuity gate.** A
curtain wall's hard property is that its rampart is walkable end to end over
stepped ground, which is what `wall.lua`'s one-Lipschitz envelope buys and what
a corner-tower step can break. This belt is a hedge and a line of trees standing
on the ground, each column written from its OWN lane's ground, so there is
nothing to walk and nothing to step. The one piece with a level of its own is a
threshold, and it clears the road by construction rather than by luck: its level
is `max(lowest + 7, highest + 4)` over its own sixteen-column zone, so every
column of the passage has at least `highest + 4 − (its own ground) ≥ 4` — the
avenue's own `MIN_CLEAR` of three blocks of air, plus the deck — on any terrain
whatever. The KAT asserts it on a synthetic profile that steps three nodes per
terrace, which is this race's step.

**The belt stops at the water.** A run carries the spans of itself that stand
over planned water and writes nothing there, because a hedge floating on a lake
is not an edge and the lake already is one. Measured by
`lethariel_plots.lua --edge` over the seven lanes of each line: the west line
has one span, `z −143..−80`, the other three have none, and the answer is
identical on all nine seeds.

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
  never moves, and three seeds reproduce themselves.

```
WP13 FINAL MICRO PAIR BYTE-IDENTICAL
c7268068f12b54487bf30339533bfbbcd62087df5b9b5502be07d901de8a7006  micro-luajit.tsv
c7268068f12b54487bf30339533bfbbcd62087df5b9b5502be07d901de8a7006  micro-puc51.tsv
```

That is the whole WP13 fixture set in one process under each interpreter, this
KAT among them. Its own rows are `lethariel_core`, `lethariel_district`,
`lethariel_sockets`, `lethariel_activities`, `lethariel_lots`,
`lethariel_overlay` and `lethariel_edge`.

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
| overlay on the KAT's synthetic terrace | 47 941 (road 19 828, grove edge 28 113) |
| **whole capital** | **358 526 of 400 000** |

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

1. **`run_capital.sh`'s digest gate aborts for a capital with no rampart and no
   gate**, which is what an OPEN capital is. In `full` mode it walks
   `for label in avenue rampart gate` and assigns
   `digest="$(grep -o "${label}_road_digest=..." | ...)"`. Lethariel's probe
   publishes `core`, `plot` and `avenue` and no rampart or gate, so the second
   iteration's `grep` finds nothing, exits 1, and under the script's own
   `set -euo pipefail` the failing command substitution ends the run — after the
   avenue digest has been recorded and before the final `PASS` line. Every pass
   in section 6(e) therefore exits 1 on a boot whose own report is
   `exit=0 errors=0 complete=1` with zero warnings; `overlay-digests.txt` in
   this package's evidence holds the values the run did produce.

   It is a one-line fix in a file this lane does not own (`|| true` on the two
   substitutions, or a probe-published label list), and Kezamba — the other open
   capital — will hit it next.

   The gate's OTHER half is now fine: before the rebase onto `c8050057` the same
   passes also carried four `resolves to no registered entity` ERROR lines for
   the wave-2 vendor kinds, which the sockets contract's section 8.4 sanctions
   and the runner's `grep -c ERROR` could not tell from a defect. The NPC
   vocabulary lane registered those entities and the count is zero now.
2. **`capital_plots.lua` and `capital_probe` cannot express a four-district
   capital.** The first reads `capital.district.plots` (one district) and the
   second's `scan` mode sweeps `x 52..204, z −96..96`, which is the quadrant Dur
   Brannoc's single district stands in. That is why Highcourt has a tool of its
   own and why `lethariel_plots.lua` exists beside it. **The gap is reported and
   not closed** — Lane D owns those files. The shape this lane suggests is the
   one it used: read `wp40/height.lua` and `wp40/simple_map.lua` directly, as
   `capital_terrain_fixture.lua` already does, and take every seed.
3. **The other capitals' lots have never been measured on more than two seeds.**
   Section 3.3 is a finding about the method, not only about this capital.
4. **NO FIXTURE SEED PUTS LETHARIEL'S ANCHOR ROOT ON A MAPCHUNK EDGE**, and
   the number is the test: a root lands on a chunk's lowest layer exactly when
   `anchor_y ≡ 47 (mod 80)`. Over the nine seeds of
   `capital_anchor_fixture.lua`, anchor_009's `anchor_y` is **41, 36, 36, 42,
   53, 36, 36, 36, 39** — not one of them is 47 or 127, and the fixture's own
   `root_on_chunk_edge` column says `false` for every one
   (`evidence/seeds.txt`). Highcourt is the capital that has such a seed
   (anchor_y 47 on 15912857179583385436), which is what the anchor-activation
   fix was written for. So the brief's fourth engine seed does not exist for
   this capital; the nine-seed engine sweep above is what stands in its place.
   Whether such a seed exists at all outside the fixture set is a search nobody
   has run.
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
8. **The lot derivation is re-runnable in one command, which is what a rebase
   onto Lane R needs.** That lane moves every WP40 route end from the capital
   anchor to the four gate points and leaves no route cell or bridge deck inside
   the 512 envelope; this capital's avenues already run to those exact points
   and nothing here reads a route cell. If the rebase moves the ground under a
   lot anyway, `luajit tools/wp13/lethariel_plots.lua .` says which, and
   `--derive` and `--derive-fill` re-take the two tables.
9. **The user has not walked Lethariel.** Nothing here is accepted until they
   have. On seed 531802985935182545 the crossing of the two great avenues — the
   `arrival` landmark, with the guard banner on it — is at **(1800, 42, −1500)**.
   Walk NORTH from it: the quay is twenty nodes on, and the causeway leaves the
   city across the water from there. The king stands in the hall west of the
   approach; the two traders are on the market walk south-east of the crossing;
   the sacred grove and the shrine are east of it.
