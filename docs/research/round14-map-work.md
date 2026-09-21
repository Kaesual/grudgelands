# Round 14 map implementation record

The atlas is a dedicated `sfinv` Map page with one whole-world view and six
bounded home-region views. Its shipped PNG backgrounds are generated from the
authored control geometry in `wp40/source/simple_map.lua`; generation loads no
mapgen session, world or chunks. The backgrounds contain coastline-scale land,
roads and zone names. Runtime settlement and player markers remain separate
formspec controls, with hover labels and click details.

`grug_map.atlas` owns the shared view definitions, world-to-screen transform
and marker-provider registry. The built-in settlement provider reads
`grug_core.settlement_socket_settlements()`, so all fitted positions—including
the Round 14 village, outpost and bandit-camp anchors—come from runtime world
authority. Presentation labels are keyed by stable settlement identity; no
position is duplicated. The player provider samples the current live position
when the page renders. Neither provider changes travel or visit state.

Regenerate the gallery from the repository root with:

```sh
for view in world dwarf human elf undead orc troll; do
  luajit tools/r14_map/render_atlas.lua "$PWD" "/tmp/grug_map_atlas_${view}.svg" "$view"
  convert "/tmp/grug_map_atlas_${view}.svg" -resize 900x800 \
    "mods/PLAYER/grug_map/textures/grug_map_atlas_${view}.png"
done
```

The generated art uses only original project geometry and system fonts; it
adds no third-party media or attribution requirement.

Candidate gates passed: plain Lua 5.1 parsing, changed-file `SETGLOBAL`
inspection, all five Lua source sweeps (including `tools/r14_map`), the
portable LuaJIT transform/provider/page fixture, `git diff --check`, and visual
inspection of the seven-image gallery. The gallery is a macro-scale diagram
from unwarped authored control geometry. It claims no exact terrain contour or
player-built terrain; live anchors and the player marker use the actual fitted
runtime coordinates over that diagram.

At whole-world scale the raster uses nine well-spaced overview labels: six
culture lands, the contested front and the two edge islands. The six bounded
region rasters retain the complete local zone names; settlement names remain
runtime marker tooltips and click details in every view.

The page content begins with `real_coordinates[true]`. `sfinv.make_formspec`
places its legacy-coordinate navigation before that content, so navigation
keeps its native layout while the atlas image, marker buttons and transform all
use the same real-coordinate unit system.
