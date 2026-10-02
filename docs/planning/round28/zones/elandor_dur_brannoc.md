# Dur Brannoc (`elandor_dur_brannoc`)

Zone 3 · capital zone · accord · race region **dwarf** · levels **20-30** · peaceful · relief `plateau` · seed 42

Map: [maps/elandor_dur_brannoc.png](maps/elandor_dur_brannoc.png). Machine-readable: [elandor_dur_brannoc.json](elandor_dur_brannoc.json). Coordinates are world nodes (x east, z north, y up).

Race track (dwarf): step 3 of the track Hearthpine Vale → Copperfell Foothills → Dur Brannoc → Frostbarrow Shelf → Stormvault Heights.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2160..-1216, z -1888..-1060 (centroid -1709, -1488) |
| Land area | 628160 nodes² (≈ 0.63 km²) |
| Hub point (authored) | -1800, -1500 |
| Height above sea | min 48, p10 64, median 76, p90 104, max 236 |
| Slope | 6.4% steep (>1 node/node), 1.0% cliff (>2) |
| Biomes (measured) | pine_hills 51.8%, crags 47.1%, crags_snowy 0.3%, deep_forest 0.3%, meadows 0.2%, swamp 0.2% |
| Neighbours (land border) | elandor_copperfell_foothills (1160 nodes, mid -1693,-1854), elandor_frostbarrow_shelf (932 nodes, mid -2121,-1455), elandor_stormvault_heights (844 nodes, mid -1706,-1086), elandor_whitebridge_shire (920 nodes, mid -1271,-1499) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 7584 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 11920 nodes² |
| Protected / drift band | 21.8% of land protected (towns, villages, camps/POIs, road corridors); 10.5% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at); its spawn regions decide where mobs stand.

Share of land per level: L20 13.2%, L21 11.1%, L22 12.2%, L23 8.7%, L24 8.4%, L25 8.4%, L26 7.5%, L27 7.4%, L28 7.6%, L29 6.8%, L30 8.5%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_007 | capital | Dur Brannoc | -1800 | 69 | -1500 | 24 | - |

## Protected areas

- Capital city (seed-dependent outline): box x -2042..-1614, z -1700..-1280, area 126664 nodes²; 79.8% of the zone's land lies outside the city. Gates: east -1639,-1573, south -1745,-1388, west -1986,-1555, north -1739,-1668.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Dur Brannoc (`dur_brannoc`, anchor_007) at -1800, 69, -1500

Residents/guards: gear_display 3, guard_patrol 50, guard_post 19, housing_manager 1, idle 125, innkeeper 1, king 1, mount_display 4, public_station 7, quest 3, riding_trainer 1, shipwright 1, trainer 8, vendor 9, waypoint 1, work 54.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| king | king |  | -1800, 75, -1468 | - |
| ancestor_hall_quest | quest giver | Dorrin Gateledger | -1838, 70, -1479 | durbrannoc_front_01, durbrannoc_front_02, durbrannoc_front_bounty, durbrannoc_gate_01, durbrannoc_gate_02, durbrannoc_gate_03, durbrannoc_gate_ashenward, durbrannoc_gate_glassroot, durbrannoc_gate_optional, durbrannoc_gate_stormvault |
| vendor_race | vendor | vendor kind: race | -1757, 70, -1491 | - |
| vendor_general | vendor | vendor kind: general | -1757, 70, -1484 | - |
| travel_waypoint | waypoint |  | -1781, 70, -1522 | - |
| forge_pack_stable/forge_pack_stable_mount_1 | mount display |  | -1871, 70, -1488 | - |
| forge_pack_stable/forge_pack_stable_mount_2 | mount display |  | -1861, 70, -1488 | - |
| forge_pack_stable/forge_pack_stable_mount_3 | mount display |  | -1871, 70, -1482 | - |
| forge_pack_stable/forge_pack_stable_mount_4 | mount display |  | -1861, 70, -1482 | - |
| forge_pack_stable/forge_pack_stable_riding | riding trainer |  | -1866, 70, -1491 | - |
| forge_pack_stable/forge_pack_stable_shipwright | shipwright |  | -1858, 70, -1491 | - |
| forge_smithy/forge_smithy_vendor_smith | vendor | vendor kind: smith | -1805, 70, -1433 | - |
| forge_smithy/forge_smithy_weaponsmith | profession trainer | trains: weaponsmith | -1814, 70, -1440 | - |
| forge_smithy/forge_smithy_armorsmith | profession trainer | trains: armorsmith | -1814, 70, -1436 | - |
| forge_smithy/forge_smithy_weapon | gear display |  | -1818, 71, -1441 | - |
| forge_smithy/forge_smithy_armor | gear display |  | -1818, 71, -1435 | - |
| forge_guild_house/forge_guild_house_gate_idle | housing steward |  | -1820, 69, -1414 | - |
| forge_guild_house/forge_guild_house_tailor | profession trainer | trains: tailor | -1822, 69, -1406 | - |
| forge_ore_yard/forge_ore_yard_goldsmith | profession trainer | trains: goldsmith | -1845, 69, -1408 | - |
| forge_ore_yard/forge_ore_yard_jewel | gear display |  | -1840, 70, -1405 | - |
| forge_store/forge_store_leatherworker | profession trainer | trains: leatherworker | -1902, 72, -1495 | - |
| deep_carvers/deep_carvers_vendor_deep_mason_stall | vendor | vendor kind: mason | -1765, 73, -1576 | - |
| deep_carvers/deep_carvers_woodcarver | profession trainer | trains: woodcarver | -1757, 73, -1585 | - |
| terrace_alehouse/terrace_alehouse_gate_idle | innkeeper (respawn bind) |  | -1674, 75, -1535 | - |
| terrace_brewhouse/terrace_brewhouse_vendor_brewer | vendor | vendor kind: brewer | -1889, 71, -1453 | - |
| terrace_brewhouse/terrace_brewhouse_alchemist | profession trainer | trains: alchemist | -1898, 71, -1461 | - |
| terrace_bakehouse/terrace_bakehouse_vendor_baker | vendor | vendor kind: baker | -1826, 67, -1371 | - |
| terrace_bakehouse/terrace_bakehouse_cooking | profession trainer | trains: cooking | -1833, 67, -1362 | - |
| terrace_bakehouse/terrace_bakehouse_quest_cook | quest giver | Varda Copperpan | -1829, 67, -1362 | durbrannoc_dispatch_01, durbrannoc_dispatch_highcourt, durbrannoc_dispatch_lorindor, durbrannoc_dispatch_whitebridge, durbrannoc_provisions_01, durbrannoc_provisions_bounty, durbrannoc_provisions_optional |
| garrison_armoury/garrison_armoury_vendor_armourer | vendor | vendor kind: armourer | -1869, 70, -1512 | - |
| deep_hall_of_record/deep_hall_of_record_quest | quest giver | (free quest socket: no quest NPC bound) | -1721, 72, -1548 | - |
| deep_memory_hall/deep_memory_hall_vendor_deep_embalmer | vendor | vendor kind: embalmer | -1730, 74, -1609 | - |
| terrace_market/terrace_market_vendor_butcher | vendor | vendor kind: butcher | -1716, 72, -1507 | - |

Public stations: forge_smithy/forge_smithy_station (forge), forge_guild_house/forge_guild_house_station (tailor_bench), forge_ore_yard/forge_ore_yard_station (jewellers_bench), forge_store/forge_store_station (tanning_rack), deep_carvers/deep_carvers_station (carving_bench), terrace_brewhouse/terrace_brewhouse_station (brewing_stand), terrace_bakehouse/terrace_bakehouse_station (furnace).

Distances: zone edge N 440 (elandor_stormvault_heights), S 328 (elandor_copperfell_foothills), E 560 (elandor_whitebridge_shire), W 332 (elandor_frostbarrow_shelf); nearest other-zone land 313 W; sea 673 W; sea-beach sand 677 W; nearest road 50.
Nearest hubs (straight / by road): Copperfell Village 540 / 857; Tarnwatch Fold 609 / 877; Rimebell Watch 559 / 1085; Copperfell Bandit Camp 612 / 1216; Bridgechalk Dig 766 / 1331.

### Current quests (17, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| durbrannoc_gate_01 | Payment Was Final | Dorrin Gateledger (Dur Brannoc) | 20 | kill 8 debtbound_zombie [in elandor_dur_brannoc/pastures] | 520 | - |
| durbrannoc_provisions_01 | A Pie Needs a Middle | Varda Copperpan (Dur Brannoc) | 20 | bring 4 grug_fishing:mire_carp | 260 | - |
| durbrannoc_dispatch_01 | The Other Half of Edda's Order | Varda Copperpan (Dur Brannoc) | 21 | talk to Edda Tarnmantle (r20_anchor_014) | 135 | durbrannoc_gate_01 |
| durbrannoc_dispatch_highcourt | Varda's Recommendation | Varda Copperpan (Dur Brannoc) | 22 | talk to Mariel Waybook (highcourt) | 140 | durbrannoc_dispatch_01 |
| durbrannoc_dispatch_lorindor | Room at Another Hearth | Varda Copperpan (Dur Brannoc) | 22 | talk to Ilwen Petalmeasure (r20_anchor_018) | 140 | durbrannoc_dispatch_01 |
| durbrannoc_dispatch_whitebridge | A Neighbour's Table | Varda Copperpan (Dur Brannoc) | 22 | talk to Merren Oakstamp (r20_anchor_016) | 140 | durbrannoc_dispatch_01 |
| durbrannoc_gate_02 | His Majesty Signed Nothing | Dorrin Gateledger (Dur Brannoc) | 23 | kill 8 toll_bandit_archer or toll_bandit [in elandor_dur_brannoc/tollwood] | 675 | durbrannoc_gate_01 |
| durbrannoc_provisions_optional | Optional: A Ram for the Roast | Varda Copperpan (Dur Brannoc) | 24 | kill 6 hill_ram [in elandor_dur_brannoc/uplands] | 543 | durbrannoc_provisions_01 |
| durbrannoc_gate_03 | Close Brakk's Account | Dorrin Gateledger (Dur Brannoc) | 27 | kill 1 ore_factor_brakk; bring 2 grug_mobs:clasped_purse | 1020 | durbrannoc_gate_02 |
| durbrannoc_gate_optional | Optional: Tithes for the Dead | Dorrin Gateledger (Dur Brannoc) | 27 | kill 6 stubborn_zombie [in elandor_dur_brannoc/heights] | 595 | durbrannoc_gate_02 |
| durbrannoc_provisions_bounty | Bounty: Supper for a City (repeatable) | Varda Copperpan (Dur Brannoc) | 28 | kill 6 hill_ram [in elandor_dur_brannoc/heights] | 425 | durbrannoc_provisions_01 |
| durbrannoc_gate_ashenward | Beyond Our Own Gate | Dorrin Gateledger (Dur Brannoc) | 29 | talk to Toren Waterbarrel (r20_anchor_031) | 175 | durbrannoc_gate_03 |
| durbrannoc_gate_glassroot | The Weight of Our Word | Dorrin Gateledger (Dur Brannoc) | 29 | talk to Faeris Rootbinder (r20_anchor_036) | 175 | durbrannoc_gate_03 |
| durbrannoc_gate_stormvault | Stone Enough to Stand On | Dorrin Gateledger (Dur Brannoc) | 29 | talk to Borin Splitbolt (r20_anchor_027) | 175 | durbrannoc_gate_03 |
| durbrannoc_front_01 | Optional: A Blank Space on the Clan's Map | Dorrin Gateledger (Dur Brannoc) | 60 | kill 6 crown_crag_eagle [in front_wyrmglass_crown/spires] | 0 | - |
| durbrannoc_front_02 | Group: Silence for the Clan | Dorrin Gateledger (Dur Brannoc) | 60 | kill 1 rime_bell_warden | 0 | durbrannoc_front_01 |
| durbrannoc_front_bounty | Bounty: The Clan's Standing Order (repeatable) | Dorrin Gateledger (Dur Brannoc) | 60 | bring 4 grug_mobs:rime_sinew | 0 | durbrannoc_front_01 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| debtbound_zombie | Debtbound Zombie | aggressive | - | 53.7% of land, L20-25 |  |
| hill_ram | Hill Ram | neutral | 79.6% of land, L21-30 | - |  |
| ore_thieving_goblin | Ore-Thieving Goblin | aggressive | 1.4% of land, L28-30 | 1.4% of land, L28-30 |  |
| rubble_goblin_slinger | Rubble Goblin Slinger | aggressive | 1.4% of land, L28-30 | 1.4% of land, L28-30 |  |
| stubborn_zombie | Tithe Revenant | aggressive | - | 52.2% of land, L26-30 |  |
| surefoot_ibex | Surefoot Ibex | neutral | 83.1% of land, L20-30 | - |  |
| toll_bandit | Toll Bandit | aggressive | - | 27.3% of land, L20-25 |  |
| toll_bandit_archer | Toll Bandit Archer | aggressive | - | 16.3% of land, L26-27 |  |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 1 | primary | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | anchor_008 (Highcourt, elandor_highcourt) | 1402 / 334 | -1536,-1633 → -1235,-1525 |
| 3 | primary | anchor_001 (Hearthpine, elandor_hearthpine_vale) | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | 825 / 88 | -1702,-1825 → -1648,-1760 |
| 9 | secondary | anchor_014 (Tarnwatch Fold, elandor_frostbarrow_shelf) | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | 477 / 88 | -2149,-1700 → -2064,-1697 |
| 12 | secondary | anchor_027 (Splitbolt Station, elandor_stormvault_heights) | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | 1736 / 200 | -1370,-1214 → -1536,-1280 |
| 33 | trail | anchor_026 (Rimebell Watch, elandor_frostbarrow_shelf) | joins road 9 | 628 / 424 | -2114,-1311 → -2128,-1696 |
| 111 | primary | end:1 | gate_east | 149 / 150 | -1536,-1633 → -1631,-1573 |
| 112 | secondary | end:12 | gate_south | 290 / 288 | -1536,-1280 → -1745,-1380 |
| 113 | secondary | end:9 | gate_west | 172 / 172 | -2064,-1697 → -1994,-1555 |
| 114 | primary | end:3 | gate_north | 144 / 144 | -1648,-1760 → -1739,-1676 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

Capital streets (avenues and lanes) inside the city: 19.

