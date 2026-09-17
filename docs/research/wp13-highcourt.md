# WP13: Highcourt, the pilot capital

Status: implemented 2026-09-14; one independent review (verdict: merge after
fixes), whose two blocking findings, one Medium and six Lows are recorded in
section 9 and fixed on 2026-09-15. Not re-reviewed. Lane: "Highcourt core",
implementing Claude Opus, coordinator Claude Fable (policy "Day-to-day routing
rule"). This is the increment record for the third increment of the capitals
contract's section 3 order: **Highcourt core plus one district plus its
avenues**, built as library compositions and deliberately NOT wired into the
WP40 seam, because the seam generalisation that lets one settlement own
several blueprints is its own package (contract section 2.2).

Contracts implemented:
[wp13-capitals-pois-contract.md](wp13-capitals-pois-contract.md) (section 2.1
what a capital is, 2.3 the budgets, 2.4 the human capital's look, and the
user's rulings on the king's hall and on the three walled races) and
[wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md) (the socket
field). The parts this composition is assembled from are
[wp13-capital-library.md](wp13-capital-library.md); the shared modules, the
generator invariants and the renderer review loop are
[wp13-settlement-pipeline.md](wp13-settlement-pipeline.md) and
[wp13-hearthpine-library.md](wp13-hearthpine-library.md).

## 1. What shipped

| File | Change |
| --- | --- |
| `mods/MAPGEN/grug_mapgen/wp13/highcourt.lua` | **new**: the 96 x 96 civic core, the avenue and ring runs, the district accessor |
| `mods/MAPGEN/grug_mapgen/wp13/highcourt_district.lua` | **new**: the market and professions district, nine terrain-relative plot compositions |
| `mods/MAPGEN/grug_mapgen/wp13/avenue.lua` | **new**: the avenue overlay as a pure function of a column-surface callback |
| `tools/wp13/highcourt_kat.lua` | **new**: acceptance for the core, every plot and the overlay |
| `tools/wp13/dump_highcourt.lua` | **new**: core, plot or avenue to TSV, for the renderer |
| `tools/wp13/highcourt_timing.lua` | **new**: build time under both interpreters against the section 2.3 budget |
| `tools/wp13/final_micro.lua` | the new KAT joins the final interpreter pair |

Nothing else was touched: no start composition, no WP40 seam file, no
blueprint wrapper, and `capitals.lua`, `buildings.lua`, `palette.lua`,
`parts.lua`, `dressing.lua` and `layout.lua` are byte-identical to what the
capital-parts lane merged. The six start blueprint identities are unchanged;
section 6 carries the proof.

## 2. The core

96 x 96, bounds x/z [-47, 47] and y [-2, 31] inside the contract's [-2, 40],
flat at y = 0 by construction, anchor-relative exactly like a start. The
result is one composition in the shape of a start blueprint -- schema,
canonical cells, bounds, byte-sorted palette, landmarks -- plus
`landmarks.sockets`.

### 2.1 The plan

The two great avenues cross at the anchor, and that crossing is `arrival`,
the capital's spawn-equivalent landmark. The throne approach runs north from
it to the king's hall; the east-west avenue runs gate to gate past its
forecourt. Both are five wide, paved in the citadel's brick pavement with a
brick kerb, and they leave the core through the four gatehouses at the core
edge on the axes.

| Quarter | What stands there |
| --- | --- |
| North, z 6..37 | the **king's hall**: a 31 x 27 basilica on its podium, great door on the axis, throne at the north end, four turrets, a clerestory with dormers and the ridge lantern |
| North, z 38..47 | the back lane, the **service avenue** and the north gatehouse |
| East, x 23..46 | the **principal service court**: the two royal trading booths (the contract's `vendor` pair), the open workyard, the household store, the draw well, stacked goods |
| West, x -47..-20 | the **chapel with its belfry**, the public **well court** and two houses |
| South-west | the **market square** (25 x 25, four booths round a marble market cross) and a house |
| South-centre | the two **colonnades** flanking the approach, the king's **statue** |
| South-east | the **waypoint plaza** reserved for WP17, the city **workshop** and two houses |
| The boundary | no curtain wall: two orchard-edge pieces either side of the south gate, a clipped hedge round every open stretch of the pad, orchards in the corners |

> **Superseded (2026-09-17):** Highcourt is now one of four walled capitals;
> every statement in this historical record that calls it open or counts only
> three walled races is superseded by
> [wp13-highcourt-fill.md](wp13-highcourt-fill.md) and the ruling of that date.

Twenty plots in all: the hall, four gatehouses, the market, two colonnades,
the statue, the well court, two orchard edges, the chapel, the workyard, the
store, the city workshop and five houses, plus the service court, the plaza,
the streets and the planting the composition authors itself.

### 2.2 Brick city, white-stone crown

The human palette of `palette.lua` is the city: cobble, brick, plank, loam
half-timbering, oak framing. The crown is a second handle -- the same palette
with `signature`, `signature_stair` and `signature_slab` rebound to darkage
marble -- and a third adds the darkage slate roof family. The king's hall, the
four gatehouses, the colonnades, the market cross, the statue and the well
court are built with the marble handle; the hall, the gatehouses, the chapel
and the two civic plots of the district are roofed in slate. Everything a
citizen built keeps plank roofs and brick accents. That is the contract's
"brick-and-white-stone city" as two handles rather than as a second palette.

The hall is built with the slate handle as well as roofed with it: its
lucarnes take their hoods from the palette's own `roof_slab`, not from the
roof palette, so a hall built with the plain handle wears plank hoods on a
slate roof.

### 2.3 The socket policy

A part cannot know how many of a thing a capital may have, and three roles
name a singular runtime seam: one throne, one travel pad for WP17, and exactly
two vendor families in `grug_traders`. The composition therefore owns a
policy, declared per plot row and asserted by the KAT as an exact multiset:

- the king's hall's own `waypoint` and the market square's are **dropped**;
  the capital publishes one travel waypoint, on the plaza reserved for it;
- the market square's four `vendor` booths are **re-published as `idle` work
  spots**, and their ids are rewritten from `_vendor_` to `_booth_`, because
  a socket called `market_vendor_1` with the role `idle` argues with itself.
  Six vendor sockets would have the runtime place six traders;
- the two real vendors stand in the service court, one of each family.

## 3. The socket table

65 sockets, in authored order (plot roster first, then the composition's own).
Positions are anchor-relative; `dir` is published beside the facedir, which is
the conversion the sockets contract asks the settlement boundary to do.

| Role | Count | Where |
| --- | --- | --- |
| `king` | 1 | `king` at (0, 6, 32), on the dais one node in front of the throne |
| `vendor` | 2 | `vendor_race` (42, 1, 7) and `vendor_general` (42, 1, 13), each outside its booth in the service court |
| `waypoint` | 1 | `travel_waypoint` (22, 1, -22), the middle of the reserved plaza |
| `quest` | 1 | `chapel_quest` (-22, 1, 27), on the chapel's doorstep |
| `guard_post` | 12 | two inside the great door, two on the throne dais, two in each of the four gate passages |
| `guard_patrol` | 18 | ten in the city loop `highcourt_watch` (orders 1..10), and two in each of the four gate towers' own loops |
| `idle` | 30 | three in the hall, two per gatehouse at its fire, four in the colonnades, six in the market (two benches, four booths), two in the well court, one at the statue, two on the orchard streets, two in the service court, two on the hall's forecourt |

**Five loops, not one.** The city's own patrol loop is a ring of ten: out
along the southern orchard street, round the four corners of the open edge,
back along the western orchard street, and up the great avenue through the two
colonnades. The four gate towers keep a loop each, of two waypoints -- the
wall walk at y = 7 and the fighting deck at y = 12 -- because that is what the
gatehouse publishes and because Highcourt has no curtain wall to carry a walk
from one gate to the next. Mixing either into the ground loop would ask an NPC
to step from the street to the wall walk through a wall. Every loop's orders
are 1..n with no gap, which the KAT walks.

## 4. The market and professions district

Nine plots along the east avenue (z = +-28) and the ring street at x = 96
(z = +-64). Each is a **self-contained composition**: its own schema,
canonical cells, bounds (x/z [-15, 15], y [-6, 24]), sorted palette,
landmarks and sockets, plus a `reference` column.

| Plot | Part | Offset from the anchor | Cells | Sockets |
| --- | --- | --- | --- | --- |
| `market_granary` | `granary` | (72, -28) | 5 715 | 3 |
| `market_stable` | `stable` | (72, 28) | 5 001 | 4 |
| `market_workshop` | `workshop`, turned | (116, -28) | 5 824 | 2 |
| `market_counting_house` | `scriptorium`, slate | (116, 28) | 6 955 | 4 |
| `market_well` | `well_court`, garden plot | (152, -28) | 4 156 | 4 |
| `market_watch` | `barracks`, slate | (152, 31) | 8 398 | 4 |
| `market_grove` | `grove` (broadleaf) | (76, -64) | 9 274 | 3 |
| `market_orchard` | `orchard_edge` | (76, 64) | 7 080 | 4 |
| `market_store` | `longhouse` | (116, -64) | 5 358 | 2 |

Each plot carries its own schema string, because the successor's `validate`
compares a blueprint's schema with its profile's.

The **reference column** is the plot origin, that is the middle of the
building: a plot levels to the ground under its own centre, never to a corner,
or half of every plot on a slope stands a terrace step too high. At settle
time the settlement config asks the pure final height of that one column once
and projects the plot's cells from it.

What makes that survive a terrace edge under the plot is the other half of
the rule, and both are built: a **foundation skirt** carries the plot's
perimeter down to y = -6, so a downhill corner still stands on masonry, and
the plot **clears its own airspace** up to its roof, so an uphill shoulder of
terrace is not left standing inside a wall. Only the perimeter is skirted and
only the airspace is cleared; a solid block of either would cost a plot four
thousand cells of buried stone and break the 12,000-cell budget on its own.

The district keeps one patrol loop of ten waypoints across all nine plots
(`highcourt_market_watch`), and every plot publishes one flair spot at its own
gate -- the plots built from `buildings.lua` publish no socket of their own,
because a start generator knows nothing about the NPC seam.

## 5. The avenue overlay

`avenue.lua` is a pure function of a column-surface callback: given a run
(axis, centre line, span, width, lamp rhythm) and `surface(x, z)`, it yields
the cells of that piece of road and nothing else. It queries no height of its
own, reads no engine, keeps no state, and is called **once per column it
touches** -- five lanes over the run plus the two verges where the rhythm puts
a lamp, which the KAT counts. That is what lets the successor call it per
mapchunk later: hand it the run clipped to the chunk and the same phase, and
the lamp line survives the chunk border.

Each of the five lanes is profiled on its own, because a terrace joint
crossing the road at an angle arrives at the five lanes in five different
columns. The carriageway is the citadel paving with a kerb lane either side.

**Where the contract's sentence was not enough.** "One stair node at each
terrace rise" is one stair per NODE of rise, not one per rise: a player walks
up half a node and jumps a whole one, and the WP40 race terrace steps are 2
(human), 3 (elf, undead, troll) and 4 (dwarf, orc).

The first version built a flight per joint, and a per-joint rule cannot be
right. Two joints closer than their flights fought over the columns between
them and left a step nobody could climb, and a joint that fell between two
PIECES of a run was walked by neither, so a road emerged one mapchunk at a
time grew a wall where a single call had a flight. Both were found by the
review, measured, and are what section 9 records.

What replaces it is one rule with no joints in it. The road's walking level is
the **one-Lipschitz upper envelope** of the lane's ground: the lowest height
field that is everywhere at or above the surface and never changes by more
than a node between two columns (two sweeps, no search). Each column is filled
from its ground up to one course below its envelope and capped with a tread
wherever the envelope stands above the ground or above a neighbour -- because
a one-node change is walked as the two halves of one stair, and a full cube
there is a node to jump. From that single rule:

- a rise of `h` still climbs over `h` columns, half a node at a time;
- two joints in a row simply make the road leave the ground earlier, which is
  what a ramp is;
- a descent is the same picture mirrored, with no second code path;
- and the envelope of a column depends on the ground within `REACH` columns of
  it and on nothing else, so a piece of the run is **exactly** that stretch of
  the whole run. `REACH` is 40: WP40 terraces a capital envelope within cut 24
  and fill 16, and a column's influence decays by one node per column of
  distance, so nothing further away can lift this one. A caller whose terrain
  is flatter may pass a smaller `reach`.

The price of chunk independence is the look-around: a run reads the ground
over its span plus twice the reach, five lanes wide, plus the two verge
columns the lamp rhythm lands on. The KAT counts those queries exactly.

The KAT profiles a synthetic terrace worse than the human plateau's -- a flat
approach, a two-node rise, a four-node rise, a three-node drop and one node of
cross fall on the southern verge, with the joints off the lamp rhythm -- and
walks every lane end to end in half-node steps, where a full node's surface is
the top of its cell and a stair carries two. It then does the same over five
more profiles, including two joints of four one column apart and a random walk
over the three race terrace steps off the library's own position hash, and
**cuts each of them at every column**, asserting that the union of the two
pieces is the whole run cell for cell: 160 cuts over 1 775 cells.

## 6. Verification

### (a) The KAT, both interpreters

`tools/wp13/highcourt_kat.lua` checks, for the core and for every plot: the
envelope and the cell budget, canonical unique cells, the palette as the
byte-sorted set of its own names, every emitted name registered and not
retired, the three authored tables of `parts.lua` against the registry in both
directions, round A's two shape rules, every pane settled the way
`update_pane` would settle it, every attached node on the support its own
rating names, no detached cell and no floating island, every torch on an
opaque full node, the exact light population, every doorway passable with a
walkable step on both sides, every closed room roofed and lit, every
destination reachable from `arrival` by the conservative walk, and the socket
contract with the exact role multiset and the loops walked 1..n.

For the core it adds: the flat ground course (only footings below y = 0), the
four gate openings walkable end to end, the king socket at the throne and
inside the hall's own box, one vendor of each family, and the waypoint plaza
empty of everything above its own paving. For a plot it adds: the reference
column, the skirt to -6 without a hole, the airspace cleared to its own roof,
and that no two plots overlap in the envelope, stand on one of the eight
street runs, or reach into a gate corridor.

For the overlay it adds the two rows the review asked for: five profiles --
including two four-node joints one column apart and a random walk over the
race terrace steps -- walked lane by lane in half-node steps, and every one of
them cut at every column with the union of the two pieces compared to the
whole run, cell for cell.

Run through `tools/wp13/evidence/20260914-highcourt/kat.sh` (library_kat +
blueprint_kat + highcourt_kat + integration_fixture in one process):

```
KAT PAIR BYTE-IDENTICAL
be4258e12c0214ed1f7222fe504dc01d10e25a6396e6dc3f793aa18a7e9eac34  kat-luajit.txt
be4258e12c0214ed1f7222fe504dc01d10e25a6396e6dc3f793aa18a7e9eac34  kat-puc51.txt
```

### (b) Build time and budget

`timing.sh` / `timing.txt`, three runs each, `os.clock` CPU milliseconds on a
16-core workstation:

| Subject | LuaJIT | PUC 5.1 | Cells |
| --- | --- | --- | --- |
| module load | 12.7 - 13.2 ms | 16.9 - 17.1 ms | -- |
| core | 111.6 - 115.5 ms | 338.0 - 354.1 ms | 101 831 |
| core, second build | 114.1 - 119.5 ms | 341.8 - 349.5 ms | same |
| district, all nine plots | 49.5 - 51.0 ms | 180.0 - 182.5 ms | 57 761 |
| one 209-node avenue run | 2.9 - 3.0 ms | 2.0 - 2.1 ms | 1 237 |

Against the contract's section 2.3 budget: the core is **101 831 of 150 000**
cells, the largest plot **9 274 of 12 000**, and a whole capital -- core plus
district -- is **159 592 of 400 000**. "Builds in a few seconds under LuaJIT
when first touched" is 0.17 s for core and district together, and 0.53 s under
the fallback interpreter. The overlay is the one piece that is faster under
PUC than under LuaJIT: it is a thousand cells of work, too little for the JIT
to pay for itself, which is worth knowing because it is the piece the
successor will call per mapchunk.

The 96 x 96 ground course is 9 025 cells and the footings 9 509; the core
carries 155 lights, 21 doorways, 15 rooms and 7 885 standable positions
reachable from the crossing.

### (c) Renders, and what changed after looking

`renders.sh` produces 32 files in
`tools/wp13/evidence/20260914-highcourt/renders/`: the core whole from both
diagonals and at night, the king's hall outside, cut open, turned and at
night, the four quarters, the crossing, the south gate, every district plot
plus six interior cutaways, and the avenue over its terraces from both
diagonals and at night. The socket inventory is `sockets.txt`.

What changed **after looking at them**:

1. **The four gatehouses stood in grass.** An open city's boundary was four
   towers and two orchard strips with nothing between them. The hedge is now
   walked round the WHOLE pad -- every column of the boundary ring that is
   still open ground gets three courses, and the run breaks by itself at a
   gate, a plot or an orchard piece. The four authored hedge runs it replaced
   included one that was planted straight through a cottage's apron.
2. **The quarters away from the centre were bare meadow.** Two more houses
   (one behind the chapel, one west of the market) and six more orchard
   blocks; a capital core has to read denser than a start from every corner,
   not only from the crossing.
3. **The waypoint plaza read as an empty car park.** It may carry nothing
   above its own paving, so its whole decoration is the floor: a white stone
   cross and diamond drawn into the ground course, which is also what marks
   the spot WP17's pad is being kept for.
4. **The hall's four lucarnes per slope wore plank hoods on a slate roof**,
   because a dormer hood comes from the palette's `roof_slab` and not from the
   roof palette. The hall is built with the slate handle now.
5. **The chapel's belfry hung its bell on nothing.** A lantern taller than
   three courses hangs the bell from a cross-beam at its own centre, and that
   beam touches nothing but the bell: the two are an island four courses above
   the ridge. `capitals.lua` carries the same two bearing cells for the king's
   hall and the temple (`bear_bell`, a local function there), so the same fix
   is written at this call site. The KAT's island flood is what found it.

Three defects the KAT caught before any render, each worth recording because
each is a generator default meeting a composition that asked for something no
start had asked for:

- **A lamp post on one avenue's verge stands in the other's carriageway.**
  The great avenue's lamp line runs on the kerb at x = +-3, and the east-west
  avenue is z -2..2: the standard at the crossing blocked a five-wide gate
  road. The line stops one node short of it.
- **`longhouse` with the `store` kit cannot carry a centred door in an
  eleven-wide gable.** The kit stands its roof posts on the odd cells of that
  wall's inner run, so the centred double door opens onto a post. Hearthpine's
  nine-wide store misses the post by one cell. Both stores are single-leaved
  at index 4 now.
- **`workshop` cannot carry a door in its z- gable at all.** The `workshop`
  kit stands the forge's cauldrons on the odd cells of that wall's inner run
  and a double door takes an odd cell whichever index it is given, and the
  generator's own default chimney stack stands on the middle cell of the same
  wall and is written after the door. The district's workshop opens in its x-
  wall, like Dawnmere's smithy, and the plot is turned instead.

### (d) Static gates, the start identities and the final micro pair

`static.sh` / `static.txt`: `tools/bin/luac51 -p` and the SETGLOBAL count on
every file this lane touched (all PASS, all zero globals), the whole
`mods/*/grug_*` and `tools` trees parse, and the five plain-5.1 sweeps scoped
first to the changed files and then to `wp13/` and `tools/wp13`. The only
sweep hits are `os.exit` in `dump_highcourt.lua`, the same standalone-CLI
pattern `dump_blueprint.lua` and `dump_capital_part.lua` have carried since
the renderer landed: none of the three is ever loaded by the engine. The
fresh-server audit passes.

`start-identity.txt`: the identity digest `r7_settlement` computes (schema,
bounds, palette, cells) for all six starts, identical to the digests the
capital-parts lane recorded. This lane added three files and changed one test
runner; it touched no shared module, so the six starts are unchanged by
construction and the digest says so.

`final-micro.sh`: one LuaJIT process and one PUC 5.1 process over the frozen
inputs, hashed before and after, running every WP13 fixture, this lane's among them:

```
9ea624d599f3a97af3ce09b56a432509de30fdc689ceb5827eb658838a87c0c9  micro-luajit.tsv
9ea624d599f3a97af3ce09b56a432509de30fdc689ceb5827eb658838a87c0c9  micro-puc51.tsv
```

`files.sha256` is the frozen-byte manifest of every input and every artefact.

**No engine run.** Nothing here is wired into the WP40 seam, so there is no
mapchunk to generate and no blueprint identity to bind; the registration half
an engine run proves is covered by the KAT's registry scan, which loads the
real definitions under a stub `core` and checks every name the composition
emits. The seam package that binds a capital owes the engine run.

## 7. What the next lane needs to know

1. **The core is not a start blueprint yet.** It is `M.core()`, a table in the
   start shape. Binding it needs the seam generalisation of contract section
   2.2: per-blueprint bounds, a settlement owning several blueprints, the
   roster-derived manifest order, and lazy construction. The numbers in
   section 6 (b) are what lazy construction has to hide: 113 ms for the core
   under LuaJIT, 350 ms under the fallback interpreter.
2. **A plot is projected, not stamped.** `plot.reference` names the column
   whose final height becomes the plot's y = 0, and the plot list carries each
   plot's offset from the capital anchor. The writer asks the pure height
   function once per plot per session and caches it.
3. **The avenue is a function, not cells.** `avenue.run(palette, spec,
   surface)` is safe to call per mapchunk: clip the run to the chunk and pass
   the same `lamp_phase` for every piece.
4. **Socket ids are unique within one composition.** The core's 65 and each
   plot's own are distinct, but a plot id is only unique within its own
   composition, so the registry key has to be the settlement key plus the plot
   id when the district registers.
5. **Four district plots sit on the blend band.** WP40 blends the core to
   the race terraces over the 32 nodes outside it (|x| 48..78 on this axis),
   and `market_granary`, `market_stable`, `market_grove` and `market_orchard`
   reach into it at |x| 62..88. The plot skirt assumes a fall no deeper than
   a terrace step; on the blend the surface may drop further, so the seam
   package must measure the real surface under each plot and either move them
   out to |x| >= 80 or deepen the skirt. Everything it needs is one height
   query per plot corner.
6. **The two capital vendors are still hard-coded.** `grug_traders/
   vendors.lua` places them at the anchor plus (+-5, 1, 3), which in this core
   is the kerb of the gate avenue. The sockets contract says they migrate to
   the `vendor` sockets when the first core lands; that is the same change
   that binds the core, and it cannot be split from it.
7. **The five remaining capitals** reuse this file's shape: a plot roster, a
   socket policy, the two or three palette handles, and the same KAT with its
   own expected multiset. Three of them are walled (Dur Brannoc, Nhal Veyr,
   Gor Drazhak), which is where `wall_segment`, `wall_tower` and the
   gatehouse's chaining really come in; Highcourt uses the gatehouse as a
   free-standing city gate and nothing else of the wall kit.

## 8. The review round (2026-09-15)

One independent review, verdict "merge after fixes": two blocking findings,
one Medium, six Lows and two look notes. What changed:

- **H1, H2 (blocking): the avenue overlay.** Both are the per-joint flight
  rule, and both are fixed by replacing it with the one-Lipschitz envelope of
  section 5. The KAT gained the two rows the review asked for: five profiles
  walked lane by lane, and every one of them cut at every column with the
  union of the pieces compared to the whole.
- **M1: the waypoint plaza landmark contained its own lamps.** The published
  box is the square inside the kerb now, and the KAT holds every column of it
  empty, edge included, instead of skipping the border.
- **M3: `market_watch` reached into the gate corridor.** Moved from z = 28 to
  z = 31, and the KAT now asserts that no plot enters the 32-node corridor of
  any gate axis -- a width nothing else in the tree enforces.
- **L1: the ring street had a one-column hole at each corner.** All four runs
  span -96..96 now, and the KAT closes the circuit by construction.
- **L2: nine plots shared one schema string.** Each plot carries its own, so
  the successor's `validate` has something to compare per plot.
- **L4: two KAT rules were narrower than the code they guard.** The plot
  airspace is checked to the plot's own roof instead of four courses, and the
  "not on a street" rule is read off the avenue and ring specs themselves
  instead of the 5 x 5 square at the anchor.
- **L5, L6:** BACKLOG, README and ROADMAP carry the increment; the stale
  comments in `highcourt.lua` and `final_micro.lua` say what the files do.
- **Look: the nave was a bare paving field.** The composition now lays a white
  stone edging either side of the carpet, a band across the nave at every
  arcade bay, four braziers and four hangings on the aisle walls -- 90 floor
  cells, asserted exactly, and each hanging searches its own bay for two
  courses of masonry rather than counting on the window rhythm.
- **Look: `market_well` read as a paved court in a field.** It is a garden
  plot now: five nodes of extra ground all round, four fruit trees, two
  planters, a second bench and the carrier's crates.
- **Look: the gatehouses read as brick prisms.** Left alone, as instructed:
  that is the parts lane's generator.

M2 (the blend band under four plots) and L3 (the hard-coded vendor offsets)
are recorded for the seam package in section 7 rather than fixed here, because
both belong to the package that binds a capital.

## 9. Open points

- The king's hall's nave floor is a large plain paving field between the
  benches and the dais. The part is the capital-parts lane's and this lane
  changed none of it; a later pass may want banners or braziers down the nave,
  which is a change to `capitals.lua` and to its own KAT row.
- The district is one of four. The other three roles (martial/garrison,
  lore/spiritual, residential/cultural) and the quadrant permutation from the
  world seed are the next increment's, together with the fixed-vs-seeded
  question the contract leaves at "a deterministic permutation from the world
  seed through the existing R6 hash".
- The user has not walked Highcourt. Nothing here is accepted until they have.
