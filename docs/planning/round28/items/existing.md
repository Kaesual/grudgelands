# Round 28 — existing items (designer reference)

Generated from the real item registry by a headless engine probe
(`tools/r28_design/dump_items.sh`, which also writes
[existing.json](existing.json)). Do not edit by hand; rerun the tool.
The design catalogue's own sub-types and new loot items are left out
(see [the catalogue](../design/catalog/README.md)).

Use these ids in quest item objectives, rewards, drop tables and enchant
inputs. New items go into `catalog/items.json`. Never reference an item
under [Curated out](#curated-out). **Tier** is the explicit tier the code
declares (profession ingredient tier, material tier, harvest tier, food
tier, tool tier, fishing band); blank means the code declares none.
**Sources**: grid / furnace (engine recipes), `<profession> T<n>`
(profession recipe), dual furnace, mining, mob drop, fishing, dig (another
node drops it). Nodes without a source (logs, sand, stone …) drop
themselves when dug.

Item groups usable in quest `group` objectives: [Item groups](#item-groups).
Mob entities and today's drops: [Mob entities](#mob-entities).

| Section | Entries |
|---|---|
| [Ores and gems (mined raw items)](#ores-and-gems-mined-raw-items) | 15 |
| [Bars and alloys](#bars-and-alloys) | 10 |
| [Cut gems](#cut-gems) | 7 |
| [Mob drops and mob materials](#mob-drops-and-mob-materials) | 34 |
| [Fish](#fish) | 6 |
| [Food (raw, cooked, found)](#food-raw-cooked-found) | 55 |
| [Wood (logs, planks, sticks, seasoned wood)](#wood-logs-planks-sticks-seasoned-wood) | 20 |
| [Profession materials](#profession-materials) | 35 |
| [Gathered herbs and plants](#gathered-herbs-and-plants) | 25 |
| [Farming (seeds, crops, crop nodes)](#farming-seeds-crops-crop-nodes) | 101 |
| [Alchemy and brewing](#alchemy-and-brewing) | 44 |
| [Tools](#tools) | 34 |
| [Gear (weapons, armour, offhands, trinkets)](#gear-weapons-armour-offhands-trinkets) | 156 |
| [Other craft items](#other-craft-items) | 51 |
| [Skill items (soulbound; never quest items or rewards)](#skill-items-soulbound-never-quest-items-or-rewards) | 26 |
| [Ore and gem nodes (dig for the raw item; not quest items)](#ore-and-gem-nodes-dig-for-the-raw-item-not-quest-items) | 15 |
| [Other nodes (building, decor, terrain)](#other-nodes-building-decor-terrain) | 773 |

## Ores and gems (mined raw items)

Gathering XP: ore 0.10 KE, gem 0.20 KE at the reference level 10 x harvest tier.

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `default:coal_lump` | Coal Lump | 1 | grid, mining, dig | coal |
| `default:copper_lump` | Copper Lump | 1 | mining, dig |  |
| `default:gold_lump` | Gold Lump | 2 | mining, dig |  |
| `default:iron_lump` | Iron Lump | 1 | mining, mob drop, dig |  |
| `default:tin_lump` | Tin Lump | 1 | mining, dig |  |
| `grug_materials:abyssal_crystal` | Abyssal Crystal | 5 | grid, mining, dig |  |
| `grug_materials:emberglass` | Emberglass | 4 | grid, mining, mob drop, dig |  |
| `grug_materials:quartz` | Quartz | 1 | mining, mob drop, dig |  |
| `grug_materials:rough_citrine` | Rough Citrine | 2 | mining, dig |  |
| `grug_materials:rough_diamond` | Rough Diamond | 4 | mining, mob drop, dig |  |
| `grug_materials:rough_garnet` | Rough Garnet | 2 | mining, dig |  |
| `grug_materials:rough_jade` | Rough Jade | 2 | mining, dig |  |
| `grug_materials:rough_ruby` | Rough Ruby | 4 | mining, dig |  |
| `grug_materials:rough_sapphire` | Rough Sapphire | 4 | mining, dig |  |
| `grug_materials:silver_lump` | Silver | 3 | mining, mob drop, dig |  |

## Bars and alloys

Normal furnace: one lump, one bar. Dual furnace: two inputs, one alloy bar.

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `grug_materials:abyssal_steel_bar` | Abyssal Steel Bar | 6 | grid, dual furnace |  |
| `grug_materials:bronze_bar` | Bronze Bar | 1 | grid, dual furnace |  |
| `grug_materials:copper_bar` | Copper Bar | 1 | grid, furnace |  |
| `grug_materials:embersteel_bar` | Embersteel Bar | 5 | grid, dual furnace |  |
| `grug_materials:gold_bar` | Gold Bar | 2 | grid, furnace |  |
| `grug_materials:iron_bar` | Iron Bar | 2 | grid, furnace, mob drop |  |
| `grug_materials:silver_bar` | Silver Bar |  | grid, furnace |  |
| `grug_materials:silversteel_bar` | Silversteel Bar | 4 | grid, dual furnace |  |
| `grug_materials:steel_bar` | Steel Bar | 3 | grid, dual furnace |  |
| `grug_materials:tin_bar` | Tin Bar | 1 | grid, furnace |  |

## Cut gems

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `grug_materials:cut_citrine` | Cut Citrine | 2 | goldsmith T2 |  |
| `grug_materials:cut_diamond` | Cut Diamond | 4 | goldsmith T4 |  |
| `grug_materials:cut_garnet` | Cut Garnet | 2 | goldsmith T2 |  |
| `grug_materials:cut_jade` | Cut Jade | 2 | goldsmith T2 |  |
| `grug_materials:cut_quartz` | Cut Quartz | 1 | goldsmith T1 |  |
| `grug_materials:cut_ruby` | Cut Ruby | 4 | goldsmith T4 |  |
| `grug_materials:cut_sapphire` | Cut Sapphire | 4 | goldsmith T4 |  |

## Mob drops and mob materials

Today's static drops (chance = 1 in N). Ruling 36 replaces them with band tables.

| Item | Name | Tier | Sources | Dropped by (1 in N) |
|---|---|---|---|---|
| `default:apple` | Apple | 2 | mob drop | ashen_treant 4, gravewood_treant 4 |
| `default:stick` | Stick |  | grid, mob drop, fishing junk | ashen_treant 1, gravewood_treant 1 |
| `grug_materials:emberglass_shard` | Emberglass Shard |  | mob drop | crystal_shard 1, dungeon_master 2 |
| `grug_mobs:ape_hair` | Ape Hair |  | mob drop | jungle_ape 4 |
| `grug_mobs:arrow` | Bundle of Arrows |  | mob drop | frost_stray 3, goblin_miner_slinger 3, goblin_slinger 3, skeleton_archer 3, skeleton_raider 3 |
| `grug_mobs:bear_claw` | Bear Claw | 3 | mob drop | bear 4, plaguehide_bear 4 |
| `grug_mobs:boar_tusk` | Boar Tusk |  | mob drop | boar 3, jungle_boar 3, plague_boar 3 |
| `grug_mobs:bone` | Bone |  | mob drop | frost_stray 1, skeleton_archer 1, skeleton_raider 1 |
| `grug_mobs:croc_tooth` | Crocodile Tooth | 4 | mob drop | crocodile 3 |
| `grug_mobs:dragon_rime` | Dragon Rime |  |  |  |
| `grug_mobs:dragon_scorch` | Dragon Scorch |  |  |  |
| `grug_mobs:fallen_crown` | Fallen Crown |  |  |  |
| `grug_mobs:fang` | Fang | 2 | mob drop | blightfang_wolf 3, fox 3, hyena 3, wolf 3 |
| `grug_mobs:feather` | Feather |  | mob drop | carrion_crow 1, crag_eagle 2, vulture 2 |
| `grug_mobs:heavy_cloth` | Heavy Cloth | 3 | mob drop | guard_accord 3, guard_throng 3, royal_guard_dwarf 3, royal_guard_elf 3, royal_guard_human 3, royal_guard_orc 3, royal_guard_troll 3, royal_guard_undead 3, skeleton_raider 3 |
| `grug_mobs:heavy_leather` | Heavy Leather | 3 | grid, mob drop | bear 2, jungle_ape 2, land_guard 2, mountain_ram 4, plaguehide_bear 2, speargrass_tiger 2 |
| `grug_mobs:light_leather` | Light Leather | 1 | grid, mob drop | boar 2, jungle_boar 2, plague_boar 2 |
| `grug_mobs:linen_cloth` | Linen Cloth | 2 | mob drop | mirefolk 2 |
| `grug_mobs:linen_scrap` | Linen Scrap | 1 | mob drop | bog_ooze 3, bog_witch 2, frost_stray 2, goblin_miner 2, goblin_miner_slinger 2, goblin_raider 2, goblin_slinger 2, skeleton_archer 2, skeleton_raider 2, sun_dried_husk 2, zombie 2 |
| `grug_mobs:raptor_claw` | Small Cat Claw |  | mob drop | jungle_lynx 3 |
| `grug_mobs:scaled_hide` | Scaled Hide | 4 | grid, mob drop | crocodile 1, reef_lurker 2, scorpion 2, serpent 2, shore_crab 2, viper 2 |
| `grug_mobs:sharp_feather` | Sharp Feather | 6 | mob drop | crag_eagle 1, vulture 1 |
| `grug_mobs:shiny_scale` | Shiny Scale | 4 | mob drop | mirefolk 4 |
| `grug_mobs:sleek_pelt` | Sleek Pelt | 5 | mob drop | panther 4, snow_leopard 4, speargrass_tiger 4 |
| `grug_mobs:slime_gel` | Slime Gel | 3 | mob drop | bog_ooze 1, lava_flan 2, rift_spawn 2 |
| `grug_mobs:spider_silk` | Spider Silk | 4 | mob drop | giant_spider 1, jungle_spider 1, pale_spider 1, spiderling 2 |
| `grug_mobs:stolen_purse` | Stolen Purse |  | mob drop | goblin_miner 8, goblin_raider 8 |
| `grug_mobs:stone_core` | Stone Core | 6 | mob drop | mesa_golem 1, stone_golem 1, stone_mite 8, war_construct 1 |
| `grug_mobs:venom_gland` | Venom Gland | 2 | mob drop | giant_spider 6, glowwing 5, jungle_spider 6, pale_spider 6 |
| `grug_mobs:venom_sac` | Venom Sac | 4 | mob drop | bog_witch 3, scorpion 3, serpent 3, viper 3 |
| `grug_mobs:war_trophy` | War Trophy |  | mob drop | guard_accord 1, guard_throng 1, royal_guard_dwarf 1, royal_guard_elf 1, royal_guard_human 1, royal_guard_orc 1, royal_guard_troll 1, royal_guard_undead 1 |
| `grug_mobs:zombie_flesh` | Rotting Flesh |  | mob drop | sun_dried_husk 1, zombie 1 |
| `mobs:leather` | Leather | 1 | mob drop | blightfang_wolf 2, fox 2, gaunt_stag 2, hyena 2, ibex 2, jungle_lynx 2, panther 2, snow_leopard 2, stag 2, tapir 2, wolf 2, zebra 2 |
| `mobs:meat_raw` | Raw Meat | 1 | mob drop | bear 1, blightfang_wolf 1, blood_bat 1, boar 1, bog_fowl 1, bone_weevil 1, cave_bat 1, cave_crawler 1, crag_eagle 2, crocodile 1, fox 1, gaunt_stag 1, giant_rat 1, goblin_hound 1, gull 1, hare 1, hyena 1, ibex 1, jungle_ape 1, jungle_boar 1, jungle_lynx 1, mountain_ram 1, panther 1, parrot 1, plague_boar 1, plaguehide_bear 1, plains_runner 1, rabbit 1, reef_lurker 1, shore_crab 1, snow_leopard 1, song_bird 1, speargrass_tiger 1, stag 1, tapir 1, vulture 2, wild_turkey 1, wolf 1, zebra 1 |

## Fish

Gathering XP: fish 0.33 KE at the reference level 10 x the water's band.

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `grug_fishing:ember_eel` | Ember Eel | 5 | fishing | food_fish_raw, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |
| `grug_fishing:frostfin` | Frostfin | 4 | fishing | food_fish_raw, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |
| `grug_fishing:mire_carp` | Mire Carp | 3 | fishing | food_fish_raw, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |
| `grug_fishing:silver_trout` | Silver Trout | 2 | fishing | food_fish_raw, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |
| `grug_fishing:storm_tuna` | Storm Tuna | 6 | fishing | food_fish_raw, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |
| `grug_mobs:raw_fish` | Raw Fish | 1 | mob drop, fishing | food_fish_raw, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |

## Food (raw, cooked, found)

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `default:blueberries` | Blueberries | 2 | dig | food_berry, food_blueberries, grug_cooking_berry, grug_cooking_fruit, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |
| `grug_cooking:bamboo_shoot` | Bamboo Shoot | 1 | dig | grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier, grug_plant_item |
| `grug_cooking:berry_preserve` | Berry Preserve | 2 | grid, cooking T2 | grug_food, grug_food_dish, grug_food_role_caster, grug_food_tier |
| `grug_cooking:blightberry` | Blightberry | 2 | dig | grug_cooking_berry, grug_cooking_fruit, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier, grug_plant_item |
| `grug_cooking:bread` | Bread | 1 | furnace | grug_food, grug_food_dish, grug_food_role_hearty, grug_food_tier |
| `grug_cooking:carrot` | Carrot | 1 | dig | grug_cooking_root, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier, grug_plant_item |
| `grug_cooking:cassava` | Cassava | 1 | dig | grug_cooking_root, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier, grug_plant_item |
| `grug_cooking:cave_cap` | Cave Cap | 3 | dig | grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier, grug_plant_item |
| `grug_cooking:cocoa_rubbed_game` | Cocoa-Rubbed Game | 6 | grid, cooking T6 | grug_food, grug_food_dish, grug_food_role_hunter, grug_food_tier |
| `grug_cooking:corn_crusted_fish` | Corn-Crusted Fish | 1 | grid, cooking T1 | grug_food, grug_food_dish, grug_food_role_hunter, grug_food_tier |
| `grug_cooking:foragers_pot` | Forager's Pot | 3 | furnace, cooking T3 | grug_food, grug_food_dish, grug_food_role_hearty, grug_food_tier |
| `grug_cooking:frost_melon` | Frost Melon | 4 | dig | grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier, grug_plant_item |
| `grug_cooking:fruit_glazed_roast` | Fruit-Glazed Roast | 2 | grid, cooking T2 | grug_food, grug_food_dish, grug_food_role_hunter, grug_food_tier |
| `grug_cooking:grand_feast` | Grand Feast | 6 | furnace, cooking T6 | grug_food, grug_food_dish, grug_food_role_hearty, grug_food_tier |
| `grug_cooking:hearty_stew` | Hearty Stew | 1 | furnace, cooking T1 | grug_food, grug_food_dish, grug_food_role_hearty, grug_food_tier |
| `grug_cooking:hunters_feast` | Hunter's Feast | 4 | grid, cooking T4 | grug_food, grug_food_dish, grug_food_role_hunter, grug_food_tier |
| `grug_cooking:jungle_berry` | Jungle Berry | 2 | dig | grug_cooking_berry, grug_cooking_fruit, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier, grug_plant_item |
| `grug_cooking:jungle_cocoa` | Jungle Cocoa | 6 | grid, cooking T6 | grug_food, grug_food_dish, grug_food_role_caster, grug_food_tier |
| `grug_cooking:kelp_wrapped_roast` | Kelp-Wrapped Roast | 5 | furnace, cooking T5 | grug_food, grug_food_dish, grug_food_role_hearty, grug_food_tier |
| `grug_cooking:marsh_roast` | Marsh Roast | 4 | furnace, cooking T4 | grug_food, grug_food_dish, grug_food_role_hearty, grug_food_tier |
| `grug_cooking:marshbloom_chowder` | Marshbloom Chowder | 4 | grid, cooking T4 | grug_food, grug_food_dish, grug_food_role_caster, grug_food_tier |
| `grug_cooking:mushroom_skewer` | Mushroom Skewer | 3 | grid, cooking T3 | grug_food, grug_food_dish, grug_food_role_caster, grug_food_tier |
| `grug_cooking:onion_seared_steak` | Onion-Seared Steak | 3 | grid, cooking T3 | grug_food, grug_food_dish, grug_food_role_hunter, grug_food_tier |
| `grug_cooking:pumpkin` | Pumpkin | 2 | dig | grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier, grug_plant_item |
| `grug_cooking:pumpkin_stew` | Pumpkin Stew | 2 | furnace, cooking T2 | grug_food, grug_food_dish, grug_food_role_hearty, grug_food_tier |
| `grug_cooking:salt_crusted_fish` | Salt-Crusted Fish | 5 | grid, cooking T5 | grug_food, grug_food_dish, grug_food_role_hunter, grug_food_tier |
| `grug_cooking:stormkelp_broth` | Stormkelp Broth | 5 | grid, cooking T5 | grug_food, grug_food_dish, grug_food_role_caster, grug_food_tier |
| `grug_cooking:sunberry` | Sunberry | 2 | dig | grug_cooking_berry, grug_cooking_fruit, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier, grug_plant_item |
| `grug_cooking:sweetroot_mash` | Sweetroot Mash | 1 | grid, cooking T1 | grug_food, grug_food_dish, grug_food_role_caster, grug_food_tier |
| `grug_cooking:wild_grain` | Wild Grain | 1 | dig | grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier, grug_plant_item |
| `grug_fishing:cooked_fish` | Cooked Fish | 1 | furnace | food_fish, grug_food, grug_food_dish, grug_food_role_hearty, grug_food_tier |
| `grug_gathering:corn` | Corn | 1 | dig | grug_cooking_staple, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |
| `grug_gathering:corn_source` | Corn Source |  |  | grug_food, grug_gathering_source |
| `grug_gathering:melon` | Melon | 4 | dig | grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |
| `grug_gathering:melon_source` | Melon Source |  |  | grug_food, grug_gathering_source |
| `grug_gathering:mushroom` | Mushroom | 3 | dig | grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |
| `grug_gathering:mushroom_source` | Mushroom Source |  |  | grug_food, grug_found_only_food, grug_gathering_source |
| `grug_gathering:potato` | Potato | 1 | dig | grug_cooking_staple, grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |
| `grug_gathering:potato_source` | Potato Source |  |  | grug_food, grug_gathering_source |
| `grug_gathering:rock_salt_source` | Rock Salt Source |  |  | grug_food, grug_found_only_food, grug_gathering_source |
| `grug_gathering:wild_cocoa` | Wild Cocoa | 6 | dig | grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |
| `grug_gathering:wild_cocoa_source` | Wild Cocoa Source |  |  | grug_food, grug_found_only_food, grug_gathering_source |
| `grug_mapgen:bamboo_shoot_source` | Bamboo Shoot (Wild) |  |  | grug_food, grug_gathering_source |
| `grug_mapgen:blightberry_source` | Blightberry (Wild) |  |  | grug_food, grug_gathering_source |
| `grug_mapgen:carrot_source` | Carrot (Wild) |  |  | grug_food, grug_gathering_source |
| `grug_mapgen:cassava_source` | Cassava (Wild) |  |  | grug_food, grug_gathering_source |
| `grug_mapgen:cave_cap_source` | Cave Cap (Wild) |  |  | grug_food, grug_gathering_source |
| `grug_mapgen:frost_melon_source` | Frost Melon (Wild) |  |  | grug_food, grug_gathering_source |
| `grug_mapgen:jungle_berry_source` | Jungle Berry (Wild) |  |  | grug_food, grug_gathering_source |
| `grug_mapgen:pumpkin_source` | Pumpkin (Wild) |  |  | grug_food, grug_gathering_source |
| `grug_mapgen:sunberry_source` | Sunberry (Wild) |  |  | grug_food, grug_gathering_source |
| `grug_mapgen:wild_grain_source` | Wild Grain (Wild) |  |  | grug_food, grug_gathering_source |
| `mobs:meat` | Meat | 1 | furnace | food_meat, grug_food, grug_food_dish, grug_food_role_hearty, grug_food_tier |
| `mobs:meatblock` | Meat Block | 1 | furnace, grid | grug_food, grug_food_dish, grug_food_role_hearty, grug_food_tier |
| `mobs:meatblock_raw` | Raw Meat Block | 1 | grid | grug_food, grug_food_raw, grug_food_role_hp, grug_food_tier |

## Wood (logs, planks, sticks, seasoned wood)

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `default:acacia_tree` | Acacia Tree |  |  | tree |
| `default:acacia_wood` | Acacia Wood Planks |  | grid | wood |
| `default:aspen_tree` | Aspen Tree |  |  | tree |
| `default:aspen_wood` | Aspen Wood Planks |  | grid | wood |
| `default:jungletree` | Jungle Tree |  |  | tree |
| `default:junglewood` | Jungle Wood Planks |  | grid | wood |
| `default:pine_tree` | Pine Tree |  |  | tree |
| `default:pine_wood` | Pine Wood Planks |  | grid | wood |
| `default:tree` | Apple Tree |  |  | tree |
| `default:wood` | Apple Wood Planks |  | grid | wood |
| `grug_artisans:hardened_wood` | Hardened Wood | 3 | grid | grug_profession_material, grug_wood_grade |
| `grug_artisans:heartwood_wood` | Heartwood Wood | 6 | grid | grug_profession_material, grug_wood_grade |
| `grug_artisans:inlaid_wood` | Inlaid Wood | 4 | grid | grug_profession_material, grug_wood_grade |
| `grug_artisans:lacquered_wood` | Lacquered Wood | 5 | grid | grug_profession_material, grug_wood_grade |
| `grug_artisans:polished_wood` | Polished Wood | 2 | grid | grug_profession_material, grug_wood_grade |
| `grug_artisans:seasoned_wood` | Seasoned Wood | 1 | grid | grug_profession_material, grug_wood_grade |
| `grug_trees:gravewood_tree` | Gravewood Tree |  |  | tree |
| `grug_trees:gravewood_wood` | Gravewood Planks |  | grid | wood |
| `grug_trees:silverwood_tree` | Silverwood Tree |  |  | tree |
| `grug_trees:silverwood_wood` | Silverwood Planks |  | grid | wood |

## Profession materials

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `grug_artisans:ornament_components_t3` | Tier 3 Ornament Components |  | goldsmith T3 | grug_ornament_components, grug_profession_material |
| `grug_artisans:ornament_components_t4` | Tier 4 Ornament Components |  | goldsmith T4 | grug_ornament_components, grug_profession_material |
| `grug_artisans:ornament_components_t5` | Tier 5 Ornament Components |  | goldsmith T5 | grug_ornament_components, grug_profession_material |
| `grug_artisans:ornament_components_t6` | Tier 6 Ornament Components |  | goldsmith T6 | grug_ornament_components, grug_profession_material |
| `grug_artisans:setting_copper_inlaid_steel` | Copper-inlaid Steel Setting | 3 | goldsmith T3 | grug_jewellery_setting, grug_profession_material |
| `grug_artisans:setting_gold` | Gold Setting | 4 | goldsmith T4 | grug_jewellery_setting, grug_profession_material |
| `grug_artisans:setting_gold_filigreed_abyssal_steel` | Gold-filigreed Abyssal Steel Setting | 6 | goldsmith T6 | grug_jewellery_setting, grug_profession_material |
| `grug_artisans:setting_gold_filigreed_embersteel` | Gold-filigreed Embersteel Setting | 5 | goldsmith T5 | grug_jewellery_setting, grug_profession_material |
| `grug_artisans:setting_iron` | Iron Setting | 2 | goldsmith T2 | grug_jewellery_setting, grug_profession_material |
| `grug_artisans:setting_tin` | Tin Setting | 1 | goldsmith T1 | grug_jewellery_setting, grug_profession_material |
| `grug_professions:bolt_heavy` | Heavy Bolt | 3 | grid | grug_profession_material, grug_tailor_bolt |
| `grug_professions:bolt_patch` | Patch Bolt | 1 | grid | grug_profession_material, grug_tailor_bolt |
| `grug_professions:bolt_silk` | Silk Bolt | 5 | grid | grug_profession_material, grug_tailor_bolt |
| `grug_professions:bolt_silkweave` | Silkweave Bolt | 4 | grid | grug_profession_material, grug_tailor_bolt |
| `grug_professions:bolt_stormweave` | Stormweave Bolt | 6 | grid | grug_profession_material, grug_tailor_bolt |
| `grug_professions:bolt_woven` | Woven Bolt | 2 | grid | grug_profession_material, grug_tailor_bolt |
| `grug_professions:cured_leather` | Cured Leather | 2 | grid | grug_leather_grade, grug_profession_material |
| `grug_professions:heavy_bolt_bundle` | Bundle of Five Heavy Bolts | 3 | tailor T3 | grug_tailor_bundle |
| `grug_professions:metal_rod_abyssal_steel` | Abyssal Steel Rod |  | grid | grug_metal_rod |
| `grug_professions:metal_rod_bronze` | Bronze Rod |  | grid | grug_metal_rod |
| `grug_professions:metal_rod_embersteel` | Embersteel Rod |  | grid | grug_metal_rod |
| `grug_professions:metal_rod_iron` | Iron Rod |  | grid | grug_metal_rod |
| `grug_professions:metal_rod_silversteel` | Silversteel Rod |  | grid | grug_metal_rod |
| `grug_professions:metal_rod_steel` | Steel Rod |  | grid | grug_metal_rod |
| `grug_professions:nightscale_leather` | Nightscale Leather | 6 | grid | grug_leather_grade, grug_profession_material |
| `grug_professions:parchment` | Parchment |  |  | grug_profession_supply |
| `grug_professions:sleek_leather` | Sleek Leather | 5 | grid | grug_leather_grade, grug_profession_material |
| `grug_professions:thread` | Thread |  | grid | grug_profession_supply |
| `grug_professions:weapon_grip_cured` | Cured Leather Weapon Grip | 2 | leatherworker T2 | grug_profession_material, grug_weapon_grip |
| `grug_professions:weapon_grip_heavy` | Heavy Leather Weapon Grip | 3 | leatherworker T3 | grug_profession_material, grug_weapon_grip |
| `grug_professions:weapon_grip_light` | Light Leather Weapon Grip | 1 | leatherworker T1 | grug_profession_material, grug_weapon_grip |
| `grug_professions:weapon_grip_nightscale` | Nightscale Leather Weapon Grip | 6 | leatherworker T6 | grug_profession_material, grug_weapon_grip |
| `grug_professions:weapon_grip_scaled` | Scaled Leather Weapon Grip | 4 | leatherworker T4 | grug_profession_material, grug_weapon_grip |
| `grug_professions:weapon_grip_sleek` | Sleek Leather Weapon Grip | 5 | leatherworker T5 | grug_profession_material, grug_weapon_grip |
| `grug_professions:woven_bolt_bundle` | Bundle of Four Woven Bolts | 2 | tailor T2 | grug_tailor_bundle |

## Gathered herbs and plants

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `grug_cooking:ember_moss` | Ember Moss | 5 | dig | grug_alchemy_reagent, grug_plant_item |
| `grug_cooking:fire_pepper` | Fire Pepper | 1 | dig | grug_cooking_early_spice, grug_plant_item, grug_spice |
| `grug_cooking:salt_crust` | Salt Crust | 5 | dig | grug_plant_item, grug_salt |
| `grug_cooking:sugar_cane` | Sugar Cane | 2 | dig | grug_plant_item, grug_sweetener |
| `grug_cooking:wild_onion` | Wild Onion | 1 | dig | grug_cooking_early_spice, grug_plant_item, grug_spice |
| `grug_gathering:crimson_lotus` | Crimson Lotus | 3 | dig |  |
| `grug_gathering:crimson_lotus_source` | Crimson Lotus Source |  |  | grug_gathering_source, grug_healing_herb |
| `grug_gathering:dragonweed` | Dragonweed | 2 | dig |  |
| `grug_gathering:dragonweed_source` | Dragonweed Source |  |  | grug_gathering_source, grug_healing_herb |
| `grug_gathering:gravemoss` | Gravemoss | 1 | dig |  |
| `grug_gathering:gravemoss_source` | Gravemoss Source |  |  | grug_gathering_source, grug_healing_herb |
| `grug_gathering:gravesalt_source` | Gravesalt Source |  |  | grug_cultural_source, grug_gathering_source |
| `grug_gathering:marshbloom` | Marshbloom | 4 | dig |  |
| `grug_gathering:marshbloom_source` | Marshbloom Source |  |  | grug_gathering_source, grug_spice |
| `grug_gathering:moonresin_source` | Moonresin Source |  |  | grug_cultural_source, grug_gathering_source |
| `grug_gathering:red_ochre_source` | Red Ochre Source |  |  | grug_cultural_source, grug_gathering_source |
| `grug_gathering:rock_salt` | Rock Salt | 5 | dig |  |
| `grug_gathering:runeslate_source` | Runeslate Source |  |  | grug_cultural_source, grug_gathering_source |
| `grug_gathering:spirit_resin_source` | Spirit Resin Source |  |  | grug_cultural_source, grug_gathering_source |
| `grug_gathering:stormkelp` | Stormkelp | 5 | dig |  |
| `grug_gathering:stormkelp_source` | Stormkelp Source |  |  | grug_gathering_source, grug_spice |
| `grug_gathering:sunleaf` | Sunleaf | 1 | dig |  |
| `grug_gathering:sunleaf_source` | Sunleaf Source |  |  | grug_gathering_source, grug_spice |
| `grug_gathering:sunwax_source` | Sunwax Source |  |  | grug_cultural_source, grug_gathering_source |
| `grug_mapgen:ember_moss_source` | Ember Moss (Wild) |  |  | grug_gathering_source, grug_healing_herb |

## Farming (seeds, crops, crop nodes)

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `grug_farming:bamboo_shoot_1` | Bamboo Shoot Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:bamboo_shoot_2` | Bamboo Shoot Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:bamboo_shoot_3` | Bamboo Shoot Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:bamboo_shoot_3_upper_1` | Bamboo Shoot Crop (upper) |  |  | plant |
| `grug_farming:bamboo_shoot_4` | Bamboo Shoot Crop |  |  | grug_farming_crop, plant |
| `grug_farming:bamboo_shoot_4_upper_1` | Bamboo Shoot Crop (upper) |  |  | plant |
| `grug_farming:bamboo_shoot_4_upper_2` | Bamboo Shoot Crop (upper) |  |  | plant |
| `grug_farming:blightberry_1` | Blightberry Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:blightberry_2` | Blightberry Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:blightberry_3` | Blightberry Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:blightberry_4` | Blightberry Crop |  |  | grug_farming_crop, plant |
| `grug_farming:carrot_1` | Carrot Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:carrot_2` | Carrot Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:carrot_3` | Carrot Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:carrot_4` | Carrot Crop |  |  | grug_farming_crop, plant |
| `grug_farming:cassava_1` | Cassava Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:cassava_2` | Cassava Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:cassava_3` | Cassava Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:cassava_4` | Cassava Crop |  |  | grug_farming_crop, plant |
| `grug_farming:cave_cap_1` | Cave Cap Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:cave_cap_2` | Cave Cap Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:cave_cap_3` | Cave Cap Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:cave_cap_4` | Cave Cap Crop |  |  | grug_farming_crop, plant |
| `grug_farming:corn_1` | Corn Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:corn_2` | Corn Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:corn_3` | Corn Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:corn_3_upper_1` | Corn Crop (upper) |  |  | plant |
| `grug_farming:corn_4` | Corn Crop |  |  | grug_farming_crop, plant |
| `grug_farming:corn_4_upper_1` | Corn Crop (upper) |  |  | plant |
| `grug_farming:corn_4_upper_2` | Corn Crop (upper) |  |  | plant |
| `grug_farming:ember_moss_1` | Ember Moss Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:ember_moss_2` | Ember Moss Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:ember_moss_3` | Ember Moss Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:ember_moss_4` | Ember Moss Crop |  |  | grug_farming_crop, plant |
| `grug_farming:empty_iron_bucket` | Iron Bucket |  | grid | grug_bucket |
| `grug_farming:fire_pepper_1` | Fire Pepper Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:fire_pepper_2` | Fire Pepper Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:fire_pepper_3` | Fire Pepper Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:fire_pepper_4` | Fire Pepper Crop |  |  | grug_farming_crop, plant |
| `grug_farming:frost_melon_1` | Frost Melon Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:frost_melon_2` | Frost Melon Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:frost_melon_3` | Frost Melon Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:frost_melon_4` | Frost Melon Crop |  |  | grug_farming_crop, plant |
| `grug_farming:jungle_berry_1` | Jungle Berry Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:jungle_berry_2` | Jungle Berry Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:jungle_berry_3` | Jungle Berry Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:jungle_berry_4` | Jungle Berry Crop |  |  | grug_farming_crop, plant |
| `grug_farming:potato_1` | Potato Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:potato_2` | Potato Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:potato_3` | Potato Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:potato_4` | Potato Crop |  |  | grug_farming_crop, plant |
| `grug_farming:pumpkin_1` | Pumpkin Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:pumpkin_2` | Pumpkin Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:pumpkin_3` | Pumpkin Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:pumpkin_4` | Pumpkin Crop |  |  | grug_farming_crop, plant |
| `grug_farming:salt_crust_1` | Salt Crust Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:salt_crust_2` | Salt Crust Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:salt_crust_3` | Salt Crust Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:salt_crust_4` | Salt Crust Crop |  |  | grug_farming_crop, plant |
| `grug_farming:seed_bamboo_shoot` | Bamboo Shoot Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_blightberry` | Blightberry Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_carrot` | Carrot Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_cassava` | Cassava Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_cave_cap` | Cave Cap Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_corn` | Corn Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_ember_moss` | Ember Moss Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_fire_pepper` | Fire Pepper Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_frost_melon` | Frost Melon Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_jungle_berry` | Jungle Berry Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_potato` | Potato Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_pumpkin` | Pumpkin Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_salt_crust` | Salt Crust Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_sugar_cane` | Sugar Cane Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_sunberry` | Sunberry Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_wild_grain` | Wild Grain Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:seed_wild_onion` | Wild Onion Seeds |  | grid, dig | grug_farming_seed, seed |
| `grug_farming:soil` | Crop Soil |  |  | soil |
| `grug_farming:soil_wet` | Wet Crop Soil |  |  | soil |
| `grug_farming:sugar_cane_1` | Sugar Cane Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:sugar_cane_2` | Sugar Cane Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:sugar_cane_2_upper_1` | Sugar Cane Crop (upper) |  |  | plant |
| `grug_farming:sugar_cane_3` | Sugar Cane Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:sugar_cane_3_upper_1` | Sugar Cane Crop (upper) |  |  | plant |
| `grug_farming:sugar_cane_3_upper_2` | Sugar Cane Crop (upper) |  |  | plant |
| `grug_farming:sugar_cane_4` | Sugar Cane Crop |  |  | grug_farming_crop, plant |
| `grug_farming:sugar_cane_4_upper_1` | Sugar Cane Crop (upper) |  |  | plant |
| `grug_farming:sugar_cane_4_upper_2` | Sugar Cane Crop (upper) |  |  | plant |
| `grug_farming:sugar_cane_4_upper_3` | Sugar Cane Crop (upper) |  |  | plant |
| `grug_farming:sunberry_1` | Sunberry Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:sunberry_2` | Sunberry Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:sunberry_3` | Sunberry Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:sunberry_4` | Sunberry Crop |  |  | grug_farming_crop, plant |
| `grug_farming:water_bucket` | Water Bucket |  |  | grug_bucket |
| `grug_farming:wild_grain_1` | Wild Grain Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:wild_grain_2` | Wild Grain Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:wild_grain_3` | Wild Grain Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:wild_grain_4` | Wild Grain Crop |  |  | grug_farming_crop, plant |
| `grug_farming:wild_onion_1` | Wild Onion Crop (Stage 1) |  |  | grug_farming_crop, plant |
| `grug_farming:wild_onion_2` | Wild Onion Crop (Stage 2) |  |  | grug_farming_crop, plant |
| `grug_farming:wild_onion_3` | Wild Onion Crop (Stage 3) |  |  | grug_farming_crop, plant |
| `grug_farming:wild_onion_4` | Wild Onion Crop |  |  | grug_farming_crop, plant |

## Alchemy and brewing

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `grug_alchemy:elixir_deepwater` | Deepwater Elixir |  | alchemist T5 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_focus_t3` | Elixir of Focus III |  | alchemist T3 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_focus_t4` | Elixir of Focus IV |  | alchemist T4 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_focus_t5` | Elixir of Focus V |  | alchemist T5 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_focus_t6` | Elixir of Focus VI |  | alchemist T6 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_precision_t3` | Elixir of Precision III |  | alchemist T3 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_precision_t4` | Elixir of Precision IV |  | alchemist T4 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_precision_t5` | Elixir of Precision V |  | alchemist T5 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_precision_t6` | Elixir of Precision VI |  | alchemist T6 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_stoneskin` | Stoneskin Elixir |  | alchemist T4 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_vigor_t3` | Elixir of Vigor III |  | alchemist T3 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_vigor_t4` | Elixir of Vigor IV |  | alchemist T4 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_vigor_t5` | Elixir of Vigor V |  | alchemist T5 | grug_elixir, grug_potion |
| `grug_alchemy:elixir_vigor_t6` | Elixir of Vigor VI |  | alchemist T6 | grug_elixir, grug_potion |
| `grug_alchemy:mixture_elixir_deepwater` | Prepared Deepwater Elixir Mixture | 5 | grid, alchemist T5 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_focus_t3` | Prepared Elixir of Focus III Mixture | 3 | grid, alchemist T3 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_focus_t4` | Prepared Elixir of Focus IV Mixture | 4 | grid, alchemist T4 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_focus_t5` | Prepared Elixir of Focus V Mixture | 5 | grid, alchemist T5 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_focus_t6` | Prepared Elixir of Focus VI Mixture | 6 | grid, alchemist T6 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_precision_t3` | Prepared Elixir of Precision III Mixture | 3 | grid, alchemist T3 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_precision_t4` | Prepared Elixir of Precision IV Mixture | 4 | grid, alchemist T4 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_precision_t5` | Prepared Elixir of Precision V Mixture | 5 | grid, alchemist T5 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_precision_t6` | Prepared Elixir of Precision VI Mixture | 6 | grid, alchemist T6 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_stoneskin` | Prepared Stoneskin Elixir Mixture | 4 | grid, alchemist T4 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_vigor_t3` | Prepared Elixir of Vigor III Mixture | 3 | grid, alchemist T3 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_vigor_t4` | Prepared Elixir of Vigor IV Mixture | 4 | grid, alchemist T4 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_vigor_t5` | Prepared Elixir of Vigor V Mixture | 5 | grid, alchemist T5 | grug_potion_mixture |
| `grug_alchemy:mixture_elixir_vigor_t6` | Prepared Elixir of Vigor VI Mixture | 6 | grid, alchemist T6 | grug_potion_mixture |
| `grug_alchemy:mixture_potion_antivenom` | Prepared Antivenom Mixture | 2 | grid, alchemist T2 | grug_potion_mixture |
| `grug_alchemy:mixture_potion_cave` | Prepared Cave Draught Mixture | 3 | grid, alchemist T3 | grug_potion_mixture |
| `grug_alchemy:mixture_potion_greater_healing` | Prepared Greater Healing Potion Mixture | 3 | grid, alchemist T3 | grug_potion_mixture |
| `grug_alchemy:mixture_potion_greater_mana` | Prepared Greater Mana Potion Mixture | 3 | grid, alchemist T3 | grug_potion_mixture |
| `grug_alchemy:mixture_potion_healing` | Prepared Healing Potion Mixture | 1 | grid, alchemist T1 | grug_potion_mixture |
| `grug_alchemy:mixture_potion_mana` | Prepared Mana Potion Mixture | 1 | grid, alchemist T1 | grug_potion_mixture |
| `grug_alchemy:mixture_potion_swiftness` | Prepared Swiftness Draught Mixture | 2 | grid, alchemist T2 | grug_potion_mixture |
| `grug_alchemy:potion_antivenom` | Antivenom |  | alchemist T2 | grug_potion, grug_potion_instant |
| `grug_alchemy:potion_cave` | Cave Draught |  | alchemist T3 | grug_potion, grug_potion_instant |
| `grug_alchemy:potion_greater_healing` | Greater Healing Potion |  | alchemist T3 | grug_potion, grug_potion_instant |
| `grug_alchemy:potion_greater_mana` | Greater Mana Potion |  | alchemist T3 | grug_potion, grug_potion_instant |
| `grug_alchemy:potion_healing` | Healing Potion |  | alchemist T1 | grug_potion, grug_potion_instant |
| `grug_alchemy:potion_mana` | Mana Potion |  | alchemist T1 | grug_potion, grug_potion_instant |
| `grug_alchemy:potion_swiftness` | Swiftness Draught |  | alchemist T2 | grug_potion, grug_potion_instant |
| `grug_brewing:brewing_stand` | Brewing Stand |  | grid, alchemist T3, dig |  |
| `grug_brewing:brewing_stand_active` | Brewing Stand |  |  |  |

## Tools

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `grug_farming:hoe` | Wooden Hoe | 1 | grid | grug_farming_hoe, grug_gathering_tool, hoe |
| `grug_farming:hoe_abyssal_steel` | Abyssal Steel Hoe | 6 | grid | grug_farming_hoe, grug_gathering_tool, hoe |
| `grug_farming:hoe_bronze` | Bronze Hoe | 1 | grid | grug_farming_hoe, grug_gathering_tool, hoe |
| `grug_farming:hoe_embersteel` | Embersteel Hoe | 5 | grid | grug_farming_hoe, grug_gathering_tool, hoe |
| `grug_farming:hoe_iron` | Iron Hoe | 2 | grid | grug_farming_hoe, grug_gathering_tool, hoe |
| `grug_farming:hoe_silversteel` | Silversteel Hoe | 4 | grid | grug_farming_hoe, grug_gathering_tool, hoe |
| `grug_farming:hoe_steel` | Steel Hoe | 3 | grid | grug_farming_hoe, grug_gathering_tool, hoe |
| `grug_farming:hoe_stone` | Stone Hoe | 1 | grid | grug_farming_hoe, grug_gathering_tool, hoe |
| `grug_fishing:rod` | Fishing Rod |  | grid | fishing_rod, tool |
| `grug_materials:axe_abyssal_steel` | Abyssal Steel Woodcutting Axe | 6 | grid | axe, grug_axe_tier, grug_gathering_tool |
| `grug_materials:axe_bronze` | Bronze Axe | 1 | grid | axe, grug_axe_tier, grug_gathering_tool |
| `grug_materials:axe_embersteel` | Embersteel Woodcutting Axe | 5 | grid | axe, grug_axe_tier, grug_gathering_tool |
| `grug_materials:axe_iron` | Iron Woodcutting Axe | 2 | grid | axe, grug_axe_tier, grug_gathering_tool |
| `grug_materials:axe_silversteel` | Silversteel Woodcutting Axe | 4 | grid | axe, grug_axe_tier, grug_gathering_tool |
| `grug_materials:axe_steel` | Steel Axe | 3 | grid | axe, grug_axe_tier, grug_gathering_tool |
| `grug_materials:axe_stone` | Stone Axe | 1 | grid | axe, grug_axe_tier, grug_gathering_tool |
| `grug_materials:axe_wood` | Wooden Axe | 1 | grid | axe, grug_axe_tier, grug_gathering_tool |
| `grug_materials:pick_abyssal_steel` | Abyssal Steel Pickaxe | 6 | grid | grug_gathering_tool, grug_pick_tier, pickaxe |
| `grug_materials:pick_bronze` | Bronze Pickaxe | 1 | grid | grug_gathering_tool, grug_pick_tier, pickaxe |
| `grug_materials:pick_embersteel` | Embersteel Pickaxe | 5 | grid | grug_gathering_tool, grug_pick_tier, pickaxe |
| `grug_materials:pick_iron` | Iron Pickaxe | 2 | grid | grug_gathering_tool, grug_pick_tier, pickaxe |
| `grug_materials:pick_silversteel` | Silversteel Pickaxe | 4 | grid | grug_gathering_tool, grug_pick_tier, pickaxe |
| `grug_materials:pick_steel` | Steel Pickaxe | 3 | grid | grug_gathering_tool, grug_pick_tier, pickaxe |
| `grug_materials:pick_stone` | Stone Pickaxe | 1 | grid | grug_gathering_tool, grug_pick_tier, pickaxe |
| `grug_materials:pick_wood` | Wooden Pickaxe | 1 | grid | grug_gathering_tool, grug_pick_tier, pickaxe |
| `grug_materials:shovel_abyssal_steel` | Abyssal Steel Shovel | 6 | grid | grug_gathering_tool, grug_shovel_tier, shovel |
| `grug_materials:shovel_bronze` | Bronze Shovel | 1 | grid | grug_gathering_tool, grug_shovel_tier, shovel |
| `grug_materials:shovel_embersteel` | Embersteel Shovel | 5 | grid | grug_gathering_tool, grug_shovel_tier, shovel |
| `grug_materials:shovel_iron` | Iron Shovel | 2 | grid | grug_gathering_tool, grug_shovel_tier, shovel |
| `grug_materials:shovel_silversteel` | Silversteel Shovel | 4 | grid | grug_gathering_tool, grug_shovel_tier, shovel |
| `grug_materials:shovel_steel` | Steel Shovel | 3 | grid | grug_gathering_tool, grug_shovel_tier, shovel |
| `grug_materials:shovel_stone` | Stone Shovel | 1 | grid | grug_gathering_tool, grug_shovel_tier, shovel |
| `grug_materials:shovel_wood` | Wooden Shovel | 1 | grid | grug_gathering_tool, grug_shovel_tier, shovel |
| `mobs:mob_reset_stick` | Mob Reset Stick |  |  |  |

## Gear (weapons, armour, offhands, trinkets)

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `grug_gear:apothecary_loop_t1` | Tin Apothecary Loop |  | goldsmith T1 | grug_equip_trinket, grug_gear |
| `grug_gear:apothecary_loop_t2` | Iron Apothecary Loop |  | goldsmith T2 | grug_equip_trinket, grug_gear |
| `grug_gear:apothecary_loop_t3` | Steel Apothecary Loop |  | goldsmith T3 | grug_equip_trinket, grug_gear |
| `grug_gear:apothecary_loop_t4` | Gold Apothecary Loop |  | goldsmith T4 | grug_equip_trinket, grug_gear |
| `grug_gear:apothecary_loop_t5` | Embersteel Apothecary Loop |  | goldsmith T5 | grug_equip_trinket, grug_gear |
| `grug_gear:apothecary_loop_t6` | Abyssal Steel Apothecary Loop |  | goldsmith T6 | grug_equip_trinket, grug_gear |
| `grug_gear:battlebeat_t1` | Tin Battlebeat Band |  | goldsmith T1 | grug_equip_trinket, grug_gear |
| `grug_gear:battlebeat_t2` | Iron Battlebeat Band |  | goldsmith T2 | grug_equip_trinket, grug_gear |
| `grug_gear:battlebeat_t3` | Steel Battlebeat Band |  | goldsmith T3 | grug_equip_trinket, grug_gear |
| `grug_gear:battlebeat_t4` | Gold Battlebeat Band |  | goldsmith T4 | grug_equip_trinket, grug_gear |
| `grug_gear:battlebeat_t5` | Embersteel Battlebeat Band |  | goldsmith T5 | grug_equip_trinket, grug_gear |
| `grug_gear:battlebeat_t6` | Abyssal Steel Battlebeat Band |  | goldsmith T6 | grug_equip_trinket, grug_gear |
| `grug_gear:bow_abyssal_steel` | Abyssal Steel Bow |  | grid | bow, grug_bow, grug_equip_weapon, grug_gear |
| `grug_gear:bow_bronze` | Bronze Bow |  | grid | bow, grug_bow, grug_equip_weapon, grug_gear |
| `grug_gear:bow_embersteel` | Embersteel Bow |  | grid | bow, grug_bow, grug_equip_weapon, grug_gear |
| `grug_gear:bow_iron` | Iron Bow |  | grid | bow, grug_bow, grug_equip_weapon, grug_gear |
| `grug_gear:bow_silversteel` | Silversteel Bow |  | grid | bow, grug_bow, grug_equip_weapon, grug_gear |
| `grug_gear:bow_steel` | Steel Bow |  | grid | bow, grug_bow, grug_equip_weapon, grug_gear |
| `grug_gear:chest_cloth_heavy` | Heavy Robe |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_cloth_patch` | Patch Robe |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_cloth_silk` | Silk Robe |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_cloth_silkweave` | Silkweave Robe |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_cloth_stormweave` | Stormweave Robe |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_cloth_woven` | Woven Robe |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_leather_cured` | Cured Jerkin |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_leather_heavy` | Heavy Jerkin |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_leather_light` | Light Jerkin |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_leather_nightscale` | Nightscale Jerkin |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_leather_scaled` | Scaled Jerkin |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_leather_sleek` | Sleek Jerkin |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_metal_abyssal_steel` | Abyssal Steel Chestplate |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_metal_bronze` | Bronze Chestplate |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_metal_embersteel` | Embersteel Chestplate |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_metal_iron` | Iron Chestplate |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_metal_silversteel` | Silversteel Chestplate |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:chest_metal_steel` | Steel Chestplate |  | grid | grug_armor_class, grug_equip_chest, grug_gear |
| `grug_gear:dagger_abyssal_steel` | Abyssal Steel Dagger |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:dagger_bronze` | Bronze Dagger |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:dagger_embersteel` | Embersteel Dagger |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:dagger_iron` | Iron Dagger |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:dagger_silversteel` | Silversteel Dagger |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:dagger_steel` | Steel Dagger |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:feet_cloth_heavy` | Heavy Slippers |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_cloth_patch` | Patch Slippers |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_cloth_silk` | Silk Slippers |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_cloth_silkweave` | Silkweave Slippers |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_cloth_stormweave` | Stormweave Slippers |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_cloth_woven` | Woven Slippers |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_leather_cured` | Cured Boots |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_leather_heavy` | Heavy Boots |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_leather_light` | Light Boots |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_leather_nightscale` | Nightscale Boots |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_leather_scaled` | Scaled Boots |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_leather_sleek` | Sleek Boots |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_metal_abyssal_steel` | Abyssal Steel Sabatons |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_metal_bronze` | Bronze Sabatons |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_metal_embersteel` | Embersteel Sabatons |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_metal_iron` | Iron Sabatons |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_metal_silversteel` | Silversteel Sabatons |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:feet_metal_steel` | Steel Sabatons |  | grid | grug_armor_class, grug_equip_feet, grug_gear |
| `grug_gear:greataxe_abyssal_steel` | Abyssal Steel Battle Axe |  | grid | axe, grug_equip_weapon, grug_gear |
| `grug_gear:greataxe_bronze` | Bronze Battle Axe |  | grid | axe, grug_equip_weapon, grug_gear |
| `grug_gear:greataxe_embersteel` | Embersteel Battle Axe |  | grid | axe, grug_equip_weapon, grug_gear |
| `grug_gear:greataxe_iron` | Iron Battle Axe |  | grid | axe, grug_equip_weapon, grug_gear |
| `grug_gear:greataxe_silversteel` | Silversteel Battle Axe |  | grid | axe, grug_equip_weapon, grug_gear |
| `grug_gear:greataxe_steel` | Steel Battle Axe |  | grid | axe, grug_equip_weapon, grug_gear |
| `grug_gear:head_cloth_heavy` | Heavy Cowl |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_cloth_patch` | Patch Cowl |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_cloth_silk` | Silk Cowl |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_cloth_silkweave` | Silkweave Cowl |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_cloth_stormweave` | Stormweave Cowl |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_cloth_woven` | Woven Cowl |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_leather_cured` | Cured Hood |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_leather_heavy` | Heavy Hood |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_leather_light` | Light Hood |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_leather_nightscale` | Nightscale Hood |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_leather_scaled` | Scaled Hood |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_leather_sleek` | Sleek Hood |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_metal_abyssal_steel` | Abyssal Steel Helm |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_metal_bronze` | Bronze Helm |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_metal_embersteel` | Embersteel Helm |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_metal_iron` | Iron Helm |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_metal_silversteel` | Silversteel Helm |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:head_metal_steel` | Steel Helm |  | grid | grug_armor_class, grug_equip_head, grug_gear |
| `grug_gear:last_light_t1` | Tin Last Light Locket |  | goldsmith T1 | grug_equip_trinket, grug_gear |
| `grug_gear:last_light_t2` | Iron Last Light Locket |  | goldsmith T2 | grug_equip_trinket, grug_gear |
| `grug_gear:last_light_t3` | Steel Last Light Locket |  | goldsmith T3 | grug_equip_trinket, grug_gear |
| `grug_gear:last_light_t4` | Gold Last Light Locket |  | goldsmith T4 | grug_equip_trinket, grug_gear |
| `grug_gear:last_light_t5` | Embersteel Last Light Locket |  | goldsmith T5 | grug_equip_trinket, grug_gear |
| `grug_gear:last_light_t6` | Abyssal Steel Last Light Locket |  | goldsmith T6 | grug_equip_trinket, grug_gear |
| `grug_gear:legs_cloth_heavy` | Heavy Leggings |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_cloth_patch` | Patch Leggings |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_cloth_silk` | Silk Leggings |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_cloth_silkweave` | Silkweave Leggings |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_cloth_stormweave` | Stormweave Leggings |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_cloth_woven` | Woven Leggings |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_leather_cured` | Cured Pants |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_leather_heavy` | Heavy Pants |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_leather_light` | Light Pants |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_leather_nightscale` | Nightscale Pants |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_leather_scaled` | Scaled Pants |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_leather_sleek` | Sleek Pants |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_metal_abyssal_steel` | Abyssal Steel Greaves |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_metal_bronze` | Bronze Greaves |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_metal_embersteel` | Embersteel Greaves |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_metal_iron` | Iron Greaves |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_metal_silversteel` | Silversteel Greaves |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:legs_metal_steel` | Steel Greaves |  | grid | grug_armor_class, grug_equip_legs, grug_gear |
| `grug_gear:manawell_t1` | Tin Manawell Pendant |  | goldsmith T1 | grug_equip_trinket, grug_gear |
| `grug_gear:manawell_t2` | Iron Manawell Pendant |  | goldsmith T2 | grug_equip_trinket, grug_gear |
| `grug_gear:manawell_t3` | Steel Manawell Pendant |  | goldsmith T3 | grug_equip_trinket, grug_gear |
| `grug_gear:manawell_t4` | Gold Manawell Pendant |  | goldsmith T4 | grug_equip_trinket, grug_gear |
| `grug_gear:manawell_t5` | Embersteel Manawell Pendant |  | goldsmith T5 | grug_equip_trinket, grug_gear |
| `grug_gear:manawell_t6` | Abyssal Steel Manawell Pendant |  | goldsmith T6 | grug_equip_trinket, grug_gear |
| `grug_gear:mercy_seal_t1` | Tin Mercy Seal |  | goldsmith T1 | grug_equip_trinket, grug_gear |
| `grug_gear:mercy_seal_t2` | Iron Mercy Seal |  | goldsmith T2 | grug_equip_trinket, grug_gear |
| `grug_gear:mercy_seal_t3` | Steel Mercy Seal |  | goldsmith T3 | grug_equip_trinket, grug_gear |
| `grug_gear:mercy_seal_t4` | Gold Mercy Seal |  | goldsmith T4 | grug_equip_trinket, grug_gear |
| `grug_gear:mercy_seal_t5` | Embersteel Mercy Seal |  | goldsmith T5 | grug_equip_trinket, grug_gear |
| `grug_gear:mercy_seal_t6` | Abyssal Steel Mercy Seal |  | goldsmith T6 | grug_equip_trinket, grug_gear |
| `grug_gear:reclaimers_mark_t1` | Tin Reclaimer's Mark |  | goldsmith T1 | grug_equip_trinket, grug_gear |
| `grug_gear:reclaimers_mark_t2` | Iron Reclaimer's Mark |  | goldsmith T2 | grug_equip_trinket, grug_gear |
| `grug_gear:reclaimers_mark_t3` | Steel Reclaimer's Mark |  | goldsmith T3 | grug_equip_trinket, grug_gear |
| `grug_gear:reclaimers_mark_t4` | Gold Reclaimer's Mark |  | goldsmith T4 | grug_equip_trinket, grug_gear |
| `grug_gear:reclaimers_mark_t5` | Embersteel Reclaimer's Mark |  | goldsmith T5 | grug_equip_trinket, grug_gear |
| `grug_gear:reclaimers_mark_t6` | Abyssal Steel Reclaimer's Mark |  | goldsmith T6 | grug_equip_trinket, grug_gear |
| `grug_gear:shield_abyssal_steel` | Abyssal Steel Shield |  | grid | grug_equip_offhand, grug_gear, grug_shield |
| `grug_gear:shield_bronze` | Bronze Shield |  | grid | grug_equip_offhand, grug_gear, grug_shield |
| `grug_gear:shield_embersteel` | Embersteel Shield |  | grid | grug_equip_offhand, grug_gear, grug_shield |
| `grug_gear:shield_iron` | Iron Shield |  | grid | grug_equip_offhand, grug_gear, grug_shield |
| `grug_gear:shield_silversteel` | Silversteel Shield |  | grid | grug_equip_offhand, grug_gear, grug_shield |
| `grug_gear:shield_steel` | Steel Shield |  | grid | grug_equip_offhand, grug_gear, grug_shield |
| `grug_gear:spellbook_abyssal_steel` | Abyssal Steel Spellbook |  | goldsmith T6 | grug_equip_offhand, grug_gear, grug_spellbook |
| `grug_gear:spellbook_bronze` | Bronze Spellbook |  | goldsmith T1 | grug_equip_offhand, grug_gear, grug_spellbook |
| `grug_gear:spellbook_embersteel` | Embersteel Spellbook |  | goldsmith T5 | grug_equip_offhand, grug_gear, grug_spellbook |
| `grug_gear:spellbook_iron` | Iron Spellbook |  | goldsmith T2 | grug_equip_offhand, grug_gear, grug_spellbook |
| `grug_gear:spellbook_silversteel` | Silversteel Spellbook |  | goldsmith T4 | grug_equip_offhand, grug_gear, grug_spellbook |
| `grug_gear:spellbook_steel` | Steel Spellbook |  | goldsmith T3 | grug_equip_offhand, grug_gear, grug_spellbook |
| `grug_gear:staff_abyssal_steel` | Abyssal Steel Staff |  | grid | grug_equip_weapon, grug_gear, staff |
| `grug_gear:staff_bronze` | Bronze Staff |  | grid | grug_equip_weapon, grug_gear, staff |
| `grug_gear:staff_embersteel` | Embersteel Staff |  | grid | grug_equip_weapon, grug_gear, staff |
| `grug_gear:staff_iron` | Iron Staff |  | grid | grug_equip_weapon, grug_gear, staff |
| `grug_gear:staff_silversteel` | Silversteel Staff |  | grid | grug_equip_weapon, grug_gear, staff |
| `grug_gear:staff_steel` | Steel Staff |  | grid | grug_equip_weapon, grug_gear, staff |
| `grug_gear:sword_abyssal_steel` | Abyssal Steel Sword |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:sword_bronze` | Bronze Sword |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:sword_embersteel` | Embersteel Sword |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:sword_iron` | Iron Sword |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:sword_silversteel` | Silversteel Sword |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:sword_steel` | Steel Sword |  | grid | grug_equip_weapon, grug_gear, sword |
| `grug_gear:wand_abyssal_steel` | Abyssal Steel Wand |  | grid | grug_caster_weapon, grug_equip_weapon, grug_gear, wand |
| `grug_gear:wand_bronze` | Bronze Wand |  | grid | grug_caster_weapon, grug_equip_weapon, grug_gear, wand |
| `grug_gear:wand_embersteel` | Embersteel Wand |  | grid | grug_caster_weapon, grug_equip_weapon, grug_gear, wand |
| `grug_gear:wand_iron` | Iron Wand |  | grid | grug_caster_weapon, grug_equip_weapon, grug_gear, wand |
| `grug_gear:wand_silversteel` | Silversteel Wand |  | grid | grug_caster_weapon, grug_equip_weapon, grug_gear, wand |
| `grug_gear:wand_steel` | Steel Wand |  | grid | grug_caster_weapon, grug_equip_weapon, grug_gear, wand |

## Other craft items

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `default:book` | Book |  | grid | book |
| `default:book_written` | Book with Text |  | grid | book |
| `default:clay_brick` | Clay Brick |  | furnace, grid |  |
| `default:clay_lump` | Clay Lump |  | grid, dig |  |
| `default:flint` | Flint |  | dig |  |
| `default:obsidian_shard` | Obsidian Shard |  | grid |  |
| `default:paper` | Paper |  | grid |  |
| `doors:door_glass` | Glass Door |  | grid, dig |  |
| `doors:door_obsidian_glass` | Obsidian Glass Door |  | grid, dig |  |
| `doors:door_steel` | Steel Door |  | dig |  |
| `doors:door_wood` | Wooden Door |  | grid, dig |  |
| `dye:black` | Black Dye |  | grid | color_black, dye |
| `dye:blue` | Blue Dye |  | grid | color_blue, dye |
| `dye:brown` | Brown Dye |  | grid | color_brown, dye |
| `dye:cyan` | Cyan Dye |  | grid | color_cyan, dye |
| `dye:dark_green` | Dark Green Dye |  | grid | color_dark_green, dye |
| `dye:dark_grey` | Dark Grey Dye |  | grid | color_dark_grey, dye |
| `dye:green` | Green Dye |  | grid | color_green, dye |
| `dye:grey` | Grey Dye |  | grid | color_grey, dye |
| `dye:magenta` | Magenta Dye |  | grid | color_magenta, dye |
| `dye:orange` | Orange Dye |  | grid | color_orange, dye |
| `dye:pink` | Pink Dye |  | grid | color_pink, dye |
| `dye:red` | Red Dye |  | grid | color_red, dye |
| `dye:violet` | Violet Dye |  | grid | color_violet, dye |
| `dye:white` | White Dye |  |  | color_white, dye |
| `dye:yellow` | Yellow Dye |  |  | color_yellow, dye |
| `grug_cooking:raw_foragers_pot` | Raw Forager's Pot | 3 | grid, cooking T3 | grug_raw_dish |
| `grug_cooking:raw_grand_feast` | Raw Grand Feast | 6 | grid, cooking T6 | grug_raw_dish |
| `grug_cooking:raw_kelp_roast` | Raw Kelp-Wrapped Roast | 5 | grid, cooking T5 | grug_raw_dish |
| `grug_cooking:raw_marsh_roast` | Raw Marsh Roast | 4 | grid, cooking T4 | grug_raw_dish |
| `grug_cooking:raw_pumpkin_pot` | Raw Pumpkin Stew | 2 | grid, cooking T2 | grug_raw_dish |
| `grug_cooking:raw_stew_pot` | Raw Hearty Stew | 1 | grid, cooking T1 | grug_raw_dish |
| `grug_gear:arrow` | Arrow |  | grid | grug_arrow |
| `grug_inventory:bag_great` | Great Cloth Bag (32 slots) |  | tailor T5 | bagslots |
| `grug_inventory:bag_large` | Large Bag (24 slots) |  | tailor T4 | bagslots |
| `grug_inventory:bag_leather_pack` | Leather Pack (24 slots) |  | leatherworker T4 | bagslots |
| `grug_inventory:bag_leather_pouch` | Leather Pouch (8 slots) |  | leatherworker T1 | bagslots |
| `grug_inventory:bag_leather_rucksack` | Leather Rucksack (32 slots) |  | leatherworker T5 | bagslots |
| `grug_inventory:bag_leather_satchel` | Leather Satchel (16 slots) |  | leatherworker T2 | bagslots |
| `grug_inventory:bag_medium` | Medium Bag (16 slots) |  | tailor T2 | bagslots |
| `grug_inventory:bag_small` | Small Bag (8 slots) |  | tailor T1 | bagslots |
| `grug_materials:gravesalt` | Gravesalt |  | dig |  |
| `grug_materials:moonresin` | Moonresin |  | dig |  |
| `grug_materials:red_ochre` | Red Ochre |  | dig |  |
| `grug_materials:runeslate` | Runeslate |  | dig |  |
| `grug_materials:spirit_resin` | Spirit Resin |  | dig |  |
| `grug_materials:sunwax` | Sunwax |  | dig |  |
| `grug_smelting:charcoal` | Charcoal |  | furnace | grug_furnace_fuel |
| `grug_traders:potion_healing_weak` | Weak Healing Potion |  |  | grug_potion, grug_potion_instant |
| `vessels:glass_fragments` | Glass Fragments |  | grid |  |
| `xpanes:door_steel_bar` | Steel Bar Door |  | grid, dig |  |

## Skill items (soulbound; never quest items or rewards)

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `grug_abilities:blink` | Blink (Mage) |  |  |  |
| `grug_abilities:charge` | Charge (Warrior) |  |  |  |
| `grug_abilities:cinderfall` | Cinderfall (Mage) |  |  |  |
| `grug_abilities:fireball` | Fireball (Mage) |  |  |  |
| `grug_abilities:flash_heal` | Flash Heal (Priest) |  |  |  |
| `grug_abilities:frost_nova` | Frost Nova (Mage) |  |  |  |
| `grug_abilities:glacial_ward` | Glacial Ward (Mage) |  |  |  |
| `grug_abilities:hamstring` | Hamstring (Warrior) |  |  |  |
| `grug_abilities:hold_ground` | Hold Ground (Warrior) |  |  |  |
| `grug_abilities:loose` | Loose (Scout) |  |  |  |
| `grug_abilities:mighty_blow` | Mighty Blow (Warrior) |  |  |  |
| `grug_abilities:opening` | Opening (Scout) |  |  |  |
| `grug_abilities:pinning_shot` | Pinning Shot (Scout) |  |  |  |
| `grug_abilities:power_word_shield` | Power Word: Shield (Priest) |  |  |  |
| `grug_abilities:renew` | Renew (Priest) |  |  |  |
| `grug_abilities:sidestep` | Sidestep (Scout) |  |  |  |
| `grug_abilities:smite` | Smite (Priest) |  |  |  |
| `grug_abilities:snare_shot` | Snare Shot (Scout) |  |  |  |
| `grug_abilities:sprint` | Sprint (Scout) |  |  |  |
| `grug_abilities:strike` | Strike (every class) |  |  |  |
| `grug_abilities:taunt` | Taunt (Warrior) |  |  |  |
| `grug_abilities:word_of_ruin` | Word of Ruin (Priest) |  |  |  |
| `grug_mounts:apprentice_mount` | Apprentice Riding | 1 |  | grug_mount |
| `grug_mounts:expert_mount` | Expert Riding | 3 |  | grug_mount |
| `grug_mounts:journeyman_mount` | Journeyman Riding | 2 |  | grug_mount |
| `grug_mounts:master_mount` | Master Riding | 4 |  | grug_mount |

## Ore and gem nodes (dig for the raw item; not quest items)

| Item | Name | Tier | Sources | Groups |
|---|---|---|---|---|
| `default:stone_with_coal` | Coal Ore |  |  | grug_resource |
| `default:stone_with_copper` | Copper Ore |  |  | grug_resource |
| `default:stone_with_gold` | Gold Ore |  |  | grug_resource |
| `default:stone_with_iron` | Iron Ore |  |  | grug_resource |
| `default:stone_with_tin` | Tin Ore |  |  | grug_resource |
| `grug_materials:abyssal_crystal_ore` | Abyssal Crystal Ore |  |  | grug_resource |
| `grug_materials:stone_with_citrine` | Citrine Ore |  |  | grug_resource |
| `grug_materials:stone_with_diamond` | Diamond Ore |  |  | grug_resource |
| `grug_materials:stone_with_emberglass` | Emberglass Ore |  |  | grug_resource |
| `grug_materials:stone_with_garnet` | Garnet Ore |  |  | grug_resource |
| `grug_materials:stone_with_jade` | Jade Ore |  |  | grug_resource |
| `grug_materials:stone_with_quartz` | Quartz Ore |  |  | grug_resource |
| `grug_materials:stone_with_ruby` | Ruby Ore |  |  | grug_resource |
| `grug_materials:stone_with_sapphire` | Sapphire Ore |  |  | grug_resource |
| `grug_materials:stone_with_silver` | Silver Ore |  |  | grug_resource |

## Other nodes (building, decor, terrain)

Names only; see existing.json for groups and descriptions.

- **beds** (4): `bed_bottom`, `bed_top`, `fancy_bed_bottom`, `fancy_bed_top`
- **default** (123): `acacia_bush_leaves`, `acacia_bush_sapling`, `acacia_bush_stem`, `acacia_leaves`, `acacia_sapling`, `apple_mark`, `aspen_leaves`, `aspen_sapling`, `blueberry_bush_leaves`, `blueberry_bush_leaves_with_berries`, `blueberry_bush_sapling`, `bookshelf`, `brick`, `bush_leaves`, `bush_sapling`, `bush_stem`, `cactus`, `cave_ice`, `chest`, `chest_locked`, `chest_locked_open`, `chest_open`, `clay`, `cloud`, `coalblock`, `cobble`, `coral_brown`, `coral_cyan`, `coral_green`, `coral_orange`, `coral_pink`, `coral_skeleton`, `desert_cobble`, `desert_sand`, `desert_sandstone`, `desert_sandstone_block`, `desert_sandstone_brick`, `desert_stone`, `desert_stone_block`, `desert_stonebrick`, `dirt`, `dirt_with_coniferous_litter`, `dirt_with_dry_grass`, `dirt_with_grass`, `dirt_with_grass_footsteps`, `dirt_with_rainforest_litter`, `dirt_with_snow`, `dry_dirt`, `dry_dirt_with_dry_grass`, `dry_grass_1`, `dry_grass_2`, `dry_grass_3`, `dry_grass_4`, `dry_grass_5`, `dry_shrub`, `emergent_jungle_sapling`, `fence_acacia_wood`, `fence_aspen_wood`, `fence_junglewood`, `fence_pine_wood`, `fence_rail_acacia_wood`, `fence_rail_aspen_wood`, `fence_rail_junglewood`, `fence_rail_pine_wood`, `fence_rail_wood`, `fence_wood`, `fern_1`, `fern_2`, `fern_3`, `furnace`, `furnace_active`, `glass`, `grass_1`, `grass_2`, `grass_3`, `grass_4`, `grass_5`, `gravel`, `ice`, `junglegrass`, `jungleleaves`, `junglesapling`, `ladder_wood`, `large_cactus_seedling`, `lava_flowing`, `lava_source`, `leaves`, `marram_grass_1`, `marram_grass_2`, `marram_grass_3`, `mossycobble`, `obsidian`, `obsidian_block`, `obsidian_glass`, `obsidianbrick`, `papyrus`, `permafrost`, `permafrost_with_moss`, `permafrost_with_stones`, `pine_bush_needles`, `pine_bush_sapling`, `pine_bush_stem`, `pine_needles`, `pine_sapling`, `river_water_flowing`, `river_water_source`, `sand`, `sand_with_kelp`, `sandstone`, `sandstone_block`, `sandstonebrick`, `sapling`, `sign_wall_wood`, `snow`, `snowblock`, `stone`, `stone_block`, `stonebrick`, `torch`, `torch_ceiling`, `torch_wall`, `water_flowing`, `water_source`
- **doors** (31): `door_glass_a`, `door_glass_b`, `door_glass_c`, `door_glass_d`, `door_obsidian_glass_a`, `door_obsidian_glass_b`, `door_obsidian_glass_c`, `door_obsidian_glass_d`, `door_steel_a`, `door_steel_b`, `door_steel_c`, `door_steel_d`, `door_wood_a`, `door_wood_b`, `door_wood_c`, `door_wood_d`, `gate_acacia_wood_closed`, `gate_acacia_wood_open`, `gate_aspen_wood_closed`, `gate_aspen_wood_open`, `gate_junglewood_closed`, `gate_junglewood_open`, `gate_pine_wood_closed`, `gate_pine_wood_open`, `gate_wood_closed`, `gate_wood_open`, `hidden`, `trapdoor`, `trapdoor_open`, `trapdoor_steel`, `trapdoor_steel_open`
- **grug_decor** (356): `capital_anvil`, `capital_bedding`, `capital_carving`, `capital_case`, `capital_cloth`, `capital_counter`, `capital_herbs`, `capital_hides`, `capital_lava`, `capital_loom`, `capital_product_alchemist`, `capital_product_armorsmith`, `capital_product_cooking`, `capital_product_goldsmith`, `capital_product_leatherworker`, `capital_product_leatherworker_exterior`, `capital_product_tailor`, `capital_product_weaponsmith`, `capital_product_woodcarver`, `capital_quench`, `capital_rail`, `capital_timber`, `capital_trough`, `castle_arrowslit_castle`, `castle_arrowslit_castle_cross`, `castle_arrowslit_castle_embrasure`, `castle_arrowslit_castle_hole`, `castle_arrowslit_desert_stone_block`, `castle_arrowslit_desert_stone_block_cross`, `castle_arrowslit_desert_stone_block_embrasure`, `castle_arrowslit_desert_stone_block_hole`, `castle_arrowslit_desert_stonebrick`, `castle_arrowslit_desert_stonebrick_cross`, `castle_arrowslit_desert_stonebrick_embrasure`, `castle_arrowslit_desert_stonebrick_hole`, `castle_arrowslit_mossycobble`, `castle_arrowslit_mossycobble_cross`, `castle_arrowslit_mossycobble_embrasure`, `castle_arrowslit_mossycobble_hole`, `castle_arrowslit_obsidianbrick`, `castle_arrowslit_obsidianbrick_cross`, `castle_arrowslit_obsidianbrick_embrasure`, `castle_arrowslit_obsidianbrick_hole`, `castle_arrowslit_sandstonebrick`, `castle_arrowslit_sandstonebrick_cross`, `castle_arrowslit_sandstonebrick_embrasure`, `castle_arrowslit_sandstonebrick_hole`, `castle_arrowslit_silver_sandstone_brick`, `castle_arrowslit_silver_sandstone_brick_cross`, `castle_arrowslit_silver_sandstone_brick_embrasure`, `castle_arrowslit_silver_sandstone_brick_hole`, `castle_arrowslit_stone_block`, `castle_arrowslit_stone_block_cross`, `castle_arrowslit_stone_block_embrasure`, `castle_arrowslit_stone_block_hole`, `castle_arrowslit_stonebrick`, `castle_arrowslit_stonebrick_cross`, `castle_arrowslit_stonebrick_embrasure`, `castle_arrowslit_stonebrick_hole`, `castle_dungeon_stone`, `castle_dungeon_stone_slab`, `castle_dungeon_stone_stair`, `castle_dungeon_stone_stair_inner`, `castle_dungeon_stone_stair_outer`, `castle_hole_castle`, `castle_hole_desert_stone_block`, `castle_hole_desert_stonebrick`, `castle_hole_mossycobble`, `castle_hole_obsidianbrick`, `castle_hole_sandstonebrick`, `castle_hole_silver_sandstone_brick`, `castle_hole_stone_block`, `castle_hole_stonebrick`, `castle_machicolation_castle`, `castle_machicolation_desert_stone_block`, `castle_machicolation_desert_stonebrick`, `castle_machicolation_mossycobble`, `castle_machicolation_obsidianbrick`, `castle_machicolation_sandstonebrick`, `castle_machicolation_silver_sandstone_brick`, `castle_machicolation_stone_block`, `castle_machicolation_stonebrick`, `castle_pavement_brick`, `castle_pavement_brick_slab`, `castle_pavement_brick_stair`, `castle_pavement_brick_stair_inner`, `castle_pavement_brick_stair_outer`, `castle_pillar_castle_bottom`, `castle_pillar_castle_bottom_half`, `castle_pillar_castle_crossbrace`, `castle_pillar_castle_extended_crossbrace`, `castle_pillar_castle_middle`, `castle_pillar_castle_middle_half`, `castle_pillar_castle_top`, `castle_pillar_castle_top_half`, `castle_pillar_desert_stone_block_bottom`, `castle_pillar_desert_stone_block_bottom_half`, `castle_pillar_desert_stone_block_crossbrace`, `castle_pillar_desert_stone_block_extended_crossbrace`, `castle_pillar_desert_stone_block_middle`, `castle_pillar_desert_stone_block_middle_half`, `castle_pillar_desert_stone_block_top`, `castle_pillar_desert_stone_block_top_half`, `castle_pillar_desert_stonebrick_bottom`, `castle_pillar_desert_stonebrick_bottom_half`, `castle_pillar_desert_stonebrick_crossbrace`, `castle_pillar_desert_stonebrick_extended_crossbrace`, `castle_pillar_desert_stonebrick_middle`, `castle_pillar_desert_stonebrick_middle_half`, `castle_pillar_desert_stonebrick_top`, `castle_pillar_desert_stonebrick_top_half`, `castle_pillar_mossycobble_bottom`, `castle_pillar_mossycobble_bottom_half`, `castle_pillar_mossycobble_crossbrace`, `castle_pillar_mossycobble_extended_crossbrace`, `castle_pillar_mossycobble_middle`, `castle_pillar_mossycobble_middle_half`, `castle_pillar_mossycobble_top`, `castle_pillar_mossycobble_top_half`, `castle_pillar_obsidianbrick_bottom`, `castle_pillar_obsidianbrick_bottom_half`, `castle_pillar_obsidianbrick_crossbrace`, `castle_pillar_obsidianbrick_extended_crossbrace`, `castle_pillar_obsidianbrick_middle`, `castle_pillar_obsidianbrick_middle_half`, `castle_pillar_obsidianbrick_top`, `castle_pillar_obsidianbrick_top_half`, `castle_pillar_sandstonebrick_bottom`, `castle_pillar_sandstonebrick_bottom_half`, `castle_pillar_sandstonebrick_crossbrace`, `castle_pillar_sandstonebrick_extended_crossbrace`, `castle_pillar_sandstonebrick_middle`, `castle_pillar_sandstonebrick_middle_half`, `castle_pillar_sandstonebrick_top`, `castle_pillar_sandstonebrick_top_half`, `castle_pillar_silver_sandstone_brick_bottom`, `castle_pillar_silver_sandstone_brick_bottom_half`, `castle_pillar_silver_sandstone_brick_crossbrace`, `castle_pillar_silver_sandstone_brick_extended_crossbrace`, `castle_pillar_silver_sandstone_brick_middle`, `castle_pillar_silver_sandstone_brick_middle_half`, `castle_pillar_silver_sandstone_brick_top`, `castle_pillar_silver_sandstone_brick_top_half`, `castle_pillar_stone_block_bottom`, `castle_pillar_stone_block_bottom_half`, `castle_pillar_stone_block_crossbrace`, `castle_pillar_stone_block_extended_crossbrace`, `castle_pillar_stone_block_middle`, `castle_pillar_stone_block_middle_half`, `castle_pillar_stone_block_top`, `castle_pillar_stone_block_top_half`, `castle_pillar_stonebrick_bottom`, `castle_pillar_stonebrick_bottom_half`, `castle_pillar_stonebrick_crossbrace`, `castle_pillar_stonebrick_extended_crossbrace`, `castle_pillar_stonebrick_middle`, `castle_pillar_stonebrick_middle_half`, `castle_pillar_stonebrick_top`, `castle_pillar_stonebrick_top_half`, `castle_roofslate`, `castle_rubble`, `castle_rubble_slab`, `castle_rubble_stair`, `castle_rubble_stair_inner`, `castle_rubble_stair_outer`, `castle_stonewall`, `castle_stonewall_corner`, `castle_stonewall_slab`, `castle_stonewall_stair`, `castle_stonewall_stair_inner`, `castle_stonewall_stair_outer`, `cottages_anvil`, `cottages_barrel`, `cottages_barrel_lying`, `cottages_barrel_lying_open`, `cottages_barrel_open`, `cottages_bench`, `cottages_clay_slab`, `cottages_clay_stair`, `cottages_clay_stair_inner`, `cottages_clay_stair_outer`, `cottages_glass_pane`, `cottages_glass_pane_side`, `cottages_loam`, `cottages_loam_slab`, `cottages_loam_stair`, `cottages_loam_stair_inner`, `cottages_loam_stair_outer`, `cottages_reet`, `cottages_roof_connector_reet`, `cottages_roof_connector_shingle_red`, `cottages_roof_connector_shingle_wood`, `cottages_roof_connector_slate`, `cottages_roof_connector_straw`, `cottages_roof_connector_wood`, `cottages_roof_flat_reet`, `cottages_roof_flat_shingle_red`, `cottages_roof_flat_shingle_wood`, `cottages_roof_flat_slate`, `cottages_roof_flat_straw`, `cottages_roof_flat_wood`, `cottages_roof_reet`, `cottages_roof_shingle_red`, `cottages_roof_shingle_wood`, `cottages_roof_slate`, `cottages_roof_straw`, `cottages_roof_wood`, `cottages_shelf`, `cottages_slate_vertical`, `cottages_straw`, `cottages_straw_bale`, `cottages_straw_ground`, `cottages_straw_mat`, `cottages_table`, `cottages_tub`, `cottages_wagon_load`, `cottages_wagon_wheel`, `cottages_wagon_wheel_road`, `cottages_washing`, `cottages_window_shutter_closed`, `cottages_window_shutter_open`, `cottages_wood_flat`, `cottages_wool_tent`, `darkage_adobe`, `darkage_basalt`, `darkage_basalt_block`, `darkage_basalt_brick`, `darkage_basalt_brick_slab`, `darkage_basalt_brick_stair`, `darkage_basalt_brick_stair_inner`, `darkage_basalt_brick_stair_outer`, `darkage_basalt_rubble`, `darkage_basalt_rubble_slab`, `darkage_basalt_rubble_stair`, `darkage_basalt_rubble_stair_inner`, `darkage_basalt_rubble_stair_outer`, `darkage_basalt_rubble_wall`, `darkage_basalt_slab`, `darkage_basalt_stair`, `darkage_basalt_stair_inner`, `darkage_basalt_stair_outer`, `darkage_chalk`, `darkage_chalked_bricks`, `darkage_chalked_bricks_slab`, `darkage_chalked_bricks_stair`, `darkage_chalked_bricks_stair_inner`, `darkage_chalked_bricks_stair_outer`, `darkage_glass`, `darkage_glass_round`, `darkage_glass_square`, `darkage_iron_bars`, `darkage_iron_grille`, `darkage_marble`, `darkage_marble_slab`, `darkage_marble_stair`, `darkage_marble_stair_inner`, `darkage_marble_stair_outer`, `darkage_marble_tile`, `darkage_marble_tile_slab`, `darkage_marble_tile_stair`, `darkage_marble_tile_stair_inner`, `darkage_marble_tile_stair_outer`, `darkage_mud`, `darkage_ors`, `darkage_ors_block`, `darkage_ors_brick`, `darkage_ors_brick_slab`, `darkage_ors_brick_stair`, `darkage_ors_brick_stair_inner`, `darkage_ors_brick_stair_outer`, `darkage_ors_rubble`, `darkage_ors_rubble_slab`, `darkage_ors_rubble_stair`, `darkage_ors_rubble_stair_inner`, `darkage_ors_rubble_stair_outer`, `darkage_ors_rubble_wall`, `darkage_ors_slab`, `darkage_ors_stair`, `darkage_ors_stair_inner`, `darkage_ors_stair_outer`, `darkage_reinforced_wood`, `darkage_reinforced_wood_arrow`, `darkage_reinforced_wood_bars`, `darkage_reinforced_wood_slope`, `darkage_serpentine`, `darkage_serpentine_slab`, `darkage_serpentine_stair`, `darkage_serpentine_stair_inner`, `darkage_serpentine_stair_outer`, `darkage_slate`, `darkage_slate_block`, `darkage_slate_brick`, `darkage_slate_brick_slab`, `darkage_slate_brick_stair`, `darkage_slate_brick_stair_inner`, `darkage_slate_brick_stair_outer`, `darkage_slate_rubble`, `darkage_slate_rubble_slab`, `darkage_slate_rubble_stair`, `darkage_slate_rubble_stair_inner`, `darkage_slate_rubble_stair_outer`, `darkage_slate_rubble_wall`, `darkage_slate_slab`, `darkage_slate_stair`, `darkage_slate_stair_inner`, `darkage_slate_stair_outer`, `darkage_slate_tile`, `darkage_slate_tile_slab`, `darkage_slate_tile_stair`, `darkage_slate_tile_stair_inner`, `darkage_slate_tile_stair_outer`, `darkage_stone_brick`, `darkage_stone_brick_slab`, `darkage_stone_brick_stair`, `darkage_stone_brick_stair_inner`, `darkage_stone_brick_stair_outer`, `darkage_stone_brick_wall`, `darkage_straw_bale`, `darkage_straw_bale_slab`, `darkage_straw_bale_stair`, `darkage_straw_bale_stair_inner`, `darkage_straw_bale_stair_outer`, `darkage_wood_bars`, `darkage_wood_frame`, `darkage_wood_grille`, `xdecor_barrel`, `xdecor_candle`, `xdecor_cauldron`, `xdecor_chair`, `xdecor_cobweb`, `xdecor_curtain`, `xdecor_curtain_open`, `xdecor_cushion`, `xdecor_cushion_block`, `xdecor_empty_shelf`, `xdecor_itemframe`, `xdecor_ivy`, `xdecor_lantern`, `xdecor_lantern_hanging`, `xdecor_painting_1`, `xdecor_painting_2`, `xdecor_painting_3`, `xdecor_painting_4`, `xdecor_potted_chrysanthemum_green`, `xdecor_potted_dandelion_white`, `xdecor_potted_dandelion_yellow`, `xdecor_potted_geranium`, `xdecor_potted_rose`, `xdecor_potted_tulip`, `xdecor_potted_tulip_black`, `xdecor_potted_viola`, `xdecor_rope`, `xdecor_stonepath`, `xdecor_table`, `xdecor_woodframed_glass`, `xdecor_workbench`
- **grug_housing** (3): `claim_stone`, `claim_stone_draft`, `claim_stone_empty`
- **grug_jobs** (5): `carving_bench`, `forge`, `jewellers_bench`, `tailor_bench`, `tanning_rack`
- **grug_mapgen** (12): `fire_pepper_source`, `freshwater_waterlily`, `freshwater_waterweed`, `poi_display_dwarf`, `poi_display_elf`, `poi_display_human`, `poi_display_orc`, `poi_display_troll`, `poi_display_undead`, `salt_crust_source`, `sugar_cane_source`, `wild_onion_source`
- **grug_materials** (54): `abyssal_crystal_block`, `abyssal_steel_block`, `basalt`, `bronze_block`, `citrine_block`, `copper_block`, `diamond_block`, `emberglass_block`, `emberglass_lamp`, `emberglass_post_light`, `emberglass_post_light_acacia_wood`, `emberglass_post_light_aspen_wood`, `emberglass_post_light_junglewood`, `emberglass_post_light_pine_wood`, `embersteel_block`, `garnet_block`, `gold_block`, `granite`, `iron_block`, `iron_ladder`, `iron_sign_wall`, `jade_block`, `ruby_block`, `sapphire_block`, `silver_block`, `silversteel_block`, `slab_bronze_block`, `slab_copper_block`, `slab_gold_block`, `slab_iron_block`, `slab_tin_block`, `slate`, `stair_bronze_block`, `stair_copper_block`, `stair_gold_block`, `stair_inner_bronze_block`, `stair_inner_copper_block`, `stair_inner_gold_block`, `stair_inner_iron_block`, `stair_inner_tin_block`, `stair_iron_block`, `stair_outer_bronze_block`, `stair_outer_copper_block`, `stair_outer_gold_block`, `stair_outer_iron_block`, `stair_outer_tin_block`, `stair_tin_block`, `steel_block`, `t2_stone`, `t3_stone`, `t4_stone`, `t5_stone`, `t6_stone`, `tin_block`
- **grug_nodes** (12): `ash_ground`, `blight_dirt`, `bone_pile`, `camp_fire`, `dirt_with_bone_litter`, `dirt_with_canopy_litter`, `dirt_with_forest_litter`, `dirt_with_moss`, `dirt_with_silver_litter`, `guard_banner`, `mesa_clay`, `mud`
- **grug_smelting** (2): `dual_furnace`, `dual_furnace_active`
- **grug_trees** (4): `gravewood_leaves`, `gravewood_sapling`, `silverwood_leaves`, `silverwood_sapling`
- **mobs** (6): `fallback_node`, `fence_top`, `fence_wood`, `hearing_vines`, `hearing_vines_active`, `spawner`
- **stairs** (112): `slab_acacia_wood`, `slab_aspen_wood`, `slab_brick`, `slab_cobble`, `slab_desert_cobble`, `slab_desert_sandstone`, `slab_desert_sandstone_block`, `slab_desert_sandstone_brick`, `slab_desert_stone`, `slab_desert_stone_block`, `slab_desert_stonebrick`, `slab_glass`, `slab_ice`, `slab_junglewood`, `slab_mossycobble`, `slab_obsidian`, `slab_obsidian_block`, `slab_obsidian_glass`, `slab_obsidianbrick`, `slab_pine_wood`, `slab_sandstone`, `slab_sandstone_block`, `slab_sandstonebrick`, `slab_snowblock`, `slab_stone`, `slab_stone_block`, `slab_stonebrick`, `slab_wood`, `stair_acacia_wood`, `stair_aspen_wood`, `stair_brick`, `stair_cobble`, `stair_desert_cobble`, `stair_desert_sandstone`, `stair_desert_sandstone_block`, `stair_desert_sandstone_brick`, `stair_desert_stone`, `stair_desert_stone_block`, `stair_desert_stonebrick`, `stair_glass`, `stair_ice`, `stair_inner_acacia_wood`, `stair_inner_aspen_wood`, `stair_inner_brick`, `stair_inner_cobble`, `stair_inner_desert_cobble`, `stair_inner_desert_sandstone`, `stair_inner_desert_sandstone_block`, `stair_inner_desert_sandstone_brick`, `stair_inner_desert_stone`, `stair_inner_desert_stone_block`, `stair_inner_desert_stonebrick`, `stair_inner_glass`, `stair_inner_ice`, `stair_inner_junglewood`, `stair_inner_mossycobble`, `stair_inner_obsidian`, `stair_inner_obsidian_block`, `stair_inner_obsidian_glass`, `stair_inner_obsidianbrick`, `stair_inner_pine_wood`, `stair_inner_sandstone`, `stair_inner_sandstone_block`, `stair_inner_sandstonebrick`, `stair_inner_snowblock`, `stair_inner_stone`, `stair_inner_stone_block`, `stair_inner_stonebrick`, `stair_inner_wood`, `stair_junglewood`, `stair_mossycobble`, `stair_obsidian`, `stair_obsidian_block`, `stair_obsidian_glass`, `stair_obsidianbrick`, `stair_outer_acacia_wood`, `stair_outer_aspen_wood`, `stair_outer_brick`, `stair_outer_cobble`, `stair_outer_desert_cobble`, `stair_outer_desert_sandstone`, `stair_outer_desert_sandstone_block`, `stair_outer_desert_sandstone_brick`, `stair_outer_desert_stone`, `stair_outer_desert_stone_block`, `stair_outer_desert_stonebrick`, `stair_outer_glass`, `stair_outer_ice`, `stair_outer_junglewood`, `stair_outer_mossycobble`, `stair_outer_obsidian`, `stair_outer_obsidian_block`, `stair_outer_obsidian_glass`, `stair_outer_obsidianbrick`, `stair_outer_pine_wood`, `stair_outer_sandstone`, `stair_outer_sandstone_block`, `stair_outer_sandstonebrick`, `stair_outer_snowblock`, `stair_outer_stone`, `stair_outer_stone_block`, `stair_outer_stonebrick`, `stair_outer_wood`, `stair_pine_wood`, `stair_sandstone`, `stair_sandstone_block`, `stair_sandstonebrick`, `stair_snowblock`, `stair_stone`, `stair_stone_block`, `stair_stonebrick`, `stair_wood`
- **vessels** (3): `drinking_glass`, `glass_bottle`, `shelf`
- **walls** (3): `cobble`, `desertcobble`, `mossycobble`
- **wool** (15): `black`, `blue`, `brown`, `cyan`, `dark_green`, `dark_grey`, `green`, `grey`, `magenta`, `orange`, `pink`, `red`, `violet`, `white`, `yellow`
- **xpanes** (12): `bar`, `bar_flat`, `door_steel_bar_a`, `door_steel_bar_b`, `door_steel_bar_c`, `door_steel_bar_d`, `obsidian_pane`, `obsidian_pane_flat`, `pane`, `pane_flat`, `trapdoor_steel_bar`, `trapdoor_steel_bar_open`

## Item groups

A quest objective `{"type": "item", "group": "tree", "count": 5}` accepts any member.
Recommended groups first; the second table lists every other group with two or
more members that describes a kind of item. Engine dig and placement groups
(cracky, choppy, stair, …) are not objective groups.

| Group | Meaning | Members |
|---|---|---|
| `group:dye` | any dye | `dye:black`, `dye:blue`, `dye:brown`, `dye:cyan`, `dye:dark_green`, `dye:dark_grey`, `dye:green`, `dye:grey`, `dye:magenta`, `dye:orange`, `dye:pink`, `dye:red`, `dye:violet`, `dye:white`, `dye:yellow` |
| `group:flora` | any flower or small plant | `default:dry_grass_1`, `default:dry_grass_2`, `default:dry_grass_3`, `default:dry_grass_4`, `default:dry_grass_5`, `default:fern_1`, `default:fern_2`, `default:fern_3`, `default:grass_1`, `default:grass_2`, `default:grass_3`, `default:grass_4`, `default:grass_5`, `default:junglegrass`, `default:marram_grass_1`, `default:marram_grass_2`, `default:marram_grass_3`, `grug_mapgen:freshwater_waterlily` |
| `group:food_fish_raw` | any raw fish | `grug_fishing:ember_eel`, `grug_fishing:frostfin`, `grug_fishing:mire_carp`, `grug_fishing:silver_trout`, `grug_fishing:storm_tuna`, `grug_mobs:raw_fish` |
| `group:grass` | any grass tuft | `default:dry_grass_1`, `default:dry_grass_2`, `default:dry_grass_3`, `default:dry_grass_4`, `default:dry_grass_5`, `default:fern_1`, `default:fern_2`, `default:fern_3`, `default:grass_1`, `default:grass_2`, `default:grass_3`, `default:grass_4`, `default:grass_5`, `default:junglegrass`, `default:marram_grass_1`, `default:marram_grass_2`, `default:marram_grass_3` |
| `group:grug_cooking_berry` | any berry | `default:blueberries`, `grug_cooking:blightberry`, `grug_cooking:jungle_berry`, `grug_cooking:sunberry` |
| `group:grug_cooking_fruit` | any fruit | `default:apple`, `default:blueberries`, `grug_cooking:blightberry`, `grug_cooking:jungle_berry`, `grug_cooking:sunberry` |
| `group:grug_farming_seed` | any farming seed | `grug_farming:seed_bamboo_shoot`, `grug_farming:seed_blightberry`, `grug_farming:seed_carrot`, `grug_farming:seed_cassava`, `grug_farming:seed_cave_cap`, `grug_farming:seed_corn`, `grug_farming:seed_ember_moss`, `grug_farming:seed_fire_pepper`, `grug_farming:seed_frost_melon`, `grug_farming:seed_jungle_berry`, `grug_farming:seed_potato`, `grug_farming:seed_pumpkin`, `grug_farming:seed_salt_crust`, `grug_farming:seed_sugar_cane`, `grug_farming:seed_sunberry`, `grug_farming:seed_wild_grain`, `grug_farming:seed_wild_onion` |
| `group:grug_food_dish` | any cooked dish | `grug_cooking:berry_preserve`, `grug_cooking:bread`, `grug_cooking:cocoa_rubbed_game`, `grug_cooking:corn_crusted_fish`, `grug_cooking:foragers_pot`, `grug_cooking:fruit_glazed_roast`, `grug_cooking:grand_feast`, `grug_cooking:hearty_stew`, `grug_cooking:hunters_feast`, `grug_cooking:jungle_cocoa`, `grug_cooking:kelp_wrapped_roast`, `grug_cooking:marsh_roast`, `grug_cooking:marshbloom_chowder`, `grug_cooking:mushroom_skewer`, `grug_cooking:onion_seared_steak`, `grug_cooking:pumpkin_stew`, `grug_cooking:salt_crusted_fish`, `grug_cooking:stormkelp_broth`, `grug_cooking:sweetroot_mash`, `grug_fishing:cooked_fish`, `mobs:meat`, `mobs:meatblock` |
| `group:grug_food_raw` | any raw food | `default:apple`, `default:blueberries`, `grug_cooking:bamboo_shoot`, `grug_cooking:blightberry`, `grug_cooking:carrot`, `grug_cooking:cassava`, `grug_cooking:cave_cap`, `grug_cooking:frost_melon`, `grug_cooking:jungle_berry`, `grug_cooking:pumpkin`, `grug_cooking:sunberry`, `grug_cooking:wild_grain`, `grug_fishing:ember_eel`, `grug_fishing:frostfin`, `grug_fishing:mire_carp`, `grug_fishing:silver_trout`, `grug_fishing:storm_tuna`, `grug_gathering:corn`, `grug_gathering:melon`, `grug_gathering:mushroom`, `grug_gathering:potato`, `grug_gathering:wild_cocoa`, `grug_mobs:raw_fish`, `mobs:meat_raw`, `mobs:meatblock_raw` |
| `group:grug_healing_herb` | any healing herb | `grug_gathering:crimson_lotus_source`, `grug_gathering:dragonweed_source`, `grug_gathering:gravemoss_source`, `grug_mapgen:ember_moss_source` |
| `group:grug_leather` | any leather | `grug_mobs:heavy_leather`, `grug_mobs:light_leather`, `grug_mobs:scaled_hide` |
| `group:grug_material` | profession/loot material | `grug_mobs:ape_hair`, `grug_mobs:arrow`, `grug_mobs:bear_claw`, `grug_mobs:boar_tusk`, `grug_mobs:bone`, `grug_mobs:croc_tooth`, `grug_mobs:fang`, `grug_mobs:feather`, `grug_mobs:heavy_cloth`, `grug_mobs:heavy_leather`, `grug_mobs:light_leather`, `grug_mobs:linen_cloth`, `grug_mobs:linen_scrap`, `grug_mobs:raptor_claw`, `grug_mobs:scaled_hide`, `grug_mobs:sharp_feather`, `grug_mobs:shiny_scale`, `grug_mobs:sleek_pelt`, `grug_mobs:slime_gel`, `grug_mobs:spider_silk`, `grug_mobs:stone_core`, `grug_mobs:venom_gland`, `grug_mobs:venom_sac`, `grug_mobs:zombie_flesh` |
| `group:grug_plant_item` | any gathered plant item | `grug_cooking:bamboo_shoot`, `grug_cooking:blightberry`, `grug_cooking:carrot`, `grug_cooking:cassava`, `grug_cooking:cave_cap`, `grug_cooking:ember_moss`, `grug_cooking:fire_pepper`, `grug_cooking:frost_melon`, `grug_cooking:jungle_berry`, `grug_cooking:pumpkin`, `grug_cooking:salt_crust`, `grug_cooking:sugar_cane`, `grug_cooking:sunberry`, `grug_cooking:wild_grain`, `grug_cooking:wild_onion` |
| `group:grug_potion` | any potion | `grug_alchemy:elixir_deepwater`, `grug_alchemy:elixir_focus_t3`, `grug_alchemy:elixir_focus_t4`, `grug_alchemy:elixir_focus_t5`, `grug_alchemy:elixir_focus_t6`, `grug_alchemy:elixir_precision_t3`, `grug_alchemy:elixir_precision_t4`, `grug_alchemy:elixir_precision_t5`, `grug_alchemy:elixir_precision_t6`, `grug_alchemy:elixir_stoneskin`, `grug_alchemy:elixir_vigor_t3`, `grug_alchemy:elixir_vigor_t4`, `grug_alchemy:elixir_vigor_t5`, `grug_alchemy:elixir_vigor_t6`, `grug_alchemy:potion_antivenom`, `grug_alchemy:potion_cave`, `grug_alchemy:potion_greater_healing`, `grug_alchemy:potion_greater_mana`, `grug_alchemy:potion_healing`, `grug_alchemy:potion_mana`, `grug_alchemy:potion_swiftness`, `grug_traders:potion_healing_weak` |
| `group:grug_profession_material` | processed profession material | `grug_artisans:hardened_wood`, `grug_artisans:heartwood_wood`, `grug_artisans:inlaid_wood`, `grug_artisans:lacquered_wood`, `grug_artisans:ornament_components_t3`, `grug_artisans:ornament_components_t4`, `grug_artisans:ornament_components_t5`, `grug_artisans:ornament_components_t6`, `grug_artisans:polished_wood`, `grug_artisans:seasoned_wood`, `grug_artisans:setting_copper_inlaid_steel`, `grug_artisans:setting_gold`, `grug_artisans:setting_gold_filigreed_abyssal_steel`, `grug_artisans:setting_gold_filigreed_embersteel`, `grug_artisans:setting_iron`, `grug_artisans:setting_tin`, `grug_professions:bolt_heavy`, `grug_professions:bolt_patch`, `grug_professions:bolt_silk`, `grug_professions:bolt_silkweave`, `grug_professions:bolt_stormweave`, `grug_professions:bolt_woven`, `grug_professions:cured_leather`, `grug_professions:nightscale_leather`, `grug_professions:sleek_leather`, `grug_professions:weapon_grip_cured`, `grug_professions:weapon_grip_heavy`, `grug_professions:weapon_grip_light`, `grug_professions:weapon_grip_nightscale`, `grug_professions:weapon_grip_scaled`, `grug_professions:weapon_grip_sleek` |
| `group:grug_tailor_bolt` | any cloth bolt | `grug_professions:bolt_heavy`, `grug_professions:bolt_patch`, `grug_professions:bolt_silk`, `grug_professions:bolt_silkweave`, `grug_professions:bolt_stormweave`, `grug_professions:bolt_woven` |
| `group:grug_wood_grade` | any seasoned wood grade | `grug_artisans:hardened_wood`, `grug_artisans:heartwood_wood`, `grug_artisans:inlaid_wood`, `grug_artisans:lacquered_wood`, `grug_artisans:polished_wood`, `grug_artisans:seasoned_wood` |
| `group:leaves` | any leaves | `default:acacia_bush_leaves`, `default:acacia_leaves`, `default:aspen_leaves`, `default:blueberry_bush_leaves`, `default:blueberry_bush_leaves_with_berries`, `default:bush_leaves`, `default:jungleleaves`, `default:leaves`, `default:pine_bush_needles`, `default:pine_needles`, `grug_trees:gravewood_leaves`, `grug_trees:silverwood_leaves` |
| `group:sand` | any sand | `default:desert_sand`, `default:sand`, `default:silver_sand`, `grug_mapgen:freshwater_waterweed` |
| `group:sapling` | any sapling | `default:acacia_bush_sapling`, `default:acacia_sapling`, `default:aspen_sapling`, `default:blueberry_bush_sapling`, `default:bush_sapling`, `default:emergent_jungle_sapling`, `default:junglesapling`, `default:pine_bush_sapling`, `default:pine_sapling`, `default:sapling`, `grug_trees:gravewood_sapling`, `grug_trees:silverwood_sapling` |
| `group:seed` | any seed | `grug_farming:seed_bamboo_shoot`, `grug_farming:seed_blightberry`, `grug_farming:seed_carrot`, `grug_farming:seed_cassava`, `grug_farming:seed_cave_cap`, `grug_farming:seed_corn`, `grug_farming:seed_ember_moss`, `grug_farming:seed_fire_pepper`, `grug_farming:seed_frost_melon`, `grug_farming:seed_jungle_berry`, `grug_farming:seed_potato`, `grug_farming:seed_pumpkin`, `grug_farming:seed_salt_crust`, `grug_farming:seed_sugar_cane`, `grug_farming:seed_sunberry`, `grug_farming:seed_wild_grain`, `grug_farming:seed_wild_onion` |
| `group:stick` | sticks | `default:stick` |
| `group:stone` | any plain stone / cobble | `default:cobble`, `default:desert_cobble`, `default:desert_stone`, `default:desert_stone_block`, `default:desert_stonebrick`, `default:mossycobble`, `default:stone`, `default:stone_block`, `default:stonebrick`, `walls:cobble`, `walls:desertcobble`, `walls:mossycobble` |
| `group:tree` | any log (trunk node) | `default:acacia_tree`, `default:aspen_tree`, `default:jungletree`, `default:pine_tree`, `default:tree`, `grug_trees:gravewood_tree`, `grug_trees:silverwood_tree` |
| `group:wood` | any planks | `default:acacia_wood`, `default:aspen_wood`, `default:junglewood`, `default:pine_wood`, `default:wood`, `grug_trees:gravewood_wood`, `grug_trees:silverwood_wood` |
| `group:wool` | any wool | `wool:black`, `wool:blue`, `wool:brown`, `wool:cyan`, `wool:dark_green`, `wool:dark_grey`, `wool:green`, `wool:grey`, `wool:magenta`, `wool:orange`, `wool:pink`, `wool:red`, `wool:violet`, `wool:white`, `wool:yellow` |

| Group | Members |
|---|---|
| `group:axe` | `grug_gear:greataxe_abyssal_steel`, `grug_gear:greataxe_bronze`, `grug_gear:greataxe_embersteel`, `grug_gear:greataxe_iron`, `grug_gear:greataxe_silversteel`, `grug_gear:greataxe_steel`, `grug_materials:axe_abyssal_steel`, `grug_materials:axe_bronze`, `grug_materials:axe_embersteel`, `grug_materials:axe_iron`, `grug_materials:axe_silversteel`, `grug_materials:axe_steel`, `grug_materials:axe_stone`, `grug_materials:axe_wood` |
| `group:bagslots` | `grug_inventory:bag_great`, `grug_inventory:bag_large`, `grug_inventory:bag_leather_pack`, `grug_inventory:bag_leather_pouch`, `grug_inventory:bag_leather_rucksack`, `grug_inventory:bag_leather_satchel`, `grug_inventory:bag_medium`, `grug_inventory:bag_small` |
| `group:book` | `default:book`, `default:book_written` |
| `group:bow` | `grug_gear:bow_abyssal_steel`, `grug_gear:bow_bronze`, `grug_gear:bow_embersteel`, `grug_gear:bow_iron`, `grug_gear:bow_silversteel`, `grug_gear:bow_steel` |
| `group:dry_grass` | `default:dry_grass_1`, `default:dry_grass_2`, `default:dry_grass_3`, `default:dry_grass_4`, `default:dry_grass_5` |
| `group:fern` | `default:fern_1`, `default:fern_2`, `default:fern_3` |
| `group:grug_armor_class` | `grug_gear:chest_cloth_heavy`, `grug_gear:chest_cloth_patch`, `grug_gear:chest_cloth_silk`, `grug_gear:chest_cloth_silkweave`, `grug_gear:chest_cloth_stormweave`, `grug_gear:chest_cloth_woven`, `grug_gear:chest_leather_cured`, `grug_gear:chest_leather_heavy`, `grug_gear:chest_leather_light`, `grug_gear:chest_leather_nightscale`, `grug_gear:chest_leather_scaled`, `grug_gear:chest_leather_sleek`, `grug_gear:chest_metal_abyssal_steel`, `grug_gear:chest_metal_bronze`, `grug_gear:chest_metal_embersteel`, `grug_gear:chest_metal_iron`, `grug_gear:chest_metal_silversteel`, `grug_gear:chest_metal_steel`, `grug_gear:feet_cloth_heavy`, `grug_gear:feet_cloth_patch`, `grug_gear:feet_cloth_silk`, `grug_gear:feet_cloth_silkweave`, `grug_gear:feet_cloth_stormweave`, `grug_gear:feet_cloth_woven`, `grug_gear:feet_leather_cured`, `grug_gear:feet_leather_heavy`, `grug_gear:feet_leather_light`, `grug_gear:feet_leather_nightscale`, `grug_gear:feet_leather_scaled`, `grug_gear:feet_leather_sleek`, `grug_gear:feet_metal_abyssal_steel`, `grug_gear:feet_metal_bronze`, `grug_gear:feet_metal_embersteel`, `grug_gear:feet_metal_iron`, `grug_gear:feet_metal_silversteel`, `grug_gear:feet_metal_steel`, `grug_gear:head_cloth_heavy`, `grug_gear:head_cloth_patch`, `grug_gear:head_cloth_silk`, `grug_gear:head_cloth_silkweave`, … (32 more) |
| `group:grug_axe_tier` | `grug_materials:axe_abyssal_steel`, `grug_materials:axe_bronze`, `grug_materials:axe_embersteel`, `grug_materials:axe_iron`, `grug_materials:axe_silversteel`, `grug_materials:axe_steel`, `grug_materials:axe_stone`, `grug_materials:axe_wood` |
| `group:grug_bow` | `grug_gear:bow_abyssal_steel`, `grug_gear:bow_bronze`, `grug_gear:bow_embersteel`, `grug_gear:bow_iron`, `grug_gear:bow_silversteel`, `grug_gear:bow_steel` |
| `group:grug_bucket` | `grug_farming:empty_iron_bucket`, `grug_farming:water_bucket` |
| `group:grug_caster_weapon` | `grug_gear:wand_abyssal_steel`, `grug_gear:wand_bronze`, `grug_gear:wand_embersteel`, `grug_gear:wand_iron`, `grug_gear:wand_silversteel`, `grug_gear:wand_steel` |
| `group:grug_cooking_early_spice` | `grug_cooking:fire_pepper`, `grug_cooking:wild_onion` |
| `group:grug_cooking_root` | `grug_cooking:carrot`, `grug_cooking:cassava` |
| `group:grug_cooking_staple` | `grug_gathering:corn`, `grug_gathering:potato` |
| `group:grug_cultural_source` | `grug_gathering:gravesalt_source`, `grug_gathering:moonresin_source`, `grug_gathering:red_ochre_source`, `grug_gathering:runeslate_source`, `grug_gathering:spirit_resin_source`, `grug_gathering:sunwax_source` |
| `group:grug_decorative_rock` | `grug_materials:basalt`, `grug_materials:granite`, `grug_materials:slate` |
| `group:grug_elixir` | `grug_alchemy:elixir_deepwater`, `grug_alchemy:elixir_focus_t3`, `grug_alchemy:elixir_focus_t4`, `grug_alchemy:elixir_focus_t5`, `grug_alchemy:elixir_focus_t6`, `grug_alchemy:elixir_precision_t3`, `grug_alchemy:elixir_precision_t4`, `grug_alchemy:elixir_precision_t5`, `grug_alchemy:elixir_precision_t6`, `grug_alchemy:elixir_stoneskin`, `grug_alchemy:elixir_vigor_t3`, `grug_alchemy:elixir_vigor_t4`, `grug_alchemy:elixir_vigor_t5`, `grug_alchemy:elixir_vigor_t6` |
| `group:grug_equip_chest` | `grug_gear:chest_cloth_heavy`, `grug_gear:chest_cloth_patch`, `grug_gear:chest_cloth_silk`, `grug_gear:chest_cloth_silkweave`, `grug_gear:chest_cloth_stormweave`, `grug_gear:chest_cloth_woven`, `grug_gear:chest_leather_cured`, `grug_gear:chest_leather_heavy`, `grug_gear:chest_leather_light`, `grug_gear:chest_leather_nightscale`, `grug_gear:chest_leather_scaled`, `grug_gear:chest_leather_sleek`, `grug_gear:chest_metal_abyssal_steel`, `grug_gear:chest_metal_bronze`, `grug_gear:chest_metal_embersteel`, `grug_gear:chest_metal_iron`, `grug_gear:chest_metal_silversteel`, `grug_gear:chest_metal_steel` |
| `group:grug_equip_feet` | `grug_gear:feet_cloth_heavy`, `grug_gear:feet_cloth_patch`, `grug_gear:feet_cloth_silk`, `grug_gear:feet_cloth_silkweave`, `grug_gear:feet_cloth_stormweave`, `grug_gear:feet_cloth_woven`, `grug_gear:feet_leather_cured`, `grug_gear:feet_leather_heavy`, `grug_gear:feet_leather_light`, `grug_gear:feet_leather_nightscale`, `grug_gear:feet_leather_scaled`, `grug_gear:feet_leather_sleek`, `grug_gear:feet_metal_abyssal_steel`, `grug_gear:feet_metal_bronze`, `grug_gear:feet_metal_embersteel`, `grug_gear:feet_metal_iron`, `grug_gear:feet_metal_silversteel`, `grug_gear:feet_metal_steel` |
| `group:grug_equip_head` | `grug_gear:head_cloth_heavy`, `grug_gear:head_cloth_patch`, `grug_gear:head_cloth_silk`, `grug_gear:head_cloth_silkweave`, `grug_gear:head_cloth_stormweave`, `grug_gear:head_cloth_woven`, `grug_gear:head_leather_cured`, `grug_gear:head_leather_heavy`, `grug_gear:head_leather_light`, `grug_gear:head_leather_nightscale`, `grug_gear:head_leather_scaled`, `grug_gear:head_leather_sleek`, `grug_gear:head_metal_abyssal_steel`, `grug_gear:head_metal_bronze`, `grug_gear:head_metal_embersteel`, `grug_gear:head_metal_iron`, `grug_gear:head_metal_silversteel`, `grug_gear:head_metal_steel` |
| `group:grug_equip_legs` | `grug_gear:legs_cloth_heavy`, `grug_gear:legs_cloth_patch`, `grug_gear:legs_cloth_silk`, `grug_gear:legs_cloth_silkweave`, `grug_gear:legs_cloth_stormweave`, `grug_gear:legs_cloth_woven`, `grug_gear:legs_leather_cured`, `grug_gear:legs_leather_heavy`, `grug_gear:legs_leather_light`, `grug_gear:legs_leather_nightscale`, `grug_gear:legs_leather_scaled`, `grug_gear:legs_leather_sleek`, `grug_gear:legs_metal_abyssal_steel`, `grug_gear:legs_metal_bronze`, `grug_gear:legs_metal_embersteel`, `grug_gear:legs_metal_iron`, `grug_gear:legs_metal_silversteel`, `grug_gear:legs_metal_steel` |
| `group:grug_equip_offhand` | `grug_gear:shield_abyssal_steel`, `grug_gear:shield_bronze`, `grug_gear:shield_embersteel`, `grug_gear:shield_iron`, `grug_gear:shield_silversteel`, `grug_gear:shield_steel`, `grug_gear:spellbook_abyssal_steel`, `grug_gear:spellbook_bronze`, `grug_gear:spellbook_embersteel`, `grug_gear:spellbook_iron`, `grug_gear:spellbook_silversteel`, `grug_gear:spellbook_steel` |
| `group:grug_equip_trinket` | `grug_gear:apothecary_loop_t1`, `grug_gear:apothecary_loop_t2`, `grug_gear:apothecary_loop_t3`, `grug_gear:apothecary_loop_t4`, `grug_gear:apothecary_loop_t5`, `grug_gear:apothecary_loop_t6`, `grug_gear:battlebeat_t1`, `grug_gear:battlebeat_t2`, `grug_gear:battlebeat_t3`, `grug_gear:battlebeat_t4`, `grug_gear:battlebeat_t5`, `grug_gear:battlebeat_t6`, `grug_gear:last_light_t1`, `grug_gear:last_light_t2`, `grug_gear:last_light_t3`, `grug_gear:last_light_t4`, `grug_gear:last_light_t5`, `grug_gear:last_light_t6`, `grug_gear:manawell_t1`, `grug_gear:manawell_t2`, `grug_gear:manawell_t3`, `grug_gear:manawell_t4`, `grug_gear:manawell_t5`, `grug_gear:manawell_t6`, `grug_gear:mercy_seal_t1`, `grug_gear:mercy_seal_t2`, `grug_gear:mercy_seal_t3`, `grug_gear:mercy_seal_t4`, `grug_gear:mercy_seal_t5`, `grug_gear:mercy_seal_t6`, `grug_gear:reclaimers_mark_t1`, `grug_gear:reclaimers_mark_t2`, `grug_gear:reclaimers_mark_t3`, `grug_gear:reclaimers_mark_t4`, `grug_gear:reclaimers_mark_t5`, `grug_gear:reclaimers_mark_t6` |
| `group:grug_equip_weapon` | `grug_gear:bow_abyssal_steel`, `grug_gear:bow_bronze`, `grug_gear:bow_embersteel`, `grug_gear:bow_iron`, `grug_gear:bow_silversteel`, `grug_gear:bow_steel`, `grug_gear:dagger_abyssal_steel`, `grug_gear:dagger_bronze`, `grug_gear:dagger_embersteel`, `grug_gear:dagger_iron`, `grug_gear:dagger_silversteel`, `grug_gear:dagger_steel`, `grug_gear:greataxe_abyssal_steel`, `grug_gear:greataxe_bronze`, `grug_gear:greataxe_embersteel`, `grug_gear:greataxe_iron`, `grug_gear:greataxe_silversteel`, `grug_gear:greataxe_steel`, `grug_gear:staff_abyssal_steel`, `grug_gear:staff_bronze`, `grug_gear:staff_embersteel`, `grug_gear:staff_iron`, `grug_gear:staff_silversteel`, `grug_gear:staff_steel`, `grug_gear:sword_abyssal_steel`, `grug_gear:sword_bronze`, `grug_gear:sword_embersteel`, `grug_gear:sword_iron`, `grug_gear:sword_silversteel`, `grug_gear:sword_steel`, `grug_gear:wand_abyssal_steel`, `grug_gear:wand_bronze`, `grug_gear:wand_embersteel`, `grug_gear:wand_iron`, `grug_gear:wand_silversteel`, `grug_gear:wand_steel` |
| `group:grug_farming_crop` | `grug_farming:bamboo_shoot_1`, `grug_farming:bamboo_shoot_2`, `grug_farming:bamboo_shoot_3`, `grug_farming:bamboo_shoot_4`, `grug_farming:blightberry_1`, `grug_farming:blightberry_2`, `grug_farming:blightberry_3`, `grug_farming:blightberry_4`, `grug_farming:carrot_1`, `grug_farming:carrot_2`, `grug_farming:carrot_3`, `grug_farming:carrot_4`, `grug_farming:cassava_1`, `grug_farming:cassava_2`, `grug_farming:cassava_3`, `grug_farming:cassava_4`, `grug_farming:cave_cap_1`, `grug_farming:cave_cap_2`, `grug_farming:cave_cap_3`, `grug_farming:cave_cap_4`, `grug_farming:corn_1`, `grug_farming:corn_2`, `grug_farming:corn_3`, `grug_farming:corn_4`, `grug_farming:ember_moss_1`, `grug_farming:ember_moss_2`, `grug_farming:ember_moss_3`, `grug_farming:ember_moss_4`, `grug_farming:fire_pepper_1`, `grug_farming:fire_pepper_2`, `grug_farming:fire_pepper_3`, `grug_farming:fire_pepper_4`, `grug_farming:frost_melon_1`, `grug_farming:frost_melon_2`, `grug_farming:frost_melon_3`, `grug_farming:frost_melon_4`, `grug_farming:jungle_berry_1`, `grug_farming:jungle_berry_2`, `grug_farming:jungle_berry_3`, `grug_farming:jungle_berry_4`, … (28 more) |
| `group:grug_farming_hoe` | `grug_farming:hoe`, `grug_farming:hoe_abyssal_steel`, `grug_farming:hoe_bronze`, `grug_farming:hoe_embersteel`, `grug_farming:hoe_iron`, `grug_farming:hoe_silversteel`, `grug_farming:hoe_steel`, `grug_farming:hoe_stone` |
| `group:grug_food` | `default:apple`, `default:blueberries`, `grug_cooking:bamboo_shoot`, `grug_cooking:berry_preserve`, `grug_cooking:blightberry`, `grug_cooking:bread`, `grug_cooking:carrot`, `grug_cooking:cassava`, `grug_cooking:cave_cap`, `grug_cooking:cocoa_rubbed_game`, `grug_cooking:corn_crusted_fish`, `grug_cooking:foragers_pot`, `grug_cooking:frost_melon`, `grug_cooking:fruit_glazed_roast`, `grug_cooking:grand_feast`, `grug_cooking:hearty_stew`, `grug_cooking:hunters_feast`, `grug_cooking:jungle_berry`, `grug_cooking:jungle_cocoa`, `grug_cooking:kelp_wrapped_roast`, `grug_cooking:marsh_roast`, `grug_cooking:marshbloom_chowder`, `grug_cooking:mushroom_skewer`, `grug_cooking:onion_seared_steak`, `grug_cooking:pumpkin`, `grug_cooking:pumpkin_stew`, `grug_cooking:salt_crusted_fish`, `grug_cooking:stormkelp_broth`, `grug_cooking:sunberry`, `grug_cooking:sweetroot_mash`, `grug_cooking:wild_grain`, `grug_fishing:cooked_fish`, `grug_fishing:ember_eel`, `grug_fishing:frostfin`, `grug_fishing:mire_carp`, `grug_fishing:silver_trout`, `grug_fishing:storm_tuna`, `grug_gathering:corn`, `grug_gathering:corn_source`, `grug_gathering:melon`, … (23 more) |
| `group:grug_food_role_caster` | `grug_cooking:berry_preserve`, `grug_cooking:jungle_cocoa`, `grug_cooking:marshbloom_chowder`, `grug_cooking:mushroom_skewer`, `grug_cooking:stormkelp_broth`, `grug_cooking:sweetroot_mash` |
| `group:grug_food_role_hearty` | `grug_cooking:bread`, `grug_cooking:foragers_pot`, `grug_cooking:grand_feast`, `grug_cooking:hearty_stew`, `grug_cooking:kelp_wrapped_roast`, `grug_cooking:marsh_roast`, `grug_cooking:pumpkin_stew`, `grug_fishing:cooked_fish`, `mobs:meat`, `mobs:meatblock` |
| `group:grug_food_role_hp` | `default:apple`, `default:blueberries`, `grug_cooking:bamboo_shoot`, `grug_cooking:blightberry`, `grug_cooking:carrot`, `grug_cooking:cassava`, `grug_cooking:cave_cap`, `grug_cooking:frost_melon`, `grug_cooking:jungle_berry`, `grug_cooking:pumpkin`, `grug_cooking:sunberry`, `grug_cooking:wild_grain`, `grug_fishing:ember_eel`, `grug_fishing:frostfin`, `grug_fishing:mire_carp`, `grug_fishing:silver_trout`, `grug_fishing:storm_tuna`, `grug_gathering:corn`, `grug_gathering:melon`, `grug_gathering:mushroom`, `grug_gathering:potato`, `grug_gathering:wild_cocoa`, `grug_mobs:raw_fish`, `mobs:meat_raw`, `mobs:meatblock_raw` |
| `group:grug_food_role_hunter` | `grug_cooking:cocoa_rubbed_game`, `grug_cooking:corn_crusted_fish`, `grug_cooking:fruit_glazed_roast`, `grug_cooking:hunters_feast`, `grug_cooking:onion_seared_steak`, `grug_cooking:salt_crusted_fish` |
| `group:grug_food_tier` | `default:apple`, `default:blueberries`, `grug_cooking:bamboo_shoot`, `grug_cooking:berry_preserve`, `grug_cooking:blightberry`, `grug_cooking:bread`, `grug_cooking:carrot`, `grug_cooking:cassava`, `grug_cooking:cave_cap`, `grug_cooking:cocoa_rubbed_game`, `grug_cooking:corn_crusted_fish`, `grug_cooking:foragers_pot`, `grug_cooking:frost_melon`, `grug_cooking:fruit_glazed_roast`, `grug_cooking:grand_feast`, `grug_cooking:hearty_stew`, `grug_cooking:hunters_feast`, `grug_cooking:jungle_berry`, `grug_cooking:jungle_cocoa`, `grug_cooking:kelp_wrapped_roast`, `grug_cooking:marsh_roast`, `grug_cooking:marshbloom_chowder`, `grug_cooking:mushroom_skewer`, `grug_cooking:onion_seared_steak`, `grug_cooking:pumpkin`, `grug_cooking:pumpkin_stew`, `grug_cooking:salt_crusted_fish`, `grug_cooking:stormkelp_broth`, `grug_cooking:sunberry`, `grug_cooking:sweetroot_mash`, `grug_cooking:wild_grain`, `grug_fishing:cooked_fish`, `grug_fishing:ember_eel`, `grug_fishing:frostfin`, `grug_fishing:mire_carp`, `grug_fishing:silver_trout`, `grug_fishing:storm_tuna`, `grug_gathering:corn`, `grug_gathering:melon`, `grug_gathering:mushroom`, … (7 more) |
| `group:grug_found_only_food` | `grug_gathering:mushroom_source`, `grug_gathering:rock_salt_source`, `grug_gathering:wild_cocoa_source` |
| `group:grug_gathering_source` | `grug_gathering:corn_source`, `grug_gathering:crimson_lotus_source`, `grug_gathering:dragonweed_source`, `grug_gathering:gravemoss_source`, `grug_gathering:gravesalt_source`, `grug_gathering:marshbloom_source`, `grug_gathering:melon_source`, `grug_gathering:moonresin_source`, `grug_gathering:mushroom_source`, `grug_gathering:potato_source`, `grug_gathering:red_ochre_source`, `grug_gathering:rock_salt_source`, `grug_gathering:runeslate_source`, `grug_gathering:spirit_resin_source`, `grug_gathering:stormkelp_source`, `grug_gathering:sunleaf_source`, `grug_gathering:sunwax_source`, `grug_gathering:wild_cocoa_source`, `grug_mapgen:bamboo_shoot_source`, `grug_mapgen:blightberry_source`, `grug_mapgen:carrot_source`, `grug_mapgen:cassava_source`, `grug_mapgen:cave_cap_source`, `grug_mapgen:ember_moss_source`, `grug_mapgen:fire_pepper_source`, `grug_mapgen:frost_melon_source`, `grug_mapgen:jungle_berry_source`, `grug_mapgen:pumpkin_source`, `grug_mapgen:salt_crust_source`, `grug_mapgen:sugar_cane_source`, `grug_mapgen:sunberry_source`, `grug_mapgen:wild_grain_source`, `grug_mapgen:wild_onion_source` |
| `group:grug_gathering_tool` | `grug_farming:hoe`, `grug_farming:hoe_abyssal_steel`, `grug_farming:hoe_bronze`, `grug_farming:hoe_embersteel`, `grug_farming:hoe_iron`, `grug_farming:hoe_silversteel`, `grug_farming:hoe_steel`, `grug_farming:hoe_stone`, `grug_materials:axe_abyssal_steel`, `grug_materials:axe_bronze`, `grug_materials:axe_embersteel`, `grug_materials:axe_iron`, `grug_materials:axe_silversteel`, `grug_materials:axe_steel`, `grug_materials:axe_stone`, `grug_materials:axe_wood`, `grug_materials:pick_abyssal_steel`, `grug_materials:pick_bronze`, `grug_materials:pick_embersteel`, `grug_materials:pick_iron`, `grug_materials:pick_silversteel`, `grug_materials:pick_steel`, `grug_materials:pick_stone`, `grug_materials:pick_wood`, `grug_materials:shovel_abyssal_steel`, `grug_materials:shovel_bronze`, `grug_materials:shovel_embersteel`, `grug_materials:shovel_iron`, `grug_materials:shovel_silversteel`, `grug_materials:shovel_steel`, `grug_materials:shovel_stone`, `grug_materials:shovel_wood` |
| `group:grug_gear` | `grug_gear:apothecary_loop_t1`, `grug_gear:apothecary_loop_t2`, `grug_gear:apothecary_loop_t3`, `grug_gear:apothecary_loop_t4`, `grug_gear:apothecary_loop_t5`, `grug_gear:apothecary_loop_t6`, `grug_gear:battlebeat_t1`, `grug_gear:battlebeat_t2`, `grug_gear:battlebeat_t3`, `grug_gear:battlebeat_t4`, `grug_gear:battlebeat_t5`, `grug_gear:battlebeat_t6`, `grug_gear:bow_abyssal_steel`, `grug_gear:bow_bronze`, `grug_gear:bow_embersteel`, `grug_gear:bow_iron`, `grug_gear:bow_silversteel`, `grug_gear:bow_steel`, `grug_gear:chest_cloth_heavy`, `grug_gear:chest_cloth_patch`, `grug_gear:chest_cloth_silk`, `grug_gear:chest_cloth_silkweave`, `grug_gear:chest_cloth_stormweave`, `grug_gear:chest_cloth_woven`, `grug_gear:chest_leather_cured`, `grug_gear:chest_leather_heavy`, `grug_gear:chest_leather_light`, `grug_gear:chest_leather_nightscale`, `grug_gear:chest_leather_scaled`, `grug_gear:chest_leather_sleek`, `grug_gear:chest_metal_abyssal_steel`, `grug_gear:chest_metal_bronze`, `grug_gear:chest_metal_embersteel`, `grug_gear:chest_metal_iron`, `grug_gear:chest_metal_silversteel`, `grug_gear:chest_metal_steel`, `grug_gear:dagger_abyssal_steel`, `grug_gear:dagger_bronze`, `grug_gear:dagger_embersteel`, `grug_gear:dagger_iron`, … (116 more) |
| `group:grug_jewellery_setting` | `grug_artisans:setting_copper_inlaid_steel`, `grug_artisans:setting_gold`, `grug_artisans:setting_gold_filigreed_abyssal_steel`, `grug_artisans:setting_gold_filigreed_embersteel`, `grug_artisans:setting_iron`, `grug_artisans:setting_tin` |
| `group:grug_leather_grade` | `grug_professions:cured_leather`, `grug_professions:nightscale_leather`, `grug_professions:sleek_leather` |
| `group:grug_metal_rod` | `grug_professions:metal_rod_abyssal_steel`, `grug_professions:metal_rod_bronze`, `grug_professions:metal_rod_embersteel`, `grug_professions:metal_rod_iron`, `grug_professions:metal_rod_silversteel`, `grug_professions:metal_rod_steel` |
| `group:grug_mount` | `grug_mounts:apprentice_mount`, `grug_mounts:expert_mount`, `grug_mounts:journeyman_mount`, `grug_mounts:master_mount` |
| `group:grug_ornament_components` | `grug_artisans:ornament_components_t3`, `grug_artisans:ornament_components_t4`, `grug_artisans:ornament_components_t5`, `grug_artisans:ornament_components_t6` |
| `group:grug_pick_tier` | `grug_materials:pick_abyssal_steel`, `grug_materials:pick_bronze`, `grug_materials:pick_embersteel`, `grug_materials:pick_iron`, `grug_materials:pick_silversteel`, `grug_materials:pick_steel`, `grug_materials:pick_stone`, `grug_materials:pick_wood` |
| `group:grug_potion_instant` | `grug_alchemy:potion_antivenom`, `grug_alchemy:potion_cave`, `grug_alchemy:potion_greater_healing`, `grug_alchemy:potion_greater_mana`, `grug_alchemy:potion_healing`, `grug_alchemy:potion_mana`, `grug_alchemy:potion_swiftness`, `grug_traders:potion_healing_weak` |
| `group:grug_potion_mixture` | `grug_alchemy:mixture_elixir_deepwater`, `grug_alchemy:mixture_elixir_focus_t3`, `grug_alchemy:mixture_elixir_focus_t4`, `grug_alchemy:mixture_elixir_focus_t5`, `grug_alchemy:mixture_elixir_focus_t6`, `grug_alchemy:mixture_elixir_precision_t3`, `grug_alchemy:mixture_elixir_precision_t4`, `grug_alchemy:mixture_elixir_precision_t5`, `grug_alchemy:mixture_elixir_precision_t6`, `grug_alchemy:mixture_elixir_stoneskin`, `grug_alchemy:mixture_elixir_vigor_t3`, `grug_alchemy:mixture_elixir_vigor_t4`, `grug_alchemy:mixture_elixir_vigor_t5`, `grug_alchemy:mixture_elixir_vigor_t6`, `grug_alchemy:mixture_potion_antivenom`, `grug_alchemy:mixture_potion_cave`, `grug_alchemy:mixture_potion_greater_healing`, `grug_alchemy:mixture_potion_greater_mana`, `grug_alchemy:mixture_potion_healing`, `grug_alchemy:mixture_potion_mana`, `grug_alchemy:mixture_potion_swiftness` |
| `group:grug_profession_supply` | `grug_professions:parchment`, `grug_professions:thread` |
| `group:grug_raw_dish` | `grug_cooking:raw_foragers_pot`, `grug_cooking:raw_grand_feast`, `grug_cooking:raw_kelp_roast`, `grug_cooking:raw_marsh_roast`, `grug_cooking:raw_pumpkin_pot`, `grug_cooking:raw_stew_pot` |
| `group:grug_salt` | `grug_cooking:salt_crust`, `grug_mapgen:salt_crust_source` |
| `group:grug_shield` | `grug_gear:shield_abyssal_steel`, `grug_gear:shield_bronze`, `grug_gear:shield_embersteel`, `grug_gear:shield_iron`, `grug_gear:shield_silversteel`, `grug_gear:shield_steel` |
| `group:grug_shovel_tier` | `grug_materials:shovel_abyssal_steel`, `grug_materials:shovel_bronze`, `grug_materials:shovel_embersteel`, `grug_materials:shovel_iron`, `grug_materials:shovel_silversteel`, `grug_materials:shovel_steel`, `grug_materials:shovel_stone`, `grug_materials:shovel_wood` |
| `group:grug_spellbook` | `grug_gear:spellbook_abyssal_steel`, `grug_gear:spellbook_bronze`, `grug_gear:spellbook_embersteel`, `grug_gear:spellbook_iron`, `grug_gear:spellbook_silversteel`, `grug_gear:spellbook_steel` |
| `group:grug_spice` | `grug_cooking:fire_pepper`, `grug_cooking:wild_onion`, `grug_gathering:marshbloom_source`, `grug_gathering:stormkelp_source`, `grug_gathering:sunleaf_source`, `grug_mapgen:fire_pepper_source`, `grug_mapgen:wild_onion_source` |
| `group:grug_sweetener` | `grug_cooking:sugar_cane`, `grug_mapgen:sugar_cane_source` |
| `group:grug_tailor_bundle` | `grug_professions:heavy_bolt_bundle`, `grug_professions:woven_bolt_bundle` |
| `group:grug_trash_loot` | `grug_mobs:stolen_purse`, `grug_mobs:war_trophy` |
| `group:grug_weapon_grip` | `grug_professions:weapon_grip_cured`, `grug_professions:weapon_grip_heavy`, `grug_professions:weapon_grip_light`, `grug_professions:weapon_grip_nightscale`, `grug_professions:weapon_grip_scaled`, `grug_professions:weapon_grip_sleek` |
| `group:hoe` | `grug_farming:hoe`, `grug_farming:hoe_abyssal_steel`, `grug_farming:hoe_bronze`, `grug_farming:hoe_embersteel`, `grug_farming:hoe_iron`, `grug_farming:hoe_silversteel`, `grug_farming:hoe_steel`, `grug_farming:hoe_stone` |
| `group:marram_grass` | `default:marram_grass_1`, `default:marram_grass_2`, `default:marram_grass_3` |
| `group:normal_grass` | `default:grass_1`, `default:grass_2`, `default:grass_3`, `default:grass_4`, `default:grass_5` |
| `group:pickaxe` | `grug_materials:pick_abyssal_steel`, `grug_materials:pick_bronze`, `grug_materials:pick_embersteel`, `grug_materials:pick_iron`, `grug_materials:pick_silversteel`, `grug_materials:pick_steel`, `grug_materials:pick_stone`, `grug_materials:pick_wood` |
| `group:plant` | `grug_farming:bamboo_shoot_1`, `grug_farming:bamboo_shoot_2`, `grug_farming:bamboo_shoot_3`, `grug_farming:bamboo_shoot_3_upper_1`, `grug_farming:bamboo_shoot_4`, `grug_farming:bamboo_shoot_4_upper_1`, `grug_farming:bamboo_shoot_4_upper_2`, `grug_farming:blightberry_1`, `grug_farming:blightberry_2`, `grug_farming:blightberry_3`, `grug_farming:blightberry_4`, `grug_farming:carrot_1`, `grug_farming:carrot_2`, `grug_farming:carrot_3`, `grug_farming:carrot_4`, `grug_farming:cassava_1`, `grug_farming:cassava_2`, `grug_farming:cassava_3`, `grug_farming:cassava_4`, `grug_farming:cave_cap_1`, `grug_farming:cave_cap_2`, `grug_farming:cave_cap_3`, `grug_farming:cave_cap_4`, `grug_farming:corn_1`, `grug_farming:corn_2`, `grug_farming:corn_3`, `grug_farming:corn_3_upper_1`, `grug_farming:corn_4`, `grug_farming:corn_4_upper_1`, `grug_farming:corn_4_upper_2`, `grug_farming:ember_moss_1`, `grug_farming:ember_moss_2`, `grug_farming:ember_moss_3`, `grug_farming:ember_moss_4`, `grug_farming:fire_pepper_1`, `grug_farming:fire_pepper_2`, `grug_farming:fire_pepper_3`, `grug_farming:fire_pepper_4`, `grug_farming:frost_melon_1`, `grug_farming:frost_melon_2`, … (40 more) |
| `group:shovel` | `grug_materials:shovel_abyssal_steel`, `grug_materials:shovel_bronze`, `grug_materials:shovel_embersteel`, `grug_materials:shovel_iron`, `grug_materials:shovel_silversteel`, `grug_materials:shovel_steel`, `grug_materials:shovel_stone`, `grug_materials:shovel_wood` |
| `group:soil` | `default:dirt`, `default:dirt_with_coniferous_litter`, `default:dirt_with_dry_grass`, `default:dirt_with_grass`, `default:dirt_with_grass_footsteps`, `default:dirt_with_rainforest_litter`, `default:dirt_with_snow`, `default:dry_dirt`, `default:dry_dirt_with_dry_grass`, `grug_farming:soil`, `grug_farming:soil_wet`, `grug_nodes:ash_ground`, `grug_nodes:blight_dirt`, `grug_nodes:dirt_with_bone_litter`, `grug_nodes:dirt_with_canopy_litter`, `grug_nodes:dirt_with_forest_litter`, `grug_nodes:dirt_with_moss`, `grug_nodes:dirt_with_silver_litter`, `grug_nodes:mud` |
| `group:staff` | `grug_gear:staff_abyssal_steel`, `grug_gear:staff_bronze`, `grug_gear:staff_embersteel`, `grug_gear:staff_iron`, `grug_gear:staff_silversteel`, `grug_gear:staff_steel` |
| `group:sword` | `grug_gear:dagger_abyssal_steel`, `grug_gear:dagger_bronze`, `grug_gear:dagger_embersteel`, `grug_gear:dagger_iron`, `grug_gear:dagger_silversteel`, `grug_gear:dagger_steel`, `grug_gear:sword_abyssal_steel`, `grug_gear:sword_bronze`, `grug_gear:sword_embersteel`, `grug_gear:sword_iron`, `grug_gear:sword_silversteel`, `grug_gear:sword_steel` |
| `group:wand` | `grug_gear:wand_abyssal_steel`, `grug_gear:wand_bronze`, `grug_gear:wand_embersteel`, `grug_gear:wand_iron`, `grug_gear:wand_silversteel`, `grug_gear:wand_steel` |

## Mob entities

Every registered mob entity (existing roles are the name without `grug_mobs:`).
Disposition from `grug_mobs/disposition.lua`; drops are today's static rows.

| Entity | Name | Type | Disposition | Drops (1 in N) |
|---|---|---|---|---|
| `grug_mobs:ashen_treant` | Ashen Treant | monster | aggressive | default:stick 1, default:apple 4 |
| `grug_mobs:bandit` | Bandit | monster | aggressive |  |
| `grug_mobs:bandit_archer` | Bandit Archer | monster | aggressive |  |
| `grug_mobs:bear` | Bear | monster | aggressive | mobs:meat_raw 1, grug_mobs:heavy_leather 2, grug_mobs:bear_claw 4 |
| `grug_mobs:blightfang_wolf` | Blightfang Wolf | monster | aggressive | mobs:meat_raw 1, mobs:leather 2, grug_mobs:fang 3 |
| `grug_mobs:blood_bat` | Blood Bat | monster | aggressive | mobs:meat_raw 1 |
| `grug_mobs:boar` | Boar | monster | neutral | mobs:meat_raw 1, grug_mobs:light_leather 2, grug_mobs:boar_tusk 3 |
| `grug_mobs:bog_fowl` | Bog Fowl | animal | critter | mobs:meat_raw 1 |
| `grug_mobs:bog_ooze` | Bog Ooze | monster | aggressive | grug_mobs:slime_gel 1, grug_mobs:linen_scrap 3 |
| `grug_mobs:bog_witch` | Bog Witch | monster | aggressive | grug_mobs:venom_sac 3, grug_mobs:linen_scrap 2 |
| `grug_mobs:bone_weevil` | Bone Weevil | animal | critter | mobs:meat_raw 1 |
| `grug_mobs:carrion_crow` | Carrion Crow | animal | neutral | grug_mobs:feather 1 |
| `grug_mobs:cave_bat` | Cave Bat | animal | critter | mobs:meat_raw 1 |
| `grug_mobs:cave_crawler` | Cave Crawler | animal | critter | mobs:meat_raw 1 |
| `grug_mobs:crag_eagle` | Crag Eagle | monster | aggressive | grug_mobs:sharp_feather 1, grug_mobs:feather 2, mobs:meat_raw 2 |
| `grug_mobs:crocodile` | Crocodile | monster | aggressive | grug_mobs:scaled_hide 1, mobs:meat_raw 1, grug_mobs:croc_tooth 3 |
| `grug_mobs:crystal_shard` | Crystal Shard | monster | aggressive | grug_materials:emberglass_shard 1, grug_materials:emberglass 6 |
| `grug_mobs:dungeon_master` | Dungeon Master | monster | aggressive | grug_materials:emberglass_shard 2, grug_materials:rough_diamond 8 |
| `grug_mobs:elder_dwarf` | Vale Elder | npc |  |  |
| `grug_mobs:elder_elf` | Lore Keeper | npc |  |  |
| `grug_mobs:elder_human` | Village Elder | npc |  |  |
| `grug_mobs:elder_orc` | Camp Elder | npc |  |  |
| `grug_mobs:elder_troll` | Cradle Elder | npc |  |  |
| `grug_mobs:elder_undead` | Hollow Warden | npc |  |  |
| `grug_mobs:ember_wisp` | Ember Wisp | monster | aggressive | grug_materials:emberglass 4 |
| `grug_mobs:fox` | Fox | monster | aggressive | mobs:meat_raw 1, mobs:leather 2, grug_mobs:fang 3 |
| `grug_mobs:frost_stray` | Frost Stray | monster | aggressive | grug_mobs:bone 1, grug_mobs:linen_scrap 2, grug_mobs:arrow 3 |
| `grug_mobs:gaunt_stag` | Gaunt Stag | animal | neutral | mobs:meat_raw 1, mobs:leather 2 |
| `grug_mobs:giant_rat` | Giant Rat | monster | aggressive | mobs:meat_raw 1 |
| `grug_mobs:giant_spider` | Giant Spider | monster | aggressive | grug_mobs:spider_silk 1, grug_mobs:venom_gland 6 |
| `grug_mobs:glowwing` | Glowwing | monster | aggressive | grug_mobs:venom_gland 5 |
| `grug_mobs:goblin_hound` | Goblin Raider Hound | monster | aggressive | mobs:meat_raw 1 |
| `grug_mobs:goblin_miner` | Goblin Miner | monster | aggressive | grug_mobs:linen_scrap 2, grug_mobs:stolen_purse 8 |
| `grug_mobs:goblin_miner_slinger` | Goblin Miner Slinger | monster | aggressive | grug_mobs:linen_scrap 2, grug_mobs:arrow 3 |
| `grug_mobs:goblin_raider` | Goblin Raider | monster | aggressive | grug_mobs:linen_scrap 2, grug_mobs:stolen_purse 8 |
| `grug_mobs:goblin_slinger` | Goblin Slinger | monster | aggressive | grug_mobs:linen_scrap 2, grug_mobs:arrow 3 |
| `grug_mobs:gravewood_treant` | Gravewood Treant | monster | aggressive | default:stick 1, default:apple 4 |
| `grug_mobs:guard_accord` | Accord Guard | npc |  | grug_mobs:war_trophy 1, grug_mobs:heavy_cloth 3 |
| `grug_mobs:guard_throng` | Throng Guard | npc |  | grug_mobs:war_trophy 1, grug_mobs:heavy_cloth 3 |
| `grug_mobs:gull` | Gull | animal | critter | mobs:meat_raw 1 |
| `grug_mobs:hare` | Hare | animal | critter | mobs:meat_raw 1 |
| `grug_mobs:hyena` | Hyena | monster | aggressive | mobs:meat_raw 1, mobs:leather 2, grug_mobs:fang 3 |
| `grug_mobs:ibex` | Ibex | animal | neutral | mobs:meat_raw 1, mobs:leather 2 |
| `grug_mobs:ice_dragon` | Wyrmglass Ice Dragon | monster | aggressive |  |
| `grug_mobs:ice_whelp` | Wyrmglass Ice Dragon Whelp | monster | aggressive |  |
| `grug_mobs:jungle_ape` | Jungle Ape | monster | aggressive | mobs:meat_raw 1, grug_mobs:heavy_leather 2, grug_mobs:ape_hair 4 |
| `grug_mobs:jungle_boar` | Jungle Boar | monster | neutral | mobs:meat_raw 1, grug_mobs:light_leather 2, grug_mobs:boar_tusk 3 |
| `grug_mobs:jungle_lynx` | Jungle Lynx | monster | aggressive | mobs:meat_raw 1, mobs:leather 2, grug_mobs:raptor_claw 3 |
| `grug_mobs:jungle_spider` | Jungle Spider | monster | aggressive | grug_mobs:spider_silk 1, grug_mobs:venom_gland 6 |
| `grug_mobs:jungle_wyvern` | Stormscale Jungle Wyvern | monster | aggressive |  |
| `grug_mobs:king_dwarf` | King of Dur Brannoc | npc | aggressive |  |
| `grug_mobs:king_elf` | King of Lethariel | npc | aggressive |  |
| `grug_mobs:king_human` | King of Highcourt | npc | aggressive |  |
| `grug_mobs:king_orc` | King of Gor Drazhak | npc | aggressive |  |
| `grug_mobs:king_troll` | King of Kezamba | npc | aggressive |  |
| `grug_mobs:king_undead` | King of Nhal Veyr | npc | aggressive |  |
| `grug_mobs:kraken` | Kraken Guard | monster | aggressive |  |
| `grug_mobs:land_guard` | Land Guard | monster |  | grug_mobs:heavy_leather 2, grug_materials:rough_diamond 4 |
| `grug_mobs:lava_flan` | Lava Flan | monster | aggressive | grug_materials:emberglass 5, grug_mobs:slime_gel 2 |
| `grug_mobs:mesa_golem` | Mesa Golem | monster | aggressive | grug_mobs:stone_core 1, default:iron_lump 2, grug_materials:rough_diamond 8 |
| `grug_mobs:mirefolk` | Mirefolk | monster | aggressive | grug_mobs:linen_cloth 2, grug_mobs:raw_fish 1, grug_mobs:shiny_scale 4 |
| `grug_mobs:mountain_ram` | Mountain Ram | animal | neutral | mobs:meat_raw 1, grug_mobs:heavy_leather 4 |
| `grug_mobs:oerkki` | Oerkki | monster | aggressive | grug_materials:quartz 2, grug_materials:silver_lump 5 |
| `grug_mobs:pale_spider` | Bonelurker Spider | monster | aggressive | grug_mobs:spider_silk 1, grug_mobs:venom_gland 6 |
| `grug_mobs:panther` | Panther | monster | aggressive | mobs:meat_raw 1, mobs:leather 2, grug_mobs:sleek_pelt 4 |
| `grug_mobs:parrot` | Parrot | animal | critter | mobs:meat_raw 1 |
| `grug_mobs:plague_boar` | Plague Boar | monster | neutral | mobs:meat_raw 1, grug_mobs:light_leather 2, grug_mobs:boar_tusk 3 |
| `grug_mobs:plaguehide_bear` | Plaguehide Bear | monster | aggressive | mobs:meat_raw 1, grug_mobs:heavy_leather 2, grug_mobs:bear_claw 4 |
| `grug_mobs:plains_runner` | Plains Runner | animal | neutral | mobs:meat_raw 1 |
| `grug_mobs:poacher` | Poacher | monster | aggressive |  |
| `grug_mobs:rabbit` | Rabbit | animal | critter | mobs:meat_raw 1 |
| `grug_mobs:reed_angelfish` | Reed Angelfish | animal | critter | grug_mobs:raw_fish 1 |
| `grug_mobs:reef_lurker` | Reef Lurker | animal | neutral | mobs:meat_raw 1, grug_mobs:scaled_hide 2 |
| `grug_mobs:rift_spawn` | Rift Spawn | monster | aggressive | grug_mobs:slime_gel 2 |
| `grug_mobs:royal_guard_dwarf` | King of Dur Brannoc Royal Guard | npc |  | grug_mobs:war_trophy 1, grug_mobs:heavy_cloth 3 |
| `grug_mobs:royal_guard_elf` | King of Lethariel Royal Guard | npc |  | grug_mobs:war_trophy 1, grug_mobs:heavy_cloth 3 |
| `grug_mobs:royal_guard_human` | King of Highcourt Royal Guard | npc |  | grug_mobs:war_trophy 1, grug_mobs:heavy_cloth 3 |
| `grug_mobs:royal_guard_orc` | King of Gor Drazhak Royal Guard | npc |  | grug_mobs:war_trophy 1, grug_mobs:heavy_cloth 3 |
| `grug_mobs:royal_guard_troll` | King of Kezamba Royal Guard | npc |  | grug_mobs:war_trophy 1, grug_mobs:heavy_cloth 3 |
| `grug_mobs:royal_guard_undead` | King of Nhal Veyr Royal Guard | npc |  | grug_mobs:war_trophy 1, grug_mobs:heavy_cloth 3 |
| `grug_mobs:scorpion` | Scorpion | monster | aggressive | grug_mobs:scaled_hide 2, grug_mobs:venom_sac 3 |
| `grug_mobs:serpent` | Serpent | monster | aggressive | grug_mobs:scaled_hide 2, grug_mobs:venom_sac 3 |
| `grug_mobs:shore_crab` | Shore Crab | animal | neutral | mobs:meat_raw 1, grug_mobs:scaled_hide 2 |
| `grug_mobs:skeleton_archer` | Skeleton Archer | monster | aggressive | grug_mobs:bone 1, grug_mobs:linen_scrap 2, grug_mobs:arrow 3 |
| `grug_mobs:skeleton_raider` | Skeleton Raider | monster | aggressive | grug_mobs:bone 1, grug_mobs:linen_scrap 2, grug_mobs:arrow 3, grug_mobs:heavy_cloth 3 |
| `grug_mobs:snow_leopard` | Snow Leopard | monster | aggressive | mobs:meat_raw 1, mobs:leather 2, grug_mobs:sleek_pelt 4 |
| `grug_mobs:song_bird` | Song Bird | animal | critter | mobs:meat_raw 1 |
| `grug_mobs:speargrass_tiger` | Speargrass Tiger | monster | aggressive | mobs:meat_raw 1, grug_mobs:heavy_leather 2, grug_mobs:sleek_pelt 4 |
| `grug_mobs:spiderling` | Spiderling | monster | aggressive | grug_mobs:spider_silk 2 |
| `grug_mobs:stag` | Stag | animal | neutral | mobs:meat_raw 1, mobs:leather 2 |
| `grug_mobs:stone_golem` | Stone Golem | monster | aggressive | grug_mobs:stone_core 1, default:iron_lump 2, grug_materials:rough_diamond 8 |
| `grug_mobs:stone_mite` | Stone Mite | monster | aggressive | grug_mobs:stone_core 8 |
| `grug_mobs:storm_whelp` | Stormscale Jungle Wyvern Whelp | monster | aggressive |  |
| `grug_mobs:sun_dried_husk` | Sun-Dried Husk | monster | aggressive | grug_mobs:zombie_flesh 1, grug_mobs:linen_scrap 2, grug_materials:iron_bar 10 |
| `grug_mobs:tapir` | Tapir | animal | neutral | mobs:meat_raw 1, mobs:leather 2 |
| `grug_mobs:villager_dwarf` | Vale Dwarf | npc |  |  |
| `grug_mobs:villager_elf` | Glade Elf | npc |  |  |
| `grug_mobs:villager_human` | Dawnmere Farmer | npc |  |  |
| `grug_mobs:villager_orc` | Camp Orc | npc |  |  |
| `grug_mobs:villager_troll` | Cradle Troll | npc |  |  |
| `grug_mobs:villager_undead` | Hollow Dweller | npc |  |  |
| `grug_mobs:viper` | Viper | monster | aggressive | grug_mobs:scaled_hide 2, grug_mobs:venom_sac 3 |
| `grug_mobs:vulture` | Vulture | monster | aggressive | grug_mobs:sharp_feather 1, grug_mobs:feather 2, mobs:meat_raw 2 |
| `grug_mobs:war_construct` | War Construct | monster | aggressive | grug_mobs:stone_core 1, grug_materials:iron_bar 1 |
| `grug_mobs:wild_turkey` | Wild Turkey | animal | critter | mobs:meat_raw 1 |
| `grug_mobs:wisp` | Wisp | monster | aggressive |  |
| `grug_mobs:wolf` | Wolf | monster | aggressive | mobs:meat_raw 1, mobs:leather 2, grug_mobs:fang 3 |
| `grug_mobs:zebra` | Zebra | animal | neutral | mobs:meat_raw 1, mobs:leather 2 |
| `grug_mobs:zombie` | Zombie | monster | aggressive | grug_mobs:zombie_flesh 1, grug_mobs:linen_scrap 2, grug_materials:iron_bar 10 |
| `grug_traders:vendor_armourer` | Armourer | npc |  |  |
| `grug_traders:vendor_baker` | Baker | npc |  |  |
| `grug_traders:vendor_bowyer` | Bowyer | npc |  |  |
| `grug_traders:vendor_brewer` | Brewer | npc |  |  |
| `grug_traders:vendor_butcher` | Butcher | npc |  |  |
| `grug_traders:vendor_embalmer` | Embalmer | npc |  |  |
| `grug_traders:vendor_fishmonger` | Fishmonger | npc |  |  |
| `grug_traders:vendor_general_accord` | Accord Quartermaster | npc |  |  |
| `grug_traders:vendor_general_throng` | Throng Quartermaster | npc |  |  |
| `grug_traders:vendor_herbalist` | Herbalist | npc |  |  |
| `grug_traders:vendor_mason` | Mason | npc |  |  |
| `grug_traders:vendor_race_dwarf` | Dwarven Quartermaster | npc |  |  |
| `grug_traders:vendor_race_elf` | Elven Quartermaster | npc |  |  |
| `grug_traders:vendor_race_human` | Human Quartermaster | npc |  |  |
| `grug_traders:vendor_race_orc` | Orcish Quartermaster | npc |  |  |
| `grug_traders:vendor_race_troll` | Troll Quartermaster | npc |  |  |
| `grug_traders:vendor_race_undead` | Undead Quartermaster | npc |  |  |
| `grug_traders:vendor_smith` | Blacksmith | npc |  |  |
| `grug_traders:vendor_tailor` | Tailor | npc |  |  |
| `grug_traders:vendor_tanner` | Tanner | npc |  |  |
| `mobs:_pos` |  |  |  |  |

## Quest NPCs

Registered quest NPC ids today (settlement / socket). The zone atlas says
which zone and hub each belongs to.

| NPC id | Name | Settlement | Socket |
|---|---|---|---|
| `r14_dwarf_captive` | Tovin Ashthumb | copperfell_bandit_camp | quest_captive |
| `r14_dwarf_elder` | Brunna Flintbraid | hearthpine | hall_quest |
| `r14_dwarf_scout` | Mara Deepwatch | copperfell_outpost | quest_scout |
| `r14_dwarf_steward` | Orrik Pineledger | copperfell_village | quest_steward |
| `r14_elf_captive` | Nima Fern | starbough_bandit_camp | quest_captive |
| `r14_elf_elder` | Saelin Dewbough | silverleaf | hall_quest |
| `r14_elf_scout` | Theren Farstep | starbough_outpost | quest_scout |
| `r14_elf_steward` | Ilyra Mossveil | starbough_village | quest_steward |
| `r14_human_captive` | Pella Thatch | goldmead_bandit_camp | quest_captive |
| `r14_human_elder` | Elian Reed | dawnmere | hall_quest |
| `r14_human_scout` | Jon Vale | goldmead_outpost | quest_scout |
| `r14_human_steward` | Marta Millward | goldmead_village | quest_steward |
| `r14_orc_captive` | Rokka Emberhand | redtusk_bandit_camp | quest_captive |
| `r14_orc_elder` | Gara Stonevoice | sunscar | hall_quest |
| `r14_orc_scout` | Kesh Longstride | redtusk_outpost | quest_scout |
| `r14_orc_steward` | Borak Redgrass | redtusk_village | quest_steward |
| `r14_troll_captive` | Veko Bluefeather | raincall_bandit_camp | quest_captive |
| `r14_troll_elder` | Zalima Rainhum | kapok | hall_quest |
| `r14_troll_scout` | Neshi Reedstep | raincall_outpost | quest_scout |
| `r14_troll_steward` | Daro Kapok | raincall_village | quest_steward |
| `r14_undead_captive` | Hollis Grey | mournfen_bandit_camp | quest_captive |
| `r14_undead_elder` | Veyra Pall | stillgrave | hall_quest |
| `r14_undead_scout` | Sera Vane | mournfen_outpost | quest_scout |
| `r14_undead_steward` | Mordec Silt | mournfen_village | quest_steward |
| `r15_dwarf_local` | Dagna Copperset | copperfell_village | quest_local |
| `r15_elf_local` | Lethri Reedshade | starbough_village | quest_local |
| `r15_human_local` | Alda Sheaf | goldmead_village | quest_local |
| `r15_orc_local` | Morga Clayhand | redtusk_village | quest_local |
| `r15_troll_local` | Amari Palmweave | raincall_village | quest_local |
| `r15_undead_local` | Edris Wax | mournfen_village | quest_local |
| `r20_anchor_014_host` | Edda Tarnmantle | r20_anchor_014 | quest_host |
| `r20_anchor_016_host` | Merren Oakstamp | r20_anchor_016 | quest_host |
| `r20_anchor_018_host` | Ilwen Petalmeasure | r20_anchor_018 | quest_host |
| `r20_anchor_020_host` | Sovel Namekeeper | r20_anchor_020 | quest_host |
| `r20_anchor_022_host` | Brakka Jarward | r20_anchor_022 | quest_host |
| `r20_anchor_024_host` | Taleko Drycord | r20_anchor_024 | quest_host |
| `r20_anchor_026_host` | Hedra Rimebell | r20_anchor_026 | quest_host |
| `r20_anchor_027_host` | Borin Splitbolt | r20_anchor_027 | quest_host |
| `r20_anchor_028_host` | Alna Archsight | r20_anchor_028 | quest_host |
| `r20_anchor_030_host` | Jessa Axlewright | r20_anchor_030 | quest_host |
| `r20_anchor_031_host` | Toren Waterbarrel | r20_anchor_031 | quest_host |
| `r20_anchor_032_host` | Nella Hedgeward | r20_anchor_032 | quest_host |
| `r20_anchor_034_host` | Orya Petalward | r20_anchor_034 | quest_host |
| `r20_anchor_035_host` | Lethen Moonledger | r20_anchor_035 | quest_host |
| `r20_anchor_036_host` | Faeris Rootbinder | r20_anchor_036 | quest_host |
| `r20_anchor_038_host` | Mereth Rubbinghand | r20_anchor_038 | quest_host |
| `r20_anchor_039_host` | Vaska Ashlistener | r20_anchor_039 | quest_host |
| `r20_anchor_040_host` | Orrel Hollowstep | r20_anchor_040 | quest_host |
| `r20_anchor_042_host` | Morga Cutgrass | r20_anchor_042 | quest_host |
| `r20_anchor_043_host` | Drek Rampbinder | r20_anchor_043 | quest_host |
| `r20_anchor_044_host` | Yarra Standardmender | r20_anchor_044 | quest_host |
| `r20_anchor_046_host` | Enashi Reedvoice | r20_anchor_046 | quest_host |
| `r20_anchor_047_host` | Tokai Knotreader | r20_anchor_047 | quest_host |
| `r20_anchor_048_host` | Rumela Stormstep | r20_anchor_048 | quest_host |
| `r20_anchor_061_host` | Kelda Screesort | r20_anchor_061 | quest_host |
| `r20_anchor_062_host` | Halen Chalkthumb | r20_anchor_062 | quest_host |
| `r20_anchor_063_host` | Saevin Rootscribe | r20_anchor_063 | quest_host |
| `r20_anchor_064_host` | Neris Fossilhand | r20_anchor_064 | quest_host |
| `r20_anchor_065_host` | Gorren Redpick | r20_anchor_065 | quest_host |
| `r20_anchor_066_host` | Zali Runoff | r20_anchor_066 | quest_host |
| `r20_dwarf_capital_cook` | Varda Copperpan | dur_brannoc | terrace_bakehouse/terrace_bakehouse_quest_cook |
| `r20_dwarf_capital_envoy` | Dorrin Gateledger | dur_brannoc | ancestor_hall_quest |
| `r20_dwarf_start_cook` | Hilda Hearthspoon | hearthpine | quest_cook |
| `r20_elf_capital_cook` | Mirael Petalpot | lethariel | market_bakehouse/market_bakehouse_quest_cook |
| `r20_elf_capital_envoy` | Eriath Boughwarden | lethariel | star_hall_quest |
| `r20_elf_start_cook` | Liora Dewpot | silverleaf | quest_cook |
| `r20_human_capital_cook` | Ansel Ovenward | highcourt | homes_bakehouse/homes_bakehouse_quest_cook |
| `r20_human_capital_envoy` | Mariel Waybook | highcourt | chapel_quest |
| `r20_human_start_cook` | Bess Honeycrust | dawnmere | quest_cook |
| `r20_orc_capital_cook` | Gorla Longladle | gor_drazhak | warren_cook_court/warren_cook_court_quest_cook |
| `r20_orc_capital_envoy` | Thorga Roadspeaker | gor_drazhak | skull_hall_quest |
| `r20_orc_start_cook` | Ugra Brothstone | sunscar | quest_cook |
| `r20_troll_capital_cook` | Teshani Smokereed | kezamba | shore_smokehouse/shore_smokehouse_quest_cook |
| `r20_troll_capital_envoy` | Nalo Pathdrum | kezamba | shrine_quest |
| `r20_troll_start_cook` | Zemi Sweetroot | kapok | quest_cook |
| `r20_undead_capital_cook` | Velis Mourningbowl | nhal_veyr | homes_mourners_hall/homes_mourners_hall_quest_cook |
| `r20_undead_capital_envoy` | Ossa Quietregister | nhal_veyr | vigil_hall_quest |
| `r20_undead_start_cook` | Neral Saltkeeper | stillgrave | quest_cook |

## Curated out

Never reference these (`mods/ITEMS/grug_materials/content_curation.lua`).

| Item | Why |
|---|---|
| `default:pick_mese` | content_curation: unregistered (retired tier/duplicate) |
| `default:shovel_mese` | content_curation: unregistered (retired tier/duplicate) |
| `default:axe_mese` | content_curation: unregistered (retired tier/duplicate) |
| `default:sword_mese` | content_curation: unregistered (retired tier/duplicate) |
| `default:pick_diamond` | content_curation: unregistered (retired tier/duplicate) |
| `default:shovel_diamond` | content_curation: unregistered (retired tier/duplicate) |
| `default:axe_diamond` | content_curation: unregistered (retired tier/duplicate) |
| `default:sword_diamond` | content_curation: unregistered (retired tier/duplicate) |
| `default:sword_bronze` | content_curation: unregistered (retired tier/duplicate) |
| `default:sword_steel` | content_curation: unregistered (retired tier/duplicate) |
| `default:sword_wood` | content_curation: unregistered (retired tier/duplicate) |
| `default:sword_stone` | content_curation: unregistered (retired tier/duplicate) |
| `default:copper_ingot` | content_curation: unregistered (retired tier/duplicate) |
| `default:copperblock` | content_curation: unregistered (retired tier/duplicate) |
| `default:tin_ingot` | content_curation: unregistered (retired tier/duplicate) |
| `default:tinblock` | content_curation: unregistered (retired tier/duplicate) |
| `default:bronze_ingot` | content_curation: unregistered (retired tier/duplicate) |
| `default:bronzeblock` | content_curation: unregistered (retired tier/duplicate) |
| `default:steel_ingot` | content_curation: unregistered (retired tier/duplicate) |
| `default:steelblock` | content_curation: unregistered (retired tier/duplicate) |
| `default:gold_ingot` | content_curation: unregistered (retired tier/duplicate) |
| `default:goldblock` | content_curation: unregistered (retired tier/duplicate) |
| `default:stone_with_mese` | content_curation: unregistered (retired tier/duplicate) |
| `default:mese` | content_curation: unregistered (retired tier/duplicate) |
| `default:mese_crystal` | content_curation: unregistered (retired tier/duplicate) |
| `default:mese_crystal_fragment` | content_curation: unregistered (retired tier/duplicate) |
| `default:meselamp` | content_curation: unregistered (retired tier/duplicate) |
| `default:mese_post_light` | content_curation: unregistered (retired tier/duplicate) |
| `default:mese_post_light_acacia_wood` | content_curation: unregistered (retired tier/duplicate) |
| `default:mese_post_light_junglewood` | content_curation: unregistered (retired tier/duplicate) |
| `default:mese_post_light_pine_wood` | content_curation: unregistered (retired tier/duplicate) |
| `default:mese_post_light_aspen_wood` | content_curation: unregistered (retired tier/duplicate) |
| `default:stone_with_diamond` | content_curation: unregistered (retired tier/duplicate) |
| `default:diamond` | content_curation: unregistered (retired tier/duplicate) |
| `default:diamondblock` | content_curation: unregistered (retired tier/duplicate) |
| `default:sign_wall_steel` | content_curation: unregistered (retired tier/duplicate) |
| `default:ladder_steel` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_steelblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_inner_steelblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_outer_steelblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:slab_steelblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_tinblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_inner_tinblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_outer_tinblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:slab_tinblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_copperblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_inner_copperblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_outer_copperblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:slab_copperblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_bronzeblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_inner_bronzeblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_outer_bronzeblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:slab_bronzeblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_goldblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_inner_goldblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:stair_outer_goldblock` | content_curation: unregistered (retired tier/duplicate) |
| `stairs:slab_goldblock` | content_curation: unregistered (retired tier/duplicate) |
| `mobs:nametag` | content_curation: mobs_redo utility not registered |
| `mobs:net` | content_curation: mobs_redo utility not registered |
| `mobs:lasso` | content_curation: mobs_redo utility not registered |
| `mobs:shears` | content_curation: mobs_redo utility not registered |
| `mobs:protector` | content_curation: mobs_redo utility not registered |
| `mobs:protector2` | content_curation: mobs_redo utility not registered |
| `mobs:mob_repellent` | content_curation: mobs_redo utility not registered |
| `mobs:saddle` | content_curation: mobs_redo utility not registered |
| `default:silver_sand` | content_curation: registered for authored builds, no recipe and no world source |
| `default:silver_sandstone` | content_curation: registered for authored builds, no recipe and no world source |
| `default:silver_sandstone_brick` | content_curation: registered for authored builds, no recipe and no world source |
| `default:silver_sandstone_block` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:slab_silver_sandstone` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:stair_silver_sandstone` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:stair_inner_silver_sandstone` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:stair_outer_silver_sandstone` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:slab_silver_sandstone_brick` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:stair_silver_sandstone_brick` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:stair_inner_silver_sandstone_brick` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:stair_outer_silver_sandstone_brick` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:slab_silver_sandstone_block` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:stair_silver_sandstone_block` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:stair_inner_silver_sandstone_block` | content_curation: registered for authored builds, no recipe and no world source |
| `stairs:stair_outer_silver_sandstone_block` | content_curation: registered for authored builds, no recipe and no world source |

## Aliases

Alias names resolve to another item; always write the target id.

- `CraftItem` → ``
- `MBOItem` → ``
- `MaterialItem` → ``
- `MaterialItem2` → ``
- `MaterialItem3` → ``
- `NodeItem` → ``
- `ToolItem` → ``
- `craft` → ``
- `default:axe_bronze` → `grug_materials:axe_bronze`
- `default:axe_steel` → `grug_materials:axe_steel`
- `default:axe_stone` → `grug_materials:axe_stone`
- `default:axe_wood` → `grug_materials:axe_wood`
- `default:pick_bronze` → `grug_materials:pick_bronze`
- `default:pick_steel` → `grug_materials:pick_steel`
- `default:pick_stone` → `grug_materials:pick_stone`
- `default:pick_wood` → `grug_materials:pick_wood`
- `default:shovel_bronze` → `grug_materials:shovel_bronze`
- `default:shovel_steel` → `grug_materials:shovel_steel`
- `default:shovel_stone` → `grug_materials:shovel_stone`
- `default:shovel_wood` → `grug_materials:shovel_wood`
- `mapgen_apple` → `default:apple`
- `mapgen_cobble` → `default:cobble`
- `mapgen_desert_sand` → `default:desert_sand`
- `mapgen_desert_stone` → `default:desert_stone`
- `mapgen_dirt` → `default:dirt`
- `mapgen_dirt_with_grass` → `default:dirt_with_grass`
- `mapgen_dirt_with_snow` → `default:dirt_with_snow`
- `mapgen_gravel` → `default:gravel`
- `mapgen_ice` → `default:ice`
- `mapgen_junglegrass` → `default:junglegrass`
- `mapgen_jungleleaves` → `default:jungleleaves`
- `mapgen_jungletree` → `default:jungletree`
- `mapgen_lava_source` → `default:lava_source`
- `mapgen_leaves` → `default:leaves`
- `mapgen_mossycobble` → `default:mossycobble`
- `mapgen_pine_needles` → `default:pine_needles`
- `mapgen_pine_tree` → `default:pine_tree`
- `mapgen_river_water_source` → `default:river_water_source`
- `mapgen_sand` → `default:sand`
- `mapgen_snow` → `default:snow`
- `mapgen_snowblock` → `default:snowblock`
- `mapgen_stair_cobble` → `stairs:stair_cobble`
- `mapgen_stair_desert_stone` → `stairs:stair_desert_stone`
- `mapgen_stone` → `default:stone`
- `mapgen_tree` → `default:tree`
- `mapgen_water_source` → `default:water_source`
- `node` → ``
- `tool` → ``

