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

A source has `build()` returning a `Template` (`tools/expedition_templates/template.py`): `box`, `set`, `dig`, `place`,
`encounter`, `trap_floor`, `trap_wall`. The tool refuses a template without the required places, a waystone place holding no waystone, an arrival
without floor or head room, an unknown node, an open or diggable cell on the template's outer shell, or a `dig` node
that is not solid.

## The file

A text head, then one zlib stream. Coordinates are box-relative cells from the box's lowest corner.

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
data 342
<342 bytes>
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
  `room` spawn together. `tier` is `normal`, `elite` or `boss`: at most one `boss`, count 1, an elite with the run's
  ledger (its HP from its definition's `_grug_hp_scale`, never the flat `boss` tier). An unknown mob or tier stops the
  server at load.
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
- The reward room's nodes are in the template: `grug_expeditions:reward_door` fills the opening, every such node within
  8 cells of the `door` place goes when the boss dies; `grug_expeditions:reward_chest` stands on the `chest` place. An
  Expedition's chest contents live in `grug_expeditions/loot.lua`, by catalogue id.
- `data <bytes>`: the length of the stream that follows the line. The stream unpacks to `sx * sy * sz` palette bytes in
  VoxelManip order (`z * sy * sx + y * sx + x + 1`), then as many param2 bytes.

The file holds no node meta, no timers and no light: VoxelManip writes neither of the first two, listeners of
`register_on_ready` set theirs, and the engine computes the light on write.

Why packed: a single `.mts` would have to be walked whole for each mapblock, and `.mts` per column makes 64 files per
template. One stream unpacked at load costs one reader of about 40 lines and two bytes per node in memory.
