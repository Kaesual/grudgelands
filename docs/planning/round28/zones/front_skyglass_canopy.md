# The Skyglass Canopy (`front_skyglass_canopy`)

Zone 37 · front zone · contested · race region **elf** · levels **51-59** · contested · relief `highland` · seed 42

Map: [maps/front_skyglass_canopy.png](maps/front_skyglass_canopy.png). Machine-readable: [front_skyglass_canopy.json](front_skyglass_canopy.json). Coordinates are world nodes (x east, z north, y up).

**Front:** Battlegrounds band around z = 0: Accord comes from -z (south), Throng from +z (north).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 1368..2600, z -264..340 (centroid 2015, 31) |
| Land area | 563648 nodes² (≈ 0.56 km²) |
| Hub point (authored) | 2000, 0 |
| Height above sea | min 0, p10 85, median 160, p90 215, max 287 |
| Slope | 44.1% steep (>1 node/node), 12.0% cliff (>2) |
| Biomes (measured) | jungle_fringe 71.3%, elf_forest 18.6%, deep_forest 8.9%, deep_jungle 0.5%, badlands 0.4%, swamp 0.2%, badlands_east 0.1%, savanna 0.0% |
| Neighbours (land border) | elandor_glassroot_wilds (1292 nodes, mid 2053,-236), front_shattered_line (636 nodes, mid 1397,24), kragmar_thunderroot_wilds (1016 nodes, mid 2165,311) |
| Sea coast | 984 nodes of coastline; sea-beach sand 3568 nodes²; lake/river-bank sand 2608 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 60384 nodes² |
| Protected / drift band | 0.2% of land protected (towns, villages, camps/POIs, road corridors); 0.0% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 2513, -122 | x 2492..2536, z -180..-68 | 1952 | L52-56 |
| B2 | 2555, 104 | x 2544..2576, z 32..172 | 1536 | L55-59 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L51 12.4%, L52 8.7%, L53 9.1%, L54 10.9%, L55 10.1%, L56 11.2%, L57 13.2%, L58 11.8%, L59 12.7%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_084 | clash site | Skyroot Crossing | 1832 | 179 | -96 | 55 | poi x 1824..1839, z -104..-89 |
| anchor_085 | clash site | Cloudwatch Fall | 2176 | 207 | 104 | 57 | poi x 2168..2183, z 96..111 |
| anchor_094 | rare route | Silkfang's Loom | 2026 | 126 | 94 | 58 | poi x 2020..2031, z 88..99 |

## Protected areas

- poi Skyroot Crossing (anchor_084): x 1824..1839, z -104..-89
- poi Cloudwatch Fall (anchor_085): x 2168..2183, z 96..111
- poi Silkfang's Loom (anchor_094): x 2020..2031, z 88..99
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

No quest is given in this zone today.

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| carrion_crow | Carrion Crow | neutral | 100.0% of land, L51-59 | 100.0% of land, L51-59 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, snowblock … |
| jungle_ape | Jungle Ape | aggressive | 71.9% of land, L51-59 | - | dirt_with_rainforest_litter, dirt_with_canopy_litter |
| jungle_spider | Jungle Spider | aggressive | - | 99.2% of land, L51-59 | dirt_with_rainforest_litter, dirt_with_canopy_litter, dirt_with_forest_litter, dirt_with_silver_litter |
| panther | Panther | aggressive | - | 71.9% of land, L51-59 | dirt_with_rainforest_litter, dirt_with_canopy_litter |
| reef_lurker | Reef Lurker | neutral | 3568 nodes², L52-59 | 3568 nodes², L52-59 | sand (dry, within 6 nodes of water) |
| rift_spawn | Rift Spawn | aggressive | - | 71.9% of land, L51-59 | dirt_with_rainforest_litter, gravel, snowblock, dirt_with_bone_litter, dirt_with_canopy_litter |
| serpent | Serpent | aggressive | 72.1% of land, L51-59 | - | dirt_with_rainforest_litter, dirt_with_canopy_litter, mud |
| skeleton_raider | Skeleton Raider | aggressive | - | 100.0% of land, L51-59 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| zombie | Zombie | aggressive | - | 100.0% of land, L51-59 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

**Rares (knowledge rewards, not quest targets):** Silkfang (jungle_spider, the jungle fringe, route 1978,70 → 2042,134 → 2082,78, L58, respawn 2-4 h)

## Roads and trails touching the zone

No road or trail.

