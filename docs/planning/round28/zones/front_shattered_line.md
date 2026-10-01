# The Shattered Line (`front_shattered_line`)

Zone 36 · front zone · contested · race region **orc** · levels **41-50** · contested · relief `plateau` · seed 42

Map: [maps/front_shattered_line.png](maps/front_shattered_line.png). Machine-readable: [front_shattered_line.json](front_shattered_line.json). Coordinates are world nodes (x east, z north, y up).

**Front:** Battlegrounds band around z = 0: Accord comes from -z (south), Throng from +z (north).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -8..1448, z -340..368 (centroid 722, 23) |
| Land area | 678368 nodes² (≈ 0.68 km²) |
| Hub point (authored) | 750, 0 |
| Height above sea | min 59, p10 93, median 142, p90 202, max 344 |
| Slope | 19.9% steep (>1 node/node), 2.5% cliff (>2) |
| Biomes (measured) | badlands 73.8%, swamp 13.7%, savanna 10.5%, deep_forest 1.2%, deep_jungle 0.3%, jungle_fringe 0.3%, meadows 0.2% |
| Neighbours (land border) | elandor_ashenward_march (1304 nodes, mid 492,-199), elandor_glassroot_wilds (540 nodes, mid 1190,-285), front_broken_causeway (524 nodes, mid 0,126), front_skyglass_canopy (632 nodes, mid 1402,27), kragmar_bannerbreak_mesa (1436 nodes, mid 502,281), kragmar_thunderroot_wilds (536 nodes, mid 1255,250) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 4656 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 8288 nodes² |
| Protected / drift band | 0.2% of land protected (towns, villages, camps/POIs, road corridors); 0.0% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L41 7.5%, L42 8.0%, L43 10.2%, L44 12.3%, L45 11.3%, L46 13.0%, L47 9.8%, L48 9.7%, L49 9.6%, L50 8.7%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_081 | clash site | West Trench Mouth | 250 | 144 | 100 | 47 | poi x 242..257, z 92..107 |
| anchor_082 | clash site | Siege Ramp Foot | 782 | 113 | -116 | 46 | poi x 774..789, z -124..-109 |
| anchor_083 | clash site | No-Man's Orchard | 1282 | 115 | 84 | 47 | poi x 1274..1289, z 76..91 |
| anchor_100 | rare route | Bonerattle's Siege Halt | 600 | 152 | -80 | 47 | poi x 594..605, z -86..-75 |

## Protected areas

- poi West Trench Mouth (anchor_081): x 242..257, z 92..107
- poi Siege Ramp Foot (anchor_082): x 774..789, z -124..-109
- poi No-Man's Orchard (anchor_083): x 1274..1289, z 76..91
- poi Bonerattle's Siege Halt (anchor_100): x 594..605, z -86..-75
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

No quest is given in this zone today.

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| carrion_crow | Carrion Crow | neutral | 100.0% of land, L41-50 | 100.0% of land, L41-50 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, snowblock … |
| hyena | Hyena | aggressive | 84.1% of land, L41-50 | 84.1% of land, L41-50 | dry_dirt_with_dry_grass, mesa_clay |
| mesa_golem | Mesa Golem | aggressive | 73.7% of land, L41-50 | 73.7% of land, L41-50 | stone, mesa_clay |
| scorpion | Scorpion | aggressive | - | 84.1% of land, L41-50 | dry_dirt_with_dry_grass, mesa_clay |
| skeleton_raider | Skeleton Raider | aggressive | - | 100.0% of land, L41-50 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| speargrass_tiger | Speargrass Tiger | aggressive | 84.1% of land, L41-50 | - | dry_dirt_with_dry_grass, mesa_clay |
| sun_dried_husk | Sun-Dried Husk | aggressive | - | 84.1% of land, L41-50 | dry_dirt_with_dry_grass, mesa_clay |
| vulture | Vulture | aggressive | 73.7% of land, L41-50 | - | mesa_clay |
| war_construct | War Construct | aggressive | 98.1% of land, L41-50 | 98.1% of land, L41-50 | dry_dirt_with_dry_grass, stone, mesa_clay, mud |

In the palette but no host ground in this zone: Crag Eagle, Mountain Ram.

**Rares (knowledge rewards, not quest targets):** Captain Bonerattle (skeleton_raider, the war coast, route 552,-104 → 616,-40 → 656,-96, L46, respawn 2-4 h)

## Roads and trails touching the zone

No road or trail.

