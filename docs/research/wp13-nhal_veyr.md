# WP13: Nhal Veyr, the undead capital and the raised necropolis

Increment record, 2026-09-15, written against `main` at `922bfd92` ("Extend the
socket vocabulary for the wave-2 capitals") and rebased onto `c8050057` ("Merge
the wave-2 NPC vocabulary"), which is where the `herbalist` and `embalmer`
trader entities this capital's sockets ask for come from. It is the third capital of the
capitals contract's section 3 order and the second WALLED one (the user's
ruling of 2026-09-14: walls for Dur Brannoc, Nhal Veyr and Gor Drazhak; open
edges for Lethariel and Kezamba, with Highcourt joining the walled three
through the round-3 plan).

Contracts implemented:
[wp13-capitals-pois-contract.md](wp13-capitals-pois-contract.md) (2.1 what a
capital is, 2.3 the budgets, 2.4 the undead row of the race table, 4 the
rulings on the king's hall, the sockets and the walls) and
[wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md), including the
WAVE-2 vocabulary of its section 8.2, which this capital is the first structure
lane to author. The standard it is measured against is the pilot's:
[wp13-highcourt.md](wp13-highcourt.md), [wp13-highcourt-districts.md](wp13-highcourt-districts.md)
and [wp13-highcourt-fill.md](wp13-highcourt-fill.md). The wall it inherits is
[wp13-dur-brannoc.md](wp13-dur-brannoc.md) section 2, unchanged.

Evidence: `tools/wp13/evidence/20260915-nhal_veyr/`.

## 1. What shipped

| File | Change |
| --- | --- |
| `wp13/nhal_veyr.lua` | **new**: the 96 × 96 civic core, the avenue, ring and wall run specifications, and the overlay dispatch |
| `wp13/nhal_veyr_plot.lua` | **new**: the plot builder, `highcourt_plot.lua`'s rule in the undead palette with this capital's two handles |
| `wp13/nhal_veyr_quadrants.lua` | **new**: the four lot grids, the four fill grids, the eight district lanes and the seeded permutation |
| `wp13/nhal_veyr_districts.lua` | **new**: where the four rosters and the quadrants meet |
| `wp13/nhal_veyr_district.lua` | **new**: the ossuary market and trades district |
| `wp13/nhal_veyr_district_martial.lua` | **new**: the bone watch |
| `wp13/nhal_veyr_district_lore.lua` | **new**: the vigil |
| `wp13/nhal_veyr_district_homes.lua` | **new**: the kept houses |
| `wp13/undead_parts.lua` | **new**: the two parts the shared kit has no equivalent of — a mausoleum and a candle court |
| `wp40/r7_nhal_veyr_blueprint.lua` | **new**: the capital source the seam reads — core, 52 plots, one overlay of twenty runs |
| `wp40/r7_settlement.lua` | one roster row; nothing else |
| `tools/wp13/nhal_veyr_kat.lua` | **new**: acceptance for the core, every plot, the lots, the avenues and the wall |
| `tools/wp13/nhal_veyr_plots.lua` | **new**: the committed lot predicate |
| `tools/wp13/final_micro.lua` | the new KAT joins the interpreter pair |
| `wp13/wall.lua` | **section 1b**: the corner reconciliation, and the one field of the plan it reads (section 3b). Nothing else in the module moves — `HALF`, `RISE`, `FOOTING`, `REACH` and `GATE_PASSAGE` are untouched, and a run whose plan authors no `corners` is built exactly as before |
| `wp13/highcourt.lua`, `wp13/dur_brannoc.lua` | the same four `corners` entries in each wall plan; nothing else |
| `tools/wp13/capital_wall.lua` | the same clamp modelled, so its corner rule becomes a standing gate |
| `tools/wp13/capital_probe/init.lua` | a `<key>-corner.tsv` region — the four places two wall runs meet, which no other dump contains (section 6 (f)) — and a dump region that may be a list of boxes |
| `tools/wp13/capital_probe/init.lua`, `run_capital.sh` | **Lane D's**: one dump region, the steepest gate approach out to 261 (section 6 (d)) |
| `tools/wp13/route_gates.lua` | **Lane R's**: each capital's avenues are built through its own `M.overlay_run` where it has one (section 6 (d)) |

Not touched: the six start compositions, the rest of `highcourt*.lua` and
`dur_brannoc*.lua`,
`avenue.lua`, `capitals.lua`, `buildings.lua`, `parts.lua`,
`palette.lua`, `dressing.lua`, `layout.lua`, `interiors.lua`, `roofs.lua`, and
every WP40 file but the roster row and the new blueprint source. Section 6 (b)
carries the proof.

**`palette.lua` needed no change at all.** The undead capital vocabulary —
`castle_wall` as dungeon stone, `castle_slit` as the obsidian arrowslit,
`signature` as obsidian brick — was already in the file when Dur Brannoc landed
the castle kit, and it is exactly what this capital wanted. That is the one
place this lane spent nothing.

## 2. The identity, and where each half of the contract's line is built

The contract's section 2.4 row is "raised necropolis, step 3" and "dungeon
stone and obsidian brick, mausoleum core, stepped terraces with ruins mixed
among kept houses, candles and iron bars".

| The line | Where it is |
| --- | --- |
| dungeon stone and obsidian brick | the CRYPT handle of `nhal_veyr_plot.lua`: `wall` → `grug_decor:castle_dungeon_stone`, `wall_accent` → obsidian brick, `floor` → castle pavement, under a VAULT roof of dressed stone brick (section 7, point 7). Every civic building of the core and every civic plot of a district is built with it; the houses keep the Stillgrave palette's gravewood boards |
| mausoleum core | the core's north quarter: `capitals.king_hall`, built and roofed in that handle, its nave floor laid in grave slabs with four votive lights between the bays. The architecture is the library's, because the contract's own ruling of 2026-09-14 is that the core builds the throne room the king encounter will use |
| stepped terraces | WP40's, and the whole reason a district plot is terrain-relative: the undead envelope steps three nodes (section 3) |
| ruins mixed among kept houses | two of the nine lots of the kept-houses district carry a `buildings.ruin` between the cottages, the vigil district's ruin close carries two more on one fill lot, and the core itself has one fallen shell between its two west houses |
| candles | `undead_parts.candle_court` on a fill lot of every district, the two standards of every mausoleum, the votive lights of the mausoleum core, and the candle works of the vigil district |
| iron bars | the palette's `window` is `xpanes:bar_flat` — every opening in this city is barred — and the core's citadel parapet carries a barred opening on every fourth column instead of a merlon |

Two things in that table are DESIGN DECISIONS of this lane and not the
contract's, and are labelled here as the brief asks: the grave fields that
stand where Highcourt has crop fields, and the ossuary court that is this
capital's signature quarter where Dur Brannoc has a forge court. Both come
from the lane brief's own design space.

## 3. The ground, measured before anything was designed against it

`tools/wp13/run_capital.sh <out> nhal_veyr terrain <seed>` samples the four
candidate wall lines column by column across the wall's own thickness, plus a
4-node grid of the whole 512 envelope and its collar. It runs BEFORE the
capital is on the roster, which is the only way to measure a capital that does
not exist yet.

**WHAT THE THREE NAMED SEEDS ARE CALLED HERE**, because an earlier draft of this
record used "the user seed" for two of them. `531802985935182545` is **the gate
seed** (`common.md`'s first gate seed, the one this package's single-pass proofs
use); `8675309` is **the boundary seed** (the second gate seed); and
`15912857179583385436` is **the user's world seed**. The other six of the nine
are named by their number.

WP40 fits Nhal Veyr's anchor at **(−1800, 106, 1500)** on the gate seed and
**(−1800, 100, 1500)** on the boundary seed.

| seed | line | wet columns | worst step | low | high | range |
| --- | --- | --- | --- | --- | --- | --- |
| 531802985935182545 | west | 0 | 2 | 72 | 118 | 46 |
|  | east | 0 | 3 | 69 | 121 | 52 |
|  | south | 0 | 2 | 91 | 127 | 36 |
|  | north | 0 | 2 | 75 | 103 | 28 |
| 8675309 | west | 0 | 2 | 65 | 112 | 47 |
|  | east | 0 | 2 | 70 | 109 | 39 |
|  | south | 0 | 1 | 73 | 85 | 12 |
|  | north | 0 | 1 | 70 | 94 | 24 |

Read out of that:

- **NOT ONE COLUMN of the envelope is water**, on either seed — 0 of 21 025 in
  the coarse grid and 0 of 14 840 on the wall lines. The Kragmar blight has no
  river in it. That is the opposite of Highcourt, whose two rivers are the
  reason its four lot grids differ from one another, and it is why this
  capital's grids are the authored layout rotated rather than four separate
  designs.
- **The ground never steps more than three nodes** along a wall line, which is
  exactly the undead terrace step of the contract's section 1. `wall.lua`'s
  one-Lipschitz rule is written for that and the deck steps down one node at a
  time over it.
- **The widest spread along one line is 52 nodes.** A wall that followed the
  ground naively would be 52 nodes of staircase; what it is instead is a deck
  that never changes by more than a node per column over masonry that starts
  under each column's own lowest ground.

## 3a. The curtain wall's corners, on all nine seeds — FOUND, AND FIXED

**This section's finding is now closed, in `wp13/wall.lua` section 1b, and
section 3b is the fix.** What follows is what the defect WAS, kept because the
measurement is the reason the fix exists and because it is the shape of the
defect any future change to the wall module has to stay clear of. Every number
in it is a BEFORE number.

`tools/wp13/capital_wall.lua` asks whether the real ground under the four wall
lines is ground the module's rules were written for, and one of its five
questions is the one the wave-2 review asked every walled capital for: **where
an x-run's walk arrives at a z-run's CORNER TURRET, how far does it step?** The
turret's own rampart opening is three courses, so a step of **two or less** is
walked through a three-course opening and anything more is a break in the
circuit. That is what the predicate asserts: it fails at `step >= 3`
(`capital_wall.lua`'s `CORNER_OPENING`), not at more than three.

`wall_all.sh` runs the predicate over the nine seeds as eight consecutive
pairs, 64 corner measurements in all:

| step | 0 | 1 | 2 | 3 | 4 | 5 | 7 | 9 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| corners | 16 | 12 | 12 | 4 | 4 | 9 | 5 | 2 |

**TWENTY-FOUR of the sixty-four fail the predicate** — every step of 3 or more,
which is 4 + 4 + 9 + 5 + 2 = 24 — **and the worst steps nine nodes.** (The first
draft of this section said twenty; it had counted only the steps ABOVE three and
so undercounted its own re-run by four. The re-run itself reports 24 findings.)
On the two gate seeds alone, three of the eight corner measurements break:
`wall_east`/`wall_north` steps 7 on the gate seed, and on the boundary seed
`wall_west`/`wall_north` steps 3 and `wall_east`/`wall_north` steps 5. The
rampart of this capital is not a continuous circuit.

**It is the module's mechanism and this capital's ground.** Measured the same
way on the same two gate seeds (`wall-across-capitals.txt`):

| capital | corner steps, both gate seeds | worst wall-line range |
| --- | --- | --- |
| Dur Brannoc | 0, 0, 0, 0, 1, 1, 1, 0 | 36 |
| Highcourt | 2, 2, 2, 2, 1, 0, 1, 2 | — |
| **Nhal Veyr** | **0, 1, 1, 7, 0, 3, 2, 5** | **52** |

Two perpendicular one-Lipschitz envelopes meeting at a corner agree exactly
when the ground they each smooth agrees, and `wall.lua` computes each run's
deck from its OWN axis over a 40-column look-around. Dur Brannoc's granite
terrace is calm enough at its corners for the two to land within a node;
Nhal Veyr's raised necropolis ranges 47 to 52 nodes along a single line and
they do not.

**WHAT FIXES IT IS THE MODULE'S.** The composition cannot: the divergence
is between two runs' envelopes and a run sees only its own. So the coordinator
handed this lane `wp13/wall.lua` for the corner reconciliation and nothing else,
with Lane O's solution of the same defect in its own palisade
(`wp13/orc_palisade.lua` section 1b, branch `wp13-w2-gor-drazhak`) as the shape
to follow. Section 3b is what landed.

## 3b. `wall.lua` section 1b: the corners, reconciled

**THE RULE.** Each wall run's authored plan gains one field, `corners`: the pair
of places this run's walk MEETS another run's, each entry naming MY column and
the OTHER run's line and column. A z-run meets an x-run at its own corner
turret's centre column (±256); the x-run meets it four columns earlier at its
own end (±252), where its walk stops and the turret's city-face opening begins.
Both runs of a pair name the same two places.

At each of its corners a run evaluates BOTH raw envelopes — its own, and the
other line's, reproduced by sampling that line's seven lanes over ±`reach` of
its column — and clamps its own column to the MAXIMUM of the two. Three
properties make that sound, and they are the same three Lane O's palisade rests
on:

- **It is SYMMETRIC.** Both runs take the same max of the same two raw values,
  so the corner step is not merely small, IT IS ZERO. Re-sweeping cannot spoil
  that: with the floor raised to `datum` at column `c`, the swept value at `c` is
  `max(datum, max over r != c of floor[r] - |c - r|)`, and that second term is at
  most the RAW envelope at `c`, which is at most `datum`. So the swept value at
  `c` is exactly `datum`.
- **It only ever RAISES a deck**, so the no-gap guarantee is untouched: a
  column's masonry still starts under its own lowest ground. `base` — the true
  lowest ground of a column, which the footing is measured down from and the gate
  passage cleared up from — never moves; what the clamp raises is `floor`, the
  envelope's INPUT. Conflating the two would lift a footing off its own ground,
  which is the gap the whole module exists to make impossible.
- **The raise is RE-SWEPT**, so the walk stays one-Lipschitz and the rise is
  walked as treads over the columns leading up to it.

And one guard: a raise deeper than the look-around is REFUSED with an error. The
clamp's influence decays by one node per column, so it reaches
`datum - E[corner]` columns, while a mapchunk piece whose window excludes the
corner is at least `reach` = 40 columns away from it. The two are consistent
exactly while the raise is no deeper than the look-around, and that line is what
says so rather than a comment hoping it. `HALF`, `RISE`, `FOOTING`, `REACH` and
`GATE_PASSAGE` are untouched, and a run whose plan authors no `corners` — an
open capital, a fixture — is left exactly as it was.

**NHAL VEYR: CORNER STEP 0 ON ALL NINE SEEDS.** `wall_all.sh` again, the same 64
measurements section 3a reported:

| step | 0 | 1 | 2 | 3 or more |
| --- | --- | --- | --- | --- |
| corners BEFORE | 16 | 12 | 12 | **24** |
| corners AFTER | **64** | 0 | 0 | **0** |

`tools/wp13/capital_wall.lua` models the module rather than calling it, so the
clamp is modelled there too, and its section 5 is now a STANDING GATE instead of
a measurement somebody reads: zero findings on all eight consecutive pairs of the
nine fixture seeds.

**THE TWO SHIPPED CAPITALS MOVED ONLY AT THEIR CORNERS.** The constraint on this
commit was that Highcourt's and Dur Brannoc's built ramparts may move in corner
cells and nowhere else. It is proved twice below — and a THIRD time, in the
engine, by the re-review of 2026-09-16: section 6 (f) carries that measurement
and the dump region this package added so nobody has to take it by hand again.

*Offline, exhaustively.* Every cell of all four wall runs of both capitals, built
whole out of the real WP40 height session, before (`main` at `f5583e13`) against
after, on both gate seeds:

| capital | seed | changed cells | columns | worst distance from a corner |
| --- | --- | --- | --- | --- |
| Dur Brannoc | 531802985935182545 | 112 | 2 + 2 | 1 |
| Dur Brannoc | 8675309 | 27 | 1 | 0 |
| Highcourt | 531802985935182545 | 802 | 22 + 5 | 18 |
| Highcourt | 8675309 | 184 | 4 + 2 | 3 |

Every changed cell is within the look-around window of a corner column of its own
run's axis; **the worst is 18 columns of a look-around of 40**, and not one lies
outside. (`classify.py` used to print the column range instead, which for a run
that moved at both of its corners reads `-252..252` and looks like a
five-hundred-column spread; it prints the count, the worst distance and the
contracted column set now, which is what the question wants. Review note N1.) **Neither capital's z-runs moved at all** —
`wall_west` and `wall_east` are byte-identical on both seeds, on both capitals —
which is the clamp's "only ever raises" property showing up as evidence: at every
one of these corners the z-run already held the maximum and the x-run rose to
meet it. Highcourt's `wall_north` on the gate seed spreads over eighteen columns
because its deck there was already climbing at exactly one node per column, so a
TWO-node raise at the corner (deck 60 to 62) carries all the way back as treads;
the raise itself is two nodes, not eighteen.

*The corner step read off those same dumps:*

| capital | seed | west/south | west/north | east/south | east/north |
| --- | --- | --- | --- | --- | --- |
| Dur Brannoc | 531802985935182545 | 1 -> **0** | 1 -> **0** | 0 -> 0 | 0 -> 0 |
| Dur Brannoc | 8675309 | 0 -> 0 | 0 -> 0 | 1 -> **0** | 0 -> 0 |
| Highcourt | 531802985935182545 | 2 -> **0** | 2 -> **0** | 2 -> **0** | 2 -> **0** |
| Highcourt | 8675309 | 1 -> **0** | 0 -> 0 | 1 -> **0** | 2 -> **0** |

The BEFORE column reproduces the committed `wall-across-capitals.txt` table of
section 3a exactly, from a different tool on a different input, which is what says
both measurements are of the same thing. Nhal Veyr's own curtain read the same
way — there is no BEFORE for it, because it does not exist on `main` — gives
`west/south 109, west/north 94, east/south 125, east/north 92` on the gate seed
and `82, 85, 91, 94` on the boundary seed, step 0 in all eight and the same eight
numbers `capital_wall.lua` reports from the terrain dumps.

`tools/wp13/evidence/20260915-nhal_veyr/corners/` carries the tool
(`wall_cells.lua`), the runner, the four raw diffs and the classification.

*In the engine.* Eight full passes — both capitals, both gate seeds, before on a
pristine export of `main` at `f5583e13` and after on this branch. Every one of
them PASSES, and every digest the runners gate on is BYTE-IDENTICAL across the
pair:

| pass | avenue | rampart / wall | gate |
| --- | --- | --- | --- |
| Dur Brannoc 531802985935182545 | `20d17012…` = | `d5030431…` = | `e135f724…` = |
| Dur Brannoc 8675309 | `2f8f54a4…` = | `6ca991b4…` = | `27ea04ef…` = |
| Highcourt 531802985935182545 | `0619c8eb…` = | dump sha `2ce7f3c8…` = | dump sha `46ca5425…` = |
| Highcourt 8675309 | see `corners/` | = | = |

They are identical because the two probes' rampart regions are the EAST curtain
either side of the anchor (Dur Brannoc z = −80…80, Highcourt z = 36…92) and
neither contains a corner — which is the constraint restated as a measurement:
the corner commit moved nothing a shipped capital's frozen dump can see. The
exhaustive whole-curtain diff above is what covers the corners themselves.

**One pre-existing failure, and it is not this lane's.**
`run_capital.sh full dur_brannoc <gate seed>` exits 1 on `main` at `f5583e13`
ITSELF, on both gate seeds, because the committed
`evidence/20260915-capital-terrain/dur_brannoc/avenue-digest-<seed>.txt` no
longer matches what the engine builds: the avenue follows the ground, and
Lane R's routes ending at the capital gates moved the ground. The BEFORE and
AFTER digests are equal to each other (`20d17012…`, `2f8f54a4…`), so the drift is
main's and not the corner commit's, and the expectation file is left alone for
whoever owns that measurement. Dur Brannoc's rampart and gate digests still match
their committed values on both seeds, before and after.

**THE KAT RULE, red without the fix.** `nhal_veyr_kat.lua`'s wall section (f) is
the standing test. Its synthetic ground is TWO DIMENSIONAL now — it had been one
profile per run evaluated along that run's own axis, which is enough for every
single-run rule and a fiction for a rule that reads the other line — and it
carries two SHOULDERS: patches of ground twelve nodes high, six columns from a
z-run's corner column and four columns clear of the x-run's lanes, so they stand
inside one run's look-around and outside the other's. At those two corners the raw
envelopes differ by 6; at the other two they agree exactly. The rule asserts both:
the built step is 0 at all four corners, AND the raw split is at least the
turret's three-course opening at the two shouldered ones and zero at the others,
so the fixture cannot quietly stop testing anything. `mutations.sh` carries the
proof as its fourth mutation — with the clamp's two lines removed, the KAT goes
red with "wall_west/wall_south: the walk steps 6 nodes at the corner".

**And nothing else moved.** `identity.sh` on this tree against an export of
`main` at `f5583e13`: the six start blueprint identities, `library_kat`,
`blueprint_kat`, `highcourt_kat` and `dur_brannoc_kat` are byte-identical.

**That equality is NOT evidence about the corners, and is not offered as any.**
A blueprint identity is frozen over the SPECIFICATION of an overlay -- the runs,
the carriageway, the palette -- and `wall_plan` is not in it, for the same reason
section 8 point 7 gives about the turret and gate positions. An identity that
moved would mean something; an identity that did not move means the seam was not
asked. What measures the corner change is the cell diff above and the engine
region section 6 (g) adds. The two
pilot capitals' own KATs build their walls over synthetic profiles whose corners
already agreed, so the clamp finds nothing to do there — which is worth knowing,
because it means those two KATs could not have caught this defect and the
shouldered fixture above is the first that can.

**Calibration of the coarse grid.** The grid dump samples every FOURTH column
and the lot predicate is built on it, so how much that hides is measured rather
than assumed. Against the 1-node wall lines of the SAME dumps, over the same
31-column window, at 464 window positions per seed
(`terrain/calibration.txt`): 4-node sampling understates a **fall by at most
one node** and a **rise by at most two**. That is why `nhal_veyr_plots.lua`
derives a district lot against a fall of 5 and a rise of 6 where the real
limits are 6 and the plot's own clear of at least 8, and a fill lot against a
rise of 5 because a yard plot clears the builder's floor of 8 and nothing more.
Every margin is the measured error or better, and the engine pass of section
6 (e) is what confirms it on the real ground.

## 4. Where the lots stand

`tools/wp13/nhal_veyr_plots.lua` is the committed predicate: dry, inside the
skirt, under its own roof, inside its own quarter, clear of the core, the four
32-node gate corridors, every street run the overlay writes — the avenues, the
ring, the eight district lanes AND the curtain — and a lane clear of every other
lot. Since the review round it also carries the FOUR-GATE section of section
6 (d), because a gate ramp is a property of the same terrain the lots stand on
and both are answered from the same nine dumps in one run.

**Re-run on `f5583e13`'s terrain, which moved.** Lane R's routes ending at the
capital gates re-grade the columns they approach on, so the nine terrain dumps
this predicate reads are not the ones the first version of this section was
derived against — 616 of the gate seed's 21 025 grid rows differ. The committed
grids were NOT re-derived for it: all 52 lots are still legal on all nine
worlds, and all 36 gate rows still legal, on the new ground.

**ON ALL NINE SEEDS, and that is the whole of this section's history.** The
first version of these grids was derived against the two gate seeds, which is
how the pilot capital's were derived and is how this lane started. The wave-2
coordinator's review of the first two capitals then found twenty-one illegal
lots in another lane on seeds nobody had looked at, and the same predicate run
over the nine seeds of `capital_anchor_fixture.lua` said the same thing here:
**34 of this capital's 52 lots stood somewhere they may not**, sixteen of them
with a perimeter fall of 6 to 11 against a skirt of 6. Two worlds is not a
sample.

Re-derived against all nine, of 52 lots: **9 keep the authored position, 18
slid twelve nodes or less, 25 slid further**, the worst of them 76. Nothing is
homeless: every lot is dry on all nine worlds, falls at most 5 and rises at most
6 (5 for a fill lot) at the grid's own resolution, and the engine's own
per-plot measurement of section 6 (e) confirms it on the real ground.

The authored 3 × 3 layout is therefore a starting point on this terrain and not
a plan: what survives nine worlds is scattered, and the tables in
`nhal_veyr_quadrants.lua` are what the search returned rather than what anyone
drew. That is the honest cost of a raised necropolis whose envelope ranges 47
to 52 nodes along one wall line.

**Fill slot 4 cannot stand where it is authored on any world, and the reason is
arithmetic rather than ground.** The authored close is a 5-reach lot in the gap
between two columns of the grid; a 5-reach lot with two nodes of margin is 15
wide, the gap between two 31-wide footprints 44 apart is 14, and a four-node
lane either side needs 23. It takes the nearest open ground inside its own
quarter in all four. Highcourt's own fill slot 4 stands where it does because
its grid is staggered; this one's cannot.

## 5. The core, the districts and the socket table

### 5.1 The core

96 × 96, bounds x/z [−47, 47] and y [−2, 31] inside the contract's [−2, 40],
flat at y = 0 by construction, anchor-relative exactly like a start.

| Quarter | What stands there |
| --- | --- |
| North, z 6..37 | the **mausoleum**: the library's 31 × 27 basilica on its podium in dungeon stone under a vaulted roof, throne at the north end, four turrets, ridge lantern; the composition lays its nave floor in grave slabs with four votive lights |
| North-east, x 22..45 | the **ossuary court**, this capital's signature: the bone works, the charnel yard, the two royal booths, gravewood stacks, coffin crates, the wax pots and the embalmer's slab line on one paved court |
| West | the **cistern court**, the **hall of vigil** (the library's temple, which carries the capital's one quest socket) and a house |
| South-west | the **market square** (25 × 25), two houses and the core's own **fallen shell** between them |
| South-centre | the two **colonnades** flanking the throne approach and the king's **statue** |
| South-east | the **travel plaza** reserved for WP17, the **bonesmiths' guild** and two houses |
| The turf between | a **burial ground**: 122 markers on flagstones and 15 gravewood stands among them |
| The boundary | a **citadel parapet**, 229 columns of dungeon stone with merlons on a four-node rhythm and a BARRED OPENING on every fourth column between them (56 of them), and a crenellated **drum at each corner** |

### 5.2 The districts

Four districts of nine building lots and four fill dressings each, assigned to
the four quadrants by a permutation of the world seed through R6's own
construction with this capital's own prefix.

| District | Role | What it is |
| --- | --- | --- |
| `nhal_veyr_market` | market_professions | the ossuary market: bone store, cart yard, bonesmith, shroud house, cistern, watch, gravewood copse, physic house, charnel store; fill of a grave field, a bone yard, a candle court and a close |
| `nhal_veyr_watch` | martial_garrison | the bone watch: barracks, captain's hall, armoury, stables, drill yard, quartermaster, cart shed, serjeant's house, watch tower; fill of a muster field, a bone rampart, a pyre court and a close |
| `nhal_veyr_vigil` | lore_spiritual | the vigil: ossuary, scriptorium, embalmer's house, **two mausolea**, candle works, cloister garth, watch, copse; fill of the old burial ground, a **ruin close**, the high vigil and a close |
| `nhal_veyr_homes` | residential_cultural | the kept houses: four cottages, **two fallen shells between them**, the mourners' hall, the watch, the cistern; fill of the family plots, the blight garden, a candle court and a green |

### 5.3 The socket table

The settlement registers **274** sockets, against Highcourt's 256.

| Role | Nhal Veyr | Highcourt |
| --- | --- | --- |
| `king` | 1 | 1 |
| `waypoint` | 1 | 1 |
| `quest` | 1 | 2 |
| `vendor` | 6 | 7 |
| `guard_post` | 21 | 19 |
| `guard_patrol` | 50 | 56 |
| `idle` (incl. spares) | 142 | 134 |
| of which SPARE | 26 | 26 |
| `work` | 52 | 36 |
| **residents / walkers** | **168 / 24 (14.3 %)** | 144 / 22 (15.3 %) |

Residents are the spawn sockets — `work` plus `idle` with `spawn ~= false` —
and the walker share is the sockets contract's section 8.3 arithmetic,
`ceil(I / 5)` of `I + W`, inside its 10–30 % band. 116 idle spawn sockets
against 52 work sockets is comfortably the "at least one idle spawn socket per
work socket" the contract asks for.

**The activities placed.** The KAT counts all FIFTEEN activity names the socket
contract knows and prints every one of them, which is why three zeroes stand in
the line below; TWELVE of the fifteen are actually placed:

```
brew=3 carve=5 chop=1 forage=2 mine=2 mourn=11 pray=9
sit=6 smith=2 spar=5 sweep=2 tend=4      (farm=0 fish=0 stall=0)
```

Six of those are the WAVE-2 names of section 8.2 and Nhal Veyr is the first
capital to author any of them. `farm` and `fish` are deliberately zero: a
necropolis grows no crop and this envelope has no water anywhere, so the grave
fields carry `mourn` and `tend` where Highcourt's fields carry `farm` and its
pond carries `fish`.

**The vendor kinds placed**: `race` and `general` in the core's ossuary court,
`smith`, `tailor` and `herbalist` in the market district, `embalmer` in the
vigil. One of each, which the KAT's family rule asserts across every
composition at once.

**All six kinds have an entity.** `herbalist` and `embalmer` are WAVE-2 kinds
and had none while this package was being built, which the sockets contract's
section 8.4 covers ("a kind whose entity the traders mod has not registered yet
is an error line at placement and an empty socket, never a load failure"): every
engine pass carried exactly those two ERROR lines and nothing else. Lane N
landed the seven wave-2 vendor entities on `main` at `c8050057`, this package
was rebased onto it, and the passes of section 6 (e) carry **no ERROR and no
ModError line at all**.

## 6. Verification

**The tree these numbers were taken on.** The engine and terrain measurements of
this section were taken on `main` at **`f5583e13`** and the package is rebased
onto **`1c9e0f39`**, the wave-2 merge (Gor Drazhak, Lethariel and Kezamba).
NOTHING WP40 MOVED BETWEEN THE TWO — `git diff f5583e13 1c9e0f39 -- wp40/` is
three new blueprint files and the roster row, and `avenue.lua`, `wall.lua`,
`palette.lua` and `parts.lua` are untouched — so the nine terrain dumps, the lot
and gate predicates and the nine-seed wall sweep are re-run against them on the
new base and reproduce byte for byte. The full pass of section 6 (f) and the
identity gate of 6 (b) are taken on `1c9e0f39` itself.

`f5583e13` brought the wave-2 NPC vocabulary (Lane N), the WP40 routes ending at
the capital gates (Lane R) and the Dur Brannoc upgrade (Lane D). Three things in
that base matter here:
Lane R's route ends are what section 6 (d)'s gate table is measured against;
Lane D's `capital_probe` now passes the world's SEEDED quadrant assignment to
the blueprint source, so every plot dump and every render below is labelled with
the district the map really holds (this package's first pass was labelled with
the canonical assignment and is re-derived); and Lane D's `run_capital.sh` gained
the `field` and `edge` modes, which this package does not use but which share the
file the gate-approach dump was appended to.

### (a) The KAT, both interpreters

`tools/wp13/nhal_veyr_kat.lua` is `highcourt_kat.lua`'s acceptance for a
four-district capital, applied to this one: the core's envelope, budget,
canonicity and flat ground course; every emitted name against the real registry
and the authored tables of `parts.lua` in both directions; the two shape rules;
every pane settled the way `update_pane` would; every attached node on the
support its rating names; no detached cell and no island; every torch on an
opaque full node; the exact light population; every doorway passable with a
walkable step on both sides; every closed room roofed and lit; every
destination reachable from `arrival`; the socket contract with the exact role
multiset and every loop walked 1..n; the flat ground course; the four gate
openings walkable end to end; the king on his throne facing his hall; one
vendor of each kind; the plaza empty; the permutation's arithmetic; the 36 lots
and 16 fill lots against their own envelope; every plot's reference column,
foundation skirt, cleared airspace and lot fit; the avenue overlay on a
synthetic terrace profile; and the curtain wall.

Three rules in it are this lane's own:

- **the six wave-2 activities** and the feature each names, built from the
  palette's roles wherever the contract names a palette thing. `mourn` is a
  grave marker or a candle; `forage` is a vine or leaves and explicitly NOT the
  bone piles of `undergrowth`, because a bone pile is none of the five things
  the contract lists and a rule that accepted it would accept anything;
- **`spar` has two readings** and the KAT implements both: the training-dummy
  name set, and — where no name is found — another `spar` socket within three
  nodes along the socket's own facing, which is what two guards sparring
  actually is;
- **the curtain wall's corners** (rule (f), section 3b): the four runs are built
  over a two-dimensional synthetic ground with two shoulders that split two of
  its corners apart, and the walk must arrive at every corner with a step of
  ZERO while the raw envelopes at the two shouldered corners still differ by at
  least the turret's three-course opening.

The feature search and the feature sets were both TIGHTENED by the review of
2026-09-16, which had proved them toothless by mutation: the search read one
course BELOW the socket's feet, so the paved court a resident stands on answered
for the feature in front of them, and `mine`, `pray` and `carve` carried the
plot's own paving roles. The search is `dy = 0, 1` now, `mine` is rock names
only, and `signature`/`foundation` — which in this palette are the same node and
between them the footing of every building in the city — are out of `carve` and
`pray`. `mutations.sh` is the evidence: four mutations, all red.

```
WP13 FINAL MICRO PAIR BYTE-IDENTICAL
c9c4fc8f5c2e986822b5875ab0e4bc5138eacb19991d7aaabd44c636703afe61  micro-luajit.tsv
c9c4fc8f5c2e986822b5875ab0e4bc5138eacb19991d7aaabd44c636703afe61  micro-puc51.tsv
```

That is the whole WP13 fixture set in one process under each interpreter, this
KAT among them.

### (b) Every capital already on main is byte-identical

The same fixtures, run on this tree and on an export of `main` at `1c9e0f39` —
the wave-2 merge, so Gor Drazhak, Lethariel and Kezamba are in the list too, and
three of those five capitals share `wall.lua` and all five share
`capital_probe` — **with the corner reconciliation of `wall.lua` section 1b, the
gate ramp, the gate tunnel and the new corner dump region in the tree**:

| fixture | main 1c9e0f39 | this lane |
| --- | --- | --- |
| `start_identity` | `0bbf87a7…` | `0bbf87a7…` |
| `library_kat` | `bd4b51ab…` | `bd4b51ab…` |
| `blueprint_kat` | `13f7fd7d…` | `13f7fd7d…` |
| `highcourt_kat` | `ac387756…` | `ac387756…` |
| `dur_brannoc_kat` | `36b36628…` | `36b36628…` |
| `gor_drazhak_kat` | `77b14a25…` | `77b14a25…` |
| `lethariel_kat` | `04d2f746…` | `04d2f746…` |
| `kezamba_kat` | `76a72cae…` | `76a72cae…` |

`start_identity`'s own digest is the value wave 1 recorded, unchanged.
`identity.sh` in the evidence directory is what produces both columns. That the
two capital KATs do not move is a fact about THEIR fixtures and not about the
change: their synthetic wall profiles are one-dimensional per run, so their
corners already agreed and the clamp has nothing to do there. Section 3b's cell
diff is what measures the change on the ground those capitals really stand on.

### (c) Build time and budget

`timing.lua` / `timing.txt`, three runs each, `os.clock` CPU milliseconds:

| Subject | LuaJIT | PUC 5.1 | Cells |
| --- | --- | --- | --- |
| module load | 79.4 – 86.2 ms | 107.3 – 108.0 ms | — |
| core | 112.2 – 120.9 ms | 343.0 – 349.4 ms | 97 494 |
| core, second build | 111.7 – 124.9 ms | 327.9 – 336.8 ms | same |
| all 52 plots | 253.7 – 269.3 ms | 690.2 – 705.4 ms | 268 856 |
| one 209-node avenue run | 1.22 – 1.46 ms | 2.29 – 2.35 ms | 1 291 |
| **seam prepare** (all 54 blueprints built, hashed, released) | 733 – 795 ms | 2016 – 2073 ms | — |

Re-measured on `f5583e13` with the corner reconciliation, the gate ramp and the
gate tunnel in the tree. Module load is up some 30 ms because `nhal_veyr.lua` now
loads the district roster it publishes as `M.districts`; every other subject is
at or below what it was.

Against the contract's section 2.3 budget: core **97 494 of 150 000** cells,
largest plot **9 795 of 12 000** (the watch barracks), the 53 cell-bearing
blueprints **366 350** against Highcourt's 376 274. The overlay has no cells
until a surface reaches it. "Builds in a few seconds under LuaJIT when first
touched" is 0.12 s for the core alone and 0.74 s for the whole prepare; 2.2 s
under the fallback interpreter.

### (d) Per-mapchunk cost

`nhal_veyr/probe-<seed>.txt`, one boot per seed. The corpus is the mapchunks
the capital's blueprints, avenues, lanes and wall actually touch, derived from
the real geometry, plus three kinds of control.

| Kind | chunks | steady mean | worst | best |
| --- | --- | --- | --- | --- |
| warm-up (not counted) | 1 | — | ~25 s | — |
| **Nhal Veyr**, the gate seed 531802985935182545 | 79 | **0.65 s** | 1.64 s | 0.17 s |
| Lethariel (a capital with no WP13 cells) | 8 | 2.65 s | 16.0 s | 0.26 s |
| open land and the Dawnmere start | 3 | 0.65 s | 1.30 s | — |

The gate seed's row is the pass re-taken on `f5583e13`. The boundary seed and the
user's world seed were 0.81 s over 69 chunks and 0.63 s over 73 on `c8050057`'s
WP40; that terrain has since moved under them and they are not re-quoted.

The warm-up mapchunk carries the emerge environment's whole one-time R7
construction, which is why it is emerged first and not counted. Lethariel is
the honest control: WP40 fits, flattens, terraces and protects it exactly like
Nhal Veyr and it has no WP13 blueprints at all. **Nhal Veyr's mapchunks are
four times cheaper than that control's.** Against the contract's "no more than
2× the ~0.5 s Dawnmere chunk": 0.65 s, against the same boot's own open-land
control of 0.65 s.

79 mapchunks against Dur Brannoc's 85 and Highcourt's 33 — a wall round a
512 envelope touches every mapchunk on the ring, and four districts of thirteen
plots touch most of the rest. The corner clamp costs 567 extra surface queries in
the sixteen of those seventy-nine whose look-around reaches a corner, and nothing
in the other sixty-three; the steady mean moved from 0.57 s to 0.65 s between
`c8050057` and `f5583e13`, with the terrain, the gate ramp, the gate tunnel and
the clamp all in that difference.

**THE NORTH AVENUE DID LEAVE ITS GROUND, and the first draft of this section
said otherwise.** What that draft claimed — "no causeway parapet, and that is
measured" — was measured on the EAST avenue only, and only out to column 240,
by the span of paving names in the finished map. It is wrong about the capital.
The independent review of 2026-09-16 found the north avenue standing 4 to 7
courses above its ground at the gate point on the gate seed and 6 to 10 on seed
12345, with nothing at its edge, on all nine seeds.

The reason is `avenue.lua`'s own contract and not a bug in it: a road walks the
ONE-LIPSCHITZ UPPER ENVELOPE of the ground, so where the ground falls faster
than a node a column the road cannot follow it down. Nhal Veyr's north centre
line falls 1.5 to 2.0 nodes a column from z = 232 to z = 261 — the east, south
and west lines fall 0 to 3 nodes in total and ride their own ground the whole
way, which is what the first draft saw and generalised from.

The fix is in this capital and not in Lane R's module: `gate_road` in
`nhal_veyr.lua` hands `avenue.run` the free surface CAPPED by a cone of slope
one rising back from the free height at the gate point, so the envelope the road
walks arrives at the gate at the free terrain and steps at most a node a column
the whole way down; where the natural ground then stands above the road the
piece cuts it to air, and a course of dungeon stone rails the two KERB lanes --
the carriageway's own outermost, at `at ± half` -- wherever the carriageway's
fill reaches three courses (Dur Brannoc's threshold). Section 7 of the KAT holds the mechanism, including the proof that a
mapchunk piece caps exactly as the whole run does.

**ALL FOUR GATES ON ALL NINE SEEDS** (`nhal_veyr_plots.lua`'s gate section,
`lot-legality.txt`). `gate_y` is the free terrain at the gate point; `step` is
how far the road's top course stands from it there; `fill` and `cut` are the
deepest course count under and above the carriageway; `rail` is the number of
railed kerb columns.

| seed | south gate_y / step / fill / cut / rail | north | west | east |
| --- | --- | --- | --- | --- |
| 531802985935182545 | 97 / 0 / 2 / 0 / 0 | **94 / 0 / 6 / 5 / 4** | 109 / 0 / 1 / 0 / 0 | 95 / 0 / 2 / 0 / 0 |
| 8675309 | 76 / 0 / 2 / 0 / 0 | **85 / 0 / 6 / 3 / 6** | 102 / 0 / 2 / 0 / 0 | 83 / 0 / 2 / 0 / 0 |
| 15912857179583385436 | 110 / 0 / 2 / 0 / 0 | **72 / 0 / 6 / 0 / 5** | 108 / 0 / 2 / 0 / 0 | 89 / 0 / 2 / 0 / 0 |
| 0 | 99 / 0 / 2 / 0 / 0 | **63 / 0 / 4 / 0 / 4** | 94 / 0 / 2 / 0 / 0 | 111 / 0 / 2 / 0 / 0 |
| 1 | 118 / 0 / 2 / 0 / 0 | **78 / 0 / 6 / 1 / 6** | 104 / 0 / 2 / 0 / 0 | 114 / 0 / 2 / 1 / 0 |
| 2 | 102 / 0 / 2 / 0 / 0 | **69 / 0 / 6 / 3 / 5** | **86 / 0 / 3 / 0 / 1** | 102 / 0 / 1 / 0 / 0 |
| 42 | 98 / 0 / 2 / 0 / 0 | **77 / 0 / 6 / 2 / 7** | 92 / 0 / 1 / 0 / 0 | 105 / 0 / 2 / 0 / 0 |
| 12345 | 103 / 0 / 1 / 0 / 0 | **105 / 0 / 5 / 7 / 5** | **116 / 0 / 3 / 0 / 1** | 126 / 0 / 2 / 1 / 0 |
| 999999999 | 84 / 0 / 2 / 0 / 0 | **67 / 0 / 6 / 0 / 5** | 90 / 0 / 1 / 0 / 0 | 99 / 0 / 1 / 0 / 0 |

**The step at the gate point is 0 in all thirty-six.** The road meets Lane R's
route at exactly the height the route ends at, everywhere — and that is not this
lane's own tool saying so. `tools/wp13/route_gates.lua --strict` is Lane R's
acceptance gate, built out of the real WP40 height session with no engine and no
world: it walks the four incoming routes to each capital, reads the built road
back off its own cells, and compares the route's graded surface at the gate
column with the road's top there. Over all nine fixture seeds and all six
capitals (`gates.sh`, `gates/`):

```
route_gates seed=<each of the nine> mode=strict route_faults=0 city_faults=0
```

Before the fix that same run reported two faults, both Nhal Veyr's north gate:
"north gate steps 4 between route grade and avenue road" and "north entry breaks
1 time(s), worst 5 at 261". After it, zero on every seed. Nhal Veyr's own 36
rows out of that run carry `route_y` and `road_y` equal in every one, and equal
to the `gate_y` column of the table above — two independent tools, one reading
WP40's route surface and one the free terrain, landing on the same 36 numbers.

One change was needed to make that tool able to see the fix at all, and it is
reported in section 8 as a change to Lane R's file: it built every capital's
avenues with `avenue.run` directly, so it measured the CONTRACT road rather than
the one a capital's own `M.overlay_run` builds. It now dispatches through the
capital's own overlay where the capital exists.

**The rail.** Fill of 1 or 2 is the road's own two-course bed on its own ground
and carries no rail, which is the same threshold Dur Brannoc uses; every row
whose fill reaches three is railed, and the one that needs it most — the north
gate, on every seed — carries rails the whole width of the descent. The seven
columns of the gate passage itself carry none: there the curtain's own piers
stand either side of the road, and a kerb course would be masonry in the tunnel
mouth.

**AND THE GATE TUNNEL NEEDED A FLOOR, which only the finished map showed.**
`wall.lua` cuts its gate passage as air from the column's own LOWEST ground over
the curtain's seven lanes up to one course under the deck, and its comment says
why that is safe: the avenue "writes its pavement from the GROUND upward" and
therefore holds its own road up. Measured, that is true of Highcourt and Dur
Brannoc — both gate columns are solid from the tunnel floor straight to the road
stair — and it stops being true the moment a road is laid ABOVE the lowest ground
of that band, which is exactly what arriving at the gate point's own height does
here. At Nhal Veyr's north gate the curtain's tunnel floor is 91 and the road is
94, and the two courses between them were AIR with the carriageway riding over
them.

Nothing offline could see it. The road piece is solid; the hole is opened
afterwards by another run, and the cross-run arbitration is the successor's.
`nhal_veyr/approach.py` over the probe's new gate-approach dump is what found
it — which is the whole reason that dump was added — and `gate_road` now carries
its own tunnel floor over the band the curtain clears, from the band's lowest
ground up to the road, using the curtain's own two numbers (`wall.HALF` columns
either side, `wall.GATE_PASSAGE` lanes either side) and not new ones. The avenue
is the first run and wins every cell it and the curtain share, so what it writes
there is what the map gets. KAT rule (f) holds it and `mutations.sh`'s fifth
mutation is the red without it.

### (e) Engine

`tools/wp13/run_capital.sh <out> nhal_veyr surface <seed>` on ALL NINE seeds of
`tools/wp13/capital_anchor_fixture.lua` (on `c8050057`'s WP40), and `full` — one
pass, re-taken on `f5583e13` with the corner reconciliation, the gate ramp and
the gate tunnel in it. Every pass: the capital emerged one mapchunk at a time,
**274 sockets registered and NINE patrol loops** — the city ring, one per gate
tower, one per district — and the roster placed:

| | 531802985935182545 (`f5583e13`) | 8675309 | 15912857179583385436 |
| --- | --- | --- | --- |
| sockets registered | 274 | 274 | 274 |
| loops | 9 | 9 | 9 |
| guards | 29/30 | 27/30 | 28/30 |
| flair | 152/168 | 118/168 | 137/168 |
| vendors | **6/6** | 5/6 | 3/6 |
| spare | 26 | 26 | 26 |
| residents / walkers | 168 / 24 | 168 / 24 | 168 / 24 |
| ERROR / ModError lines | 0 | 0 | 0 |

As at Highcourt and Dur Brannoc, the split between "placed at readiness" and
"pending" depends on which mapblocks the emerge sequence had loaded and is not
a gate; what is reproducible is the socket count, the loop count, the vendor
roster on a seed whose mapblocks are all loaded, and that the walker share is
24 of 168 on all three. The second and third columns are the `c8050057` passes
and are kept for the comparison; only the first was re-taken.

**The load-time terrain audit** (`r7_settlement.audit_terrain`, run from
`r7_loader.lua` on every boot) is the authority the offline predicate is a
pre-flight for, and with the grids re-derived against all nine seeds it has
nothing to say about this capital:

| seed | Nhal Veyr | Highcourt | Dur Brannoc | worst perimeter fall | submerged |
| --- | --- | --- | --- | --- | --- |
| 531802985935182545 | **0** | 0 | 0 | 4 | 0 |
| 8675309 | **0** | 0 | 0 | 5 | 0 |
| 15912857179583385436 (the user's) | **0** | 1 | 0 | 5 | 0 |
| 0 | **0** | 1 | 0 | 6 | 0 |
| 1 | **0** | 0 | 0 | 6 | 0 |
| 2 | **0** | 1 | 0 | 5 | 0 |
| 42 | **0** | 1 | 0 | 6 | 0 |
| 12345 | **0** | 1 | 0 | 5 | 0 |
| 999999999 | **0** | 6 | 1 | 6 | 0 |

Zero findings on all nine, a worst perimeter fall of 6 against a skirt of 6,
and not one submerged column anywhere. The two capitals already on main have
findings on five and one of the nine respectively, which is what a two-seed
derivation buys — and is exactly what this capital's own first version looked
like before section 4's re-derivation.

**No error line of any kind.** Every pass of section 6 (e) logs 0 ERROR and 0
ModError, and `run_capital.sh` reports PASS. Until the rebase onto `c8050057` it
carried two — the unregistered `herbalist` and `embalmer` vendor entities of
section 5.3 — and `errors.sh` in the evidence directory is what said so by name
rather than by exit code; it now expects zero and still names any line it finds.

### (f) The corner, in the engine — a STANDING GATE

Everything section 3b measures the corner with is a model or a fixture:
`capital_wall.lua` reproduces the rule rather than calling it (which is what lets
it ask about ground no capital stands on yet), and the KAT calls the module over
synthetic shouldered ground. Both are good and neither is the engine. The
re-review of 2026-09-16 put the number on it: **every frozen artefact is blind to
a corner column.**

| dump | region, anchor-relative | contains a corner? |
| --- | --- | --- |
| `<key>-rampart.tsv` | `x = WALL_AT ± 6`, `z = −80 … +80` | no |
| `<key>-gate.tsv` | `z = −20 … +20` | no |
| `highcourt-wall.tsv` | `x = 248 … 264`, `z = +36 … +92` | no |
| `highcourt-gate.tsv` | `z = −24 … +24` | no |

So `plan.corners` could be dropped from a capital tomorrow and every committed
digest and every KAT would stay green. The reviewer had to read the corners by
hand, through `WP13_HIGHCOURT_CROSSING` — an extra-region setting that exists
only in the PILOT capital's own probe — and what they found is the measurement
this package could not take: **209 changed cells in Highcourt's north-east corner
box and 49 in its south-west, between `main` and this branch, and 0 in the
`core`, `avenue`, `wall`, `gate` and `surface` dumps**; the offline model exact
against the built map, 1899 of 1899 corner cells present with the same node name
and 0 disagreements; the deck 55 / 57 / 59 at x = 248 / 250 / 252 in both, which
is the two-node corner raise carried back as treads.

`capital_probe` now publishes that region itself, the way this branch already
gave it `<key>-approach.tsv` for the same kind of reason — a defect nothing could
look at. **`<key>-corner.tsv`: four boxes, one per corner, ±12 of each corner
column.** That window covers the z-run's corner TURRET (centred on ±256, eleven
columns along and seven across), the x-run's last columns up to its own end at
±252 with its own seven lanes, and a margin — and it does not reach the nearest
ordinary turret at ±192, so what is in it is corner and nothing else. A dump
region is a LIST of boxes now; every existing region names one and is normalised
into a one-element list, so no region, mode, digest or log line of Lane D's file
changes. `run_capital.sh` gates on `corner_road_digest` beside `rampart` and
`gate`.

**A box has to be read the moment it is emerged, and that cost one run to
learn.** The dump queue's own header says the server unloads mapblocks when no
player is near; the first version of this region emerged all four corners and
then read all four, and read **56 125 `ignore` nodes against 39 529 real ones** —
three of the four corners had gone before the read reached them. So a region is
opened, each box is appended while that box is the one that just arrived, and
the file is digested at the end.

**Nhal Veyr's committed expectation, gate seed 531802985935182545**
(`evidence/20260915-capital-terrain/nhal_veyr/`, the one-line format every
capital uses):

```
1de2189a4a37f4737bf910060bcf7e55097af44177c9a0fc77c239c213e2067f  corner seed=531802985935182545 overlay_cells=8039 main=1c9e0f39 package=20260915-nhal_veyr
```

66 091 cells read across the four boxes, **0 of them `ignore`**, 8 039 of them
overlay.

**And the expectation bites.** Built offline out of the same WP40 height session,
this capital's whole curtain with the reconciliation and without it, restricted to
the four boxes the region dumps: 9 992 cells before against 10 127 after, **357 of
them differing** (`corners/cornerbite.sh`). Drop `plan.corners` from
`nhal_veyr.lua` and this digest moves; that is the property every other frozen
artefact lacked. `avenue`, `rampart` and `gate` are frozen beside it in the same
directory, in the format every capital uses, and `run_capital.sh full nhal_veyr`
gates on all four.

**And the other walled capitals can be read now.** Dur Brannoc and Gor Drazhak
publish the region the moment they are run — both author `wall_`-prefixed rampart
runs, which is the composition's own way of saying it has a wall, and Gor
Drazhak's stake palisade answers it exactly as a curtain does. Measured, one full
pass on the gate seed with this branch's `wall.lua` on the tree:

```
WP13 capital pass PASS: gor_drazhak full
avenue overlay digest matches the committed value      303a5ab4…
rampart overlay digest matches the committed value     6589b4e4…
gate overlay digest matches the committed value        e008bb2c…
corner overlay digest recorded (no committed value for seed … yet)
                                                       9d30229d…  10 798 cells
```

Its rampart is `wp13/orc_palisade.lua`, a different module with its own corner
reconciliation (Lane O's, which this one was modelled on), so the corner clamp in
`wall.lua` cannot reach it and all three of its frozen digests are untouched —
which is what that pass was run to show. Its corner digest is left UNFROZEN here:
the region is new, the value is Lane O's capital's to freeze, and the runner says
so rather than failing.

Highcourt's own probe is a separate file that this package does not touch, so
Highcourt's corners stay readable the reviewer's way, through
`WP13_HIGHCOURT_CROSSING` — worth knowing, because the pilot capital is the one
whose corners moved most.

### (g) Static gates

`static.sh` / `static.txt`: `tools/bin/luac51 -p` and the SETGLOBAL count on
every file this package touched (all PASS, all zero globals), the whole `mods`
and `tools` trees parse under plain 5.1, and the five plain-5.1 sweeps scoped
first to the touched files and then to `mods/*/grug_*` and `tools/wp13`. The
only sweep hit this package contributes is `os.exit` in `nhal_veyr_plots.lua`,
the same standalone-CLI pattern `highcourt_plots.lua` and `capital_plots.lua`
have carried since the seam package: it is never loaded by the engine.
`check_fresh_server.py` PASS.

## 7. What changed after looking, and what the fixtures caught

Seven defects and one render verdict, each worth recording because each is a
shape the next capital will meet — and then, below, the four the INDEPENDENT
REVIEW of 2026-09-16 found, which are the ones this package learned most from:

1. **A grave marker on a cottage's doorstep.** `dressing.graveyard` sets a
   marker wherever the cell below is not air and the cell above is free, which
   on a hamlet pad means "on the turf" and on a CAPITAL pad means the market
   square, the travel plaza and a house's own step as well. The burial ground is
   walked in the composition now, with the guard the citadel parapet already
   uses: `layout.natural` (ground this composition laid and has built nothing
   on) and `layout.free`. The KAT's doorway rule is what found it.
2. **A bone pile in a patrol waypoint's headroom, and a dead shrub in a
   sparring guard's.** Three scatters run over the core's turf before its
   sockets exist and none of them can see a standing position, because a socket
   is an ABSENCE of cells. The core's own standing positions are declared as
   data at the head of the file now, a `STANDING` set is built from them before
   the scatters, and the three ask it — the tree guard three nodes wider than
   the others, because a gravewood's arms reach that far and end a course above
   the ground.
3. **Every gravewood but one lost its ground.** The burial ground ran first and
   a graveyard leaves no seven-column clearing anywhere in its rectangle. The
   trees go first now and the markers break round them, which is also what a
   burial ground under trees looks like.
4. **A tomb's candle standard replaced by a bench.** The plot builder writes a
   bench at `(3, z0 + 2)` beside every plot's door, and a mausoleum's plinth
   makes that exactly its own front corner: the candle's masonry base became a
   stair and its light hung on it. The standards moved to the plinth's front
   row either side of the doorstep. The KAT's torch rule found it.
5. **A votive light three courses up that no mourner could see.** The feature
   search of the sockets contract looks one course below, level with and one
   above the socket's FEET, so a light on a two-course standard at y = 3 is out
   of range of a resident standing at y = 1. Every `mourn` and `pray` feature in
   this capital is now at knee height — a votive light on a single block, or a
   grave marker — which is also what a candle at a grave looks like.
6. **`tend` faced a heap of bones.** The feature set was built from the palette
   roles the pilot capital's is built from, and one of them is `undergrowth`,
   which is a bush in the human palette and `grug_nodes:bone_pile` in this one.
   A gardener tending a bone pile passes a rule written as "a plant or a
   flower". The set lost that role, and the KAT now asserts that every name
   surviving into `tend` or `forage` is a plant BY ITS OWN REGISTRATION — drawn
   `plantlike`, `plantlike_rooted`, `firelike` or the wallmounted `signlike` a
   vine is, or in the leaves group. The wave-2 coordinator's review asked for
   the rule; the assertion is what makes the answer checkable.
7. **A mausoleum roofed in its own walls.** The first version gave the crypt
   handle a dungeon-stone roof family to go with its dungeon-stone walls, and
   the render out of the engine was one unbroken black mass with a lantern on
   top — Highcourt's "a civic building roofed in the same boards as a cottage
   reads as a big cottage", in reverse. The vault is dressed STONE BRICK now, a
   mid grey, and every civic building of this capital reads as a pale lid on
   black walls from the end of an avenue. Two things that attempt also taught:
   the castle kit's own shaped nodes carry NO paramtype2, so `parts.put`
   refuses them and a roof stair has to come from a `stairs:` family; and a
   material change like this one moves no socket, no count and no lot, but it
   does move every read-back digest, so the engine passes were taken again.

And what the review found, which is the set worth the most, because every one of
them is a case where this package had measured something and believed the
measurement:

R1. **The north avenue left its ground, and the record said no avenue did.**
   Section 6 (d). The claim was measured on the EAST avenue, out to column 240,
   by the span of PAVING NAMES in a column — three independent ways of not being
   able to see the case it ruled out, on a capital where one axis falls two
   nodes a column through its gate band. The lesson is the one the reviewer
   wrote: a measurement that cannot fail is not a measurement. The replacement
   reads all four axes on nine seeds AND the finished map, and the acceptance is
   another lane's tool.

R2. **The work-socket rule did not bite, proved by mutation.** Retyping a `pray`
   socket of a paved court to `mine` stayed GREEN, because the feature search
   read one course below the socket's feet and `mine` carried the plot's own
   paving. A rule with a hole that big had been green for the whole package.
   `mutations.sh` exists so the next change to it has to earn its green.

R3. **A doc claim that was true when written and false when read.** The vendor
   paragraph in `settlements.md` said the embalmer and the herbalist have no
   entity; Lane N had landed both before this package was rebased. A record that
   states another lane's state has to be re-read at rebase, not only re-read at
   review.

R4. **The failure count in this record was four short of its own re-run.** The
   corner section said twenty; `capital_wall.lua` fails at `step >= 3` and the
   re-run reports 24. Counting by eye off a histogram instead of by the
   predicate's own threshold.

R5. **And the fix for R1 opened a hole of its own, two runs away.** Bringing the
   road down to the gate point's own height put it above the lowest ground of the
   band the curtain clears its passage through, and the curtain then cleared the
   ground out from under it: two courses of air under the north carriageway, at
   the gate column, in the built map. Every offline check said the road was
   solid, because it was — the hole belongs to the pair of runs and not to
   either. What found it was the read-back the review's own criticism of
   `embankment.py` forced this package to build. Section 6 (d) carries the fix.

And one the SEAM caught, which is the one worth the most:

6. **The middle of a mausoleum is air.** `interiors.kits.crypt` sinks its nave
   by a course so the walkway has a lip. That is right on a start pad and fatal
   on a capital DISTRICT PLOT: a terrain-relative plot levels to one reference
   column, the seam requires that column to be a column of the plot's own
   ground course, and the plot builder centres a part on its reference column.
   `r7_settlement.prepare_cells` refused the blueprint at load, which is exactly
   where a rule like that should bite. `undead_parts.mausoleum` fills the
   emptied interior cells back with the same paving: the sarcophagi, the altar
   tomb and the kerb ring keep their cells and one node of lip is lost.

## 8. Open points

1. **CLOSED: the curtain wall's corners.** Section 3a's finding was fixed in
   `wp13/wall.lua` section 1b on the coordinator's hand-off; section 3b is the
   rule, the nine-seed table (64 corners, step 0 on every one) and the cell diff
   that says Highcourt's and Dur Brannoc's built ramparts moved at their corners
   and nowhere else. What is LEFT of it is one thing worth writing down: the two
   pilot capitals' own KATs could not have caught this, because their synthetic
   wall profiles are one-dimensional per run and therefore have no corner
   disagreement to find. `nhal_veyr_kat.lua`'s shouldered two-dimensional ground
   is the first fixture that does, and if the wall module keeps growing shared
   rules, the pilot KATs should grow the same kind of ground.
1a. **FOUR FILES OF OTHER LANES WERE TOUCHED, each with the smallest change
   that answered a finding, and each is reported here because the owner has to
   see it.**
   * `wp13/wall.lua` — Lane R's road module's sibling and the shared wall,
     handed to this lane by the coordinator FOR THE CORNER RECONCILIATION ONLY.
     The seam is Lane O's (`plan.corners`); `HALF`, `RISE`, `FOOTING`, `REACH`
     and `GATE_PASSAGE` are unchanged; `highcourt.lua` and `dur_brannoc.lua`
     gain the same four `corners` entries and nothing else.
   * `tools/wp13/capital_probe/init.lua` and `run_capital.sh` — Lane D's. ONE
     dump region added, `<key>-approach.tsv`: the steepest of the four gate
     approaches, out to 261. No existing dump, digest, mode or log line changes.
     The reason is section 6 (d): the probe read the east avenue and only the
     east avenue, and the north one was the broken one.
   * `tools/wp13/capital_wall.lua` — Dur Brannoc's (`39ac1e28`, `124a4051`).
     It MODELS the wall rule rather than calling it, which is what lets it ask
     about ground no capital stands on yet, so section 1b had to be modelled
     there too or its corner rule would have gone on reporting the unreconciled
     step. Same clamp, same pairing, and its section 5 changes from a number
     somebody reads into a gate.
   * `tools/wp13/route_gates.lua` — Lane R's. The four avenues it builds now go
     through the capital's own `M.overlay_run` where the capital exists, and
     through `avenue.run` where it does not. Its question 4 measures exactly the
     quantity a capital's gate ramp changes, so measuring the contract run
     instead reported a four-node gate step on a capital whose built road has
     none. The spec is handed over anchor-relative (which is what the seam does)
     and with the carriageway fields spelled out (which Dur Brannoc's rail
     requires). It is the acceptance gate section 6 (d) quotes.
2. **`tools/wp13/capital_timing.lua` cannot time a four-district capital.** It
   reads `capital.district.plots` — one district — and builds the road with
   `palettes.new("dwarf")`. Two lines would generalise it (take the race from
   the roster profile, take the plot list from the blueprint source), but it is
   Lane D's file in the wave-2 ownership, so this package's timing harness lives
   in its own evidence directory instead. The same is true of
   `tools/wp13/capital_plots.lua`, which reads the same single-district field:
   `nhal_veyr_plots.lua` is this capital's own.
1b. **`wall.lua`'s gate passage assumes the avenue fills from the ground, and
   the avenue does not have to.** Section 6 (d): the curtain clears its passage
   from the column's own LOWEST ground over its seven lanes, on the strength of
   a comment that the road holds itself up. A road laid above that lowest ground
   is left over air. This capital carries its own tunnel floor now and the two
   already shipped need none (measured, both gate seeds), so nothing is broken
   today — but the assumption is a comment in a shared module and not a rule
   anything checks, and the next capital whose road arrives at a gate point above
   its band's floor will meet it. The honest fix is in `wall.lua`: clear the
   passage from the deck DOWN to whatever the column actually carries rather than
   up from a height it guesses. That is more than a corner reconciliation and was
   not this lane's hand-off.
1c. **What the re-review of 2026-09-16 closed, and what it left.** Closed: the
   corner fix now has an engine gate (section 6 (f)); `wall.lua`'s corner guard
   carries the argument for why it is a load error and not a fail-soft, and both
   the datum and the guard read a RAW envelope copy so the symmetry proof is
   about the values the code uses rather than about two corners being 504 columns
   apart; `classify.py` prints counts and the worst distance instead of a column
   range; `corners/engine-walls.sh` can fail again (it piped a gate through
   `tail`); the stray `kat.err` is gone and `mutations.sh` writes nothing outside
   its own scratch. Left, deliberately, as things worth knowing:
   * **the gate ramp's cutting is bounded only by the terrain.** `gate_road`
     clears `top + 1 … natural` on every column the cap bit, with no limit; the
     deepest over 36 gate/seed pairs is SEVEN courses (seed 12345 north). It
     leaves the hillside as air up to the natural ground and no further, so it
     relies on the 532-node protected capital footprint to keep decoration out of
     the cutting. True today; worth re-checking if that footprint ever shrinks.
   * **KAT rule (e) splits the gate run at four cuts and not at every column**
     (`{120, 200, 244, 255}`, against the plain avenue rule's every-column
     split). That is a cost decision and is now written down as one: 255 falls
     inside the tunnel band 253…259, so the band and the cap are both covered.
   * **`route_gates.lua`'s capital dispatch is duck-typed** — any `overlay_run`
     that is a function is called with `(avenue, palette, spec, surface)`, with no
     arity or convention check. All six capitals use that signature, and the
     three-seed run after the wave-2 merge prints `own` for all six, which is the
     check that matters until someone writes a seventh.
2a. **`run_capital.sh full dur_brannoc` fails on `main` at `f5583e13` itself,
   and it is not this lane's either.** Both gate seeds: the committed
   `evidence/20260915-capital-terrain/dur_brannoc/avenue-digest-<seed>.txt` no
   longer matches what the engine builds (`20d17012…` against `1299e97e…` on the
   gate seed, `2f8f54a4…` against `260941bb…` on the boundary seed). That gate is
   a "look at what moved" gate by its own comment, and what moved is the ground:
   Lane R's routes ending at the capital gates re-grade the columns the avenue
   follows. Measured on a pristine export of `main` BEFORE this package's
   changes and on this branch after them, the two digests are equal to each
   other, so the drift belongs to whoever owns that expectation file and the
   corner commit is not it. Dur Brannoc's rampart and gate digests match their
   committed values on both seeds, before and after.
3. **`tools/wp40/r7/anchor_activation_kat.lua` fails, and it is not this
   lane's.** `bash tools/wp40/r7/run.sh unit` stops at "WP40 R7 anchor KAT:
   operation differs at 1". It fails identically on a pristine archive of `main`
   at `922bfd92` with no WP13 change in the tree at all, so it is pre-existing
   and belongs to whoever owns that fixture; it is recorded here because this
   lane ran into it and somebody should.
4. **The pilot capital's own lots have not been through the nine-seed rule.**
   Section 4 is what re-deriving Nhal Veyr's against nine worlds cost: 34 of 52
   lots moved. The same predicate run against Highcourt on the same nine seeds
   reports findings on five of them (section 6 (e)'s table), so the pilot's
   grids were derived the way this lane's first version was. That is
   `highcourt_plots.lua`'s to answer, not this file's.
5. **The capital's own lot predicate reads a 4-node grid.** Section 3 calibrates
   the error — a fall by at most one node, a rise by at most two — and section
   4's limits carry that margin, but a 1-node field dump would be better.
   Adding a `field` mode to `capital_probe` is the generic fix and belongs with
   whoever owns that probe next.
6. **No seed found puts NHAL VEYR's own anchor root on a mapchunk edge**, so
   the lane brief's "plus one seed on which your capital's anchor root lies on a
   mapchunk edge" has no engine pass behind it. What was measured instead: across
   the nine seeds of `capital_anchor_fixture.lua` this capital's fitted anchor is
   87..124, and a scan of the first 84 small seeds through the same height
   runtime widens that to **71..132** — which does contain 127, the one value
   whose root (128) is a chunk's lowest slice, but no seed in the scan hits it.
   The scan costs about ten seconds a seed, which is why it stopped there.

   The case itself is not uncovered: `capital_anchor_fixture.lua` asserts that
   SOME capital anchor in its nine-seed set has its root on a chunk edge and
   refuses a seed list in which none does, and the emerge-order-independent
   anchor activation that landed on main at `2932a9c7` is what makes that case
   survive. What is open is a pass on a world where the anchor in question is
   this one.
7. **The wall's identity is its specification**, and the turret and gate
   positions are not in it — the same arrangement Dur Brannoc records, and the
   same two things that catch a change: the KAT's built-cell digest and the
   engine pass's read-back digest. No `*-digest-<seed>.txt` is committed for
   this capital yet, so `run_capital.sh` prints "recorded (no committed value
   for seed … yet)" rather than comparing; the values are in
   `nhal_veyr/probe-<seed>.txt` and freezing them is the first thing to do
   after the user's playtest, not before it.
8. **The user has not walked Nhal Veyr.** Nothing here is accepted until they
   have. On seed 531802985935182545 the crossing of the two great avenues —
   the `arrival` landmark, with the guard banner on it — is at
   **(−1800, 107, 1500)**. The king stands on his throne at the north end of
   the mausoleum, the two traders in the ossuary court north-east of the
   crossing, the quest shell on the hall of vigil's doorstep in the west
   quarter, and the travel plaza WP17 is being kept clear of south-east of it.
   Walk east out of the precinct, down the avenue over the terraces, and the
   curtain's east gatehouse is 256 nodes out.
