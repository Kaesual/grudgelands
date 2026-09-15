# WP13: Gor Drazhak, the orc capital

> **Read sections 10 and 11 first.** Section 11 is the second rebase (onto
> `main` at `f5583e13` = Lane N + Lane R + Lane D) and carries the current
> numbers. An independent review of the first version found
> one blocker and six should-fixes, all but one of them the same root cause: the
> coverage the brief asked for (nine fixture seeds) was taken on three. Sections
> 1-9 are the first version's record and their three-seed numbers stand as
> history; section 10 is the fix round, and where the two disagree the fix round
> is what the tree does.

Increment record, 2026-09-15, built against `main` at `922bfd92` ("Extend the
socket vocabulary for the wave-2 capitals"). It belongs to the capitals
contract's section 3 step 3, "the other five capitals, one lane each": Dur
Brannoc went first and the remaining four are wave 2, built in parallel lanes,
of which this is one. It is the **second WALLED capital** and the **second with
four districts**.

Contracts implemented:
[wp13-capitals-pois-contract.md](wp13-capitals-pois-contract.md) (2.1 what a
capital is, 2.3 the budgets, 2.4 the orc column of the race table, 4 the rulings
on the king's hall, the sockets and the walls) and
[wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md) (2 the socket
field, 8 work sockets, profession vendors and the 80/20 rule, including the
wave-2 vocabulary). The seam it plugs into is
[wp13-seam-generalisation.md](wp13-seam-generalisation.md); the patterns it
follows are [wp13-highcourt.md](wp13-highcourt.md),
[wp13-highcourt-districts.md](wp13-highcourt-districts.md),
[wp13-highcourt-fill.md](wp13-highcourt-fill.md) and
[wp13-dur-brannoc.md](wp13-dur-brannoc.md).

Evidence: `tools/wp13/evidence/20260915-gor_drazhak/`.

## 1. What shipped

| File | Change |
| --- | --- |
| `wp13/orc_palisade.lua` | **new**: the city wall as a STAKE PALISADE ON AN EARTH RAMPART — an overlay with `wall.lua`'s seam and constants and none of its section |
| `wp13/gor_drazhak_quadrants.lua` | **new**: the city plan — avenues, ring, lanes, rampart runs, the corner table the rampart reconciles against, and one authored lot grid turned four times with eighteen measured repairs, plus the seeded quadrant permutation |
| `wp13/gor_drazhak_plot.lua` | **new**: one district plot in the orc palette, behind a flat deck and a breastwork |
| `wp13/gor_drazhak_district_market.lua` | **new**: the BAZAAR — nine plots and four fill lots, five profession vendors |
| `wp13/gor_drazhak_district_martial.lua` | **new**: the WAR YARD — the arena, the drill yard, the beast pen |
| `wp13/gor_drazhak_district_lore.lua` | **new**: the BONE HALLS — the spirit hall, the totem court, the barrow, the quarry face |
| `wp13/gor_drazhak_district_homes.lua` | **new**: the WARRENS — clan lodges, the cook court, the story fire, and this roster's own round-lodge generator |
| `wp13/gor_drazhak_districts.lua` | **new**: the 52 plots in a fixed order with this world's offsets |
| `wp13/gor_drazhak.lua` | **new**: the 96 × 96 civic core, the fighting platform, the muster court, the precinct bank and stockade, and the overlay dispatch |
| `wp40/r7_gor_drazhak_blueprint.lua` | **new**: the capital source the seam reads — core, 52 plots, one overlay of twenty runs |
| `wp40/r7_settlement.lua` | one roster row, after `dur_brannoc`; nothing else |
| `tools/wp13/gor_drazhak_kat.lua` | **new**: acceptance for the core, every plot, the whole capital's socket contract, the rampart, the work-socket features and the quadrants |
| `tools/wp13/gor_drazhak_lots.lua` | **new**: derives and verifies the 36 district lots and the 16 fill lots from the terrain grid of all nine fixture worlds |
| `tools/wp13/gor_drazhak_rampart.lua` | **new** (fix round): the rampart's own nine-seed predicate — dry, terrace step, no gap, dry gates and the four corners continuous |
| `tools/wp13/gor_drazhak_identities.lua` | **new**: the 54 blueprint identities in manifest order |
| `tools/wp13/final_micro.lua` | one line: the new KAT joins the interpreter pair |
| `docs/design/settlements.md` | two paragraphs: the palisade variant of a walled capital, and the orc capital's own shape |

Not touched: the six start compositions, `highcourt*.lua`, `dur_brannoc*.lua`,
`wall.lua`, `avenue.lua`, `capitals.lua`, `buildings.lua`, `parts.lua`,
`palette.lua`, `dressing.lua`, `layout.lua`, `interiors.lua`, `roofs.lua`, and
every WP40 file but the roster row and the new blueprint source. Section 6 (b)
carries the proof.

## 2. The wall: why it is not `wall.lua`, and what it shares with it

**Decision: Gor Drazhak's city wall is a NEW overlay module,
`wp13/orc_palisade.lua`, on `wall.lua`'s seam and constants.**

The contract's section 2.4 orc line is

> "Gor Drazhak | orc | mesa shelf, step 4 | adobe flat roofs with parapets,
> ors-stone base courses, **palisade and earthworks**, warlord hall with
> fighting platform"

and section 4 makes it one of the three walled capitals. `wp13/wall.lua` builds
the other kind of wall: a five-thick masonry curtain, rubble-cored, with a
crenellated parapet, loopholes and merlon caps. Rebinding its `castle_wall` role
to acacia would have produced a five-thick SOLID TIMBER curtain with
crenellations — a wooden castle, which is neither a palisade nor an earthwork.
The contract names a different piece of architecture, so this is a different
module.

What it is NOT is a different SEAM. Everything `wall.lua` promises the
successor, this promises in the same words:

* the same run specification (`axis`, `at`, `from`, `to`, `lamp_phase`,
  `reach`) and the same authored `plan` (`outside`, `towers`, `cross_towers`,
  `gates`);
* the same one-Lipschitz envelope rule, so a piece of a run is exactly that
  stretch of the whole run;
* the same `HALF` = 3 activation band, `RISE` = 6, `FOOTING` = 2, `REACH` = 40
  and `GATE_PASSAGE` = 3. **The KAT asserts those five equal to `wall.lua`'s**
  rather than leaving it to a comment, and it has to: `tools/wp13/
  capital_wall.lua` loads its constants from `wall.lua` and measures the ground
  under THESE runs, so the day one of them moves the measurement is of the
  wrong rule.

### 2.1 The section, from the field inward

With `o` the outward lane sign and `D` the walk at `E + RISE`:

| lane | what stands there |
| --- | --- |
| 3·o | the OUTER BERM: dug earth from the footing to three courses over the envelope, beaten bare on top |
| 2·o | the STOCKADE: an ors-stone base course from the footing to one under the walk, then three or four courses of acacia stakes, every one sharpened, with a brazier in place of a point every sixteen columns |
| 1·o, 0, 1·i | the RAMPART BODY: rammed earth to one under the walk, and the walk itself — a three-wide timber fighting platform, treaded wherever it steps |
| 2·i | the body's inner edge: earth, a log kerb at the walk and a rail above it |
| 3·i | the INNER SLOPE: earth to three courses, beaten bare — the back of the bank |

**No gap is possible**, for `wall.lua`'s reason exactly: every column is filled
from `B[p] − FOOTING`, at or below every one of that column's own seven ground
samples, up to its own `D[p]`, and `D` is the one-Lipschitz upper envelope of
`B` plus `RISE`. A terrace step makes the next column start lower and the face
becomes a staircase of bank and stake, never a hole.

The towers are timber: seven across, eleven along, rising six courses over the
walk, with the rampart passing THROUGH them (a three-wide, three-high opening in
each end face), a plank fighting floor and a log breastwork with a sharpened
stake every other node. The four gate towers are the same piece at fifteen along
with a seven-column passage clear from the road to the underside of the walk.
Seven and not five for the reason Dur Brannoc records: the avenue's lamp
standards stand on the verge, one node outside the carriageway, and inside a
gate that verge is a column of the tower.

## 3. The ground, measured on three worlds

`tools/wp13/run_capital.sh <out> gor_drazhak terrain <seed>` samples every
column
of the four candidate rampart lines at ±256, lane by lane across the seven-lane
thickness, plus the pure final height and the water class of every fourth column
of the whole 576-node envelope. `tools/wp13/capital_wall.lua` is the predicate
over two of those dumps.

WP40 fits Gor Drazhak's anchor at **(0, 94, 1500)** on the first gate seed,
**(0, 104, 1500)** on the boundary seed and **(0, 128, 1500)** on the user's
world seed.

| seed | line | wet columns | worst step | low | high | range | face overlap | gate fall |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 531802985935182545 | west | 0 | 3 | 77 | 102 | 25 | 5 | 2 |
| | east | 0 | 1 | 71 | 106 | 35 | 7 | 3 |
| | south | 0 | 1 | 74 | 98 | 24 | 7 | 0 |
| | north | 0 | 1 | 74 | 85 | 11 | 7 | 0 |
| 8675309 | west | 0 | 2 | 72 | 104 | 32 | 6 | 0 |
| | east | 0 | 1 | 84 | 108 | 24 | 7 | 1 |
| | south | 0 | 1 | 76 | 95 | 19 | 7 | 0 |
| | north | 0 | **4** | 89 | 120 | 31 | 4 | 3 |

Read out of that:

* **No rampart line is ever water**, on any of the three worlds — and neither is
  anything else in this envelope (section 4).
* **The ground never steps more than four nodes** between two columns, which is
  the race terrace step of the contract's section 1, and the tool refuses
  anything deeper. Most steps are ONE node: the round-3 terrace step bands turn
  every riser into a band of one-block steps, and the four-node step on the
  boundary seed's north line is the only place the raw terrace shows through.
* **The face overlap is four to seven courses.** Two neighbouring columns of
  bank are each filled from their own ground minus the footing to their own
  deck, and the lower one's fill starts at most one terrace step below the
  higher one's, so the two faces share `rise + footing − step` courses. Four is
  the worst case and one or more is what "no gap" means as arithmetic.
* **The corner step is zero to two nodes** across the eight corners of the two
  worlds. Where an x-run's walk arrives at a z-run's corner tower the two runs
  compute their decks from different neighbourhoods and can disagree; the
  tower's own rampart opening is three courses high, so a two-node step is
  walked through it, and the tool refuses three.

## 4. Where the lots stand, and the one thing that differs most from Highcourt

**Gor Drazhak's envelope has no water in it.** That is measured, not assumed:
21 025 sampled columns per world -- every fourth column of the square out to
+-288, which is the 512 envelope and its whole collar -- on three worlds,
`wet = 0` for all 63 075 of them, and zero wet columns on all four rampart
lines lane by lane besides. The pilot capital is the
opposite case — WP40 runs two rivers through Highcourt's envelope, and its own
quadrant module records that the set of positions dry in all four rotations is a
handful of columns, so it carries four separately authored lot grids and its
south-west quadrant slid four of its nine lots by up to 32 nodes.

A mesa shelf is dry ground, so the implementation Highcourt could not have is
available here: **one authored 3 × 3 lot grid, turned a quarter at a time**.
`M.LOTS` and `M.FILL_LOTS` are DERIVED from `M.AUTHORED` and `M.FILL_AUTHORED`
by `M.rotate` at load rather than typed out per quadrant, so there is nothing to
remember and nothing to drift.

**Seven of the fifty-two lots do not take the turn**, and that is the honest
half of the same story: the ground under a turned lot is not the ground under
its original. `tools/wp13/gor_drazhak_lots.lua --repair` measured them on three
worlds and moved each to the NEAREST legal position — nearest and not flattest,
because the layout is a design and sorting on flatness is what put two Highcourt
plots in a river.

| quadrant | lot | from | to | why it moved |
| --- | --- | --- | --- | --- |
| southeast | 6 | (160, −116) | (160, −112) | rise 7 against a clear of 8 |
| southeast | 8 | (116, −160) | (116, −164) | fall 7 against a skirt of 6 |
| southeast | fill 3 | (200, −200) | (200, −204) | fall 7 |
| northwest | 3 | (−160, 72) | (−160, 68) | rise 7 |
| northwest | 7 | (−72, 160) | (−72, 164) | rise 8 |
| southwest | 8 | (−160, −116) | (−168, −116) | rise 7 |
| southwest | 9 | (−160, −160) | (−168, −160) | rise 8 |

Five moved four nodes and two moved eight; the other forty-five stand exactly
where the turn put them.

### 4.1 The plots as the engine sees them

The lot tool reads the terrain grid at a quarter of its resolution and is
therefore a DERIVATION instrument, not the gate. The gate is
`run_capital.sh <out> gor_drazhak surface <seed>`, which samples every plot
column by column at its real position with the same `grug_zones.
terrain_height_at` the load-time `r7_settlement.audit_terrain` uses — and the
audit itself, which runs on every boot.

**52 plots × 3 worlds = 156 rows, 0 illegal.** Worst perimeter fall **6**
against a foundation skirt of 6 (`warren_cook_court`); worst rise **8** against
an airspace clear of 8 (`bone_barrow`); zero submerged columns, zero wet
margins, zero wet reference columns. The engine's own terrain audit logged no
finding for any plot on any of the three worlds.

Both worst cases sit exactly ON their limit rather than inside it. That is worth
stating because it is where the next WP40 terrain change will bite first:
`gor_drazhak_lots.lua --repair` is the one command that moves them, and section
8 records it as an open point.

## 5. The core, the districts and the socket table

### 5.1 The core

96 × 96, bounds x/z [−47, 47] and y [−2, 31] inside the contract's [−2, 40],
flat at y = 0 by construction, **94 582 cells of the 150 000 budget**. Two
palette handles: the orc palette, and the same palette with `wall` rebound to
`grug_decor:darkage_ors_block` — the contract's "ors-stone base courses" carried
up the whole wall of a building meant to read as the warlord's and not as a
dwelling.

| Quarter | What stands there |
| --- | --- |
| North, z 9..35 | the **warlord hall**: the library's basilica on its podium, great door on the axis, throne at the north end, built in ors block; the composition lays its nave floor in banded courses with four braziers |
| The forecourt, x 4..14 | the **fighting platform**: a raised ors-stone court four courses up, its own breastwork on the merlon rhythm the whole city uses, one flight off its east flank, a brazier at each corner and two guard posts on the deck. Beside the door and not across it — the first version stood on the axis and made the throne approach a four-node wall |
| North-east, x 22..45 | the **muster court**, this capital's signature quarter: a floor of beaten red sand with the two royal booths, a rank of six drill posts, three weapon racks, two war wains, five standards, two fires and the crates and benches of a host that has stopped moving |
| West | the **cistern court** (a mesa shelf has no standing water anywhere in its envelope, so the city's water is a tank), the **skull hall** — the library's temple, which carries the capital's first quest shell — and a dwelling |
| South-west | the **great bazaar square** (25 × 25 round a stepped cross) and a dwelling |
| South-centre | the two **colonnades** flanking the approach and the warlord's **statue** |
| South-east | the **travel plaza** reserved for WP17, the **war council house** and two dwellings |
| The boundary | no hedge and no citadel parapet: a **bank and stockade**, two courses of dug earth beaten flat with a sharpened stake every other node, walked round the whole pad, and a timber-crowned **tower at each corner** — the outer rampart's own section at a quarter of its height |

Eighteen plots, 240 columns of bank carrying 119 stakes, four corner towers,
four deck breastworks, six acacias, ten rock outcrops, 264 cells of platform.

**Six acacias and not twelve pine stands.** That is a measurement and not a
shortfall: a flat-crowned acacia needs seven nodes of clear ground and ten of
clear air, and after four avenues, the muster court, the bazaar square, the
plaza and eighteen plots there are six such places left inside a 96-node orc
precinct. What fills the ground between the quarters here is the shelf itself —
ten rock outcrops of the mesa's own stone, on which nothing grows because every
column below their cap is rock — and dry scrub.

### 5.2 The four districts

Four districts of nine plots and four fill dressings each, in the contract's own
role order, assigned to quadrants by the world seed:

| District | Role | What it is |
| --- | --- | --- |
| the **bazaar** | market and professions | butcher row with hanging racks over a chopping block, tannery with its vats, grog house, armourer, smith, store house, wain yard, carver, trader's house; fill: stock pen, drying floor, spoil heap, fire court |
| the **war yard** | martial and garrison | barracks, the ARENA (a sunken sand floor inside a stepped ors bank with a gate at each end), armoury, beast pen, drill yard, quartermaster, wain shed, war chief's house, watch tower; fill: muster field, remount paddock, wood yard, guard fire |
| the **bone halls** | lore and spiritual | spirit hall (the second quest shell), totem court of nine posts, burial barrow, QUARRY FACE cut into the mesa, bone reader's hall, herb house, ancestor store, shaman's house, ash court; fill: ancestor field, scrub garden, spoil shelf, candle court |
| the **warrens** | residential and cultural | clan longhouse, chief's round lodge, cook court with four communal ovens, three clan dwellings, weaver's shed, store lodge, story fire; fill: clan ground, dry garden, fuel yard, green |

52 plots, **260 652 cells**, largest `bone_spirit_hall` at 11 820 of the 12 000
per-plot budget. **Core plus plots: 355 234 of the contract's 400 000**, against
Highcourt's measured 376 274 (101 831 + 274 443).

### 5.3 The socket table

The capital publishes **315 sockets**, against Highcourt's 256.

| Role | Gor Drazhak | Highcourt |
| --- | --- | --- |
| `king` | 1 | 1 |
| `waypoint` | 1 | 1 |
| `quest` | 2 | 2 |
| `vendor` | 7 | 7 |
| `guard_post` | 21 | 19 |
| `guard_patrol` | 50 (nine loops) | 56 |
| `idle` | 177 (151 spawn, 26 spare) | 134 (108 spawn, 26 spare) |
| `work` | 56 | 36 |
| **residents / walkers** | **207 / 31 (15.0 %)** | 144 / 22 (15.3 %) |

Every loop's orders are 1..n with no gap and no repeat; no socket id is
published twice; every socket is a real standing position on the finished
composition (feet and head air, walkable ground under it), which the KAT
measures rather than assumes.

**The seven vendor kinds**, one of each, which is the whole of the capital's
allowance: `race` and `general` at the two royal booths of the muster court, and
`butcher`, `tanner`, `brewer`, `armourer` and `smith` in the bazaar, each
standing at the trade it sells. Three of those five have no entity in
`grug_traders` yet — see section 7.

**Thirteen of the fifteen activities** in the sockets contract's section 8.2,
including **all six of the wave-2 ones**: `mine` at the quarry face and the
spoil shelf, `brew` at the tan vats, the grog vats, the cook ovens and the fire
courts, `carve` at the totem posts and the bone reader's desk, `mourn` at the
barrow and the candle court, `spar` in the arena and the drill yard, `forage` on
the open ground. Only `farm` and `fish` are absent, and both for the same
measured reason: the orc palette binds neither `crop`/`crop_soil` nor `water`,
because a mesa shelf grows nothing in furrows and holds no standing water.

**Gor Drazhak carries more people than Highcourt** — 207 residents against 144,
44 % more — and that is a deviation from the standard this lane made
deliberately and reports rather than hides. The walker SHARE, which is what the
sockets contract's section 8.3 actually bounds, is 15.0 % against Highcourt's
15.3 %, comfortably inside the 10–30 % band, and the arithmetic that keeps it
there is the rule the contract states: 151 idle spawn sockets against 56 work
sockets. The cost the user's ruling names is path-finding and animated meshes;
this capital's is 31 walkers against Highcourt's 22. **If the coordinator wants
the resident count at the Highcourt standard, the cheap knob is the four
district rosters' `extra_sockets`: converting twenty tagged idle spots to
`plots.spare` drops twenty residents and four walkers without moving a cell.**
The first version of these rosters had 88 work sockets against 76 idle spawn
ones — a 9.8 % walker share, below the band — and the trim to 52 district work
sockets is what brought it inside.

## 6. Verification

### (a) The KAT, both interpreters

`tools/wp13/gor_drazhak_kat.lua` is the acceptance of `highcourt_kat.lua` and
`dur_brannoc_kat.lua` for this capital — envelope and budget, canonical unique
cells in canonical order, the byte-sorted palette, every emitted name registered
and not retired, `parts.lua`'s three authored tables against the real registry
in both directions, the two shape rules, every attached node on the support its
rating names, every torch on an opaque full node, every doorway passable with a
walkable step on both sides, every socket a standing position, the flat ground
course, the two great avenues walkable end to end, the king on his throne
looking down his own approach, the fighting platform's deck and its flight, and
per plot the lot envelope, the reference column, the skirt at the contract's
floor and the airspace it really cut — **plus four sections of its own**:

* **section 3, the socket contract over the WHOLE capital**: the role multiset,
  one vendor per kind, every loop walked 1..n, spares carrying `spawn = false`
  and no tag, and the 80/20 arithmetic of section 8.3 as an assertion.
* **section 4, the rampart**: the five constants asserted EQUAL to `wall.lua`'s;
  every cell of every piece inside the seam's activation band; no gap between
  the footing and the walk in any column of any of the four runs; the walk never
  changing by more than a node and every change a tread; the gate passage clear
  through the whole thickness; the piece cut at every column of a representative
  hundred-column stretch with the union compared to the whole, cell for cell;
  and the digest of the built cells, because an overlay's manifest identity is
  its SPECIFICATION and would not move if every node of the rampart did.
* **section 6, the work sockets**: the feature-under-`dir` rule of the sockets
  contract's section 8.1, for every one of the 50 activities that name a
  feature, with the search stopping at the first opaque node on the socket's own
  course so a feature behind a wall does not count. `sit` and `sweep` name none;
  a `spar` socket's feature is its partner.
* **section 7, the quadrants**: every lot inside the envelope, off the core, off
  the four gate corridors, off all twenty street runs, inside its own quarter
  and a lane's width clear of every other lot of that quarter; the seeded
  permutation a bijection on all nine fixture seeds and not constant; the
  canonical assignment the authored order; and every repair naming a lot the
  turn really put somewhere else.

```
WP13 FINAL MICRO PAIR BYTE-IDENTICAL
757efd30c445d68ecf24afa7bc5f34f7fec0e242aa74d44679079aab11513303  micro-luajit.tsv
757efd30c445d68ecf24afa7bc5f34f7fec0e242aa74d44679079aab11513303  micro-puc51.tsv
```

That is the whole WP13 fixture set in one process under each interpreter, this
KAT among them (`final-micro.sh`, with the input set hashed before and after so
the two runs provably saw the same bytes). The value above is the FIX ROUND's;
the first version's was `b3725124...`, and it moved because the corner
reconciliation, the deeper airspace and the socket trim each change something a
fixture prints.

The KAT's own rows are `gor_drazhak_core`, `gor_drazhak_throne`,
`gor_drazhak_district`, `gor_drazhak_sockets`, `gor_drazhak_rampart`,
`gor_drazhak_avenue`, `gor_drazhak_work` and `gor_drazhak_quadrants`.

### (b) The six starts, Highcourt and Dur Brannoc are unchanged

`identity.txt`: the six start identity digests are unchanged and
`start_identity.lua`'s whole output still hashes to
`0bbf87a7253deadca55951752adde73e82c31cd10878dc64ef6d44af91ad1f5f`, the value
wave 1 recorded. `highcourt_identities.lua` still totals **376 274** cells;
`highcourt_kat.lua`, `dur_brannoc_kat.lua`, `library_kat.lua` and
`blueprint_kat.lua` produce output byte-identical to what the SAME KATs produce
on an archive of `main` at `922bfd92` -- extracted into a scratch tree, the KAT
run there, the two hashed. `identity.sh` carries those four values and exits
non-zero if one of them moves, so this is a comparison and not a number
somebody wrote down from this tree. This lane changed no shared
module: outside its own files it touched `r7_settlement.lua` (one roster row),
`final_micro.lua` (one line) and `docs/design/settlements.md`.

`r7_manifest.lua` needed no re-freeze: since the seam generalisation its
`FIELD_ORDER` and `SETTLEMENT_ORDER` are DERIVED from the roster, so a new
roster row extends them by construction. `seam_kat.lua` needed no new row for
the same reason — it reads the roster and now reports nine settlements, three of
them capitals.

### (c) Build time and budget

From the engine's own `build_us` on three worlds (`probe.txt`): module load
33.6–33.8 ms, the core 132–345 ms, the largest plot (`bone_spirit_hall`)
14.4–16.0 ms, the smallest (`warren_green`) 0.9–4.7 ms, all 52 plots together
about 300 ms. Against the contract's section 2.3 "builds in a few seconds under
LuaJIT when first touched": the whole capital's blueprints are half a second.

Cells: core **94 582 of 150 000**, largest plot **11 820 of 12 000**, whole
capital **355 234 of 400 000**.

The rampart is the biggest single writer and never sits in memory: an overlay
has no cells until a mapchunk hands it a surface. On the KAT's synthetic
terraced profile the four runs write **172 402 cells over 2 056 columns** (84 a
column), against Dur Brannoc's curtain at 137 860 over the same 2 056. The
difference is the earthwork: a bank is seven lanes of fill where a curtain is
five.

### (d) Per-mapchunk cost

`gor_drazhak/probe-<seed>.txt` and `timings.txt`, one boot per seed. The corpus
is the mapchunks the capital's blueprints, avenues, lanes and rampart actually
touch, derived from the real geometry, plus three kinds of control. The warm-up
mapchunk carries the emerge environment's whole one-time R7 construction, which
is why it is emerged first and not counted.

| Kind | chunks | first | steady mean | worst | best |
| --- | --- | --- | --- | --- | --- |
| warm-up (not counted) | 1 | 23.9 – 26.0 s | — | — | — |
| **Gor Drazhak**, 531802985935182545 | 60 | 1.16 s | **0.669 s** | 1.16 s | 0.10 s |
| **Gor Drazhak**, 8675309 | 65 | 1.25 s | **0.579 s** | 1.25 s | 0.11 s |
| **Gor Drazhak**, 15912857179583385436 | 112 | 1.24 s | **0.499 s** | 1.24 s | 0.13 s |
| Lethariel (a capital with no WP13 cells) | 8 | 12.3 – 14.3 s | 2.24 / 2.75 / 2.39 s | 17.1 s | 0.10 s |
| open land / the Dawnmere start | 3 | 0.68 – 0.84 s | 0.52 / 0.39 / 0.40 s | 1.03 s | 0.003 s |

Lethariel is the honest control: WP40 fits, flattens, terraces and protects it
exactly like Gor Drazhak and it has no WP13 blueprints at all. **Gor Drazhak's
mapchunks are four to five times cheaper than that control's**, and against the
contract's "no more than 2× the ~0.5 s Dawnmere chunk" — that is 1.0 s — the
three steady means are 0.50, 0.58 and 0.67 s.

They are higher than Dur Brannoc's 0.43 – 0.45 s, and the reason is the two
things this capital has that it does not: twenty overlay runs against twelve
(eight district lanes), and a rampart whose section is seven lanes of bank where
a curtain is five. 112 mapchunks on the user's seed against Dur Brannoc's 85 is
the same fact from the other side — four districts in four quarters touch more
of the envelope than one district does.

### (e) Engine

`tools/wp13/run_capital.sh <out> gor_drazhak full <seed>`, three cold worlds:
the capital emerged one mapchunk at a time, **no finding from the seam's
load-time terrain audit**, and the NPC roster placed in full.

| | 531802985935182545 | 8675309 | 15912857179583385436 |
| --- | --- | --- | --- |
| sockets registered | 315 | 315 | 315 |
| roster placed | `guards 30/30 flair 207/207 vendor 4/4 quest 2/2 pending 0 spare 26` | `guards 30/30 flair 207/207 pending 0` | **`guards 27/30 flair 169/207 pending 41`** |
| residents / walkers | 207 / 31 | 207 / 31 | 207 / 31 |
| loops | 9 | 9 | 9 |
| worst plot perimeter fall | 6 (`warren_cook_court`) | 5 (`bone_totem_court`) | 5 (`bone_quarry`) |
| submerged plot columns | 0 | 0 | 0 |
| terrain-audit findings | 0 | 0 | 0 |
| ERROR / ModError lines | 3 | 3 | 3 |

**`pending 41` ON THE USER'S OWN WORLD SEED, and the first version of this
table said `same` there.** It is benign and it is not the same: a settlement's
roster is filled INCREMENTALLY, and `grug_mobs/start_npcs.lua` counts a slot as
pending when the socket's own mapblock was not loaded at the moment its turn in
the heartbeat came. The probe's corpus emerges a capital one mapchunk at a time
and then stops, so which of the four districts is resident at the end depends on
which mapblocks that sequence happened to leave loaded -- Highcourt's own
package records the same thing ("the split between placed at readiness and
pending depends on which mapblocks the emerge sequence had loaded and is not a
gate"). What IS a gate is that nothing is refused: `new 38 pending 41` with no
error line means 41 slots are waiting for their ground, not rejected by it. The
row now carries the measurement instead of the summary.

`vendor 4/4` and not 7/7 is section 7: three of the seven kinds have no entity
in `grug_traders` yet, so three sockets stay empty and each logs one line. Those
three lines are the only ERROR lines in any of the three logs
(`gor_drazhak/errors-<seed>.txt` is the complete listing), and they are why
`run_capital.sh` reports FAILED for a pass that is otherwise clean.

**The built road, rampart and gate are digested.** The probe reads five regions
back out of the finished map — the core, one district plot, an avenue over the
terraces, a stretch of rampart crossing a terrace step with a tower on it, and a
gate — and hashes each over its own node names. The fifteen values are in
`gor_drazhak/*-digest-<seed>.txt`. They are not frozen forever: WP40 terrain
changes move the ground the road and the rampart follow, so the gate is "look at
what moved and say why", and each file names its seed.

Gor Drazhak's core identity is
`8853176bdcc231f2aa73b9cbfdfd010148064639658c945da7998e850edff10e`; its 54
blueprints carry 54 distinct identity SHAs, which
`tools/wp13/gor_drazhak_identities.lua` prints in roster order.

### (f) Static gates

`static.txt`: `tools/bin/luac51 -p` on every file this package touched, the
SETGLOBAL count (zero globals), the five plain-5.1 sweeps and
`check_fresh_server.py`.

## 7. What is NOT this lane's to fix

**Three of the seven vendor kinds have no entity.** `grug_traders` registers
`race`, `general`, `butcher`, `smith`, `fishmonger`, `baker` and `tailor`; the
wave-2 kinds `mason`, `brewer`, `bowyer`, `herbalist`, `armourer`, `tanner` and
`embalmer` are in the socket REGISTRY (`grug_core/settlement_sockets.lua`) but
have no entity yet. The sockets contract's section 8.4 says exactly what happens
then — "a kind whose entity the traders mod has not registered yet is an error
line at placement and an empty socket, never a load failure" — and that is what
happens: three ERROR lines per boot, one each for `vendor_tanner`,
`vendor_brewer` and `vendor_armourer`, and three empty sockets.

**The consequence for the gate is this lane's to report.**
`tools/wp13/run_capital.sh` fails a pass whose log carries any ERROR line, so it
cannot return PASS for Gor Drazhak until the NPC vocabulary lane registers those
three entities. Every pass in the evidence directory therefore carries
`errors=3`, and `gor_drazhak/errors-<seed>.txt` is the complete list of ERROR
and ModError lines in each log -- those three and nothing else.
Dropping the three kinds would make the gate green and would take the three
trades the contract's orc line is built round out of the bazaar, so this lane
did not.

**A generic gap in the capital tooling, reported before it was worked round.**
Lane D's `tools/wp13/capital_plots.lua` is the general lot predicate for a
capital whose plots are ONE district: it reads `capital.district.plots` and the
ground out of `run_capital.sh … scan`, whose sweep covers one quadrant band
(x 52..204, z −96..96). A four-district capital has neither shape.
`highcourt_plots.lua` is the four-district predicate and is hard-wired to the
pilot capital's quadrant module and to its own `field` probe mode, which the
generic probe does not have. This lane wrote `tools/wp13/gor_drazhak_lots.lua`
against the generic `terrain` mode's whole-envelope grid rather than widening
either of those two files. **What the tooling wants, for the two remaining
four-district capitals: a four-district lot predicate keyed by settlement, and a
whole-envelope field dump in `capital_probe`.**

## 8. Open points

1. **Two plots sit exactly on their limit.** `warren_cook_court`'s perimeter
   fall is 6 against a skirt of 6 and `bone_barrow`'s rise is 8 against a clear
   of 8, on the worst of the three worlds. Both are legal and the engine's own
   audit passes them; both are where the next WP40 terrain change will bite
   first. `luajit tools/wp13/gor_drazhak_lots.lua . <grid-a> <grid-b> <grid-c>
   --repair` is the one command that moves them.
2. **The rampart's towers are closed boxes above the walk**, exactly as Dur
   Brannoc's turrets are: the walk passes through them, but there is no flight
   up to the fighting floor and nothing stands there. A manned rampart needs a
   flight and a way for an OVERLAY to publish sockets, which the seam does not
   have — it reads sockets off a prepared blueprint's landmarks and an overlay
   is
   prepared from its specification. That is a seam change and belongs to
   whichever lane first wants guards on a wall.
3. **The rampart's identity is its specification**, and the tower and gate
   positions are not in it — they are derived in the composition from the run
   extents, so moving a tower moves no manifest SHA. What catches it is the
   KAT's built-cell digest and the engine pass's read-back digest, the same
   arrangement the avenue has.
4. **Gor Drazhak carries 207 residents against Highcourt's 144.** Section 5.3
   has the numbers, the reasoning and the one-line knob.
5. **The user has not walked Gor Drazhak.** Nothing here is accepted until they
   have. Section 9 says where to stand.

## 9. Where to walk in

On seed 531802985935182545 the crossing of the two great avenues — the `arrival`
landmark, with the guard banner on it — is at **(0, 95, 1500)**. From there:

* north up the approach to the **warlord hall**, with the **fighting platform**
  on the right of the forecourt: climb its east flight and look back down the
  avenue;
* east into the **muster court**, which is the quarter this capital is meant to
  be recognised by: red sand, a rank of drill posts, the war wains, the
  standards and the two royal booths;
* out of any gate and 209 nodes on to the **rampart**: an earth bank with a
  stockade of sharpened acacia on its crest, a plank walk along the top, a
  brazier every sixteen paces and a timber tower every sixty-four nodes. The
  east gate is at (256, ~90, 1500); walk the walk north to the corner tower and
  look back over the city.

The four districts stand in the four diagonal quarters; which is which depends
on the seed (the probe log's `districts=` line says).

## 10. The fix round (2026-09-15, after the independent review)

Rebased onto `main` at `c8050057` (the wave-2 NPC vocabulary: six activities
animated, seven profession vendors). The review's one blocker and six
should-fixes are below, each with the measurement that closed it. Evidence:
`tools/wp13/evidence/20260915-gor_drazhak/` — the `nine/` directory and the
`fix-round-*` files are this round's.

### 10.1 The blocker: the rampart's walk broke at a corner

**Measured, nine seeds.** `tools/wp13/capital_wall.lua` refuses a corner step of
three or more because a corner tower's own rampart opening is three courses.
Sections 3 and 6 of this note ran it on the two gate seeds and reported "zero to
two nodes". On all nine the raw corner step is:

| seed | worst raw corner step |
| --- | --- |
| 531802985935182545 (gate) | 2 |
| 8675309 (gate) | 2 |
| **15912857179583385436 (the user's world)** | **4** |
| 0 | 3 |
| 1 | 3 |
| 2 | 3 |
| 42 | 3 |
| 12345 | 2 |
| 999999999 | 3 |

So on six of nine worlds — the user's among them — the walk this note invites a
player onto stopped at a corner.

**Why.** `E[p]` is the one-Lipschitz envelope of the ground within `reach`
columns of THIS RUN'S OWN AXIS. The run that arrives at a corner along x and the
run that arrives along z therefore compute their decks from two different
neighbourhoods, and nothing made them agree.

**The fix** is `wp13/orc_palisade.lua` section 1b. Each run's plan now names its
two CORNERS — my column, and the other run's line and column — both runs
evaluate BOTH raw envelopes there, and both clamp their own column to the
maximum of the two. Three properties make it sound, and all three are asserted
rather than argued:

* it is SYMMETRIC: both runs take the same maximum of the same two raw values,
  so they agree by construction and the step is **zero**, not merely small;
* it only ever RAISES a deck, so the no-gap guarantee is untouched — a column's
  fill still starts under its own lowest ground. (The first version of the clamp
  raised `base` instead of the envelope's floor, which lifted the FOOTING off
  the ground; the KAT's own no-gap rule caught it on the first run, and `base`
  and `floor` are two arrays now.)
* the raise is re-swept, so the walk stays one-Lipschitz and the rise is walked
  as treads. A raise deeper than the look-around is REFUSED, because that is
  exactly the condition under which a mapchunk piece that cannot see the corner
  would disagree with one that can.

**The gates.** `tools/wp13/gor_drazhak_rampart.lua` is new and is this module's
own nine-seed predicate: `capital_wall.lua` reads exactly two dumps and ignores
the rest, and it models `wall.lua`'s UNRECONCILED rule, so it is the right gate
for a masonry curtain and the wrong one here. The new tool reports both numbers
— the raw step, so the fix can be seen to do something, and the reconciled one,
which is the gate:

```
worlds 9   worst raw corner step 4   worst reconciled 0
every gor_drazhak rampart line is dry, steps no more than a terrace,
leaves no gap, and its four corners are continuous, on 9 worlds
```

And `gor_drazhak_kat.lua` section 4g asserts the eight corner meetings equal on
a synthetic ground that is now genuinely TWO-DIMENSIONAL — terraced along x and
along z independently, with a shoulder placed inside one run's look-around and
outside the other's at two corners. The first version's field gave every run the
same profile as a function of its own axis, which is the one shape that cannot
expose this defect. **Without section 1b the KAT now fails with
`wall_west walks at 116 where wall_south walks at 121`**, which is the negative
test the brief asks a KAT to pass.

### 10.2 Lot legality and the terrain audit, on all nine

Reproduced the review exactly: 21 of 52 lots illegal on nine worlds, and the
engine's own load-time audit logging 3 findings on seed 2 and 1 on seed 42 (0 on
the other seven). Two things closed it.

**The rise bound is the plot builder's own floor, less the margin, and is read
from it.** `tools/wp13/gor_drazhak_lots.lua` repeated Highcourt's `rise <= 6`
as a literal. The engine's audit refuses a rise greater than the airspace the
plot really CUT, so the true bound is the least `clear_to` any plot publishes —
`gor_drazhak_plot.MIN_CLEAR` — less the two-node interchange margin. The tool
now reads that constant.

**`MIN_CLEAR` goes from 8 to 9**, one course of authored air, **14 630 cells**
of
the 400 000 budget. That is not a rounding: on nine worlds one lot of the
south-west quarter — boxed in by the gate corridor, the ring street and its own
neighbours — had NO legal position within eighty nodes for a rise of seven, and
the alternative was moving a house eighty-four nodes out of its district.

**`--repair` serves the most constrained lot first.** Repaired in roster order,
the first lot of a quarter took the one patch of ground the second could have
used. Counting each broken lot's candidates once, before any of them moves, and
serving the scarcest first is what gave every one of them somewhere to go.

**Result, nine worlds:**

| | first version (3 seeds) | fix round (9 seeds) |
| --- | --- | --- |
| lot repairs off the pure rotation | 6 + 1 fill | **11 + 7 fill** |
| lots legal | 52/52 on 3 | **52/52 on 9** |
| worst perimeter fall / rise | 6 / 8 | **6 / 7** (against skirt 6, clear 9) |
| `audit_terrain` findings | 0 on 3 | **0 on all 9** |
| core + plot cells | 355 234 | **369 864** of 400 000 (Highcourt 376 274) |

Seventeen of the eighteen repairs move four to twenty nodes and stay in their
own row and column. The exception is the south-west quarter's lot 8, which moves
seventy-two nodes to (−204, −144) and stands in the outer band: that quarter is
the one the mesa's own back runs through, and that is the honest cost of the
nine-seed bar.

### 10.3 The work sockets' features

The review found that every `tend` socket passed only because the KAT's feature
list carried `default:desert_stone_block` — a planter's own kerb, which is
neither "a plant" nor "a flower" and which, being an opaque full node, is what
the section 8.1 search stops at. With it removed, four keepers faced a kerb that
blocked their own course and two faced no plant at all.

The list is transcribed from the contract now, entry by entry, with the
contract's own words above each one; `smith` lost a cauldron, `mine` lost gravel
and `pray`/`mourn` lost plain cobble (review N5 — dead entries, but they made
the KAT read stricter than it was). And the six sockets:

| socket | what changed |
| --- | --- |
| `paddock_tend`, `herb_tend_west`, `scrub_tend_west`, `garden_tend_west` | a dry shrub on open ground in front of each, and the socket faces it — a keeper works a plant, not a kerb |
| `war_beast_pen` `pen_tend` → `pen_muck` | **activity changed to `sweep`**: a beast pen has straw, rails and hay and no plant within three nodes of anywhere a keeper can stand, so `tend` was a label its own ground did not carry. `sweep` needs no feature and describes mucking out exactly. |
| `warren_weaver` `weaver_rack` | **activity changed to `carve`**: a drying rack is two acacia posts under a beam. §8.2's `carve` feature is "a log, a totem/statue part or a stone block", and the rack's own end post is the first of those on the socket's course. Scraping a hide on its frame is what the socket now says. |

One more the sweep caught on its own: the barrow's `mourn` socket faced the
burial ground's GATE — a path node — rather than a marker. It faces into the
ground now, at a grave the composition sets for it rather than one the
graveyard's hash happened to leave.

### 10.4 The resident band

Coordinator's ruling for all wave-2 capitals: 150 to 170 residents, at most 25
walkers. The first version had 207 and 31.

Three uniform rules took it there, and none of them moves a cell:

1. **a fill plot's gate spot is a spare, not a resident** (16). A field, a spoil
   heap or a wood yard has a way in and no doorstep, and standing somebody at
   the gate of a paddock for the life of the world is a resident spent on
   nothing. The position stays — a walker may still go there.
2. **every idle spot on a fill yard is a spare** (23).
3. **eight plot spots that were a second person at a feature another socket
   already works** join them — the tannery's second vat, the armourer's second
   forge, the totem court's second carver, and so on.

| | first version | fix round | Highcourt |
| --- | --- | --- | --- |
| idle spawn | 151 | **104** | 108 |
| work | 56 | **56** | 36 |
| residents | 207 | **160** | 144 |
| walkers | 31 | **21** | 22 |
| walker share | 15.0 % | **13.1 %** | 15.3 % |
| spare | 26 | **73** | 26 |
| sockets | 315 | **315** | 256 |

`idle spawn >= work` holds (104 >= 56) and the KAT asserts both it and the
share.
The socket COUNT is unchanged because every trim is a conversion: the standing
positions are all still there, and seventy-three of them are now wander targets
rather than homes, which is what a walker's ring is made of.

### 10.5 The chunk-edge seed the brief asked for does not exist here

`common.md` asks for an engine pass "on one seed where your capital's anchor
root lies on a mapchunk edge". **There is none in the nine-seed set**, and that
is a fact to write down rather than pass over. `luajit
tools/wp13/capital_anchor_fixture.lua .` on `anchor_011` (Gor Drazhak, (0,
1500)):

| seed | anchor_y | root_y | root on chunk edge |
| --- | --- | --- | --- |
| 531802985935182545 | 94 | 95 | no |
| 8675309 | 104 | 105 | no |
| 15912857179583385436 | 128 | 129 | no |
| 0 | 114 | 115 | no |
| 1 | 111 | 112 | no |
| 2 | 98 | 99 | no |
| 42 | 88 | 89 | no |
| 12345 | 80 | 81 | no |
| 999999999 | 84 | 85 | no |

A mapchunk spans `[80k - 32, 80k + 47]`, so an edge is `y = 48, 128, 208`. No
root lands on one; the set's only `true` is `anchor_008` (Highcourt) on the
user's world seed. The requirement is vacuous for this capital on this seed set.

The adjacent case DOES arise and was run: on the user's world seed Gor Drazhak's
anchor itself sits at **y = 128**, a mapchunk's lowest layer, so its SUPPORT is
the first course of a chunk and its root the second. That seed is one of the
three `full` passes. `capital_anchor_fixture.lua` is Lane R's and was not
touched; the seed-set question goes to the coordinator with this table.

### 10.6 Two statements that were not true

* **"the roster placed in full on all three"** (section 6e's table and the
  evidence README) contradicted this lane's own `timings.txt`: on the user's
  world seed the first round measured `guards 27/30 flair 169/207 pending 41`.
  Both now carry the measurement and what `pending` means.
* **`docs/design/settlements.md`** said only the dwarves and the undead raise a
  stone curtain. Highcourt has been walled since the round-3 plan (contract §4:
  "four walled and two open"), so the sentence now names the humans too.

### 10.7 What the fix round measured in the engine

Three `full` passes on the rebased tree, and **`run_capital.sh` returns PASS**:
Lane N's wave-2 vendor entities exist, so the three ERROR lines section 7
recorded are gone and every pass is `errors=0`.

| | 531802985935182545 | 8675309 | 15912857179583385436 |
| --- | --- | --- | --- |
| ERROR / ModError | 0 | 0 | 0 |
| sockets registered | 315 | 315 | 315 |
| roster | `guards 30/30 flair 157/160 vendor 7/7 quest 2/2 pending 3 spare 73` | `guards 30/30 flair 160/160 vendor 7/7 quest 2/2 new 17 pending 0 spare 73 residents 160 walkers 21` | `guards 27/30 flair 101/160 vendor 7/7 quest 2/2 new 10 pending 62 spare 73 residents 160 walkers 21` |
| residents / walkers | 160 / 21 | 160 / 21 | 160 / 21 |
| per-mapchunk steady mean | 0.681 s | 0.611 s | 0.710 s |
| Lethariel control (same treatment, no WP13 cells) | 2.428 s | 2.421 s | 2.172 s |
| mapchunks in the corpus | 60 | 65 | 112 |
| worst plot perimeter fall | 6 | 5 | 5 |
| terrain-audit findings | 0 | 0 | 0 |

`vendor 7/7` is the whole of section 7's first open point closed by somebody
else's lane, exactly as that section predicted.

**The engine's own inventory agrees, socket for socket.**
`tools/wp13/run_npc_probe.sh <out> <seed> capital gor_drazhak` -- the capital
mode Lane N landed with the vocabulary -- forceloads the whole capital, holds
every socket's mapblock and counts what the placement engine actually put
there:

```
capital_blocks    planned=259 asked=259 refused=0 loaded=259 active=252
capital_settle    roster=199 marked=199 live=199 filled=true
capital_inventory sockets=315 carriers=199 standing=199 owed=0 spare=73
                  residents=160 walkers=21 share=13.1
                  roles=guard_patrol=9,guard_post=21,idle=104,quest=2,
                        vendor=7,work=56
                  activities=brew=8,carve=5,chop=6,forage=2,mine=3,mourn=3,
                             pray=2,sit=2,smith=3,spar=8,stall=5,sweep=5,tend=4
                  vendor_kinds=armourer,brewer,butcher,general,race,smith,tanner
capital_gaps      n=0 unmarked=0 of=199
```

`owed = 0` and `capital_gaps n = 0` are the two that matter: with the whole
capital held loaded, every socket that is supposed to carry somebody carries
somebody, and not one of the 315 is empty for a reason the map could give. The
`tend = 4` is section 10.3's two re-labels; the walker share the engine computes
for itself, 13.1 %, is the same number the KAT asserts offline.

`pending` again on the user's world seed, and larger (62), for the reason
section 10.6 records: that world's corpus is 112 mapchunks against the gate
seeds' 60 and 65 -- the capital sits higher there (anchor y 128 against 94 and
104), so its envelope spans more chunks and the emerge sequence leaves more of
the outlying districts' mapblocks unloaded when the probe stops. Nothing is
refused on any of the three, and the boundary seed places all 160 with
`pending 0`.

### 10.8 The load measurement

The review asked for one before a resident ruling was possible, and it is
right that it did: without it "207 is fine" and "207 is too many" are both
opinions. Two passes give the two halves.

**What a capital's NPCs actually cost, per NPC.**
`tools/wp13/run_npc_load.sh /tmp/grug-w2-gor-npc-load 531802985935182545` --
one boot, each of the six starts forceloaded in turn, settled, measured for
thirty seconds and released. Its `micro` event times the mod-side tick of every
settlement NPC directly rather than reading the server step, because the step of
a quiet world reads 90 ms whatever a settlement costs:

| start | NPCs | us per NPC per second | find_path / min | step mean |
| --- | --- | --- | --- | --- |
| dawnmere | 11 | 3.24 | 0.00 | 90.26 ms |
| hearthpine | 11 | 3.29 | 0.00 | 90.25 ms |
| kapok | 11 | 3.49 | 0.00 | 90.28 ms |
| silverleaf | 11 | 2.75 | 0.00 | 90.34 ms |
| stillgrave | 11 | **9.21** | 0.00 | 90.40 ms |
| **sunscar (the orc start, this race)** | 11 | **2.93** | 0.00 | 90.45 ms |

**`find_path` is ZERO in every window**, which is the number the user's own
round-3 ruling names as the cost ("path-finding and animated meshes are the
cost, not the entity count"). A settlement full of standing residents asks the
path-finder for nothing at all; the only caller a settlement has is the patrol
module's stuck rescue, and it did not fire in three minutes of measurement
across six settlements.

**The arithmetic for Gor Drazhak.** 160 residents and 30 guards is 190 NPCs. At
the orc start's own measured 2.93 us/NPC/s that is **557 us of mod-side work per
second of server time**; at the worst of the six (Stillgrave's 9.21, whose
crypt kit costs more per tick) it is 1.75 ms. The server's own step budget is
90 ms eleven times a second, so the whole capital's residents are **0.06 % of
it, and 0.20 % at the worst-case rate**. Animated meshes are the other half of
the ruling and this probe does not separate them from the tick it times; what it
does say is that the tick is the cost and the tick is small.

**What the capital itself reports.** The capital inventory pass above gives the
counts with the whole capital held loaded: 199 carriers standing, `owed = 0`,
`capital_gaps n = 0`, 160 residents, 21 walkers, 13.1 %.

**The honest limit of this measurement.** `run_npc_load.sh` walks the six STARTS
-- its own `collect_starts` filters a settlement to those whose socket anchor is
the published start anchor of its race -- so the per-NPC number above is
measured on eleven-NPC settlements and SCALED to a hundred and ninety, not
measured at that size. Scaling is sound for a per-entity tick and is not sound
for anything quadratic; nothing in `start_villagers.lua`'s tick is quadratic,
but that is a reading of the code and not a measurement. **What the tooling
wants, and what would settle the world-wide question the review raises: a
capital subject in `npc_load_probe`, which is one predicate away from the
capital mode `npc_probe` already has.** That is not this lane's file and is
reported rather than taken.


### 10.9 What the fix round did NOT change

The architecture, the seam, the file ownership and the renders. `wall.lua`,
`avenue.lua`, `capitals.lua`, `parts.lua`, `palette.lua`, `dressing.lua`,
`layout.lua`, `interiors.lua`, `roofs.lua`, every `highcourt*` and
`dur_brannoc*` file and `capital_anchor_fixture.lua` are untouched; outside its
own files this lane still holds one roster row, one line in `final_micro.lua`
and three paragraphs in `settlements.md`. The six start identities, Highcourt's
376 274 cells and the four prior KATs are still byte-identical to `main`'s
(`identity.sh`, which carries `main`'s own values and exits non-zero if one
moves).

### 10.9b One more finding, from the refreshed plot gate

`surface.sh` replays the plot rules over the probe's own per-plot dumps, and on
the boundary seed one row now reads `bone_barrow rise 10 against a clear of 9`
while the engine's audit reports nothing there. Both are right, and the
difference is the probe defect the coordinator already has in hand:
`tools/wp13/capital_probe` builds the blueprint source with NO options, so its
plot list carries the CANONICAL quadrant assignment while the engine's own
settlement was built with the SEEDED one. A dump row therefore names a LOT
correctly and pairs it with the wrong district's plot -- a yard clearing 9
reported on a lot a hall clearing 13 stands on.

`surface_check.lua` now asserts only what survives that mispairing -- water and
perimeter fall are properties of the POSITION, and every lot is held to the same
dry margin and the same six-course skirt whichever plot stands on it -- and
prints a rise over its row's clear as a row to explain. The authority for a rise
is `nine/audit-nine-seeds.txt`: zero findings on all nine worlds. This is
independent confirmation of Lane D's probe bug with a concrete number, not a new
defect.

### 10.10 Open points this round adds

1. **`tools/wp13/capital_wall.lua` reads two dumps and ignores the rest.** Nine
   passed to it report on two. It is Lane D's file and this lane did not widen
   it; `gor_drazhak_rampart.lua` is the nine-seed predicate for this module, and
   the same gap is the reason the blocker survived the first round.
2. **The rampart-line dump spans ±264 and the look-around is 40**, so at a
   corner column (±256) the outermost eight columns of the envelope's window are
   missing from the offline predicate. The engine is the authority; this is
   stated in the tool's own header.
3. **The lot layout is now tuned to nine worlds, and two lots sit on their
   limit** (worst perimeter fall 6 against a skirt of 6, worst rise 7 against a
   clear of 9). `gor_drazhak_lots.lua --repair` over fresh grids is the one
   command that moves them when WP40's terrain does.

## 11. The second rebase, onto `main` at `f5583e13`

Lane N (the wave-2 NPC vocabulary), Lane R (routes end at the 24 gate points)
and Lane D (the Dur Brannoc upgrade, and the capital tooling with it). What the
rebase moved, what it fixed for free and what it cost.

### 11.1 What moved in the rebase

One conflict, in `docs/design/settlements.md`: Lane D added two paragraphs (the
fill ground between the plots, and the dwarf capital's own shape) exactly where
this lane adds two (the palisade variant of a walled capital, and the orc
capital's shape). Both sides are pure additions to the same place; both are
kept, main's first. Everything else merged: the roster row stayed after
`dur_brannoc`, and the `final_micro.lua` rows appended beside Lane R's new
`route_gates_kat`.

**Nothing in this lane's own code changed.** The KAT's every row is
byte-identical across the rebase.

### 11.2 The route gates: zero faults for this capital, on nine seeds

`luajit tools/wp13/route_gates.lua "$PWD" <seed> --strict` on all nine fixture
seeds, wrapped as `evidence/.../gates.sh` (which follows THIS capital's fault
count rather than the world's, and keeps every report under `gates/`). **Gor Drazhak has zero route faults and zero city faults on every one of
them.** The tool's exit status is the whole world's, not one capital's, and it
exits 1 on five seeds -- every one of those faults is **Nhal Veyr's north gate**
(`steps 4 between route grade and avenue road`, `entry breaks 1 time(s), worst
5`), which is the case Lane R's own note §2.1.1 names as "a capital's own
fitting must reach its four gates".

| seed | route faults (world) | city faults (world) | of those, Gor Drazhak's |
| --- | --- | --- | --- |
| 531802985935182545 | 0 | 2 | **0** |
| 8675309 | 0 | 2 | **0** |
| 15912857179583385436 | 0 | 0 | **0** |
| 0 | 0 | 0 | **0** |
| 1 | 0 | 0 | **0** |
| 2 | 0 | 2 | **0** |
| 42 | 0 | 1 | **0** |
| 12345 | 0 | 2 | **0** |
| 999999999 | 0 | 0 | **0** |

**The ground inside the gates, which §3.1 of Lane R's note hands to the capital
lane.** The worst raw terrain step over the eight columns inside a Gor Drazhak
gate, across the nine seeds: **west 3, east 3, south 1, north 2** -- Lane R's own
table says 3/3/—/3 and this reproduces it. The tool refuses 12 and the
contract's own bound is twice the race terrace rise, which is 8, so nothing here
needs terracing: this capital's gate approaches are among the flattest of the
six. And nothing of this lane's is standing in those columns to be disturbed --
the lot predicate holds every plot clear of the four 32-node gate corridors, and
the rampart's own gate passage is authored air from one course over the ground
to the walk.

The gate geometry the contract asks for is satisfied unchanged: the four avenues
run to ±261 so they cross the whole seven-node rampart, the gate passage is
`2 × GATE_PASSAGE + 1 = 7` columns centred on the anchor's own axis (the
contract's floor is 7), and the tool's `approach` rows show all four routes
ending AT their gate (`gate distance 0`, `144` nodes of straight approach) with
`end_cap 15/15` -- the fifteen columns the contract allows inside, paved over by
the avenue.

### 11.3 Lane D's probe fix closes §10.9b

The `EXPLAIN` row §10.9b recorded -- `bone_barrow rise 10 against a clear of 9`
on the boundary seed, where the engine's own audit logged nothing -- was the
probe pairing CANONICAL plot offsets with a SEEDED map. Lane D's
`capital_probe` now passes the seeded assignment, and the plot gate is clean:

```
rows 104   plots 52   illegal 0   to explain 0
worst perimeter fall 6  war_armoury   (skirt 6)
worst rise          7   bazaar_armourer (airspace floor 9)
```

The `worst_plot` the engine names has changed with it -- `war_armoury` and
`war_muster_field` where the first rounds said `warren_cook_court` and
`bone_totem_court` -- because the labels are finally the ones the map holds.
`surface_check.lua` keeps its split (water and fall asserted, a rise over its
row's clear reported) as a guard rather than a live finding.

### 11.4 The nine-seed gates, re-measured on the new terrain

Lane R's change moves the ground INSIDE the envelope: a route no longer grades
anything there, so the anchor fitting meets the hillside on its own. The nine
terrain dumps were therefore re-taken and both gates re-run.

**The layout survives it unchanged.** `gor_drazhak_lots.lua --repair` over the
nine new grids proposes nothing, so none of the eighteen repairs moved and no
nineteenth is needed; `nine.sh` is green end to end:

| | result |
| --- | --- |
| rampart, nine worlds | dry, terrace step, no gap, gates dry; worst RAW corner step 4, **worst reconciled 0** |
| lots, nine worlds | **52/52 legal** |
| `audit_terrain`, nine worlds | **0 findings** |

### 11.5 Two engine passes with the corrected labels

| | 531802985935182545 | 15912857179583385436 |
| --- | --- | --- |
| verdict | **PASS**, `errors=0` | **PASS**, `errors=0` |
| sockets | 315 | 315 |
| roster | `guards 30/30 flair 160/160 vendor 7/7 quest 2/2 pending 0 spare 73` | `guards 30/30 flair 151/160 vendor 7/7 quest 2/2 pending 9 spare 73` |
| residents / walkers | 160 / 21 | 160 / 21 |
| per-mapchunk steady mean | **0.640 s** | **0.473 s** |
| Lethariel control | 2.452 s | 2.375 s |
| mapchunks | 60 | 112 |
| worst plot perimeter fall | 6 (`war_armoury`) | 5 (`war_muster_field`) |
| terrain-audit findings | 0 | 0 |

Both means are lower than the fix round's 0.681 / 0.710 s, and the reason is
Lane R's: a route that no longer grades inside the envelope is work the emerge
no longer does there. The user's world seed now places the whole roster but
nine, against sixty-two before -- the same emerge-corpus effect, smaller.

### 11.5b The interpreter pair

`final-micro.sh` on the rebased tree: **byte-identical**,
`d9b7a41ffa56ca7bdf781fb599cad75b6ced40203fb804aa88bcb3199bd4e8a2`. It moved
from the fix round's `757efd30...` because the set now carries Lane R's
`route_gates_kat` and Lane D's upgraded `dur_brannoc_kat` beside this lane's
rows; **this lane's own eight rows are unchanged across the rebase.**

### 11.6 The whole capital as a plan

`renders/plan-whole-capital.png`, drawn through Lane D's new generic
`tools/wp13/dump_capital_plan.lua` at seed 531802985935182545: 52 plots, 789 883
cells on one flat plane, with the quarters this world's permutation gives --
lore south-east, market north-west, martial south-west, residential north-east.
It is the picture the contract's §2.3 density question wants and no number
answers: the rampart ring with its towers, the four avenues and the ring street,
each quarter's lane pair and its 3 × 3 grid with the fill lots pushed out into
the outer band, and the dense core in the middle.

What it also shows, honestly: a band of open ground roughly thirty nodes deep
between the outermost fill lots and the rampart. That is the wall margin every
walled capital has and it is where a later increment would put what a city keeps
against its own wall.
