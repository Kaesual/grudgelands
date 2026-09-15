# WP13: the capital parts library

Status: implemented and fix-rounded 2026-09-14; one independent review
(verdict: merge after fixes), whose 2 Medium, 5 Low and 3 judgement calls are
recorded in section 3b. Not re-reviewed. The user's 2026-09-15 GUI playtest of
Highcourt added the throne-orientation fix of section 5b, also not reviewed yet.
Lane: "Capital parts",
implementing Claude Opus, coordinator Claude Fable (policy "Day-to-day
routing rule"). This is the increment record for
`mods/MAPGEN/grug_mapgen/wp13/capitals.lua`, the capital-scale half of the
building library. It ships no settlement: a later composition lane assembles
these parts into the Highcourt core and its districts.

Contracts implemented:
[wp13-capitals-pois-contract.md](wp13-capitals-pois-contract.md) (what a
capital is, the 2.4 race identity table, the user's rulings on the king's
hall, the sockets and the three walled races) and
[wp13-npc-sockets-contract.md](wp13-npc-sockets-contract.md) (the socket
field). The library contract and the section-5 invariants are
[wp13-settlement-pipeline.md](wp13-settlement-pipeline.md); the shared
modules and the renderer review loop are
[wp13-hearthpine-library.md](wp13-hearthpine-library.md).

## 1. What shipped

| File | Change |
| --- | --- |
| `mods/MAPGEN/grug_mapgen/wp13/capitals.lua` | **new**: eighteen generators, the socket seam, the capital accessors |
| `mods/MAPGEN/grug_mapgen/wp13/palette.lua` | ten new OPTIONAL roles plus five new bindings of the pre-existing `pillar` |
| `mods/MAPGEN/grug_mapgen/wp13/parts.lua` | the arrowslit and throne orientation families, the capital shape families, two opaque cubes |
| `mods/MAPGEN/grug_mapgen/wp13/interiors.lua` | five new kits: `barracks`, `temple`, `scriptorium`, `granary`, `stable` |
| `tools/wp13/library_kat.lua` | section 12 and 12b: every capital part, every race, all four rotations |
| `tools/wp13/dump_capital_part.lua` | **new**: one part to TSV, for the renderer |
| `tools/wp13/extract_tiles.py`, `node_tiles.json` | the capital vocabulary's tiles (37 nodes added, one repaired) |

Nothing in the six start compositions, the wp40 seam files or the blueprint
wrappers was touched. The six start blueprint identities and the library KAT's
existing rows are unchanged; §5 carries the proof.

## 2. The capital vocabulary

Eleven roles, all **optional** and all bound for every race. TEN of them are
new to `palette.optional`; the eleventh, `pillar`, was already there and
already bound for the undead (`palette.lua`, the Stillgrave table), and what
this lane added is its five other race bindings. Optional is not politeness: a
start composition must keep building without them (which is what keeps the six
shipped blueprints byte-identical), and every generator has a fallback into the
start vocabulary, proved by KAT section 12b, which strips the whole vocabulary
out of a throwaway palette and builds all eighteen parts against it.

| Role | Dwarf | Human | Elf | Undead | Orc | Troll |
| --- | --- | --- | --- | --- | --- | --- |
| `castle_wall` (+`_stair`, `_slab`) | `castle_stonewall` | `castle_stonewall` | `castle_stonewall` | `castle_dungeon_stone` | `castle_stonewall` | `castle_stonewall` |
| `castle_paving` | `castle_pavement_brick` | same | same | same | same | same |
| `castle_rubble` | `castle_rubble` | same | same | same | same | same |
| `castle_slit` | `castle_arrowslit_stone_block` | `…_stonebrick` | `…_silver_sandstone_brick` | `…_obsidianbrick` | `…_desert_stonebrick` | `…_mossycobble` |
| `pillar` (family) | `castle_pillar_stone_block` | `…_stonebrick` | `…_silver_sandstone_brick` | `…_obsidianbrick` (unchanged) | `…_desert_stonebrick` | `…_mossycobble` |
| `signature` | `default:stone_block` | `default:brick` | `darkage_marble` | `default:obsidianbrick` | `darkage_adobe` | `darkage_basalt` |
| `signature_stair` / `_slab` | `stairs:*_stone_block` | `stairs:*_brick` | `darkage_marble_*` | `stairs:*_obsidianbrick` | `darkage_ors_brick_*` | `darkage_basalt_*` |
| `throne` | `xdecor_chair` | same | same | same | same | same |

Three notes the next lane needs:

- **`signature_stair`/`_slab` are not always the shape family of
  `signature`.** `grug_decor:darkage_adobe` ships no stair or slab shape at
  all (`darkage.lua`'s `shaped` roster), so the orc pair is the Old Red
  Sandstone brick the same palette already bands its walls with. A generator
  that assumes "signature plus `_stair`" would name an unregistered node.
- **`pillar` was already the undead vocabulary and keeps its exact binding**,
  so Stillgrave's gate is untouched; the other five races gained a binding
  nothing in the six starts reads.
- **The arrowslit is the one castle-kit node whose param2 is load bearing.**
  Its opening runs from z = 0.3125 to z = 0.5, the node's own +Z face
  (`castle.lua`, `register_arrowslit`), and a facedir node's +Z face looks
  along `facedir_to_dir(param2)` -- the same rule the shutter obeys. The
  pillars are deliberately NOT in `PARAM2_KIND`: their three nodeboxes are
  symmetric about both horizontal axes, so a rotation would write a param2
  that means nothing.

## 3. The generators

Common interface, identical to `buildings.lua`: `M.<name>(palette, spec)`
returns a part `{buffer, w, d, peak, points}` in its own local frame -- x
0..w-1, z 0..d-1, y = 0 the ground node, y = 1 the first walkable course --
which `parts.stamp(target, part, ox, oy, oz, turns)` places at any of the four
rotations. Authored populations (merlons, arrowslits, trees, stalls, piers,
benches) travel on the part table beside `w`/`d`/`peak`; `points` holds only
lists of points, because `parts.stamp` rotates every entry of every list in
it. `peak` is MEASURED from the finished buffer, never declared.

`points.sockets` is the NPC seam: an array of
`{id, role, x, y, z, face, …}` where `face` is a facedir that rotates with the
part and the optional fields are the contract's (`group`/`order` for a patrol
loop, `kind` for a vendor, `tags` for an idle spot). A composition converts
`face` with `core.dir_to_yaw(core.facedir_to_dir(face))`.

Extents below are every cell the part writes, aprons, eaves, buttresses and
flights included, which is the plot a composition has to reserve. The envelope
is the capitals contract's: **core** 48 x 48 and y -2..40, **plot** 32 x 32
and y -6..24. KAT section 12 measures both.

| Generator | Spec (defaults) | Extent (x, z, y) | Sockets | Solid / all cells |
| --- | --- | --- | --- | --- |
| `king_hall` | `w 31, d 39, arcade 5, rise 7, door_x, service_z, dais_z, inside, roof_palette` | 36 x 44, y -2..31 (core) | `king` 1, `guard_post` 4, `waypoint` 1, `idle` 3 | 8 693 / 47 817 |
| `wall_segment` | `len 8, phase 0, stair, patrol_group, order` | len x 5, y -2..9 | `guard_patrol` 2 | 386 / 520 (544 / 780 with the stair) |
| `wall_tower` | `patrol_group, order` | 9 x 9, y -2..15 | `guard_post` 1, `guard_patrol` 1, `idle` 1 | 780 / 1 539 |
| `gatehouse` | `patrol_group, deck_group, order` | 13 x 7, y -2..14 | `guard_post` 2, `guard_patrol` 2, `idle` 2 | 899 / 1 547 |
| `colonnade` | `len 15, d 5, patrol_group, order` | 17 x 7, y 0..7 | `idle` 2, `guard_patrol` 1 | 344 / 1 071 |
| `market_square` | `size 25` | 25 x 25, y 0..7 | `vendor` 4, `idle` 2, `waypoint` 1 | 919 / 5 625 |
| `well_court` | `size 11` | 11 x 11, y 0..4 | `idle` 2 | 155 / 847 |
| `statue_plinth` | -- | 9 x 9, y 0..9 | `idle` 1 | 157 / 810 |
| `barracks` | `w 15, d 21, wall_h 5, roof "gable", rise 4, infill, shutters` | 17 x 23, y 0..10 | `guard_post` 1, `idle` 1, `guard_patrol` 1 | 1 233 / 4 692 |
| `temple` | `w 13, d 19, wall_h 7, roof "hip", rise 5` | 15 x 21, y 0..20 | `idle` 1, `quest` 1 | 1 186 / 4 798 |
| `scriptorium` | `w 13, d 17, wall_h 6, roof "saltbox"` | 15 x 19, y 0..11 | `idle` 2 | 1 089 / 3 990 |
| `granary` | `w 11, d 15, wall_h 5, roof "saltbox"` | 13 x 17, y 0..11 | `idle` 1 | 810 / 3 094 |
| `stable` | `w 15, d 11, wall_h 5, roof "gable"` | 17 x 13, y 0..9 | `idle` 2 | 749 / 2 652 |
| `orchard_edge` | `len 21, d 11, patrol_group, order` | 21 x 13, y 0..9 | `idle` 1, `guard_patrol` 2 | 727 / 3 968 |
| `grove` | `size 17, kind "tree", height 8` | 17 x 17, y 0..9 | `idle` 1 | 516 / 7 225 |
| `stilt_platform` | `size 15, deck 6, spur 6, patrol_group, order` | 15 x 26, y 0..7 | `guard_patrol` 2, `idle` 1 | 643 / 2 587 |
| `water_channel` | `len 21, bridge, patrol_group, order` | 21 x 7, y -3..3 | `idle` 1, `guard_patrol` 2 | 524 / 1 176 |

Cell counts are the dwarf palette's, SOLID (non-air) first and then the whole
cell list. The two differ a great deal and only the second is the budget
number: a blueprint's cell list carries its authored AIR as well, which is what
clears the volume a part stands in, and the contract's per-plot and per-core
budgets count cells, not stone. Hearthpine Vale, for comparison, is 61,932
cells of which 46,389 are solid. The king's hall is 47,817 cells, 32% of the
capitals contract's 150,000-cell core budget; the largest plot is the grove at
7,225, well inside the 12,000 a plot is allowed, and it is mostly the cleared
volume over the trees.

The six races differ by at most 55 cells on one part, where an optional role
degrades (the orchard plants a hedge only for the human palette, the stable
beds its boxes only for the three races that bind a mat).

What each one is, and the decisions inside it:

- **`king_hall`** is a **basilica**, and the section is the point. The first
  version was one rectangle with walls all round and one gable over the lot,
  and the render was a barn. This one is a tall narrow nave between two
  arcades, a low aisle either side under its own lean-to, and the nave wall
  carried on the arcade rising clear above the aisle roofs as a clerestory --
  three roof planes at two heights, four bands on the long elevation. Four
  crenellated corner turrets, a buttress every sixth bay, a rose over the
  great door with a light carried on up the gable, three lancets over the
  throne, and the library's own `buildings.belfry` on the ridge over the
  dais. Inside: a carpet approach three cells wide, a three-step dais with
  stair risers, the throne against a screen of signature masonry under a
  canopy of two columns and a lintel, royal hangings on the end wall, benches
  down both aisles, braziers at the arcade feet and a service door for the
  household. The room corner publishes the AISLE head as its `top`, because
  the lowest roofed level of a basilica is the aisle.
- **`wall_segment`** is the chaining piece: rubble core between two masonry
  faces, a three-wide walkway, a crenellated outer parapet with signature
  caps, a solid inner one, loopholes on the four-node merlon rhythm, and
  optionally an internal flight with its own door. `spec.phase` carries the
  crenellation across the joint. Every cell lies inside `x 0..len-1,
  z 0..4`, so chaining is stamping the same part at len-node intervals; the
  KAT asserts that footprint.
- **`wall_tower`** is the corner: a nine by nine drum, two straight flights
  to the rampart floor and on to the fighting top, rampart openings three
  wide in two adjacent faces at walkway height, loopholes on all four, a
  crenellated crown. **Both flights run along X, against the two faces the
  rampart does not arrive at.** That is not style: the rampart enters through
  the z = 0 face and leaves through the x = 0 face, so a walker turning the
  corner crosses the whole z 3..5 band, and a stairwell cut through the
  rampart floor anywhere in that band is a hole in the wall walk.
- **`gatehouse`** carries a chamber over a **five-wide passage**: x 4..8 is
  clear from the paving to head height for the whole depth, which KAT section
  12 asserts against the registry's `walkable`. The arch springs from a stone
  stair each side at y = 5. Each pier holds a guard chamber with its own door
  to the street.
  Its chamber is a **rampart room, not a dead end**: the floor is the wall
  walk's own level and both end faces carry an opening three wide and two
  high at z 2..4, so a walker on the curtain wall walks THROUGH the gate.
  Nothing cuts that floor -- there is deliberately no flight from the ground
  to the chamber, because any stairwell wide enough to climb would be a hole
  in the wall walk, and a gate tower is reached from the rampart. The fighting
  deck five courses higher is reached by a flight in the city-side row, clear
  of the through-band, and its patrol waypoint is in a **loop of its own**
  (`spec.deck_group`), because a loop that mixed y = 7 and y = 12 would ask an
  NPC to walk between them with nothing in between.
- **`colonnade`**, **`market_square`**, **`well_court`**,
  **`statue_plinth`** are the civic furniture. The market is four awninged
  `dressing.stall` booths round a stepped market cross, with crates, benches
  on all four sides, planters and eight lamps; the trader stands one cell
  outside his booth, because all nine of its cells are taken. The statue is
  one material on a plinth of another -- a flared robe, a narrow body, two
  stair shoulders, a head and a crown.
- **`barracks`, `temple`, `scriptorium`, `granary`, `stable`** are ordinary
  `buildings.build` blocks with a capital kit, so they inherit the library's
  walls, framed windows, real doors and rasterised roof. They ask for half
  timbering by default and for shutters never (the only shutter in the tree
  is the CLOSED leaf, and a plot that asks for shutters everywhere renders as
  a boarded-up building). The temple carries a belfry on its ridge. Every kit
  keeps the room's centre column clear, which is where the sockets stand.
- **`orchard_edge`, `grove`, `stilt_platform`, `water_channel`** are the open
  races' edge, in place of a curtain wall (the user's 2026-09-14 ruling:
  walls for Dur Brannoc, Nhal Veyr and Gor Drazhak only). The orchard edge is
  a kerbed ring street, a clipped hedge with a gate gap and two rows of fruit
  trees; `grove` takes a `kind` naming any `dressing` tree silhouette; the
  stilt platform is timber legs on masonry pads under a six-course deck, with
  a railed walkway spur and a flight down; the water channel is a lined cut
  with paved banks, a kerb rail and a five-wide plank crossing.

## 3b. The review round

An independent review of the first version returned "merge after these fixes".
What changed:

- **The wall walk dead-ended at every gate** (M1). The gatehouse chamber was
  walled solid on the two end faces the curtain wall abuts, so a walker on the
  rampart stopped at each gate; its only patrol waypoint was on the roof deck
  five courses higher and in the same loop as the wall's own. Fixed as
  described above: rampart openings at z 2..4 on both end faces, an unbroken
  chamber floor, the ground flight removed, a chamber-to-deck flight in the
  city-side row, and two waypoints in two loops.
  The review did not say so, but **the corner tower had the same defect one
  level down**: its two flights ran along Z at x = 1 and x = 7 and cut their
  stairwells straight through the z 3..5 band a walker crosses to turn the
  corner. Both flights run along X now, against the two faces the rampart does
  not use. A scratch conservative walk over each part confirms rampart-to-
  rampart, rampart-to-top and ground-to-rampart on the tower, and
  rampart-to-rampart and rampart-to-deck on the gatehouse.
- **A two-cell island inside every belfry** (M2). `buildings.belfry` hangs the
  bell under a cross-beam whenever the lantern is taller than three courses,
  and writes that beam as one cell at the centre of the plan while its beam
  ring is the edge cells only: beam and bell touch each other and nothing
  else. Every rule this library had asks whether a cell touches another cell,
  and these two do, so nothing caught it. `capitals.bear_bell` carries the
  frame across to the ring, and the king's hall and the temple call it.
  **Scoped to the capital parts on purpose, exactly like the well kerb in
  `well_court`:** Silverleaf Glade's shrine stamps the same four-course
  lantern at (-21, 15/16, 25) and its blueprint identity is frozen, so
  `buildings.belfry` itself must not move a cell. A composition that stamps a
  lantern taller than three courses has to call `bear_bell` too.
  The durable half of the fix is in the KAT: section 12 now floods the same
  adjacency (face or vertical diagonal) from the GROUND up and requires every
  non-loose cell to be reachable, so a piece of architecture has to be
  connected to the terrain and not merely to itself. Deleting the `bear_bell`
  call makes it fail on the bell slab, which is how the guard was proved.
- **Every internal flight landed one tread short** (L1) -- a 1.0-node jump
  rather than a 0.5 step. The rule is written down at the wall stair now: a
  flight from a floor at y = f to a floor at y = g carries g - f treads, at
  y = f + 1 .. g, and the TOP one stands IN the upper floor. The wall stair,
  both tower flights and the stilt platform's flight gained their last tread.
  `dressing.stair_up` is left alone (Kapok's identity is frozen) and the stilt
  platform writes the tread the shared routine omits, with the reason at the
  call site.
- Three judgement calls from the renders, all taken:
  **the corner turrets** read as chimneys -- three by three of solid masonry
  twenty-two courses high with two slits. They are hollow above the hall floor
  now, carry four storeys of loopholes instead of two, and wear a corbel table
  that oversails their two outward faces one node under the crown. What is
  left, and a composition should know it: a turret's two INNER faces are
  genuinely internal below the aisle roof, so from a camera over the building's
  own corner a near turret still shows blank masonry.
  **The statue** is an armoured man with a standard: a flared skirt, a shield
  arm, two stair shoulders, a head, a helm crest, and a standard with a banner
  off the other shoulder, which is the piece that makes the outline a figure
  rather than a pillar. The per-race obelisk and lantern-pillar variants the
  review offered as an alternative are a `spec.form` away and are not built.
  **The nave roof** gained four dormers per slope, three wide and three tall,
  each standing on the course of roof it interrupts. A full change of pitch
  was priced and not taken: the roof is a height field, and a second pitch
  needs cheek-filling the rasteriser does not do.

## 4. Two things deliberately left out

- **The water channel is authored DRY.** Pipeline contract §5 invariant 1
  forbids a liquid in a blueprint, and for a good reason: a VoxelManip write
  places no liquid update, so authored water is either a static block that
  never flows or a flood nobody asked for. What the part builds is the cut,
  the lining, the banks and the crossing. Filling it is a composition-lane
  decision and the engine's job.
- **No engine run.** Nothing here is wired into a settlement, so there is no
  mapchunk to generate and no blueprint identity to bind. The registration
  half that an engine run proves is covered by the KAT's registry scan, which
  loads the real definitions under a stub `core` and checks every name every
  part emits. The first composition that places these parts owes the engine
  run.

## 5. Verification

### (a) The library KAT, both interpreters

`tools/wp13/library_kat.lua` gained **section 12**: for each of eighteen
cases, for each of the six races, the part is built twice (determinism, cell
for cell) and stamped at all four rotations, and each stamped buffer is put
through, against the real registry loaded by `tools/wp13/stub_registry.lua`:

1. the bounds envelope of its class, and that no cell stands above the part's
   own declared `peak`;
2. every emitted name registered, not retired, and `parts.param2_kind`,
   `parts.pane_connects`, `parts.full_solid` and `parts.shaped` each agreeing
   with the registry in both directions, with `place_param2` honoured and
   every unoriented node at param2 0;
3. round A's two shape rules -- a bottom slab carries nothing, and an
   upside-down facedir cell is a stair or a slab that meets what is above it;
4. every pane exactly what `update_pane` would have settled on, re-derived
   from the mod's own connection groups after `parts.resolve_panes`;
5. every `group:attached_node` cell attached to a WALKABLE support in the
   direction its own rating names, transcribed from
   `builtin/game/falling.lua:391-434`;
6. no detached cell, with the same three node-property exemptions as section
   11, AND no island: the same adjacency flooded from the ground up, so two
   cells that touch each other and nothing else fail where the local
   neighbour rule passes them;
7. every torch on an opaque full node;
8. the socket contract: unique ids, a valid role, the exact authored role
   multiset, a facing, two free cells and a walkable floor, `group`/`order`
   on every patrol waypoint and `kind` on every vendor;
9. every doorway a real leaf-and-hidden pair, passable and with a walkable
   step on BOTH sides;
10. roof and wall closure plus at least one light for every room a part
    declares closed, and the exact authored room count;
11. the chaining footprint of the linear pieces and the five-wide clear of the
    gate passage.

The status line at the top is now: reviewed once (verdict "merge after these
fixes"), fixes applied, not re-reviewed.

**Section 12b** registers a throwaway race with all eleven capital roles
stripped out and builds all eighteen parts against it, which is the only place
the "optional, with a fallback" claim is actually tested.

Run through `tools/wp13/evidence/20260914-capital-parts/kat.sh`
(library_kat + blueprint_kat + integration_fixture in one process):

```
KAT PAIR BYTE-IDENTICAL
f3a38c47a3a94715ae318beca0d8f45bb8f395e807f286a7ed261f6a053b343e  kat-luajit.txt
f3a38c47a3a94715ae318beca0d8f45bb8f395e807f286a7ed261f6a053b343e  kat-puc51.txt
```

### (b) The six start blueprints are byte-identical

The identity digest `r7_settlement` computes (schema, bounds, palette, cells),
taken from a `git archive` of `main` at `9026d89` and from this tree:

| Start | Cells | Palette | Identity SHA-256 |
| --- | --- | --- | --- |
| dawnmere | 66 361 | 54 | `80b3f0fcd3005f5186e528393f171029eb9fcf66ed0674ce321dbe1bc38f748b` |
| hearthpine | 61 932 | 41 | `8233c7bc0fe668991e2afd1de53eaae1ede18cf1893cb8ab37ecb223248d4240` |
| kapok | 72 535 | 42 | `c7aadf6a8f599d0f9213cce26153a62e739f1ff2f7920c3a25c1031b63bc21a5` |
| silverleaf | 71 495 | 48 | `149ca6ebdfea6dac18b9385f7fbaa7bbadf37c400cd5d22422acb184859bba05` |
| stillgrave | 51 641 | 44 | `ed6ddd43946d3909aa4a061e3bfa816d80c3e9b6663f33cfc640ec919f836a34` |
| sunscar | 57 227 | 43 | `8110477c6fc555b32c8bd34834812e7b2adb3c561b68202d050cefd6c686fbc6` |

All six identical before and after. That is what the three shared-module
changes are worth: the palette change only ADDS optional roles (and rebinds
`pillar` for five races that read it nowhere), the `parts.lua` change only
ADDS table entries for names no start emits, and the `interiors.lua` change
only adds kits no start furnishes with. The one existing kit line that moved
-- the stable's feed store and its trough -- is in a kit this lane wrote.

### (c) Renders

`tools/wp13/evidence/20260914-capital-parts/renders.sh` renders every part for
human, dwarf and troll, plus twelve interior cutaways, two turned views and
two night views: 71 files in `renders/`. The socket inventory is
`sockets.txt`. What changed **after looking at them**:

1. **The king's hall read as a box.** One rectangle, one roof plane, windows
   too small to break either. Rebuilt as the basilica above; then, on the
   second look, the nave roof was still one unbroken plane thirty-nine nodes
   long, so it gained the ridge lantern; and the clipped aisle lean-to ended
   in a flat three-node deck against the clerestory that read as a gutter
   running the whole length, so the aisle pitch was set to the aisle's own
   width. The nave roof also oversailed the clerestory by a node, which left a
   plank ledge four courses clear of the aisle roof with nothing under its
   nose at the gable; it lands flush now.
2. **The throne was a chair lost on a fifteen-node dais.** It got a screen of
   signature masonry two courses taller than the man in it.
3. **The stilt platform read as a plinth, not stilts.** Legs three apart in
   basalt under a four-course deck is a wall with a lid on it. Timber posts
   on a four-node grid under a six-course deck, on masonry pad stones.
4. **The statue was a striped totem** -- the figure alternated the two
   materials up its own height. Plinth in the citadel masonry, figure in the
   signature material, all of it; and a flared robe and stair shoulders
   instead of two cubes with slabs stuck out either side.
5. **The market square was four booths round thirteen by thirteen nodes of
   bare paving.** It gained the stepped market cross, crates beside every
   booth, benches on all four sides, four planters and eight lamps.
6. **The temple looked boarded up**: shutters on by default, and the only
   shutter in the tree is the closed leaf. Default off.
7. **The gatehouse crown was a dentil band**, one course with a slab on every
   other cell. Two courses and a cap, like the tower and the wall.
8. **The stable's feed troughs were anvils** (the `workbench` role is an anvil
   in two palettes and an iron block in a third). They are the race's own
   cauldron now.
9. The orchard hedge was two courses and disappeared behind the trees; three.

Three defects the KAT caught before any render, worth recording because each
is a rule this library already had: the gate-jamb torches hung in the middle
of the road (the support step's sign), the wall stair started in its own
doorway so a walker stepped out onto the raised half of a stair, and
`dressing.stair_up`'s flight, given the wrong sign, walked back across the
deck and cut three holes in it.

**One latent library defect found and scoped, not fixed:**
`dressing.well` stands its two frame posts on its own kerb, and the kerb is
the palette's `low_wall`. For the three starts that draw a well that is a
`walls:` nodebox, a full-height cube; for the ELF it is
`grug_decor:darkage_serpentine_slab`, a bottom slab, so both posts would ride
half a node clear of their footing -- round A's defect, in a piece of dressing
no pale-stone race had drawn yet. `well_court` re-lays the two bearing cells
in its own paving. Fixing `dressing.well` itself would move cells in
Hearthpine, Dawnmere and Stillgrave, whose blueprint identities are frozen, so
a future lane that gives the elf a well must either carry the same local fix
or change the elf `low_wall` binding.

### (d) Static gates and the final micro pair

`static.sh` / `static.txt`: `tools/bin/luac51 -p` and the SETGLOBAL count on
every touched Lua file (all PASS, all zero globals), the whole
`mods/*/grug_*` and `tools` trees parse, and the five plain-5.1 sweeps scoped
first to the changed files and then to `wp13/` and `tools/wp13`. The only
sweep hits are `os.exit` in `dump_capital_part.lua`, which is the same
standalone-CLI pattern `dump_blueprint.lua` has carried since the renderer
landed: neither file is ever loaded by the engine. `extract_tiles.py`
compiles, `node_tiles.json` parses (506 nodes), and the fresh-server audit
passes.

`final-micro.sh`: `tools/wp13/final_micro.lua` is **byte-identical** (it takes
the same three arguments and runs the same three fixtures). One LuaJIT process
and one PUC 5.1 process over the frozen inputs, hashed before and after:

```
f3a38c47a3a94715ae318beca0d8f45bb8f395e807f286a7ed261f6a053b343e  micro-luajit.tsv
f3a38c47a3a94715ae318beca0d8f45bb8f395e807f286a7ed261f6a053b343e  micro-puc51.tsv
```

`files.sha256` is the frozen-byte manifest of every input and every artefact.

## 5b. Playtest round 1 (2026-09-15): the throne faced the wall

The user's GUI playtest of Highcourt found the king's hall's chair turned
round: the backrest stood between the king and his hall instead of behind him.
`king_hall` wrote the **king socket's own facedir** into the seat.

Both nodes the `throne` role can bind carry their back on their own **+Z**
side -- `grug_decor:xdecor_chair`'s two tall posts and its back panel sit at
pixels z 11..13, and the degraded binding is a stair-seat whose raised half is
its +Z half -- and a facedir node's +Z side looks along
`core.facedir_to_dir(param2)`. So a seat that LOOKS at `face` carries
`(face + 2) % 4`, which is exactly what `parts.seat` writes and what the
socket's own facing needed converting to. `king_hall` now names the direction
(`throne_look = 2`, the great door at local z 0) and does that arithmetic. One
cell moved in the whole hall: `15,6,24` from param2 2 to param2 0.

Two things came out of the round beyond the one literal:

- **`highcourt_kat.lua` now asserts the orientation**, derived from its own
  direction model rather than from `parts.seat`'s arithmetic: the seat's look
  direction is the opposite of its +Z side, it must equal the king socket's own
  facing, and that shared direction must be -z, the great door. It publishes a
  `highcourt_throne` row. Setting the literal back to the rejected value fails
  the fixture.
- **`render_blueprint.py` could not show the defect.** It drew every
  `nodebox` -- the chair included -- as one generic inset box, so the review
  loop's own pictures were blind to the thing the user saw from the ground. The
  renderer now knows a `chair` shape (seat plus back, turned with the facedir)
  and `extract_tiles.py` classifies the chair as one, so the regenerated
  `node_tiles.json` keeps it. The before/after pair is in
  `tools/wp13/evidence/20260915-apron-and-throne/renders/`, with an orientation
  reference picture beside it that makes the view's axes readable off the
  picture itself.

What this costs: **Highcourt's core identity SHA-256 moves**, and with it the
settlement-level one, because a blueprint identity covers every cell's param2:
`90eae871e24a1247...` becomes `187f79e0ba521038...`. Its population (101,831
cells in the core, 169,150 in the settlement) and all nine district plot SHAs,
the avenue overlay SHA and the six START blueprint SHAs are unchanged.
`tools/wp13/run_highcourt.sh`'s avenue digest is unaffected -- it hashes the
road the map actually has, which no chair touches -- and re-measured to the same
`9d6f0167f043f899...` on seed 531802985935182545, 0 ERROR and 0 ModError.

## 6. What the composition lane needs to know

1. **Run `parts.resolve_panes` over the finished pad**, once, after every part
   is stamped. The parts write the provisional flat pane; a pane's shape
   depends on neighbours the part that wrote it cannot see, and the six start
   compositions all do this.
2. **`points.sockets` carries `face` as a facedir**, not as the contract's
   `dir` vector. Convert at the settlement boundary:
   `dir = core.facedir_to_dir(face)`.
3. **Socket ids are unique within a PART, not within a settlement.** Every
   generator prefixes with `spec.id`; give each plot a distinct `id` or two
   colonnades will publish `colonnade_idle_a` twice.
4. **The wall chains on its own footprint** (`len x 5`), and `spec.phase`
   carries the crenellation. Its walkway is the three cells z 1..3 of that
   footprint, decked at y = 6 and walked at y = 7.
   **A wall is CENTRED on the tower or gatehouse it meets, and that inset is
   the composition's to get right.** A five-deep wall centred on the nine-deep
   `wall_tower` is inset two nodes, so the walkway's z 1..3 arrives at the
   tower's z 3..5, which is where the tower's rampart openings are; centred on
   the seven-deep `gatehouse` it is inset one node, so the same walkway arrives
   at z 2..4, which is where the gatehouse's are. Get the inset wrong and the
   walk meets masonry.
5. **`grove` takes `spec.kind`** naming any `dressing` tree function
   (`tree`, `broadleaf`, `columnar`, `acacia`, `jungle_tree`, `gravewood`,
   `emergent`); the default conifer is not what a troll basin wants.
6. The plots' `y` extents are all inside -6..24 and the hall's inside -2..40,
   but several parts write NEGATIVE y (the skirts, the channel invert). The
   plot projection has to carry them.
