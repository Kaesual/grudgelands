# Silverleaf Glades (`elandor_silverleaf_glades`)

Zone 11 · start zone · accord · race region **elf** · levels **1-10** · peaceful · relief `lowland` · seed 42

Map: [maps/elandor_silverleaf_glades.png](maps/elandor_silverleaf_glades.png). Machine-readable: [elandor_silverleaf_glades.json](elandor_silverleaf_glades.json). Coordinates are world nodes (x east, z north, y up).

Race track (elf): step 1 of the track Silverleaf Glades → Starbough Vale → Lethariel → Lorindor → Moonfall Wood → Glassroot Wilds.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 1180..2564, z -3032..-2224 (centroid 1903, -2598) |
| Land area | 653968 nodes² (≈ 0.65 km²) |
| Hub point (authored) | 1800, -2550 |
| Height above sea | min 0, p10 6, median 35, p90 59, max 121 |
| Slope | 2.8% steep (>1 node/node), 0.2% cliff (>2) |
| Biomes (measured) | elf_forest 99.9%, deep_forest 0.1% |
| Neighbours (land border) | elandor_moonfall_wood (208 nodes, mid 2506,-2371), elandor_starbough_vale (1444 nodes, mid 1877,-2318) |
| Sea coast | 3448 nodes of coastline; sea-beach sand 42224 nodes²; lake/river-bank sand 0 nodes² |
| Water inside | bay 426704 nodes², rivers/lakes 0 nodes² |
| Protected / drift band | 3.8% of land protected (towns, villages, camps/POIs, road corridors); 2.3% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 1708, -2874 | x 1572..1848, z -2956..-2804 | 9520 | L3 |
| B2 | 1379, -2446 | x 1320..1428, z -2628..-2316 | 9040 | L3-9 |
| B3 | 1395, -2739 | x 1348..1468, z -2792..-2664 | 5056 | L3 |
| B4 | 2532, -2487 | x 2504..2564, z -2588..-2392 | 4800 | L6-10 |
| B5 | 2130, -2895 | x 2084..2224, z -2952..-2852 | 4048 | L3 |
| B6 | 1202, -2269 | x 1180..1252, z -2320..-2228 | 2288 | L8-10 |
| B7 | 2322, -2851 | x 2268..2352, z -2896..-2784 | 2144 | L3 |
| B8 | 1357, -2283 | x 1320..1388, z -2308..-2264 | 1536 | L9-10 |
| B9 | 2438, -2658 | x 2420..2456, z -2684..-2632 | 992 | L4 |
| B10 | 2092, -3019 | x 2064..2108, z -3032..-2996 | 688 | L3 |
| B11 | 2415, -2738 | x 2396..2432, z -2752..-2716 | 688 | L3 |
| B12 | 1350, -2649 | x 1344..1360, z -2660..-2636 | 224 | L3 |

## Levels

Start-zone gradient (zones.lua): L1 within 100 nodes of the start anchor, L2 to 150; beyond, band 1 top (L3) behind and beside the town, rising through band 2 (L4-6) and band 3 (L7-10) toward the front border (+z), reaching L10 at the border.

Share of land per level: L1 4.8%, L2 6.0%, L3 53.8%, L4 7.4%, L5 6.2%, L6 5.5%, L7 4.1%, L8 4.4%, L9 4.1%, L10 3.7%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_003 | start town | Silverleaf | 1800 | 36 | -2550 | 1 | - |

## Protected areas

- Start town: pad x 1736..1863, z -2614..-2487 plus a 12-node band (outer box x 1724..1875, z -2626..-2475); hard protected, hostile spawns refused.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Silverleaf (`silverleaf`, anchor_003) at 1800, 36, -2550

Residents/guards: guard_patrol 5, guard_post 2, idle 6, innkeeper 1, public_station 1, quest 2, trainer 1, vendor 1, waypoint 1, work 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| court_vendor | vendor | vendor kind: race | 1807, 37, -2554 | - |
| home_innkeeper | innkeeper (respawn bind) |  | 1765, 37, -2572 | - |
| hall_quest | quest giver | Saelin Dewbough | 1820, 37, -2536 | silverleaf_departure, silverleaf_hunt_01, silverleaf_hunt_02, silverleaf_hunt_03, silverleaf_hunt_04, silverleaf_hunt_05, silverleaf_tools_01, silverleaf_tools_02, silverleaf_tools_03, silverleaf_tools_04 |
| travel_waypoint | waypoint |  | 1756, 37, -2573 | - |
| trainer_cooking | profession trainer | trains: cooking | 1802, 37, -2540 | - |
| quest_cook | quest giver | Liora Dewpot | 1802, 37, -2537 | silverleaf_kitchen_01, silverleaf_kitchen_02, silverleaf_kitchen_03, silverleaf_pantry_01, silverleaf_pantry_02, silverleaf_pantry_03 |

Public stations: cook_oven (furnace).

Distances: zone edge N 236 (elandor_starbough_vale), S 408 (coastal_shelf), E 740 (coastal_shelf), W 444 (bay_water); nearest other-zone land 235 N; sea 342 SW; sea-beach sand 305 SW; nearest road 64.
Nearest hubs (straight / by road): Starbough Village 539 / 696; Starbough Outpost 541 / 774; Starbough Bandit Camp 512 / 944; Lethariel 1050 / 1289; Paleroot Cutting 1508 / 2175.

### Current quests (16, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| silverleaf_hunt_01 | A Century Down the Snout | Saelin Dewbough (Silverleaf) | 1 | kill 8 small_boar [in elandor_silverleaf_glades/home_glades] | 105 | - |
| silverleaf_kitchen_01 | The Oven Keeps No Seasons | Liora Dewpot (Silverleaf) | 1 | bring 5 group:tree | 30 | - |
| silverleaf_tools_01 | Begin with the Grain | Saelin Dewbough (Silverleaf) | 1 | bring 1 grug_materials:axe_wood; bring 1 grug_materials:pick_wood | 30 | - |
| silverleaf_hunt_02 | The Ferns Have Teeth | Saelin Dewbough (Silverleaf) | 2 | kill 8 large_rat [in elandor_silverleaf_glades/home_glades] | 105 | silverleaf_hunt_01 |
| silverleaf_kitchen_02 | Embers Before Eloquence | Liora Dewpot (Silverleaf) | 2 | bring 5 default:coal_lump | 60 | silverleaf_kitchen_01 |
| silverleaf_tools_02 | A Lesson That Holds Its Edge | Saelin Dewbough (Silverleaf) | 2 | bring 1 grug_materials:axe_stone; bring 1 grug_materials:pick_stone | 60 | silverleaf_tools_01 |
| silverleaf_hunt_03 | Let the Grass Remember Footsteps | Saelin Dewbough (Silverleaf) | 3 | kill 6 braindead_zombie [in elandor_silverleaf_glades/strand] | 135 | silverleaf_hunt_02 |
| silverleaf_pantry_01 | The Basket-Mender's Due | Liora Dewpot (Silverleaf) | 3 | bring 2 grug_mobs:rat_fur_patch | 60 | silverleaf_hunt_02 |
| silverleaf_hunt_04 | Eight Shadows in the Seedbeds | Saelin Dewbough (Silverleaf) | 4 | kill 8 small_fox [in elandor_silverleaf_glades/foxglades] | 165 | silverleaf_hunt_03 |
| silverleaf_kitchen_03 | Enough for the Latecomers | Liora Dewpot (Silverleaf) | 4 | bring 10 mobs:meat_raw | 100 | silverleaf_kitchen_02 |
| silverleaf_pantry_02 | A Shore Supper | Liora Dewpot (Silverleaf) | 4 | bring 2 grug_mobs:crab_leg | 100 | silverleaf_pantry_01 |
| silverleaf_pantry_03 | Dust Is Not a Seasoning | Liora Dewpot (Silverleaf) | 5 | bring 2 grug_mobs:fox_tail | 110 | silverleaf_pantry_02, silverleaf_hunt_04 |
| silverleaf_tools_03 | A Hall Should Not Creak | Saelin Dewbough (Silverleaf) | 5 | bring 3 grug_materials:copper_bar; bring 3 grug_materials:tin_bar | 110 | silverleaf_tools_02 |
| silverleaf_tools_04 | The Third Metal | Saelin Dewbough (Silverleaf) | 7 | bring 3 grug_materials:bronze_bar | 130 | silverleaf_tools_03 |
| silverleaf_hunt_05 | A Forest Is Not a Woodpile | Saelin Dewbough (Silverleaf) | 8 | kill 7 furtive_poacher or confused_bandit [in elandor_silverleaf_glades/poacher_camp]; kill 1 misguided_poacher_chief | 350 | silverleaf_hunt_04 |
| silverleaf_departure | Beyond the First Ring | Saelin Dewbough (Silverleaf) | 9 | talk to Ilyra Mossveil (starbough_village) | 35 | silverleaf_hunt_05 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| aggressive_boar | Aggressive Boar | aggressive | 54.4% of land, L5-10 | - |  |
| braindead_zombie | Braindead Zombie | aggressive | - | 32.5% of land, L3-4 |  |
| confused_bandit | Confused Bandit | aggressive | 1.4% of land, L9-10 | 1.4% of land, L9-10 |  |
| drowned_zombie | Monstrous Drowned Zombie | aggressive | - | 28.6% of land, L8-10 |  |
| furtive_poacher | Confused Poacher | aggressive | 1.4% of land, L8-10 | 1.4% of land, L8-10 |  |
| giant_crab | Monstrous Crab | aggressive | 4.2% of land, L7-10 | - |  |
| large_rat | Large Rat | aggressive | - | 36.6% of land, L1-4 |  |
| monstrous_rat | Monstrous Rat | aggressive | - | 26.6% of land, L8-10 |  |
| quiet_shore_crab | Small Crab | neutral | 5.6% of land, L3-6 | - |  |
| rabid_rat | Aggressive Rat | aggressive | - | 27.8% of land, L5-7 |  |
| shore_crab | Shore Crab | neutral | 42224 nodes², L3-10 | 42224 nodes², L3-10 | sand (dry, within 6 nodes of water) |
| sluggish_zombie | Sluggish Zombie | aggressive | - | 30.0% of land, L5-7 |  |
| small_boar | Small Boar | neutral | 36.6% of land, L1-4 | - |  |
| small_fox | Young Fox | neutral | 27.8% of land, L5-7 | - |  |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 5 | primary | anchor_003 (Silverleaf, elandor_silverleaf_glades) | anchor_009 (Lethariel, elandor_lethariel) | 810 / 200 | 1799,-2486 → 1750,-2315 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

