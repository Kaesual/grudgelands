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
