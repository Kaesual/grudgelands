# Gor Drazhak (`kragmar_gor_drazhak`)

Zone 24 · capital zone · throng · race region **orc** · levels **20-30** · peaceful · relief `plateau` · seed 42

Map: [maps/kragmar_gor_drazhak.png](maps/kragmar_gor_drazhak.png). Machine-readable: [kragmar_gor_drazhak.json](kragmar_gor_drazhak.json). Coordinates are world nodes (x east, z north, y up).

Race track (orc): step 3 of the track Sunscar Flats → Redtusk Savanna → Gor Drazhak → Speargrass Reach → Bannerbreak Mesa.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -500..540, z 1064..1872 (centroid 30, 1461) |
| Land area | 702976 nodes² (≈ 0.70 km²) |
| Hub point (authored) | 0, 1500 |
| Height above sea | min 28, p10 53, median 66, p90 100, max 153 |
| Slope | 3.6% steep (>1 node/node), 0.1% cliff (>2) |
| Biomes (measured) | savanna 59.5%, badlands 39.9%, deep_jungle 0.3%, jungle_edge 0.3%, swamp 0.0% |
| Neighbours (land border) | kragmar_bannerbreak_mesa (1216 nodes, mid 10,1102), kragmar_redtusk_savanna (1240 nodes, mid 8,1819), kragmar_speargrass_reach (684 nodes, mid -478,1404), kragmar_whispering_reedlands (760 nodes, mid 518,1504) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 4656 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 8992 nodes² |
| Protected / drift band | 19.7% of land protected (towns, villages, camps/POIs, road corridors); 10.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at); capital palettes are empty today, so no ambient mobs spawn anywhere in the zone.

Share of land per level: L20 10.9%, L21 10.6%, L22 11.0%, L23 8.4%, L24 8.4%, L25 8.3%, L26 8.3%, L27 8.2%, L28 8.4%, L29 8.4%, L30 9.0%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_011 | capital | Gor Drazhak | 0 | 61 | 1500 | 24 | - |

## Protected areas

- Capital city (seed-dependent outline): box x -162..248, z 1288..1716, area 129128 nodes²; 81.6% of the zone's land lies outside the city. Gates: east 175,1586, south -69,1687, west -140,1503, north 12,1309.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Gor Drazhak (`gor_drazhak`, anchor_011) at 0, 61, 1500

Residents/guards: gear_display 3, guard_patrol 50, guard_post 21, housing_manager 1, idle 167, innkeeper 1, king 1, mount_display 4, public_station 7, quest 3, riding_trainer 1, trainer 8, vendor 7, waypoint 1, work 53.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| king | king |  | 0, 67, 1532 | - |
| skull_hall_quest | quest giver | Thorga Roadspeaker | -38, 62, 1521 | r20_orc_capital_services, r20_orc_capital_stores, r20_orc_journey_01 |
| vendor_race | vendor | vendor kind: race | 43, 62, 1509 | - |
| vendor_general | vendor | vendor kind: general | 43, 62, 1516 | - |
| travel_waypoint | waypoint |  | 19, 62, 1478 | - |
| bazaar_tannery/bazaar_tannery_vendor_tanner | vendor | vendor kind: tanner | -35, 59, 1399 | - |
| bazaar_tannery/bazaar_tannery_leatherworker | profession trainer | trains: leatherworker | -27, 59, 1403 | - |
| bazaar_carver/bazaar_carver_woodcarver | profession trainer | trains: woodcarver | -81, 60, 1461 | - |
| war_beast_pen/war_beast_pen_mount_1 | mount display |  | 117, 61, 1521 | - |
| war_beast_pen/war_beast_pen_mount_2 | mount display |  | 117, 61, 1511 | - |
| war_beast_pen/war_beast_pen_mount_3 | mount display |  | 123, 61, 1521 | - |
| war_beast_pen/war_beast_pen_mount_4 | mount display |  | 123, 61, 1511 | - |
| war_beast_pen/war_beast_pen_riding | riding trainer |  | 114, 61, 1516 | - |
| bone_herb_house/bone_herb_house_alchemist | profession trainer | trains: alchemist | 56, 65, 1601 | - |
| warren_clan_house/warren_clan_house_gate_idle | innkeeper (respawn bind) |  | -61, 60, 1570 | - |
| warren_cook_court/warren_cook_court_cooking | profession trainer | trains: cooking | -87, 62, 1518 | - |
| warren_cook_court/warren_cook_court_quest_cook | quest giver | Gorla Longladle | -87, 62, 1522 | r20_orc_capital_cook |
| warren_weaver/warren_weaver_gate_idle | housing steward |  | -28, 62, 1572 | - |
| warren_weaver/warren_weaver_tailor | profession trainer | trains: tailor | -26, 62, 1566 | - |
| bazaar_armourer/bazaar_armourer_vendor_armourer | vendor | vendor kind: armourer | 94, 62, 1499 | - |
| bazaar_armourer/bazaar_armourer_goldsmith | profession trainer | trains: goldsmith | 88, 62, 1490 | - |
| bazaar_armourer/bazaar_armourer_jewel | gear display |  | 85, 63, 1495 | - |
| bazaar_smithy/bazaar_smithy_vendor_smith | vendor | vendor kind: smith | 57, 59, 1407 | - |
| bazaar_smithy/bazaar_smithy_weaponsmith | profession trainer | trains: weaponsmith | 66, 59, 1403 | - |
| bazaar_smithy/bazaar_smithy_armorsmith | profession trainer | trains: armorsmith | 62, 59, 1403 | - |
| bazaar_smithy/bazaar_smithy_weapon | gear display |  | 67, 60, 1399 | - |
| bazaar_smithy/bazaar_smithy_armor | gear display |  | 61, 60, 1399 | - |
| bone_spirit_hall/bone_spirit_hall_quest | quest giver | (free quest socket: no quest NPC bound) | 43, 62, 1580 | - |
| bazaar_butcher/bazaar_butcher_vendor_butcher | vendor | vendor kind: butcher | 138, 58, 1448 | - |
| bazaar_brewhouse/bazaar_brewhouse_vendor_brewer | vendor | vendor kind: brewer | 34, 58, 1354 | - |

Public stations: bazaar_tannery/bazaar_tannery_station (tanning_rack), bazaar_carver/bazaar_carver_station (carving_bench), bone_herb_house/bone_herb_house_station (brewing_stand), warren_cook_court/warren_cook_court_station (furnace), warren_weaver/warren_weaver_station (tailor_bench), bazaar_armourer/bazaar_armourer_station (jewellers_bench), bazaar_smithy/bazaar_smithy_station (forge).

Distances: zone edge N 352 (kragmar_redtusk_savanna), S 428 (kragmar_bannerbreak_mesa), E 520 (kragmar_whispering_reedlands), W 480 (kragmar_speargrass_reach); nearest other-zone land 343 N; sea 820 NE; sea-beach sand 779 NE; nearest road 50.
Nearest hubs (straight / by road): Redtusk Village 512 / 675; Cutgrass Watch 696 / 982; Redtusk Bandit Camp 577 / 992; Red Ramp Post 729 / 1021; Reedvoice Station 732 / 1267.

### Current quests (4, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_orc_capital_cook | The Longladle Ration | Gorla Longladle (Gor Drazhak) | 10 | bring 5 mobs:meat_raw | 380 | - |
| r20_orc_capital_services | A Bowl at Longladle | Thorga Roadspeaker (Gor Drazhak) | 10 | talk to Gorla Longladle (gor_drazhak) | 285 | r20_orc_capital_intro |
| r20_orc_capital_stores | Stone for the Muster Yard | Thorga Roadspeaker (Gor Drazhak) | 20 | bring 12 default:cobble | 780 | - |
| r20_orc_journey_01 | Word for Brakka Jarward | Thorga Roadspeaker (Gor Drazhak) | 21 | talk to Brakka Jarward (r20_anchor_022) | 615 | - |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

Empty palette: no ambient surface mobs.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 15 | primary | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 1440 / 224 | -481,1536 → -272,1582 |
| 16 | primary | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | anchor_012 (Kezamba, kragmar_kezamba) | 1364 / 266 | 272,1634 → 521,1670 |
| 18 | primary | anchor_005 (Sunscar, kragmar_sunscar_flats) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 799 / 80 | -101,1834 → -112,1760 |
| 27 | secondary | anchor_043 (Red Ramp Post, kragmar_bannerbreak_mesa) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 390 / 124 | -290,1118 → -256,1232 |
| 47 | trail | anchor_046 (Reedvoice Station, kragmar_whispering_reedlands) | joins road 16 | 522 / 312 | 509,1344 → 445,1639 |
| 57 | trail | anchor_057 (Redtusk Bandit Camp, kragmar_redtusk_savanna) | joins road 16 | 349 / 216 | 327,1842 → 353,1634 |
| 58 | trail | anchor_058 (Sunderstrap Camp, kragmar_bannerbreak_mesa) | joins road 27 | 1283 / 186 | -103,1086 → -290,1121 |
| 132 | primary | end:16 | gate_east | 106 / 108 | 272,1634 → 182,1586 |
| 133 | primary | end:18 | gate_south | 97 / 100 | -112,1760 → -69,1694 |
| 134 | primary | end:15 | gate_west | 184 / 184 | -272,1582 → -147,1503 |
| 135 | secondary | end:27 | gate_north | 297 / 296 | -256,1232 → 12,1302 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

Capital streets (avenues and lanes) inside the city: 19.

