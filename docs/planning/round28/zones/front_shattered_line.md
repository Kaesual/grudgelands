# The Shattered Line (`front_shattered_line`)

Zone 36 · front zone · contested · race region **orc** · levels **41-50** · contested · relief `plateau` · seed 42

Map: [maps/front_shattered_line.png](maps/front_shattered_line.png). Machine-readable: [front_shattered_line.json](front_shattered_line.json). Coordinates are world nodes (x east, z north, y up).

**Front:** Battlegrounds band around z = 0: Accord comes from -z (south), Throng from +z (north).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -8..1448, z -432..452 (centroid 687, 0) |
| Land area | 1004416 nodes² (≈ 1.00 km²) |
| Hub point (authored) | 750, 0 |
| Height above sea | min 42, p10 84, median 137, p90 205, max 390 |
| Slope | 20.7% steep (>1 node/node), 2.7% cliff (>2) |
| Biomes (measured) | badlands 73.5%, swamp 14.5%, savanna 10.5%, deep_forest 0.6%, meadows 0.4%, jungle_fringe 0.3%, deep_jungle 0.2% |
| Neighbours (land border) | elandor_ashenward_march (1192 nodes, mid 490,-371), elandor_glassroot_wilds (600 nodes, mid 1181,-374), front_broken_causeway (1008 nodes, mid 10,39), front_skyglass_canopy (760 nodes, mid 1403,-15), kragmar_bannerbreak_mesa (1276 nodes, mid 533,371), kragmar_thunderroot_wilds (376 nodes, mid 1194,355) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 7984 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 22400 nodes² |
| Protected / drift band | 0.6% of land protected (towns, villages, camps/POIs, road corridors); 1.5% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L41 12.0%, L42 10.6%, L43 11.1%, L44 12.2%, L45 10.0%, L46 11.1%, L47 8.8%, L48 7.6%, L49 8.6%, L50 8.0%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_081 | clash site | West Trench Mouth | 250 | 143 | 100 | 47 | poi x 242..257, z 92..107 |
| anchor_082 | clash site | Siege Ramp Foot | 782 | 114 | -116 | 47 | poi x 774..789, z -124..-109 |
| anchor_083 | clash site | No-Man's Orchard | 1282 | 113 | 84 | 47 | poi x 1274..1289, z 76..91 |
| anchor_100 | rare route | Bonerattle's Siege Halt | 600 | 156 | -80 | 48 | poi x 594..605, z -86..-75 |

## Protected areas

- poi West Trench Mouth (anchor_081): x 242..257, z 92..107
- poi Siege Ramp Foot (anchor_082): x 774..789, z -124..-109
- poi No-Man's Orchard (anchor_083): x 1274..1289, z 76..91
- poi Bonerattle's Siege Halt (anchor_100): x 594..605, z -86..-75
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

No quest is given in this zone today.

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| dustwing_vulture | Mesa Vulture | aggressive | 32.5% of land, L41-50 | - |  |
| reed_stalking_tiger | Tallgrass Tiger | aggressive | 32.5% of land, L41-50 | - |  |
| siege_deserter | Siege Deserter | aggressive | 36.6% of land, L41-45 | 15.0% of land, L41-43 |  |
| siege_deserter_archer | Siege Deserter Archer | aggressive | 18.7% of land, L48-50 | 40.4% of land, L46-50 |  |
| siege_husk | Siege-Worn Sun-Dried Husk | aggressive | 12.1% of land, L41-45 | 15.1% of land, L41-43 |  |
| siege_skeleton_raider | Siege Skeleton Raider | aggressive | - | 55.3% of land, L41-50 |  |
| unburied_husk | Unburied Mummy | aggressive | 5.3% of land, L46-47 | 29.6% of land, L46-50 |  |
| war_stinger | War-Stinger Scorpion | aggressive | - | 44.7% of land, L41-50 |  |
| warpack_hyena | Warpack Hyena | aggressive | 55.3% of land, L41-50 | - |  |
| watchful_carrion_crow | Battlefield Crow | neutral | 6.8% of land, L41-43 | - |  |

**Rares (knowledge rewards, not quest targets):** Captain Bonerattle (skeleton_raider, the war coast, route 552,-104 → 616,-40 → 656,-96, L47, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 29 | primary | anchor_008 (Highcourt, elandor_highcourt) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 2860 / 364 | -5,24 → 52,452 |
| 57 | trail | anchor_056 (Pallcloth Den, kragmar_blackwind_rise) | joins road 29 | 2074 / 20 | 23,411 → 39,419 |
| 59 | trail | anchor_058 (Sunderstrap Camp, kragmar_bannerbreak_mesa) | joins road 29 | 207 / 130 | 90,453 → 80,336 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

