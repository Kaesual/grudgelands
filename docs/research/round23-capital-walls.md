# Round 23 Lane C — capital walls (receipt)

2026-09-28. Contract: [Round 23 plan](../planning/round23-world-life-plan.md),
Lane C. Branch `wp13-capital-walls` off `27703fc7`. Capitals only; start
towns, villages and POIs are untouched. Design result:
[settlements.md](../design/settlements.md) (civic-core boundary table, walled
capitals, the lake capital, the palisade), [world_zones.md](../design/world_zones.md)
§12 and [world.md](../design/world.md).

## What changed

| Capital | Change |
| --- | --- |
| Highcourt | The precinct hedge becomes a one-node castle-stonewall wall on exactly the hedge's 332 ring columns: stonewall y 1–2, the crown's marble band at y 3 (the band the four gatehouse piers carry at y 3, so it runs straight into them), a stonewall merlon at y 4 on every other column (the gatehouses' battlement rhythm). Four courses, one more than the hedge's three. Outer wall unchanged. |
| Dur Brannoc | Precinct parapet three courses instead of two; the capped merlon every fourth column moves up one (y 4 stone, y 5 cap). |
| Gor Drazhak | Precinct bank three courses (two of dug earth, the beaten crest at y 3) with the stake and point every other column at y 4–5. |
| Nhal Veyr | Bar course closed (below). Height unchanged. |
| Lethariel | Outer edge: the stone curtain model in a light elf style (below), with gatehouses and turrets. Core: the silverwood hedge becomes a one-node light wall — silver sandstone brick y 1–2, marble coping y 3 (the height of the pale gatehouses' marble band), a colonnette (pale castle pillar, base y 4 and top y 5) on every other column; the mere still replaces the boundary where it reaches the ring. |
| Kezamba | Outer edge: the orc palisade model in the troll core palisade's materials (below), with the palisade's own gate passages. Core unchanged (byte-identical blueprint). |

All six core blueprints keep their bounds (y −2..31); outside the ring
columns not one cell changed (cell diff before/after, all six cores).

### Style choices made by feel

- **Lethariel curtain** (`city_edge.lua` STYLES.elf.stone): face
  `default:silver_sandstone_brick` (the civic quarter's pale stone), core
  `default:silver_sandstone`, walk `darkage_marble_tile` with its slab, a green
  `darkage_serpentine` string course three under the walk, a marble coping on
  every parapet and tower top, colonnettes (`castle_pillar_silver_sandstone_brick`
  `_bottom` + `_top`) in place of every merlon, a marble lintel over each gate
  passage and a serpentine band round the gate towers at lintel height, marble
  slab caps on the passage parapet, an `emberglass_lamp` on the deck of every
  turret. Slim footprint: wall 5 wide, walk 6 above ground (7 elsewhere),
  turret radius 3 every ~48 nodes, gate boxes 7 × 11.
- **Kezamba palisade** (STYLES.troll.palisade): jungle-log stakes (`tree_log`),
  a `stairs:stair_outer_junglewood` point on **every** stake turned
  `(x + z) % 4` exactly like the core palisade, junglewood beams over the
  passage, junglewood walk and slab, a `default:dirt` rampart; timber deck on
  piles over the cenote.
- **Highcourt band**: marble (the crown's white, continuous with the gate
  piers) rather than the outer wall's brick; 1-on-1-off merlons to match the
  gatehouse battlements next to them.
- **Gor Drazhak**: the bank grew (not the stakes), so the section stays "bank
  with a stockade on its crest".

### Nhal Veyr: the gap cause and fix

Not pane connection. The bar course wrote a bar only where `(x + z) % 4 == 2`
and nothing at `% 4 == 1` and `3`, so each opening between two merlons was
air | bar | air: one node of air on each side of every bar. All 72 bars were
already `xpanes:bar_flat` with param2 0/3 along their wall side (engine
`update_pane` would settle on the same). Fix: all three columns between two
merlons carry the flat bar; `parts.resolve_panes` settles them to flat panes
along the wall (152 new, 0 connected-node variants, 0 empty course columns).

Found on the way: the corner drums/towers (5 × 5 at ±47) own the ring columns
at ±45, and the ring wrote there (Nhal Veyr bars and Gor Drazhak earth would
have cut 8 tower-wall cells each). `precinct_ring.is_corner` now skips from
±45; Gor Drazhak's four towers regain 16 wall cells they had lost before.

## Layouts unchanged

The new edge kinds `stone_narrow` / `palisade_narrow` (`capital_planner.lua`
M.EDGE) keep the planted belt's planner footprint (WALL_HALF 2, WALL_KEEP 6,
gate 3 × 5), so only the wall's own payload lines differ. Seed 4242, engine
layouts before (main) vs final:

- water and road sections (including every capital street and connector)
  byte-identical; capital lines `o`, `g`, `p`, `s`, `q` byte-identical;
- wall point positions, gap and wet flags identical for all six;
- Highcourt, Dur Brannoc, Gor Drazhak, Nhal Veyr: walk and turrets identical;
- Lethariel: kind, walk (667 points) and turrets (0 → 26) differ;
  Kezamba: kind, walk (642) and turrets (0 → 21) differ.

**Walk over water.** Both civic lakes lie across these outlines (Lethariel
111 + 37 wet points, Kezamba 84). The planner's three neighbour passes could
not lift the middle of such a crossing: the belt-era walk dipped to 21.5 over
the cenote whose surface is ~36. New rule: over water the walk stands at least
`WALL_CLEAR` above the surface (default 1, which changes nothing on the four
unchanged capitals; 5 for the narrow kinds). Engine profile: Lethariel
arcade — water surface 5 under the walk, one free course, arch masonry three
courses, piers to the bed; Kezamba — deck 5 above the water, piles to the bed
19 below the surface.

## Preparation and protection consistency

- Core walls reach y 5 at most; core bounds (from cells) unchanged.
- The overlay y range (`r7_capital_blueprint.lua`) now takes the depth below
  the lowest walk from the edge kind's `footing` (24 as before for stone and
  palisade; 28 for the narrow kinds, because a pile to the cenote bed under a
  walk 5 above the surface reaches 25–26). Top: turret colonnettes and lamps
  reach walk + 7, gatehouses gate floor + 13, inside the existing
  `+8` / gate `+9 +8`. Probe: every edge cell ≤ y_max.
- Protection outline is built from the unchanged wall line; the narrow gate
  boxes are smaller than `EDGE_REACH` assumes. No Lane A file touched.

## Evidence

- `luajit tools/wp13/capital_walls_probe.lua . <layouts>`: PASS. Core rings
  (courses, rhythm, height, bars flat, no empty bar column, nothing in a gate
  passage): Highcourt 332 columns/164 merlons, Dur Brannoc 304/80, Gor Drazhak
  304/152, Nhal Veyr 304/80, Lethariel 258/128 (74 mere), Kezamba 238 (94
  cenote). Edges on the final seed-4242 layouts (synthetic ground): names ⊆
  palette, heights ≤ y_max, gate passages clear, Lethariel 26 lamps for 26
  turrets and 872 colonnettes, Kezamba 2 726 points all turned by column.
- Old vs new `city_edge.lua` on Highcourt, Dur Brannoc, Gor Drazhak and Nhal
  Veyr (same layouts and terrain, roads on every 7th column): identical cells
  and node-name lists.
- Real gate passages (engine dumps): Lethariel south/east clear y 1–5 above
  the road, Kezamba south/east clear y 2–5 above the road at y 1, beams at 6.
- `tools/check_lua.sh` on all changed files: parser and sweeps 1–6 pass, no
  SETGLOBAL.
- Engine runs (`tools/luanti_headless.sh`, seed 4242, `chrt --idle`, one at a
  time): 1 baseline 240 s; 2 new code + disposable dump probe 290 s; 3 final
  code + probe 150 s. All PASS (listening, no ERROR); layouts built in ~20 s;
  capital planning 1.2–1.3 s each as before. The run-2 and run-3 dumps are
  byte-identical. No PUC run (mapgen exemption).

Images (`round23-capital-walls/`, `render_blueprint.py`; it draws the pillar
colonnettes as cubes, panes as grey slabs and `darkage_marble_tile_slab` as a
flat colour): `highcourt-core-wall`, `dur-brannoc-core-wall`,
`gor-drazhak-core-wall`, `nhal-veyr-core-bars-before`/`-after`,
`lethariel-core-wall`, `lethariel-edge-gate`, `lethariel-edge-lake-arcade`,
`lethariel-edge-turret`, `kezamba-edge-gate`, `kezamba-edge-lake-deck`,
`kezamba-edge-turret`. Core images are blueprint renders; edge images are real
terrain dumped from the engine.

## Runtime test plan (fresh world)

1. Highcourt: walk round the precinct; wall 4 high, marble band flush with the
   gate piers' band, merlons alternate; all four gate passages open.
2. Dur Brannoc and Gor Drazhak: precinct parapet/bank one node taller; the
   corner drums/towers have closed walls where the ring meets them.
3. Nhal Veyr: the bar course runs merlon to merlon with no air gaps; look at
   bars on the east/west sides too.
4. Lethariel: arrive by road; pale gatehouse with marble lintel, walk the
   curtain, colonnettes, turret lamps at night; the arcade across the crown
   lake (boat/swim underneath); the core's light wall against the pale
   gatehouses and at the mere.
5. Kezamba: palisade with pointed jungle-log stakes, gate passages, the deck
   across the cenote; core palisade unchanged.

## Open risks

- Lethariel's arcade and Kezamba's deck now cut across the civic lakes: the
  free course above the water is one node, so a swimmer passes under by
  diving (boat clearance not tested). If the user prefers the lake as the boundary, the wall can
  stop at the shores instead.
- Styles are first versions by feel; the renders under-represent the pillar
  and bar shapes.
- The narrow gatehouses (7 × 11) are smaller than the other capitals'.
- `footing` 28 covers a 19-deep cenote bed; a deeper authored lake under an
  edge would need a larger value.
