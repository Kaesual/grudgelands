# Expedition template format

Round 71 (lane FRAME). An Expedition template is one repository file that fills a slot's box. The game reads it once
at load (`mods/PLAYER/grug_expeditions/template.lua`); a malformed file or an unknown node stops the server at load,
never in a preparation. Slots, box and step size: `grug_expeditions/catalogue.lua`.

## Files

| What | Where |
|---|---|
| Templates, written by the tool | `mods/PLAYER/grug_expeditions/templates/<name>.exp` |
| Their sources (edit these) | `tools/expedition_templates/sources/<name>.py` |
| The tool | `tools/expedition_templates/build.py` (`--check`: every file matches its source) |
| The walk grid (Round 74) | written by `tools/expedition_templates/walkgrid.py`, read by `grug_expeditions/walkgrid.lua` |

A source has `build()` returning a `Template` (`tools/expedition_templates/template.py`): `box`, `set`, `dig`, `place`,
`encounter`, `trap_floor`, `trap_wall`, and since Round 73 `ambush` and `particles` (their signatures at the top of
`template.py`). The tool refuses a template without the required places, a waystone place holding no waystone, an arrival
without floor or head room, an unknown node, an open or diggable cell on the template's outer shell, or a `dig` node
that is not solid.

## The file

A text head, then one zlib stream, then (Round 74) the walk grid: a `grid <bytes>` line and a second zlib
stream. Coordinates are box-relative cells from the box's lowest corner.

```
grudgelands-expedition-template 1
name test_vault
size 48 32 48
node default:stonebrick
node air
dig default:stone_with_tin
place arrival 8 5 8
place start_waystone 8 5 6
encounter hall grug_mobs:giant_spider 2 normal 30 5 12
trap f1 1 floor 8 5 30
trap w1 1 wall 3.6 5.5 34 +x 4 0
ambush a1 1 drift 11 5 18 13 20
particles dust 5 5 5 14 9 14 24
data 342
<342 bytes>grid 577
<577 bytes>
```

- `size`: multiples of 16, at most the box (128 64 128). A smaller template sits in the box's lowest corner; the
  clearing pass's solid stone fills the rest. The format is 3D; several floors need nothing new.
- `node`: the palette, at most 256 lines, in byte order from 0.
- `dig <node>`: a palette node meant to be dug. Every cell of it can be dug in a running Expedition by a player who
  belongs to it, through the ordinary mining path; everything else in the box stays refused for everyone
  (`grug_expeditions/guard.lua`). The mark is by node, so a template keeps its diggable nodes out of its walls.
  Ore and gem are written as T2's (`catalogue.TEMPLATE_ORE`, `TEMPLATE_GEM`): a run of another tier writes its tier's
  nodes in their cells and marks those instead (`catalogue.TIERS`, `template.resolve`'s variants, `written(run)`).
- `place <name> x y z`: a named cell. `arrival` (the cell a player stands in, the start waystone beside it),
  `start_waystone` and `end_waystone` are required; `chest`, `door` and any other name are for the lanes that read them
  through `grug_expeditions.places(run)`.
- `encounter <room> <mob> <count> <tier> x y z`: one marker, in file order, the cell a mob stands in; markers with one
  `room` spawn together. `tier` is `normal`, `elite`, `boss` or (Round 73) `critter`: at most one `boss`, count 1, an
  elite with the run's ledger (its HP from its definition's `_grug_hp_scale`, never the flat `boss` tier). A `critter`
  marker names one of `grug_mobs:cave_bat`, `grug_mobs:cave_crawler`, `grug_mobs:bone_weevil`; its room holds critters
  only and is no pack ([rules](../design/expeditions.md#8-mobs-and-packs)). An unknown mob or tier, or a critter off
  that roster, stops the server at load.
- `trap <group> <pick> floor x y z` and `trap <group> <pick> wall x y z <axis> <period> <offset>` (Round 72): one
  trap candidate ([rules](../design/expeditions.md#traps), `grug_expeditions/traps.lua`). A run arms `pick` of each
  group's lines, at random when it is ready. A floor line names the cell a player stands in over the trap: air (its mark
  goes there, so no torch, plant or carpet), on a walkable floor. A wall line names the muzzle point in node coordinates, whole numbers being node centres and
  decimals allowed (`43 8.5 15.6`: just inside the open cell in front of the wall); `axis` is `+x`, `-x`, `+z` or
  `-z`, the fireball's direction; the first shot comes `offset` seconds after readiness, then one every `period`
  seconds. A group's lines agree on kind, pick, period and offset, and pick at most as many as they are. The source
  calls `t.trap_floor(group, pick, x, y, z)` and `t.trap_wall(group, pick, x, y, z, axis, period, offset)`; the
  tool refuses a pick that is not a whole number of at least 1, a period not above 0, a negative offset, a floor
  cell that is not air on a floor (the reader refuses a floor cell that is not air too), and a muzzle where a cell the ball touches (radius 0.4, so
  a point at y 8.5 reaches the rows 8 and 9) is walkable at the muzzle or one cell ahead. In flight, every walkable
  node the ball touches stops it.
- `ambush <group> <pick> <room> x0 y z0 x1 z1` (Round 73): one ambush candidate
  ([rules](../design/expeditions.md#traps)). The zone is every cell from (x0, y, z0) to (x1, y, z1), both corners
  included, in either order; `y` is the feet's row, the first air over the floor. Feet from half a node below to 3
  nodes above that floor are in the zone (`traps.lua` `AMBUSH_ABOVE`), so no other floor runs over a zone that low. `room` names its markers: the
  `encounter` lines of that room, `normal` only and melee only (no mob whose `attack_type` is `shoot` or `dogshoot`),
  never placed by proximity; one ambush per room, and the room must have markers. Ambush and trap groups share one
  name space: a group is all `trap` or all `ambush` lines, and its lines agree on `pick` (at most as many as they are).
  A run arms `pick` of the group's candidates when it is ready, with the traps. The source calls
  `t.ambush(group, pick, room, x0, y, z0, x1, z1)`.
- `particles <style> x0 y0 z0 x1 y1 z1 <amount>` (Round 73): one particle spawner in the box between two corners,
  both included. `style` is one of `drip`, `dust`, `ash`, `paper`, `ember`, `spark` (`template.PARTICLE_STYLES`,
  drawn by `grug_expeditions/particles.lua`); `amount`, a whole number of at least 1, is the most live particles the
  spawner keeps. A template's amounts add up to at most 300 (`template.PARTICLE_BUDGET`, `template.py`'s
  `PARTICLE_BUDGET`). The source calls `t.particles(style, x0, y0, z0, x1, y1, z1, amount)`.
- The reader (`template.lua`) refuses a malformed `ambush` or `particles` line, an unknown style, a group that
  mixes kinds or disagrees on `pick`, an ambush room with another tier or without markers, two ambushes naming one
  room, a room mixing critters with a pack, and particles over the budget, at load; `check_fits` refuses a zone or a
  box outside the template. `template.py`'s writers and `problems()` refuse the same at build, and a tier it does not
  know.
- The reward room's nodes are in the template: `grug_expeditions:reward_door` fills the opening, every such node within
  8 cells of the `door` place goes when the boss dies; `grug_expeditions:reward_chest` stands on the `chest` place. An
  Expedition's chest contents live in `grug_expeditions/loot.lua`, by catalogue id.
- `data <bytes>`: the length of the stream that follows the line. The stream unpacks to `sx * sy * sz` palette bytes in
  VoxelManip order (`z * sy * sx + y * sx + x + 1`), then as many param2 bytes.
- `grid <bytes>` (Round 74), right after the cells' stream (no newline between): the length of the walk grid's
  stream, which unpacks to four planes of `sx * sz` bytes, one per column in the order `z * sx + x + 1`. The game's
  reader keeps it packed (`template.lua` `parse`: `tpl.grid`, nil without the section; `load` refuses a shipped
  template without it, and `parse` refuses bytes after the cells that are no grid section, or a grid cut short or
  of another size). The planes:
  - **height**: the feet row of the column's one walking cell, 255 for none. The walking cells are the shared proof's
    height map (`proofs.lua` `map`): what a player walks to from the arrival, the reward door read open and the
    diggable ore read **solid** (a dug cell only offers a shortcut the grid ignores); one per column, the proof's
    `surface` rule.
  - **mask**: the moves a mob makes from the cell, bit `k - 1` for move `k` of `+x, -x, +z, -z, +x+z, +x-z, -x+z,
    -x-z`. A straight move goes to a neighbour's walking cell at most one node up or down, with the body's two rows
    free over both columns at the higher level (every Expedition mob has stepheight 1.1, and a physics box at most
    1.95 high: the engine steps it up any box within that, `collision.cpp` `collisionMoveSimple`'s `step_up`). A
    diagonal move needs both straight neighbours as moves from the cell and each of them a move to the diagonal cell:
    no corner is cut. A player's level leap over open columns (The Last Mint's lake) is no mob move.
  - **clearance**: the Chebyshev distance (at most 6) to the nearest column a body standing on the cell would hit:
    one solid in the body's two rows, or a floor two or more nodes higher. Open air beside the floor (a pit, the
    lake) is no wall.
  - **flags**: bit 0 a door cell (a reward door node in its body rows; passable only while the door is open, read
    live at the `door` place); bits 1 to 4 a free 2 x 2 block the cell is a corner of, towards `+x+z`, `+x-z`,
    `-x+z`, `-x-z`.

  A body's class follows its width (the larger side of its collision box): up to one node any walking cell, up to two
  a cell of a free 2 x 2 block (it steers at the block's middle), wider a cell whose clearance is at least
  `ceil(width / 2 - 0.5) + 1`. `build.py` refuses a grid off the height map it re-derives, a move without its way
  back or with a step over one, a diagonal that cuts a corner, an encounter or an ambush zone cell off the grid, a
  place with no walking cell in or beside it, and a room whose markers lie in two walk components; `--check` compares
  the unpacked grid too. `tools/r74_nav/portable_test.lua` derives every plane again from `proofs.lua`'s map of the
  written file.

The file holds no node meta, no timers and no light: VoxelManip writes neither of the first two, listeners of
`register_on_ready` set theirs, and the engine computes the light on write.

## Authoring helpers (Round 73)

Lane TOOLS's helpers in `tools/expedition_templates/`, each with a usage note at its top; the sources call them, the
format above is unchanged by them.

- **The floor is a height map** `{(x, z): h}`, `h` the first air row of a column (a player's feet). One map for the
  whole floor, rooms and passages merged (`relief.merge` refuses a column with two heights).
- **Stairs** (`relief.py`, the only writer of floor stairs): where a cell is higher than a neighbour (all eight count)
  its floor node at `h - 1` is a stair of an existing set (`stairs:stair_<m>`, `stair_inner_<m>`, `stair_outer_<m>`,
  upright, param2 0 to 3), shape and param2 derived from which of its four quarters touch a lower neighbour: two
  adjacent low quarters a normal stair, one an inner, three an outer. Facedir p turns the node box's +z to +x
  (`mapnode.cpp` `transformNodeBox`), so a normal stair's low side is -z at 0, -x at 1, +z at 2 and +x at 3. The helper
  refuses a step of two, a ridge or trench one node wide, a peak or diagonal ridge no stair fits, a trap cell or its
  neighbours not flat, a floor node below row 2, and a material with no stair set.
- `passages.py`: polylines with a width profile (`s` 0 to 1 by length), niches, stair runs, mouths. `light.py`:
  sources at authored points and a seeded spread with a minimum spacing, the engine's light (`levels`). `dressing.py`:
  clusters by a seeded per-cell roll; nothing walkable, harvestable or a cobweb on a walking cell. `hazards.py`: the
  lava fall written whole (the source behind a lip, the falling column at param2 15, the basin's sources two rows under
  the feet with the floor's row flowing at the levels the engine settles on), ambush alcoves sized for their mob, the
  ambush's line and its `normal` markers through `t.ambush` and `t.encounter` (`hazards.ambush`), a dark check.
  `registry.py`: the node facts these need (walkable, light level, the 31 stair sets) from
  `tools/building_templates/nodes.json`.
- **Uneven by default:** `relief.vary(cells, base, features)` with `relief.pit`, `rise` and `terrace` gives seeded
  irregular outlines and a gentle and a steep side (`gentle=False` for an even feature); kept cells (passage mouths,
  traps) stay at the base, and the map is repaired where features meet. A flat room is a choice: `relief.flat`.
- **Previews:** `preview.py` (Pillow) draws the written files, never a source: a plan of the relief (height shading,
  stairs dark on their low side) and of the light at eye height (0, below 4, 4 and up), ambush zones, lava, critters
  and particle boxes; per room a sheet with both plans and two sections (`ROOMS`, one entry per Expedition); a sheet
  across every stair run. `--name`, `--file`, `--out` (default the uncommitted `style-previews/`).
- **The proof** (`proofs.lua`) reads the written file, never a source: the floor is what a player walks to from the
  arrival (a step level or down, up only onto a stair, a level leap over one or two open columns), light and sight see
  the nodes as written (the door shut). Rules by id (`P.RULES`); a fixture's `report` set turns a rule's failures into
  report lines for a template not yet built for it. The ambush rule reads the `ambush` lines: each zone on flat floor,
  cutting the walk from the arrival to the end (no leap over it), at light 0 with its markers and two nodes round it,
  never the first fight (taken out every pack room's fighting floor, no walk from the arrival reaches it), its markers
  `normal`, melee and on the zone's floor with head room, out of every pack's notice and room and of the start
  waystone's sight, no trap in its dark stretch; the floor within two nodes of its markers needs no light in sight. The
  particles rule: the `particles` lines' amounts within 300, each box holding air.

Why packed: a single `.mts` would have to be walked whole for each mapblock, and `.mts` per column makes 64 files per
template. One stream unpacked at load costs one reader of about 40 lines and two bytes per node in memory.
