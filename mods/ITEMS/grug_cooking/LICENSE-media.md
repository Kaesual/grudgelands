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

The exact deterministic mapping is `tools/r10_art/import_harvest_icons.sh`.
Every output is a byte-preserving copy except Fire Pepper's documented baked
red grade.

| Output concept | Pinned source | Author | License | Treatment |
|---|---|---|---|---|
| Wild Grain | `farming` `1a918c7a`, `textures/farming_wheat.png` | VanessaE | CC BY 3.0 | copy |
| Carrot | `farming` `1a918c7a`, `textures/farming_carrot.png` | Gambit | CC BY 3.0 | copy |
| Cassava | `farming` `1a918c7a`, `textures/farming_potato.png` | Doc | CC BY 3.0 | copy |
| Wild Onion | `farming` `1a918c7a`, `textures/crops_onion.png` | Oz-tal | CC BY-SA 3.0 | copy |
| Fire Pepper | `x_farming` `ac5f69d5`, `textures/x_farming_carrot.png` | SaKeL | CC BY-SA 4.0 | `#c02018` 40% baked colorize |
| Pumpkin | `x_farming` `ac5f69d5`, `textures/x_farming_pumpkin_mash.png` | SaKeL | CC BY-SA 4.0 | copy |
| Blightberry | `farming` `1a918c7a`, `textures/farming_blackberry.png` | Felfa | CC0 1.0 | copy |
| Sunberry | `farming` `1a918c7a`, `textures/ethereal_strawberry.png` | Hugues Ross | CC BY-SA 4.0 | copy |
| Jungle Berry | `farming` `1a918c7a`, `textures/farming_grapes.png` | Oz-tal | CC BY-SA 3.0 | copy |
| Frost Melon | `x_farming` `ac5f69d5`, `textures/x_farming_melon.png` | SaKeL | CC BY-SA 4.0 | copy |
| Sugar Cane | VoxeLibre `c2dbc520`, `textures/mcl_core_reeds.png` | XSSheep / VoxeLibre contributors | CC BY-SA 4.0 | copy |
| Bamboo Shoot | VoxeLibre `c2dbc520`, `textures/mcl_bamboo_bamboo_shoot.png` | XSSheep / VoxeLibre contributors | CC BY-SA 4.0 | copy |
| Cave Cap | `goblins` `ce27b15f`, `textures/goblins_mushroom_brown.png` | Francisco Athens | CC BY-SA 3.0 | copy |
| Salt Crust | `x_farming` `ac5f69d5`, `textures/x_farming_salt.png` | SaKeL | CC BY-SA 4.0 | copy |
| Ember Moss | `x_farming` `ac5f69d5`, `textures/x_farming_obsidian_wart_6.png` | SaKeL | CC BY-SA 4.0 | copy |

No foreign code, recipes, models or sounds were imported. The exact input and
output hashes are in `docs/research/r10-visuals/source-manifest.tsv`.
