# Kezamba (`kragmar_kezamba`)

Zone 29 · capital zone · throng · race region **troll** · levels **20-30** · peaceful · relief `plateau` · seed 42

Map: [maps/kragmar_kezamba.png](maps/kragmar_kezamba.png). Machine-readable: [kragmar_kezamba.json](kragmar_kezamba.json). Coordinates are world nodes (x east, z north, y up).

Race track (troll): step 3 of the track Kapok Cradle → Raincall Basin → Kezamba → Whispering Reedlands → Totemwater Reach → Thunderroot Wilds.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 1268..2144, z 1004..1896 (centroid 1698, 1459) |
| Land area | 617024 nodes² (≈ 0.62 km²) |
| Hub point (authored) | 1800, 1500 |
| Height above sea | min 25, p10 34, median 46, p90 75, max 121 |
| Slope | 0.9% steep (>1 node/node), 0.0% cliff (>2) |
| Biomes (measured) | jungle_edge 83.6%, deep_jungle 9.9%, swamp 6.3%, badlands_east 0.2% |
| Neighbours (land border) | kragmar_raincall_basin (1004 nodes, mid 1729,1861), kragmar_thunderroot_wilds (864 nodes, mid 1736,1032), kragmar_totemwater_reach (848 nodes, mid 2118,1412), kragmar_whispering_reedlands (1028 nodes, mid 1321,1472) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 11712 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 34720 nodes² |
| Protected / drift band | 20.2% of land protected (towns, villages, camps/POIs, road corridors); 9.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at); its spawn regions decide where mobs stand.

Share of land per level: L20 12.8%, L21 12.0%, L22 10.1%, L23 6.7%, L24 7.7%, L25 8.6%, L26 8.5%, L27 8.0%, L28 8.3%, L29 7.8%, L30 9.4%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_012 | capital | Kezamba | 1800 | 36 | 1500 | 24 | - |

## Protected areas

- Capital city (seed-dependent outline): box x 1550..2032, z 1284..1726, area 146100 nodes²; 76.3% of the zone's land lies outside the city. Gates: east 1933,1484, south 1755,1633, west 1572,1561, north 1823,1336.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Kezamba (`kezamba`, anchor_012) at 1800, 36, 1500

Residents/guards: gear_display 3, guard_patrol 60, guard_post 13, housing_manager 1, idle 103, innkeeper 1, king 1, mount_display 4, public_station 7, quest 2, riding_trainer 1, trainer 8, vendor 7, waypoint 1, work 53.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| king | king |  | 1811, 42, 1469 | - |
| shrine_quest | quest giver | Nalo Pathdrum | 1762, 37, 1527 | r20_troll_capital_services, r20_troll_capital_stores, r20_troll_journey_01 |
| vendor_race | vendor | vendor kind: race | 1776, 37, 1487 | - |
| vendor_general | vendor | vendor kind: general | 1776, 37, 1493 | - |
| travel_waypoint | waypoint |  | 1762, 37, 1476 | - |
| vendor_fishmonger | vendor | vendor kind: fishmonger | 1775, 37, 1521 | - |
| vine_longhouse/vine_longhouse_gate_idle | innkeeper (respawn bind) |  | 1727, 37, 1543 | - |
| vine_herbalist/vine_herbalist_vendor_herbalist | vendor | vendor kind: herbalist | 1714, 39, 1553 | - |
| vine_herbalist/vine_herbalist_alchemist | profession trainer | trains: alchemist | 1708, 39, 1555 | - |
| canopy_armoury/canopy_armoury_weaponsmith | profession trainer | trains: weaponsmith | 1758, 37, 1408 | - |
| canopy_armoury/canopy_armoury_armorsmith | profession trainer | trains: armorsmith | 1754, 37, 1408 | - |
| canopy_armoury/canopy_armoury_weapon | gear display |  | 1759, 38, 1404 | - |
| canopy_armoury/canopy_armoury_armor | gear display |  | 1753, 38, 1404 | - |
| canopy_stable/canopy_stable_mount_1 | mount display |  | 1697, 37, 1481 | - |
| canopy_stable/canopy_stable_mount_2 | mount display |  | 1687, 37, 1481 | - |
| canopy_stable/canopy_stable_mount_3 | mount display |  | 1697, 37, 1475 | - |
| canopy_stable/canopy_stable_mount_4 | mount display |  | 1687, 37, 1475 | - |
| canopy_stable/canopy_stable_riding | riding trainer |  | 1692, 37, 1484 | - |
| totem_scriptorium/totem_scriptorium_goldsmith | profession trainer | trains: goldsmith | 1873, 38, 1476 | - |
| totem_scriptorium/totem_scriptorium_jewel | gear display |  | 1868, 39, 1473 | - |
| shore_tailor/shore_tailor_gate_idle | housing steward |  | 1725, 38, 1518 | - |
| shore_tailor/shore_tailor_vendor_tailor | vendor | vendor kind: tailor | 1721, 38, 1517 | - |
| shore_tailor/shore_tailor_tailor | profession trainer | trains: tailor | 1723, 38, 1523 | - |
| shore_store/shore_store_leatherworker | profession trainer | trains: leatherworker | 1716, 40, 1590 | - |
| shore_smokehouse/shore_smokehouse_cooking | profession trainer | trains: cooking | 1684, 40, 1554 | - |
| shore_smokehouse/shore_smokehouse_quest_cook | quest giver | Teshani Smokereed | 1688, 40, 1554 | r20_troll_capital_cook |
| shore_carvers/shore_carvers_woodcarver | profession trainer | trains: woodcarver | 1749, 39, 1588 | - |
| shore_market/shore_market_vendor_brewer | vendor | vendor kind: brewer | 1652, 34, 1489 | - |
| shore_butcher/shore_butcher_vendor_butcher | vendor | vendor kind: butcher | 1629, 36, 1501 | - |

Public stations: vine_herbalist/vine_herbalist_station (brewing_stand), canopy_armoury/canopy_armoury_station (forge), totem_scriptorium/totem_scriptorium_station (jewellers_bench), shore_tailor/shore_tailor_station (tailor_bench), shore_store/shore_store_station (tanning_rack), shore_smokehouse/shore_smokehouse_station (furnace), shore_carvers/shore_carvers_station (carving_bench).

Distances: zone edge N 364 (kragmar_raincall_basin), S 492 (kragmar_thunderroot_wilds), E 296 (kragmar_totemwater_reach), W 528 (kragmar_whispering_reedlands); nearest other-zone land 296 E; sea 782 E; sea-beach sand 739 E; nearest road 50.
Nearest hubs (straight / by road): Raincall Bandit Camp 560 / 1008; Thunderstep Watch 836 / 1089; Totemwater Post 618 / 1158; Whisperreed Landing 930 / 1244; Reedstone Cut 798 / 1384.

### Current quests (4, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_troll_capital_cook | Smoke Above the Cenote | Teshani Smokereed (Kezamba) | 10 | bring 5 mobs:meat_raw | 380 | - |
| r20_troll_capital_services | The Smokereed Welcome | Nalo Pathdrum (Kezamba) | 10 | talk to Teshani Smokereed (kezamba) | 285 | r20_troll_capital_intro |
| r20_troll_capital_stores | Boards for the Rain Stores | Nalo Pathdrum (Kezamba) | 20 | bring 10 default:junglewood | 780 | - |
| r20_troll_journey_01 | Word for Taleko Drycord | Nalo Pathdrum (Kezamba) | 21 | talk to Taleko Drycord (r20_anchor_024) | 615 | - |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| debtbound_zombie | Debtbound Zombie | aggressive | - | 39.9% of land, L24-25 |  |
| furrow_boar | Furrow Boar | neutral | 66.0% of land, L21-24 | - |  |
| monstrous_boar | Razorback | aggressive | 64.5% of land, L25-30 | - |  |
| reed_fang_viper | Reed-Fang Viper | aggressive | - | 94.6% of land, L20-30 |  |
| reed_jungle_lynx | Reed Jungle Lynx | aggressive | 28.6% of land, L28-30 | - |  |
| reed_tapir | Reed Tapir | neutral | 34.0% of land, L20-27 | - |  |
| stubborn_zombie | Tithe Revenant | aggressive | - | 32.5% of land, L26-30 |  |
| toll_bandit | Toll Bandit | aggressive | - | 30.0% of land, L20-23 |  |
| toll_bandit_archer | Toll Bandit Archer | aggressive | 1.5% of land, L28-30 | 1.5% of land, L28-30 |  |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 16 | primary | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | anchor_012 (Kezamba, kragmar_kezamba) | 1364 / 250 | 1294,1771 → 1536,1758 |
| 19 | primary | anchor_006 (Kapok, kragmar_kapok_cradle) | joins road 16 | 984 / 128 | 1405,1885 → 1422,1774 |
| 28 | secondary | anchor_048 (Thunderstep Watch, kragmar_thunderroot_wilds) | anchor_012 (Kezamba, kragmar_kezamba) | 613 / 218 | 1954,1052 → 1840,1232 |
| 30 | secondary | anchor_012 (Kezamba, kragmar_kezamba) | anchor_023 (Raincall Village, kragmar_raincall_basin) | 352 / 132 | 1712,1760 → 1765,1861 |
| 49 | trail | anchor_047 (Totemwater Post, kragmar_totemwater_reach) | joins road 28 | 561 / 268 | 2141,1248 → 1913,1133 |
| 175 | secondary | end:30 | gate_south | 159 / 160 | 1712,1760 → 1755,1639 |
| 176 | primary | end:16 | gate_west | 220 / 222 | 1536,1758 → 1566,1561 |
| 177 | secondary | end:28 | gate_north | 104 / 106 | 1840,1232 → 1823,1330 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

Capital streets (avenues and lanes) inside the city: 19.

