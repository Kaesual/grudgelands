# Round 45 A2 — Crafting stations

Fifteen original, AI-assisted, one-node designs by **GPT-6 Astra**,
2026-10-09: three choices for each of five professions' stations. The
existing forge/anvil is the reference and stays unchanged.

## The user's pick (2026-10-09) and what ships

| Station | Pick | Node | Tiles |
| --- | --- | --- | --- |
| Tanning rack | **B**, stretching trestle | `grug_jobs:tanning_rack` | `grug_jobs/textures/grug_jobs_tanning_rack_<face>.png` |
| Tailor bench | **B**, pattern table | `grug_jobs:tailor_bench` | `grug_jobs/textures/grug_jobs_tailor_bench_<face>.png` |
| Carving bench | **B**, sculptor's stump | `grug_jobs:carving_bench` | `grug_jobs/textures/grug_jobs_carving_bench_<face>.png` |
| Jeweller's bench | **A**, gem setter's bench | `grug_jobs:jewellers_bench` | `grug_jobs/textures/grug_jobs_jewellers_bench_<face>.png` |
| Brewing stand | **B**, apothecary bench | `grug_brewing:brewing_stand` and `_active` | `grug_brewing/textures/grug_brewing_stand_<face>.png` |

`<face>` is `top`, `bottom`, `right`, `left`, `back`, `front`. The picked
design's boxes are the node's `node_box` verbatim (in
`mods/PLAYER/grug_jobs/station_visuals.lua` and
`mods/ITEMS/grug_brewing/node.lua`); no station defines a separate selection
or collision box, so both follow the node box. Node names, groups, sounds,
the dig refund, station sounds and the job station lookup are unchanged;
stations already placed in the capitals only change their look. The lit
brewing stand (`grug_brewing:brewing_stand_active`) has the same boxes and
tiles and shows its state by glowing (`light_source` 6). The old loom and
brewing-stand textures are removed.

[final_sheet.png](final_sheet.png) renders the five stations from the
registered game nodes (loaded through `tools/wp13/stub_registry.lua`) with the
same renderer; each view is pixel-identical to the picked proposal's view.

The proposal sheets below stay as the record of the choice; every design's
`design.lua` stays as its geometry record. The per-design tiles and views are
not kept as files (the generator rebuilds them in a scratch folder).

**Upgrade classification: compatible.** Looks only: no node, item or saved
state changes.

## The sheets

The upper row is front-left, the lower row back-right. Every view uses
the same 30-degree elevation, perspective camera, node scale and lighting.
The pale floor square marks one node and is presentation-only.

| Station / comparison sheet | A | B | C |
| --- | --- | --- | --- |
| [Tanning rack](tanning_rack/sheet.png) | **Laced hide:** a full hide laced into an open upright oak frame on long feet. | **Stretching trestle:** a low open stretching bed with a flat russet hide and a broad scraper. | **Twin drying rail:** two narrow pale hides hang from a divided rail above a leather-working shelf. |
| [Tailor bench](tailor_bench/sheet.png) | **Open cloth loom:** an open oak loom shows ivory warp above teal cloth, with a spool at its foot. | **Pattern table:** a broad cutting table carries folded plum cloth, shears and an upright thread spool. | **Bolt and spindle:** a low cloth-roll cradle pairs a hanging teal bolt with a tall exposed spindle. |
| [Carving bench](carving_bench/sheet.png) | **Vise workbench:** a braced oak bench holds a clamped timber blank, a mallet and a steel chisel. | **Sculptor's stump:** a bark-covered chopping stump supports a stepped wooden carving and two upright gouges. | **Shaving horse:** a narrow shaving horse grips a long timber under raised jaws, with its drawknife across the front. |
| [Jeweller's bench](jewellers_bench/sheet.png) | **Gem setter's bench:** a notched walnut bench presents a green work mat, bench peg, tiny hammer and bright cut gems. | **Assayer's balance:** a brass balance with two suspended pans stands above a drawer, a cut gem and fine tools. | **Lapidary wheel:** an upright stepped grinding wheel rises over a low bench with a gem tray and copper tool rest. |
| [Brewing stand](brewing_stand/sheet.png) | **Copper retort:** a copper still feeds a blue receiver through a squared swan-neck pipe above a small burner. | **Apothecary bench:** a compact two-tier bottle shelf backs a working flask and warm copper burner. | **Suspended flasks:** an iron gantry suspends teal and violet flasks above two burners on a stepped stone plinth. |

[Today's anvil, rendered by the same tool](anvil_reference.png).

The warm woods, dark metal and restrained pixels use the existing game's
palette and scale as a visual guide. Teal, plum and pale fabric distinguish
tailoring; small cyan/ruby/violet gems identify jewellery; copper and
painted glass distinguish alchemy. The designs serve both The Accord and
The Throng without faction-specific decoration.

## Files and reproduction

Each `<station>/<A|B|C>/design.lua` is a literal
`return {boxes = {...}, tiles = {...}}` table whose six tiles were named
`grug_r45_a2_<station>_<a|b|c>_<face>.png` (16×16 RGB) in its folder. The
five `sheet.png` files are **1088×910 RGB**, `anvil_reference.png` is
**736×472 RGB** and `final_sheet.png` is **1784×910 RGB**.

Run with Python 3, Pillow and LuaJIT installed, from the repository root:

```sh
python3 tools/r45_a2/generate.py
python3 tools/r45_a2/generate.py --check
bash tools/check_lua.sh tools/r45_a2/*/*/design.lua
```

The generator builds all fifteen designs (Lua tables, 90 tiles, 30 views) in
a temporary folder, then writes the 15 `design.lua` files, the six sheets,
the 30 picked tiles under their game names and `final_sheet.png`. `--check`
writes nothing and compares all of them byte for byte, rejecting extra or
missing files. `designs.py` owns the authored geometry; `generate.py` owns
pixel painting, the six-tile bake and the picks (`PICKS`); `render.py` owns
the renderer, original caption alphabet and sheet layout.
`tools/r45_art/portable_test.lua` checks in the game registry that every
station's boxes lie within the node, its tiles exist and match the pick.

## How the renderings correspond to the game

All boxes fit inside **−0.5…0.5** on all three axes. The front is **−Z**,
with tile order **+Y, −Y, +X, −X, +Z, −Z**. Each design has exactly six
shared tiles with filenames relative to its folder; every basename is
unique across the proposals. The picked `boxes` are used directly as fixed
node boxes; the tiles ship under the game names above.

The renderer **re-reads the exported Lua table and PNGs**. It never sees the
authoring materials assigned to individual boxes. Native node-coordinate
UVs are used throughout, so a thin box samples a slice of a tile rather
than stretching a complete image over each face. UV orientation and tile
ordering were checked against the pinned engine at `df0487906`:

- `reference_projects/luanti/src/client/content_mapblock.cpp:140-193`,
  `setupCuboidVertices`.
- The same file, lines 345–367, `generateCuboidTextureCoords`.
- The same file, lines 1581–1706, `drawNodeboxNode`.
- `reference_projects/luanti/src/client/imagesource.cpp:1238-1275`,
  counter-clockwise `transformR90` for the existing anvil top.

The atlas bake resolves overlapping material projections into those six
tiles. Some colour sharing between surfaces is intrinsic to fixed node
boxes and is visible in the previews. Rendering subdivides visible faces
at texel and box boundaries, removes internal patches, samples textures
with nearest-neighbour sampling and paints far-to-near. All edges remain
unsmoothed. The directional shade is illustrative; engine lighting will
depend on the placed station's surroundings.

The anvil's geometry and tile list are loaded from the current
`mods/PLAYER/grug_jobs/station_visuals.lua` through one short LuaJIT call;
the renderer applies its existing top rotation. Neither reference geometry
nor texture pixels are duplicated as a new source of truth.

All new tiles are opaque, including painted glass. Each proposal uses
**13–27 boxes**, with no entities, animation, particles or runtime effects.
The burner colours are static pixels. Proximity rules and the absence of a
station dialog remain the production code's responsibility.

## Proposal-lane verification (2026-10-09)

The proposal lane checked all 15 tables with `tools/check_lua.sh` (269
positive boxes within the node, all 90 tiles 16×16 RGB), `generate.py
--check`, a visual inspection of all 30 views and the anvil comparison, and
one full fixture run (145 passed).

## Provenance and licences

The new pixel textures, geometry designs, caption glyphs and proposal
renderings are original, **CC0 1.0 Universal**. Python generators are
**GPL-3.0-or-later** under the repository's code licence. Tools used:
Python/Pillow, GPT-6 Astra assistance and LuaJIT for the local reference
table; no downloaded material, external font, image-generation service or
third-party source pixels in the new proposals.

The separate **anvil reference** retains **CC BY-SA 4.0**. It renders
the three existing local `grug_jobs_anvil_*.png` textures, credited to
**XSSheep / Pixel Perfection and VoxeLibre contributors**, and the existing
node boxes. Source:
[VoxeLibre at the recorded import commit](https://github.com/VoxeLibre/VoxeLibre/tree/c2dbc520ff4e1637072d33b06c3a2404e0f08df7).
Changes for that reference are perspective projection, the existing top
rotation, directional shading and the caption layout. The reference sheet
is distributed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

The shipped tiles' licence rows are in
[grug_jobs/LICENSE-media.md](../../mods/PLAYER/grug_jobs/LICENSE-media.md#round-45-station-tiles)
and [grug_brewing/LICENSE-media.md](../../mods/ITEMS/grug_brewing/LICENSE-media.md);
the existing upstream attribution is in [CREDITS.md](../../CREDITS.md). The
sheets and `design.lua` files here are CC0 1.0 like the tiles; the anvil
reference keeps CC BY-SA 4.0 as described above.
