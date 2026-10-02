# Gravesalt Escarpment (`front_gravesalt_escarpment`)

Zone 34 · front zone · contested · race region **undead** · levels **51-60** · contested · relief `highland` · seed 42

Map: [maps/front_gravesalt_escarpment.png](maps/front_gravesalt_escarpment.png). Machine-readable: [front_gravesalt_escarpment.json](front_gravesalt_escarpment.json). Coordinates are world nodes (x east, z north, y up).

**Front:** Battlegrounds band around z = 0: Accord comes from -z (south), Throng from +z (north).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2528..-1300, z -308..288 (centroid -1985, -24) |
| Land area | 404320 nodes² (≈ 0.40 km²) |
| Hub point (authored) | -2000, 0 |
| Height above sea | min 0, p10 76, median 177, p90 272, max 372 |
| Slope | 67.6% steep (>1 node/node), 27.8% cliff (>2) |
| Biomes (measured) | bone_forest 52.9%, swamp 18.3%, blight 16.9%, beach 10.5%, meadows 0.7%, crags 0.6%, deep_forest 0.1%, crags_snowy 0.1% |
| Neighbours (land border) | elandor_stormvault_heights (636 nodes, mid -2055,-294), front_broken_causeway (764 nodes, mid -1385,-3), kragmar_blackwind_rise (1636 nodes, mid -1879,177) |
| Sea coast | 852 nodes of coastline; sea-beach sand 2368 nodes²; lake/river-bank sand 1312 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 97856 nodes² |
| Protected / drift band | 0.2% of land protected (towns, villages, camps/POIs, road corridors); 0.0% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -2439, -189 | x -2480..-2396, z -216..-168 | 1248 | L53-55 |
| B2 | -2496, 100 | x -2512..-2484, z 60..140 | 896 | L52-55 |
| B3 | -2406, -239 | x -2416..-2392, z -248..-224 | 192 | L52-53 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L51 9.9%, L52 8.0%, L53 7.6%, L54 10.1%, L55 11.3%, L56 10.3%, L57 13.5%, L58 15.0%, L59 14.2%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_076 | clash site | Saltgate Remnant | -2200 | 107 | -80 | 58 | poi x -2208..-2193, z -88..-73 |
| anchor_077 | clash site | Tombroad Ambush | -1768 | 132 | 64 | 55 | poi x -1776..-1761, z 56..71 |

## Protected areas

- poi Saltgate Remnant (anchor_076): x -2208..-2193, z -88..-73
- poi Tombroad Ambush (anchor_077): x -1776..-1761, z 56..71
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

No quest is given in this zone today.

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bear | Bear | aggressive | 1.3% of land, L51-58 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| blightfang_wolf | Blightfang Wolf | aggressive | 52.7% of land, L51-59 | 52.7% of land, L51-59 | dirt_with_bone_litter |
| bog_witch | Bog Witch | aggressive | - | 71.4% of land, L51-59 | dirt_with_rainforest_litter, dirt_with_bone_litter, dirt_with_canopy_litter, mud |
| bone_weevil | Bone Weevil | critter | 71.0% of land, L51-59 | - | blight_dirt, dirt_with_bone_litter |
| carrion_crow | Carrion Crow | neutral | 91.5% of land, L51-59 | 91.5% of land, L51-59 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, snowblock … |
| gaunt_stag | Gaunt Stag | neutral | 52.7% of land, L51-59 | - | dirt_with_bone_litter |
| giant_spider | Giant Spider | aggressive | - | 1.3% of land, L51-58 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| gull | Gull | critter | 42432 nodes² | - | sand |
| pale_spider | Bonelurker Spider | aggressive | - | 71.0% of land, L51-59 | dry_dirt_with_dry_grass, blight_dirt, dirt_with_bone_litter |
| plaguehide_bear | Plaguehide Bear | aggressive | 71.0% of land, L51-59 | - | dry_dirt_with_dry_grass, blight_dirt, dirt_with_bone_litter |
| reef_lurker | Reef Lurker | neutral | 2368 nodes², L52-55 | 2368 nodes², L52-55 | sand (dry, within 6 nodes of water) |
| rift_spawn | Rift Spawn | aggressive | - | 53.3% of land, L51-59 | dirt_with_rainforest_litter, gravel, snowblock, dirt_with_bone_litter, dirt_with_canopy_litter |
| skeleton_raider | Skeleton Raider | aggressive | - | 100.0% of land, L51-59 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| stag | Stag | neutral | 1.3% of land, L51-58 | - | dirt_with_grass, dirt_with_forest_litter |
| wolf | Wolf | aggressive | 1.3% of land, L51-58 | 1.3% of land, L51-58 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter |
| zombie | Zombie | aggressive | 18.3% of land, L51-59 | 47.3% of land, L51-59 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

## Roads and trails touching the zone

No road or trail.

