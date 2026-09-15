# WP13: Dur Brannoc, the dwarf capital and the first walled one

Increment record, 2026-09-15, rebased onto and re-measured against `main` at
`7f988a60` (the merge of the round-2 weapon ladder, the round-2 NPC fixes and
Highcourt's districts 2-4). It is the fourth increment of the capitals
contract's section 3 order — the first of
"the other five capitals, one lane each" — and the first capital with a
**curtain wall** (the user's ruling of 2026-09-14: walls for Dur Brannoc, Nhal
Veyr and Gor Drazhak; open edges for Highcourt, Lethariel and Kezamba).

Contracts implemented:
[wp13-capitals-pois-contract.md](wp13-capitals-pois-contract.md) (2.1 what a
capital is, 2.3 the budgets, 2.4 the dwarf column of the race table, 4 the
rulings on the king's hall, the sockets and the walls) and
[wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md). The seam it
plugs into is [wp13-seam-generalisation.md](wp13-seam-generalisation.md); the
pattern it follows is [wp13-highcourt.md](wp13-highcourt.md); the parts it is
assembled from are [wp13-capital-library.md](wp13-capital-library.md) and
[wp13-hearthpine-library.md](wp13-hearthpine-library.md).

Evidence: `tools/wp13/evidence/20260915-dur-brannoc/`.

## 1. What shipped

| File | Change |
| --- | --- |
| `wp13/wall.lua` | **new**: the curtain wall as an OVERLAY — a pure function of the column surface, like `avenue.lua`, with turrets and gatehouses |
| `wp13/dur_brannoc.lua` | **new**: the 96 × 96 civic core, the avenue, ring and wall run specifications, the overlay dispatch and the causeway parapet |
| `wp13/dur_brannoc_district.lua` | **new**: the forge and craft district, nine terrain-relative plots |
| `wp40/r7_dur_brannoc_blueprint.lua` | **new**: the capital source the seam reads — core, nine plots, one overlay of twelve runs |
| `wp40/r7_settlement.lua` | one roster row; nothing else |
| `tools/wp13/dur_brannoc_kat.lua` | **new**: acceptance for the core, every plot, the avenues, the wall and the causeway parapet |
| `tools/wp13/capital_probe/` | **new**: the disposable headless probe, keyed by settlement, with a `terrain` mode that runs before the composition exists |
| `tools/wp13/run_capital.sh` | **new**: the engine pass of one capital, ports 31300–31399 |
| `tools/wp13/capital_plots.lua` | **new**: `highcourt_plots.lua` generalised — where a capital's district plots may stand |
| `tools/wp13/capital_wall.lua` | **new**: whether the real ground under the four wall lines is ground a wall survives |
| `tools/wp13/capital_timing.lua` | **new**: `highcourt_timing.lua` generalised |
| `tools/wp13/seam_kat.lua`, `highcourt_timing.lua` | one line each: take the FIRST capital of the roster, not the last |
| `wp13/dur_brannoc_district.lua` | publishes `clear_to` — the airspace a plot really cut — so `r7_settlement.audit_terrain` holds it to that and not to the top of its bounds |
| `tools/wp13/final_micro.lua` | the new KAT joins the interpreter pair |

Not touched: the six start compositions, `highcourt.lua`,
`highcourt_district.lua`, `highcourt_kat.lua`, `avenue.lua`, `capitals.lua`,
`buildings.lua`, `parts.lua`, `palette.lua`, `dressing.lua`, `layout.lua`,
`interiors.lua`, `roofs.lua` and every WP40 file but the roster row. Section 6
(b) carries the proof.

## 2. The wall: how it is represented in the seam, and why

**Decision: the curtain wall is an OVERLAY, in the same overlay blueprint as
the avenues, dispatched by run id.**

The seam (`wp40/r7_settlement.lua`) offers three kinds of blueprint. Two of
them cannot hold a wall:

- an **anchor** blueprint is anchor-relative and bounded at ±47; a wall side is
  513 nodes long and stands 250 nodes further out;
- a **reference** plot is bounded at ±15 and projected from ONE column, so a
  wall would need some seventy of them per capital — seventy identity rows,
  seventy height queries, and a projection seam every thirty-two nodes, which
  is exactly where a wall on terraced ground would show a step or a gap.

The third kind, **overlay**, is a pure function of the column surface evaluated
per mapchunk, and that is what a wall on WP40's terraces actually is. The
measurement below is what says so: the ground under Dur Brannoc's four wall
lines falls up to **36 nodes along one side** in **four-node** terrace steps.

Three consequences worth stating, because each was a decision:

1. **One overlay, not two.** The seam gives a settlement exactly one overlay
   blueprint, and that is the right number here rather than a limitation worked
   round. The successor's cross-run arbitration only exists WITHIN one overlay,
   and it is what lets the avenue run through the gate and the wall yield the
   cells of the road it lets past. Two overlays could not have agreed on that.
   The run list's ORDER is therefore load bearing: avenues, then the ring
   street, then the wall.
2. **Every wall cell stays inside the run rectangle the seam activates on.**
   `bind_plan` offers a mapchunk a run when the chunk meets `at ± (half + 1)`,
   which is three nodes either side of the centre line for the contract's
   five-wide carriageway. A wall cell outside that band would be a cell in a
   mapchunk the run is never called for — and nothing else in the tree would
   see it. So the curtain is five thick and its turrets and gatehouses seven
   across, and the KAT asserts that no cell of any piece leaves the band.
3. **The wall publishes no NPC sockets.** An overlay has no `landmarks` in the
   seam at all — `M.sockets` reads them off prepared blueprints, and an overlay
   is prepared from its specification. The city's garrison is therefore the
   core's: four inner gatehouses with two guard posts and a two-waypoint tower
   watch each. Section 9 records what a manned rampart would need.

### 2.1 The rule the wall is built from

For each column `p` of a run, `B[p]` is the **lowest** ground under the wall's
own seven-lane footprint at that column and `E` is the **one-Lipschitz upper
envelope** of `B` — the lowest height field everywhere at or above `B` that
never changes by more than a node between two columns. The wall walk is
`D = E + 6`. That is `avenue.lua`'s rule, applied to a rampart instead of a
road, and from the single rule:

- **no gap is possible.** Every column is masonry from `B[p] − 2`, which is at
  or below every one of that column's own ground samples, up to `D[p]`. A
  terrace step makes the neighbouring column start lower and the wall face
  becomes a staircase of masonry following the ground; it never becomes a hole,
  because no column's fill begins above its own ground;
- **the walk is walkable.** `D` changes by at most one node per column and a
  column whose deck stands above a neighbour's is capped with a tread, so a
  four-node terrace step is walked as four half-node stairs;
- **a piece of a run is exactly that stretch of the whole run**, because
  `E[p]` depends on the ground within `reach` columns of `p` and on nothing
  else. That is what lets the successor call it per mapchunk.

The four sides are authored asymmetrically on purpose. The two z-runs (west and
east) carry the four **corner turrets** and reach 261, five nodes past the
envelope edge, so a turret centred on the corner is whole; the two x-runs stop
at 252, one node short of the corner turret's own face, so the two never write
into each other. First-run-wins arbitration would otherwise decide which half
of a corner survives, and half a turret is not a corner.

### 2.2 What is in the wall

| Piece | Geometry |
| --- | --- |
| curtain | five thick; rubble core between two masonry faces, a signature string course three under the walk, a three-wide walk, a crenellated outer parapet on a four-node merlon rhythm with signature caps, a solid inner parapet, a loophole on the same rhythm, a wall torch every sixteen columns |
| turret | seven across × eleven along, rising nine courses over the walk; the rampart passes THROUGH it (a three-wide, three-high opening in each end face), a fighting floor and a crenellated crown over it. 28 of them, every 64 nodes |
| corner turret | the same, plus an opening on its city face, which is how the wall that meets it at right angles gets onto the rampart. 4 of them |
| gatehouse | seven across × fifteen along, with a **seven-column passage** clear from the road to the underside of the walk, the arch springing on the outer lanes, and the same chamber and crown as a turret. 4 of them, on the four gate axes |

The gate passage is seven columns and not the carriageway's five for a reason
the composition cannot avoid: the avenue's lamp standards stand on the verge,
one node outside the carriageway, and inside a gate that verge is a column of
the gatehouse. Seven leaves them in open air. (In the finished map they are not
there at all — the successor's own rule 2 drops a standard that falls in
another run's carriageway band, and the wall run's band covers them — but a
rule that depends on another run's arbitration is not a rule the composition may
rely on.)

## 3. The ground, measured on both gate seeds

`tools/wp13/run_capital.sh <out> dur_brannoc terrain <seed>` samples every
column of the four candidate wall lines at ±256, lane by lane across the wall's
own thickness, plus a coarse grid of the whole envelope.
`tools/wp13/capital_wall.lua` is the predicate over those two dumps.

WP40 fits Dur Brannoc's anchor at **(−1800, 149, −1500)** on the user seed and
**(−1800, 140, −1500)** on the boundary seed.

| seed | line | wet columns | worst step | low | high | range | face overlap | gate fall |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 531802985935182545 | west | 0 | 4 | 93 | 105 | 12 | 4 | 4 |
| | east | 0 | 4 | 85 | 101 | 16 | 4 | 4 |
| | south | 0 | 4 | 97 | 105 | 8 | 4 | 4 |
| | north | 0 | 4 | 89 | 101 | 12 | 4 | 0 |
| 8675309 | west | 0 | 4 | 76 | 96 | 20 | 4 | 4 |
| | east | 0 | 4 | 80 | 116 | **36** | 4 | 0 |
| | south | 0 | 4 | 76 | 108 | 32 | 4 | 4 |
| | north | 0 | 4 | 76 | 96 | 20 | 4 | 0 |

Read out of that:

- **No wall line is ever water**, on either seed — the dwarf granite terrace has
  no river in it, which is the one thing Highcourt's own first sweep got wrong.
- **The ground never steps more than four nodes** between two columns, which is
  exactly the race terrace step of the contract's section 1. The wall's rules
  are written for that and the tool refuses anything deeper.
- **The face overlap is four courses.** Two neighbouring columns of masonry are
  each filled from their own ground minus the footing to their own deck, and the
  lower one's fill starts at most one terrace step below the higher one's, so
  the two faces share `rise + footing − step` = 6 + 2 − 4 = **4** courses. One
  or more is what "no gap" means as arithmetic.
- **The corner step is zero at seven of the eight corners and one node at the
  eighth.** Where an x-run's walk arrives at a z-run's corner turret, the two
  runs compute their decks from different neighbourhoods and can disagree; on
  the user seed `wall_north` meets `wall_west`'s turret at deck 104 against 103.
  The turret's own rampart opening is three courses high, so a one-node step is
  walked through it; the tool refuses three.

  The first version of this record said zero everywhere, and it was wrong
  because the TOOL was: `capital_wall.lua` built the envelope over the run's
  span alone while `wall.lua` builds it over the span plus the look-around
  either side. Three columns of `wall_west` and one of `wall_north` moved when
  the window was put back, and the corner step with them. The independent review
  found it by reading the built decks out of the map.

The cross-thickness fall — the ground's spread across the wall's own seven lanes
at one column — is at most **4** nodes, on 230 of the 2 116 columns the terrain
dump covers on the user seed and 421 on the boundary seed. That is a terrace step running diagonally under the
wall, and it is why `B` is the minimum over all seven lanes and not the centre
lane's height.

## 4. Where the district plots may stand

`tools/wp13/capital_plots.lua` is `highcourt_plots.lua` generalised to any
capital: dry, inside the skirt, under its own roof, clear of the core, the four
32-node gate corridors, every street run the overlay writes — **including the
curtain, which Highcourt's version had no notion of** — and one node clear of
every other plot, on BOTH gate seeds.

It refused four of the nine plots at the positions the Highcourt layout suggests,
and the reason is the one thing that differs most between a human plateau and a
dwarf terrace. **WP40 blends the flat civic core down to the granite terraces
over some forty nodes, and it falls 44 nodes doing it**: on the user seed the
ground under the east avenue is 149 at |x| = 60 and 105 at |x| = 104. The four
plots the pilot layout puts at |x| 72 and 76 stand on the steepest ground in the
whole envelope, with a perimeter fall of 8 to 12 against a foundation skirt that
reaches 6.

| Plot | position | moved from | fall (a / b) | rise | clear |
| --- | --- | --- | --- | --- | --- |
| `forge_charcoal` | (56, −72) | (72, −28) | 4 / 4 | 9 | 13 |
| `forge_pack_stable` | (56, 60) | (72, 28) | 3 / 3 | 3 | 11 |
| `forge_smithy` | (116, −28) | — | 0 / 0 | 8 | 11 |
| `forge_guild_house` | (116, 28) | — | 4 / 4 | 8 | 13 |
| `forge_quench_court` | (160, −28) | — | 4 / 4 | 4 | 9 |
| `forge_watch` | (160, 32) | (160, 31) | 4 / 4 | 4 | 12 |
| `forge_copse` | (112, −92) | (76, −64) | 4 / 4 | 12 | 24 |
| `forge_ore_yard` | (112, 64) | (76, 64) | 4 / 4 | 8 | 13 |
| `forge_store` | (116, −60) | (116, −64) | 4 / 4 | 4 | 12 |

Every plot: zero submerged columns on both seeds, perimeter fall ≤ 4 against a
skirt of 6, and rise at least two nodes inside its own airspace clear.

`clear` is the airspace the plot really CUT and not the top of its bounds, and
the difference is not academic: a `grove`'s own authored air reaches y = 24 over
its trees while the plot's clear over its two-node margin ring stops at its roof.
The first version of this predicate read the bounds, passed `forge_copse` at
(112, −88) with a rise of 12 "against 24", and the seam's own load-time
`audit_terrain` then said out of the engine that the real clear there is 11. The
tool reads the composition's published `clear_to` now and the copse moved four
nodes.

## 5. The core, and the socket table

96 × 96, bounds x/z [−47, 47] and y [−2, 31] inside the contract's [−2, 40],
flat at y = 0 by construction, anchor-relative exactly like a start. Two palette
handles, not Highcourt's three: the dwarf signature IS `default:stone_block` and
is bound in the Hearthpine palette already, so the only second handle is the
darkage slate roof of the civic buildings — the contract's "pine-and-slate
halls" as one rebinding rather than a second palette.

| Quarter | What stands there |
| --- | --- |
| North, z 6..37 | the **king's hall**: the library's 31 × 27 basilica on its podium, great door on the axis, throne at the north end, slate roof, four turrets, ridge lantern; the composition lays its nave floor in stone-block bands with four braziers |
| North-east, x 22..45 | the **forge court**, this capital's signature: the great forge, the smelting yard, the two royal trading booths, charcoal stacks, ore crates, quenching cauldrons, an anvil line and six lamps on one paved court |
| West | the **cistern court**, the **hall of the ancestors** (the library's temple, which carries the capital's one quest socket) and a house |
| South-west | the **market square** (25 × 25 round a stepped market cross) and two houses |
| South-centre | the two **colonnades** flanking the throne approach and the king's **statue** |
| South-east | the **travel plaza** reserved for WP17, the **masons' guild** and two houses |
| The boundary | no hedge: a **citadel parapet**, two courses of castle masonry with merlons on a four-node rhythm, walked round the whole pad, and a crenellated **drum at each corner** |

Eighteen plots, twelve pine stands, 240 columns of parapet, four drums.

### 5.1 The socket table

The core publishes 65 sockets and the nine district plots 29; the settlement
registers **94**. Positions are anchor-relative and `dir` is published beside the
facedir, which is the conversion the sockets contract asks the settlement
boundary to do.

| Role | Core | District | Where |
| --- | --- | --- | --- |
| `king` | 1 | — | `king`, on the dais one node in front of the throne, looking down the approach |
| `vendor` | 2 | — | `vendor_race` and `vendor_general`, one outside each booth in the forge court |
| `waypoint` | 1 | — | `travel_waypoint`, the middle of the plaza reserved for WP17 |
| `quest` | 1 | — | the hall of the ancestors' own, published by `capitals.temple` |
| `guard_post` | 12 | 1 | two inside the great door, two on the dais, two in each of the four gate passages; the district's barracks adds one |
| `guard_patrol` | 14 | 9 | six in the city loop `dur_brannoc_watch` (the two colonnades and four precinct corners), two in each of the four gate towers' own loops, nine in the district loop `dur_brannoc_forge_watch` |
| `idle` | 34 | 19 | three in the hall, two per gatehouse at its fire, four in the colonnades, six in the market, two in the cistern court, one at the statue, three in the forge court, two on the hall's forecourt, one per district plot at its gate plus each part's own — **and two SPARE, wander-only spots** |

**Six loops**, orders 1..n with no gap in each, which the KAT walks: the city
ring, one per gate tower, and the district's own.

**The two spare spots** (`citadel_walk_west`, `citadel_walk_north`) carry
`spawn = false` and no tag, which is the sockets contract's own shape for them
(playtest round 2, 2026-09-15, and the shape Highcourt's districts settled on).
The position is real and reaches every consumer; nobody is placed on it. The NPC
lane walks a flair villager from one spot of its own composition to another, and
a roster with exactly as many spots as villagers gives every one of them the
same two ends of the same line.

The first version of this package wrote them as ordinary idle spots with a
`walk` TAG, which is a description and not a contract: the engine placed a
villager on each and the settlement was back to two ends of a line. The
independent review found it in this package's own engine evidence (`flair
53/53`). `grug_core/settlement_sockets.lua` normalises the field,
`grug_mobs/start_npcs.lua` counts spares out of the roster and keeps them as
wander targets, and the KAT's `dur_brannoc_spares` row asserts both halves of
the arithmetic: 53 idle sockets, 51 of them placed, 2 spare.

### 5.2 The causeway parapet

The blend band of section 4 has a second consequence, and the first engine pass
is where it was seen rather than reasoned about: the ground falls two nodes per
column there while the road's one-Lipschitz envelope may fall only one, so **the
east avenue leaves the ground and runs out of the citadel on an embankment eight
to ten nodes high, with nothing at its edge**. That is the "causeway has no
parapet" open point the seam package left for this lane
([wp13-seam-generalisation.md](wp13-seam-generalisation.md) section 9.1).

`avenue.lua` is not where the fix goes: it is the shared road module and
Highcourt's built road is frozen against it. The rail is added by the
composition to the piece the road module returns, as a pure function of that
piece's own cells — a kerb column whose cells span three or more courses is a
column the road had to FILL, and one course of citadel masonry on top of it is
the rail. It reads nothing but the piece, so it is chunk-independent for the same
reason the road under it is, and the KAT cuts it at every column to prove it.

## 6. Verification

### (a) The KAT, both interpreters

`tools/wp13/dur_brannoc_kat.lua` is `highcourt_kat.lua`'s acceptance for the
core, every plot and the avenues — envelope and budget, canonical unique cells,
the byte-sorted palette, every emitted name registered and not retired, the
three authored tables of `parts.lua` against the real registry in both
directions, the two shape rules, every pane settled the way `update_pane` would,
every attached node on the support its rating names, no detached cell and no
island, every torch on an opaque full node, the exact light population, every
doorway passable with a walkable step on both sides, every closed room roofed
and lit, every destination reachable from `arrival`, the socket contract with the
exact role multiset and every loop walked 1..n, the flat ground course, the four
gate openings walkable end to end, the king on his throne facing his hall, one
vendor of each family, the plaza empty, and per plot the reference column, the
skirt to −6, the cleared airspace and no overlap with another plot, a street or a
gate corridor — **plus two sections of its own**:

- **section 4, the curtain wall.** Every cell inside the seam's activation band;
  no gap between the footing and the walk in any column of any of the four runs;
  the walk never changing by more than a node and every change a stair; the gate
  passage clear through the whole thickness; the piece cut at every column of a
  representative stretch with the union compared to the whole, cell for cell; and
  the digest of the built cells, because an overlay's manifest identity is its
  SPECIFICATION and would not move if every node of the wall did.
- **section 5, the causeway parapet.** Every rail cell on a kerb lane, one course
  over the road, over a fill of at least three courses; no such column missed;
  and the same cut-at-every-column union test.

```
WP13 FINAL MICRO PAIR BYTE-IDENTICAL
37221ada423b25a03a06851d7532488e5dd59c7b787d1cc5d58429dac22af12b  micro-luajit.tsv
37221ada423b25a03a06851d7532488e5dd59c7b787d1cc5d58429dac22af12b  micro-puc51.tsv
```

That is the whole WP13 fixture set in one process under each interpreter, this
KAT among them (`final-micro.sh`, with the inputs hashed before and after). The
KAT's own rows are
`dur_brannoc_core`, `dur_brannoc_throne`, nine `dur_brannoc_plot` rows,
`dur_brannoc_district`, `dur_brannoc_avenue`, `dur_brannoc_avenue_built`,
`dur_brannoc_wall` and `dur_brannoc_causeway`.

### (b) The six starts and Highcourt are byte-identical

`identity.txt`: the identity digest `r7_settlement` computes for all six
starts, unchanged:
`8233c7bc…` (hearthpine), `80b3f0fc…` (dawnmere), `149ca6eb…` (silverleaf),
`ed6ddd43…` (stillgrave), `8110477c…` (sunscar), `c7aadf6a…` (kapok).

`highcourt_kat.lua` (`f0b85533…`), `library_kat.lua` (`104d21df…`) and
`blueprint_kat.lua` (`c645fc27…`) produce byte-identical output on this tree and
on an archive of `main` at `9e22b0d` (`identity.txt`). This lane changed no
shared module: the three files it did
touch outside its own are `r7_settlement.lua` (one roster row), `seam_kat.lua`
and `highcourt_timing.lua` (one line each, both to make them take the FIRST
capital of the roster rather than whichever one it ends with — without that, the
day a second capital landed both would have silently stopped exercising the
first).

### (c) Build time and budget

`timing.sh` / `timing.txt`, three runs each, `os.clock` CPU milliseconds:

| Subject | LuaJIT | PUC 5.1 | Cells |
| --- | --- | --- | --- |
| module load | 12.8 – 13.4 ms | 17.2 – 17.8 ms | — |
| core | 108.8 – 114.3 ms | 346.6 – 353.5 ms | 95 914 |
| core, second build | 107.1 – 122.8 ms | 350.8 – 368.2 ms | same |
| district, all nine plots | 53.1 – 54.4 ms | 158.8 – 166.7 ms | 54 876 |
| one 209-node avenue run | 1.10 – 1.18 ms | 2.24 – 2.26 ms | 1 291 |
| **seam prepare** (all 11 blueprints built, hashed, released) | 269 – 313 ms | 908 – 935 ms | — |
| **seam first touch** (core rebuilt, hashed, compared, written) | 231 – 258 ms | 617 – 634 ms | 95 913 |

Against the contract's section 2.3 budget: core **95 914 of 150 000** cells,
largest plot **9 746 of 12 000** (the copse, whose margin ring is cut to the
top of its own trees), whole capital including both overlays **299 660 of
400 000** written cells. "Builds in a few seconds under LuaJIT when
first touched" is 0.23 s, and 0.63 s under the fallback interpreter.

The wall is the biggest single writer. The overlay is **147 102** of those
299 660 cells (the total less the core's 95 914 and the district's 56 644), and
the wall is almost all of it: 2 056 columns of curtain — 523 on each z-run and
505 on each x-run — at some 67 cells each, plus 32 turrets and four gatehouses.
The KAT's own `dur_brannoc_wall` row counts 137 860 cells over the same 2 056
columns, which is the same wall on the fixture's synthetic profile rather than
on this world's ground. It is also the piece that never sits in memory: an
overlay has no cells until a mapchunk hands it a surface.

### (d) Per-mapchunk cost

`dur_brannoc/probe-<seed>.txt`, one boot per seed. The corpus is the mapchunks
the capital's blueprints, avenues and wall actually touch, derived from the real
geometry, plus three kinds of control.

| Kind | chunks | first | steady mean | worst | best |
| --- | --- | --- | --- | --- | --- |
| warm-up (not counted) | 1 | ~21 s | — | — | — |
| **Dur Brannoc**, user seed | 85 | 0.86 s | **0.43 s** | 0.86 s | 0.10 s |
| **Dur Brannoc**, boundary seed | 85 | — | **0.45 s** | 0.90 s | — |
| Lethariel (a capital with no WP13 cells) | 8 | ~11 s | 2.21 / 2.47 s | 13.3 / 15.4 s | 0.19 s |
| open land / the Dawnmere start | 3 | ~0.7 s | 0.48 / 0.32 s | 0.95 s | 0.003 s |

The warm-up mapchunk carries the emerge environment's whole one-time R7
construction, which is why it is emerged first and not counted. Lethariel is the
honest control: WP40 fits, flattens, terraces and protects it exactly like Dur
Brannoc and it has no WP13 blueprints at all. **Dur Brannoc's mapchunks are five
times cheaper than that control's**, and its steady mean sits at or below the
open-land control's, so the capital settlement's own contribution — wall
included — is inside the noise of the terrain work around it. Against the
contract's "no more than 2× the ~0.5 s Dawnmere chunk": 0.43 – 0.45 s.

85 mapchunks against Highcourt's 33, which is the wall: four runs of 513 columns
round a 512 envelope touch every mapchunk on the ring.

### (e) Engine

`tools/wp13/run_capital.sh <out> dur_brannoc full <seed>`, both gate seeds, one
cold world each: **0 ERROR and 0 ModError lines**, the capital emerged one
mapchunk at a time, **no finding from the seam's load-time terrain audit**, and
the NPC roster placed in full.

| | user seed 531802985935182545 | boundary seed 8675309 |
| --- | --- | --- |
| sockets registered | 94 | 94 |
| idle sockets / placed / spare | 53 / 51 / 2 | same |
| roster placed | `guards 19/19 flair 51/51 vendor 2/2 quest 1/1 spare 2` | same |
| loops | 6 | 6 |
| terrain-audit findings | 0 | 0 |

Both capital vendors stand on their sockets, so `grug_traders/vendors.lua`
places none of its own at Dur Brannoc. As at Highcourt, the split between
"placed at readiness" and "pending" depends on which mapblocks the emerge
sequence had loaded and is not a gate; what is reproducible is that the roster
ends complete.

The boundary-seed row is the pass taken before the review round; the user seed
was re-run on the final tree, which is the one the numbers above come from and
the one `REBASE.md` records.

Dur Brannoc's core identity is
`c87bf21b083db8ac55202d9e17ad953aec7721c27dd76f30fff1fd00bedf293f`; its eleven
blueprints carry eleven distinct identity SHAs, which the integration fixture
prints in roster order.

**The built road, rampart and gate are digested.** `run_capital.sh` compares
three SHA-256s — the avenue, a stretch of curtain crossing its terrace steps
with a turret on it, and the east gatehouse — read back out of the finished map
against the committed values in `dur_brannoc/*-digest-<seed>.txt`. Those values
are not frozen forever (WP40 terrain changes move the ground both follow); the
gate is "look at what moved and say why", and each file names its seed.

The gate works, and it was not taken on faith. The pass that recorded these
values was followed by a fourth, fresh boot of the same seed, which printed

```
avenue overlay digest matches the committed value
rampart overlay digest matches the committed value
gate overlay digest matches the committed value
```

and the pass BEFORE those values — the one taken before the causeway parapet of
section 5.2 was added — failed all three, naming the old digest and the new one.
The rampart and gate digests had moved by exactly one cell each, which is the
rail landing on the kerb column at x = 252, just inside the gate.

### (f) Static gates

`static.sh` / `static.txt`: `tools/bin/luac51 -p` and the SETGLOBAL count on
every file this package touched (all PASS, all zero globals except the probe's
own single mod table), the whole `mods` and `tools` trees parse under plain 5.1,
and the five plain-5.1 sweeps scoped first to the touched files and then to
`mods/*/grug_*` and `tools/wp13`. The only sweep hits this package contributes
are `os.exit` in `capital_plots.lua` and `capital_wall.lua`, the same
standalone-CLI pattern `highcourt_plots.lua` and the three dumpers have carried
since the renderer landed: none of them is ever loaded by the engine.
`check_fresh_server.py` PASS.

## 7. Dur Brannoc as built, and what changed after looking

`renders/`, drawn by `tools/wp13/render_blueprint.py` from TSVs the probe read
back **out of the finished map**, not from the composition.

| File | What |
| --- | --- |
| `core-ne.png`, `core-sw.png`, `core-night.png` | the civic core in terrain from both diagonals and at night |
| `core-overview.png` | the whole core at a smaller scale, which is the picture to look at first |
| `kings-hall.png`, `forge-court.png` | the two quarters that carry this capital's identity |
| `plot-charcoal.png` | a district plot on its own terrace |
| `avenue-east.png`, `avenue-east-night.png` | the east avenue down the terraces, over its embankment, to the gate |
| `wall-terrace.png`, `wall-terrace-sw.png` | the curtain crossing its terrace steps with a turret on it — the picture this package exists for |
| `gatehouse.png`, `gatehouse-night.png` | the east gatehouse with the road running under it |
| `renders/tsv/*.tsv` | the read-back dumps themselves, anchor-relative |

What changed **after looking at them**:

1. **The east avenue ran out of the citadel on an unrailed embankment.** The
   causeway parapet of section 5.2, its KAT row and the `RAIL_FILL` threshold
   are all that render's doing.
2. **The forge court was a paved field with two buildings on it.** It gained
   three more charcoal stacks, seven more ore crates, a four-anvil line, two
   benches and the two booths moved out of the forge's apron: the quarter that
   is supposed to say "dwarf" from the crossing now has work in it.

Three defects the KAT caught before any render, each worth recording:

- **A pine hung its needles on a merlon cap.** The precinct parapet is written
  after the trees and only asks whether the four courses above the ground are
  free, so a stem on the ring's own column let the wall be built under it. Every
  pine stands three nodes clear of the ring now, and the rule is written at the
  call site. The KAT's own shape rule — a bottom slab carries nothing — is what
  found it.
- **The four corner drums found no room.** They were authored after the parapet,
  which had already walked through their corners; the drums go first now and the
  parapet breaks by itself at them, and the composition refuses a build with
  fewer than four.
- **The travel plaza had ten slabs hanging over it.** The east colonnade's eaves
  oversail its own footprint by two nodes, and the plaza started where they end.
  The reserved square moved two nodes east.

## 7b. What the rebase onto `7f988a60` changed

This package was written against `main` at `9e22b0d` and rebased onto the three
lanes that landed first. Four things in it are theirs and not this lane's design:

1. **The blueprint source takes the seam's options.** `r7_runtime.lua` now
   validates the world seed once and hands every source `{full_seed,
   raw_sha256}`. Dur Brannoc has one district and no quadrant permutation, so it
   reads neither — but `r7_dur_brannoc_blueprint.lua` refuses a HALF seam rather
   than shrugging at it, because a caller that passes one field and not the other
   has a defect upstream, and the day this capital grows a seeded assignment the
   refusal is already where it belongs.
2. **`r7_settlement.audit_terrain` audits every capital plot at load** and logs a
   warning per submerged or steep one. Dur Brannoc's nine plots are audited too,
   and the engine pass's log carries no finding for any of them — which is the
   runtime restatement of section 4's offline verdict, on the same ground.
   `dur_brannoc_district.lua` publishes `clear_to` so the audit holds a rise
   against the airspace the plot really cut rather than the top of its bounds.
3. **The quest socket moves through `socket_overrides`**, the hook
   `highcourt_plot.lua` gained, rather than through this composition's own
   `recast`. See section 5 for what it does and why it is not in `capitals.lua`.
4. **Spares carry `spawn = false` and no tag**, which is the shape lane 3's
   spares settled on; this package's first version used a `walk` tag and no
   field, and the engine placed a villager on each.

## 8. Open points

1. **The turret and gatehouse chambers are closed boxes above the walk.** The
   rampart passes THROUGH them, which is what the wall walk needs, but there is
   no flight up to a fighting top and nothing stands there. A manned rampart
   needs two things this lane deliberately did not build: a flight, and a way for
   an OVERLAY to publish sockets — which today it cannot, because the seam reads
   sockets off a prepared blueprint's landmarks and an overlay is prepared from
   its specification. That is a seam change and belongs to whichever lane first
   wants guards on a wall.
2. **`avenue.REACH` is 40 and the blend band falls 44.** A column's influence on
   the road's envelope decays by one node per column, so a plateau 44 columns
   from the road it lifts is just outside the look-around. On the real ground
   that is harmless — the fall averages exactly one node per column, which is the
   rate at which influence decays, and the built road on the user seed has **no
   step over one node** anywhere along its 205 columns across three mapchunk
   borders — but it is not proved, it is measured. A synthetic profile that falls
   two nodes per column for twenty columns DOES make two pieces disagree by a
   node, and the first version of the causeway KAT row found it. Raising `REACH`
   is an `avenue.lua` change and would move Highcourt's built road.
3. **The terraces beside the avenue and under the wall read as bare grey cut
   stone.** That is WP40's terrain treatment of a capital envelope, not this
   package's; it is recorded because it is what the wall renders against.
4. **The overlay's manifest field prefix is `dur_brannoc_avenue`** even though
   that blueprint carries the curtain wall as well. Renaming it is a change to
   `r7_settlement.lua`'s descriptor code, which this lane kept to its roster row.
5. **The wall's identity is its specification, and the turret and gate positions
   are not in it.** They are derived in the composition from the run extents, so
   moving a turret moves no manifest SHA. What catches it is the KAT's built-cell
   digest and the engine pass's read-back digest, which is the same arrangement
   the avenue has and the same lesson the seam package recorded.
6. **The other three districts** and the quadrant permutation are a later
   increment's, exactly as at Highcourt.
7. **The user has not walked Dur Brannoc.** Nothing here is accepted until they
   have. On seed 531802985935182545 the crossing of the two great avenues — the
   `arrival` landmark, with the guard banner on it — is at **(−1800, 150,
   −1500)**. The king stands at (−1800, 155, −1468); the two traders at
   (−1757, 150, −1491) and (−1757, 150, −1484) in the forge court; the travel
   plaza WP17 is being kept clear of at (−1781, 150, −1522); the quest shell on
   the hall of the ancestors' doorstep at (−1838, 150, −1475). The east gate of
   the curtain wall is at (−1544, ~99, −1500) — walk east out of the citadel,
   down the avenue's embankment and its terrace stairs; the curtain either side
   of that gate is the thing this package exists for.
