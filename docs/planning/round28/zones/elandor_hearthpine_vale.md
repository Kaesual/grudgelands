# Hearthpine Vale (`elandor_hearthpine_vale`)

Zone 1 · start zone · accord · race region **dwarf** · levels **1-10** · peaceful · relief `lowland` · seed 42

Map: [maps/elandor_hearthpine_vale.png](maps/elandor_hearthpine_vale.png). Machine-readable: [elandor_hearthpine_vale.json](elandor_hearthpine_vale.json). Coordinates are world nodes (x east, z north, y up).

Race track (dwarf): step 1 of the track Hearthpine Vale → Copperfell Foothills → Dur Brannoc → Frostbarrow Shelf → Stormvault Heights.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2580..-1248, z -2956..-2232 (centroid -1901, -2602) |
| Land area | 506016 nodes² (≈ 0.51 km²) |
| Hub point (authored) | -1800, -2550 |
| Height above sea | min 0, p10 4, median 33, p90 51, max 88 |
| Slope | 2.7% steep (>1 node/node), 0.3% cliff (>2) |
| Biomes (measured) | pine_hills 86.2%, crags 13.8% |
| Neighbours (land border) | elandor_copperfell_foothills (1732 nodes, mid -1892,-2385) |
| Sea coast | 3360 nodes of coastline; sea-beach sand 39712 nodes²; lake/river-bank sand 0 nodes² |
| Water inside | bay 292032 nodes², rivers/lakes 0 nodes² |
| Protected / drift band | 4.9% of land protected (towns, villages, camps/POIs, road corridors); 2.9% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -2225, -2893 | x -2356..-2068, z -2956..-2832 | 11504 | L3 |
| B2 | -1491, -2675 | x -1644..-1408, z -2816..-2556 | 9824 | L3 |
| B3 | -2428, -2850 | x -2504..-2376, z -2880..-2812 | 3984 | L3-4 |
| B4 | -1321, -2315 | x -1356..-1256, z -2396..-2252 | 3968 | L6-10 |
| B5 | -2045, -2813 | x -2072..-2016, z -2848..-2788 | 2320 | L3 |
| B6 | -1387, -2512 | x -1404..-1372, z -2548..-2476 | 1984 | L3-4 |
| B7 | -1833, -2842 | x -1904..-1780, z -2892..-2816 | 1968 | L3 |
| B8 | -1414, -2437 | x -1452..-1380, z -2456..-2420 | 1696 | L4-5 |
| B9 | -1480, -2499 | x -1492..-1464, z -2548..-2452 | 1088 | L3-4 |
| B10 | -2568, -2757 | x -2580..-2548, z -2784..-2724 | 848 | L5-6 |

## Levels

Start-zone gradient (zones.lua): L1 within 100 nodes of the start anchor, L2 to 150; beyond, band 1 top (L3) behind and beside the town, rising through band 2 (L4-6) and band 3 (L7-10) toward the front border (+z), reaching L10 at the border.

Share of land per level: L1 6.2%, L2 7.8%, L3 46.3%, L4 8.5%, L5 7.9%, L6 7.2%, L7 4.6%, L8 4.0%, L9 4.0%, L10 3.6%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_001 | start town | Hearthpine | -1800 | 35 | -2550 | 1 | - |

## Protected areas

- Start town: pad x -1864..-1737, z -2614..-2487 plus a 12-node band (outer box x -1876..-1725, z -2626..-2475); hard protected, hostile spawns refused.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Hearthpine (`hearthpine`, anchor_001) at -1800, 35, -2550

Residents/guards: guard_patrol 5, guard_post 2, idle 6, innkeeper 1, public_station 1, quest 2, trainer 1, vendor 1, work 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| plaza_vendor | vendor | vendor kind: race | -1793, 36, -2555 | - |
| idle_west_door | innkeeper (respawn bind) |  | -1816, 36, -2546 | - |
| hall_quest | quest giver | Brunna Flintbraid | -1828, 36, -2524 | r14_dwarf_01_tusks_at_the_timberline, r14_dwarf_03_rats_in_the_woodpiles, r14_dwarf_04_lanterns_after_sundown, r14_dwarf_05_the_high_path, r14_dwarf_06_loose_stone_on_copper_road, r14_dwarf_10_an_axe_worth_carrying, r14_dwarf_11_stone_before_steel, r20_dwarf_capital_intro |
| trainer_cooking | profession trainer | trains: cooking | -1798, 36, -2540 | - |
| quest_cook | quest giver | Hilda Hearthspoon | -1798, 36, -2537 | r14_dwarf_02_meat_for_the_smokehouse, r20_dwarf_start_cook |

Public stations: cook_oven (furnace).

Distances: zone edge N 244 (elandor_copperfell_foothills), S 320 (coastal_shelf), E 332 (coastal_shelf), W 548 (elandor_copperfell_foothills); nearest other-zone land 206 NW; sea 282 S; sea-beach sand 267 S; nearest road 64.
Nearest hubs (straight / by road): Copperfell Outpost 541 / 638; Copperfell Village 518 / 655; Copperfell Bandit Camp 537 / 673; Dur Brannoc 1050 / 1378; Tarnwatch Fold 1146 / 2058.

### Current quests (10, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r14_dwarf_01_tusks_at_the_timberline | Tusks at the Timberline | Brunna Flintbraid (Hearthpine) | 1 | kill 3 boar or small_boar | 20 | - |
| r14_dwarf_02_meat_for_the_smokehouse | Meat for the Smokehouse | Hilda Hearthspoon (Hearthpine) | 1 | bring 4 mobs:meat_raw | 20 | - |
| r14_dwarf_10_an_axe_worth_carrying | An Axe Worth Carrying | Brunna Flintbraid (Hearthpine) | 1 | bring 1 grug_materials:axe_wood | 15 | - |
| r20_dwarf_start_cook | Warmth for the Timber Shift | Hilda Hearthspoon (Hearthpine) | 1 | bring 3 default:coal_lump | 20 | - |
| r14_dwarf_11_stone_before_steel | Stone Before Steel | Brunna Flintbraid (Hearthpine) | 2 | bring 1 grug_materials:pick_stone | 45 | r14_dwarf_10_an_axe_worth_carrying |
| r14_dwarf_03_rats_in_the_woodpiles | Boards for the Winter Stacks | Brunna Flintbraid (Hearthpine) | 3 | bring 6 default:pine_wood | 100 | r14_dwarf_01_tusks_at_the_timberline |
| r14_dwarf_04_lanterns_after_sundown | Lanterns After Sundown | Brunna Flintbraid (Hearthpine) | 4 | kill 3 zombie or braindead_zombie or sluggish_zombie | 140 | r14_dwarf_01_tusks_at_the_timberline |
| r14_dwarf_05_the_high_path | The High Path | Brunna Flintbraid (Hearthpine) | 5 | kill 5 ibex or young_ibex | 180 | r14_dwarf_03_rats_in_the_woodpiles |
| r14_dwarf_06_loose_stone_on_copper_road | The Road to Orrik Pineledger | Brunna Flintbraid (Hearthpine) | 10 | talk to Orrik Pineledger (copperfell_village) | 285 | r14_dwarf_05_the_high_path |
| r20_dwarf_capital_intro | The Road to Dur Brannoc | Brunna Flintbraid (Hearthpine) | 10 | talk to Dorrin Gateledger (dur_brannoc) | 285 | - |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| aggressive_boar | Aggressive Boar | aggressive | 31.9% of land, L5-10 | - |  |
| braindead_zombie | Braindead Zombie | aggressive | - | 7.6% of land, L3-4 |  |
| confused_bandit | Confused Bandit | aggressive | 1.8% of land, L9-10 | 1.8% of land, L9-10 |  |
| drowned_zombie | Monstrous Drowned Zombie | aggressive | - | 5.6% of land, L8-10 |  |
| giant_crab | Monstrous Crab | aggressive | 4.2% of land, L7-10 | - |  |
| large_rat | Large Rat | aggressive | - | 32.5% of land, L1-4 |  |
| monstrous_rat | Monstrous Rat | aggressive | - | 22.9% of land, L8-10 |  |
| quiet_shore_crab | Small Crab | neutral | 7.8% of land, L3-6 | - |  |
| rabid_rat | Aggressive Rat | aggressive | - | 21.9% of land, L5-7 |  |
| shore_crab | Shore Crab | neutral | 39712 nodes², L3-10 | 39712 nodes², L3-10 | sand (dry, within 6 nodes of water) |
| sluggish_zombie | Sluggish Zombie | aggressive | - | 7.6% of land, L5-7 |  |
| small_boar | Small Boar | neutral | 34.5% of land, L1-4 | - |  |
| small_fox | Young Fox | neutral | 27.3% of land, L5-7 | - |  |
| young_ibex | Young Ibex | neutral | 21.9% of land, L5-7 | - |  |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 3 | primary | anchor_001 (Hearthpine, elandor_hearthpine_vale) | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | 825 / 198 | -1800,-2486 → -1793,-2302 |
| 32 | trail | anchor_025 (Copperfell Outpost, elandor_copperfell_foothills) | joins road 3 | 368 / 4 | -1797,-2304 → -1795,-2305 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

