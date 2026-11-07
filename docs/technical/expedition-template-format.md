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

A source has `build()` returning a `Template` (`tools/expedition_templates/template.py`): `box`, `set`, `place`,
`encounter`. The tool refuses a template without the required places, a waystone place holding no waystone, an arrival
without floor or head room, an unknown node, or an open cell on the template's outer shell.

## The file

A text head, then one zlib stream. Coordinates are box-relative cells from the box's lowest corner.

```
grudgelands-expedition-template 1
name test_vault
size 48 32 48
node default:stonebrick
node air
place arrival 8 5 8
place start_waystone 8 5 6
encounter hall grug_mobs:giant_spider 2 normal 30 5 12
data 342
<342 bytes>
```

- `size`: multiples of 16, at most the box (128 64 128). A smaller template sits in the box's lowest corner; the
  clearing pass's solid stone fills the rest. The format is 3D; several floors need nothing new.
- `node`: the palette, at most 256 lines, in byte order from 0.
- `place <name> x y z`: a named cell. `arrival` (the cell a player stands in, the start waystone beside it),
  `start_waystone` and `end_waystone` are required; `chest`, `door` and any other name are for the lanes that read them
  through `grug_expeditions.places(run)`.
- `encounter <room> <mob> <count> <tier> x y z`: one marker, in file order, the cell a mob stands in; markers with one
  `room` spawn together. `tier` is `normal`, `elite` or `boss`: at most one `boss`, count 1, an elite with the run's
  ledger (its HP from its definition's `_grug_hp_scale`, never the flat `boss` tier). An unknown mob or tier stops the
  server at load.
- The reward room's nodes are in the template: `grug_expeditions:reward_door` fills the opening, every such node within
  8 cells of the `door` place goes when the boss dies; `grug_expeditions:reward_chest` stands on the `chest` place. An
  Expedition's chest contents live in `grug_expeditions/loot.lua`, by catalogue id.
- `data <bytes>`: the length of the stream that follows the line. The stream unpacks to `sx * sy * sz` palette bytes in
  VoxelManip order (`z * sy * sx + y * sx + x + 1`), then as many param2 bytes.

The file holds no node meta, no timers and no light: VoxelManip writes neither of the first two, listeners of
`register_on_ready` set theirs, and the engine computes the light on write.

Why packed: a single `.mts` would have to be walked whole for each mapblock, and `.mts` per column makes 64 files per
template. One stream unpacked at load costs one reader of about 40 lines and two bytes per node in memory.
