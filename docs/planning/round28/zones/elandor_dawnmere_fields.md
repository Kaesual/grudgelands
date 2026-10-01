# Dawnmere Fields (`elandor_dawnmere_fields`)

Zone 6 · start zone · accord · race region **human** · levels **1-10** · peaceful · relief `lowland` · seed 42

Map: [maps/elandor_dawnmere_fields.png](maps/elandor_dawnmere_fields.png). Machine-readable: [elandor_dawnmere_fields.json](elandor_dawnmere_fields.json). Coordinates are world nodes (x east, z north, y up).

Race track (human): step 1 of the track Dawnmere Fields → Goldmead Vale → Highcourt → Whitebridge Shire → Ashenward March.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -844..496, z -3140..-2196 (centroid -112, -2660) |
| Land area | 816912 nodes² (≈ 0.82 km²) |
| Hub point (authored) | 0, -2550 |
| Height above sea | min 0, p10 5, median 32, p90 47, max 63 |
| Slope | 1.3% steep (>1 node/node), 0.1% cliff (>2) |
| Biomes (measured) | meadows 86.3%, swamp 9.2%, deep_forest 4.5% |
| Neighbours (land border) | elandor_goldmead_vale (1492 nodes, mid -162,-2294) |
| Sea coast | 4064 nodes of coastline; sea-beach sand 61024 nodes²; lake/river-bank sand 4320 nodes² |
| Water inside | bay 595648 nodes², rivers/lakes 12368 nodes² |
| Protected / drift band | 3.0% of land protected (towns, villages, camps/POIs, road corridors); 1.7% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -356, -3053 | x -536..-132, z -3140..-2904 | 22112 | L3 |
| B2 | 87, -3065 | x -20..196, z -3112..-2980 | 8592 | L3 |
| B3 | 386, -2820 | x 268..480, z -2912..-2708 | 7296 | L3 |
| B4 | -791, -2386 | x -844..-720, z -2440..-2292 | 7168 | L7-10 |
| B5 | -681, -2578 | x -724..-640, z -2660..-2492 | 5344 | L4-6 |
| B6 | -629, -2762 | x -652..-604, z -2852..-2676 | 3968 | L3-4 |
| B7 | 234, -2929 | x 208..264, z -2976..-2900 | 1664 | L3 |
| B8 | 405, -2221 | x 388..416, z -2268..-2200 | 896 | L8-10 |
| B9 | 358, -2615 | x 340..376, z -2636..-2596 | 736 | L3 |
| B10 | 487, -2639 | x 476..496, z -2648..-2632 | 352 | L3 |
| B11 | -690, -2425 | x -712..-668, z -2436..-2416 | 320 | L7-8 |
| B12 | 488, -2688 | x 480..492, z -2700..-2676 | 208 | L3 |

## Levels

Start-zone gradient (zones.lua): L1 within 100 nodes of the start anchor, L2 to 150; beyond, band 1 top (L3) behind and beside the town, rising through band 2 (L4-6) and band 3 (L7-10) toward the front border (+z), reaching L10 at the border.

Share of land per level: L1 3.8%, L2 4.7%, L3 64.0%, L4 6.3%, L5 5.4%, L6 4.4%, L7 2.5%, L8 3.3%, L9 3.0%, L10 2.6%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_002 | start town | Dawnmere | 0 | 36 | -2550 | 1 | - |

## Protected areas

- Start town: pad x -64..63, z -2614..-2487 plus a 12-node band (outer box x -76..75, z -2626..-2475); hard protected, hostile spawns refused.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Dawnmere (`dawnmere`, anchor_002) at 0, 36, -2550

Residents/guards: guard_patrol 5, guard_post 2, idle 6, innkeeper 1, public_station 1, quest 2, trainer 1, vendor 1, work 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| green_vendor | vendor | vendor kind: race | 6, 37, -2554 | - |
| home_innkeeper | innkeeper (respawn bind) |  | 11, 37, -2541 | - |
| hall_quest | quest giver | Elian Reed | -11, 37, -2542 | r14_human_01_boars_beyond_the_fence, r14_human_03_granary_teeth, r14_human_04_shapes_by_lanternlight, r14_human_05_the_missing_flock, r14_human_06_flock_on_mill_road, r14_human_10_a_woodsman_s_edge, r14_human_11_a_pick_for_the_road, r20_human_capital_intro |
| trainer_cooking | profession trainer | trains: cooking | 2, 37, -2540 | - |
| quest_cook | quest giver | Bess Honeycrust | 2, 37, -2537 | r14_human_02_the_smokehouse_share, r20_human_start_cook |

Public stations: cook_oven (furnace).

Distances: zone edge N 236 (elandor_goldmead_vale), S 552 (coastal_shelf), E 476 (bay_water), W 696 (coastal_shelf); nearest other-zone land 229 N; sea 362 E; sea-beach sand 345 E; nearest road 64.
Nearest hubs (straight / by road): Goldmead Outpost 553 / 686; Goldmead Bandit Camp 654 / 1022; Highcourt 1050 / 1366; Goldmead Village 543 / 1576; Oakspan Tollhouse 1425 / 2134.

### Current quests (10, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r14_human_01_boars_beyond_the_fence | Boars Beyond the Fence | Elian Reed (Dawnmere) | 1 | kill 3 boar | 20 | - |
| r14_human_02_the_smokehouse_share | The Smokehouse Share | Bess Honeycrust (Dawnmere) | 1 | bring 4 mobs:meat_raw | 20 | - |
| r14_human_10_a_woodsman_s_edge | A Woodsman's Edge | Elian Reed (Dawnmere) | 1 | bring 1 grug_materials:axe_wood | 15 | - |
| r20_human_start_cook | The Second Oven | Bess Honeycrust (Dawnmere) | 1 | bring 3 default:coal_lump | 20 | - |
| r14_human_11_a_pick_for_the_road | A Pick for the Road | Elian Reed (Dawnmere) | 2 | bring 1 grug_materials:pick_stone | 45 | r14_human_10_a_woodsman_s_edge |
| r14_human_03_granary_teeth | Braces for the Granary | Elian Reed (Dawnmere) | 3 | bring 6 default:wood | 100 | r14_human_01_boars_beyond_the_fence |
| r14_human_04_shapes_by_lanternlight | Shapes by Lanternlight | Elian Reed (Dawnmere) | 4 | kill 3 zombie | 140 | r14_human_01_boars_beyond_the_fence |
| r14_human_05_the_missing_flock | The Missing Flock | Elian Reed (Dawnmere) | 5 | kill 5 wild_turkey | 180 | r14_human_03_granary_teeth |
| r14_human_06_flock_on_mill_road | The Road to Marta Millward | Elian Reed (Dawnmere) | 10 | talk to Marta Millward (goldmead_village) | 285 | r14_human_05_the_missing_flock |
| r20_human_capital_intro | The Road to Highcourt | Elian Reed (Dawnmere) | 10 | talk to Mariel Waybook (highcourt) | 285 | - |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| boar | Boar | neutral | 100.0% of land, L1-10 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| fox | Fox | aggressive | 24.2% of land, L4-10 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_silver_litter |
| giant_rat | Giant Rat | aggressive | - | 83.7% of land, L1-10 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, blight_dirt, dirt_with_silver_litter |
| rabbit | Rabbit | critter | 100.0% of land, L1-10 | - | dirt_with_coniferous_litter, dirt_with_grass, gravel, sand, snowblock, dirt_with_forest_litter … |
| shore_crab | Shore Crab | neutral | 61024 nodes², L3-10 | 61024 nodes², L3-10 | sand (dry, within 6 nodes of water) |
| wild_turkey | Wild Turkey | critter | 87.0% of land, L1-10 | - | dirt_with_grass |
| zombie | Zombie | aggressive | - | 91.5% of land, L3-10 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 4 | primary | anchor_002 (Dawnmere, elandor_dawnmere_fields) | anchor_008 (Highcourt, elandor_highcourt) | 796 / 180 | -1,-2486 → -13,-2319 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

