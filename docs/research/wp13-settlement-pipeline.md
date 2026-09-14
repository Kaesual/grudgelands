# WP13: settlement authoring pipeline

Status: draft contract, 2026-09-14. Coordinator: Claude Fable (user ruling of
the same day; see `agent-model-policy.md` "Day-to-day routing rule").
Implementation lanes: Claude Opus. This note is the working contract for the
third Hearthpine increment and for every later start, capital and camp. It
becomes design once the user accepts the first rendered result; until then
`docs/design/settlements.md` stays the decided appearance.

## 1. Why the current buildings look plain

The user's verdict after the nine-building playtest: acceptable, but less
attractive than VoxeLibre's villages. Decoding the twelve VoxeLibre
`mcl_villages` schematics (CC BY-SA 4.0, MysticTempest; read-only reference
at `reference_projects/VoxeLibre/mods/MAPGEN/mcl_villages/schematics`) shows
why. Their houses are small and dense; ours are large and hollow.

| Measure | VoxeLibre small/medium house | Hearthpine west home |
|---|---|---|
| Footprint | 9 × 8 / 9 × 12 | 13 × 16 (walls 11 × 14) |
| Non-air nodes | 206 / 356 | roughly 1,000 |
| Distinct node kinds | 17 / 24 | 8 |
| Roof | stair nodes with outer/inner corners, slab ridge | stepped full wood blocks |
| Windows | `xpanes` panes framed by logs | single glass blocks |
| Door | two-node wooden door | open gap |
| Interior | bed, loom, crafting table, barrel, flower pots, chest | one fence-and-slab table |
| Wall material mix | cobble base, planks, log posts, carved stone accents | stone brick base, planks, log posts |

Detail density, human scale and real building parts (doors, panes, stair
roofs, furniture) are the difference. None of that needs a new authoring
method; it needs better parts and a smaller module.

## 2. Decision: a Lua building library, not hand-built `.mts`

- Buildings stay deterministic Lua that produces the existing cell list
  (`{x, y, z, name, param2}`, canonical z/y/x order, sorted palette). The
  R7 successor, the manifest identity, the clipping, the reload behaviour and
  the acceptance fixtures of the first two increments remain unchanged.
- No in-game building: `game.conf` disables creative mode, nobody wants to
  hand-place six capitals, and a schematic cannot be diffed or reviewed. If
  a later increment wants to import an external `.mts` (for example a
  licence-cleared decoration), it is converted to cells through the same
  library and reviewed the same way.
- The review loop is the new textured isometric renderer
  (`tools/wp13/render_blueprint.py`, in progress): every building generator
  is rendered from two views plus an interior cutaway and a night view. The
  coordinator judges the pictures, then the user judges the world. Iteration
  happens on the pictures, which are cheap, not on playtests, which are not.
- Every generator takes a **palette** (role → node name) so one generator
  serves six races. Race identity comes from palette, roof form and a few
  race-only parts, not from six separate code bases.

## 3. Module layout

New directory `mods/MAPGEN/grug_mapgen/wp13/`, loaded by `r7_runtime.lua`
next to the existing blueprint factory. Plain Lua 5.1, no engine calls at
construction time, no globals.

| File | Owns |
|---|---|
| `palette.lua` | role vocabulary, six race palettes, validation (every role bound, every name a string) |
| `parts.lua` | the cell writer (`put`, `fill`, `clear`, `box`, `hollow_box`), rotation of cells and param2 (facedir 4 horizontal orientations, wallmounted torches, door halves), placement of a part at an origin with a rotation |
| `roofs.lua` | gable, hip, saltbox, lean-to and flat roofs from stair/outer/inner/slab roles, with overhang and ridge options; watertightness is a generator invariant |
| `buildings.lua` | parametric generators returning cells plus landmarks: `cottage`, `longhouse`, `workshop`, `hall`, `watchpost`, `shed`, `well`, `stall`, `shrine`. Parameters: width, depth, storeys, roof form, porch side, door side, window rhythm, interior kit |
| `interiors.lua` | furnishing kits placed inside a cleared room: bed corner, hearth, table and seats, shelves, storage, workbench, lamp positions |
| `dressing.lua` | exterior props: fences, low walls, wood piles, crates, planters, path lights, benches, well, signposts |
| `layout.lua` | plot placement on the pad, road and plaza, paths from every door to the road, light spacing, ground and planting |
| `hearthpine.lua` | the Hearthpine composition using the above; replaces the hand-written body of `r7_hearthpine_blueprint.lua`, which becomes a thin wrapper that returns the same schema |

`r7_hearthpine_blueprint.lua` keeps its file name, schema string, bounds
contract (x/z [-63, 63], y [-2, 24]), landmark keys and destination ids so the
existing KAT, engine cases and manifest wiring stay valid. Only the cells and
the palette change.

## 4. Palette roles

Every generator addresses nodes only through roles. Minimum role set:

```
ground, ground_patch, path, plaza, plaza_edge
foundation, wall, wall_accent, post, beam, floor, ceiling
roof_stair, roof_stair_outer, roof_stair_inner, roof_slab, roof_ridge
window, window_frame, door (registered door base name), shutter (optional)
fence, fence_gate (optional), low_wall, railing
light_wall, light_post, light_indoor
bed, table_top, seat, shelf, storage, workbench, hearth, chimney
planter, crop (optional), tree_log, tree_leaves, undergrowth
```

Draft race palettes from nodes that exist today plus the seven mods being
vendored from minetest_game (doors, xpanes, beds, wool, dye, vessels, walls).
Nodes from the ContentDB kit under audit (castle_*, xdecor-libre, cottages,
darkage) are added as optional roles after their licences are confirmed; a
generator must degrade gracefully when an optional role is nil.

| Role | Dwarf (Hearthpine) | Human (Dawnmere) | Elf | Undead | Orc | Troll |
|---|---|---|---|---|---|---|
| foundation | `default:stone_block` | `default:cobble` | `grug_decor:darkage_marble_tile` | `default:obsidianbrick` or dark stone | `default:desert_stone_block` | `default:mossycobble` |
| wall | `default:pine_wood` | `default:wood` | `grug_trees:silverwood_wood` | `grug_trees:gravewood_wood` | `default:desert_sandstone_brick` (adobe) | `default:junglewood` |
| wall_accent | `default:stonebrick` | `default:brick` | `grug_decor:darkage_slate_brick` | `default:stonebrick` | `default:desert_stonebrick` | `default:sandstone_block` |
| post | `default:pine_tree` | `default:tree` | `grug_trees:silverwood_tree` | `grug_trees:gravewood_tree` | `default:acacia_tree` | `default:jungletree` |
| roof_stair family | `stairs:stair_pine_wood` (+outer/inner) | `stairs:stair_wood` | `grug_decor:darkage_slate_tile_stair` domestic, `stairs:stair_silver_sandstone_brick` civic | `stairs:stair_stonebrick` | `stairs:stair_desert_stonebrick` | `stairs:stair_junglewood` |
| window | `xpanes:pane_flat` | `xpanes:pane_flat` | `xpanes:pane_flat` | `xpanes:bar_flat` | `xpanes:bar_flat` | open, `default:fence_junglewood` |
| door | `doors:door_wood` | `doors:door_wood` | `doors:door_wood` | `doors:door_steel` | `doors:door_wood` | `doors:door_wood` |
| light_wall / post | `default:torch_wall` / `default:torch` | same | `grug_decor:xdecor_candle`, plus `grug_decor:xdecor_lantern_hanging` and `grug_materials:emberglass_lamp` as optional roles | `default:torch` (few) | `default:torch` | `default:torch` |
| fence / low_wall | `default:fence_pine_wood` / `walls:cobble` | `default:fence_wood` / `walls:cobble` | `default:fence_aspen_wood` / `grug_decor:darkage_serpentine_slab` | `walls:mossycobble` | `walls:desertcobble` | `default:fence_junglewood` |

All names above exist in the vendored `default`/`stairs` mods (every
`register_stair_and_slab` material also has `stair_outer`/`stair_inner`
shapes) or in the seven mods being vendored. Silverwood and gravewood
stair/slab shapes do not exist yet; registering them in `grug_trees` is a
small follow-up, not a design question.

**The elf column was corrected on 2026-09-14 to the palette that shipped.**
Four of its six entries had been drafted before the kit was in the tree and
the registry refused them:

- the roofs. `grug_trees` registers no stair or slab shape, so silverwood
  cannot roof anything, and silverwood plank, silver sandstone and silver
  litter all sit between luminance 187 and 202 -- a settlement built only out
  of them is invisible against its own ground, which is what the first review
  render showed. The DOMESTIC roof is therefore darkage slate tile (#6d818d)
  and the drafted `stairs:*_silver_sandstone_brick` family became the CIVIC
  roof, where the pale cut reads against slate instead of against litter.
  The drafted `stairs:stair_silver_sandstone` (not `_brick`) survives only as
  the table-top slab.
- the windows. `default:glass` is a cube, not a pane, and the whole window
  vocabulary of this library -- framing, rhythm, `update_pane` -- is the
  `xpanes` one. Ordinary windows are clear flat panes in silverwood frames;
  glass cubes appear only as gable lights.
- the low wall. `walls:` ships nothing pale, so it is a serpentine slab: a
  marble kerb rather than a rubble parapet.
- the lights. `grug_materials:emberglass_lamp` is a full glowing cube and
  cannot be the wallmounted `light_wall`/`light_post` the parts write. The
  required trio is the candle; the lamp and the hanging lantern are the two
  optional roles `light_beacon` and `light_hanging`, which
  `parts.beacon` and `parts.hanging_light` are the only emitters of.

The fence entry was `default:fence_wood`; aspen is the pale one, and
silverwood IS default's aspen retinted, so the fence and the plank agree.

## 5. Generator invariants (checked by the KAT, not by eye)

1. Cells unique and canonical; palette sorted; bounds inside the authorized
   volume; no spawner nodes (`camp_fire`, `guard_banner`), no liquids.
2. Every building has at least one door cell; the door's outside foot is on
   a path or plaza cell; the inside foot is standable; the door orientation
   matches the wall it sits in.
3. Every interior destination is reachable from spawn by the conservative
   walk (existing check) with doors treated as passable.
4. Roof watertight: for every interior floor column there is a roof or
   ceiling cell above the highest wall cell, and no interior column is open
   to the sky.
5. Every light cell has support in the direction its param2 requires
   (existing check), and every interior has at least one light.
6. Nothing below y = -2, nothing above y = 24, spawn support and clearance
   as before; the five-wide north road stays clear.
7. Blueprint size stays under 125,000 cells.

## 6. Increments from here

- **Increment 3 (today): library plus Hearthpine rebuilt.** Deliver
  §3 modules, the dwarf palette, the rebuilt Hearthpine composition with
  doors, pane windows, stair roofs, furnished interiors and exterior
  dressing, rendered evidence (day, cutaway, night) and the updated KAT.
  The user playtests the same seeds as before.
- **Increment 4: second start (Dawnmere Fields, human).** Proves that a
  palette plus roof-form change yields a different-looking village from the
  same generators. Ground fitting reuses the shared start-pad rule.
- **Increment 5: remaining four starts**, one palette each, plus race-only
  parts where the palette alone is not enough (elf platforms in trees,
  undead ruins and bone dressing, orc earthworks and palisades, troll stilts).
- **Later: capitals** on the 512 × 512 envelope with the 96 × 96 civic core,
  reusing the same generators at larger parameters plus a hall, walls,
  gates and the king's seat; the castle kit (if cleared) carries most of it.

Ambient atmosphere (shadows, bloom, saturation, waving; coloured fog and
weather later) is a separate `grug_core` package running in parallel and does
not change any settlement cell.

## 7. Verification budget

Per `luanti-lua.md`: `tools/bin/luac51 -p`, SETGLOBAL and the five sweeps on
changed Lua including `tools/`; LuaJIT for the KAT and renders; the existing
WP13 engine runner (two seeds, forward/reverse, cold/disk) once per increment
on frozen bytes; one final PUC/LuaJIT micro pair on those bytes. Renders are
evidence and are stored with the increment's evidence directory. No
intermediate PUC runs, no historical WP40 fleets. At most seven interpreter
processes workstation-wide.

## 8. Open for the user

- Accept or amend the draft race palettes in §4 (names are proposals).
- Whether the kit nodes cleared by the licence audit are vendored today or
  after the first rebuilt Hearthpine is accepted (recommendation: after, so
  the first comparison is like for like).
