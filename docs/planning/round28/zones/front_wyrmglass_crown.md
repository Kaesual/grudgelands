# The Wyrmglass Crown (`front_wyrmglass_crown`)

Zone 33 · dragon island (60) · contested · race region **dwarf** · levels **60-60** · contested · relief `mountain` · seed 42

Map: [maps/front_wyrmglass_crown.png](maps/front_wyrmglass_crown.png). Machine-readable: [front_wyrmglass_crown.json](front_wyrmglass_crown.json). Coordinates are world nodes (x east, z north, y up).

**Front:** Offshore dragon island, reached by boat from the Battlegrounds end zone (no land neighbours, no roads).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -3404..-2880, z -292..292 (centroid -3125, -12) |
| Land area | 223168 nodes² (≈ 0.22 km²) |
| Hub point (authored) | -3150, 0 |
| Height above sea | min 0, p10 108, median 279, p90 382, max 506 |
| Slope | 81.1% steep (>1 node/node), 62.3% cliff (>2) |
| Biomes (measured) | crags 51.3%, crags_snowy 32.8%, beach 15.9% |
| Neighbours (land border) | none |
| Sea coast | 2296 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 0 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 8064 nodes² |
| Protected / drift band | 1.3% of land protected (towns, villages, camps/POIs, road corridors); 0.0% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Flat level 60.

Share of land per level: L60 100.0%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_075 | clash site | Crystal Landing Scar | -3024 | 377 | 194 | 60 | poi x -3032..-3017, z 186..201 |
| anchor_087 | dragon arena | Wyrmglass Dragonspire | -3260 | 326 | -40 | 60 | poi x -3276..-3245, z -56..-25 |
| anchor_089 | apex mine camp | Wyrmglass Fault Camp | -3200 | 183 | 80 | 60 | poi x -3216..-3185, z 64..95 |

## Protected areas

- poi Crystal Landing Scar (anchor_075): x -3032..-3017, z 186..201
- poi Wyrmglass Dragonspire (anchor_087): x -3276..-3245, z -56..-25
- poi Wyrmglass Fault Camp (anchor_089): x -3216..-3185, z 64..95
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

No quest is given in this zone today.

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| carrion_crow | Carrion Crow | neutral | 85.0% of land, L60 | 85.0% of land, L60 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, snowblock … |
| crag_eagle | Crag Eagle | aggressive | 85.0% of land, L60 | - | gravel, snowblock |
| frost_stray | Frost Stray | aggressive | - | 85.0% of land, L60 | gravel, snowblock |
| gull | Gull | critter | 35456 nodes² | - | sand |
| mountain_ram | Mountain Ram | neutral | 85.0% of land, L60 | - | gravel, snowblock |
| rift_spawn | Rift Spawn | aggressive | - | 85.0% of land, L60 | dirt_with_rainforest_litter, gravel, snowblock, dirt_with_bone_litter, dirt_with_canopy_litter |
| snow_leopard | Snow Leopard | aggressive | - | 85.0% of land, L60 | gravel, snowblock |
| stone_golem | Stone Golem | aggressive | 85.0% of land, L60 | 85.0% of land, L60 | gravel, snowblock, stone |
| zombie | Zombie | aggressive | - | 100.0% of land, L60 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

In the palette but no host ground in this zone: Hyena, Vulture.

## Roads and trails touching the zone

No road or trail.

