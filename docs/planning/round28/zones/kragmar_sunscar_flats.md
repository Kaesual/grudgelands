# Sunscar Flats (`kragmar_sunscar_flats`)

Zone 22 · start zone · throng · race region **orc** · levels **1-10** · peaceful · relief `lowland` · seed 42

Map: [maps/kragmar_sunscar_flats.png](maps/kragmar_sunscar_flats.png). Machine-readable: [kragmar_sunscar_flats.json](kragmar_sunscar_flats.json). Coordinates are world nodes (x east, z north, y up).

Race track (orc): step 1 of the track Sunscar Flats → Redtusk Savanna → Gor Drazhak → Speargrass Reach → Bannerbreak Mesa.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -776..556, z 2240..3036 (centroid -136, 2600) |
| Land area | 687616 nodes² (≈ 0.69 km²) |
| Hub point (authored) | 0, 2550 |
| Height above sea | min 0, p10 4, median 39, p90 55, max 70 |
| Slope | 3.4% steep (>1 node/node), 0.5% cliff (>2) |
| Biomes (measured) | savanna 87.8%, badlands 12.2% |
| Neighbours (land border) | kragmar_redtusk_savanna (1724 nodes, mid -127,2300), kragmar_speargrass_reach (84 nodes, mid -771,2456) |
| Sea coast | 4576 nodes of coastline; sea-beach sand 58208 nodes²; lake/river-bank sand 1360 nodes² |
| Water inside | bay 414912 nodes², rivers/lakes 944 nodes² |
| Protected / drift band | 3.9% of land protected (towns, villages, camps/POIs, road corridors); 3.5% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 222, 2819 | x -108..432, z 2628..3036 | 31264 | L3 |
| B2 | 389, 2451 | x 336..440, z 2348..2572 | 5648 | L3-8 |
| B3 | 497, 2358 | x 452..556, z 2324..2400 | 4752 | L8-10 |
| B4 | -611, 2684 | x -660..-564, z 2624..2752 | 4704 | L3-4 |
| B5 | -421, 2959 | x -484..-356, z 2912..3016 | 3296 | L3 |
| B6 | -662, 2567 | x -720..-576, z 2492..2616 | 3072 | L4-8 |
| B7 | 490, 2451 | x 456..520, z 2412..2492 | 2368 | L5-7 |
| B8 | -596, 2895 | x -640..-556, z 2860..2912 | 1136 | L3 |
| B9 | -322, 2959 | x -344..-292, z 2936..2996 | 1136 | L3 |

## Levels

Start-zone gradient (zones.lua): L1 within 100 nodes of the start anchor, L2 to 150; beyond, band 1 top (L3) behind and beside the town, rising through band 2 (L4-6) and band 3 (L7-10) toward the front border (-z), reaching L10 at the border.

Share of land per level: L1 4.5%, L2 5.7%, L3 56.5%, L4 6.8%, L5 5.9%, L6 5.4%, L7 3.7%, L8 3.9%, L9 3.9%, L10 3.7%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_005 | start town | Sunscar | 0 | 37 | 2550 | 1 | - |

## Protected areas

- Start town: pad x -64..63, z 2486..2613 plus a 12-node band (outer box x -76..75, z 2474..2625); hard protected, hostile spawns refused.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Sunscar (`sunscar`, anchor_005) at 0, 37, 2550

Residents/guards: guard_patrol 5, guard_post 2, idle 6, innkeeper 1, public_station 1, quest 2, trainer 1, vendor 1, work 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| yard_vendor | vendor | vendor kind: race | 8, 38, 2545 | - |
| idle_tusk_door | innkeeper (respawn bind) |  | -11, 38, 2528 | - |
| hall_quest | quest giver | Gara Stonevoice | 3, 38, 2562 | r14_orc_01_tusks_at_the_water_skins, r14_orc_03_rats_under_the_hide_racks, r14_orc_04_the_thirsting_dead, r14_orc_05_shells_by_the_bedrolls, r14_orc_06_husks_on_redtusk_road, r14_orc_10_edge_of_the_first_camp, r14_orc_11_stone_has_no_pride, r20_orc_capital_intro |
| trainer_cooking | profession trainer | trains: cooking | 2, 38, 2540 | - |
| quest_cook | quest giver | Ugra Brothstone | 2, 38, 2537 | r14_orc_02_meat_for_the_long_fire, r20_orc_start_cook |

Public stations: cook_oven (furnace).

Distances: zone edge N 440 (coastal_shelf), S 308 (kragmar_redtusk_savanna), E 372 (coastal_shelf), W 708 (bay_water); nearest other-zone land 302 S; sea 320 E; sea-beach sand 289 E; nearest road 64.
Nearest hubs (straight / by road): Redtusk Outpost 507 / 617; Redtusk Village 553 / 793; Gor Drazhak 1050 / 1270; Redtusk Bandit Camp 654 / 1846; Cutgrass Watch 1453 / 2101.

### Current quests (10, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r14_orc_01_tusks_at_the_water_skins | Tusks at the Water Skins | Gara Stonevoice (Sunscar) | 1 | kill 3 boar | 20 | - |
| r14_orc_02_meat_for_the_long_fire | Meat for the Long Fire | Ugra Brothstone (Sunscar) | 1 | bring 4 mobs:meat_raw | 20 | - |
| r14_orc_10_edge_of_the_first_camp | Edge of the First Camp | Gara Stonevoice (Sunscar) | 1 | bring 1 grug_materials:axe_wood | 15 | - |
| r20_orc_start_cook | Keep the Long Fire Fed | Ugra Brothstone (Sunscar) | 1 | bring 3 default:coal_lump | 20 | - |
| r14_orc_11_stone_has_no_pride | Stone Has No Pride | Gara Stonevoice (Sunscar) | 2 | bring 1 grug_materials:pick_stone | 45 | r14_orc_10_edge_of_the_first_camp |
| r14_orc_03_rats_under_the_hide_racks | Posts Beneath the Hide Racks | Gara Stonevoice (Sunscar) | 3 | bring 6 default:acacia_wood | 100 | r14_orc_01_tusks_at_the_water_skins |
| r14_orc_04_the_thirsting_dead | The Thirsting Dead | Gara Stonevoice (Sunscar) | 5 | kill 3 sun_dried_husk | 180 | r14_orc_01_tusks_at_the_water_skins |
| r14_orc_05_shells_by_the_bedrolls | Shells by the Bedrolls | Gara Stonevoice (Sunscar) | 5 | kill 5 scorpion | 180 | r14_orc_03_rats_under_the_hide_racks |
| r14_orc_06_husks_on_redtusk_road | The Road to Borak Redgrass | Gara Stonevoice (Sunscar) | 10 | talk to Borak Redgrass (redtusk_village) | 285 | r14_orc_05_shells_by_the_bedrolls |
| r20_orc_capital_intro | The Road to Gor Drazhak | Gara Stonevoice (Sunscar) | 10 | talk to Thorga Roadspeaker (gor_drazhak) | 285 | - |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| boar | Boar | neutral | 100.0% of land, L1-10 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| giant_rat | Giant Rat | aggressive | - | 84.0% of land, L1-10 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, blight_dirt, dirt_with_silver_litter |
| hare | Hare | critter | 87.6% of land, L1-10 | - | dirt_with_rainforest_litter, dry_dirt_with_dry_grass, sand, blight_dirt, mud |
| plains_runner | Plains Runner | neutral | 87.6% of land, L1-10 | - | dry_dirt_with_dry_grass |
| scorpion | Scorpion | aggressive | 33.5% of land, L4-10 | 33.5% of land, L4-10 | dry_dirt_with_dry_grass, mesa_clay |
| shore_crab | Shore Crab | neutral | 58208 nodes², L3-10 | 58208 nodes², L3-10 | sand (dry, within 6 nodes of water) |
| sun_dried_husk | Sun-Dried Husk | aggressive | - | 33.5% of land, L4-10 | dry_dirt_with_dry_grass, mesa_clay |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 18 | primary | anchor_005 (Sunscar, kragmar_sunscar_flats) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 799 / 258 | 0,2486 → -112,2263 |
| 43 | trail | anchor_041 (Redtusk Outpost, kragmar_redtusk_savanna) | joins road 18 | 486 / 294 | 197,2254 → -22,2437 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

