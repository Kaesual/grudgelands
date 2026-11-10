# Guild table study — 2026-11-10

**Proposal only; compatible tools-only change.** No game node, template, generator,
NPC socket or persisted world data was changed. The worktree is
`character-creation`. Main's six guild templates, hall generator and two existing
table definitions matched this worktree when inspected. Expedition gameplay is
being developed separately on main and was not edited here.

Open `index.html` for the rendered comparison or `scenes.html` for the offline,
self-contained interactive viewer (all six guild houses, before/after). The viewer
uses the existing shared `tools/building_templates/viewer/renderer.js`, the real
node registry and actual capital roster palette bindings. Roof/walls above y=2
are cut away deliberately. Grey figures are **1.70-node scale references**, not
renderings of the live NPC or promises about race-specific appearance. The
isolated detail pair rotates the real arrangements into a common front view;
the six guild scenes retain actual template coordinates.

## Confirmed geometry

The floor's upper face is y=0.5. Every guild has the same arrangement, confirmed
from all six parsed templates in `audit.json`:

| Furniture | Placement | Surface above floor | Problem |
| --- | --- | --- | --- |
| Clerk / Expedition Registrar | fence (2,1,7), lower-half slab (2,2,7) | 1.50 nodes | Plate is 0.50 thick and obscures much of a standing figure |
| Exchange | center plate (8,1,7), posts (8,1,6)/(8,1,8) | 1.00 node | Upside-down slab; floor below its middle is empty; adjacent posts do not meet it |
| Stonewright | center plate (4,1,11), posts (4,1,10)/(4,1,12) | 1.00 node | Same unsupported slab arrangement |
| Leader | center plate (5,1,14), posts (4,1,14)/(6,1,14) | 1.00 node | Same unsupported slab arrangement |

A fence post is only 0.25 nodes wide. Its center is one node from the adjacent
slab center: there is **0.375 node horizontal separation** from its side to the
slab edge, unless another connecting shape bridges it (these do not). This is
not just a texture or lighting issue.

Sources:

- `tools/r58_halls/make_halls.py:263–289`: `counter()` stacks a post and slab;
  `desk()` deliberately places the inverted slab **between** posts in the same
  course. The earlier height correction created the unsupported appearance.
  This generator remains the declared owner in each guild template's header;
  future changes should edit it and regenerate only the intended outputs.
- `mods/MAPGEN/grug_mapgen/building_templates/templates/highcourt_miners_guild.tpl:77–79`:
  furniture legend; layers 1/2 contain the actual writes, `:441–444` the NPC sockets.
  The other five `*_miners_guild.tpl` files use identical furniture coordinates.
- `mods/PLAYER/grug_expeditions/registrar.lua:18,48–51`: the Registrar takes over
  `miners_guild/miners_guild_clerk`, so the too-high table is the clerk counter.
- `mods/BASE/default/functions.lua:336–356`: visible fence post and rail boxes.
- `mods/MAPGEN/grug_mapgen/wp13/palette.lua`: `table_top` is wood for Humans,
  Dwarves, Orcs and Trolls, silver sandstone for Elves, obsidian brick for Undead.

## Existing thin tables, and recommendation

There are already complete one-node tables with a post-like central leg. They
can look like separate fence + thin-board assemblies, but are single nodes.

- `grug_decor:cottages_table` (`mods/ITEMS/grug_decor/cottages.lua:556–579`) is the
  human/orc `board_table` palette role (`palette.lua:237,593`) and is explicitly
  used in camp templates. Human examples include `dawnmere_harvest_inn.tpl`,
  `dawnmere_meeting_hall.tpl`, `highcourt_market_counting_house.tpl`.
  Its plate is about **0.08 nodes thick**, but its definition has reversed Y
  corners (0.48 → 0.40) and a **0.10-node gap** above the leg (ends at 0.30).
  Reusing it unchanged would retain a smaller floating-top defect.
- `grug_decor:xdecor_table` (`mods/ITEMS/grug_decor/xdecor.lua:104–119`) is already
  the undead `board_table` (`palette.lua:484`), used in such templates as
  `nhal_veyr_vigil_hall.tpl` and `nhal_veyr_vigil_scriptorium.tpl`.
  Its top is **0.125 nodes thick**, its leg meets its underside exactly, and its
  total height above the floor is **1.00 node**.
- `grug_decor:capital_counter` (`capital.lua:27–30`) is another existing option:
  four legs, 0.25-thick top, 0.85 total height. It does not have the requested
  thin-board/pedestal appearance, so it is not the proposed rendering.

**Rendered proposal:** reuse `grug_decor:xdecor_table` at y=1 in the six guild
houses. Replace the Registrar's two stacked cells with one table; replace each
three-cell low desk with three adjoining tables. The result has a continuous
three-node top over three attached legs, within the same floor footprint.
It uses the existing warm wood texture for all six houses; current elf/undead
stone tops would therefore become wood. No new node or texture is needed.

Keep this first change local to the six guild houses. `table_top` occurs in
**159 templates**, while `board_table` occurs in 17. A global palette change
would affect unrelated counters and structures; merely swapping the slab role
cannot correct where the supporting cells were placed. A wider furniture pass
should inspect and replace complete assemblies deliberately.

## Rebuild and checks

```sh
python3 tools/capital_polish_study/tables/build.py
node tools/character_creation_preview/render-scenes.mjs \
  --directory "$PWD/tools/capital_polish_study/tables" --width 1400 --height 900
python3 tools/capital_polish_study/tables/gallery.py
```

`build.py` reads six shipped templates, asserts one high counter plus three low
slab desks per house, checks ten unique furniture footprint cells and rejects
missing nodes/media. `audit.json` records exact source hashes and resolved nodes.
The renderer uses an isolated disposable browser profile; PNG receipts record
input/output hashes and camera. All 14 renders completed without script errors.
The two detail images and both Human room images were visually inspected.

No native gameplay/pathfinding test is claimed. If the proposal becomes a
shipped template/generator change, it changes world generation: **map reset by
default**, unless an explicitly authorized existing-box migration is designed
and tested under the upgrade contract. This study does not create that exception.

Media provenance is unchanged: game textures retain their owning mod's media
licenses (`mods/BASE/default`, `mods/ITEMS/grug_decor`, `mods/PLAYER/grug_guild`,
`mods/MAPGEN/grug_mapgen` and `mods/ITEMS/grug_materials`). Renderer/Three.js
provenance is included in the offline scene page and the existing tools licenses.
