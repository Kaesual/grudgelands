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
| quest_steward | quest giver | Orrik Pineledger | -1866, 95, -2036 | r14_dwarf_07_a_ledger_in_the_scrub |
| quest_local | quest giver | Dagna Copperset | -1870, 95, -2038 | r15_dwarf_local_01, r15_dwarf_local_02 |

Distances: zone edge N 188 (elandor_dur_brannoc), S 316 (elandor_hearthpine_vale), E 696 (coastal_shelf), W 392 (elandor_frostbarrow_shelf); nearest other-zone land 176 N; sea 469 SW; sea-beach sand 513 SW; nearest road 18.
Nearest hubs (straight / by road): Copperfell Bandit Camp 301 / 493; Hearthpine 518 / 655; Copperfell Outpost 241 / 775; Dur Brannoc 540 / 857; Tarnwatch Fold 706 / 1538.

### Copperfell Outpost (`copperfell_outpost`, anchor_025) at -2100, 55, -2100

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_scout | quest giver | Mara Deepwatch | -2097, 56, -2103 | r14_dwarf_08_hold_the_marker_stones, r14_dwarf_09_ash_under_the_nails, r15_dwarf_local_03, r15_dwarf_local_04 |

Distances: zone edge N 240 (elandor_dur_brannoc), S 408 (elandor_hearthpine_vale), E 896 (coastal_shelf), W 208 (elandor_frostbarrow_shelf); nearest other-zone land 172 W; sea 233 SW; sea-beach sand 273 W; nearest road 12.
Nearest hubs (straight / by road): Hearthpine 541 / 638; Copperfell Village 241 / 775; Copperfell Bandit Camp 533 / 793; Dur Brannoc 671 / 1498; Tarnwatch Fold 606 / 2178.

### Copperfell Bandit Camp (`copperfell_bandit_camp`, anchor_049) at -1568, 68, -2066

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_captive | quest giver | Tovin Ashthumb | -1558, 69, -2056 | r15_dwarf_local_05, r15_dwarf_local_06 |

Distances: zone edge N 200 (elandor_dur_brannoc), S 172 (elandor_hearthpine_vale), E 372 (coastal_shelf), W 716 (elandor_frostbarrow_shelf); nearest other-zone land 172 S; sea 354 SE; sea-beach sand 310 SE; nearest road 16.
Nearest hubs (straight / by road): Copperfell Village 301 / 493; Hearthpine 537 / 673; Copperfell Outpost 533 / 793; Dur Brannoc 612 / 1216; Tarnwatch Fold 969 / 1896.

### Current quests (9, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r14_dwarf_07_a_ledger_in_the_scrub | A Ledger in the Scrub | Orrik Pineledger (Copperfell Village) | 10 | kill 6 fox [in elandor_copperfell_foothills] | 380 | r14_dwarf_06_loose_stone_on_copper_road |
| r15_dwarf_local_01 | Stone for the Workyard | Dagna Copperset (Copperfell Village) | 10 | bring 8 default:cobble | 285 | r14_dwarf_06_loose_stone_on_copper_road |
| r15_dwarf_local_02 | Fangs in the Tool Baskets | Dagna Copperset (Copperfell Village) | 10 | bring 2 grug_mobs:fang | 380 | r14_dwarf_06_loose_stone_on_copper_road |
| r14_dwarf_08_hold_the_marker_stones | Hold the Marker Stones | Mara Deepwatch (Copperfell Outpost) | 11 | kill 6 goblin_raider or goblin_slinger or goblin_hound [in elandor_copperfell_foothills] | 525 | r14_dwarf_07_a_ledger_in_the_scrub |
| r15_dwarf_local_03 | Scraps from the Signal Path | Mara Deepwatch (Copperfell Outpost) | 11 | bring 2 grug_mobs:linen_scrap | 315 | r14_dwarf_07_a_ledger_in_the_scrub |
| r15_dwarf_local_04 | Sure Feet, Loose Stones | Mara Deepwatch (Copperfell Outpost) | 11 | kill 5 ibex [in elandor_copperfell_foothills] | 420 | r14_dwarf_07_a_ledger_in_the_scrub |
| r14_dwarf_09_ash_under_the_nails | Ash Under the Nails | Mara Deepwatch (Copperfell Outpost) | 12 | kill 4 bandit or bandit_archer [in elandor_copperfell_foothills] | 805 | r14_dwarf_08_hold_the_marker_stones |
| r15_dwarf_local_05 | The Ore Carriers' Purses | Tovin Ashthumb (Copperfell Bandit Camp) | 12 | bring 2 grug_mobs:stolen_purse | 460 | r14_dwarf_08_hold_the_marker_stones |
| r15_dwarf_local_06 | Cloth Around the Stolen Tools | Tovin Ashthumb (Copperfell Bandit Camp) | 12 | bring 5 grug_mobs:linen_cloth | 575 | r14_dwarf_08_hold_the_marker_stones |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| boar | Boar | neutral | 100.0% of land, L11-20 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| fox | Fox | aggressive | 90.7% of land, L11-20 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_silver_litter |
| goblin_hound | Goblin Raider Hound | aggressive | - | 99.7% of land, L11-20 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| goblin_raider | Goblin Raider | aggressive | - | 99.7% of land, L11-20 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| goblin_slinger | Goblin Slinger | aggressive | - | 99.7% of land, L11-20 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| ibex | Ibex | neutral | 99.7% of land, L11-20 | - | dirt_with_coniferous_litter, gravel, snowblock |
| rabbit | Rabbit | critter | 100.0% of land, L11-20 | - | dirt_with_coniferous_litter, dirt_with_grass, gravel, sand, snowblock, dirt_with_forest_litter … |
| shore_crab | Shore Crab | neutral | 5616 nodes², L11-18 | 5616 nodes², L11-18 | sand (dry, within 6 nodes of water) |
| zombie | Zombie | aggressive | - | 100.0% of land, L11-20 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

**Camps and guard posts:**

- anchor_025 Copperfell Outpost at -2100, -2100: guard post, guard_accord × 2-3, respawn 180-360 s, level there L16.
- anchor_049 Copperfell Bandit Camp at -1568, -2066: bandit, bandit/bandit_archer × 3-5, respawn 120-300 s, level there L17.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 3 | primary | anchor_001 (Hearthpine, elandor_hearthpine_vale) | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | 825 / 526 | -1792,-2300 → -1703,-1827 |
| 8 | secondary | anchor_013 (Copperfell Village, elandor_copperfell_foothills) | joins road 3 | 53 / 56 | -1853,-2026 → -1806,-2002 |
| 31 | trail | anchor_025 (Copperfell Outpost, elandor_copperfell_foothills) | joins road 3 | 368 / 360 | -2093,-2110 → -1798,-2304 |
| 49 | trail | anchor_049 (Copperfell Bandit Camp, elandor_copperfell_foothills) | joins road 3 | 240 / 240 | -1576,-2080 → -1783,-2163 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

