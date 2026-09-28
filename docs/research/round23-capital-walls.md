# Round 23 Lane C — capital walls (receipt)

2026-09-28. Contract: [Round 23 plan](../planning/round23-world-life-plan.md),
Lane C. Branch `wp13-capital-walls` off `27703fc7`. Capitals only; start
towns, villages and POIs are untouched. Design result:
[settlements.md](../design/settlements.md) (civic-core boundary table, walled
capitals, the lake capital, the palisade), [world_zones.md](../design/world_zones.md)
§12 and [world.md](../design/world.md).

The [playtest fix](#playtest-fix-continuous-walls-at-the-civic-lakes-low-elf-crown)
at the end supersedes the lake termination of the follow-up and Lethariel's
colonnettes described in the earlier sections.

## What changed

| Capital | Change |
| --- | --- |
| Highcourt | The precinct hedge becomes a one-node castle-stonewall wall on exactly the hedge's 332 ring columns: stonewall y 1–2, the crown's marble band at y 3 (the band the four gatehouse piers carry at y 3, so it runs straight into them), a stonewall merlon at y 4 on every other column (the gatehouses' battlement rhythm). Four courses, one more than the hedge's three. Outer wall unchanged. |
| Dur Brannoc | Precinct parapet three courses instead of two; the capped merlon every fourth column moves up one (y 4 stone, y 5 cap). |
| Gor Drazhak | Precinct bank three courses (two of dug earth, the beaten crest at y 3) with the stake and point every other column at y 4–5. |
| Nhal Veyr | Bar course closed (below). Height unchanged. |
| Lethariel | Outer edge: the stone curtain model in a light elf style (below), with gatehouses and turrets. Core: the silverwood hedge becomes a one-node light wall — silver sandstone brick y 1–2, marble coping y 3 (the height of the pale gatehouses' marble band), a colonnette (pale castle pillar, base y 4 and top y 5) on every other column (since the playtest fix a brick at y 4 under a marble slab at y 5); the mere still replaces the boundary where it reaches the ring. |
| Kezamba | Outer edge: the orc palisade model in the troll core palisade's materials (below), with the palisade's own gate passages. Core unchanged (byte-identical blueprint). |

All six core blueprints keep their bounds (y −2..31); outside the ring
columns not one cell changed (cell diff before/after, all six cores).

### Style choices made by feel

- **Lethariel curtain** (`city_edge.lua` STYLES.elf.stone): face
  `default:silver_sandstone_brick` (the civic quarter's pale stone), core
  `default:silver_sandstone`, walk `darkage_marble_tile` with its slab, a green
  `darkage_serpentine` string course three under the walk, a marble coping on
  every parapet and tower top, colonnettes (`castle_pillar_silver_sandstone_brick`
  `_bottom` + `_top`) in place of every merlon (since the playtest fix: one
  brick under a marble slab), a marble lintel over each gate
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
`WALL_CLEAR` above the surface. The first delivery crossed both lakes as an
arcade and a pile deck (`WALL_CLEAR` 5); the user's ruling replaced that with
the shore termination below, and all kinds now use the default 1.

## Preparation and protection consistency

- Core walls reach y 5 at most; core bounds (from cells) unchanged.
- The overlay y range (`r7_capital_blueprint.lua`) keeps 24 below the lowest
  walk (the first delivery's `footing` 28 for pile decks is gone with them). Top: turret colonnettes and lamps
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
`lethariel-core-wall`, `lethariel-edge-gate`, `lethariel-edge-turret`,
`kezamba-edge-gate`, `kezamba-edge-turret`, and the shore follow-up's
`lethariel-shore-south-gate`, `lethariel-shore-east-gate`,
`kezamba-shore-gate`, `kezamba-shore-end-tower` (the first delivery's
lake-arcade and lake-deck renders are removed). Core images are blueprint renders; edge images are real
terrain dumped from the engine.

## Runtime test plan (fresh world)

1. Highcourt: walk round the precinct; wall 4 high, marble band flush with the
   gate piers' band, merlons alternate; all four gate passages open.
2. Dur Brannoc and Gor Drazhak: precinct parapet/bank one node taller; the
   corner drums/towers have closed walls where the ring meets them.
3. Nhal Veyr: the bar course runs merlon to merlon with no air gaps; look at
   bars on the east/west sides too.
4. Lethariel: arrive by road; pale gatehouse with marble lintel, walk the
   curtain, colonnettes, turret lamps at night; the crown lake open between
   the south and east gatehouses, no masonry in the water; the core's light
   wall against the pale gatehouses and at the mere.
5. Kezamba: palisade with pointed jungle-log stakes, gate passages; the cenote
   open between the east gatehouse and a closed timber end tower on the south
   shore; core palisade unchanged.

## Open risks

- Styles are first versions by feel; the renders under-represent the pillar
  and bar shapes.
- The narrow gatehouses (7 × 11) are smaller than the other capitals'.
- Where the civic lake is the edge, the city is open from the water: a
  swimmer or boat can enter between the shore ends (the ruling's intent).
- The shore decision is per world: another seed's outline may leave a short
  wall piece or put a gate near the water differently; the probe checks the
  rules on any layout file.

## Follow-up: the wall ends at the civic lakes' shores

2026-09-28, user ruling after review: no wall over the civic lakes of
Lethariel and Kezamba; the wall ends on both shores, closed on dry ground in
the race's style. Branch `wp13-capital-walls-shore` off main `f5a545bd`.

- **Planner** (`capital_planner.lua`): with `I.shore_distance` (passed by
  `r7_capitals.lua` from the civic lake's authored indicator, distance =
  `(0.5 - m) × LAKE_PROXY`), a non-gate wall point within `SHORE_KEEP` 6 of
  the lake's water is flagged `l` in the payload; a dry stretch of fewer than
  `SHORE_MIN_RUN` 12 points from a lake stretch to the next lake stretch or
  gate is flagged too, so no stub of wall is left between two towers or
  between a tower and a gatehouse. The first dry point beside each lake
  stretch gets a shore-end turret unless it is a gate point (then the
  gatehouse closes the end); ordinary turrets on lake points or within 6
  points of an end turret are dropped. Gaps, the plot band, streets and
  gates are computed before and without the flag.
- **Writer** (`city_edge.lua`): no wall on a segment touching a lake point; a
  shore-end turret's walk passage stays shut on its lake side, so the end
  tower is closed (stone: the elf turret with colonnettes and its lamp;
  palisade: the troll timber tower with turned points).
- **Seed 4242 result.** Lethariel: 201 lake points from the south gatehouse
  to the east gatehouse; both ends are gatehouses on the shore, 18 turrets
  (was 26). Kezamba: 141 lake points from the east gatehouse to one closed
  timber end tower on the south shore, 17 turrets (was 21). No gate or street
  depends on a lake crossing: the payload apart from the wall lines (water,
  roads and every capital street, `o g p s q`) is byte-identical to the
  pre-Round-23 baseline, as are all six capitals' wall point positions; the
  four other capitals' `w` and `t` lines are byte-identical to main.
- **Evidence.** Probe (extended: no wall or turret cell over the civic lake,
  no gate or turret on a lake point, every lake stretch closed by a gate or a
  turret whose disc is dry): PASS on the final layouts; on main's layouts it
  fails (12 753 and 6 146 cells over the lakes), so it detects the old
  arcades. Nearest wall cell 8.1 (Lethariel) and 2.9 (Kezamba) nodes off the
  water. Lethariel's south gatehouse, at its unchanged planned place on the
  shore, has 52 cells inside the indicator's margin (outer tower column
  x=1779, z −1378..−1376): the tower's outer flank stands about one column
  into the shallow shore, its masonry displacing the water there (engine
  dump `engine5/wallprobe_lethariel_shore_2.tsv`). The gate position is fixed
  by the ruling, so this is accepted (review correction). Engine dumps of all
  four shore ends show no edge material left standing in open water.
- **Review notes (Low) of the shore follow-up.** (1) End towers are checked
  only by their point's distance (> 6) from the water; on rare outlines a
  Kezamba end-tower disc can reach about one column into the edge water
  (2 of 533 synthetic outline variants, about 0.3 nodes). (2) A gate that
  finds no dry spot within its slide still stands in the lake as before
  (D70 rule, unchanged by the ruling). Two engine runs
  (150 s each, seed 4242, isolated, PASS, no ERROR); `check_lua.sh` passes.
- **Review notes (Low) from the first delivery.** (1) The `WALL_CLEAR` pass
  runs for every capital with the default 1; it only raises a walk at or
  below the water, so it is harmless there (the four other capitals' walks
  are byte-identical). (2) Lethariel's gate-tower serpentine band sits at a
  fixed `g.y + 6`, so on a steep slope, where the tower's ground rises above
  that, it can end up buried in the tower's lower courses; cosmetic.
- Remaining wet points on these two edges (small non-lake waters: Lethariel
  7 + 8, Kezamba 4 points) keep the ordinary arcade or deck with the default
  clearance, like every other capital.

## Playtest fix: continuous walls at the civic lakes, low elf crown

2026-09-28, after the user's playtest on a fresh world (current main). Branch
`wp13-capital-walls-lake-fix` off main `f712cd5d`. This section supersedes
the lake termination of the follow-up above and the Lethariel colonnettes.

### Findings and cause

1. **A lone wall piece with a turret at Lethariel**, on dry city ground near
   the lake, between the east gatehouse and the lake. Cause: the follow-up's
   `SHORE_KEEP` margin. East of the core the outline does not cross the lake
   once: it crosses it, runs about 50 nodes along a land tongue 1 to 7 nodes
   from the water (seed 4242: points 367–391, shore distance 0.9–6.1, the lake
   2–14 nodes outside it), and crosses again. Every point within 6 nodes of
   the water lost its wall, and `SHORE_MIN_RUN` stripped dry runs under 12
   points. Where the tongue lies a little further from the water for 12
   points or more, as on the playtest world, that run kept its wall and got a
   shore-end turret at both ends: a lone piece on the tongue. On seed 4242
   two points reach 6.1 and were swallowed by the 12-point rule. Synthetic
   outline variants (below) show the same fragment in 57 of 119 Lethariel
   outlines and 22 of 119 Kezamba ones.
   **Kezamba had a worse form of the same margin on seed 4242.** North of the
   cenote the outline runs about 100 nodes along the shore (points 425–474,
   distance 2–10), with the cenote inside and open land outside. The margin
   and the 12-point rule stripped all of it, so the city was open over land
   there. The only turret was an end tower on the south-gate side.
2. **The beach between the water and a wall end or gatehouse** was the same
   6-node margin.
3. **The elf crown**: the pillar colonnettes (two nodes over the coping) read
   too tall, on the towers most of all.

### Fix

- **Planner** (`capital_planner.lua` `M.shore_flags`, pure, unit-testable):
  only points on the water are lake. The wall runs on land up to the water,
  over the first 1 to `SHORE_INTO` 3 water points of each crossing, and ends
  there. Past the first point it runs on only while the points lie within
  `SHORE_DEEP` 3 nodes of the shore. Beside a gate the depth rule applies
  from the first point, so a gatehouse standing in the water (D70) is its
  own end. A dry stretch **between two crossings** carries no wall in two
  cases: it is shorter than `SHORE_MIN_RUN` 12 points, or the land outside
  it is closed by the lake. The second is a 4-connected fill over the dry
  columns outside the outline, started within 3 of the stretch, that never
  leaves the stretch's box grown by `SHORE_REACH` 32. Such land can be
  reached only over the water or through the city. Every other dry point is
  walled, including every stretch between a crossing and a gate. Walled
  points within `SHORE_KEEP` 6 of the water, the water points included, get
  the new payload flag `f` (footing). No turret stands within 6 points of the
  water, and the end turrets are gone.
- **Writer** (`city_edge.lua`): an `f` segment is solid down to the bed,
  never an arcade. Stone uses face and core masonry; the palisade uses stakes
  under the whole rampart where the column is in water. The wall ends in a
  **head** of 1.5 nodes on either side of its last point, reaching 1.5 nodes
  on toward the lake. Stone: a parapet across the walk, with coping and a
  merlon on every other column. Palisade: the stockade with its turned
  points. Lethariel merlons (curtain, turrets, gate towers) are now the plain
  merlon: one silver sandstone brick under a `darkage_marble_slab`, 1.5
  nodes over the coping instead of the two-node colonnette.
- **Core** (`lethariel.lua`): the light wall's merlon is the same brick at
  y 4 under a marble slab at y 5 (height and bounds unchanged).
- The overlay y range is unchanged. The footings reach the bed of shallow
  water only, far inside the existing 24 below the lowest walk, and the probe
  now also checks the bottom.

### Style choices made by feel

- The **head** is a closed parapet in the water, not a tower. An end turret
  (radius 3) centred on the last point would have stood 5–6 nodes into the
  lake. Beside a gatehouse on the shore, the gatehouse and a short head read
  as one piece.
- **Elf crown**: the user's first example, a one-node brick merlon capped
  with a marble slab, above the continuous marble coping. It keeps the
  marble-on-every-top idea at 1.5 nodes. The gate passage parapet keeps its
  marble slab caps on the coping.
- `SHORE_DEEP` 3 over 2: the wall's centre line ends about 3.2–3.6 nodes
  into the water on seed 4242, so a swimmer must leave the shallows to pass.

### Evidence

- **Probe** (`tools/wp13/capital_walls_probe.lua`, LuaJIT, extended): part 1
  checks the Lethariel core crown. Part 2 checks, on every lake end: 1–3
  walled water points (none only beside a gate), each with a footing, a
  closed head, and solid masonry or stakes from the ground to the walk in the
  middle of every walled water segment. It also checks: every dry lake point
  lies between two crossings, never between a crossing and a gate (no dry
  margin); no isolated wall run between two lake stretches unless it has 12+
  dry points and its outside land escapes (an independent even-odd fill,
  reach 48); no edge cell deeper than `SHORE_DEEP` + half + 2; no turret near
  the water; every cell inside the overlay's y range; no pillar in
  Lethariel's crown; and every marble slab either capping one brick over the
  coping or on the passage parapet's coping. New `--baseline-layouts` and
  `--baseline-edge` options compare against the previous version. Results:
  - Final seed-4242 layouts: **PASS**. Lethariel: 170 lake points (was 201),
    one crossing (the tongue merged into it), 4 walled water points (east 1,
    south 3), deepest edge cell 4.0 nodes into the water, 699 marble merlon
    caps, 0 pillars, 18 lamps for 18 turrets. Kezamba: 81 lake points (was
    141), 5 walled water points (east 2, north 3), deepest cell 5.6 (an
    outer stake of an oblique crossing), 0 isolated runs.
  - Baseline (engine layouts of main `28a9a2a3` = `f712cd5d` for mapgen and
    main's `city_edge.lua`): Highcourt, Dur Brannoc, Gor Drazhak and Nhal
    Veyr have byte-identical layout texts and identical edge cells and names
    (100 175 / 105 084 / 50 571 / 100 972 cells). For Lethariel and Kezamba
    only the `w` flags and `t` differ: every other line is byte-identical,
    and so are the wall points, walks, gate and water flags. The water and
    road sections of the whole layouts file are byte-identical.
  - The same probe **fails** on main's layouts (dry lake points between a
    crossing and a gate, and Kezamba's end tower within 6 points of the
    lake). It also fails on a mutant with the tongue's wall restored (an
    isolated 25-point run, lake ends not walled into the water).
- **Synthetic outlines** (scratch sweep): 119 variants per lake capital, the
  outline scaled 0.92–1.08 about the anchor and turned −6..6°, with gate
  points kept by index. The old rule leaves an isolated fragment in 57
  (Lethariel) and 22 (Kezamba). Under the new rule: every lake end keeps 1–3
  water points except where a variant pushed a gate into the water; the
  deepest walled water point is 3.0/3.3; the remaining walled runs between
  two lake stretches (Lethariel 1, Kezamba 21) are all 12+ dry points with
  open land outside, i.e. real land crossings. `shore_flags` costs about
  1 ms per capital.
- **Engine** (`tools/luanti_headless.sh`, seed 4242, `LC_ALL=C`, `chrt --idle
  0 ionice -c3`, a disposable dump probe, normal shutdown by
  `core.request_shutdown` after the dumps): two runs of about 42 s each.
  Both PASS (listening, no ERROR), layouts built in 19.5 s, capital planning
  6.1–6.2 s for all six as before. Run 1 layouts equal the portable
  re-derivation of the flags byte for byte in the `w` lines. Run 2 (final
  writer) layouts equal run 1's but for the source key and timings. Engine
  dumps: the deepest edge column in the water is 3.7 / 4.0 nodes (Lethariel
  east / south end) and 4.5 / 5.6 (Kezamba east / north end); no edge
  material on the Lethariel tongue. `pgrep -f '^luanti.bin'` is empty
  afterwards. No PUC (mapgen exemption).
- `tools/check_lua.sh` passes on every changed Lua file (parser, sweeps 1–6,
  no SETGLOBAL).

Images (engine dumps unless noted, `render_blueprint.py`; it draws
`darkage_marble_tile_slab` as flat colour):
`lethariel-shore-east-gate` (the east gatehouse, the wall on to the water
and its head), `lethariel-shore-south-gate` (the wall round the inner bay
and its head in the lake), `kezamba-shore-gate` (the east gatehouse with the
palisade run into the cenote), `kezamba-shore-north-end` (the new north-shore
palisade ending in the cenote), `lethariel-edge-gate` and
`lethariel-edge-turret` (the low crown), `lethariel-core-wall` (the core's
low crown, blueprint render). `kezamba-shore-end-tower` is removed.

### Runtime test plan (fresh world)

1. Lethariel, from the core looking over the crown lake toward the east
   gatehouse (the playtest viewpoint, about 1800, 100, -1500): no wall piece
   on the shore between the east gatehouse and the lake. From the east
   gatehouse the wall runs to the water and 2–3 nodes into it, closed by a
   parapet. Try to walk round its end along the beach: you have to swim.
2. The same at the other end (by the south gatehouse): the wall reaches into
   the lake and is closed at its end; the lake is open beyond.
3. Kezamba: at the east gatehouse the palisade runs from the gate tower into
   the cenote with no beach gap. On the north shore the palisade is closed
   along the whole shore and ends in the cenote, with no gap to the land
   outside.
4. Lethariel crown: curtain, turrets and gate towers carry low brick merlons
   with marble slab caps, with no tall pillars. The core's light wall has the
   same crown. Turret lamps still stand at night.
5. The other four capitals look exactly as before.

### Open risks (Low)

- On other seeds a wall run can stand between two lake crossings where it
  closes real open land (12+ dry points whose outside reaches beyond the
  lake); it then ends in a head at both ends. That is the rule's intent, but
  it is a separate piece in the lake.
- A pocket of land outside the outline that the lake closes but that is
  more than 32 nodes deep reads as open and is walled.
- Heads and footings are checked on synthetic ground and four engine dumps;
  the renders cannot show the slab caps' real shape.
