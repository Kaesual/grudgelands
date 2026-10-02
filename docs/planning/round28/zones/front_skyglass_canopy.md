# The Skyglass Canopy (`front_skyglass_canopy`)

Zone 37 · front zone · contested · race region **elf** · levels **51-60** · contested · relief `highland` · seed 42

Map: [maps/front_skyglass_canopy.png](maps/front_skyglass_canopy.png). Machine-readable: [front_skyglass_canopy.json](front_skyglass_canopy.json). Coordinates are world nodes (x east, z north, y up).

**Front:** Battlegrounds band around z = 0: Accord comes from -z (south), Throng from +z (north).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 1368..2616, z -372..472 (centroid 2024, 35) |
| Land area | 794704 nodes² (≈ 0.79 km²) |
| Hub point (authored) | 2000, 0 |
| Height above sea | min 0, p10 86, median 164, p90 221, max 288 |
| Slope | 44.6% steep (>1 node/node), 12.6% cliff (>2) |
| Biomes (measured) | jungle_fringe 77.2%, elf_forest 14.0%, deep_forest 7.6%, deep_jungle 0.7%, badlands 0.4%, badlands_east 0.2%, savanna 0.0% |
| Neighbours (land border) | elandor_glassroot_wilds (1268 nodes, mid 1940,-338), front_shattered_line (760 nodes, mid 1398,-13), kragmar_thunderroot_wilds (1324 nodes, mid 2056,422) |
| Sea coast | 1444 nodes of coastline; sea-beach sand 3840 nodes²; lake/river-bank sand 5600 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 72496 nodes² |
| Protected / drift band | 0.3% of land protected (towns, villages, camps/POIs, road corridors); 0.7% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 2513, -122 | x 2496..2536, z -180..-68 | 1936 | L54-57 |
| B2 | 2555, 104 | x 2544..2576, z 32..172 | 1504 | L56-60 |
| B3 | 2537, -322 | x 2528..2544, z -332..-308 | 256 | L51 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L51 15.8%, L52 10.8%, L53 9.3%, L54 9.8%, L55 8.5%, L56 10.0%, L57 9.1%, L58 8.2%, L59 9.5%, L60 9.0%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_084 | clash site | Skyroot Crossing | 1832 | 179 | -96 | 56 | poi x 1824..1839, z -104..-89 |
| anchor_085 | clash site | Cloudwatch Fall | 2176 | 212 | 104 | 58 | poi x 2168..2183, z 96..111 |
| anchor_094 | rare route | Silkfang's Loom | 2026 | 127 | 94 | 59 | poi x 2020..2031, z 88..99 |

## Protected areas

- poi Skyroot Crossing (anchor_084): x 1824..1839, z -104..-89
- poi Cloudwatch Fall (anchor_085): x 2168..2183, z 96..111
- poi Silkfang's Loom (anchor_094): x 2020..2031, z 88..99
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

No quest is given in this zone today.

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| glass_fang_serpent | Glass-Fang Serpent | aggressive | 40.7% of land, L54-60 | - |  |
| glass_knuckle_ape | Glass-Knuckle Jungle Ape | aggressive | 58.1% of land, L51-60 | - |  |
| glass_shadow_panther | Glass-Shadow Panther | aggressive | - | 58.1% of land, L51-60 |  |
| glass_web_spider | Glass-Web Jungle Spider | aggressive | - | 37.1% of land, L54-57 |  |
| last_pay_archer | Last-Pay Archer | aggressive | 1.1% of land, L58-60 | 1.1% of land, L58-60 |  |
| last_watch_husk | Last-Watch Mummy | aggressive | 30.0% of land, L58-60 | 1.1% of land, L58-60 |  |
| last_watch_skeleton_raider | Last-Watch Skeleton Raider | aggressive | - | 40.7% of land, L54-60 |  |
| last_watch_zombie | Last Watchman | aggressive | - | 28.9% of land, L58-60 |  |
| reef_lurker | Reef Lurker | neutral | 3840 nodes², L51-60 | 3840 nodes², L51-60 | sand (dry, within 6 nodes of water) |
| saltbound_husk | Saltbound Sun-Dried Husk | aggressive | 37.1% of land, L54-55 | - |  |
| saltbound_zombie | Saltbound Zombie | aggressive | - | 32.9% of land, L51-55 |  |
| saltroad_deserter | Saltroad Deserter | aggressive | 30.3% of land, L51-53 | - |  |
| watchful_carrion_crow | Battlefield Crow | neutral | 2.6% of land, L54-57 | - |  |

**Rares (knowledge rewards, not quest targets):** Silkfang (jungle_spider, the jungle fringe, route 1978,70 → 2042,134 → 2082,78, L59, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 61 | trail | anchor_060 (Rainchar Camp, kragmar_thunderroot_wilds) | joins road 28 | 891 / 190 | 1915,410 → 2017,417 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

