# Lethariel (`elandor_lethariel`)

Zone 13 · capital zone · accord · race region **elf** · levels **20-30** · peaceful · relief `rolling_hills` · seed 42

Map: [maps/elandor_lethariel.png](maps/elandor_lethariel.png). Machine-readable: [elandor_lethariel.json](elandor_lethariel.json). Coordinates are world nodes (x east, z north, y up).

Race track (elf): step 3 of the track Silverleaf Glades → Starbough Vale → Lethariel → Lorindor → Moonfall Wood → Glassroot Wilds.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 1300..2232, z -2024..-1004 (centroid 1783, -1485) |
| Land area | 636160 nodes² (≈ 0.64 km²) |
| Hub point (authored) | 1800, -1500 |
| Height above sea | min 32, p10 51, median 58, p90 86, max 151 |
| Slope | 1.2% steep (>1 node/node), 0.0% cliff (>2) |
| Biomes (measured) | elf_forest 87.4%, deep_forest 12.4%, swamp 0.2%, jungle_fringe 0.0% |
| Neighbours (land border) | elandor_glassroot_wilds (788 nodes, mid 1611,-1062), elandor_lorindor (620 nodes, mid 1324,-1443), elandor_moonfall_wood (1384 nodes, mid 2151,-1461), elandor_starbough_vale (1196 nodes, mid 1794,-1877) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 11184 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 46192 nodes² |
| Protected / drift band | 19.8% of land protected (towns, villages, camps/POIs, road corridors); 8.9% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at); its spawn regions decide where mobs stand.

Share of land per level: L20 9.0%, L21 10.2%, L22 12.4%, L23 10.0%, L24 9.9%, L25 7.8%, L26 7.4%, L27 8.4%, L28 8.9%, L29 8.0%, L30 8.1%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_009 | capital | Lethariel | 1800 | 55 | -1500 | 24 | - |

## Protected areas

- Capital city (seed-dependent outline): box x 1610..2052, z -1748..-1276, area 158548 nodes²; 75.1% of the zone's land lies outside the city. Gates: east 2026,-1570, south 1774,-1377, west 1664,-1461, north 1795,-1716.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Lethariel (`lethariel`, anchor_009) at 1800, 55, -1500

Residents/guards: gear_display 3, guard_patrol 43, guard_post 14, housing_manager 1, idle 127, innkeeper 1, king 1, mount_display 4, public_station 7, quest 3, riding_trainer 1, trainer 8, vendor 9, waypoint 1, work 48.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| king | king |  | 1762, 61, -1525 | - |
| star_hall_quest | quest giver | Eriath Boughwarden | 1775, 56, -1495 | r20_elf_capital_services, r20_elf_capital_stores, r20_elf_journey_01 |
| vendor_race | vendor | vendor kind: race | 1817, 56, -1525 | - |
| vendor_general | vendor | vendor kind: general | 1824, 56, -1525 | - |
| travel_waypoint | waypoint |  | 1825, 56, -1514 | - |
| market_stable/market_stable_mount_1 | mount display |  | 1812, 56, -1561 | - |
| market_stable/market_stable_mount_2 | mount display |  | 1812, 56, -1571 | - |
| market_stable/market_stable_mount_3 | mount display |  | 1818, 56, -1561 | - |
| market_stable/market_stable_mount_4 | mount display |  | 1818, 56, -1571 | - |
| market_stable/market_stable_riding | riding trainer |  | 1809, 56, -1566 | - |
| market_bowyer/market_bowyer_vendor_bowyer | vendor | vendor kind: bowyer | 1858, 56, -1510 | - |
| market_bowyer/market_bowyer_woodcarver | profession trainer | trains: woodcarver | 1865, 56, -1519 | - |
| market_weaver/market_weaver_gate_idle | housing steward |  | 1804, 57, -1590 | - |
| market_weaver/market_weaver_vendor_weaver | vendor | vendor kind: tailor | 1802, 57, -1595 | - |
| market_weaver/market_weaver_tailor | profession trainer | trains: tailor | 1812, 57, -1588 | - |
| market_bakehouse/market_bakehouse_vendor_baker | vendor | vendor kind: baker | 1879, 55, -1520 | - |
| market_bakehouse/market_bakehouse_cooking | profession trainer | trains: cooking | 1885, 55, -1529 | - |
| market_bakehouse/market_bakehouse_quest_cook | quest giver | Mirael Petalpot | 1881, 55, -1529 | r20_elf_capital_cook |
| martial_armoury/martial_armoury_vendor_armourer | vendor | vendor kind: armourer | 1739, 57, -1450 | - |
| martial_armoury/martial_armoury_weaponsmith | profession trainer | trains: weaponsmith | 1730, 57, -1457 | - |
| martial_armoury/martial_armoury_armorsmith | profession trainer | trains: armorsmith | 1730, 57, -1453 | - |
| martial_armoury/martial_armoury_weapon | gear display |  | 1726, 58, -1458 | - |
| martial_armoury/martial_armoury_armor | gear display |  | 1726, 58, -1452 | - |
| martial_store/martial_store_leatherworker | profession trainer | trains: leatherworker | 1735, 58, -1436 | - |
| mere_lore_hall/mere_lore_hall_vendor_herbalist | vendor | vendor kind: herbalist | 1867, 56, -1495 | - |
| mere_lore_hall/mere_lore_hall_goldsmith | profession trainer | trains: goldsmith | 1860, 56, -1485 | - |
| mere_lore_hall/mere_lore_hall_jewel | gear display |  | 1865, 57, -1482 | - |
| homes_longhouse/homes_longhouse_gate_idle | innkeeper (respawn bind) |  | 1790, 56, -1562 | - |
| homes_brewhouse/homes_brewhouse_vendor_brewer | vendor | vendor kind: brewer | 1725, 57, -1526 | - |
| homes_brewhouse/homes_brewhouse_alchemist | profession trainer | trains: alchemist | 1716, 57, -1533 | - |
| mere_shrine/mere_shrine_quest | quest giver | (free quest socket: no quest NPC bound) | 1884, 56, -1498 | - |
| mere_stages/mere_stages_vendor_fishmonger | vendor | vendor kind: fishmonger | 1991, 51, -1547 | - |

Public stations: market_bowyer/market_bowyer_station (carving_bench), market_weaver/market_weaver_station (tailor_bench), market_bakehouse/market_bakehouse_station (furnace), martial_armoury/martial_armoury_station (forge), martial_store/martial_store_station (tanning_rack), mere_lore_hall/mere_lore_hall_station (jewellers_bench), homes_brewhouse/homes_brewhouse_station (brewing_stand).

Distances: zone edge N 496 (elandor_glassroot_wilds), S 428 (elandor_starbough_vale), E 424 (elandor_moonfall_wood), W 488 (elandor_lorindor); nearest other-zone land 376 SW; sea 666 SW; sea-beach sand 586 SW; nearest road 50.
Nearest hubs (straight / by road): Starbough Village 530 / 812; Starbough Bandit Camp 590 / 889; Paleroot Cutting 812 / 1033; Lorindor Berrycourt 926 / 1126; Glassroot Gate 825 / 1133.

### Current quests (4, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_elf_capital_cook | The Petalpot Share | Mirael Petalpot (Lethariel) | 10 | bring 5 mobs:meat_raw | 380 | - |
| r20_elf_capital_services | Petalpot Hospitality | Eriath Boughwarden (Lethariel) | 10 | talk to Mirael Petalpot (lethariel) | 285 | r20_elf_capital_intro |
| r20_elf_capital_stores | Boards for the Grove Patrol | Eriath Boughwarden (Lethariel) | 20 | bring 10 default:wood | 780 | - |
| r20_elf_journey_01 | Word for Ilwen Petalmeasure | Eriath Boughwarden (Lethariel) | 21 | talk to Ilwen Petalmeasure (r20_anchor_018) | 615 | - |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| debtbound_zombie | Debtbound Zombie | aggressive | - | 69.8% of land, L20-25 |  |
| moss_antler_stag | Moss-Antler Stag | neutral | 58.8% of land, L20-30 | - |  |
| orchard_fox | Orchard Fox | neutral | 69.8% of land, L21-24 | - |  |
| redfang_fox | Redfang Vixen | aggressive | 68.5% of land, L25-30 | - |  |
| stubborn_zombie | Tithe Revenant | aggressive | - | 68.5% of land, L26-30 |  |
| toll_bandit | Toll Bandit | aggressive | - | 28.0% of land, L20-23 |  |
| unlicensed_poacher | Unlicensed Poacher | aggressive | 1.4% of land, L28-30 | 30.2% of land, L28-30 |  |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 2 | primary | anchor_008 (Highcourt, elandor_highcourt) | anchor_009 (Lethariel, elandor_lethariel) | 1355 / 232 | 1311,-1480 → 1536,-1489 |
| 5 | primary | anchor_003 (Silverleaf, elandor_silverleaf_glades) | anchor_009 (Lethariel, elandor_lethariel) | 810 / 180 | 1849,-1932 → 1853,-1760 |
| 14 | secondary | anchor_036 (Glassroot Gate, elandor_glassroot_wilds) | anchor_009 (Lethariel, elandor_lethariel) | 766 / 242 | 1835,-1007 → 1776,-1232 |
| 40 | trail | anchor_035 (Moonfall Observatory, elandor_moonfall_wood) | joins road 14 | 668 / 350 | 2130,-1275 → 1834,-1100 |
| 153 | secondary | end:14 | gate_south | 141 / 142 | 1776,-1232 → 1774,-1371 |
| 154 | primary | end:2 | gate_west | 137 / 138 | 1536,-1489 → 1658,-1461 |
| 155 | primary | end:5 | gate_north | 81 / 84 | 1853,-1760 → 1795,-1722 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

Capital streets (avenues and lanes) inside the city: 14.

