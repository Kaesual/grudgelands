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

Residents/guards: guard_patrol 5, guard_post 2, idle 6, innkeeper 1, public_station 1, quest 2, trainer 1, vendor 1, waypoint 1, work 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| green_vendor | vendor | vendor kind: race | 6, 37, -2554 | - |
| home_innkeeper | innkeeper (respawn bind) |  | 11, 37, -2541 | - |
| hall_quest | quest giver | Elian Reed | -11, 37, -2542 | dawnmere_departure, dawnmere_hunt_01, dawnmere_hunt_02, dawnmere_hunt_03, dawnmere_hunt_04, dawnmere_hunt_05, dawnmere_tools_01, dawnmere_tools_02, dawnmere_tools_03, dawnmere_tools_04 |
| travel_waypoint | waypoint |  | 14, 37, -2556 | - |
| trainer_cooking | profession trainer | trains: cooking | 2, 37, -2540 | - |
| quest_cook | quest giver | Bess Honeycrust | 2, 37, -2537 | dawnmere_kitchen_01, dawnmere_kitchen_02, dawnmere_kitchen_03, dawnmere_pantry_01, dawnmere_pantry_02 |

Public stations: cook_oven (furnace).

Distances: zone edge N 236 (elandor_goldmead_vale), S 552 (coastal_shelf), E 476 (bay_water), W 696 (coastal_shelf); nearest other-zone land 229 N; sea 362 E; sea-beach sand 345 E; nearest road 64.
Nearest hubs (straight / by road): Goldmead Outpost 553 / 686; Goldmead Bandit Camp 654 / 1022; Highcourt 1050 / 1366; Goldmead Village 543 / 1576; Petalbank Wardenry 1465 / 2173.

### Current quests (15, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| dawnmere_hunt_01 | Crop Thieves | Elian Reed (Dawnmere) | 1 | kill 8 small_boar [in elandor_dawnmere_fields/home_fields] | 105 | - |
| dawnmere_kitchen_01 | Five Logs, Any Tree | Bess Honeycrust (Dawnmere) | 1 | bring 5 group:tree | 30 | - |
| dawnmere_tools_01 | Two Hands, Two Tools | Elian Reed (Dawnmere) | 1 | bring 1 grug_materials:axe_wood; bring 1 grug_materials:pick_wood | 30 | - |
| dawnmere_hunt_02 | The Night Shift | Elian Reed (Dawnmere) | 2 | kill 8 large_rat [in elandor_dawnmere_fields/meadows] | 120 | dawnmere_hunt_01 |
| dawnmere_kitchen_02 | A Proper Fire | Bess Honeycrust (Dawnmere) | 2 | bring 5 default:coal_lump | 60 | dawnmere_kitchen_01 |
| dawnmere_tools_02 | A Stone Edge | Elian Reed (Dawnmere) | 2 | bring 1 grug_materials:axe_stone; bring 1 grug_materials:pick_stone | 60 | dawnmere_tools_01 |
| dawnmere_pantry_01 | The Rats Can Mend It | Bess Honeycrust (Dawnmere) | 3 | bring 2 grug_mobs:rat_fur_patch | 60 | dawnmere_hunt_02 |
| dawnmere_hunt_03 | Foxes Before Breakfast | Elian Reed (Dawnmere) | 4 | kill 8 small_fox [in elandor_dawnmere_fields/pastures] | 165 | dawnmere_hunt_02 |
| dawnmere_kitchen_03 | The Smokehouse Share | Bess Honeycrust (Dawnmere) | 4 | bring 10 mobs:meat_raw | 100 | dawnmere_kitchen_02, dawnmere_hunt_02 |
| dawnmere_tools_03 | Metal for the Mending | Elian Reed (Dawnmere) | 5 | bring 3 grug_materials:copper_bar; bring 3 grug_materials:tin_bar | 110 | dawnmere_tools_02 |
| dawnmere_hunt_04 | Five Claws Too Many | Elian Reed (Dawnmere) | 7 | kill 5 giant_crab [in elandor_dawnmere_fields/wreck_coast] | 163 | dawnmere_hunt_03 |
| dawnmere_pantry_02 | A Brush and a Better Supper | Bess Honeycrust (Dawnmere) | 7 | bring 2 grug_mobs:crab_leg; bring 1 grug_mobs:fox_tail | 130 | dawnmere_pantry_01, dawnmere_hunt_04 |
| dawnmere_tools_04 | An Edge for the Road | Elian Reed (Dawnmere) | 7 | bring 3 grug_materials:bronze_bar | 130 | dawnmere_tools_03 |
| dawnmere_hunt_05 | Requisition for One Crumb | Elian Reed (Dawnmere) | 8 | kill 7 confused_bandit [in elandor_dawnmere_fields/bandit_camp]; kill 1 confused_bandit_chief | 280 | dawnmere_hunt_04 |
| dawnmere_departure | The Next Sack of Grain | Elian Reed (Dawnmere) | 9 | talk to Marta Millward (goldmead_village) | 35 | dawnmere_hunt_05 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| aggressive_boar | Aggressive Boar | aggressive | 51.4% of land, L5-10 | - |  |
| braindead_zombie | Braindead Zombie | aggressive | - | 7.7% of land, L3-4 |  |
| confused_bandit | Confused Bandit | aggressive | 1.1% of land, L9-10 | 1.1% of land, L9-10 |  |
| drowned_zombie | Monstrous Drowned Zombie | aggressive | - | 4.6% of land, L8-10 |  |
| giant_crab | Monstrous Crab | aggressive | 6.6% of land, L7-10 | - |  |
| large_rat | Large Rat | aggressive | - | 33.1% of land, L1-4 |  |
| monstrous_rat | Monstrous Rat | aggressive | - | 23.9% of land, L8-10 |  |
| quiet_shore_crab | Small Crab | neutral | 7.2% of land, L3-6 | - |  |
| rabid_rat | Aggressive Rat | aggressive | - | 22.8% of land, L5-7 |  |
| shore_crab | Shore Crab | neutral | 61024 nodes², L3-10 | 61024 nodes², L3-10 | sand (dry, within 6 nodes of water) |
| sluggish_zombie | Sluggish Zombie | aggressive | - | 6.7% of land, L5-7 |  |
| small_boar | Small Boar | neutral | 38.0% of land, L1-4 | - |  |
| small_fox | Young Fox | neutral | 25.2% of land, L5-7 | - |  |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 4 | primary | anchor_002 (Dawnmere, elandor_dawnmere_fields) | anchor_008 (Highcourt, elandor_highcourt) | 796 / 180 | -1,-2486 → -13,-2319 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

