# WP13: Silverleaf Glade, the third start (fifth increment)

Status: implemented 2026-09-14, awaiting independent review and the user's
GUI playtest. Classification: non-trivial (R7 roster and manifest seam, raw
node semantics, new palette, new library parts, test gates). WP13 remains in
progress.

## Why

[wp13-settlement-pipeline.md](wp13-settlement-pipeline.md) §6 makes the
remaining four starts one palette each, "plus race-only parts where the
palette alone is not enough". Silverleaf Glade
(`elandor_silverleaf_glades`, `anchor_003`, x = 1800, z = -2550) is the elf
start; [world_zones.md](../design/world_zones.md) §8.1 gives the zone as
"pale trees, clear streams and circular glades", §10 the elf material
signature as "silverwood, pale cliffs, lakes, canopy paths", and §12 the
elf terrace step. The zone's road exit is `start:north`
(`station:elandor_silverleaf_glades:start_north` at z = -2486), so the
contract's five-wide road leaves toward **+z**, as at the other two starts.

## Identity

A glade cut into the silverwood: light, vertical, and stone where the other
two starts are timber.

- A **moon court** of white marble around the spawn, kerbed in dark slate,
  with a seven-node crescent inlaid in the same dark stone, four glazed
  lantern pillars at its corners and four lantern standards on its edges.
- Two **avenues** leave it east and west, the five-wide road leaves north to
  a gate of slate piers under a silverwood lintel with an emberglass lamp on
  the crown, and a **gate lookout** stands beside it.
- A **moon shrine** north-west: a narrow nave under the one full-pitch gable
  in the glade, a spire on its ridge, reached along a **colonnade** of paired
  silverwood posts carrying a beam architrave with a lantern hung in every
  bay, and a forecourt in front of its doors.
- A **lore hall** north-east, a **bowyer's workshop** east (cross gable, wing
  and work tops), a **covered market** west (open on two sides, lanterns
  under its plates), and **four houses**: two on three-node marble terraces
  with railed fronts and a flight of steps down to the lane, two on the
  glade floor. Every house is 7 x 11 with a six-course wall under a steep
  gable and an emberglass lamp set into the gable above its door.
- **109 silverwood standards** on the decoded proportions of the vendored
  aspen (see below), thinning toward the settlement so the glade reads as a
  clearing, plus fern and pale grass on the litter, flower beds and planters
  in pale green serpentine kerbs, and silverwood railings along the lanes.
- No liquids, no spawner nodes, no NPCs, no metadata-bearing node.

## Part A: the elf palette

`palette.lua`'s elf column is contract §4's, with three corrections the
registry forced and one the first review render forced:

| Contract §4 | Here | Why |
| --- | --- | --- |
| roof `stairs:stair_silver_sandstone` | `grug_decor:darkage_slate_tile_*` for the houses, `stairs:*_silver_sandstone_brick` for shrine, lore hall and lookout | silverwood plank (191), silver sandstone (187-191) and silver litter (202) all sit inside fifteen luminance steps of each other; a settlement built only out of them is invisible against its own ground, which is exactly what the first render showed. The domestic roof is now blue-grey slate and the contract's pale cut marks the three civic buildings |
| window `default:glass` | `xpanes:pane_flat` (+ the connected `xpanes:pane` in the lantern pillars) | `default:glass` is a cube, not a pane; the library's whole window vocabulary -- framing, rhythm, `update_pane` -- is the `xpanes` one |
| fence/low wall `default:fence_wood` / none | `default:fence_aspen_wood`, low wall `grug_decor:darkage_serpentine_slab` | `grug_trees` registers no stair, slab or fence shape, and silverwood IS default's aspen retinted, so the pale aspen fence and the pale plank agree; `walls:` ships nothing pale |
| light `grug_materials:emberglass_lamp` | `grug_decor:xdecor_candle` as the wallmounted trio, `grug_decor:xdecor_lantern_hanging` and `grug_materials:emberglass_lamp` as two new OPTIONAL roles | the emberglass lamp has no paramtype2, so it cannot be what `parts.wall_torch` and `parts.floor_torch` write; it is now the gable and gate beacon, and the lantern is what hangs under a beam |

Two new optional roles, `light_hanging` and `light_beacon`, are declared in
`palette.lua` and emitted only by `parts.hanging_light` and `parts.beacon`.
The hanging lamp is in `group:attached_node = 4` -- "always attached to the
node above" (lua_api.md) -- so its emitter refuses any support but an opaque
full cube overhead; the beacon is a full cube that carries itself.

## Part B: new library code

All role-driven, all degrading when a palette lacks the optional role:

- `dressing.columnar` -- the silverwood standard, on the decoded proportions
  of `mods/BASE/default/schematics/aspen_tree.mts` (5 x 14 x 5: six clear
  trunk logs, then seven crown courses alternating a 3 x 3 ring and a full
  5 x 5 square, the top course one node above the last log). Silverwood IS
  that schematic with the aspen nodes replaced
  (`grug_trees.silverwood_replacements`), so an authored grove matches what
  the surrounding elf forest actually grows.
- `dressing.terrace` -- a masonry podium with a three-tread flight of steps
  up a named side, so a building stamped at `y = height` stands on it with
  its own apron and its doorstep on the podium.
- `dressing.lantern_pillar`, `dressing.lantern_post` -- the two elven lamps.
- `layout.glade` -- the pad ground, a third period and phase from `ground`
  and `meadow`; `layout.plant_grove` -- the columnar scatter, thinning
  toward the settlement.
- `parts.hanging_light`, `parts.beacon`; the `grug_decor:xdecor_candle`
  wallmounted entry and the six `grug_decor` shape entries in
  `parts.PARAM2_KIND` (grug_decor's `shapes.lua` is a vendored byte-for-byte
  copy of the four `stairs` shape registrations, so its facedir is theirs);
  the pane, solid and registry entries the new vocabulary needs.
- `buildings.chapel` takes `roof`, `ridge_axis` and `rise` from its spec
  instead of hard-wiring a hip.
- `tools/wp13/stub_registry.lua` loads `grug_trees` and `grug_nodes`, which
  the elf palette is the first to name; the stub's `read_schematic` answers a
  unit volume, which is all `grug_trees` reads of it.

Result: 68,712 cells, 50,408 of them not air, 48 materials, 113 lights, 1,349
oriented nodes, 9 reachable destinations, 11 doors, 10 rooms, 109 silverwood
standards, 24 stepping stones. Bounds x/z `[-63, 63]`, y `[-1, 20]`, inside
the authorized volume and well under the 125,000 cell budget.

## Verification

- `tools/bin/luac51 -p` and `SETGLOBAL [0]` on all twelve changed Lua files
  and tree-wide; the five plain-5.1 sweeps scoped and tree-wide;
  `tools/check_fresh_server.py` PASS. (`static.txt`)
- `library_kat` checks every race in `palettes.races` and runs its registry,
  pane and torch sections over every blueprint in the R7 roster;
  `blueprint_kat` runs the §5 invariants plus the exact prop populations over
  all three starts, with a per-start light-carrier rule for the elf lamps
  that are not wallmounted; `integration_fixture` drives all three successors
  over the real owner grid. Byte-identical under LuaJIT and `tools/bin/lua51`.
- **Hearthpine and Dawnmere are byte-identical.** Hearthpine's blueprint
  identity stays `e07ac54b…5100cf9ffb` (61,932 cells) and Dawnmere's
  `66c7f811…54354f74` (66,343 cells), and both `blueprint_kat` rows are
  unchanged in every field against `20260914-dawnmere-fixes`.
- Engine: headless Luanti 5.17.0, seeds `531802985935182545` and `8675309`,
  two fresh worlds with opposite owner orders each followed by a disk-only
  reload -- eight passes. See `tools/wp13/evidence/20260914-silverleaf/`.
- Final micro pair: LuaJIT and PUC 5.1.5 byte-identical.

## What the renders were changed for

1. The first pass built the whole settlement out of silverwood plank, silver
   sandstone and silver litter, as contract §4 proposes. At overview scale it
   was one pale mass: no building had an outline. The domestic roofs, the
   lanes and the court kerb moved to the darkage slate family, and the
   contract's pale sandstone cut became the civic roof.
2. The lanes were marble tile on silver litter, two luminance steps apart,
   and the plan of the settlement did not read at all. They are slate now and
   the court is the white marble.
3. The moon crescent was inlaid in pale green serpentine on white marble and
   simply was not visible. It is dark slate brick now, and half again as big.
4. The shrine carried the `chapel` generator's hip roof, which at 11 x 15
   clips into a broad flat deck and reads as a ziggurat. It is 9 x 15 under a
   full-pitch gable with the ridge along the approach, and the generator
   learned to take a roof form.
5. The grove was a regular lattice over the whole pad at density 4/7 and the
   undergrowth covered every third cell; the settlement was swallowed. The
   grove thins to 1/7 within 24 nodes of the spawn and the undergrowth is
   every fifth cell.
6. The court carried six lantern standards and four lantern pillars in
   27 x 18 nodes. Four and four.

## Scoped gaps

- `tools/wp40/r7/{micro_kat_fixture,manifest_constructor_kat,runtime_fixture}`
  were already red on this increment's base commit, for the reason recorded
  in the previous two increments' evidence, and were left untouched.
- `tools/wp13/node_tiles.json` has no entry for the nodes `grug_decor`
  registers from a loop (the darkage stones) nor for `grug_nodes`, because
  `extract_tiles.py` is a static scanner. The review renders were produced
  with a scratch copy of that file carrying the missing entries; the shipped
  one is untouched, so the other three start lanes merge without a conflict
  in it. Teaching `extract_tiles.py` the `grug_decor.register_shapes` loop is
  one small follow-up.
- `docs/design/settlements.md` is unchanged: it records decided appearance,
  and Silverleaf is not decided until the user has walked it.

## User runtime test

Fresh world, elf, seed `531802985935182545` (Silverleaf anchor x = 1800,
z = -2550, fitted y from the engine receipt):

1. Spawn on the moon court: walk the crescent, the four lantern pillars and
   the slate kerb, then look north up the road to the gate.
2. West along the avenue to the colonnade, under the lanterns to the shrine
   forecourt, in through the double doors: benches down the runner, the dais,
   then step back and look at the spire on the ridge.
3. East along the other avenue to the lore hall, then on to the bowyer's
   workshop and its wing.
4. South to the two terrace houses: climb the steps, walk the railed front,
   go in; then the two houses on the glade floor and the covered market on
   the west lane.
5. Out into the grove: check the silverwood proportions against the wild
   trees outside the pad, and that no railing or planter blocks a route.
6. Set night, follow the lit road court -> gate -> lookout, climb it, leave
   and reload.
