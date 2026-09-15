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

Not touched: the six start compositions, `highcourt*.lua`, `dur_brannoc*.lua`,
`avenue.lua`, `wall.lua`, `capitals.lua`, `buildings.lua`, `parts.lua`,
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
| | east | 0 | 3 | 69 | 121 | 52 |
| | south | 0 | 3 | 91 | 127 | 36 |
| | north | 0 | 2 | 75 | 103 | 28 |
| 8675309 | west | 0 | 2 | 65 | 112 | 47 |
| | east | 0 | 3 | 70 | 109 | 39 |
| | south | 0 | 1 | 73 | 85 | 12 |
| | north | 0 | 2 | 70 | 94 | 24 |

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

## 3a. The curtain wall's corners, on all nine seeds — A FINDING

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
On the two gate seeds alone, two of the four corners break:
`wall_east`/`wall_north` steps 7 on the gate seed and 5 on the boundary seed.
The rampart of this capital is not a continuous circuit.

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

**WHAT WOULD FIX IT IS NOT THIS LANE'S.** The composition cannot: the divergence
is between two runs' envelopes and a run sees only its own. The fix belongs in
`wall.lua` — a corner turret that carries a flight between the two decks, or a
plan field that tells one run the other's deck at the shared corner — and
`wall.lua` is the shared module two shipped capitals' built walls are frozen
against. Section 8 carries it as this package's first open point.

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
lot.

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

Two rules in it are this lane's own:

- **the six wave-2 activities** and the feature each names, built from the
  palette's roles wherever the contract names a palette thing. `mourn` is a
  grave marker or a candle; `forage` is a vine or leaves and explicitly NOT the
  bone piles of `undergrowth`, because a bone pile is none of the five things
  the contract lists and a rule that accepted it would accept anything;
- **`spar` has two readings** and the KAT implements both: the training-dummy
  name set, and — where no name is found — another `spar` socket within three
  nodes along the socket's own facing, which is what two guards sparring
  actually is.

```
WP13 FINAL MICRO PAIR BYTE-IDENTICAL
7f2d2fc9720a40fd2aa8b6c10d2f72450228803dc41bf4e89161c2b6c8198293  micro-luajit.tsv
7f2d2fc9720a40fd2aa8b6c10d2f72450228803dc41bf4e89161c2b6c8198293  micro-puc51.tsv
```

That is the whole WP13 fixture set in one process under each interpreter, this
KAT among them.

### (b) The six starts, Highcourt and Dur Brannoc are byte-identical

The same five fixtures, run on this tree and on an archive of `main` at
`c8050057` (the merge of Lane N's wave-2 NPC vocabulary, which this package was
rebased onto):

| fixture | main c8050057 | this lane |
| --- | --- | --- |
| `start_identity` | `0bbf87a7…` | `0bbf87a7…` |
| `library_kat` | `bd4b51ab…` | `bd4b51ab…` |
| `blueprint_kat` | `13f7fd7d…` | `13f7fd7d…` |
| `highcourt_kat` | `ac387756…` | `ac387756…` |
| `dur_brannoc_kat` | `bfffe682…` | `bfffe682…` |

`start_identity`'s own digest is the value wave 1 recorded, unchanged.
`identity.sh` in the evidence directory is what produces both columns.

### (c) Build time and budget

`timing.lua` / `timing.txt`, three runs each, `os.clock` CPU milliseconds:

| Subject | LuaJIT | PUC 5.1 | Cells |
| --- | --- | --- | --- |
| module load | 48.9 – 50.5 ms | 64.9 – 68.5 ms | — |
| core | 120.5 – 131.6 ms | 381.0 – 386.0 ms | 97 494 |
| core, second build | 135.8 – 147.5 ms | 383.9 – 399.7 ms | same |
| all 52 plots | 260.1 – 271.6 ms | 707.5 – 717.1 ms | 268 856 |
| one 209-node avenue run | 1.22 – 1.27 ms | 3.81 – 3.90 ms | 1 291 |
| **seam prepare** (all 54 blueprints built, hashed, released) | 724 – 811 ms | 2079 – 2150 ms | — |

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
| **Nhal Veyr**, the gate seed 531802985935182545 | 80 | **0.57 s** | 1.38 s | 0.12 s |
| **Nhal Veyr**, the boundary seed 8675309 | 69 | **0.81 s** | 1.33 s | 0.10 s |
| **Nhal Veyr**, the user's world seed 15912857179583385436 | 73 | **0.63 s** | 1.40 s | 0.10 s |
| Lethariel (a capital with no WP13 cells) | 8 | 2.44 / 2.77 / 2.57 s | 14.6 / 17.3 / 16.0 s | — |
| open land and the Dawnmere start | 3 | 0.51 / 0.42 / 0.50 s | 1.01 / 0.83 / 0.99 s | — |

The warm-up mapchunk carries the emerge environment's whole one-time R7
construction, which is why it is emerged first and not counted. Lethariel is
the honest control: WP40 fits, flattens, terraces and protects it exactly like
Nhal Veyr and it has no WP13 blueprints at all. **Nhal Veyr's mapchunks are
three to four times cheaper than that control's.** Against the contract's "no
more than 2× the ~0.5 s Dawnmere chunk": 0.57 – 0.81 s.

69 to 80 mapchunks against Dur Brannoc's 85 and Highcourt's 33 — a wall round a
512 envelope touches every mapchunk on the ring, and four districts of thirteen
plots touch most of the rest.

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
piece cuts it to air, and a kerb course of dungeon stone rails the two verge
lanes wherever the carriageway's fill reaches three courses (Dur Brannoc's
threshold). Section 7 of the KAT holds the mechanism, including the proof that a
mapchunk piece caps exactly as the whole run does.

**ALL FOUR GATES ON ALL NINE SEEDS** (`nhal_veyr_plots.lua`'s gate section,
`lot-legality.txt`). `gate_y` is the free terrain at the gate point; `step` is
how far the road's top course stands from it there; `fill` and `cut` are the
deepest course count under and above the carriageway; `rail` is the number of
railed kerb columns.

| seed | south gate_y / step / fill / cut / rail | north | west | east |
| --- | --- | --- | --- | --- |
| 531802985935182545 | 97 / 0 / 2 / 0 / 0 | 94 / 0 / **6** / 5 / **8** | 109 / 0 / 1 / 0 / 0 | 95 / 0 / 2 / 0 / 0 |
| 8675309 | 76 / 0 / 2 / 0 / 0 | 85 / 0 / **5** / 3 / **5** | 102 / 0 / 2 / 0 / 0 | 83 / 0 / 2 / 2 / 0 |
| 15912857179583385436 | 110 / 0 / 2 / 0 / 0 | 72 / 0 / **4** / 1 / **5** | 108 / 0 / 2 / 0 / 0 | 89 / 0 / 2 / 0 / 0 |
| 0 | 99 / 0 / 2 / 0 / 0 | 63 / 0 / **3** / 1 / **2** | 94 / 0 / 2 / 0 / 0 | 111 / 0 / 2 / 0 / 0 |
| 1 | 118 / 0 / 2 / 0 / 0 | 78 / 0 / **5** / 1 / **5** | 104 / 0 / 2 / 0 / 0 | 114 / 0 / 2 / 0 / 0 |
| 2 | 102 / 0 / 2 / 0 / 0 | 69 / 0 / **5** / 3 / **5** | 86 / 0 / **3** / 0 / **1** | 102 / 0 / 1 / 0 / 0 |
| 42 | 98 / 0 / 2 / 0 / 0 | 77 / 0 / **4** / 2 / **5** | 92 / 0 / 1 / 0 / 0 | 105 / 0 / 2 / 0 / 0 |
| 12345 | 103 / 0 / 1 / 0 / 0 | 105 / 0 / **7** / 7 / **8** | 116 / 0 / 2 / 2 / 0 | 126 / 0 / 2 / 0 / 0 |
| 999999999 | 84 / 0 / 2 / 0 / 0 | 67 / 0 / **3** / 1 / **3** | 90 / 0 / 1 / 0 / 0 | 99 / 0 / 1 / 0 / 0 |

**The step at the gate point is 0 in all thirty-six.** The road meets Lane R's
route at exactly the height the route ends at, everywhere. Fill of 1 or 2 is
the road's own two-course bed on its own ground and carries no rail, which is
the same threshold Dur Brannoc uses; every row whose fill reaches three is
railed, and the two that need it most — the north gate on the gate seed and on
seed 12345 — carry rails the whole width of the descent. Nothing floats: the
predicate checks column by column that no carriageway cell has air under it.

### (e) Engine

`tools/wp13/run_capital.sh <out> nhal_veyr surface <seed>` on ALL NINE seeds of
`tools/wp13/capital_anchor_fixture.lua`, and `full` on the two gate seeds and
the user's world seed. Every pass: the capital emerged one mapchunk at a time,
**274 sockets registered and NINE patrol loops** — the city ring, one per gate
tower, one per district — and the roster placed:

| | 531802985935182545 | 8675309 | 15912857179583385436 |
| --- | --- | --- | --- |
| sockets registered | 274 | 274 | 274 |
| loops | 9 | 9 | 9 |
| guards | 30/30 | 27/30 | 28/30 |
| flair | 168/168 | 118/168 | 137/168 |
| vendors | **6/6** | 5/6 | 3/6 |
| spare | 26 | 26 | 26 |
| residents / walkers | 168 / 24 | 168 / 24 | 168 / 24 |
| ERROR / ModError lines | 0 | 0 | 0 |

As at Highcourt and Dur Brannoc, the split between "placed at readiness" and
"pending" depends on which mapblocks the emerge sequence had loaded and is not
a gate; what is reproducible is that the boundary seed's roster ends complete
and that the walker share is 24 of 168 on all three.

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

### (f) Static gates

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
shape the next capital will meet:

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

1. **THE CURTAIN WALL'S CORNERS BREAK, and the fix is in `wall.lua`.** Section
   3a: twenty-four of sixty-four corner measurements over the nine seeds step
   three nodes or more through a three-course opening, and the worst steps nine
   nodes, so the rampart is not a continuous circuit. The mechanism is the module's -- two
   perpendicular one-Lipschitz envelopes meeting at a corner, each smoothed over
   its own axis -- and the reason it shows here and not at Dur Brannoc is this
   capital's ground, which ranges 47 to 52 nodes along a wall line against Dur
   Brannoc's 36. A composition cannot fix it: the divergence is between two runs
   and a run sees only its own. What would: a corner turret that carries a
   flight between the two decks, or a plan field that hands one run the other's
   deck at the shared corner. Both are `wall.lua`, which is shared and which two
   shipped capitals' built walls are frozen against. **This is the first thing
   the review should look at.**
2. **`tools/wp13/capital_timing.lua` cannot time a four-district capital.** It
   reads `capital.district.plots` — one district — and builds the road with
   `palettes.new("dwarf")`. Two lines would generalise it (take the race from
   the roster profile, take the plot list from the blueprint source), but it is
   Lane D's file in the wave-2 ownership, so this package's timing harness lives
   in its own evidence directory instead. The same is true of
   `tools/wp13/capital_plots.lua`, which reads the same single-district field:
   `nhal_veyr_plots.lua` is this capital's own.
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
