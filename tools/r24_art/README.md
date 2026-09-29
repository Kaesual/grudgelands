# Round 24 rock and ore art (Lane C)

`build_rock_ore_textures.py` builds the 18 stored textures of Round 24
rulings 8, 16 and 17 into `mods/ITEMS/grug_materials/textures/`:

- `grug_materials_t2_stone.png` … `t6_stone.png`: `default_stone.png`
  darker, cooler and more cracked per tier;
- `grug_materials_slate/basalt/granite.png`: re-graded VoxeLibre rocks;
- `grug_materials_mineral_<key>.png`: transparent ore/gem overlays for the ten
  `grug_materials` resource nodes, drawn over `default_stone.png` at runtime.

Needs Python 3 and Pillow. VoxeLibre sources are read from
`reference_projects/VoxeLibre/textures`; in a worktree whose submodule is not
checked out, pass the main checkout's copy with `--voxelibre DIR`. All inputs
are pinned by SHA-256.

    python3 tools/r24_art/build_rock_ore_textures.py --voxelibre DIR            # write
    python3 tools/r24_art/build_rock_ore_textures.py --voxelibre DIR --check    # verify
    python3 tools/r24_art/build_rock_ore_textures.py --voxelibre DIR --renders  # + sheets

`--renders` (`render_sheets.py`) writes offline comparison sheets to
`docs/research/round24-art/`: `tier-rocks.png`, `decorative-rocks.png`,
`ores-gems.png` (before = today's texture-modifier tiles, emulated). They are
nearest-neighbour previews with simple cube shading, not engine screenshots.

Provenance and licences: `mods/ITEMS/grug_materials/LICENSE-media.md` §9.
