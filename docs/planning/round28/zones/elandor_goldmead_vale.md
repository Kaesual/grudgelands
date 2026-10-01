# Goldmead Vale (`elandor_goldmead_vale`)

Zone 7 · home zone 11-20 · accord · race region **human** · levels **11-20** · peaceful · relief `lowland` · seed 42

Map: [maps/elandor_goldmead_vale.png](maps/elandor_goldmead_vale.png). Machine-readable: [elandor_goldmead_vale.json](elandor_goldmead_vale.json). Coordinates are world nodes (x east, z north, y up).

Race track (human): step 2 of the track Dawnmere Fields → Goldmead Vale → Highcourt → Whitebridge Shire → Ashenward March.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -796..640, z -2344..-1656 (centroid -71, -2053) |
| Land area | 572272 nodes² (≈ 0.57 km²) |
| Hub point (authored) | 0, -2050 |
| Height above sea | min 0, p10 19, median 35, p90 65, max 119 |
| Slope | 2.6% steep (>1 node/node), 0.1% cliff (>2) |
| Biomes (measured) | meadows 68.7%, deep_forest 23.1%, swamp 8.0%, elf_forest 0.2% |
| Neighbours (land border) | elandor_dawnmere_fields (1484 nodes, mid -163,-2299), elandor_highcourt (1456 nodes, mid -24,-1812), elandor_lorindor (464 nodes, mid 565,-1796), elandor_whitebridge_shire (588 nodes, mid -665,-2031) |
| Sea coast | 596 nodes of coastline; sea-beach sand 16288 nodes²; lake/river-bank sand 9584 nodes² |
| Water inside | bay 21008 nodes², rivers/lakes 10288 nodes² |
| Protected / drift band | 2.0% of land protected (towns, villages, camps/POIs, road corridors); 6.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 502, -2058 | x 380..640, z -2200..-1940 | 14544 | L12-17 |
| B2 | -779, -2250 | x -796..-760, z -2284..-2212 | 1248 | L11-12 |
| B3 | -737, -2177 | x -748..-728, z -2188..-2164 | 400 | L12-13 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L11 12.1%, L12 10.8%, L13 11.1%, L14 12.2%, L15 12.6%, L16 12.1%, L17 9.5%, L18 8.3%, L19 5.9%, L20 5.3%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_015 | village | Goldmead Village | -120 | 37 | -2020 | 15 | village x -132..-109, z -2032..-2009 |
| anchor_029 | outpost | Goldmead Outpost | 176 | 53 | -2026 | 15 | poi x 168..183, z -2034..-2019 |
| anchor_051 | bandit camp | Goldmead Bandit Camp | 320 | 57 | -1980 | 16 | camp x 308..331, z -1992..-1969 |
| anchor_091 | rare route | Grimtusk's Rooting | 152 | 73 | -2116 | 14 | poi x 146..157, z -2122..-2111 |

## Protected areas

- village Goldmead Village (anchor_015): x -132..-109, z -2032..-2009
- poi Goldmead Outpost (anchor_029): x 168..183, z -2034..-2019
- camp Goldmead Bandit Camp (anchor_051): x 308..331, z -1992..-1969
- poi Grimtusk's Rooting (anchor_091): x 146..157, z -2122..-2111
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Goldmead Village (`goldmead_village`, anchor_015) at -120, 37, -2020

Residents/guards: idle 2, quest 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_steward | quest giver | Marta Millward | -118, 38, -2020 | r14_human_07_orchard_watch |
| quest_local | quest giver | Alda Sheaf | -122, 38, -2022 | r15_human_local_01, r15_human_local_02 |

Distances: zone edge N 136 (elandor_highcourt), S 304 (elandor_dawnmere_fields), E 700 (coastal_shelf), W 532 (elandor_whitebridge_shire); nearest other-zone land 136 N; sea 563 E; sea-beach sand 526 E; nearest road 16.
Nearest hubs (straight / by road): Highcourt 534 / 880; Goldmead Bandit Camp 442 / 1037; Goldmead Outpost 296 / 1076; Dawnmere 543 / 1576; Oakspan Tollhouse 904 / 1648.

### Goldmead Outpost (`goldmead_outpost`, anchor_029) at 176, 53, -2026

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_scout | quest giver | Jon Vale | 179, 54, -2029 | r14_human_08_empty_snares, r14_human_09_the_blackened_tally, r15_human_local_03, r15_human_local_04 |

Distances: zone edge N 208 (elandor_highcourt), S 260 (elandor_dawnmere_fields), E 400 (coastal_shelf), W 832 (elandor_whitebridge_shire); nearest other-zone land 194 N; sea 291 SE; sea-beach sand 242 E; nearest road 11.
Nearest hubs (straight / by road): Goldmead Bandit Camp 151 / 522; Dawnmere 553 / 686; Highcourt 555 / 866; Goldmead Village 296 / 1076; Oakspan Tollhouse 1099 / 1634.

### Goldmead Bandit Camp (`goldmead_bandit_camp`, anchor_051) at 320, 57, -1980

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_captive | quest giver | Pella Thatch | 330, 58, -1970 | r15_human_local_05, r15_human_local_06 |

Distances: zone edge N 204 (elandor_highcourt), S 224 (elandor_dawnmere_fields), E 312 (coastal_shelf), W 952 (elandor_whitebridge_shire); nearest other-zone land 188 NW; sea 206 SE; sea-beach sand 151 SE; nearest road 18.
Nearest hubs (straight / by road): Goldmead Outpost 151 / 522; Highcourt 577 / 828; Dawnmere 654 / 1022; Goldmead Village 442 / 1037; Oakspan Tollhouse 1179 / 1595.

### Current quests (9, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r14_human_07_orchard_watch | Orchard Watch | Marta Millward (Goldmead Village) | 10 | kill 6 fox [in elandor_goldmead_vale] | 380 | r14_human_06_flock_on_mill_road |
| r15_human_local_01 | Food for the Granary Crew | Alda Sheaf (Goldmead Village) | 10 | bring 4 mobs:meat_raw | 285 | r14_human_06_flock_on_mill_road |
| r15_human_local_02 | Apples for the Orchard Crew | Alda Sheaf (Goldmead Village) | 10 | bring 4 default:apple | 380 | r14_human_06_flock_on_mill_road |
| r14_human_08_empty_snares | Empty Snares | Jon Vale (Goldmead Outpost) | 11 | kill 6 poacher [in elandor_goldmead_vale] | 525 | r14_human_07_orchard_watch |
| r15_human_local_03 | Cloth from the Empty Snares | Jon Vale (Goldmead Outpost) | 11 | bring 3 grug_mobs:linen_cloth | 315 | r14_human_07_orchard_watch |
| r15_human_local_04 | A Clear Eastern View | Jon Vale (Goldmead Outpost) | 11 | kill 5 fox [in elandor_goldmead_vale] | 420 | r14_human_07_orchard_watch |
| r14_human_09_the_blackened_tally | The Blackened Tally | Jon Vale (Goldmead Outpost) | 12 | kill 4 bandit or bandit_archer [in elandor_goldmead_vale] | 805 | r14_human_08_empty_snares |
| r15_human_local_05 | The Millers' Missing Pay | Pella Thatch (Goldmead Bandit Camp) | 12 | bring 2 grug_mobs:stolen_purse | 460 | r14_human_08_empty_snares |
| r15_human_local_06 | Linen Around the Grain | Pella Thatch (Goldmead Bandit Camp) | 12 | bring 5 grug_mobs:linen_cloth | 575 | r14_human_08_empty_snares |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| boar | Boar | neutral | 100.0% of land, L11-20 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| fox | Fox | aggressive | 68.8% of land, L11-20 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_silver_litter |
| poacher | Poacher | aggressive | - | 91.5% of land, L11-20 | dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| rabbit | Rabbit | critter | 100.0% of land, L11-20 | - | dirt_with_coniferous_litter, dirt_with_grass, gravel, sand, snowblock, dirt_with_forest_litter … |
| shore_crab | Shore Crab | neutral | 16288 nodes², L11-17 | 16288 nodes², L11-17 | sand (dry, within 6 nodes of water) |
| wild_turkey | Wild Turkey | critter | 68.5% of land, L11-20 | - | dirt_with_grass |
| zombie | Zombie | aggressive | - | 100.0% of land, L11-20 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

**Camps and guard posts:**

- anchor_029 Goldmead Outpost at 176, -2026: guard post, guard_accord × 2-3, respawn 180-360 s, level there L15.
- anchor_051 Goldmead Bandit Camp at 320, -1980: bandit, bandit/bandit_archer × 3-5, respawn 120-300 s, level there L16.

**Rares (knowledge rewards, not quest targets):** Grimtusk (boar, the central meadows, route 104,-2140 → 168,-2076 → 208,-2132, L13, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 4 | primary | anchor_002 (Dawnmere, elandor_dawnmere_fields) | anchor_008 (Highcourt, elandor_highcourt) | 796 / 528 | -14,-2317 → 132,-1835 |
| 7 | secondary | anchor_015 (Goldmead Village, elandor_goldmead_vale) | anchor_008 (Highcourt, elandor_highcourt) | 277 / 134 | -115,-2005 → -158,-1886 |
| 34 | trail | anchor_029 (Goldmead Outpost, elandor_goldmead_vale) | joins road 4 | 83 / 84 | 166,-2030 → 88,-2012 |
| 51 | trail | anchor_051 (Goldmead Bandit Camp, elandor_goldmead_vale) | joins road 4 | 225 / 222 | 306,-1969 → 131,-1839 |
| 67 | trail | anchor_067 (Siltbasket Camp, elandor_whitebridge_shire) | joins road 7 | 500 / 380 | -511,-1827 → -160,-1920 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

