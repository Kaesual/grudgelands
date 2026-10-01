# Highcourt (`elandor_highcourt`)

Zone 8 · capital zone · accord · race region **human** · levels **20-30** · peaceful · relief `rolling_hills` · seed 42

Map: [maps/elandor_highcourt.png](maps/elandor_highcourt.png). Machine-readable: [elandor_highcourt.json](elandor_highcourt.json). Coordinates are world nodes (x east, z north, y up).

Race track (human): step 3 of the track Dawnmere Fields → Goldmead Vale → Highcourt → Whitebridge Shire → Ashenward March.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -552..488, z -1892..-1060 (centroid -33, -1486) |
| Land area | 635264 nodes² (≈ 0.64 km²) |
| Hub point (authored) | 0, -1500 |
| Height above sea | min 22, p10 36, median 46, p90 76, max 151 |
| Slope | 2.2% steep (>1 node/node), 0.1% cliff (>2) |
| Biomes (measured) | meadows 81.3%, deep_forest 18.3%, swamp 0.3%, elf_forest 0.1% |
| Neighbours (land border) | elandor_ashenward_march (1336 nodes, mid -25,-1145), elandor_goldmead_vale (1452 nodes, mid -24,-1817), elandor_lorindor (484 nodes, mid 461,-1465), elandor_whitebridge_shire (740 nodes, mid -502,-1554) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 8448 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 11248 nodes² |
| Protected / drift band | 21.0% of land protected (towns, villages, camps/POIs, road corridors); 8.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at); capital palettes are empty today, so no ambient mobs spawn anywhere in the zone.

Share of land per level: L20 10.1%, L21 11.2%, L22 11.9%, L23 8.9%, L24 9.0%, L25 8.8%, L26 8.5%, L27 8.7%, L28 8.4%, L29 7.0%, L30 7.4%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_008 | capital | Highcourt | 0 | 41 | -1500 | 24 | - |

## Protected areas

- Capital city (seed-dependent outline): box x -218..222, z -1742..-1348, area 127528 nodes²; 79.9% of the zone's land lies outside the city. Gates: east 185,-1467, south -69,-1372, west -186,-1537, north -21,-1690.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Highcourt (`highcourt`, anchor_008) at 0, 41, -1500

Residents/guards: gear_display 3, guard_patrol 56, guard_post 19, housing_manager 1, idle 134, innkeeper 1, king 1, mount_display 4, public_station 7, quest 3, riding_trainer 1, trainer 8, vendor 7, waypoint 1, work 36.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| king | king |  | 0, 47, -1468 | - |
| vendor_race | vendor | vendor kind: race | 42, 42, -1493 | - |
| vendor_general | vendor | vendor kind: general | 42, 42, -1487 | - |
| chapel_quest | quest giver | Mariel Waybook | -22, 42, -1473 | r20_human_capital_services, r20_human_capital_stores, r20_human_journey_01 |
| travel_waypoint | waypoint |  | 22, 42, -1522 | - |
| market_stable/market_stable_mount_1 | mount display |  | 12, 42, -1562 | - |
| market_stable/market_stable_mount_2 | mount display |  | 12, 42, -1572 | - |
| market_stable/market_stable_mount_3 | mount display |  | 18, 42, -1562 | - |
| market_stable/market_stable_mount_4 | mount display |  | 18, 42, -1572 | - |
| market_stable/market_stable_riding | riding trainer |  | 9, 42, -1567 | - |
| market_workshop/market_workshop_vendor_smith | vendor | vendor kind: smith | 58, 42, -1505 | - |
| market_workshop/market_workshop_weaponsmith | profession trainer | trains: weaponsmith | 65, 42, -1514 | - |
| market_workshop/market_workshop_armorsmith | profession trainer | trains: armorsmith | 61, 42, -1514 | - |
| market_workshop/market_workshop_weapon | gear display |  | 66, 43, -1518 | - |
| market_workshop/market_workshop_armor | gear display |  | 60, 43, -1518 | - |
| market_counting_house/market_counting_house_gate_idle | housing steward |  | 93, 42, -1535 | - |
| market_counting_house/market_counting_house_vendor_tailor | vendor | vendor kind: tailor | 91, 42, -1540 | - |
| market_counting_house/market_counting_house_tailor | profession trainer | trains: tailor | 101, 42, -1533 | - |
| market_store/market_store_vendor_butcher | vendor | vendor kind: butcher | 96, 41, -1510 | - |
| market_store/market_store_leatherworker | profession trainer | trains: leatherworker | 105, 41, -1504 | - |
| martial_wain_shed/martial_wain_shed_woodcarver | profession trainer | trains: woodcarver | -17, 42, -1566 | - |
| lore_archive/lore_archive_goldsmith | profession trainer | trains: goldsmith | -66, 42, -1487 | - |
| lore_archive/lore_archive_jewel | gear display |  | -61, 43, -1484 | - |
| lore_herb_garden/lore_herb_garden_alchemist | profession trainer | trains: alchemist | -96, 43, -1468 | - |
| homes_tavern/homes_tavern_gate_idle | innkeeper (respawn bind) |  | 63, 42, -1493 | - |
| homes_bakehouse/homes_bakehouse_vendor_baker | vendor | vendor kind: baker | 38, 41, -1432 | - |
| homes_bakehouse/homes_bakehouse_cooking | profession trainer | trains: cooking | 32, 41, -1424 | - |
| homes_bakehouse/homes_bakehouse_quest_cook | quest giver | Ansel Ovenward | 36, 41, -1424 | r20_human_capital_cook |
| lore_shrine/lore_shrine_quest | quest giver | (free quest socket: no quest NPC bound) | -97, 43, -1492 | - |
| market_pond/market_pond_vendor_fishmonger | vendor | vendor kind: fishmonger | 131, 46, -1608 | - |

Public stations: market_workshop/market_workshop_station (forge), market_counting_house/market_counting_house_station (tailor_bench), market_store/market_store_station (tanning_rack), martial_wain_shed/martial_wain_shed_station (carving_bench), lore_archive/lore_archive_station (jewellers_bench), lore_herb_garden/lore_herb_garden_station (brewing_stand), homes_bakehouse/homes_bakehouse_station (furnace).

Distances: zone edge N 440 (elandor_ashenward_march), S 352 (elandor_goldmead_vale), E 480 (elandor_lorindor), W 488 (elandor_whitebridge_shire); nearest other-zone land 337 S; sea 764 SE; sea-beach sand 713 SE; nearest road 50.
Nearest hubs (straight / by road): Goldmead Bandit Camp 577 / 828; Goldmead Outpost 555 / 866; Goldmead Village 534 / 880; Oakspan Tollhouse 661 / 948; Cinderline Watch 738 / 1192.

### Current quests (4, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_human_capital_cook | Bread for the Late Arrivals | Ansel Ovenward (Highcourt) | 10 | bring 5 mobs:meat_raw | 380 | - |
| r20_human_capital_services | The Ovenward Welcome | Mariel Waybook (Highcourt) | 10 | talk to Ansel Ovenward (highcourt) | 285 | r20_human_capital_intro |
| r20_human_capital_stores | Stone for the River Watch | Mariel Waybook (Highcourt) | 20 | bring 12 default:cobble | 780 | - |
| r20_human_journey_01 | Word for Merren Oakstamp | Mariel Waybook (Highcourt) | 21 | talk to Merren Oakstamp (r20_anchor_016) | 615 | - |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

Empty palette: no ambient surface mobs.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 1 | primary | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | anchor_008 (Highcourt, elandor_highcourt) | 1434 / 162 | -428,-1234 → -272,-1247 |
| 2 | primary | anchor_008 (Highcourt, elandor_highcourt) | anchor_009 (Lethariel, elandor_lethariel) | 1355 / 170 | 273,-1358 → 433,-1394 |
| 4 | primary | anchor_002 (Dawnmere, elandor_dawnmere_fields) | anchor_008 (Highcourt, elandor_highcourt) | 796 / 76 | 132,-1833 → 128,-1760 |
| 7 | secondary | anchor_015 (Goldmead Village, elandor_goldmead_vale) | anchor_008 (Highcourt, elandor_highcourt) | 277 / 140 | -158,-1884 → -207,-1759 |
| 38 | trail | anchor_034 (Petalbank Wardenry, elandor_lorindor) | joins road 2 | 488 / 136 | 408,-1271 → 352,-1392 |
| 67 | trail | anchor_067 (Siltbasket Camp, elandor_whitebridge_shire) | joins road 7 | 500 / 40 | -546,-1807 → -513,-1826 |
| 86 | primary | end:2 | gate_east | 158 / 160 | 273,-1358 → 193,-1467 |
| 87 | primary | end:1 | gate_south | 252 / 250 | -272,-1247 → -69,-1364 |
| 88 | primary | end:4 | gate_north | 179 / 180 | 128,-1760 → -21,-1698 |
| 89 | secondary | end:7 | gate_north | 260 / 260 | -207,-1759 → -21,-1698 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

Capital streets (avenues and lanes) inside the city: 15.

