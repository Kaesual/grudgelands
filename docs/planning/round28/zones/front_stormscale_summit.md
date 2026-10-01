# Stormscale Summit (`front_stormscale_summit`)

Zone 38 · dragon island (60) · contested · race region **troll** · levels **60-60** · contested · relief `mountain` · seed 42

Map: [maps/front_stormscale_summit.png](maps/front_stormscale_summit.png). Machine-readable: [front_stormscale_summit.json](front_stormscale_summit.json). Coordinates are world nodes (x east, z north, y up).

**Front:** Offshore dragon island, reached by boat from the Battlegrounds end zone (no land neighbours, no roads).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 2880..3404, z -316..296 (centroid 3135, -14) |
| Land area | 216480 nodes² (≈ 0.22 km²) |
| Hub point (authored) | 3150, 0 |
| Height above sea | min 0, p10 57, median 193, p90 235, max 309 |
| Slope | 67.6% steep (>1 node/node), 35.1% cliff (>2) |
| Biomes (measured) | deep_jungle 56.7%, badlands_east 22.1%, beach 15.7%, swamp 5.5% |
| Neighbours (land border) | none |
| Sea coast | 2368 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 0 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 19040 nodes² |
| Protected / drift band | 1.5% of land protected (towns, villages, camps/POIs, road corridors); 0.0% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Flat level 60.

Share of land per level: L60 100.0%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_086 | clash site | Thunder Shore Wreck | 3000 | 152 | 170 | 60 | poi x 2992..3007, z 162..177 |
| anchor_088 | dragon arena | Stormscale Dragonroost | 3260 | 222 | -40 | 60 | poi x 3244..3275, z -56..-25 |
| anchor_090 | apex mine camp | Stormscale Gem Camp | 3200 | 217 | 80 | 60 | poi x 3184..3215, z 64..95 |
| anchor_097 | rare route | Emerald Coil's Hollow | 3000 | 309 | -120 | 60 | poi x 2994..3005, z -126..-115 |

## Protected areas

- poi Thunder Shore Wreck (anchor_086): x 2992..3007, z 162..177
- poi Stormscale Dragonroost (anchor_088): x 3244..3275, z -56..-25
- poi Stormscale Gem Camp (anchor_090): x 3184..3215, z 64..95
- poi Emerald Coil's Hollow (anchor_097): x 2994..3005, z -126..-115
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

No quest is given in this zone today.

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bog_witch | Bog Witch | aggressive | - | 63.5% of land, L60 | dirt_with_rainforest_litter, dirt_with_bone_litter, dirt_with_canopy_litter, mud |
| carrion_crow | Carrion Crow | neutral | 86.8% of land, L60 | 86.8% of land, L60 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, snowblock … |
| gull | Gull | critter | 33888 nodes² | - | sand |
| jungle_ape | Jungle Ape | aggressive | 57.4% of land, L60 | - | dirt_with_rainforest_litter, dirt_with_canopy_litter |
| jungle_spider | Jungle Spider | aggressive | - | 57.4% of land, L60 | dirt_with_rainforest_litter, dirt_with_canopy_litter, dirt_with_forest_litter, dirt_with_silver_litter |
| panther | Panther | aggressive | - | 57.4% of land, L60 | dirt_with_rainforest_litter, dirt_with_canopy_litter |
| rift_spawn | Rift Spawn | aggressive | - | 57.4% of land, L60 | dirt_with_rainforest_litter, gravel, snowblock, dirt_with_bone_litter, dirt_with_canopy_litter |
| serpent | Serpent | aggressive | 63.5% of land, L60 | - | dirt_with_rainforest_litter, dirt_with_canopy_litter, mud |
| skeleton_raider | Skeleton Raider | aggressive | - | 100.0% of land, L60 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| zombie | Zombie | aggressive | - | 100.0% of land, L60 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

**Rares (knowledge rewards, not quest targets):** Emerald Coil (serpent, the deep jungle, route 2952,-144 → 3016,-80 → 3056,-136, L60, respawn 2-4 h)

## Roads and trails touching the zone

No road or trail.

