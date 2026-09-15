# WP13: Nhal Veyr, the undead capital and the raised necropolis

Increment record, 2026-09-15, written against `main` at `922bfd92` ("Extend the
socket vocabulary for the wave-2 capitals"). It is the third capital of the
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

WP40 fits Nhal Veyr's anchor at **(−1800, 106, 1500)** on the user seed and
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
lot, on BOTH gate seeds. Of 52 lots:

| | exact | slid ≤ 12 | slid 20 – 44 |
| --- | --- | --- | --- |
| district lots (36) | 10 | 22 | 4 |
| fill lots (16) | 6 | 4 | 6 |

Three of the four district grids carry a two-node shift in z that the
whole-grid search found. The four that had to move far, and what was under
them:

| lot | from | to | why |
| --- | --- | --- | --- |
| `southeast` 6 | (160, −116) | (198, −116) | fall 7 against a skirt of 6 |
| `northeast` 6 | (116, 162) | (116, 202) | rise 8 against a clear of 8 |
| `northeast` 8 | (160, 118) | (198, 118) | fall 9 |
| `southwest` 9 | (−160, −158) | (−172, −158) | fall 6, the skirt exactly |

**Fill slot 4 moved in every quadrant, and the reason is arithmetic rather than
ground.** The authored close is a 5-reach lot in the gap between two columns of
the grid; a 5-reach lot with two nodes of margin is 15 wide, the gap between two
31-wide footprints 44 apart is 14, and a four-node lane either side needs 23.
The authored position cannot exist on any world, so in three quadrants the close
takes the nearest open ground inside its own quarter and in the north-east it
sits in the hole lot 8 left when it slid outward. Highcourt's own fill slot 4
stands where it does because its grid is staggered; this one's cannot.

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

**The activities placed**, all fifteen counted by the KAT:

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

**`herbalist` and `embalmer` have no entity yet**, and that is the sockets
contract's own predicted behaviour (§8.4: "a kind whose entity the traders mod
has not registered yet is an error line at placement and an empty socket, never
a load failure"). `grug_traders` registers `butcher`, `smith`, `fishmonger`,
`baker` and `tailor`; the wave-2 seven are the NPC vocabulary lane's. Every
engine pass of this package therefore carries exactly two ERROR lines and no
others — see section 6 (e), which is where that stops being a footnote and
becomes the gate.

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
62cbc3c5d955d1151a2c7fb13a16aa95aa58c75506a66721893cc543db2ca961  micro-luajit.tsv
62cbc3c5d955d1151a2c7fb13a16aa95aa58c75506a66721893cc543db2ca961  micro-puc51.tsv
```

That is the whole WP13 fixture set in one process under each interpreter, this
KAT among them.

### (b) The six starts, Highcourt and Dur Brannoc are byte-identical

The same five fixtures, run on this tree and on an archive of `main` at
`922bfd92`:

| fixture | main 922bfd92 | this lane |
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
| module load | 47.3 – 49.2 ms | 65.8 – 67.3 ms | — |
| core | 114.7 – 117.1 ms | 376.6 – 391.6 ms | 97 494 |
| core, second build | 117.9 – 125.1 ms | 383.1 – 411.1 ms | same |
| all 52 plots | 261.5 – 275.2 ms | 715.2 – 716.4 ms | 268 856 |
| one 209-node avenue run | 1.15 – 1.51 ms | 2.72 – 2.77 ms | 1 291 |
| **seam prepare** (all 54 blueprints built, hashed, released) | 739 – 761 ms | 2189 – 2211 ms | — |

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
| warm-up (not counted) | 1 | — | 25.3 – 28.4 s | — |
| **Nhal Veyr**, user/gate seed 531802985935182545 | 79 | **0.62 s** | 1.24 s | 0.11 s |
| **Nhal Veyr**, boundary seed 8675309 | 70 | **0.59 s** | 1.46 s | 0.11 s |
| **Nhal Veyr**, the user's world seed | 74 | **0.70 s** | 1.57 s | 0.10 s |
| Lethariel (a capital with no WP13 cells) | 8 | 2.49 / 3.02 / 2.66 s | 15.1 / 19.1 / 16.6 s | — |
| open land and the Dawnmere start | 3 | 0.66 / 0.39 / 0.52 s | 1.31 / 0.78 / 1.04 s | — |

The warm-up mapchunk carries the emerge environment's whole one-time R7
construction, which is why it is emerged first and not counted. Lethariel is
the honest control: WP40 fits, flattens, terraces and protects it exactly like
Nhal Veyr and it has no WP13 blueprints at all. **Nhal Veyr's mapchunks are
four times cheaper than that control's**, and its steady mean sits within a
tenth of the open-land control's. Against the contract's "no more than 2× the
~0.5 s Dawnmere chunk": 0.59 – 0.70 s.

79 mapchunks against Dur Brannoc's 85 and Highcourt's 33 — a wall round a 512
envelope touches every mapchunk on the ring, and four districts of thirteen
plots touch most of the rest.

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
| guards | 30/30 | 30/30 | 27/30 |
| flair | 163/168 | 168/168 | 115/168 |
| vendors | 4/4 registered kinds | 4/4 | 2/4 |
| spare | 26 | 26 | 26 |
| residents / walkers | 168 / 24 | 168 / 24 | 168 / 24 |

As at Highcourt and Dur Brannoc, the split between "placed at readiness" and
"pending" depends on which mapblocks the emerge sequence had loaded and is not
a gate; what is reproducible is that the boundary seed's roster ends complete
and that the walker share is 24 of 168 on all three.

**The load-time terrain audit** (`r7_settlement.audit_terrain`, run from
`r7_loader.lua` on every boot) is what says whether the lots this package chose
against two seeds survive a third:

| seed | Nhal Veyr findings | Highcourt findings |
| --- | --- | --- |
| 531802985935182545 | 0 | 0 |
| 8675309 | 0 | 0 |
| 15912857179583385436 (the user's) | 0 | 1 |
| 0 | 0 | 1 |
| 1 | 0 | 0 |
| 2 | 0 | 1 |
| 42 | **2** | 1 |
| 12345 | **2** | 1 |
| 999999999 | 0 | 6 |

Seven of nine clean, and the two that are not are one node over the skirt each
— `watch_barracks` and `homes_cistern` at a perimeter fall of 7 against 6 on
seed 42, `watch_captain_hall` and `vigil_watch` on 12345. That is the
two-seed derivation running out on a third world, which is exactly what the
loader's warning exists to say; the pilot capital does the same on five of the
nine. No plot of this capital is ever submerged on any of the nine.

**THE TWO ERROR LINES.** Every engine pass of this package logs exactly two,
both the sockets contract's predicted shape:

```
ERROR[Main]: [grug_mobs] settlement npcs: nhal_veyr socket
  market_physic/market_physic_vendor_herbalist resolves to no registered
  entity (grug_traders:vendor_herbalist)
ERROR[Main]: [grug_mobs] settlement npcs: nhal_veyr socket
  vigil_embalmer/vigil_embalmer_vendor_embalmer resolves to no registered
  entity (grug_traders:vendor_embalmer)
```

`run_capital.sh` gates on `errors == 0`, so it reports FAILED on every pass of
this capital until the NPC vocabulary lane registers the two wave-2 vendor
entities. **The gate's own verdict is therefore not the signal here; the signal
is that there are exactly these two lines and no others**, which
`errors.sh` in the evidence directory checks by name.

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

Six defects and one render verdict, each worth recording because each is a
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

1. **The two wave-2 vendor entities do not exist.** `herbalist` and `embalmer`
   are placed as sockets and error at placement until `grug_traders` registers
   them; that is the NPC vocabulary lane's, and section 6 (e) is the whole
   consequence. Until then `run_capital.sh` reports FAILED for this capital on
   every pass.
2. **`tools/wp13/capital_timing.lua` cannot time a four-district capital.** It
   reads `capital.district.plots` — one district — and builds the road with
   `palettes.new("dwarf")`. Two lines would generalise it (take the race from
   the roster profile, take the plot list from the blueprint source), but it is
   Lane D's file in the wave-2 ownership, so this package's timing harness lives
   in its own evidence directory instead. The same is true of
   `tools/wp13/capital_plots.lua`, which reads the same single-district field:
   `nhal_veyr_plots.lua` is this capital's own.
3. **Two lots are one node over the skirt on two of the nine seeds.** Section
   6 (e). Fixing them means deriving the grids against more than two seeds,
   which is a change to how every capital's lots are chosen and not this
   capital's to make alone.
4. **The capital's own lot predicate reads a 4-node grid.** Section 3 calibrates
   the error at one node and section 4's limits carry the margin, but a 1-node
   field dump would be better. Adding a `field` mode to `capital_probe` is the
   generic fix and belongs with whoever owns that probe next.
5. **No seed of the fixture's nine puts NHAL VEYR's own anchor root on a
   mapchunk edge.** Its roots are 88..125 across the nine and a chunk's lowest
   slice is 48 or 128. The chunk-edge case is covered for the roster as a whole
   by `capital_anchor_fixture.lua` and by the emerge-order-independent
   activation that landed on main at `2932a9c7`; this capital's own coverage of
   it is open.
6. **The wall's identity is its specification**, and the turret and gate
   positions are not in it — the same arrangement Dur Brannoc records, and the
   same two things that catch a change: the KAT's built-cell digest and the
   engine pass's read-back digest.
7. **The user has not walked Nhal Veyr.** Nothing here is accepted until they
   have.
