# Round 47 ART — Media provenance

## Original swamp textures

Made by **GPT-6 Astra**, 2026-10-13, for Grudgelands, from independently
authored pixel grids, palettes and deterministic material grain.
The project dedicates any rights it holds in these original assets and
their generator to **CC0 1.0 Universal (CC0-1.0)**:
<https://creativecommons.org/publicdomain/zero/1.0/>.
No downloaded material or third-party source pixels are used in them.

The initial ten textures' source is
[`tools/r47_art/swamp/generate.py`](swamp/generate.py), executed with
`python3 tools/r47_art/swamp/generate.py` using installed Pillow 12.3.0.
The additional olive leaves have their own complete source in
[`swamp/generate_leaves.py`](swamp/generate_leaves.py), executed with
`python3 tools/r47_art/swamp/generate_leaves.py` using the same Pillow version.
Its leaf clusters and six-colour palette are original; the generator is
also dedicated to CC0-1.0 and reuses the original sibling's CC0 label font.

| File | Author | Source / generator | License | Modifications |
| --- | --- | --- | --- | --- |
| `swamp/mud_dry_top.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/mud_dry_side.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/mud_mottled_top.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/mud_mottled_side.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/wet_grass_top.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/wet_grass_side.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/moss_carpet_top.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/reeds.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/cattails.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/hanging_moss.png` | GPT-6 Astra | [generate.py](swamp/generate.py) | CC0-1.0 | Original pixel art |
| `swamp/swamp_leaves.png` | GPT-6 Astra | [generate_leaves.py](swamp/generate_leaves.py) | CC0-1.0 | Original olive pixel art with wrapped clusters and binary alpha cutouts |

## Comparison sheet

| File | Author | Source / generator | License | Modifications |
| --- | --- | --- | --- | --- |
| `swamp/preview.png` | GPT-6 Astra (layout, font and new artwork); Calinou (papyrus); random-geek and Neuromancer (source dirt), Grudgelands contributors (mud recolour) | [generate.py](swamp/generate.py), with the two local references below | CC BY-SA 3.0 Unported for the comparison; the separately supplied original textures remain CC0-1.0 | Nearest-neighbour enlargement, repetition, alpha compositing on plain backgrounds and labels |
| `swamp/preview-leaves.png` | GPT-6 Astra (layout, font and original swamp artwork); PilzAdam (jungle leaves); Cisoun (leaves and source bark); Grudgelands contributors (gravewood bark recolour) | [generate_leaves.py](swamp/generate_leaves.py), local references below | CC BY-SA 3.0 Unported for the comparison; the separately supplied new leaves and other original textures remain CC0-1.0 | Grey colour interpolation for gravewood leaves, nearest-neighbour enlargement, repetition, plain-background compositing, front-view leaf-pad mock and labels |

The comparisons include existing media under **CC BY-SA 3.0 Unported**
(<https://creativecommons.org/licenses/by-sa/3.0/>); they are not entirely
CC0. The original work contributed to the comparisons is also offered
under that licence to distribute the combined sheets.

- **Papyrus:** Calinou,
  [`default_papyrus.png`](../../mods/BASE/default/textures/default_papyrus.png),
  CC BY-SA 3.0, source:
  <https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_papyrus.png>;
  nearest-neighbour scaling and compositing only.
- **Current mud:** Grudgelands contributors' olive recolour of
  `default_dirt.png`, by random-geek, derived from Neuromancer,
  CC BY-SA 3.0; local reference:
  [`grug_nodes_mud.png`](../../mods/ITEMS/grug_nodes/textures/grug_nodes_mud.png),
  original source:
  <https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_dirt.png>;
  the comparison only scales and repeats the existing recoloured asset.

The leaves comparison additionally reads these existing files locally;
their pixels occur only in the comparison, never in `swamp_leaves.png`:

| Local input | Author | Original source | Exact license | Use in comparison |
| --- | --- | --- | --- | --- |
| `mods/BASE/default/textures/default_jungleleaves.png` | PilzAdam | [Pinned source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_jungleleaves.png) | CC BY-SA 3.0 Unported | Labelled 1× and 8× samples on both backgrounds |
| `mods/BASE/default/textures/default_leaves.png` | Cisoun | [Pinned source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_leaves.png) | CC BY-SA 3.0 Unported | Grey `#858585` tint at 210/255, matching gravewood's registered modifier with nearest-integer rounding; original cutouts retained |
| `mods/ITEMS/grug_trees/textures/grug_trees_gravewood_tree.png` | Cisoun (source bark); Grudgelands contributors (recolour) | [Source bark](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_tree.png), [local derivation ledger](../../mods/ITEMS/grug_trees/LICENSE-media.md) | CC BY-SA 3.0 Unported | Existing dark recolour, enlarged in the palette comparison and repeated for the mock trunk |

The leaves comparison also uses GPT-6 Astra's `swamp/hanging_moss.png`,
`swamp/moss_carpet_top.png` and `swamp/wet_grass_top.png`, all independently
authored CC0-1.0 work recorded above, unchanged except for scaling and
compositing in the sheet.

Attribution and licence checked in the vendored
[`default/README.txt`](../../mods/BASE/default/README.txt),
[`default/license.txt`](../../mods/BASE/default/license.txt) and the
[`grug_nodes` media ledger](../../mods/ITEMS/grug_nodes/LICENSE-media.md).
The leaves comparison also uses the
[`grug_trees` media ledger](../../mods/ITEMS/grug_trees/LICENSE-media.md)
and the gravewood texture modifier in its `init.lua`.
Existing project attribution is also in [CREDITS.md](../../CREDITS.md).

## Original Anthracite textures

Made by **GPT-6 Astra**, **2026-10-13**, for Grudgelands. The project
dedicates any rights it holds in these six independently drawn textures
and their generator to **CC0 1.0 Universal (CC0-1.0)**:
<https://creativecommons.org/publicdomain/zero/1.0/>.
The shaft positions follow the required existing texture/UV interface;
the artwork, palettes, fracture grids and flame sequences are original.
No downloaded material, recoloured source pixels or traced flame frames
are used in the six textures.

Source: [`anthracite/generate.py`](anthracite/generate.py), run with
`python3 tools/r47_art/anthracite/generate.py` and installed Pillow 12.3.0.
Comparison labels reuse the original CC0 font in
[`swamp/generate.py`](swamp/generate.py).

| File | Author | Source / generator | License | Modifications |
| --- | --- | --- | --- | --- |
| `anthracite/anthracite_lump.png` | GPT-6 Astra | [generate.py](anthracite/generate.py) | CC0-1.0 | Original pixel art |
| `anthracite/mineral_anthracite.png` | GPT-6 Astra | [generate.py](anthracite/generate.py) | CC0-1.0 | Original transparent ore overlay |
| `anthracite/anthracite_torch_on_floor.png` | GPT-6 Astra | [generate.py](anthracite/generate.py) | CC0-1.0 | Original pixel art; frame 02 of the floor animation |
| `anthracite/anthracite_torch_on_floor_animated.png` | GPT-6 Astra | [generate.py](anthracite/generate.py) | CC0-1.0 | Original 16-frame animation in the existing floor layout |
| `anthracite/anthracite_torch_on_ceiling_animated.png` | GPT-6 Astra | [generate.py](anthracite/generate.py) | CC0-1.0 | Original 16-frame animation in the existing ceiling sheet layout |
| `anthracite/anthracite_torch_animated.png` | GPT-6 Astra | [generate.py](anthracite/generate.py) | CC0-1.0 | Original 16-frame animation in the existing diagonal wall sheet layout |

## Anthracite comparisons

These two comparison files include the existing artwork listed below,
under **CC BY-SA 3.0 Unported**
(<https://creativecommons.org/licenses/by-sa/3.0/>).
The original layout, labels and artwork contributed to the comparisons
are also offered under that licence to distribute the combined files.
This does not change the CC0 dedication of the six separate new textures.

| File | Author | Source / generator | License | Modifications |
| --- | --- | --- | --- | --- |
| `anthracite/preview.png` | GPT-6 Astra (new artwork, layout and font); Gambit (Coal lump); celeron55 (Coal ore); VanessaE (torches); Cisoun (stone); Grudgelands contributors (tier rocks) | [generate.py](anthracite/generate.py), local inputs below | CC BY-SA 3.0 Unported | Nearest-neighbour scaling, frame extraction, ore compositing on stone, plain backgrounds and labels |
| `anthracite/torch-compare.gif` | GPT-6 Astra (new artwork, layout and font); VanessaE (Coal torches) | [generate.py](anthracite/generate.py), three local animated torch inputs below | CC BY-SA 3.0 Unported | Nearest-neighbour scaling, shared palette quantization, labels and a 3.3-second loop |

Per-file comparison inputs, all read locally; no source media is downloaded
or copied into the new texture files:

| Local input | Author | Original source | Exact license | Use in comparison |
| --- | --- | --- | --- | --- |
| `mods/BASE/default/textures/default_coal_lump.png` | Gambit | [Pinned source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_coal_lump.png) | CC BY-SA 3.0 Unported | Scaled on plain backgrounds |
| `mods/BASE/default/textures/default_mineral_coal.png` | celeron55 / Perttu Ahola (README default attribution) | [Pinned source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_mineral_coal.png) | CC BY-SA 3.0 Unported | Scaled on plain backgrounds and composited on the three rocks |
| `mods/BASE/default/textures/default_torch_on_floor.png` | VanessaE | [Pinned source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_torch_on_floor.png) | CC BY-SA 3.0 Unported | Scaled on plain backgrounds |
| `mods/BASE/default/textures/default_torch_on_floor_animated.png` | VanessaE | [Pinned source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_torch_on_floor_animated.png) | CC BY-SA 3.0 Unported | Complete strips and extracted frames; GIF palette conversion |
| `mods/BASE/default/textures/default_torch_on_ceiling_animated.png` | VanessaE | [Pinned source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_torch_on_ceiling_animated.png) | CC BY-SA 3.0 Unported | Complete strips and extracted frames; GIF palette conversion |
| `mods/BASE/default/textures/default_torch_animated.png` | VanessaE | [Pinned source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_torch_animated.png) | CC BY-SA 3.0 Unported | Complete strips and extracted frames; GIF palette conversion |
| `mods/BASE/default/textures/default_stone.png` | Cisoun | [Pinned source](https://github.com/luanti-org/minetest_game/blob/b5243f3/mods/default/textures/default_stone.png) | CC BY-SA 3.0 Unported | Coal and Anthracite overlay composites |
| `mods/ITEMS/grug_materials/textures/grug_materials_t3_stone.png` | Cisoun; Grudgelands contributors (tier derivation) | [Local source and derivation ledger](../../mods/ITEMS/grug_materials/LICENSE-media.md#91-tier-rocks--cc-by-sa-30-unported-minetest_game-derivatives) | CC BY-SA 3.0 Unported | Coal and Anthracite overlay composites; existing tint/cracks unchanged |
| `mods/ITEMS/grug_materials/textures/grug_materials_t6_stone.png` | Cisoun; Grudgelands contributors (tier derivation) | [Local source and derivation ledger](../../mods/ITEMS/grug_materials/LICENSE-media.md#91-tier-rocks--cc-by-sa-30-unported-minetest_game-derivatives) | CC BY-SA 3.0 Unported | Coal and Anthracite overlay composites; existing tint/cracks unchanged |

Attribution was checked in the vendored
[`default/README.txt`](../../mods/BASE/default/README.txt) (including its
default attribution for unlisted media),
[`default/license.txt`](../../mods/BASE/default/license.txt) and the
[`grug_materials` ledger](../../mods/ITEMS/grug_materials/LICENSE-media.md).
These existing media authors are already named in
[CREDITS.md](../../CREDITS.md).
