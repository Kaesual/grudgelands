# Media Origin and Licenses (grug_gathering)

WP33 shipped no copied or generated media files (later rounds below add some). Every inventory image and
source-node tile is a runtime colorized derivative of media vendored in
`mods/BASE/default` from minetest_game commit `b5243f3`. The originals and
their complete attribution are in `mods/BASE/default/license.txt`; the image
assets used here are CC BY-SA 3.0 Unported and the runtime derivatives retain
that license.

| Gathering presentation | Vendored source image |
|---|---|
| Gravemoss | `default_fern_1.png` |
| Dragonweed, Corn | `default_dry_grass_2.png`, `default_dry_grass_3.png` |
| Crimson Lotus, Marshbloom, Stormkelp | `default_marram_grass_1.png`, `default_marram_grass_2.png`, `default_marram_grass_3.png` |
| Sunleaf | `default_grass_3.png` |
| Potato, Rock Salt | `default_clay_lump.png` |
| Melon | `default_apple.png` |
| Mushroom, Wild Cocoa | `default_pine_bush_sapling.png` |

Node sounds reference the unchanged default leaves sound set. Its
CC BY-SA 3.0, CC BY 3.0 and CC0 notices remain in the same vendored license
file. No external plant asset is imported by WP33.

## R10 farmable staple inventory icons

`grug_gathering_potato.png` and `grug_gathering_corn.png` are byte-identical
renames of `x_farming_potato.png` and `x_farming_corn.png` from x_farming
`ac5f69d5103d4af841b1a5ed3a0b49a4e19d0c84`, media CC BY-SA 4.0. They replace
clay/grass texture expressions only; source nodes and gathering behavior are
unchanged.

## Round 48 placeholders (until the plant art pick)

Placeholders under the plant art plan's target names
(`docs/planning/plant-art-plan.md` §6), wired by `presentation.lua` and baked
by `tools/r48_farm/gen_placeholders.py`: today's runtime composites of the
vendored `mods/BASE/default` images (minetest_game `b5243f3`, CC BY-SA 3.0,
attribution in `mods/BASE/default/license.txt`), written as files. The art
lane's final files replace them together with these rows.

| File | Source | Treatment |
|---|---|---|
| `grug_gathering_melon.png` | `default_apple.png` | colorize `#61a94e` at 95/255 |
| `grug_gathering_mushroom.png` | `default_pine_bush_sapling.png` | colorize `#9b7653` at 150/255 |
| `grug_gathering_sunleaf.png`, `grug_gathering_sunleaf_plant.png` | `default_grass_3.png` | colorize `#e5d34a` at 105/255 |
| `grug_gathering_gravemoss.png`, `grug_gathering_gravemoss_plant.png` | `default_fern_1.png` | colorize `#526c45` at 100/255 |
| `grug_gathering_wild_cocoa.png`, `grug_gathering_wild_cocoa_plant.png` | `default_pine_bush_sapling.png` | colorize `#70452d` at 175/255 |
