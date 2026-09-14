# WP13: the settlement building library, and Hearthpine rebuilt on it

Status: implementation candidate, 2026-09-14. Third Hearthpine increment.
Classification: non-trivial (new shared architecture code, raw node
semantics, test gates). WP13 remains in progress.

Contract: [wp13-settlement-pipeline.md](wp13-settlement-pipeline.md)
(section 2 decision, section 3 module layout, section 4 palette roles,
section 5 invariants, section 6 increment 3, section 7 verification).
Decided appearance: [settlements.md](../design/settlements.md). The previous
increment is [wp13-hearthpine-polish.md](wp13-hearthpine-polish.md).

## What this increment delivers

`mods/MAPGEN/grug_mapgen/wp13/` is the reusable library of contract section
3. Plain Lua 5.1, pure functions, no engine calls at construction time, no
globals; every file returns a table or a constructor and is loaded with the
`dofile(<directory>/<file>)` pattern the WP40 runtime already uses.

| File | Owns |
| --- | --- |
| `palette.lua` | role vocabulary, race palettes, validation |
| `parts.lua` | cell buffer (`put`/`fill`/`clear`/`box`/`hollow_box`/`ring`), rotation of cells, points and param2, and the primitive parts (door, pane, bed, torch, stair, seat, table) |
| `roofs.lua` | gable, hip, saltbox, lean-to and flat height fields, their union, and one rasteriser that turns any height field into stair, outer stair, inner stair and slab cells |
| `buildings.lua` | `build` plus the named generators `cottage`, `workshop`, `hall`, `longhouse`, `shed`, `watchpost` |
| `interiors.lua` | furnishing kits `home`, `workshop`, `smithy`, `store`, `hall`, `watch`, `yard` |
| `dressing.lua` | fences, low walls, timber stacks, benches, planters, lamp posts, crates, well, market stall, paving inlay, pines, undergrowth |
| `layout.lua` | pad ground, paving, path routing, street lighting, planting |
| `hearthpine.lua` | the Hearthpine composition |

`wp40/r7_hearthpine_blueprint.lua` keeps its file name and is now a thin
wrapper. It derives the library directory from its own chunk source
(`debug.getinfo(1, "S").source`, which the engine sandbox whitelists) and
falls back to `core.get_modpath` if the debug library is unavailable, so the
same file works under `r7_runtime.lua`, `tools/wp13/dump_blueprint.lua`,
`tools/wp13/blueprint_kat.lua` and `tools/wp13/engine_cases.lua`. The schema
string, the bounds contract (x/z `[-63, 63]`, y `[-2, 24]`), every landmark
key, every destination id and the canonical z/y/x cell order are unchanged;
`landmarks.doors` and `landmarks.rooms` are added for the new invariants.

## Raw node semantics

WP13 writes nodes straight into the map through VoxelManip, with no
`on_place` and no construct callbacks, so every part must emit exactly what
the engine's own placement would leave behind. These were read off the
vendored mods, not guessed:

- **Doors** (`mods/BASE/doors/init.lua`): the leaf at the foot is
  `doors:door_wood_a` with `param2 = dir`, where `dir` is the facedir of the
  direction the placer looked, that is inward; the mesh puts the leaf on the
  outward face. Above it sits `doors:hidden` with `param2 = dir`. A right
  hinged twin is `_b` with its hidden node at `(dir + 3) % 4`, placed where
  `on_place` looks for a neighbouring door. `doors.door_toggle` explicitly
  repairs the missing `state` meta of an lvm-placed right-hinged door, so
  raw placement is a supported case.
- **Panes** (`mods/BASE/xpanes/init.lua`): `update_pane` settles a pane with
  two opposite connections on the flat node, `param2 0` for a wall running
  along X and `3` for one running along Z. `xpanes:pane_flat` is a fixed
  nodebox, so it renders correctly with no update callback; the connected
  `xpanes:pane` variant is only what three and four way junctions become.
  Rotating a part therefore also canonicalises `1` back to `3` and `2` to
  `0`, which are the same plate seen from the other side.
- **Beds** (`mods/BASE/beds/api.lua`): foot node carries the facedir, head
  node sits one step along `facedir_to_dir` and repeats it.
- **Walls** (`mods/BASE/walls/init.lua`): `walls:cobble` is a connected
  nodebox evaluated from its neighbours at render time; no param2, no
  callback.
- **Torches**: wallmounted `param2` points from the torch to its support.
- **Stairs**: the raised half of a stair points at `facedir_to_dir(param2)`;
  an outer stair raises one quarter, an inner stair all but one.
- A facedir node shows its front tile on the face **opposite**
  `facedir_to_dir(param2)`, which is what chests, bookshelves, shelves and
  furnaces are oriented by.

## Roofs

A roof is a height field over the building footprint grown by the eave
overhang. The lowest course sits level with the top wall course and one node
inward is one node higher, so the wall always meets the roof with no gap.
The rasteriser decides per column which of the four quarters of the node are
raised (a quarter is raised when either flanking neighbour or the diagonal
is higher): one raised quarter is an outer corner, two adjacent a straight
stair, three an inner corner, zero a slab ridge. The same rule serves every
roof form, and the union of two height fields produces real valleys, which
is how the cross gabled forge hall gets its inner corner stairs.

The height field also drives the walls: every perimeter column is built up
to one node below the roof above it. Gable ends therefore close themselves,
and a saltbox gets its taller rear wall without a special case. A `rise`
clip keeps a wide building from carrying a roof taller than its walls.

## Hearthpine

Nine plots on the same pad, arranged around the arrival plaza and a paved
cross street, in a pine wood clearing:

| Landmark | Generator | Footprint | Roof |
| --- | --- | --- | --- |
| `forge_hall` | `workshop` | 16 x 15 (hall 11 x 15 plus a 7 x 7 smithy wing) | cross gable |
| `west_home` | `cottage` | 9 x 9 | gable |
| `east_home` | `cottage` | 9 x 11 placed | hip |
| `southwest_home` | `cottage` | 9 x 9 | saltbox |
| `east_gable_home` | `cottage` | 11 x 9 | gable |
| `lagerhouse` | `longhouse` | 9 x 13 | saltbox |
| `community_hall` | `hall` | 13 x 15 | hip |
| `workyard` | `shed` | 13 x 9, open on two sides | gable |
| `gatewatch` | `watchpost` | 9 x 9, guard room plus lookout | hip |

Every closed building has a door on its path side, two-wide pane windows in
log frames, a stone base course, log corner posts, a stair roof with a one
node overhang, a chimney where there is a hearth, a furnished interior and
at least one interior light. Exterior dressing fills the space between
plots; the arrival plaza has an inlaid paving band, a draw well, a market
stall, benches and planters. Warm lamps line the street and the cross
street.

## Verification

Per `luanti-lua.md`: `tools/bin/luac51 -p` and the `SETGLOBAL` check on every
changed Lua file and on the whole `grug_*` and `tools` trees; all five source
sweeps including `tools/`; `tools/check_fresh_server.py`. LuaJIT owns
development; the frozen bytes get one PUC 5.1 pair.

- `tools/wp13/library_kat.lua` is new. It proves rotation by re-deriving
  orientation from direction vectors rather than from the index arithmetic
  under test: facedir and wallmounted rotation against `core.facedir_to_dir`,
  the upside-down family turning the other way, footprint rotation as a
  bijection, hip corner shapes, cross gable valleys, and a whole cottage
  stamped at all four rotations with an unchanged node census, doors that
  keep their hidden node pairing, torches that keep a solid support, bed
  halves that stay together and panes that stay in the plane of their wall.
  It also checks that no palette role names a node `grug_materials`
  curates away with `core.unregister_item`.
- `tools/wp13/blueprint_kat.lua` keeps every previous assertion and adds
  contract section 5 invariant 2 (door reachable, outside foot paved,
  inside foot standable, orientation matching the wall, hidden node
  present), invariant 4 (no interior column open to the sky), the
  lit-interior rule and a general "no gap under the eaves" check that
  replaces the previous hand-written guardpost assertion. Doors count as
  passable in the conservative walk.
- `tools/wp13/engine_cases.lua` is unchanged: it compares authored names and
  param2 after generation and after reload, and the new blueprint keeps the
  explicit air cell at local `(5, 2, 0)` its edit canary needs.
- `tools/wp13/integration_fixture.lua` is unchanged and still exercises the
  real successor clipping and replay.

## Evidence

`tools/wp13/evidence/20260914-hearthpine-library/`, including the rendered
review set the architecture was iterated on
(`renders/`: two opposite full views, an interior cutaway, a night view, one
zoom per generator and the plaza).

## User runtime test

Fresh dwarf world, seeds `531802985935182545` (Hearthpine y=25) and
`8675309` (y=16). Walk the plaza and the cross street, open the doors, look
at the furnished interiors, climb the watchpost stairs to the lookout,
follow the road out through the gate, set night and check the lit route,
then leave and reload.
