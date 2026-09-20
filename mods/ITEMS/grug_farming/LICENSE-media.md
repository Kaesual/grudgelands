# `grug_farming` media ledger

Soil and the hoe retain their existing minetest_game texture compositions (CC
BY-SA 3.0). R10 replaces harvest-icon crop placeholders with four actual growth
stages per family. Exact copies and stage selections are reproducible through
`tools/r10_art/import_crop_stages.sh`.

| Families | Pinned source | License / author chain | Treatment |
|---|---|---|---|
| grain, carrot, cassava/potato, onion, pepper, pumpkin, three berries, melon, ember moss, potato, corn | `x_farming` `ac5f69d5` | media CC BY-SA 4.0; README License section and `LICENSE.txt` per-file exceptions | four representative source stages selected; three berry identities use baked 22% colour grades |
| salt crust | `x_farming` `ac5f69d5`, `x_farming_salt_{1..4}_top.png`, `x_farming_salt_{1..3}_side.png`, `x_farming_salt_1_bottom.png` | CC BY-SA 4.0 for the top/side files; bottom derived by TenPlus1 from random-geek and Neuromancer textures, CC BY-SA 3.0 | four animated crystal tops and their authored shallow nodebox progression; copied/renamed |
| sugar cane, bamboo | shipped `default_papyrus.png`, minetest_game `b5243f3e` | CC BY-SA 3.0, minetest_game contributors | upright plantlike tile copied or baked with 28% green colour grade; engine stage scale supplies growth |
| cave cap | `goblins` `ce27b15f`, `goblins_mushroom_brown*.png`, Francisco Athens | CC BY-SA 3.0 | four authored mushroom stages copied/renamed |

The source allow-list is exactly the table above. The deny-list is every other
file in the two farming repositories: no recipe, model, sound, node code, or
unlisted texture is imported. All node IDs, stage counts and farming mechanics
remain local and unchanged.

## Round 11 seed inventory silhouettes

Nine unchanged renamed source sprites from pinned `x_farming`
`ac5f69d5103d4af841b1a5ed3a0b49a4e19d0c84`, authored by SaKeL under
CC BY-SA 4.0 (`LICENSE.txt:463` and its per-file list):
`x_farming_{barley,beetroot,carrot,corn,cotton,melon,potato,pumpkin,strawberry}_seed.png`.
They ship locally as `grug_farming_seed_<family>.png`. The pure
`seed_visuals.lua` map assigns all 17 crops one of these seed silhouettes;
native color modifiers distinguish fantasy families that deliberately share a
shape. Harvest icons and growth nodes are unchanged.

## Round 11 water bucket

`grug_farming_bucket.png` and `grug_farming_bucket_water.png` are unchanged
renamed copies of `mods/bucket/textures/bucket.png` and `bucket_water.png` in
minetest_game commit `b5243f3e42410ae3ca85ead795149406fa654538`
(<https://github.com/minetest/minetest_game>). Author: ElementW, **CC BY-SA 3.0**,
per pinned `mods/bucket/README.txt` and `license.txt`. Both actual sprites were
visually inspected: an empty metal pail and a blue-water-filled pail. No bucket
code, lava texture or river-specific item is imported. These two files extend
the earlier source allow-list; the R10 deny-list remains scoped to R10.

## Round 11 hoe silhouettes

`grug_farming_woodhoe.png` and `grug_farming_steelhoe.png` are renamed unchanged
copies of VoxeLibre `textures/farming_tool_woodhoe.png` and
`farming_tool_steelhoe.png` at `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`
(<https://github.com/VoxeLibre/VoxeLibre>). XSSheep/Pixel Perfection and
VoxeLibre contributors, **CC BY-SA 4.0**, per `LEGAL.md` textures section and
`mods/ITEMS/mcl_farming/README.txt`. No upstream hoe code is copied.
The wood and metal silhouettes replace the axe placeholder; material color
treatments remain owned by Round-11 ART.
