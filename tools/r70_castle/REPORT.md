# Round 70 CASTLE — delivery report

Date: 2026-11-07. Branch: `r70-castle`, based on `0a7acf25`.
Artist: GPT-6 Astra. **Compatible, tools only.** Installing the selected form
belongs to CAPITALS and joins Round 70's declared map reset.

The [pick page](page.html) is complete locally: three proposals, today's hall,
all six capital palettes, interactive orbit/walk cameras, floor plans with
socket markers, light/dark themes, and nine embedded PNGs. It is self-contained.
The user's pick and the coordinator's independent review remain pending.
No other agent was started; no game file, other worktree or reference checkout
was edited. Nothing was merged or pushed.

## Forms and recommendation

| Form | Highest node | Reachable furnished hall | Distinct form |
|---|---:|---:|---|
| **A — Crownward, recommended** | 33 | 783 | Four corner towers, a lower gate tower, a rising vaulted hall and a taller rear crown |
| B — High Seat | 38 | 783 | One monumental keep with three setbacks and an upper lantern, behind a low curtain |
| C — Gate Crown | 34 | 783 | Twin tall gate towers, a low bridge over the entrance, a broad hall and rear screen |

**Recommend Crownward:** it reads as a castle from several approach directions;
its front towers announce the threshold while the taller rear pair gives the
throne end architectural weight. High Seat is the strongest single skyline
mass, but more severe. Gate Crown makes the most emphatic entrance, at the cost
of putting more visual weight in front of the hall.

One symbolic composition produces all six race files per form. There are no
race-specific geometry branches. Each candidate uses the existing capital
palette from today's hall roster, including its roof channel. These exact
bindings are generated in [palettes.json](palettes.json); they must accompany
the selected templates at integration. In particular, Highcourt keeps marble
and slate, Lethariel its pale roof, and Kezamba basalt.

Later dressing, without changing the form:

- Dwarf / Dur Brannoc: carvers' reliefs and metal clan seals on the buttresses;
  stone-block masonry, slate and brown/red cloth already appear.
- Human / Highcourt: The Accord's hart standards and civic shields over the
  foyer; marble, slate and red/white cloth already appear.
- Elf / Lethariel: serpentine inlays and leaf reliefs at window heads;
  marble, pale sandstone and green/white cloth already appear.
- Orc / Gor Drazhak: The Throng's boar standards and iron gate bands;
  adobe, red sandstone, acacia and red/brown cloth already appear.
- Undead / Nhal Veyr: incised memorial panels and silver funerary emblems;
  obsidian, dungeon stone, gravewood and black/grey cloth already appear.
- Troll / Kezamba: woven valances, carved masks and high rope bindings;
  basalt, junglewood and green cloth with straw edging already appear.

## Land, floor and encounter

All three boxes have pivot **45 × 35**, origin **(0,0,0)** and inclusive horizontal
bounds **x 0…44, z 0…34**. Every layer explicitly writes air in unused cells.
They face south at turn 0. Their highest node is at y 33 / 38 / 34 respectively,
inside the requested y ≤ 38 and the core's y −2…40 reservation.

The DESIGN allocation is retained numerically: **304** columns in the two-node
outer band, **805** in the hall, **120** in the hall wall ring, **346** in the
remaining foyer/service/circulation budget. Sum: **1,575**.
**One explicit split adjustment:** the study's rear circulation row moves to
the foyer. The hall including walls is x 4…40, z 8…32; the foyer reservation
is six rows at z 2…7, the side strips are x 2…3 and 41…42, and there is no
rear ground corridor. Towers and entrance structures use part of that service
budget. The footprint and 35 × 23 hall reservation do not grow or shrink.

The hall's interior is **x 5…39, z 9…31**. Main floor nodes are at y 2. The
15 × 7 dais is x 15…29, z 25…31: its front stair row is y 3, its next stair
row at z 26 is y 4, with the upper floor continuing through z 31. The outer
approach has two stair rows at z 1 and 2. All these stairs face north in the
unrotated template; their two half-node treads allow walking without a jump.
The template flood fill allows cardinal steps of at most one node, with two
clear cells and clearance over an ascending traveller.

**783 reachable floor columns after furnishing**, in all 18 candidates. Counted
only at each column's authored main-floor or dais height; seats, throne surfaces
and roofs are excluded. Four seat columns and 18 throne/support columns are
occupied. The earlier exploratory count of 787 included the four seats' tops;
the final generator excludes them. Relative to the DESIGN checker's supplied
baselines, this is **+99 / 14.5%** over 684, and **+381 / 94.8%** over Kezamba's
402. Those baseline measurements were not rerun here.

A **29 × 15 = 435** rectangle, x 8…36 and z 10…24, is completely free at feet
and head height. The carpet is recessed into the floor, never a raised block
obstacle. Both sides of the dais remain open. The king stands before the seat;
his royal guards stand exactly three nodes to either side. There are no
free-standing pillars on the battle floor. Eighteen existing Emberglass lamps
light the sides, foyer, throne and two high cross-beams; the beams are at y 12.
The viewer does not model the engine's propagated night lighting.

There is one playable storey with a raised dais. Upper towers and the keep's
lantern are architectural volumes, with no playable upper rooms, stair routes
or NPC sockets. The page labels the roof plan accordingly. This proposal makes
no promise of a confined arena: king chase/leash, rewards and existing encounter
rules are not changed.

## Throne and nodes

**No new CASTLE node registrations or textures are needed.** The common throne
body is seven nodes wide, three deep and nine high (x 19…25, z 28…30,
y 5…13), built from signature stone, its slab shape, a stepped back, arms,
and inset cloth on the seat and back. Its broad stone dais uses the existing
castle stair role. The king's socket is in front of the physical seat, with
fully empty feet and head cells, rather than inside a chair's collision box.

Existing carpet vocabulary was checked: the settlement palettes already supply
`rug` and `rug_accent` as wool, with straw edging for the troll palette. These
are used flush with the floor. No thin carpet or new interaction is added.

The five selected full blocks from ART are used **once each**, at
(x 20…24, y 8, z 30), in order Iron, Steel, Silversteel, Embersteel, Abyssal Steel:

`grug_guild:ornamented_iron`, `grug_guild:ornamented_steel`,
`grug_guild:ornamented_silversteel`, `grug_guild:ornamented_embersteel`,
`grug_guild:ornamented_abyssal_steel`.

These are **dependencies on GUILD**, not new throne-specific blocks. They are
not yet registered in this base commit. [preview_nodes.json](preview_nodes.json)
contains explicit static full-cube definitions for the tools; their selected
16px faces are read directly from `tools/r70_art/candidates/final/`, following
`tools/r70_art/INSTALL.md`. They emit no light and have no callback, container,
timer or animation. Installing their actual definitions and adding them to the
registry/editor palette remains GUILD/CAPITALS work; a parser pass does not
claim that they are already usable in the live game.

Lighting uses the optional `light_beacon` role, with the existing
`grug_materials:emberglass_lamp` as fallback. Its registration in
`grug_materials/ores.lua` is static, without `on_construct` or a timer.
Candidates contain no fire, liquids, containers, falling blocks or interactive
furniture. The only functional nodes are the normal paired game doors and their
hidden upper halves. Their `_a`/`_b` orientations and the upper-half conventions
match `parts.door`; the vendored door toggle handles missing initial state.

## Socket coordinates — all three forms, all six races

The schedule is identical for **Crownward, High Seat and Gate Crown**. Coordinates
are local node positions before rotation; +x east, +z north. Faces, ids, roles,
order and idle tags are checked against each race's current hall template.

| Socket | x | y | z | Face | Role / tags |
|---|---:|---:|---:|---:|---|
| `king` | 22 | 5 | 27 | 2 | king |
| `throne_guard_west` | 19 | 5 | 27 | 2 | guard_post |
| `throne_guard_east` | 25 | 5 | 27 | 2 | guard_post |
| `door_guard_west` | 18 | 3 | 4 | 0 | guard_post |
| `door_guard_east` | 26 | 3 | 4 | 0 | guard_post |
| `hall_waypoint` | 22 | 3 | 6 | 0 | waypoint |
| `hall_idle_west` | 7 | 3 | 17 | 1 | idle, `[bench]` |
| `hall_idle_east` | 37 | 3 | 17 | 3 | idle, `[bench]` |
| `hall_idle_service` | 7 | 3 | 23 | 3 | idle, `[door]` |

The external approach point is `(22,1,0)`, face 2. The great-door point is
`(21,3,8)`, face 2; its paired leaf is at `(22,3,8)`. The high arch's other
lanes stay open, so a group can pass without filing through a two-node opening.
The hall's `inside` point is `(22,3,12)`.

Use `parts.stamp` with pivot 45,35, not an independent rotation. The four local
coordinate maps are `(x,z)`, `(z,44−x)`, `(44−x,34−z)`, `(34−z,x)`;
face becomes `(face + turns) % 4`. Odd turns produce a 35 × 45 box, even turns
a 45 × 35 box. The north-facing Kezamba placement uses turn 2. The other
placements and anchor translations belong to the approved capital land plan.
All sockets have solid support and empty feet/head, and are reached from the
outer approach. Native stamping checks this in all four turns.

## Checks and limits

- `python3 tools/r70_castle/build.py --check`: **PASS**, byte reproduction of
  all 18 templates, palette profiles, inventory, metrics, preview definitions
  and the single-file page; still input and output hashes match.
- Both existing Python template parsers: **18/18 PASS**.
- Existing game template reader under LuaJIT: **18/18 PASS**, all six races
  in every form. No PUC execution and no committed Lua additions.
- Native `templates.part` / `parts.stamp`: **72/72 PASS**. Full air/write boxes,
  bounds, socket positions, faces, feet/head and support pass in every turn.
- Candidate checks: known nodes with the five explicit ART preview additions,
  palette resolution, complete paired doors, socket identity/order/tags,
  reachability, floor counts and the clear battle rectangle: **PASS**.
- `python3 tools/r70_castle/verify.py`: **PASS**. Inline JavaScript syntax,
  external-reference check, texture/PNG decoding and **24** shared-viewer
  geometry exports, including every current hall, pass.
- Nine 1200 × 900 PNGs: approach quarter, hall from its doorway at player eye
  height, and overhead cutaway for each form. Rendered from actual shared-viewer
  triangles, textures and vertex shading; representative PNGs inspected.
- `git diff --check`: **PASS**. Only `tools/r70_castle/` and one tools-index line
  are changed. No fixtures, seed fleet, server or engine run was performed.

**Not checked:** browser layout/events, touch interaction and actual light/dark
layout. Chromium failed before loading the file with `setsockopt: Operation not
permitted`; no browser acceptance is claimed. CSS has a phone breakpoint and
system/manual theme handling, and the controls use the shared viewer's touch
implementation. Runtime lighting, collision/pathfinding for ten players and
mobs, doors in the game, combat, city placement, terrain, performance and
desktop/web engine acceptance remain for the user and CAPITALS.

The full building-template integration gate was **not** run: candidates are
outside `mods/`, have deliberately new boxes and lack installed GUILD nodes.
CAPITALS must create the final template/roster entries, coordinate the BASELINE
move, update the hall list in `tools/r58_townfix`, and run the full template gate,
required full seed fleet and desktop/web checklist described by DESIGN.

## Publication and provenance

**Local page delivered; hosted publication pending.** The available Sites
workflow requires pushing the page source to its own hosting repository. The
lane explicitly forbids pushes. A narrowly scoped hosting-only exception was
asked for; none had been received at this report's completion. No Site was
created and no push was attempted. The complete file is ready for publication
by the user or after that specific exception is granted.

Publication workflow consulted:
`/home/jan/.codex/plugins/cache/openai-curated-remote/sites/1.1.4/skills/sites/SKILL.md`.
Its source helper “owns Git preparation, ordered commands, commit/push, and
packaging”; this is the exact step conflicting with the lane's no-push rule.

The shared building viewer's parsers, packing, node geometry, textures and mesh
reader are reused without editing them. The repository's Three.js r147 is
embedded with its MIT licence; the two colour-space property names are adapted
to that version as in Round 69. The local Round 69 orbit controller is embedded.
`geometry.js` follows that lane's offline triangle export, and `render.py` reuses
its rasterizer with a wider doorway view. Existing media retain their repository
licences; the selected Stonewright faces remain GPT-6 Astra / CC0-1.0 under ART's
handoff. No third-party asset was downloaded and no image generator was needed
for this native node composition.

Design inputs read: Round 70 plan §2.6/§2.7/CASTLE; the building-template format;
settlements' capital rules; the current six hall templates and rosters; Round 69
camp art and builder; ART's final assets and INSTALL; and the read-only sibling
`r70-design/tools/r70_design/REPORT.md` / `claims.md` (especially C007/C008 and
C087–C089). Neither DESIGN nor its claimed baseline/fleet measurements was changed.

## Commits and handoff

The first composition checkpoint is `8c7b4716`; the palette/floor refinement
is `4825f97f`. The final artifact commit is
`dc8d90dd4a93760f6f4713cbb79cd6067de839da`. This report follows in its own
commit; the final handoff names that full final commit hash. A report cannot embed the hash of the commit containing
that same report. Retrieve it without ambiguity with:

```sh
git log -1 --format=%H -- tools/r70_castle/REPORT.md
git status --porcelain
```

The final working tree is clean. Each lane commit ends with
`Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.
