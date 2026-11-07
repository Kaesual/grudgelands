# Round 70 CASTLE — pass 3 delivery report

**User pick (2026-11-07): A — Crownward.** Pass 3 gives A a smaller bronze
throne with a three-wide seat. B — High Seat and C — Gate Crown remain in
place as the pass-2 record. CAPITALS handoff: [INSTALL.md](INSTALL.md).

Date: 2026-11-07. Branch: `r70-castle`; pass-3 base: `ce9da517`.
Artist: GPT-6 Astra. **Compatible, tools only.** Installation belongs to CAPITALS
and joins Round 70's declared map reset. No game files, other worktrees or
reference sources were edited; no agent, server, fixture or fleet was started.
Nothing was merged or pushed. The coordinator’s independent review of this
delta remains pending before integration.

The self-contained [pick page](page.html) retains three forms, today's hall,
all six palettes, orbit/walk controls, plans, socket markers and themes.
It includes **18 stills**, with a bright hall and a calculated night hall
side by side for each form, plus the entrance arch and a close throne view.
The PNG originals remain in [renders](renders/); the page embeds WebP previews
at quality 90. Both the builder and verifier enforce **15,000,000 bytes maximum**.
The finished page is **7,882,621 bytes** (7.88 MB).

## Pass 3 — the picked throne

- **Seat: 3 × 2**, down from 5 × 2, still raised at y 6 for a clear view
  from the far end of the hall.
- **Body: 5 × 3 × 7** (width/depth/height), down from 7 × 3 × 10.
  It occupies x 20…24, z 28…30, y 5…11. The central full bronze crown
  reaches y 11.5; the other crown cells are bottom slabs.
- The arm posts/rails now reach y 7, capped by bronze slabs at y 8,
  **one node lower**. The bronze frame remains distinct from the masonry.
  The cloth back is three wide and three high, y 7…9 at z 30.
- All **five ornamented stones** remain in their order across the top of
  the back, x 20…24, now at y 10 instead of y 12. Each appears exactly once.
- **Dais unchanged: 15 × 7.** The smaller chair still anchors the composition
  between its two lamps, as inspected in the close, far-hall and night renders.
  The two broad stair rows keep room for the king, guards and group approach.
- **Sockets unchanged.** The king remains at (22,5,27), with guards at
  x 19 and 25, three nodes to either side. The king’s final collision body
  is 0.96 × 2.72 × 0.96, from `bosses.lua::king_def` (base 8/7) and
  `levels.lua` (elite scale 1.4). Its rear edge z 27.48 clears the throne’s
  front plane z 27.5 by **0.02 node**. The guards’ bodies are 0.84 wide and
  2.38 high. All three clear the occupied cells from settled feet y 4.5
  through initial socket feet y 5, with support underneath; the king is
  in front of the chair, not inside it.
- A now has **784 reachable floor columns**, six more than pass 2. All six
  A templates and its six stills were regenerated. B/C templates and PNGs
  are byte-identical to `ce9da517`; their receipt input hashes changed because
  the page’s shared type/texture indexing changed. The rendered output hashes
  remain identical. The page marks A as picked and B/C as retained, and its
  throne dimensions and floor count follow the displayed form.

## Pass-2 fixes retained against the checker

The supplied Opus report, `grudgelands-orchestration/r70/reports/castle-check.md`,
was read and its findings checked at their sources:

1. **Light:** the former 18 lamps left the middle dark. There are now 32 static
   Emberglass lamps. Seven additional lamps hang at `(7/12/17/22/27/32/37,8,17)`
   under a beam at y 9. Six hang at `(7/12/17/27/32/37,8,26)` under side brackets
   at y 9. Their middle is open at x 18…26 so it does not cut across the throne.
   The fourteenth new lamp is flush with the dais at **(22,4,27)**, under the
   king. The source strength is 14 (`grug_materials/ores.lua`). The page names
   bright renders as geometry studies, not daylight. Night uses the calculated
   bank without extra fill or exposure lift.
2. **False door:** the two leaves and hidden upper halves are removed. The hall
   entrance is explicitly a **seven-wide open arch**, x 19…25, y 3…8, z 8.
   This is the allowed omission, preserving the group approach. The entrance
   camera and walk start are now in the foyer at z 3, before this arch.
   `grug_mobs/npc_doors.lua::D.at` confirms why the former freestanding leaves
   were not a doorway for NPCs.
3. **Reversed pair:** confirmed against `wp13/parts.lua::double_door`: face 2
   puts `_a` east of `_b`. Removing both leaves eliminates the reversed pair;
   the generator now rejects any door nodes in these open-arch candidates.
4. **Stairs:** every approach/dais stair at z 1, 2, 25 and 26 uses
   `signature_stair`, facedir 0. The resolved names contain no `wall`, `gate`
   or `fence`; these substrings trigger `mobs/api.lua`'s `facing_fence` rule.
   The existing half-tread geometry and socket heights are retained.
5. **Force air:** every explicit air cell uses the format's reserved `.`.
   There is no `node air` legend entry. The builder checks the editor palette
   allowlist, with only the five pending GUILD ornament definitions excepted.
6. **Minor points:** west seats now face 3, east seats 1. Both side openings
   have `doors` points: west `(4,3,20)`, face 3, and east `(40,3,20)`, face 1.
   Thus the unchanged `hall_idle_service` socket tagged `[door]` has a marked
   nearby opening. This point group also describes open entrances; it does not
   claim that a door leaf is installed.
7. **Throne (pass 2):** rebuilt as a bronze-framed chair with a deep raised seat, open
   spaces below its arm rails, a tall cloth back and a stepped crown. The
   bronze separates it from every culture's masonry. The carpet ends at the
   foot of the dais. No part of the rug climbs the steps or joins the seat.
   The back stands at z 30, with the clear row z 31 between it and the wall.
   Sightline checks cover the seat, back and crown from the far end of the hall.

## Forms and the recorded pick

| Form | Highest node | Reachable furnished hall | Distinct form |
|---|---:|---:|---|
| **A — Crownward, picked** | 33 | 784 | Four corner towers, low gate tower, rising vault and taller rear crown |
| B — High Seat | 38 | 778 | Monumental keep with three setbacks and an upper lantern |
| C — Gate Crown | 34 | 778 | Twin tall gate towers, low entrance bridge, broad hall and rear screen |

**The user picked Crownward:** it reads as a castle from several approaches, while
its higher rear towers give the throne end architectural weight. High Seat
has the strongest single skyline mass; Gate Crown emphasizes the entrance.
The external silhouettes, footprints, palette bindings and nine sockets are
unchanged from pass 1. The hall remains shared; only A has the smaller pass-3
throne. B and C keep their pass-2 furniture.

One symbolic composition per form generates all six races. The existing capital
roster supplies main and roof palettes, recorded in [palettes.json](palettes.json).
These bindings must accompany the chosen templates at integration.

Later dressing, without changing the shared form:

- Dwarf / Dur Brannoc: carvers' reliefs and metal clan seals; stone, slate,
  brown/red cloth.
- Human / Highcourt: The Accord's hart standards and civic shields; marble,
  slate, red/white cloth.
- Elf / Lethariel: serpentine inlays and leaf reliefs; marble, pale sandstone,
  green/white cloth.
- Orc / Gor Drazhak: The Throng's boar standards and iron gate bands; adobe,
  red sandstone, acacia, red/brown cloth.
- Undead / Nhal Veyr: memorial panels and silver funerary emblems; obsidian,
  dungeon stone, gravewood, black/grey cloth.
- Troll / Kezamba: woven valances, carved masks and high rope bindings; basalt,
  junglewood, green cloth and straw edging.

## Light measurements and rendering

The result is identical for **all six races within each form**:

| Form | Lamps | Floor columns sampled | Night median | Level ≤ 3 | Level 0 | King's head |
|---|---:|---:|---:|---:|---:|---:|
| Crownward | 32 | 784 | 7 | 53 (6.8%) | 0 | 12 |
| High Seat | 32 | 778 | 7 | 53 (6.8%) | 0 | 12 |
| Gate Crown | 32 | 778 | 7 | 53 (6.8%) | 0 | 12 |
| Today's Highcourt, supplied checker | — | 725 | 7 | 86 (11.9%) | — | — |
| Pass 1, supplied checker | 18 | 783 | 4 | 273 (34.9%) | 16 | 3 |

The present sample includes the reachable authored main floor and dais, at
feet + 1 node; the king is sampled at `(22,6,27)`. The minimum is 1, maximum
12. Full histograms are in [metrics.json](metrics.json). The two earlier rows
are the checker's supplied measurements, not reruns by this lane. A uses one fewer
floor column than pass 1 (783); B/C still use five more.

[light.py](light.py) floods each registered light source through six neighbours,
losing one level per step, and only enters nodes with `paramtype = light`.
An opaque emitter still supplies its neighbours. There is no sunlight bank or
outside light. These rules were checked against the pinned engine source,
read-only in the main checkout because this worktree's reference is unpopulated:

- `reference_projects/luanti/src/script/common/c_content.cpp`: `light_propagates`
  follows `CPT_LIGHT`.
- `reference_projects/luanti/src/voxelalgorithms.cpp::spread_light`: six adjacent
  nodes, decrement before propagation, opaque receivers stop it.
- `reference_projects/luanti/src/light.cpp::set_light_curve` and
  `src/defaultsettings.cpp`: default display LUT, gamma 1.0, alpha 0, beta 1.5,
  boost 0.2, center 0.5, spread 0.2.

The night PNGs sample this bank immediately outside the actual triangle faces,
apply that LUT in linear colour space and retain the shared viewer's face
shading. The same camera renders the bright comparison. There is no camera
light, global fill, automatic exposure or brightness normalization. This is a
**conservative offline light model, not an engine screenshot**: smooth lighting,
moonlight, bloom, client shaders and graphics settings are not reproduced.
A bright geometry study also does not promise daylight in the hall's middle.

`verify.py` recomputes all 18 banks from the embedded scene cells, compares
histograms to the generated metrics and requires median ≥ 7, a dark-column
fraction no worse than Highcourt's 86/725, no zero columns and king head ≥ 11.
Hand-computed attenuation/opaque/glass probes check the model. Removing the
14 new lights must fail the brightness criteria. The verifier also checks
that beams and lamps do not interrupt the central throne sightlines.

## Land, floor and encounter

Pivot **45 × 35**, origin **(0,0,0)**, horizontal bounds **x 0…44, z 0…34**;
unused box cells explicitly write air. Heights remain 33 / 38 / 34.
The DESIGN allocation stays **304** outer-band columns, **805** hall columns,
**120** hall-wall columns and **346** foyer/service/circulation columns: 1,575.
The pass-1 split adjustment remains: rear circulation moves to the foyer.
The wall-bounded hall is x 4…40, z 8…32, the foyer z 2…7, and the side strips
x 2…3 / 41…42; there is no rear ground corridor.

Hall interior: **x 5…39, z 9…31**, main floor at y 2. The **15 × 7 dais** is
x 15…29, z 25…31, with stair rows at `(y 3,z 25)` and `(y 4,z 26)`.
Approach stairs remain at `(y 1,z 1)` and `(y 2,z 2)`. The carpet stops at z 24.
All stairs face north at turn 0 and have half-node treads.

**784 reachable authored floor columns in A**, excluding furniture tops and
roofs: 805 minus four seats, 15 throne-base columns and two lamp-support columns.
That is **+100 / 14.6%** against DESIGN’s 684-column baseline. B/C retain 778. The checker's
Kezamba floor measurement was 406 against DESIGN's quoted 402; this proposal
exceeds either. Neither old floor measurement was rerun here.

The **29 × 15 = 435** central rectangle (x 8…36, z 10…24) stays clear at feet
and head height. There are no floor pillars in it. Both sides of the dais are
open. The king and throne guards have empty feet/head and solid support.
Upper towers and lanterns are architectural volumes, not playable floors.
Existing combat rules, chase/leash and rewards are outside this tooling lane.

## Throne and node handoff

**No new CASTLE nodes or textures.** A’s dimensions and body clearance are
recorded above. B/C retain the **7 × 3 × 10** body at x 19…25, z 28…30,
y 5…14, the **5 × 2** seat at y 6, arm caps at y 9 and ornaments at y 12.
All three keep the bronze frame and culture-specific cloth. The back at
z 30 retains a clear row at z 31 before the wall.

New to this composition, but already registered and offered by the editor:
`grug_materials:bronze_block` and `grug_materials:slab_bronze_block`.
Existing `rug_accent` supplies culture-specific upholstery; `rug` and
`rug_accent` supply the recessed runner. No thin carpet or new interaction.

The five selected GUILD full blocks still appear exactly once each, at
**(x 20…24, y 10, z 30) in A**, and y 12 in B/C, in Iron → Steel → Silversteel → Embersteel → Abyssal
Steel order. Their ids are `grug_guild:ornamented_iron`, `ornamented_steel`,
`ornamented_silversteel`, `ornamented_embersteel`, `ornamented_abyssal_steel`.
These are the same pending GUILD dependencies as pass 1, not new throne parts.
[preview_nodes.json](preview_nodes.json) provides static preview definitions;
the selected textures come from `tools/r70_art/candidates/final/` as directed
by ART's INSTALL. GUILD/CAPITALS must install them and update the live registry
and editor palette. All light comes from existing static Emberglass nodes;
there are no flame nodes, timers, containers or construction callbacks.

## Socket coordinates — all forms and races

The installation socket table is also in [INSTALL.md](INSTALL.md).
All coordinates and socket ids/roles/faces/tags are unchanged. +x is east,
+z north; all coordinates below are turn 0.

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

Entrance points: approach `(22,1,0)` face 2; hall arch `(22,3,8)` face 2;
west service `(4,3,20)` face 3; east service `(40,3,20)` face 1.
The `inside` point remains `(22,3,12)`.

Use native `parts.stamp`, pivot 45,35. Local coordinate maps are `(x,z)`,
`(z,44−x)`, `(44−x,34−z)`, `(34−z,x)`; face gains turns modulo 4.
Odd turns produce a 35 × 45 box, even turns 45 × 35. Kezamba faces north with
turn 2. Placement anchors remain CAPITALS work.

## Verification and limits

**Final pass-3 run: `build.py --check` PASS, `verify.py` PASS,
`git diff --check` PASS.**

- `python3 tools/r70_castle/build.py --check`: byte reproduction of all 18
  templates, palettes, node inventories, metrics, preview definitions and page;
  hashes cover still inputs, the light model and all 18 PNG outputs.
- Both existing Python parsers and the real LuaJIT template reader: **18/18**.
  Native `templates.part` / `parts.stamp`: **72/72** turns, bounds, full-air
  boxes, socket coordinates/faces and support. No changed Lua files.
- Editor palette allowlist: all entries pass except the explicitly pending
  five GUILD definitions. No fixed-air entry, named-wall stairs or door leaves.
  Approach flood fill reaches all sockets; 435-column battle rectangle clear.
- `python3 tools/r70_castle/verify.py`: the new A seat/body/arm dimensions,
  five top ornaments, seven complete sightlines (seat, back and all stones),
  full king/guard body clearance in all six palettes; light probes, all 18
  light banks and dark regression; inline JS syntax, no external references,
  texture and 18 PNG/WebP decoding; **24 geometry exports**, including all six
  current halls. Two Node exporters maximum.
- Eighteen 1200 × 900 PNGs: approach, hall bright, hall night, entrance, throne
  and top cutaway for each form. Representative images visually inspected.
- Comparison with `ce9da517`: 73 changed resolved cells per A palette, all
  inside the old throne box; dais and socket points unchanged. All twelve
  B/C templates and twelve B/C PNGs byte-identical. Documentation links resolve.
- `git diff --check`: no whitespace errors. Changes stay in `tools/r70_castle/`.

The generator's walk check is a **cell flood fill**, with two clear cells and
steps of at most one node; it treats stairs as blocks. It is not an engine
collision/pathfinder simulation. Opus's pass-1 checker used real collision
boxes and confirmed half-tread walking, every socket and the king body in all
72 stamps; that result belongs to `b20cee75`, not this delta. Current support,
air cells, stair types and approach reachability are checked as described above.
Pass 3 adds the conservative full-body box check against occupied cells at
turn 0; it is static clearance, not a new runtime pathfinding proof.

Browser smoke testing remains unavailable here: Chromium with a writable
`/tmp` profile exits before loading with `setsockopt: Operation not permitted`.
No pass-3 browser/mobile acceptance is claimed; the pass-2 browser restriction
was not retried. The checker ran the pass-1 page successfully in Chromium.
The full integration gate still needs the final
roster, boxes/points baseline, roof binding and installed GUILD nodes in CAPITALS
as detailed in [INSTALL.md](INSTALL.md);
the lane has not run a server, real combat, runtime pathfinding or a seed fleet.

**Desktop/web GUI checklist for the user and CAPITALS:** inspect all palettes
at night and by day; approach and cross the open arch; recognize the throne
from the far end and inspect its seat/arms; walk the two stair pairs without
jumping; verify king/guards return to their sockets; check ten-player movement
and boss combat; check phone controls and light/dark page layout.

## Publication, provenance and commits

The local page is ready for the coordinator/user to publish. No hosted page or
push is claimed. The lane's no-push rule remains in effect; no publication
permission is needed to finish this local delivery.

The shared building viewer and its node geometry are reused unchanged on disk.
Three.js r147 (MIT) and the Round 69 orbit controller are embedded. The offline
rasterizer reuses Round 69's textured triangle rasterization. Existing media
retain repository licences; the selected Stonewright faces retain ART's
GPT-6 Astra / CC0-1.0 provenance. No downloaded assets or image generator.

Pass-1 checkpoints remain `8c7b4716`, `4825f97f`, `dc8d90dd`, `b20cee75`.
Pass-2 code/artifacts: **`17514410`**; measurement/limits report: **`ce9da517`**.
Pass 3 carries `Co-Authored-By: GPT-6 Astra <noreply@openai.com>`.
The final response names the final commit; retrieve the report's commit with:

```sh
git log -1 --format=%H -- tools/r70_castle/REPORT.md
git status --porcelain
```
