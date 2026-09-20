# Media Origin and Licenses (grug_cooking)

R10 added fifteen plant harvest sprites. Round 12 preserves those ingredient
icons and replaces the generic runtime-colourized results with project art.

## Round 12 cooking results — CC0 1.0

The 18 `grug_cooking_dish_*.png` files, six `grug_cooking_raw_*.png` files and
`grug_cooking_bread.png` are original Grudgelands pixel art, authored as
explicit 16x16 geometry in `tools/r12_art/build_assets.py`. They are dedicated
to the public domain under CC0 1.0 Universal.

An OpenAI image-generation concept sheet informed the high-level vocabulary
(bowls, pots, platter, jar, mug and tied raw bundles), but no generated pixels
ship in game textures. The prompt and unmodified concept output are archived
in `tools/r12_art/`; the deterministic script is authoritative for every
shipped pixel. No foreign food asset was copied or traced.


## R10 plant harvest icons

The exact deterministic mapping is `tools/r10_art/import_harvest_icons.sh`.
Every foreign-source output is a byte-preserving copy. Fire Pepper is a
project-owned generated source with its exact prompt stored beside it, then
mechanically trimmed and downsampled by that script.

| Output concept | Pinned source | Author | License | Treatment |
|---|---|---|---|---|
| Wild Grain | `farming` `1a918c7a`, `textures/farming_wheat.png` | VanessaE | CC BY 3.0 | copy |
| Carrot | `farming` `1a918c7a`, `textures/farming_carrot.png` | Gambit | CC BY 3.0 | copy |
| Cassava | `farming` `1a918c7a`, `textures/farming_potato.png` | Doc | CC BY 3.0 | copy |
| Wild Onion | `farming` `1a918c7a`, `textures/crops_onion.png` | Oz-tal | CC BY-SA 3.0 | copy |
| Fire Pepper | `docs/research/r10-visuals/sources/fire-pepper-imagegen.png`; prompt beside it | Grudgelands project | CC0 1.0 | point-filter trim/downsample to 14×14; centered 16×16 extent; metadata stripped |
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
