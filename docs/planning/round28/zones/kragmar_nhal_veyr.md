# Nhal Veyr (`kragmar_nhal_veyr`)

Zone 19 · capital zone · throng · race region **undead** · levels **20-30** · peaceful · relief `plateau` · seed 42

Map: [maps/kragmar_nhal_veyr.png](maps/kragmar_nhal_veyr.png). Machine-readable: [kragmar_nhal_veyr.json](kragmar_nhal_veyr.json). Coordinates are world nodes (x east, z north, y up).

Race track (undead): step 3 of the track Stillgrave Hollow → Mournfen → Nhal Veyr → Ossuary Reach → Blackwind Rise.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2208..-1324, z 1032..1956 (centroid -1759, 1500) |
| Land area | 660528 nodes² (≈ 0.66 km²) |
| Hub point (authored) | -1800, 1500 |
| Height above sea | min 26, p10 41, median 52, p90 113, max 251 |
| Slope | 9.4% steep (>1 node/node), 1.4% cliff (>2) |
| Biomes (measured) | blight 75.1%, bone_forest 24.2%, savanna 0.3%, swamp 0.3%, badlands 0.2% |
| Neighbours (land border) | kragmar_blackwind_rise (896 nodes, mid -1692,1072), kragmar_mournfen (900 nodes, mid -1747,1919), kragmar_ossuary_reach (1044 nodes, mid -2148,1502), kragmar_speargrass_reach (804 nodes, mid -1351,1495) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 3376 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 4928 nodes² |
| Protected / drift band | 21.0% of land protected (towns, villages, camps/POIs, road corridors); 9.7% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at); its spawn regions decide where mobs stand.

Share of land per level: L20 10.1%, L21 11.1%, L22 11.5%, L23 9.3%, L24 8.7%, L25 9.2%, L26 9.0%, L27 8.2%, L28 8.1%, L29 7.6%, L30 7.2%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_010 | capital | Nhal Veyr | -1800 | 46 | 1500 | 24 | - |

## Protected areas

- Capital city (seed-dependent outline): box x -2034..-1564, z 1342..1682, area 127084 nodes²; 80.8% of the zone's land lies outside the city. Gates: east -1599,1558, south -1876,1662, west -1997,1557, north -1866,1366.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Nhal Veyr (`nhal_veyr`, anchor_010) at -1800, 46, 1500

Residents/guards: gear_display 3, guard_patrol 50, guard_post 21, housing_manager 1, idle 137, innkeeper 1, king 1, mount_display 4, public_station 7, quest 2, riding_trainer 1, trainer 8, vendor 6, waypoint 1, work 45.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| king | king |  | -1800, 52, 1532 | - |
| vigil_hall_quest | quest giver | Ossa Quietregister | -1838, 47, 1521 | r20_undead_capital_services, r20_undead_capital_stores, r20_undead_journey_01 |
| vendor_race | vendor | vendor kind: race | -1757, 47, 1509 | - |
| vendor_general | vendor | vendor kind: general | -1757, 47, 1516 | - |
| travel_waypoint | waypoint |  | -1781, 47, 1478 | - |
| market_bone_store/market_bone_store_goldsmith | profession trainer | trains: goldsmith | -1723, 45, 1453 | - |
| market_bone_store/market_bone_store_jewel | gear display |  | -1726, 46, 1458 | - |
| market_cart_yard/market_cart_yard_mount_1 | mount display |  | -1693, 43, 1454 | - |
| market_cart_yard/market_cart_yard_mount_2 | mount display |  | -1693, 43, 1444 | - |
| market_cart_yard/market_cart_yard_mount_3 | mount display |  | -1687, 43, 1454 | - |
| market_cart_yard/market_cart_yard_mount_4 | mount display |  | -1687, 43, 1444 | - |
| market_cart_yard/market_cart_yard_riding | riding trainer |  | -1696, 43, 1449 | - |
| market_bonesmith/market_bonesmith_vendor_smith | vendor | vendor kind: smith | -1705, 45, 1482 | - |
| market_bonesmith/market_bonesmith_weaponsmith | profession trainer | trains: weaponsmith | -1714, 45, 1475 | - |
| market_bonesmith/market_bonesmith_armorsmith | profession trainer | trains: armorsmith | -1714, 45, 1479 | - |
| market_bonesmith/market_bonesmith_weapon | gear display |  | -1718, 46, 1474 | - |
| market_bonesmith/market_bonesmith_armor | gear display |  | -1718, 46, 1480 | - |
| market_shroud_house/market_shroud_house_gate_idle | housing steward |  | -1677, 44, 1517 | - |
| market_shroud_house/market_shroud_house_vendor_tailor | vendor | vendor kind: tailor | -1682, 44, 1519 | - |
| market_shroud_house/market_shroud_house_tailor | profession trainer | trains: tailor | -1675, 44, 1509 | - |
| market_physic/market_physic_vendor_herbalist | vendor | vendor kind: herbalist | -1742, 44, 1404 | - |
| market_physic/market_physic_alchemist | profession trainer | trains: alchemist | -1735, 44, 1394 | - |
| market_charnel/market_charnel_leatherworker | profession trainer | trains: leatherworker | -1804, 47, 1412 | - |
| vigil_candle_works/vigil_candle_works_woodcarver | profession trainer | trains: woodcarver | -1694, 47, 1560 | - |
| homes_lane_house/homes_lane_house_gate_idle | innkeeper (respawn bind) |  | -1838, 47, 1585 | - |
| homes_mourners_hall/homes_mourners_hall_cooking | profession trainer | trains: cooking | -1869, 47, 1556 | - |
| homes_mourners_hall/homes_mourners_hall_quest_cook | quest giver | Velis Mourningbowl | -1869, 47, 1552 | r20_undead_capital_cook |
| vigil_embalmer/vigil_embalmer_vendor_embalmer | vendor | vendor kind: embalmer | -1752, 49, 1603 | - |

Public stations: market_bone_store/market_bone_store_station (jewellers_bench), market_bonesmith/market_bonesmith_station (forge), market_shroud_house/market_shroud_house_station (tailor_bench), market_physic/market_physic_station (brewing_stand), market_charnel/market_charnel_station (tanning_rack), vigil_candle_works/vigil_candle_works_station (carving_bench), homes_mourners_hall/homes_mourners_hall_station (furnace).

Distances: zone edge N 460 (kragmar_mournfen), S 468 (kragmar_blackwind_rise), E 468 (kragmar_speargrass_reach), W 380 (kragmar_ossuary_reach); nearest other-zone land 366 W; sea 639 W; sea-beach sand 612 NE; nearest road 50.
Nearest hubs (straight / by road): Ossuary Ledgerstead 589 / 687; Mournfen Village 530 / 717; Mournfen Outpost 671 / 935; Boneledger Post 538 / 940; Memoryvein Dig 662 / 1036.

### Current quests (4, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_undead_capital_cook | Bowls for the Vigil | Velis Mourningbowl (Nhal Veyr) | 10 | bring 5 mobs:meat_raw | 380 | - |
| r20_undead_capital_services | The Vigil Table | Ossa Quietregister (Nhal Veyr) | 10 | talk to Velis Mourningbowl (nhal_veyr) | 285 | r20_undead_capital_intro |
| r20_undead_capital_stores | Coal for the Vigil Lamps | Ossa Quietregister (Nhal Veyr) | 20 | bring 8 default:coal_lump | 780 | - |
| r20_undead_journey_01 | Word for Sovel Namekeeper | Ossa Quietregister (Nhal Veyr) | 21 | talk to Sovel Namekeeper (r20_anchor_020) | 615 | - |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| debtbound_husk | Debtbound Sun-Dried Husk | aggressive | 25.0% of land, L20-23 | - |  |
| debtbound_zombie | Debtbound Zombie | aggressive | - | 69.9% of land, L20-25 |  |
| furrow_boar | Furrow Boar | neutral | 12.9% of land, L21-24 | - |  |
| monstrous_boar | Razorback | aggressive | 49.2% of land, L25-30 | - |  |
| moss_antler_stag | Moss-Antler Stag | neutral | 78.7% of land, L20-30 | - |  |
| stubborn_husk | Tithe Mummy | aggressive | 21.3% of land, L28-30 | - |  |
| stubborn_zombie | Tithe Revenant | aggressive | - | 69.9% of land, L26-30 |  |
| toll_bandit | Toll Bandit | aggressive | - | 25.0% of land, L20-23 |  |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 15 | primary | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 1440 / 116 | -1537,1762 → -1444,1825 |
| 17 | primary | anchor_004 (Stillgrave, kragmar_stillgrave_hollow) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 782 / 192 | -1937,1948 → -1936,1760 |
| 23 | secondary | anchor_020 (Ossuary Ledgerstead, kragmar_ossuary_reach) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 324 / 148 | -2210,1646 → -2064,1650 |
| 26 | secondary | anchor_039 (Ashveil Watch, kragmar_blackwind_rise) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 584 / 130 | -2022,1118 → -2031,1233 |
| 31 | secondary | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | anchor_022 (Speargrass Wellhold, kragmar_speargrass_reach) | 802 / 266 | -1535,1649 → -1346,1561 |
| 42 | trail | anchor_038 (Boneledger Post, kragmar_ossuary_reach) | joins road 26 | 276 / 42 | -2045,1152 → -2010,1133 |
| 56 | trail | anchor_055 (Mournfen Bandit Camp, kragmar_mournfen) | joins road 15 | 275 / 136 | -1552,1906 → -1454,1819 |
| 195 | secondary | end:31 | gate_east | 123 / 124 | -1535,1649 → -1591,1558 |
| 196 | primary | end:15 | joins road 195 | 124 / 124 | -1537,1762 → -1552,1647 |
| 197 | primary | end:17 | gate_south | 114 / 114 | -1936,1760 → -1876,1670 |
| 198 | secondary | end:23 | gate_west | 121 / 122 | -2064,1650 → -2005,1557 |
| 199 | secondary | end:26 | gate_north | 226 / 224 | -2031,1233 → -1866,1358 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

Capital streets (avenues and lanes) inside the city: 17.

