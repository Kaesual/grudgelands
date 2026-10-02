# The Broken Causeway (`front_broken_causeway`)

Zone 35 · front zone · contested · race region **human** · levels **41-50** · contested · relief `wetland_delta` · seed 42

Map: [maps/front_broken_causeway.png](maps/front_broken_causeway.png). Machine-readable: [front_broken_causeway.json](front_broken_causeway.json). Coordinates are world nodes (x east, z north, y up).

**Front:** Battlegrounds band around z = 0: Accord comes from -z (south), Throng from +z (north).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -1488..20, z -532..460 (centroid -754, -2) |
| Land area | 746608 nodes² (≈ 0.75 km²) |
| Hub point (authored) | -750, 0 |
| Height above sea | min 22, p10 34, median 69, p90 151, max 403 |
| Slope | 12.1% steep (>1 node/node), 2.2% cliff (>2) |
| Biomes (measured) | swamp 43.2%, meadows 35.1%, deep_forest 19.6%, badlands 0.7%, bone_forest 0.5%, crags 0.5%, savanna 0.2%, blight 0.2%, beach 0.0% |
| Neighbours (land border) | elandor_ashenward_march (1412 nodes, mid -479,-274), elandor_stormvault_heights (1008 nodes, mid -1161,-326), front_gravesalt_escarpment (764 nodes, mid -1390,-4), front_shattered_line (524 nodes, mid 5,124), kragmar_bannerbreak_mesa (1456 nodes, mid -474,293), kragmar_blackwind_rise (568 nodes, mid -1107,381) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 22048 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 65760 nodes² |
| Protected / drift band | 0.6% of land protected (towns, villages, camps/POIs, road corridors); 2.5% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 9.0%, L32 5.5%, L33 8.0%, L34 10.7%, L35 13.8%, L36 12.2%, L37 9.9%, L38 10.5%, L39 10.8%, L40 9.6%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_078 | clash site | Causeway Toll Ruin | -1274 | 129 | -76 | 38 | poi x -1282..-1267, z -84..-69 |
| anchor_079 | clash site | Fordward Wreck | -774 | 37 | 124 | 36 | poi x -782..-767, z 116..131 |
| anchor_080 | clash site | Aqueduct Last Step | -274 | 65 | -76 | 38 | poi x -282..-267, z -84..-69 |
| anchor_099 | rare route | Bonerattle's Broken Toll | -568 | 36 | 64 | 38 | poi x -574..-563, z 58..69 |

## Protected areas

- poi Causeway Toll Ruin (anchor_078): x -1282..-1267, z -84..-69
- poi Fordward Wreck (anchor_079): x -782..-767, z 116..131
- poi Aqueduct Last Step (anchor_080): x -282..-267, z -84..-69
- poi Bonerattle's Broken Toll (anchor_099): x -574..-563, z 58..69
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

No quest is given in this zone today.

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bog_witch | Bog Witch | aggressive | - | 43.8% of land, L31-40 | dirt_with_rainforest_litter, dirt_with_bone_litter, dirt_with_canopy_litter, mud |
| carrion_crow | Carrion Crow | neutral | 100.0% of land, L31-40 | 100.0% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, snowblock … |
| gull | Gull | critter | 192 nodes² | - | sand |
| skeleton_raider | Skeleton Raider | aggressive | - | 100.0% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| war_construct | War Construct | aggressive | 44.3% of land, L31-40 | 44.3% of land, L31-40 | dry_dirt_with_dry_grass, stone, mesa_clay, mud |
| wisp | Wisp | aggressive | - | 63.7% of land, L31-40 | dirt_with_rainforest_litter, dirt_with_bone_litter, dirt_with_canopy_litter, dirt_with_forest_litter, dirt_with_silver_litter, mud |
| zombie | Zombie | aggressive | 0.1% of land, L32 | 99.5% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

**Rares (knowledge rewards, not quest targets):** Captain Bonerattle (skeleton_raider, the war coast, route -616,40 → -552,104 → -512,48, L39, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 33 | trail | anchor_028 (Archshadow Post, elandor_stormvault_heights) | joins road 13 | 1729 / 620 | -1230,-221 → -670,-306 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

