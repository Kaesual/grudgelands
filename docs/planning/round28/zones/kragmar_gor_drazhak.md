# Gor Drazhak (`kragmar_gor_drazhak`)

Zone 24 · capital zone · throng · race region **orc** · levels **20-30** · peaceful · relief `plateau` · seed 42

Map: [maps/kragmar_gor_drazhak.png](maps/kragmar_gor_drazhak.png). Machine-readable: [kragmar_gor_drazhak.json](kragmar_gor_drazhak.json). Coordinates are world nodes (x east, z north, y up).

Race track (orc): step 3 of the track Sunscar Flats → Redtusk Savanna → Gor Drazhak → Speargrass Reach → Bannerbreak Mesa.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -500..540, z 1064..1872 (centroid 30, 1461) |
| Land area | 702960 nodes² (≈ 0.70 km²) |
| Hub point (authored) | 0, 1500 |
| Height above sea | min 28, p10 53, median 66, p90 100, max 153 |
| Slope | 3.6% steep (>1 node/node), 0.1% cliff (>2) |
| Biomes (measured) | savanna 59.5%, badlands 39.9%, deep_jungle 0.3%, jungle_edge 0.3%, swamp 0.0% |
| Neighbours (land border) | kragmar_bannerbreak_mesa (1216 nodes, mid 10,1102), kragmar_redtusk_savanna (1240 nodes, mid 8,1819), kragmar_speargrass_reach (684 nodes, mid -478,1404), kragmar_whispering_reedlands (760 nodes, mid 518,1504) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 4592 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 9008 nodes² |
| Protected / drift band | 19.9% of land protected (towns, villages, camps/POIs, road corridors); 10.9% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at); its spawn regions decide where mobs stand.

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

Residents/guards: gear_display 3, guard_patrol 50, guard_post 21, housing_manager 1, idle 167, innkeeper 1, king 1, mount_display 4, public_station 7, quest 3, riding_trainer 1, shipwright 1, trainer 8, vendor 7, waypoint 1, work 53.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| king | king |  | 0, 67, 1532 | - |
| skull_hall_quest | quest giver | Thorga Roadspeaker | -38, 62, 1521 | gd_front_01, gd_front_02, gd_front_island, gor_drazhak_bounty, gor_drazhak_muster_01, gor_drazhak_muster_02, gor_drazhak_muster_03, gor_drazhak_muster_04 |
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
| war_beast_pen/war_beast_pen_shipwright | shipwright |  | 114, 61, 1508 | - |
| bone_herb_house/bone_herb_house_alchemist | profession trainer | trains: alchemist | 56, 65, 1601 | - |
| warren_clan_house/warren_clan_house_gate_idle | innkeeper (respawn bind) |  | -61, 60, 1570 | - |
| warren_cook_court/warren_cook_court_cooking | profession trainer | trains: cooking | -87, 62, 1518 | - |
| warren_cook_court/warren_cook_court_quest_cook | quest giver | Gorla Longladle | -87, 62, 1522 | gor_drazhak_dispatch_01, gor_drazhak_dispatch_02, gor_drazhak_provisions_01 |
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
Nearest hubs (straight / by road): Redtusk Village 512 / 675; Cutgrass Watch 696 / 982; Redtusk Bandit Camp 577 / 992; Red Ramp Post 729 / 1025; Reedvoice Station 732 / 1267.

### Current quests (11, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| gor_drazhak_muster_01 | A Sentry Needs Both Feet | Thorga Roadspeaker (Gor Drazhak) | 19 | kill 8 dust_stinger [in kragmar_gor_drazhak/steppe] | 585 | - |
| gor_drazhak_dispatch_01 | Spears Out, Word Back | Gorla Longladle (Gor Drazhak) | 21 | talk to Brakka Jarward (r20_anchor_022) | 203 | gor_drazhak_muster_01 |
| gor_drazhak_dispatch_02 | Salt Keeps a Friendship | Gorla Longladle (Gor Drazhak) | 22 | talk to Taleko Drycord (r20_anchor_024) | 210 | gor_drazhak_muster_01 |
| gor_drazhak_provisions_01 | The Ladle Commands | Gorla Longladle (Gor Drazhak) | 22 | bring 8 mobs:meat_raw; bring 2 grug_mobs:braided_sinew | 580 | - |
| gor_drazhak_muster_02 | Optional: The Last Laugh Costs Extra | Thorga Roadspeaker (Gor Drazhak) | 23 | kill 8 dustpack_hyena [in kragmar_gor_drazhak/badlands] | 675 | gor_drazhak_muster_01 |
| gor_drazhak_muster_03 | His Profit, Our Empty Bowls | Thorga Roadspeaker (Gor Drazhak) | 27 | kill 6 toll_bandit_archer [in kragmar_gor_drazhak/tollcamp]; kill 1 ration_broker_garr | 1073 | gor_drazhak_muster_01 |
| gor_drazhak_bounty | Bounty: A Toll Paid in Arrows (repeatable) | Thorga Roadspeaker (Gor Drazhak) | 28 | kill 6 toll_bandit_archer [in kragmar_gor_drazhak/tollcamp] | 425 | gor_drazhak_muster_03 |
| gor_drazhak_muster_04 | Your Place in the Line | Thorga Roadspeaker (Gor Drazhak) | 29 | talk to Drek Rampbinder (r20_anchor_043) | 255 | gor_drazhak_muster_03 |
| gd_front_01 | Give the Road Some Fangs | Thorga Roadspeaker (Gor Drazhak) | 41 | bring 2 grug_mobs:scorch_venom | 720 | - |
| gd_front_02 | Wear the Teeth This Time | Thorga Roadspeaker (Gor Drazhak) | 43 | kill 4 warpack_hyena [in front_shattered_line/trenches]; bring 2 grug_mobs:siegepack_fang | 1125 | gd_front_01 |
| gd_front_island | Bounty: Dead Weight Ashore (repeatable) | Thorga Roadspeaker (Gor Drazhak) | 60 | kill 8 last_watch_husk [in front_stormscale_summit/wreck_shore] | 0 | gd_front_02 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| debtbound_husk | Debtbound Sun-Dried Husk | aggressive | 4.0% of land, L20-25 | 39.7% of land, L20-25 |  |
| dust_stinger | Dust-Stinger Scorpion | aggressive | - | 89.8% of land, L20-30 |  |
| dustpack_hyena | Dustpack Hyena | aggressive | 84.6% of land, L20-30 | 4.9% of land, L20-27 |  |
| stubborn_husk | Tithe Mummy | aggressive | 30.3% of land, L26-30 | 30.3% of land, L26-30 |  |
| toll_bandit | Toll Bandit | aggressive | - | 25.4% of land, L20-23 |  |
| toll_bandit_archer | Toll Bandit Archer | aggressive | 1.3% of land, L28-30 | 1.3% of land, L28-30 |  |
| watchful_zebra | Waterhole Zebra | neutral | 65.9% of land, L20-27 | - |  |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 15 | primary | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 1440 / 224 | -481,1536 → -272,1582 |
| 16 | primary | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | anchor_012 (Kezamba, kragmar_kezamba) | 1364 / 266 | 272,1634 → 521,1670 |
| 18 | primary | anchor_005 (Sunscar, kragmar_sunscar_flats) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 799 / 80 | -101,1834 → -112,1760 |
| 27 | secondary | anchor_043 (Red Ramp Post, kragmar_bannerbreak_mesa) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 391 / 124 | -290,1118 → -256,1232 |
| 29 | primary | anchor_008 (Highcourt, elandor_highcourt) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 2860 / 160 | -36,1078 → -47,1232 |
| 48 | trail | anchor_046 (Reedvoice Station, kragmar_whispering_reedlands) | joins road 16 | 522 / 312 | 509,1344 → 445,1639 |
| 58 | trail | anchor_057 (Redtusk Bandit Camp, kragmar_redtusk_savanna) | joins road 16 | 349 / 216 | 327,1842 → 353,1634 |
| 134 | primary | end:16 | gate_east | 106 / 108 | 272,1634 → 182,1586 |
| 135 | primary | end:18 | gate_south | 97 / 100 | -112,1760 → -69,1694 |
| 136 | primary | end:15 | gate_west | 184 / 184 | -272,1582 → -147,1503 |
| 137 | primary | end:29 | gate_north | 100 / 102 | -47,1232 → 12,1302 |
| 138 | secondary | end:27 | joins road 137 | 232 / 234 | -256,1232 → -36,1260 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

Capital streets (avenues and lanes) inside the city: 19.

