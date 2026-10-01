# Starbough Vale (`elandor_starbough_vale`)

Zone 12 · home zone 11-20 · accord · race region **elf** · levels **11-20** · peaceful · relief `rolling_hills` · seed 42

Map: [maps/elandor_starbough_vale.png](maps/elandor_starbough_vale.png). Machine-readable: [elandor_starbough_vale.json](elandor_starbough_vale.json). Coordinates are world nodes (x east, z north, y up).

Race track (elf): step 2 of the track Silverleaf Glades → Starbough Vale → Lethariel → Lorindor → Moonfall Wood → Glassroot Wilds.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 1148..2444, z -2384..-1688 (centroid 1754, -2095) |
| Land area | 443120 nodes² (≈ 0.44 km²) |
| Hub point (authored) | 1800, -2050 |
| Height above sea | min -1, p10 19, median 72, p90 109, max 138 |
| Slope | 4.1% steep (>1 node/node), 0.4% cliff (>2) |
| Biomes (measured) | elf_forest 76.6%, deep_forest 23.3%, swamp 0.1% |
| Neighbours (land border) | elandor_lethariel (1188 nodes, mid 1795,-1872), elandor_lorindor (412 nodes, mid 1276,-1784), elandor_moonfall_wood (536 nodes, mid 2315,-2198), elandor_silverleaf_glades (1468 nodes, mid 1870,-2322) |
| Sea coast | 1128 nodes of coastline; sea-beach sand 9232 nodes²; lake/river-bank sand 2880 nodes² |
| Water inside | bay 112656 nodes², rivers/lakes 9024 nodes² |
| Protected / drift band | 2.1% of land protected (towns, villages, camps/POIs, road corridors); 7.0% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 1345, -2045 | x 1232..1416, z -2104..-1960 | 6976 | L14-17 |
| B2 | 1355, -2245 | x 1324..1388, z -2276..-2216 | 1344 | L11-12 |
| B3 | 1369, -1914 | x 1368..1372, z -1928..-1896 | 208 | L17-18 |
| B4 | 1312, -2247 | x 1308..1320, z -2256..-2236 | 144 | L12 |
| B5 | 1395, -1938 | x 1392..1400, z -1952..-1928 | 128 | L17 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L11 11.9%, L12 14.5%, L13 14.1%, L14 14.7%, L15 12.6%, L16 11.8%, L17 6.8%, L18 5.1%, L19 3.8%, L20 4.7%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_017 | village | Starbough Village | 1900 | 129 | -2020 | 16 | village x 1888..1911, z -2032..-2009 |
| anchor_033 | outpost | Starbough Outpost | 2100 | 98 | -2100 | 14 | poi x 2092..2107, z -2108..-2093 |
| anchor_053 | bandit camp | Starbough Bandit Camp | 1632 | 103 | -2066 | 15 | camp x 1620..1643, z -2078..-2055 |

## Protected areas

- village Starbough Village (anchor_017): x 1888..1911, z -2032..-2009
- poi Starbough Outpost (anchor_033): x 2092..2107, z -2108..-2093
- camp Starbough Bandit Camp (anchor_053): x 1620..1643, z -2078..-2055
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Starbough Village (`starbough_village`, anchor_017) at 1900, 129, -2020

Residents/guards: idle 2, quest 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_steward | quest giver | Ilyra Mossveil | 1902, 130, -2020 | r14_elf_07_quiet_the_lower_boughs |
| quest_local | quest giver | Lethri Reedshade | 1898, 130, -2022 | r15_elf_local_01, r15_elf_local_02 |

Distances: zone edge N 84 (elandor_lethariel), S 272 (elandor_silverleaf_glades), E 312 (elandor_lethariel), W 532 (coastal_shelf); nearest other-zone land 84 N; sea 528 W; sea-beach sand 485 W; nearest road 21.
Nearest hubs (straight / by road): Starbough Bandit Camp 272 / 467; Starbough Outpost 215 / 583; Silverleaf 539 / 696; Lethariel 530 / 812; Paleroot Cutting 1161 / 1699.

### Starbough Outpost (`starbough_outpost`, anchor_033) at 2100, 98, -2100

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_scout | quest giver | Theren Farstep | 2103, 99, -2103 | r14_elf_08_watch_the_green_road, r14_elf_09_cinders_in_green_cloth, r15_elf_local_03, r15_elf_local_04 |

Distances: zone edge N 180 (elandor_lethariel), S 252 (elandor_silverleaf_glades), E 156 (elandor_moonfall_wood), W 860 (bay_water); nearest other-zone land 131 NE; sea 459 E; sea-beach sand 437 E; nearest road 14.
Nearest hubs (straight / by road): Starbough Village 215 / 583; Silverleaf 541 / 774; Starbough Bandit Camp 469 / 831; Lethariel 671 / 1176; Paleroot Cutting 1366 / 2063.

### Starbough Bandit Camp (`starbough_bandit_camp`, anchor_053) at 1632, 103, -2066

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_captive | quest giver | Nima Fern | 1642, 104, -2056 | r15_elf_local_05, r15_elf_local_06 |

Distances: zone edge N 232 (elandor_lethariel), S 252 (elandor_silverleaf_glades), E 612 (elandor_moonfall_wood), W 284 (coastal_shelf); nearest other-zone land 204 NE; sea 261 W; sea-beach sand 217 W; nearest road 17.
Nearest hubs (straight / by road): Starbough Village 272 / 467; Starbough Outpost 469 / 831; Lethariel 590 / 889; Silverleaf 512 / 944; Paleroot Cutting 1012 / 1775.

### Current quests (9, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r14_elf_07_quiet_the_lower_boughs | Quiet the Lower Boughs | Ilyra Mossveil (Starbough Village) | 10 | kill 6 poacher [in elandor_starbough_vale] | 380 | r14_elf_06_axes_without_leave |
| r15_elf_local_01 | Leather for the Covered Walk | Lethri Reedshade (Starbough Village) | 10 | bring 2 mobs:leather | 285 | r14_elf_06_axes_without_leave |
| r15_elf_local_02 | Linen at the Sapling Cuts | Lethri Reedshade (Starbough Village) | 10 | bring 3 grug_mobs:linen_cloth | 380 | r14_elf_06_axes_without_leave |
| r14_elf_08_watch_the_green_road | Watch the Green Road | Theren Farstep (Starbough Outpost) | 11 | kill 6 fox [in elandor_starbough_vale] | 525 | r14_elf_07_quiet_the_lower_boughs |
| r15_elf_local_03 | No Shadow on the Sightline | Theren Farstep (Starbough Outpost) | 11 | kill 4 poacher [in elandor_starbough_vale] | 315 | r14_elf_07_quiet_the_lower_boughs |
| r15_elf_local_04 | Fangs Beside the Trail Signs | Theren Farstep (Starbough Outpost) | 11 | bring 2 grug_mobs:fang | 420 | r14_elf_07_quiet_the_lower_boughs |
| r14_elf_09_cinders_in_green_cloth | Cinders in Green Cloth | Theren Farstep (Starbough Outpost) | 12 | kill 4 bandit or bandit_archer [in elandor_starbough_vale] | 805 | r14_elf_08_watch_the_green_road |
| r15_elf_local_05 | Knots from the Bough Road | Nima Fern (Starbough Bandit Camp) | 12 | bring 2 grug_mobs:stolen_purse | 460 | r14_elf_08_watch_the_green_road |
| r15_elf_local_06 | Bindings from the Worksite | Nima Fern (Starbough Bandit Camp) | 12 | bring 5 grug_mobs:linen_cloth | 575 | r14_elf_08_watch_the_green_road |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| boar | Boar | neutral | 100.0% of land, L11-20 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| fox | Fox | aggressive | 77.5% of land, L11-20 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_silver_litter |
| poacher | Poacher | aggressive | - | 100.0% of land, L11-20 | dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| rabbit | Rabbit | critter | 100.0% of land, L11-20 | - | dirt_with_coniferous_litter, dirt_with_grass, gravel, sand, snowblock, dirt_with_forest_litter … |
| shore_crab | Shore Crab | neutral | 9232 nodes², L11-18 | 9232 nodes², L11-18 | sand (dry, within 6 nodes of water) |
| zombie | Zombie | aggressive | - | 100.0% of land, L11-20 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

**Camps and guard posts:**

- anchor_033 Starbough Outpost at 2100, -2100: guard post, guard_accord × 2-3, respawn 180-360 s, level there L14.
- anchor_053 Starbough Bandit Camp at 1632, -2066: bandit, bandit/bandit_archer × 3-5, respawn 120-300 s, level there L15.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 5 | primary | anchor_003 (Silverleaf, elandor_silverleaf_glades) | anchor_009 (Lethariel, elandor_lethariel) | 810 / 420 | 1751,-2313 → 1848,-1934 |
| 6 | secondary | anchor_017 (Starbough Village, elandor_starbough_vale) | joins road 5 | 89 / 90 | 1885,-2005 → 1801,-2028 |
| 37 | trail | anchor_033 (Starbough Outpost, elandor_starbough_vale) | joins road 5 | 317 / 316 | 2090,-2110 → 1818,-2157 |
| 53 | trail | anchor_053 (Starbough Bandit Camp, elandor_starbough_vale) | joins road 5 | 255 / 254 | 1641,-2051 → 1839,-1951 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

