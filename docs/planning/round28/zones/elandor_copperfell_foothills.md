# Copperfell Foothills (`elandor_copperfell_foothills`)

Zone 2 · home zone 11-20 · accord · race region **dwarf** · levels **11-20** · peaceful · relief `rolling_hills` · seed 42

Map: [maps/elandor_copperfell_foothills.png](maps/elandor_copperfell_foothills.png). Machine-readable: [elandor_copperfell_foothills.json](elandor_copperfell_foothills.json). Coordinates are world nodes (x east, z north, y up).

Race track (dwarf): step 2 of the track Hearthpine Vale → Copperfell Foothills → Dur Brannoc → Frostbarrow Shelf → Stormvault Heights.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2524..-1124, z -2596..-1824 (centroid -1834, -2134) |
| Land area | 545840 nodes² (≈ 0.55 km²) |
| Hub point (authored) | -1800, -2050 |
| Height above sea | min 0, p10 27, median 66, p90 102, max 158 |
| Slope | 10.7% steep (>1 node/node), 1.0% cliff (>2) |
| Biomes (measured) | pine_hills 91.2%, crags 8.6%, meadows 0.1%, deep_forest 0.0% |
| Neighbours (land border) | elandor_dur_brannoc (1156 nodes, mid -1694,-1849), elandor_frostbarrow_shelf (524 nodes, mid -2245,-2006), elandor_hearthpine_vale (1736 nodes, mid -1895,-2392), elandor_whitebridge_shire (256 nodes, mid -1168,-1918) |
| Sea coast | 1028 nodes of coastline; sea-beach sand 5616 nodes²; lake/river-bank sand 2928 nodes² |
| Water inside | bay 18640 nodes², rivers/lakes 8080 nodes² |
| Protected / drift band | 1.9% of land protected (towns, villages, camps/POIs, road corridors); 6.3% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -2327, -2342 | x -2352..-2308, z -2396..-2288 | 2032 | L12-14 |
| B2 | -2441, -2504 | x -2464..-2424, z -2560..-2452 | 1280 | L11-12 |
| B3 | -1232, -2171 | x -1252..-1216, z -2196..-2136 | 624 | L15-16 |
| B4 | -1209, -2083 | x -1220..-1200, z -2112..-2060 | 512 | L16-17 |
| B5 | -1168, -2014 | x -1192..-1152, z -2024..-2004 | 448 | L18 |
| B6 | -1228, -1999 | x -1236..-1220, z -2004..-1996 | 208 | L18 |
| B7 | -1247, -2039 | x -1260..-1236, z -2044..-2032 | 128 | L17 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L11 6.6%, L12 5.5%, L13 6.4%, L14 9.1%, L15 15.1%, L16 14.6%, L17 10.8%, L18 10.6%, L19 10.5%, L20 10.9%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_013 | village | Copperfell Village | -1868 | 94 | -2036 | 17 | village x -1880..-1857, z -2048..-2025 |
| anchor_025 | outpost | Copperfell Outpost | -2100 | 55 | -2100 | 16 | poi x -2108..-2093, z -2108..-2093 |
| anchor_049 | bandit camp | Copperfell Bandit Camp | -1568 | 68 | -2066 | 17 | camp x -1580..-1557, z -2078..-2055 |

## Protected areas

- village Copperfell Village (anchor_013): x -1880..-1857, z -2048..-2025
- poi Copperfell Outpost (anchor_025): x -2108..-2093, z -2108..-2093
- camp Copperfell Bandit Camp (anchor_049): x -1580..-1557, z -2078..-2055
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Copperfell Village (`copperfell_village`, anchor_013) at -1868, 94, -2036

Residents/guards: idle 2, quest 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_steward | quest giver | Orrik Pineledger | -1866, 95, -2036 | copperfell_bounty_rats, copperfell_survey_01, copperfell_survey_02, copperfell_survey_03 |
| quest_local | quest giver | Dagna Copperset | -1870, 95, -2038 | copperfell_workyard_01, copperfell_workyard_02, copperfell_workyard_03 |

Distances: zone edge N 188 (elandor_dur_brannoc), S 316 (elandor_hearthpine_vale), E 696 (coastal_shelf), W 392 (elandor_frostbarrow_shelf); nearest other-zone land 176 N; sea 469 SW; sea-beach sand 513 SW; nearest road 18.
Nearest hubs (straight / by road): Copperfell Bandit Camp 301 / 493; Hearthpine 518 / 655; Copperfell Outpost 241 / 775; Dur Brannoc 540 / 857; Tarnwatch Fold 706 / 1538.

### Copperfell Outpost (`copperfell_outpost`, anchor_025) at -2100, 55, -2100

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_scout | quest giver | Mara Deepwatch | -2097, 56, -2103 | copperfell_bounty_gnawers, copperfell_watch_01, copperfell_watch_02, copperfell_watch_03, copperfell_watch_04 |

Distances: zone edge N 240 (elandor_dur_brannoc), S 408 (elandor_hearthpine_vale), E 896 (coastal_shelf), W 208 (elandor_frostbarrow_shelf); nearest other-zone land 172 W; sea 233 SW; sea-beach sand 273 W; nearest road 12.
Nearest hubs (straight / by road): Hearthpine 541 / 638; Copperfell Village 241 / 775; Copperfell Bandit Camp 533 / 793; Dur Brannoc 671 / 1498; Tarnwatch Fold 606 / 2178.

### Copperfell Bandit Camp (`copperfell_bandit_camp`, anchor_049) at -1568, 68, -2066

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_captive | quest giver | Tovin Ashthumb | -1558, 69, -2056 | copperfell_bounty_dig, copperfell_departure, copperfell_dig_01, copperfell_dig_02 |

Distances: zone edge N 200 (elandor_dur_brannoc), S 172 (elandor_hearthpine_vale), E 372 (coastal_shelf), W 716 (elandor_frostbarrow_shelf); nearest other-zone land 172 S; sea 354 SE; sea-beach sand 310 SE; nearest road 16.
Nearest hubs (straight / by road): Copperfell Village 301 / 493; Hearthpine 537 / 673; Copperfell Outpost 533 / 793; Dur Brannoc 612 / 1216; Tarnwatch Fold 969 / 1896.

### Current quests (16, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| copperfell_survey_01 | The Surveyor Has Tusks | Orrik Pineledger (Copperfell Village) | 9 | kill 8 young_boar [in elandor_copperfell_foothills/lower_pines] | 320 | hearthpine_departure |
| copperfell_workyard_01 | Keep the Rails Together | Dagna Copperset (Copperfell Village) | 10 | bring 4 grug_materials:iron_bar; bring 4 default:coal_lump | 255 | hearthpine_departure |
| copperfell_survey_02 | An Appetite for Figures | Orrik Pineledger (Copperfell Village) | 11 | kill 8 granary_rat [in elandor_copperfell_foothills/lower_pines] | 340 | copperfell_survey_01 |
| copperfell_bounty_rats | Bounty: Accounts Receivable, Barely (repeatable) | Orrik Pineledger (Copperfell Village) | 12 | kill 6 granary_rat [in elandor_copperfell_foothills/lower_pines] | 170 | copperfell_survey_02 |
| copperfell_workyard_02 | A Handle on the Problem | Dagna Copperset (Copperfell Village) | 12 | bring 3 grug_mobs:ridged_boar_tusk | 225 | copperfell_workyard_01 |
| copperfell_survey_03 | Orrik Sends Useful Hands | Orrik Pineledger (Copperfell Village) | 13 | talk to Mara Deepwatch (copperfell_outpost) | 95 | copperfell_survey_02 |
| copperfell_watch_01 | The Road Has Gone Hollow | Mara Deepwatch (Copperfell Outpost) | 14 | kill 8 mangy_rat [in elandor_copperfell_foothills/pine_slopes] | 450 | copperfell_survey_03 |
| copperfell_watch_02 | Surefoot, Someone Else's Problem | Mara Deepwatch (Copperfell Outpost) | 14 | kill 8 surefoot_ibex [in elandor_copperfell_foothills/pine_slopes] | 400 | copperfell_survey_03 |
| copperfell_watch_03 | A Toll Paid in Bruises | Mara Deepwatch (Copperfell Outpost) | 15 | kill 8 quarrelsome_bandit or vigilant_bandit_archer [in elandor_copperfell_foothills/bandit_camp] | 473 | copperfell_watch_02 |
| copperfell_workyard_03 | The Guild's Good Name | Dagna Copperset (Copperfell Village) | 15 | bring 2 grug_materials:rough_jade | 440 | copperfell_workyard_02 |
| copperfell_watch_04 | One Carter Still Missing | Mara Deepwatch (Copperfell Outpost) | 16 | talk to Tovin Ashthumb (copperfell_bandit_camp) | 110 | copperfell_watch_03 |
| copperfell_bounty_gnawers | Bounty: Another Wheel Down (repeatable) | Mara Deepwatch (Copperfell Outpost) | 17 | kill 6 mangy_rat [in elandor_copperfell_foothills/pine_slopes] | 220 | copperfell_watch_04 |
| copperfell_dig_01 | I Know Where They Sold It | Tovin Ashthumb (Copperfell Bandit Camp) | 17 | kill 8 rubble_goblin_slinger or ore_guard_hound [in elandor_copperfell_foothills/goblin_dig] | 600 | copperfell_watch_04 |
| copperfell_dig_02 | Our Wages, Nog's Problem | Tovin Ashthumb (Copperfell Bandit Camp) | 18 | kill 1 foreman_nog; bring 3 grug_mobs:stolen_purse | 600 | copperfell_dig_01 |
| copperfell_bounty_dig | Bounty: Rocks in Lieu of Rent (repeatable) | Tovin Ashthumb (Copperfell Bandit Camp) | 19 | kill 6 rubble_goblin_slinger [in elandor_copperfell_foothills/goblin_dig] | 300 | copperfell_dig_02 |
| copperfell_departure | A Familiar Stamp | Tovin Ashthumb (Copperfell Bandit Camp) | 19 | talk to Dorrin Gateledger (dur_brannoc) | 180 | copperfell_dig_02 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bristling_boar | Ridgeback Tusker | aggressive | 57.9% of land, L15-20 | - |  |
| granary_rat | Granary Rat | aggressive | - | 64.5% of land, L11-14 |  |
| mangy_rat | Burrow Gnawer | aggressive | - | 57.9% of land, L15-20 |  |
| moaning_zombie | Cairn Zombie | aggressive | - | 3.3% of land, L11-15 |  |
| muttering_zombie | Pauper Shambler | aggressive | - | 8.3% of land, L16-20 |  |
| ore_guard_hound | Ore-Guard Hound | aggressive | 1.7% of land, L18-20 | 1.7% of land, L18-20 |  |
| ore_thieving_goblin | Ore-Thieving Goblin | aggressive | - | 28.8% of land, L11-13 |  |
| quarrelsome_bandit | Roadside Bandit | aggressive | 2.2% of land, L14-15 | 2.2% of land, L14-15 |  |
| rabid_fox | Thicket Vixen | aggressive | 6.7% of land, L15-20 | - |  |
| rubble_goblin_slinger | Rubble Goblin Slinger | aggressive | 1.7% of land, L18-20 | 1.7% of land, L18-20 |  |
| shore_crab | Shore Crab | neutral | 5616 nodes², L11-18 | 5616 nodes², L11-18 | sand (dry, within 6 nodes of water) |
| surefoot_ibex | Surefoot Ibex | neutral | 37.3% of land, L14-20 | - |  |
| tidepool_crab | Tidepool Crab | neutral | 1.1% of land, L11-13 | - |  |
| vigilant_bandit_archer | Bandit Lookout | aggressive | 2.2% of land, L16-17 | 2.2% of land, L16-17 |  |
| young_boar | Rooting Boar | neutral | 31.1% of land, L11-14 | - |  |
| young_fox | Bracken Fox | neutral | 28.8% of land, L11-13 | - |  |

**Camps and guard posts:**

- anchor_025 Copperfell Outpost at -2100, -2100: guard post, guard_accord × 2-3, respawn 180-360 s, level there L16.
- anchor_049 Copperfell Bandit Camp at -1568, -2066: bandit, bandit/bandit_archer × 3-5, respawn 30-60 s, level there L17.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 3 | primary | anchor_001 (Hearthpine, elandor_hearthpine_vale) | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | 825 / 526 | -1792,-2300 → -1703,-1827 |
| 8 | secondary | anchor_013 (Copperfell Village, elandor_copperfell_foothills) | joins road 3 | 53 / 56 | -1853,-2026 → -1806,-2002 |
| 32 | trail | anchor_025 (Copperfell Outpost, elandor_copperfell_foothills) | joins road 3 | 368 / 360 | -2093,-2110 → -1798,-2304 |
| 50 | trail | anchor_049 (Copperfell Bandit Camp, elandor_copperfell_foothills) | joins road 3 | 240 / 240 | -1576,-2080 → -1783,-2163 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

