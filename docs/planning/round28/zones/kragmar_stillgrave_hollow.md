# Stillgrave Hollow (`kragmar_stillgrave_hollow`)

Zone 17 · start zone · throng · race region **undead** · levels **1-10** · peaceful · relief `lowland` · seed 42

Map: [maps/kragmar_stillgrave_hollow.png](maps/kragmar_stillgrave_hollow.png). Machine-readable: [kragmar_stillgrave_hollow.json](kragmar_stillgrave_hollow.json). Coordinates are world nodes (x east, z north, y up).

Race track (undead): step 1 of the track Stillgrave Hollow → Mournfen → Nhal Veyr → Ossuary Reach → Blackwind Rise.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2572..-1316, z 2136..3072 (centroid -1941, 2600) |
| Land area | 701440 nodes² (≈ 0.70 km²) |
| Hub point (authored) | -1800, 2550 |
| Height above sea | min 0, p10 5, median 35, p90 70, max 99 |
| Slope | 5.0% steep (>1 node/node), 0.1% cliff (>2) |
| Biomes (measured) | blight 88.3%, bone_forest 6.0%, swamp 5.7% |
| Neighbours (land border) | kragmar_mournfen (1500 nodes, mid -1898,2296), kragmar_ossuary_reach (272 nodes, mid -2472,2164) |
| Sea coast | 3680 nodes of coastline; sea-beach sand 53648 nodes²; lake/river-bank sand 2928 nodes² |
| Water inside | bay 279248 nodes², rivers/lakes 512 nodes² |
| Protected / drift band | 3.5% of land protected (towns, villages, camps/POIs, road corridors); 2.2% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -1453, 2777 | x -1652..-1344, z 2404..3016 | 29392 | L3-10 |
| B2 | -2062, 2913 | x -2140..-1972, z 2868..2976 | 5536 | L3 |
| B3 | -2386, 2690 | x -2492..-2244, z 2624..2780 | 4912 | L3-4 |
| B4 | -1814, 3023 | x -1912..-1712, z 2956..3068 | 4192 | L3 |
| B5 | -2540, 2255 | x -2572..-2504, z 2200..2320 | 4048 | L8-10 |
| B6 | -2515, 2466 | x -2560..-2480, z 2436..2508 | 2944 | L5-6 |
| B7 | -2187, 2806 | x -2204..-2176, z 2780..2832 | 592 | L3 |
| B8 | -2551, 2375 | x -2556..-2540, z 2352..2400 | 480 | L6-7 |
| B9 | -2443, 2563 | x -2464..-2424, z 2552..2576 | 448 | L4 |
| B10 | -2162, 2909 | x -2172..-2152, z 2904..2916 | 144 | L3 |

## Levels

Start-zone gradient (zones.lua): L1 within 100 nodes of the start anchor, L2 to 150; beyond, band 1 top (L3) behind and beside the town, rising through band 2 (L4-6) and band 3 (L7-10) toward the front border (-z), reaching L10 at the border.

Share of land per level: L1 4.5%, L2 5.6%, L3 57.4%, L4 6.7%, L5 6.0%, L6 5.7%, L7 3.9%, L8 3.6%, L9 3.3%, L10 3.3%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_004 | start town | Stillgrave | -1800 | 36 | 2550 | 1 | - |

## Protected areas

- Start town: pad x -1864..-1737, z 2486..2613 plus a 12-node band (outer box x -1876..-1725, z 2474..2625); hard protected, hostile spawns refused.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Stillgrave (`stillgrave`, anchor_004) at -1800, 36, 2550

Residents/guards: guard_patrol 5, guard_post 2, idle 6, innkeeper 1, public_station 1, quest 2, trainer 1, vendor 1, work 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| court_vendor | vendor | vendor kind: race | -1793, 37, 2545 | - |
| idle_warden_door | innkeeper (respawn bind) |  | -1813, 37, 2582 | - |
| hall_quest | quest giver | Veyra Pall | -1798, 37, 2560 | r14_undead_01_boars_in_the_dead_furrows, r14_undead_03_gnawing_in_the_crypt_stores, r14_undead_04_the_uncalled_dead, r14_undead_05_furrows_gone_sour, r14_undead_06_tusks_along_the_fen_road, r14_undead_10_a_handle_that_will_not_rot, r14_undead_11_a_pick_among_headstones, r20_undead_capital_intro |
| trainer_cooking | profession trainer | trains: cooking | -1798, 37, 2540 | - |
| quest_cook | quest giver | Neral Saltkeeper | -1798, 37, 2537 | r14_undead_02_salt_for_what_remains, r20_undead_start_cook |

Public stations: cook_oven (furnace).

Distances: zone edge N 512 (coastal_shelf), S 284 (kragmar_mournfen), E 340 (coastal_shelf), W 668 (coastal_shelf); nearest other-zone land 254 SW; sea 336 E; sea-beach sand 320 E; nearest road 64.
Nearest hubs (straight / by road): Mournfen Village 539 / 592; Mournfen Outpost 541 / 761; Nhal Veyr 1050 / 1265; Ossuary Ledgerstead 1113 / 1727; Mournfen Bandit Camp 539 / 1969.

### Current quests (10, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r14_undead_01_boars_in_the_dead_furrows | Boars in the Dead Furrows | Veyra Pall (Stillgrave) | 1 | kill 3 plague_boar or small_boar | 20 | - |
| r14_undead_02_salt_for_what_remains | Salt for What Remains | Neral Saltkeeper (Stillgrave) | 1 | bring 4 mobs:meat_raw | 20 | - |
| r14_undead_10_a_handle_that_will_not_rot | A Handle That Will Not Rot | Veyra Pall (Stillgrave) | 1 | bring 1 grug_materials:axe_wood | 15 | - |
| r20_undead_start_cook | Salt Against the Damp | Neral Saltkeeper (Stillgrave) | 1 | bring 3 default:coal_lump | 20 | - |
| r14_undead_11_a_pick_among_headstones | A Pick Among Headstones | Veyra Pall (Stillgrave) | 2 | bring 1 grug_materials:pick_stone | 45 | r14_undead_10_a_handle_that_will_not_rot |
| r14_undead_03_gnawing_in_the_crypt_stores | Dry Shelves for the Crypt Stores | Veyra Pall (Stillgrave) | 3 | bring 6 grug_trees:gravewood_wood | 100 | r14_undead_01_boars_in_the_dead_furrows |
| r14_undead_04_the_uncalled_dead | The Uncalled Dead | Veyra Pall (Stillgrave) | 4 | kill 3 zombie or braindead_zombie or sluggish_zombie | 140 | r14_undead_01_boars_in_the_dead_furrows |
| r14_undead_05_furrows_gone_sour | Stones Against the Sour Furrows | Veyra Pall (Stillgrave) | 5 | bring 8 default:cobble | 180 | r14_undead_03_gnawing_in_the_crypt_stores |
| r14_undead_06_tusks_along_the_fen_road | The Road to Mordec Silt | Veyra Pall (Stillgrave) | 10 | talk to Mordec Silt (mournfen_village) | 285 | r14_undead_05_furrows_gone_sour |
| r20_undead_capital_intro | The Road to Nhal Veyr | Veyra Pall (Stillgrave) | 10 | talk to Ossa Quietregister (nhal_veyr) | 285 | - |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| aggressive_boar | Aggressive Boar | aggressive | 47.5% of land, L5-10 | - |  |
| braindead_zombie | Braindead Zombie | aggressive | 30.1% of land, L3-4 | 33.3% of land, L3-4 |  |
| confused_bandit | Confused Bandit | aggressive | 1.3% of land, L9-10 | 1.3% of land, L9-10 |  |
| drowned_zombie | Monstrous Drowned Zombie | aggressive | - | 28.8% of land, L8-10 |  |
| giant_crab | Monstrous Crab | aggressive | 5.6% of land, L7-10 | - |  |
| large_rat | Large Rat | aggressive | - | 32.9% of land, L1-4 |  |
| monstrous_rat | Monstrous Rat | aggressive | - | 27.2% of land, L8-10 |  |
| quiet_shore_crab | Small Crab | neutral | 7.2% of land, L3-6 | - |  |
| rabid_rat | Aggressive Rat | aggressive | - | 20.3% of land, L5-7 |  |
| shore_crab | Shore Crab | neutral | 53648 nodes², L3-10 | 53648 nodes², L3-10 | sand (dry, within 6 nodes of water) |
| sluggish_zombie | Sluggish Zombie | aggressive | 5.4% of land, L5-7 | 29.7% of land, L5-7 |  |
| small_boar | Small Boar | neutral | 37.0% of land, L1-4 | - |  |
| young_gaunt_stag | Young Gaunt Stag | neutral | 25.6% of land, L5-7 | - |  |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 17 | primary | anchor_004 (Stillgrave, kragmar_stillgrave_hollow) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 782 / 226 | -1799,2486 → -1836,2270 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

