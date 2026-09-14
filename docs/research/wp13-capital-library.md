# WP13: the capital parts library

Status: implemented 2026-09-14, not reviewed yet. Lane: "Capital parts",
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
| `mods/MAPGEN/grug_mapgen/wp13/palette.lua` | eleven new OPTIONAL roles, bound for all six races |
| `mods/MAPGEN/grug_mapgen/wp13/parts.lua` | the arrowslit and throne orientation families, the capital shape families, two opaque cubes |
| `mods/MAPGEN/grug_mapgen/wp13/interiors.lua` | five new kits: `barracks`, `temple`, `scriptorium`, `granary`, `stable` |
| `tools/wp13/library_kat.lua` | section 12 and 12b: every capital part, every race, all four rotations |
| `tools/wp13/dump_capital_part.lua` | **new**: one part to TSV, for the renderer |
| `tools/wp13/extract_tiles.py`, `node_tiles.json` | the capital vocabulary's tiles (37 nodes added, one repaired) |

Nothing in the six start compositions, the wp40 seam files or the blueprint
wrappers was touched. The six start blueprint identities and the library KAT's
existing rows are unchanged; §5 carries the proof.

## 2. The capital vocabulary

Eleven roles, all **optional**, added to `palette.optional` and bound for
every race. Optional is not politeness: a start composition must keep building
without them (which is what keeps the six shipped blueprints byte-identical),
and every generator has a fallback into the start vocabulary, proved by KAT
section 12b, which strips the whole vocabulary out of a throwaway palette and
builds all eighteen parts against it.

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

| Generator | Spec (defaults) | Extent (x, z, y) | Sockets | Cells |
| --- | --- | --- | --- | --- |
| `king_hall` | `w 31, d 39, arcade 5, rise 7, door_x, service_z, dais_z, inside, roof_palette` | 36 x 44, y -2..31 (core) | `king` 1, `guard_post` 4, `waypoint` 1, `idle` 3 | 8 685 |
| `wall_segment` | `len 8, phase 0, stair, patrol_group, order` | len x 5, y -2..9 | `guard_patrol` 2 | 386 / 549 |
| `wall_tower` | `patrol_group, order` | 9 x 9, y -2..15 | `guard_post` 1, `guard_patrol` 1, `idle` 1 | 780 |
| `gatehouse` | `patrol_group, order` | 13 x 7, y -2..14 | `guard_post` 2, `guard_patrol` 1, `idle` 2 | 903 |
| `colonnade` | `len 15, d 5, patrol_group, order` | 17 x 7, y 0..7 | `idle` 2, `guard_patrol` 1 | 344 |
| `market_square` | `size 25` | 25 x 25, y 0..7 | `vendor` 4, `idle` 2, `waypoint` 1 | 919 |
| `well_court` | `size 11` | 11 x 11, y 0..4 | `idle` 2 | 155 |
| `statue_plinth` | -- | 9 x 9, y 0..7 | `idle` 1 | 150 |
| `barracks` | `w 15, d 21, wall_h 5, roof "gable", rise 4, infill, shutters` | 17 x 23, y 0..10 | `guard_post` 1, `idle` 1, `guard_patrol` 1 | 1 233 |
| `temple` | `w 13, d 19, wall_h 7, roof "hip", rise 5` | 15 x 21, y 0..20 | `idle` 1, `quest` 1 | 1 184 |
| `scriptorium` | `w 13, d 17, wall_h 6, roof "saltbox"` | 15 x 19, y 0..11 | `idle` 2 | 1 089 |
| `granary` | `w 11, d 15, wall_h 5, roof "saltbox"` | 13 x 17, y 0..11 | `idle` 1 | 810 |
| `stable` | `w 15, d 11, wall_h 5, roof "gable"` | 17 x 13, y 0..9 | `idle` 2 | 749 |
| `orchard_edge` | `len 21, d 11, patrol_group, order` | 21 x 13, y 0..9 | `idle` 1, `guard_patrol` 2 | 727 |
| `grove` | `size 17, kind "tree", height 8` | 17 x 17, y 0..9 | `idle` 1 | 516 |
| `stilt_platform` | `size 15, deck 6, spur 6, patrol_group, order` | 15 x 26, y 0..7 | `guard_patrol` 2, `idle` 1 | 643 |
| `water_channel` | `len 21, bridge, patrol_group, order` | 21 x 7, y -3..3 | `idle` 1, `guard_patrol` 2 | 524 |

Cell counts are the dwarf palette's solid (non-air) cells; the six races differ
by at most 55 cells on one part, where an optional role degrades (the orchard
plants a hedge only for the human palette, the stable beds its boxes only for
the three races that bind a mat). The whole catalogue is 122 101 solid cells
over eighteen parts and six races.

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
  crenellated crown.
- **`gatehouse`** carries a chamber over a **five-wide passage**: x 4..8 is
  clear from the paving to head height for the whole depth, which KAT section
  12 asserts against the registry's `walkable`. The arch springs from a stone
  stair each side at y = 5. Each pier holds a guard chamber with its own door,
  the west one also the flight to the chamber above; the roof is a
  crenellated deck level with the curtain wall's crown.
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
   11;
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

**Section 12b** registers a throwaway race with all eleven capital roles
stripped out and builds all eighteen parts against it, which is the only place
the "optional, with a fallback" claim is actually tested.

Run through `tools/wp13/evidence/20260914-capital-parts/kat.sh`
(library_kat + blueprint_kat + integration_fixture in one process):

```
KAT PAIR BYTE-IDENTICAL
875fc3ddc6aecea28752a68b0b9ba9cbb6abd50dd5c31cb951500eaa985b4ee7  kat-luajit.txt
875fc3ddc6aecea28752a68b0b9ba9cbb6abd50dd5c31cb951500eaa985b4ee7  kat-puc51.txt
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
875fc3ddc6aecea28752a68b0b9ba9cbb6abd50dd5c31cb951500eaa985b4ee7  micro-luajit.tsv
875fc3ddc6aecea28752a68b0b9ba9cbb6abd50dd5c31cb951500eaa985b4ee7  micro-puc51.tsv
```

`files.sha256` is the frozen-byte manifest of every input and every artefact.

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
   carries the crenellation. A tower or a gatehouse at a corner lines up with
   the three-wide walkway at y = 6 / standing y = 7.
5. **`grove` takes `spec.kind`** naming any `dressing` tree function
   (`tree`, `broadleaf`, `columnar`, `acacia`, `jungle_tree`, `gravewood`,
   `emergent`); the default conifer is not what a troll basin wants.
6. The plots' `y` extents are all inside -6..24 and the hall's inside -2..40,
   but several parts write NEGATIVE y (the skirts, the channel invert). The
   plot projection has to carry them.
