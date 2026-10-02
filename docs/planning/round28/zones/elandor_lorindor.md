# Lorindor (`elandor_lorindor`)

Zone 14 · home zone 21-30 · accord · race region **elf** · levels **21-30** · peaceful · relief `rolling_hills` · seed 42

Map: [maps/elandor_lorindor.png](maps/elandor_lorindor.png). Machine-readable: [elandor_lorindor.json](elandor_lorindor.json). Coordinates are world nodes (x east, z north, y up).

Race track (elf): step 4 of the track Silverleaf Glades → Starbough Vale → Lethariel → Lorindor → Moonfall Wood → Glassroot Wilds.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 424..1380, z -1948..-1092 (centroid 894, -1490) |
| Land area | 558688 nodes² (≈ 0.56 km²) |
| Hub point (authored) | 900, -1500 |
| Height above sea | min 0, p10 36, median 86, p90 142, max 198 |
| Slope | 20.3% steep (>1 node/node), 1.3% cliff (>2) |
| Biomes (measured) | elf_forest 59.9%, deep_forest 22.5%, swamp 16.9%, meadows 0.6%, jungle_fringe 0.2% |
| Neighbours (land border) | elandor_ashenward_march (512 nodes, mid 583,-1178), elandor_glassroot_wilds (760 nodes, mid 1034,-1150), elandor_goldmead_vale (464 nodes, mid 561,-1800), elandor_highcourt (476 nodes, mid 456,-1465), elandor_lethariel (624 nodes, mid 1329,-1441), elandor_starbough_vale (400 nodes, mid 1283,-1786) |
| Sea coast | 1156 nodes of coastline; sea-beach sand 10112 nodes²; lake/river-bank sand 8288 nodes² |
| Water inside | bay 74448 nodes², rivers/lakes 9456 nodes² |
| Protected / drift band | 2.8% of land protected (towns, villages, camps/POIs, road corridors); 9.9% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 969, -1799 | x 896..1068, z -1856..-1764 | 6128 | L21 |
| B2 | 665, -1877 | x 644..708, z -1948..-1824 | 2384 | L21 |
| B3 | 768, -1831 | x 728..812, z -1852..-1800 | 1488 | L21 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L21 10.7%, L22 11.4%, L23 11.1%, L24 11.3%, L25 11.4%, L26 10.7%, L27 8.5%, L28 8.7%, L29 8.1%, L30 8.1%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_018 | village | Lorindor Berrycourt | 876 | 100 | -1556 | 24 | village x 864..887, z -1568..-1545 |
| anchor_034 | outpost | Petalbank Wardenry | 626 | 53 | -1226 | 29 | poi x 618..633, z -1234..-1219 |
| anchor_063 | mine | Paleroot Cutting | 1026 | 178 | -1256 | 29 | poi x 1016..1035, z -1266..-1247 |
| anchor_068 | mirefolk camp | Whitepetal Fenhold | 1096 | 41 | -1716 | 22 | camp x 1088..1103, z -1724..-1709 |

## Protected areas

- village Lorindor Berrycourt (anchor_018): x 864..887, z -1568..-1545
- poi Petalbank Wardenry (anchor_034): x 618..633, z -1234..-1219
- poi Paleroot Cutting (anchor_063): x 1016..1035, z -1266..-1247
- camp Whitepetal Fenhold (anchor_068): x 1088..1103, z -1724..-1709
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Lorindor Berrycourt (`r20_anchor_018`, anchor_018) at 876, 100, -1556

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Ilwen Petalmeasure | 878, 101, -1556 | r20_anchor_018_01, r20_anchor_018_02, r20_anchor_018_03, r20_elf_journey_02 |

Distances: zone edge N 420 (elandor_glassroot_wilds), S 228 (bay_water), E 452 (elandor_lethariel), W 396 (elandor_highcourt); nearest other-zone land 382 SW; sea 215 S; sea-beach sand 211 S; nearest road 16.
Nearest hubs (straight / by road): Paleroot Cutting 335 / 1051; Lethariel 926 / 1126; Petalbank Wardenry 414 / 1147; Highcourt 878 / 1360; Goldmead Bandit Camp 699 / 1784.

### Petalbank Wardenry (`r20_anchor_034`, anchor_034) at 626, 53, -1226

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Orya Petalward | 628, 54, -1226 | r20_anchor_034_01, r20_anchor_034_02, r20_anchor_034_03 |

Distances: zone edge N 80 (elandor_ashenward_march), S 684 (elandor_goldmead_vale), E 700 (elandor_lethariel), W 120 (elandor_ashenward_march); nearest other-zone land 65 N; sea 572 S; sea-beach sand 594 S; nearest road 13.
Nearest hubs (straight / by road): Lorindor Berrycourt 414 / 1147; Highcourt 683 / 1211; Goldmead Bandit Camp 814 / 1635; Goldmead Outpost 918 / 1673; Goldmead Village 1089 / 1687.

### Paleroot Cutting (`r20_anchor_063`, anchor_063) at 1026, 178, -1256

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Saevin Rootscribe | 1028, 179, -1256 | r20_anchor_063_01, r20_anchor_063_02, r20_anchor_063_03, r20_elf_journey_03 |

Distances: zone edge N 96 (elandor_glassroot_wilds), S 548 (coastal_shelf), E 308 (elandor_lethariel), W 576 (elandor_ashenward_march); nearest other-zone land 89 N; sea 539 S; sea-beach sand 516 S; nearest road 13.
Nearest hubs (straight / by road): Lethariel 812 / 1033; Lorindor Berrycourt 335 / 1051; Starbough Village 1161 / 1699; Starbough Bandit Camp 1012 / 1775; Petalbank Wardenry 401 / 1983.

### Current quests (11, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_018_01 | Stones Around the Roots | Ilwen Petalmeasure (Lorindor Berrycourt) | 21 | bring 8 default:cobble | 820 | - |
| r20_anchor_018_02 | No Snares in Berrycourt | Ilwen Petalmeasure (Lorindor Berrycourt) | 21 | kill 4 poacher or unlicensed_poacher [in elandor_lorindor] | 820 | - |
| r20_anchor_034_01 | The Trough's New Kerb | Orya Petalward (Petalbank Wardenry) | 21 | bring 8 default:cobble | 820 | - |
| r20_anchor_034_02 | Wardens Without Arrows | Orya Petalward (Petalbank Wardenry) | 21 | kill 4 poacher or unlicensed_poacher [in elandor_lorindor] | 820 | - |
| r20_anchor_063_01 | A Gentle Edge | Saevin Rootscribe (Paleroot Cutting) | 21 | bring 1 grug_materials:pick_stone | 820 | - |
| r20_anchor_063_02 | The Survey Stakes Vanish | Saevin Rootscribe (Paleroot Cutting) | 21 | kill 4 poacher or unlicensed_poacher [in elandor_lorindor] | 820 | - |
| r20_anchor_018_03 | The Uninvited Lanterns | Ilwen Petalmeasure (Lorindor Berrycourt) | 23 | kill 3 wisp [in elandor_lorindor] | 900 | r20_anchor_018_02 |
| r20_anchor_034_03 | Lanterns We Did Not Hang | Orya Petalward (Petalbank Wardenry) | 23 | kill 3 wisp [in elandor_lorindor] | 900 | r20_anchor_034_02 |
| r20_anchor_063_03 | Light on the Cutting Marks | Saevin Rootscribe (Paleroot Cutting) | 23 | kill 3 wisp [in elandor_lorindor] | 900 | r20_anchor_063_02 |
| r20_elf_journey_02 | Word for Saevin Rootscribe | Ilwen Petalmeasure (Lorindor Berrycourt) | 24 | talk to Saevin Rootscribe (r20_anchor_063) | 705 | - |
| r20_elf_journey_03 | Word for Faeris Rootbinder | Saevin Rootscribe (Paleroot Cutting) | 31 | talk to Faeris Rootbinder (r20_anchor_036) | 915 | - |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| armored_crab | Barnacle Pincher | aggressive | 1.6% of land, L25-27 | - |  |
| bank_crab | Bank Crab | neutral | 3.4% of land, L21-24 | - |  |
| moss_antler_stag | Moss-Antler Stag | neutral | 93.4% of land, L21-30 | - |  |
| shore_crab | Shore Crab | neutral | 10112 nodes², L21 | 10112 nodes², L21 | sand (dry, within 6 nodes of water) |
| toll_mirefolk | Toll Mirefolk | aggressive | 3.2% of land, L21-30 | 3.2% of land, L21-30 |  |
| unlicensed_poacher | Unlicensed Poacher | aggressive | - | 29.3% of land, L21-23 |  |
| wandering_wisp | Wandering Wisp | aggressive | - | 96.8% of land, L21-30 |  |

**Camps and guard posts:**

- anchor_034 Petalbank Wardenry at 626, -1226: guard post, guard_accord × 2-3, respawn 180-360 s, level there L29.
- anchor_068 Whitepetal Fenhold at 1096, -1716: mirefolk camp, EMPTY today: no camp fire is placed (anchor roster lists only capital, outpost and bandit populations) (level there L22).

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 2 | primary | anchor_008 (Highcourt, elandor_highcourt) | anchor_009 (Lethariel, elandor_lethariel) | 1355 / 936 | 435,-1395 → 1309,-1481 |
| 11 | secondary | anchor_018 (Lorindor Berrycourt, elandor_lorindor) | joins road 2 | 93 / 96 | 879,-1540 → 848,-1455 |
| 39 | trail | anchor_034 (Petalbank Wardenry, elandor_lorindor) | joins road 2 | 488 / 66 | 632,-1215 → 614,-1159 |
| 64 | trail | anchor_063 (Paleroot Cutting, elandor_lorindor) | joins road 2 | 467 / 462 | 1030,-1244 → 1284,-1493 |
| 69 | trail | anchor_068 (Whitepetal Fenhold, elandor_lorindor) | joins road 2 | 302 / 298 | 1106,-1708 → 1184,-1488 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

