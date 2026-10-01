# Bannerbreak Mesa (`kragmar_bannerbreak_mesa`)

Zone 26 · contested 31-40 · contested · race region **orc** · levels **31-40** · contested · relief `plateau` · seed 42

Map: [maps/kragmar_bannerbreak_mesa.png](maps/kragmar_bannerbreak_mesa.png). Machine-readable: [kragmar_bannerbreak_mesa.json](kragmar_bannerbreak_mesa.json). Coordinates are world nodes (x east, z north, y up).

Race track (orc): step 5 of the track Sunscar Flats → Redtusk Savanna → Gor Drazhak → Speargrass Reach → Bannerbreak Mesa.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -940..1060, z 208..1184 (centroid 52, 670) |
| Land area | 1482112 nodes² (≈ 1.48 km²) |
| Hub point (authored) | 0, 700 |
| Height above sea | min 28, p10 72, median 100, p90 137, max 350 |
| Slope | 11.8% steep (>1 node/node), 1.2% cliff (>2) |
| Biomes (measured) | badlands 66.7%, savanna 23.4%, swamp 9.3%, meadows 0.2%, bone_forest 0.2%, deep_jungle 0.1%, deep_forest 0.0%, jungle_edge 0.0% |
| Neighbours (land border) | front_broken_causeway (1472 nodes, mid -474,287), front_shattered_line (1432 nodes, mid 503,276), kragmar_blackwind_rise (576 nodes, mid -919,693), kragmar_gor_drazhak (1212 nodes, mid 9,1106), kragmar_speargrass_reach (660 nodes, mid -707,1011), kragmar_thunderroot_wilds (844 nodes, mid 988,606), kragmar_whispering_reedlands (664 nodes, mid 703,1074) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 9968 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 17776 nodes² |
| Protected / drift band | 1.2% of land protected (towns, villages, camps/POIs, road corridors); 5.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 10.0%, L32 10.6%, L33 10.4%, L34 11.3%, L35 11.6%, L36 11.2%, L37 8.8%, L38 8.8%, L39 8.4%, L40 8.9%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_043 | outpost | Red Ramp Post | -374 | 78 | 874 | 33 | poi x -382..-367, z 866..881 |
| anchor_044 | outpost | Tornstandard Hold | 276 | 110 | 474 | 38 | poi x 268..283, z 466..481 |
| anchor_058 | bandit hideout | Sunderstrap Camp | 32 | 90 | 414 | 38 | camp x 24..39, z 406..421 |
| anchor_073 | clash site | Redcut Breach | -218 | 45 | 304 | 40 | poi x -226..-211, z 296..311 |
| anchor_074 | clash site | Bannerfall Pocket | 282 | 135 | 304 | 40 | poi x 274..289, z 296..311 |
| anchor_096 | rare route | Dustwing's Perch | 156 | 128 | 674 | 35 | poi x 150..161, z 668..679 |

## Protected areas

- poi Red Ramp Post (anchor_043): x -382..-367, z 866..881
- poi Tornstandard Hold (anchor_044): x 268..283, z 466..481
- camp Sunderstrap Camp (anchor_058): x 24..39, z 406..421
- poi Redcut Breach (anchor_073): x -226..-211, z 296..311
- poi Bannerfall Pocket (anchor_074): x 274..289, z 296..311
- poi Dustwing's Perch (anchor_096): x 150..161, z 668..679
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Red Ramp Post (`r20_anchor_043`, anchor_043) at -374, 78, 874

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Drek Rampbinder | -372, 79, 874 | r20_anchor_043_01, r20_anchor_043_02, r20_anchor_043_03 |

Distances: zone edge N 236 (kragmar_gor_drazhak), S 584 (front_broken_causeway), E 1292 (kragmar_thunderroot_wilds), W 552 (kragmar_blackwind_rise); nearest other-zone land 238 N; sea 1207 NW; sea-beach sand 1170 NW; nearest road 13.
Nearest hubs (straight / by road): Tornstandard Hold 763 / 965; Hollowarch Station 1179 / 1512; Last Hedge Redoubt 1486 / no road; Cinderline Watch 1724 / no road; Archshadow Post 1738 / no road.

### Tornstandard Hold (`r20_anchor_044`, anchor_044) at 276, 110, 474

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Yarra Standardmender | 278, 111, 474 | r20_anchor_044_01, r20_anchor_044_02, r20_anchor_044_03 |

Distances: zone edge N 636 (kragmar_gor_drazhak), S 240 (front_shattered_line), E 760 (kragmar_thunderroot_wilds), W 1184 (kragmar_blackwind_rise); nearest other-zone land 188 SW; sea 1591 N; sea-beach sand 1550 NE; nearest road 13.
Nearest hubs (straight / by road): Red Ramp Post 763 / 965; Last Hedge Redoubt 924 / no road; Cinderline Watch 1465 / no road; Hollowarch Station 1744 / 2348; Glassroot Gate 1955 / no road.

### Current quests (6, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_043_01 | Planks for the Ascent | Drek Rampbinder (Red Ramp Post) | 31 | bring 10 default:acacia_wood | 1220 | - |
| r20_anchor_043_02 | Shells Among the Planks | Drek Rampbinder (Red Ramp Post) | 31 | kill 4 scorpion [in kragmar_bannerbreak_mesa] | 1220 | - |
| r20_anchor_044_01 | A Standard Needs a Footing | Yarra Standardmender (Tornstandard Hold) | 31 | bring 8 default:cobble | 1220 | - |
| r20_anchor_044_02 | The Empty Mesa Patrol | Yarra Standardmender (Tornstandard Hold) | 31 | kill 4 skeleton_raider [in kragmar_bannerbreak_mesa] | 1220 | - |
| r20_anchor_043_03 | Sunderstrap's Sentinels | Drek Rampbinder (Red Ramp Post) | 33 | kill 4 bandit_archer [in kragmar_bannerbreak_mesa] | 1300 | r20_anchor_043_02 |
| r20_anchor_044_03 | The Last Hedge Abroad | Yarra Standardmender (Tornstandard Hold) | 40 | kill 3 guard_accord [in elandor_ashenward_march] | 1975 | r20_anchor_044_02 |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| carrion_crow | Carrion Crow | neutral | 100.0% of land, L31-40 | 100.0% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, snowblock … |
| goblin_hound | Goblin Raider Hound | aggressive | - | 90.1% of land, L31-40 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| goblin_raider | Goblin Raider | aggressive | - | 90.1% of land, L31-40 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| goblin_slinger | Goblin Slinger | aggressive | - | 90.1% of land, L31-40 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| hyena | Hyena | aggressive | 90.1% of land, L31-40 | 90.1% of land, L31-40 | dry_dirt_with_dry_grass, mesa_clay |
| mesa_golem | Mesa Golem | aggressive | 67.1% of land, L31-40 | 67.1% of land, L31-40 | stone, mesa_clay |
| scorpion | Scorpion | aggressive | - | 90.1% of land, L31-40 | dry_dirt_with_dry_grass, mesa_clay |
| skeleton_raider | Skeleton Raider | aggressive | - | 100.0% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| vulture | Vulture | aggressive | 67.1% of land, L31-40 | - | mesa_clay |
| zombie | Zombie | aggressive | - | 99.9% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

In the palette but no host ground in this zone: Crag Eagle, Mountain Ram.

**Camps and guard posts:**

- anchor_043 Red Ramp Post at -374, 874: guard post, guard_throng × 2-3, respawn 180-360 s, level there L33.
- anchor_044 Tornstandard Hold at 276, 474: guard post, guard_throng × 2-3, respawn 180-360 s, level there L38.
- anchor_058 Sunderstrap Camp at 32, 414: bandit, bandit/bandit_archer × 3-5, respawn 120-300 s, level there L38.

**Rares (knowledge rewards, not quest targets):** Dustwing (vulture, the badlands, route 108,650 → 172,714 → 212,658, L35, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 27 | secondary | anchor_043 (Red Ramp Post, kragmar_bannerbreak_mesa) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 390 / 262 | -367,885 → -291,1116 |
| 42 | trail | anchor_040 (Hollowarch Station, kragmar_blackwind_rise) | joins road 27 | 1438 / 824 | -906,485 → -336,928 |
| 45 | trail | anchor_044 (Tornstandard Hold, kragmar_bannerbreak_mesa) | joins road 27 | 806 / 794 | 270,485 → -294,995 |
| 58 | trail | anchor_058 (Sunderstrap Camp, kragmar_bannerbreak_mesa) | joins road 27 | 1283 / 1076 | 42,420 → -259,1106 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

