# Nhal Veyr (`kragmar_nhal_veyr`)

Zone 19 · capital zone · throng · race region **undead** · levels **20-30** · peaceful · relief `plateau` · seed 42

Map: [maps/kragmar_nhal_veyr.png](maps/kragmar_nhal_veyr.png). Machine-readable: [kragmar_nhal_veyr.json](kragmar_nhal_veyr.json). Coordinates are world nodes (x east, z north, y up).

Race track (undead): step 3 of the track Stillgrave Hollow → Mournfen → Nhal Veyr → Ossuary Reach → Blackwind Rise.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2208..-1324, z 1032..1956 (centroid -1759, 1500) |
| Land area | 657088 nodes² (≈ 0.66 km²) |
| Hub point (authored) | -1800, 1500 |
| Height above sea | min 26, p10 41, median 52, p90 113, max 251 |
| Slope | 9.6% steep (>1 node/node), 1.4% cliff (>2) |
| Biomes (measured) | blight 75.2%, bone_forest 24.1%, savanna 0.3%, swamp 0.3%, badlands 0.2% |
| Neighbours (land border) | kragmar_blackwind_rise (896 nodes, mid -1692,1072), kragmar_mournfen (872 nodes, mid -1742,1918), kragmar_ossuary_reach (1044 nodes, mid -2148,1502), kragmar_speargrass_reach (804 nodes, mid -1351,1495) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 5280 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 8368 nodes² |
| Protected / drift band | 21.1% of land protected (towns, villages, camps/POIs, road corridors); 12.2% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at); capital palettes are empty today, so no ambient mobs spawn anywhere in the zone.

Share of land per level: L20 10.2%, L21 11.0%, L22 11.5%, L23 9.2%, L24 8.6%, L25 9.1%, L26 9.0%, L27 8.2%, L28 8.2%, L29 7.7%, L30 7.3%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_010 | capital | Nhal Veyr | -1800 | 46 | 1500 | 24 | - |

## Protected areas

- Capital city (seed-dependent outline): box x -1998..-1642, z 1274..1728, area 126840 nodes²; 80.7% of the zone's land lies outside the city. Gates: east -1671,1562, south -1864,1708, west -1962,1557, north -1858,1308.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Nhal Veyr (`nhal_veyr`, anchor_010) at -1800, 46, 1500

Residents/guards: gear_display 3, guard_patrol 50, guard_post 21, housing_manager 1, idle 140, innkeeper 1, king 1, mount_display 4, public_station 7, quest 2, riding_trainer 1, trainer 8, vendor 6, waypoint 1, work 50.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| king | king |  | -1800, 52, 1532 | - |
| vigil_hall_quest | quest giver | Ossa Quietregister | -1838, 47, 1521 | r20_undead_capital_services, r20_undead_capital_stores, r20_undead_journey_01 |
| vendor_race | vendor | vendor kind: race | -1757, 47, 1509 | - |
| vendor_general | vendor | vendor kind: general | -1757, 47, 1516 | - |
| travel_waypoint | waypoint |  | -1781, 47, 1478 | - |
| market_bone_store/market_bone_store_goldsmith | profession trainer | trains: goldsmith | -1873, 47, 1452 | - |
| market_bone_store/market_bone_store_jewel | gear display |  | -1870, 48, 1447 | - |
| market_cart_yard/market_cart_yard_mount_1 | mount display |  | -1893, 48, 1496 | - |
| market_cart_yard/market_cart_yard_mount_2 | mount display |  | -1893, 48, 1486 | - |
| market_cart_yard/market_cart_yard_mount_3 | mount display |  | -1887, 48, 1496 | - |
| market_cart_yard/market_cart_yard_mount_4 | mount display |  | -1887, 48, 1486 | - |
| market_cart_yard/market_cart_yard_riding | riding trainer |  | -1896, 48, 1491 | - |
| market_bonesmith/market_bonesmith_vendor_smith | vendor | vendor kind: smith | -1908, 50, 1494 | - |
| market_bonesmith/market_bonesmith_weaponsmith | profession trainer | trains: weaponsmith | -1917, 50, 1487 | - |
| market_bonesmith/market_bonesmith_armorsmith | profession trainer | trains: armorsmith | -1917, 50, 1491 | - |
| market_bonesmith/market_bonesmith_weapon | gear display |  | -1921, 51, 1486 | - |
| market_bonesmith/market_bonesmith_armor | gear display |  | -1921, 51, 1492 | - |
| market_shroud_house/market_shroud_house_gate_idle | housing steward |  | -1832, 47, 1411 | - |
| market_shroud_house/market_shroud_house_vendor_tailor | vendor | vendor kind: tailor | -1827, 47, 1409 | - |
| market_shroud_house/market_shroud_house_tailor | profession trainer | trains: tailor | -1834, 47, 1419 | - |
| market_physic/market_physic_vendor_herbalist | vendor | vendor kind: herbalist | -1854, 48, 1399 | - |
| market_physic/market_physic_alchemist | profession trainer | trains: alchemist | -1847, 48, 1389 | - |
| market_charnel/market_charnel_leatherworker | profession trainer | trains: leatherworker | -1900, 49, 1432 | - |
| vigil_candle_works/vigil_candle_works_woodcarver | profession trainer | trains: woodcarver | -1810, 48, 1620 | - |
| homes_lane_house/homes_lane_house_gate_idle | innkeeper (respawn bind) |  | -1814, 47, 1386 | - |
| homes_mourners_hall/homes_mourners_hall_cooking | profession trainer | trains: cooking | -1784, 47, 1412 | - |
| homes_mourners_hall/homes_mourners_hall_quest_cook | quest giver | Velis Mourningbowl | -1780, 47, 1412 | r20_undead_capital_cook |
| vigil_embalmer/vigil_embalmer_vendor_embalmer | vendor | vendor kind: embalmer | -1791, 47, 1599 | - |

Public stations: market_bone_store/market_bone_store_station (jewellers_bench), market_bonesmith/market_bonesmith_station (forge), market_shroud_house/market_shroud_house_station (tailor_bench), market_physic/market_physic_station (brewing_stand), market_charnel/market_charnel_station (tanning_rack), vigil_candle_works/vigil_candle_works_station (carving_bench), homes_mourners_hall/homes_mourners_hall_station (furnace).

Distances: zone edge N 460 (kragmar_mournfen), S 468 (kragmar_blackwind_rise), E 468 (kragmar_speargrass_reach), W 380 (kragmar_ossuary_reach); nearest other-zone land 366 W; sea 639 W; sea-beach sand 612 NE; nearest road 50.
Nearest hubs (straight / by road): Ossuary Ledgerstead 589 / 677; Mournfen Village 530 / 754; Mournfen Outpost 671 / 971; Boneledger Post 538 / 1012; Memoryvein Dig 662 / 1027.

### Current quests (4, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_undead_capital_cook | Bowls for the Vigil | Velis Mourningbowl (Nhal Veyr) | 10 | bring 5 mobs:meat_raw | 380 | - |
| r20_undead_capital_services | The Vigil Table | Ossa Quietregister (Nhal Veyr) | 10 | talk to Velis Mourningbowl (nhal_veyr) | 285 | r20_undead_capital_intro |
| r20_undead_capital_stores | Coal for the Vigil Lamps | Ossa Quietregister (Nhal Veyr) | 20 | bring 8 default:coal_lump | 780 | - |
| r20_undead_journey_01 | Word for Sovel Namekeeper | Ossa Quietregister (Nhal Veyr) | 21 | talk to Sovel Namekeeper (r20_anchor_020) | 615 | - |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

Empty palette: no ambient surface mobs.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 15 | primary | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 1440 / 116 | -1537,1762 → -1444,1825 |
| 17 | primary | anchor_004 (Stillgrave, kragmar_stillgrave_hollow) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 782 / 192 | -1937,1948 → -1936,1760 |
| 23 | secondary | anchor_020 (Ossuary Ledgerstead, kragmar_ossuary_reach) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 324 / 148 | -2210,1646 → -2064,1650 |
| 26 | secondary | anchor_039 (Ashveil Watch, kragmar_blackwind_rise) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 584 / 130 | -2022,1118 → -2031,1233 |
| 30 | secondary | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | anchor_022 (Speargrass Wellhold, kragmar_speargrass_reach) | 802 / 266 | -1535,1649 → -1346,1561 |
| 41 | trail | anchor_038 (Boneledger Post, kragmar_ossuary_reach) | joins road 26 | 276 / 42 | -2045,1152 → -2010,1133 |
| 55 | trail | anchor_055 (Mournfen Bandit Camp, kragmar_mournfen) | joins road 15 | 275 / 136 | -1552,1906 → -1454,1819 |
| 56 | trail | anchor_056 (Pallcloth Den, kragmar_blackwind_rise) | joins road 30 | 1756 / 590 | -1488,1086 → -1422,1590 |
| 192 | secondary | end:30 | gate_east | 177 / 176 | -1535,1649 → -1663,1562 |
| 193 | primary | end:15 | joins road 192 | 118 / 120 | -1537,1762 → -1551,1650 |
| 194 | primary | end:17 | gate_south | 95 / 96 | -1936,1760 → -1864,1716 |
| 195 | secondary | end:23 | gate_west | 143 / 142 | -2064,1650 → -1970,1557 |
| 196 | secondary | end:26 | gate_north | 215 / 216 | -2031,1233 → -1858,1300 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

Capital streets (avenues and lanes) inside the city: 17.

