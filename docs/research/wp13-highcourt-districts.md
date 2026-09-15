# WP13: Highcourt's other three districts, and the quadrant permutation

Increment record, 2026-09-15, on `main` at `9e22b0d`. Implements the last open
point of [wp13-highcourt.md](wp13-highcourt.md) section 9 and point 4 of
[wp13-seam-generalisation.md](wp13-seam-generalisation.md) section 9: the
martial/garrison, lore/spiritual and residential/cultural districts of the
capitals contract, and the deterministic permutation that decides which of the
four districts stands in which quadrant. Evidence:
`tools/wp13/evidence/20260915-highcourt-districts/`.

Contracts implemented:
[wp13-capitals-pois-contract.md](wp13-capitals-pois-contract.md) section 2.1
(district plots, the four fixed roles, "assigned to quadrants by a
deterministic permutation from the world seed through the existing R6 hash"),
2.3 (the budgets) and [wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md)
(the socket field). The seam it is carried by is
[wp13-seam-generalisation.md](wp13-seam-generalisation.md), which is untouched:
a capital source hands the seam a plot list, and this package hands it 36 plots
where it used to hand it nine.

## 1. What shipped

| File | Change |
| --- | --- |
| `wp13/highcourt_plot.lua` | **new**: the plot builder, lifted out of the market district unchanged, plus the extension points the other three needed (`decorate`, `extra_sockets`, palette handle, the minimum airspace clear) |
| `wp13/highcourt_quadrants.lua` | **new**: the four quadrants' lot grids, the district lanes and the seeded permutation |
| `wp13/highcourt_district_martial.lua` | **new**: the martial and garrison roster, nine plots |
| `wp13/highcourt_district_lore.lua` | **new**: the lore and spiritual roster, nine plots |
| `wp13/highcourt_district_homes.lua` | **new**: the residential and cultural roster, nine plots |
| `wp13/highcourt_districts.lua` | **new**: the four rosters plus the permutation, resolved into 36 plots with their offsets |
| `wp13/highcourt_district.lua` | rewritten as a ROSTER: the builder moved out, the nine authored POSITIONS moved out, everything else byte-identical (section 6 b) |
| `wp40/r7_highcourt_blueprint.lua` | the plot list is the four districts' and the overlay's run list gains the district lanes; the world seed and the engine's SHA-256 reach the permutation here |
| `tools/wp13/highcourt_kat.lua` | the lot geometry, the permutation, the four districts, the lane-meets-avenue rule and the capital budget |
| `tools/wp13/highcourt_plots.lua` | rewritten: the lot predicate over a terrain FIELD rather than a per-plot candidate scan, plus `--derive`, which reproduces the committed grids |
| `tools/wp13/highcourt_identities.lua` | **new**: every blueprint identity the capital publishes, so the core's and the market's are checkable |
| `tools/wp13/highcourt_probe/init.lua` | `field` mode replaces `scan`; the district assignment and every plot's world position are logged; one dump per district |
| `tools/wp13/run_highcourt.sh`, `dump_highcourt.lua`, `highcourt_timing.lua`, `seam_kat.lua` | follow the above |

Not touched: `highcourt.lua` (the civic core, the avenues and the ring street),
`avenue.lua`, `capitals.lua`, `buildings.lua`, `parts.lua`, `palette.lua`,
`dressing.lua`, the six start compositions, and every file of the WP40 seam
except the capital source wrapper.

## 2. The four districts

Nine plots each, thirty-six in all. Each is a self-contained composition in the
shape of a start -- schema, canonical cells, bounds, sorted palette, landmarks,
`reference` and `clear_to` -- built by the one builder in `highcourt_plot.lua`.

### 2.1 Market and professions (`highcourt_market`, loop `highcourt_market_watch`)

Unchanged from the pilot lane except for `market_well` (section 6 b) and two
spare wander spots. Granary, stable, workshop, counting house, well garden,
watch house, grove, orchard edge, store.

### 2.2 Martial and garrison (`highcourt_martial`, loop `highcourt_garrison_watch`)

| Lot | Plot | Part | Cells | Sockets |
| --- | --- | --- | --- | --- |
| 1 | `martial_barracks` | `barracks` 17 x 21, slate | 9 795 | 6 |
| 2 | `martial_muster_hall` | `hall` 15 x 17, slate | 6 699 | 2 |
| 3 | `martial_armoury` | `workshop` 11 x 15, turned | 6 416 | 2 |
| 4 | `martial_stables` | `stable` 15 x 13 | 5 567 | 4 |
| 5 | `martial_drill_yard` | `watchpost` + drill posts, standards, billets | 7 456 | 5 |
| 6 | `martial_quartermaster` | `longhouse` 13 x 15 | 5 966 | 2 |
| 7 | `martial_wain_shed` | `shed` 13 x 9 + wagon, crates | 5 207 | 2 |
| 8 | `martial_guard_house` | `cottage` 11 x 7, hip | 2 711 | 2 |
| 9 | `martial_watch_tower` | `watchpost`, turned | 3 880 | 4 |

Nineteen guard posts stand in the capital; the garrison publishes six of them
(two at the barracks door, two at the drill yard's gate, one at the tower's
foot, one the barracks generator publishes itself) and no other district
publishes more than the one its own watch house generator does.

### 2.3 Lore and spiritual (`highcourt_lore`, loop `highcourt_cloister_watch`)

| Lot | Plot | Part | Cells | Sockets |
| --- | --- | --- | --- | --- |
| 1 | `lore_shrine` | `temple` 13 x 17 with its belfry, slate | 10 451 | 4 |
| 2 | `lore_library` | `hall` 15 x 19, slate | 7 790 | 2 |
| 3 | `lore_scriptorium` | `scriptorium` 15 x 17, slate | 7 665 | 4 |
| 4 | `lore_archive` | `granary` 13 x 15, slate | 6 764 | 3 |
| 5 | `lore_herb_garden` | `well_court` + fruit trees and physic beds | 4 862 | 5 |
| 6 | `lore_chapter_house` | `longhouse` 11 x 13 | 4 862 | 2 |
| 7 | `lore_almonry` | `cottage` 9 x 11 | 3 360 | 2 |
| 8 | `lore_cloister_walk` | `colonnade` 15 x 5, marble | 2 841 | 4 |
| 9 | `lore_quiet_grove` | `grove` 15, columnar | 7 978 | 3 |

**The chapel with its belfry is in the CORE and is not repeated here.** The
core's west quarter carries it, which is what the contract's human-capital line
asks for; `lore_shrine` is `capitals.temple` instead -- taller, hip roofed, its
own bell on the ridge -- so the district has a place of its own without
building the same thing twice two hundred nodes away. It is also where the
district's `quest` socket comes from, which is the generator's own.

### 2.4 Residential and cultural (`highcourt_homes`, loop `highcourt_lanes_watch`)

| Lot | Plot | Part | Cells | Sockets |
| --- | --- | --- | --- | --- |
| 1 | `homes_tavern` | `hall` 13 x 15 + trestles, wood pile | 5 567 | 2 |
| 2 | `homes_well` | `well_court` 11 | 3 210 | 4 |
| 3 | `homes_monument` | `statue_plinth`, marble, on a paved square | 4 077 | 4 |
| 4 | `homes_house_gable` | `cottage` 9 x 7 | 2 600 | 2 |
| 5 | `homes_house_hip` | `cottage` 11 x 9, hip | 3 105 | 2 |
| 6 | `homes_house_lane` | `cottage` 9 x 9, turned | 2 980 | 2 |
| 7 | `homes_tenement` | `longhouse` 11 x 17 | 5 854 | 2 |
| 8 | `homes_bakehouse` | `workshop` 11 x 11, turned | 4 430 | 2 |
| 9 | `homes_orchard` | `orchard_edge` 21 x 13 | 7 960 | 4 |

The three houses are three different houses on purpose: footprint, roof form
and door side are what give a lane of cottages three silhouettes instead of one
repeated. All three are half timbered, which is what the contract's
"half-timbered lanes" is made of in this palette.

### 2.5 Sockets

181 in all, up from 95: one king, two vendors, one waypoint, two quest spots,
19 guard posts, 56 patrol waypoints in **nine** loops and 100 idle spots.

Each district publishes exactly **two spare wander spots** -- idle positions a
walking NPC may use as a destination and which the placement engine is meant
not to staff with an inhabitant of its own. The registry of
`grug_core/settlement_sockets.lua` carries `tags` today and drops a field it
does not know, so the marker that works NOW is `tags = {"spare", "wander"}`;
`spawn = false` is published beside it so the NPC lane's own field starts
working the day that lane lands it, with no second edit in the compositions.
**Until then a spare carries an ordinary villager**, which the engine pass
confirms (flair 100/100) and which is why the count is two and not ten.

No district publishes a `vendor`, a `king` or a `waypoint`: `grug_traders` has
exactly two vendor families and the core's service court already carries one of
each, so a vendor socket out here would have the runtime place a third trader.
The KAT asserts all three refusals.

## 3. The quadrants, and why the layout is not one layout turned four times

### 3.1 The quadrants are the diagonals

The four avenues leave the core on the axes, so the four quarters they cut the
512 envelope into are the diagonals: **south-east, north-east, north-west,
south-west**, in that order, which is also the order a quarter turn
(`(x, z) -> (-z, x)`) walks them. A district therefore sits between two
avenues with the ring street's corner running through it. A lot's whole
footprint stands at least 32 nodes clear of both avenues, which is what stops
two districts meeting in a corner.

### 3.2 A rotating layout does not exist on this terrain

The obvious implementation is one authored layout rotated a quarter turn per
quadrant. It was measured against the real terrain of both gate seeds and it
does not exist. WP40 runs **two rivers** through Highcourt's envelope -- it is
the contract's own "river plateau" capital -- and they meet north of the core
on a diagonal. The set of positions that are dry, inside the foundation skirt
and under the plot's own airspace in ALL FOUR rotations at once is a handful of
columns at the envelope edge; nine of them with lanes between them do not
exist. A rotating layout would have had to put a building in a river to keep
its shape.

So **each quadrant carries its own nine lots**, and the four grids are what the
same authored 3 x 3 layout becomes when it is rotated into that quadrant and
then allowed to slide to the nearest ground that will carry it.

### 3.3 A lot is a lot, whichever district stands on it

The permutation only means something if any district may take any quadrant, so
a lot is held to ONE envelope and every plot of every district is held to the
same one:

- footprint inside **±13** of the lot origin (the contract's plot volume is
  ±15; the two nodes are what buys the interchange);
- two nodes of dry margin round that, **not one column of water** on either
  seed;
- perimeter fall at most the foundation skirt, **6**, on either seed;
- rise at most **6** under an airspace clear of at least **8**;
- off the core, off all four 32-node gate corridors, off all fifteen street
  runs, inside its own quarter, and a lane of 8 clear of every other lot of
  every other quadrant.

`highcourt_kat.lua` checks the geometry on the **36 lots**, once, independently
of any assignment -- which is what makes it true for all 24 permutations
instead of for the one this run happened to build -- and checks that every plot
fits that envelope. `highcourt_plots.lua` checks the terrain half against both
seeds' fields.

### 3.4 The permutation

`r6_hash.lua` refuses a domain that is not on its own closed list, and that
list is pinned by the WP40 R6 micro-KAT's `domain_population` row: adding a
domain to it would move a frozen WP40 digest for a WP13 reason. What
`highcourt_quadrants.lua` uses instead is **R6's construction with a WP13
prefix of its own** -- the same length-framed canonical fields, the same
SHA-256, the same two-word modular reduction that stays exact in a double:

```
digest = SHA256( frame("grug_wp13_highcourt_district_quadrant_v1")
               . frame(<world seed as the engine publishes it>)
               . frame("4") )
index  = ((hi mod 24) * (2^32 mod 24) + (lo mod 24)) mod 24
```

and `index` is read as a factorial-base Lehmer code into one of the 24
permutations of four. Role `i` of
`{market_professions, martial_garrison, lore_spiritual, residential_cultural}`
takes quadrant `permutation[i]` of
`{southeast, northeast, northwest, southwest}`.

The seed and the SHA-256 reach it through `r7_highcourt_blueprint.lua`, which
reads the engine's own `seed` mapgen setting and `core.sha256`, so **the main
and the emerge environment cannot disagree** about where a district stands. An
engine-free caller -- a fixture, the renderer, the timing harness -- gets the
**canonical** assignment (the roles in authored order), and the KAT is what
checks the seeded ones.

**Nothing in the manifest moves either way.** A plot's identity is its schema,
bounds, palette and cells; its cells do not know which quadrant they will stand
in. The 38 identity SHAs, the manifest field order and the blueprint order are
the same on every world; only the descriptors' offsets differ.

What the two gate seeds ask for:

| Seed | market | martial | lore | homes |
| --- | --- | --- | --- | --- |
| 531802985935182545 | south-east | north-west | north-east | south-west |
| 8675309 | south-east | north-west | south-west | north-east |

Eight seeds produced seven distinct assignments in the KAT, which is the row
that exists to catch a permutation that never permutes.

### 3.5 The district lanes

The first render of the four districts showed nine buildings standing in a
meadow: the only streets the capital had were the four avenues and the ring at
96, and a district sits outside both. **A district is a place with streets in
it**, so each quadrant carries one or two lanes -- ordinary `avenue.lua` runs,
so they cost no new code: paved at the surface they find, climbing a terrace
the same way, carrying the same lamp rhythm, and the successor's cross-run
arbitration already knows what to do where one meets the ring or an avenue.

Every lane runs down the middle of a gap between two rows or columns of lots
and **starts on an avenue**, which the KAT asserts, so a district is reached
from the city and not merely near it. The lanes belong to the QUADRANT, not to
the district standing in it -- every quadrant is always occupied -- so the
overlay's run list and therefore its identity stay independent of the seed.

The south-west has one lane where the others have a crossing pair: both rivers
run through that quadrant, its nine lots are the only staggered grid of the
four, and there is no second gap wide enough to carry a road between them. Its
outer column is served by the ring street's west side instead.

## 4. Where the lots stand, measured on both gate seeds

The terrain question is asked against a **field**: the probe's new `field` mode
reads the pure final height and the land/water class of every column of the
±250 envelope once (one boot, about twenty seconds, no mapchunk emerged) and
writes it as a TSV. Every plot question is then arithmetic on an array outside
the engine. The old per-plot candidate sweep asked the same terrain column once
per candidate position per plot -- two million queries per plot for one
quadrant -- and four districts in four quadrants is where that stopped being
affordable. The two fields are committed:
`evidence/20260915-highcourt-districts/highcourt/field-<seed>.tsv`.

The grids below are **derived**, not chosen: `highcourt_plots.lua --derive`
rotates the authored layout into the quadrant, slides it as a whole to the
translation that needs the least correction, and gives every lot that still
does not stand the nearest position that does. It ranks by the WORST move, then
the total, then the translation itself -- minimising the sum is what chooses a
layout where one lot walks eighty nodes and the rest stay put, and that is not
the same design any more. Re-running it reproduces the committed table exactly.

| Quadrant | Shift from the authored layout | Worst move | Lots |
| --- | --- | --- | --- |
| south-east | none | 0 | (72,−72) (116,−72) (160,−72) (72,−116) (116,−116) (160,−116) (72,−160) (116,−160) (160,−160) |
| north-east | dx 36, dz −60 | 0 | (132,108) (132,152) (132,196) (176,108) (176,152) (176,196) (220,108) (220,152) (220,196) |
| north-west | dx 60, dz −8 | 0 | (−132,80) (−176,80) (−220,80) (−132,124) (−176,124) (−220,124) (−132,168) (−176,168) (−220,168) |
| south-west | dx 12, dz 32 | 32 | (−48,−76) (−48,−132) (−48,−172) (−84,−116) (−84,−152) (−84,−188) (−120,−84) (−128,−128) (−120,−164) |

Three of the four grids are the authored 3 x 3 exactly, translated. The
south-west is the one the rivers bend: four of its nine slid, by 8 to 32 nodes.

Per-lot terrain, worst of the two seeds (`plots.txt`): **perimeter fall 2 to 6
against a skirt of 6, rise 2 to 6 against a clear of at least 8, and zero
submerged columns on 36 of 36 lots on both worlds.** As built, the engine's own
surface report says worst fall **4** (`market_workshop`) and zero submerged, on
both seeds.

## 5. Budgets and cost

### 5.1 Cells

| Subject | Cells | Budget |
| --- | --- | --- |
| civic core | 101 831 | 150 000 |
| market district, nine plots | 58 467 | — |
| martial district, nine plots | 53 697 | — |
| lore district, nine plots | 56 573 | — |
| residential district, nine plots | 40 915 | — |
| largest single plot (`lore_shrine`) | 10 451 | 12 000 |
| **the whole capital** | **311 483** | **400 000** |

The avenue overlay is computed per mapchunk and stored nowhere, as the contract
says, so it is not in the total; the road it writes on the user seed is 1 733
cells.

### 5.2 Build time, both interpreters

`timing.sh` / `timing.txt`, three runs each, `os.clock` CPU milliseconds:

| Subject | LuaJIT | PUC 5.1 |
| --- | --- | --- |
| module load | 12.6 – 12.8 ms | 16.9 – 17.1 ms |
| core (101 831 cells) | 110.9 – 112.0 ms | 349.2 – 351.3 ms |
| **all four districts, 36 plots** (209 652 cells) | 218.2 – 222.3 ms | 577.6 – 583.6 ms |
| one 209-node avenue run | 0.9 – 1.0 ms | 11.5 – 12.1 ms |
| **seam prepare** (all 38 blueprints built, hashed, released) | 552 – 562 ms | 1 631 – 1 644 ms |
| **seam first touch** (core rebuilt, hashed, compared, 101 830 cells written) | 189 – 210 ms | 690 – 695 ms |

"Builds in a few seconds under LuaJIT when first touched" is 0.56 s for the
whole identity pass and 1.64 s under the fallback interpreter — three times the
pilot's, for three times the blueprints.

### 5.3 Per-mapchunk cost

`engine-*/probe.txt`, one boot per seed, each mapchunk emerged on its own in a
fixed order. The warm-up chunk carries the emerge environment's whole one-time
R7 construction and is not counted, exactly as the seam package measured it.

| Kind | user seed | boundary seed |
| --- | --- | --- |
| Highcourt mapchunks | 67 | 50 |
| steady mean | **0.38 s** | **0.50 s** |
| worst single chunk | 0.88 s | 0.98 s |
| Lethariel (a capital with no WP13 cells) | 2.10 s | 2.60 s |
| open land / the Dawnmere start | 0.41 s | 0.40 s |

The contract's limit is "no more than 2× the ~0.5 s Dawnmere chunk". The
capital's steady mean is at or below the empty-land control's on both seeds and
well under a quarter of the honest capital control's, which is WP40 fitting,
flattening, terracing and protecting a capital that has no WP13 blueprints at
all. **The districts quadrupled the blueprint count and did not move the
per-chunk cost**, which is what lazy construction and the per-session height
memo are for.

## 6. Verification

### (a) The KATs, both interpreters

`highcourt_kat.lua` gained: the 36 lots against the whole geometric rule set,
independently of any assignment; the factorial decode onto 24 distinct
permutations and the canonical assignment's identity; eight seeds, each
deterministic and not all equal; a refusal of a seed that is not a seed; every
plot inside the lot envelope and clearing at least 8; each district's loop
walked 1..n with no gap; exactly two spare wander spots per district and their
`spawn = false`; no `vendor`, `king` or `waypoint` in any district; the
garrison holding more guard posts than anybody else; every lane meeting an
avenue and no two runs sharing an id; and the whole capital against the
400 000-cell budget. Every plot still passes the pilot's own rules -- palette,
registry, panes, attachment, islands, torches, lights, doorways, closed rooms,
reachability, reference column, skirt to −6 and cleared airspace.

`seam_kat.lua` carries the capital with 38 blueprints (core, 36 reference
plots, overlay), 38 distinct identity SHAs, 181 sockets and the derived
manifest order.

`final-micro.sh`: one LuaJIT process and one PUC 5.1 process over the frozen
inputs, hashed before and after, running every WP13 fixture:

```
WP13 FINAL MICRO PAIR BYTE-IDENTICAL
7bcc38dec909fca0c2b87d63e43269813089fc1979701a04feeeebb5f2928167  micro-luajit.tsv
7bcc38dec909fca0c2b87d63e43269813089fc1979701a04feeeebb5f2928167  micro-puc51.tsv
```

### (b) Identity: what moved and what did not

The six start blueprint identity SHAs are **unchanged** (`timing.txt`, and the
`wp13_integration` row of the micro pair). The **Highcourt core** digest is
unchanged at `187f79e0ba52103818eba53f7ed9c3beadc631682648918301287fa4a7200499`,
the value the playtest round's throne fix froze.

Eight of the nine market plots are cell-for-cell identical, compared against
`main`'s own build before and after the builder was lifted out of
`highcourt_district.lua`; two of those eight (`market_grove`, `market_store`)
gained the district's two spare wander sockets, which the sockets contract
excludes from the identity bytes, so their blueprint SHAs did not move either.
**One plot moved, and it is a defect the move fixes.** `market_well` cleared its airspace to `part.peak + 2` = 7 while
the legality predicate credited it with `bounds.max.y` = 9, because the garden's
fruit trees are written AFTER the clear and reach above it. Two things follow:
a plot now publishes `clear_to`, the airspace it actually cut, and that is what
the predicate holds a lot's rise against; and every plot clears at least 8,
because a lot may rise 6 under it. `market_well` is 4 862 cells now instead of
4 156, and its identity SHA moved with them. No other plot's clear was below 8.

The nine market plots also moved POSITION, from the pilot's hand-tuned
offsets to the south-east lot grid. That is the price of the permutation: a lot
has to carry any district's plot, so all 36 are held to one envelope, and the
pilot's positions were tuned per plot against each plot's own footprint. Their
cells did not change; their offsets did.

### (c) Engine

`tools/wp13/run_highcourt.sh <out> full <seed>`, one isolated headless boot per
gate seed through a temporary `LUANTI_USER_PATH`, ports 31200-31299:

| | user seed 531802985935182545 | boundary seed 8675309 |
| --- | --- | --- |
| ERROR / ModError lines | 0 | 0 |
| mapchunks emerged | 79 | 62 |
| sockets registered | 181 | 181 |
| patrol loops | 9 | 9 |
| NPCs placed | `guards 28/28 flair 100/100 vendor 2/2 quest 2/2 pending 0` | same |
| district assignment | market SE, martial NW, lore NE, homes SW | market SE, martial NW, lore SW, homes NE |
| avenue road digest | `db3cf4b304bd6b59…` (1 733 cells) | `e9317dbb2ec2cc84…` (1 719 cells) |

**The built road's digest moved, and this package moved it**: the overlay's run
list gained the eight district lanes. Both values are recorded in
`highcourt/avenue-digest-<seed>.txt` with the seed and the `main` commit they
were taken on, and `run_highcourt.sh` compares against them — a second boot on
the user seed reproduced the digest exactly. The expectation file lives with the
lane that last changed the road, which is why the path moved out of the seam
package's evidence directory into this one.

### (d) Static gates

`static.sh` / `static.txt`: `tools/bin/luac51 -p` and the SETGLOBAL count on
every file this package touched (all PASS, all zero globals except the probe's
own single mod table), the whole `mods` and `tools` trees parse under plain
5.1, and the five sweeps scoped first to the touched files and then to
`mods/*/grug_*` and `tools/wp13`. The only sweep hit on a touched file is the
standalone-CLI `os.exit` pattern in `highcourt_plots.lua` and
`dump_highcourt.lua`, neither of which the engine ever loads.
`check_fresh_server.py` PASS.

## 7. Renders, and what changed after looking at them

`renders/`, 46 files, three kinds (`renders.sh` says which is which):
`plot-*.png` is each of the 36 plots from its composition, `capital-<seed>.png`
is the whole capital on one plane per gate seed -- the picture that shows which
district took which quadrant -- and `built-*.png` is read back out of the
finished map, so the terraces, the river and the road as actually laid are in
them.

What changed **after looking at them**:

1. **The districts were nine buildings in a meadow.** Every plot had its own
   kerbed pad and there was nothing between them, because the capital's only
   streets were the four avenues and the ring at 96 and a district sits outside
   both. That is the district lanes of section 3.5, and it is the change that
   makes the plan read as a city with four quarters rather than as a core with
   thirty-six sheds scattered round it.
2. **The "small square" was a monument standing on a lawn.** The plinth is nine
   nodes across and its margin is the plot's own grass, so a square with four
   lanes arriving at it arrived at a verge. Everything inside the kerb that the
   plinth does not already pave is laid in the same citadel paving the core's
   plazas are.
3. **Three of the districts were rosters of the same nine buildings.** The
   first version gave the garrison, the cloister and the lanes the market's own
   specs, so the capital had three identical barracks, four identical
   longhouses and three identical cottages. Every repeated part now differs in
   footprint, wall height, roof form or turn from every other use of it; the
   two orchards and the two groves are the deliberate exceptions, and they
   differ in species and length.
4. **The wain shed's dressing stood under its own eaves**, and the KAT caught it
   before the render did (a stair on a bottom slab). A yard needs four nodes of
   margin, not two; the same is true of the tavern's trestles.

## 8. Open points

1. **The terraces beside every district read as bare grey cut stone.** That is
   WP40's terrain treatment of a capital envelope, not this package's, and it
   is what `built-*.png` shows first. Recorded here for the same reason the
   seam package recorded it.
2. **A spare wander spot still carries a villager.** `spawn = false` is
   published and the registry drops it until the NPC lane adds the field; eight
   sockets across the capital are affected. The tag is there today.
3. **The south-west quadrant has one lane, not two**, and its outer column of
   three lots is served only by the ring street. Both rivers run through that
   quadrant and its lot grid is the only staggered one; a second lane would
   need the grid to be regular, and no regular nine-lot grid is legal there on
   both seeds.
4. **The lanes do not reach every lot.** A lane serves the two rows or columns
   it runs between; the outer row of each grid is reached along the lane rather
   than fronted by it. A second cross per quadrant is possible in the north-east
   and north-west and is a `highcourt_quadrants.lua` change.
5. **Nothing renders the four districts together as built.** The per-seed
   capital plan is drawn from the compositions on a flat plane; what the engine
   dumps is the core, one plot per district and the east avenue, because a
   512 × 512 region dump of the finished map is a different order of cost. A
   reviewer who wants the real thing walks it.
6. **The user has not walked Highcourt**, still. Nothing here is accepted until
   they have; section 9 says where to stand.

## 9. Where to look, in the client, on seed 531802985935182545

Highcourt's anchor is `(0, 40, -1500)`. The four avenues leave the core on the
axes; each district is one quarter turn round from the next.

| District | Quadrant | Walk to | Nine plots at |
| --- | --- | --- | --- |
| market and professions | south-east | `(116, 40, -1616)` | x 72/116/160, z −1572/−1616/−1660 |
| martial and garrison | north-west | `(-176, 40, -1376)` | x −132/−176/−220, z −1420/−1376/−1332 |
| lore and spiritual | north-east | `(176, 40, -1348)` | x 132/176/220, z −1392/−1348/−1304 |
| residential and cultural | south-west | `(-84, 40, -1632)` | x −48/−84/−120, z −1576 to −1688 |

Each named coordinate is the middle lot of its district; the plot's own ground
course is the terrain height there, not y = 40. The district lanes run between
the lot rows and back to the avenues, so walking out of a gate and turning
once reaches all nine.

The single most useful thing to look at first is `renders/capital-531802985935182545.png`,
which is the whole plan on one page.
