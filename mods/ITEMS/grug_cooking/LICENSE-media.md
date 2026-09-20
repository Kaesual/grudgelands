# Media Origin and Licenses (grug_cooking)

R10 adds fifteen plant harvest sprites; raw assemblies and dishes continue to
use the existing runtime-colourized presentations below.

| Presentations | Runtime source file | Pinned source URL / repository path | Author chain | Exact licence | Modification |
|---|---|---|---|---|---|
| Bread, all raw assemblies and all Hearty dishes | `default_clay_lump.png` | <https://github.com/luanti-org/minetest_game/blob/b5243f3e42410ae3ca85ead795149406fa654538/mods/default/textures/default_clay_lump.png> | minetest_game contributors listed in `mods/BASE/default/license.txt` | CC BY-SA 3.0 Unported | Runtime colourize only |
| all Caster dishes | `default_apple.png` | <https://github.com/luanti-org/minetest_game/blob/b5243f3e42410ae3ca85ead795149406fa654538/mods/default/textures/default_apple.png> | minetest_game contributors listed in `mods/BASE/default/license.txt` | CC BY-SA 3.0 Unported | Runtime colourize only |
| all Hunter dishes | `grug_mobs_item_raw_fish.png` | `mods/ENTITIES/grug_mobs/textures/grug_mobs_item_raw_fish.png`; generator `tools/gen_mob_item_textures.py:748`; owning ledger `mods/ENTITIES/grug_mobs/LICENSE-media.md:284` | Grudgelands project | CC0 1.0 | Runtime colourize only |

The complete minetest_game attribution and licence text remain in
`mods/BASE/default/license.txt`. These derived presentations remain under the
same licence as their respective source.


## R10 plant harvest icons

The fifteen `grug_cooking_<plant>.png` files are byte-preserving selections
from the pinned allow-list documented in `grug_farming/LICENSE-media.md`:
`farming` `1a918c7a`, VoxeLibre `c2dbc520`, x_farming `ac5f69d5`, and goblins
`ce27b15f`. Exact source-to-concept mappings are recorded by
`tools/r10_art/import_crop_stages.sh` and `docs/research/r10-visuals.md`;
licenses remain their upstream per-file CC0, CC BY, CC BY-SA 3.0 or CC BY-SA
4.0 terms. No foreign code, recipes, models or sounds were imported.
