# Six-culture facade study

Local proposal requested on 2026-11-10, based on main `0fd00949` (0.75.2).
Iteration 6 replaces the remaining sandstone window jambs on the orc home
with adobe: three cells beside each of its three windows. Corner supports,
base and roof stay unchanged, as do all eleven other proposals.
The original path and local URL remain valid. Main advanced independently to
`23f0f1b4` (0.75.3); the source templates, palettes and shared rendering inputs
used here still match the study base.

Worktree/branch: `study-dwarf-architecture`. **Compatible, tools only.**
No game version, shipped template, palette, runtime code or installed game changes.
No merge, push, map reset or world rewrite is part of this study. Adopting changes
to generated buildings later will need the normal map-reset release declaration.

## Open the comparison

Open `index.html` directly in a browser: it is self-contained and works offline.
Alternatively serve this directory on localhost:

```sh
python3 -m http.server 8874 --bind 127.0.0.1 --directory tools/dwarf_architecture_study
```

Choose a culture, then either of its two buildings. Desktop shows the actual
source template on the left and the proposal on the right, with coupled
orbit/pan/zoom cameras. On narrow screens switch between **Bestand** and
**Vorschlag** with the same camera. Presets show the entrance, side/gable, rear
and an interior cut. The layer slider follows each building's full height;
the interior cut is relative to its floor, including the raised troll house.
Clicking a block identifies its node and labels study-only reed shapes as
preview forms. The URL records the selected
building, for example `?building=elf_home`; the original `home` and `forge`
links still select the two dwarf buildings. The footer links to the complete
previous study in `iterations/iteration5.html`. Left remains the original game
building, right is the current proposal.

## Examples and proposed architectural directions

| Culture | Residential example | Larger example | Direction |
| --- | --- | --- | --- |
| Dwarf | Hearthpine west home | Hearthpine forge hall | Stone base and masonry, now also around the home entrance; gable and head course now use one warm wood tone, under dark slate. |
| Human | Dawnmere lane cottage | Dawnmere meeting hall | Red brick base and loam replacing the middle window piers on the home; the hall keeps its stone base and framing; the original wood roof for the house, the original red brick roof restored on the hall. |
| Elf | Lethariel plaza house (`dur_brannoc_lane_house`) | Silverleaf lore hall | Pale stone base, marble frames, silverwood infill and a restrained green head course; blue slate on the home, restored original silver sandstone brick roof on the lore hall. |
| Orc | Sunscar chief lodge | Sunscar armoury | Red stone base, original red sandstone supports and adobe infill, now replacing both jambs beside the home windows; existing flat roofs differentiated into an earthy inner surface and red masonry rim. |
| Troll | Kapok river stilt house | Kapok spirit lodge | Dark framing, rough red-brown jungle bark infill and brown reed roofing. The elevated house gets wood rather than masonry at its wall foot; the ground-level hall keeps a stone base. |
| Undead | Stillgrave keeper's house | Stillgrave bone works | Very dark green mottled masonry, mossy cobble plinth with dark basalt head course and framing and restored original obsidian brick roofing. The home keeps its dark wood gable; the workshop is masonry above too. |

The elf home deliberately demonstrates a **shared template**: it is also used
by a dwarf building, but the original scene is resolved with its actual
`lethariel.roster` elf binding. Other scenes use their actual start-town
placements, including roof and town channels; no original is recoloured to
make its proposal look better.

The revised examples await user feedback. Acceptance of a visual direction
is not authorization to implement the study in the game. Shared roles and their assignment in templates would be the later
implementation route; these material replacements are scoped to the twelve
selected examples, not a new global facade algorithm.

## Preserved content and material limits

Every cell position and orientation is unchanged. Drawtypes, node boxes and
collision boxes match for all replacements. Windows, doors, furniture, lights,
floors, paths, chimneys and building shapes are preserved. The troll house's
actual stilts and entrance steps remain untouched. Several templates reuse
roof roles for low ledges or entrance steps: these remain unchanged below the
actual roof level in the new examples.

All textures are existing game assets. Four **preview-only reed shapes** in
`preview_materials.py` copy the existing junglewood stair, inner corner, outer
corner and slab geometry and use the existing `cottages_reet` texture. These
definitions live only in the browser registry; no Luanti nodes were registered.
The troll notes and node picker disclose this explicitly. Adopting these roofs
would require adding that shape family to the game. Other replacements use
existing registered nodes. Palette choices and materials are shown alongside
each example. No new raster art was created.

No additional objects were added to improve the comparison. These isolated
scenes contain the templates' authored contents; later town furnishing passes,
surrounding landscape, NPCs and terrain context are not included.

## Source and rendering

`build.py` reads the actual templates and their placements from
`mods/MAPGEN/grug_mapgen/building_templates/`. `cultures.py` owns the ten added
proposals and their presentation copy. The existing template parser, game
palette resolver, pane settlement, node registry and
`tools/building_templates/viewer/renderer.js` are used without changes.
Original and proposal use the same camera, lighting and display settings.

This is a Three.js approximation, **not a Luanti screenshot**. The shared
renderer approximates lighting and ignores node colour palettes; see its
[limitations](../building_templates/viewer/README.md#what-the-page-approximates).
Game asset provenance is unchanged; see
[grug_decor media licences](../../mods/ITEMS/grug_decor/LICENSE-media.md),
[CREDITS](../../CREDITS.md) and [VENDOR](../../VENDOR.md).
Three.js's licence is embedded in the page, using the existing offline bundle.
The engine-owned `blank.png` is read from the pinned Luanti reference checkout
(from the main checkout when building in a worktree).

## Rebuild and verification

```sh
python3 tools/dwarf_architecture_study/build.py
node tools/dwarf_architecture_study/check_browser.mjs
```

Build requires Python 3, Pillow, LuaJIT and the initialized Luanti reference
checkout. The browser check uses Node.js with built-in WebSocket and Chromium
(`CHROME` may override `chromium-browser`). It launches an isolated temporary
profile and removes it afterwards.

`audit.json` records the base commit, template/layout/shared-input hashes,
every changed cell, media results and page hash. It also records changes from
iteration 5, the archived audit hash and the four preview-only definitions. Build assertions verify:

- Exactly two examples per culture, twelve buildings and twenty-four scenes.
- Identical cell keys, param2, drawtypes, node boxes and collision boxes.
- Non-shell cells unchanged; missing or unsupported media fail the build.
- Only nine remaining sandstone jamb cells on the orc home change to adobe.
- All eleven other proposals remain unchanged, including the orc armoury.
- Both human, both undead and the elf hall roofs still match their original game nodes.

`iterations/iteration5-audit.json` is the comparison baseline. Earlier iterations
remain archived alongside it.
`dwarf-baseline.json` remains a historical receipt of the first dwarf study;
its material choices were superseded by the user's iteration 2 feedback.

`browser-check.json` records **143 successful browser checks**, no JavaScript
exceptions and **15 hash-matched captures**: twelve overview comparisons,
interior cuts for the dwarf forge and troll stilt house, and a narrow layout.
Every building is checked for actual mouse-driven camera coupling in both
directions, all presets, correct full-height and floor-relative cuts,
selection/URL state and decoded swatches. Additional checks cover clicking
navigation controls, node picking, narrow-screen switching/overflow, resizing
and loading a direct link to a new culture. The coordinator visually inspected all twelve iteration 2 overview captures
and a contact sheet of candidate block textures. The iteration 6 orc home
capture was regenerated and visually inspected by the coordinator.

The original dwarf study, the six-culture extension and iterations 2 through 5
passed independent review. Iteration 6 also received an independent **PASS**,
with no findings: exactly nine remaining window-jamb cells become adobe,
all other proposals are unchanged, and source/page/capture hashes and the
143-check browser receipt match. The reviewer visually inspected the new
orc home capture.

Delivery: the existing local server on port 8874 serves the expanded page; HTTP
200 verified. Main remains clean and the study remains in its own worktree; no
game sync, merge or push. No native desktop/web game acceptance is claimed. The
user chooses the design; a technical review does not approve the proposed
architectural direction.
