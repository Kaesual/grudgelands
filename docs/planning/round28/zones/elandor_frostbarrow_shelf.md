# Frostbarrow Shelf (`elandor_frostbarrow_shelf`)

Zone 4 · home zone 21-30 · accord · race region **dwarf** · levels **21-30** · peaceful · relief `plateau` · seed 42

Map: [maps/elandor_frostbarrow_shelf.png](maps/elandor_frostbarrow_shelf.png). Machine-readable: [elandor_frostbarrow_shelf.json](elandor_frostbarrow_shelf.json). Coordinates are world nodes (x east, z north, y up).

Race track (dwarf): step 4 of the track Hearthpine Vale → Copperfell Foothills → Dur Brannoc → Frostbarrow Shelf → Stormvault Heights.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2564..-2040, z -2176..-988 (centroid -2319, -1497) |
| Land area | 371744 nodes² (≈ 0.37 km²) |
| Hub point (authored) | -2400, -1500 |
| Height above sea | min 0, p10 26, median 108, p90 182, max 357 |
| Slope | 47.2% steep (>1 node/node), 13.1% cliff (>2) |
| Biomes (measured) | pine_hills 51.9%, crags 28.2%, swamp 19.9% |
| Neighbours (land border) | elandor_copperfell_foothills (520 nodes, mid -2240,-2009), elandor_dur_brannoc (924 nodes, mid -2116,-1456), elandor_stormvault_heights (556 nodes, mid -2241,-1039) |
| Sea coast | 1940 nodes of coastline; sea-beach sand 6848 nodes²; lake/river-bank sand 224 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 2416 nodes² |
| Protected / drift band | 2.1% of land protected (towns, villages, camps/POIs, road corridors); 8.7% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -2509, -1105 | x -2524..-2488, z -1176..-1060 | 2192 | L29-30 |
| B2 | -2483, -1310 | x -2520..-2456, z -1368..-1252 | 2176 | L27-28 |
| B3 | -2553, -1465 | x -2564..-2536, z -1540..-1408 | 1296 | L25-26 |
| B4 | -2464, -1721 | x -2476..-2444, z -1756..-1680 | 1008 | L23-24 |
| B5 | -2493, -1014 | x -2496..-2488, z -1024..-1004 | 128 | L30 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L21 8.3%, L22 8.3%, L23 9.1%, L24 9.5%, L25 12.4%, L26 13.0%, L27 8.4%, L28 10.1%, L29 9.9%, L30 10.9%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_014 | village | Tarnwatch Fold | -2404 | 87 | -1576 | 25 | village x -2416..-2393, z -1588..-1565 |
| anchor_026 | outpost | Rimebell Watch | -2300 | 113 | -1250 | 28 | poi x -2308..-2293, z -1258..-1243 |
| anchor_061 | mine | Tarncut Mine | -2418 | 39 | -1296 | 28 | poi x -2428..-2409, z -1306..-1287 |

## Protected areas

- village Tarnwatch Fold (anchor_014): x -2416..-2393, z -1588..-1565
- poi Rimebell Watch (anchor_026): x -2308..-2293, z -1258..-1243
- poi Tarncut Mine (anchor_061): x -2428..-2409, z -1306..-1287
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Tarnwatch Fold (`r20_anchor_014`, anchor_014) at -2404, 87, -1576

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Edda Tarnmantle | -2402, 88, -1576 | r20_anchor_014_01, r20_anchor_014_02, r20_anchor_014_03, r20_dwarf_journey_02 |

Distances: zone edge N 576 (elandor_stormvault_heights), S 508 (coastal_shelf), E 256 (elandor_dur_brannoc), W 140 (coastal_shelf); nearest other-zone land 246 E; sea 79 SW; sea-beach sand 126 SW; nearest road 17.
Nearest hubs (straight / by road): Tarncut Mine 280 / 662; Dur Brannoc 609 / 877; Rimebell Watch 342 / 1070; Copperfell Village 706 / 1538; Copperfell Bandit Camp 969 / 1896.

### Rimebell Watch (`r20_anchor_026`, anchor_026) at -2300, 113, -1250

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Hedra Rimebell | -2298, 114, -1250 | r20_anchor_026_01, r20_anchor_026_02, r20_anchor_026_03 |

Distances: zone edge N 240 (elandor_stormvault_heights), S 836 (elandor_copperfell_foothills), E 212 (elandor_dur_brannoc), W 224 (coastal_shelf); nearest other-zone land 197 E; sea 187 W; sea-beach sand 168 W; nearest road 12.
Nearest hubs (straight / by road): Tarnwatch Fold 342 / 1070; Dur Brannoc 559 / 1085; Tarncut Mine 127 / 1529; Copperfell Village 897 / 1745; Copperfell Bandit Camp 1096 / 2104.

### Tarncut Mine (`r20_anchor_061`, anchor_061) at -2418, 39, -1296

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Kelda Screesort | -2416, 40, -1296 | r20_anchor_061_01, r20_anchor_061_02, r20_anchor_061_03, r20_dwarf_journey_03 |

Distances: zone edge N 296 (elandor_stormvault_heights), S 512 (coastal_shelf), E 312 (elandor_dur_brannoc), W 84 (coastal_shelf); nearest other-zone land 296 N; sea 60 W; sea-beach sand 42 W; nearest road 13.
Nearest hubs (straight / by road): Tarnwatch Fold 280 / 662; Dur Brannoc 651 / 1336; Rimebell Watch 127 / 1529; Copperfell Village 922 / 1997; Copperfell Bandit Camp 1147 / 2355.

### Current quests (11, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_014_01 | The Cairn Mortar | Edda Tarnmantle (Tarnwatch Fold) | 21 | bring 10 default:cobble | 820 | - |
| r20_anchor_014_02 | Hooves Above the Sleds | Edda Tarnmantle (Tarnwatch Fold) | 21 | kill 4 ibex or surefoot_ibex [in elandor_frostbarrow_shelf] | 820 | - |
| r20_anchor_026_01 | Fuel Under Cover | Hedra Rimebell (Rimebell Watch) | 21 | bring 6 default:coal_lump | 820 | - |
| r20_anchor_026_02 | The Sled Track Pack | Hedra Rimebell (Rimebell Watch) | 21 | kill 3 snow_leopard [in elandor_frostbarrow_shelf] | 820 | - |
| r20_anchor_061_01 | A Handle for the Cutting | Kelda Screesort (Tarncut Mine) | 21 | bring 1 grug_materials:pick_stone | 820 | - |
| r20_anchor_061_02 | Rams on the Haul Lane | Kelda Screesort (Tarncut Mine) | 21 | kill 4 mountain_ram [in elandor_frostbarrow_shelf] | 820 | - |
| r20_anchor_014_03 | The Bell After Dark | Edda Tarnmantle (Tarnwatch Fold) | 23 | kill 4 goblin_raider or ore_thieving_goblin [in elandor_frostbarrow_shelf] | 900 | r20_anchor_014_02 |
| r20_anchor_026_03 | Notches on the Signal Pole | Hedra Rimebell (Rimebell Watch) | 23 | kill 4 goblin_slinger or rubble_goblin_slinger [in elandor_frostbarrow_shelf] | 900 | r20_anchor_026_02 |
| r20_anchor_061_03 | The Cold Shift | Kelda Screesort (Tarncut Mine) | 23 | kill 3 snow_leopard [in elandor_frostbarrow_shelf] | 900 | r20_anchor_061_02 |
| r20_dwarf_journey_02 | Word for Kelda Screesort | Edda Tarnmantle (Tarnwatch Fold) | 24 | talk to Kelda Screesort (r20_anchor_061) | 705 | - |
| r20_dwarf_journey_03 | Word for Borin Splitbolt | Kelda Screesort (Tarncut Mine) | 31 | talk to Borin Splitbolt (r20_anchor_027) | 915 | - |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| armored_crab | Barnacle Pincher | aggressive | 10.0% of land, L25-30 | - |  |
| bank_crab | Bank Crab | neutral | 8.1% of land, L21-24 | - |  |
| hill_ram | Hill Ram | neutral | 88.1% of land, L21-30 | - |  |
| ore_guard_hound | Ore-Guard Hound | aggressive | - | 23.2% of land, L24-27 |  |
| ore_thieving_goblin | Ore-Thieving Goblin | aggressive | - | 5.4% of land, L21-23 |  |
| prowling_snow_leopard | Crag Snow Leopard | aggressive | - | 100.0% of land, L21-30 |  |
| ridge_crag_eagle | Ridge Crag Eagle | aggressive | 65.2% of land, L21-30 | - |  |
| rubble_goblin_slinger | Rubble Goblin Slinger | aggressive | - | 19.4% of land, L21-23 |  |
| shore_crab | Shore Crab | neutral | 6848 nodes², L21-30 | 6848 nodes², L21-30 | sand (dry, within 6 nodes of water) |
| surefoot_ibex | Surefoot Ibex | neutral | 22.9% of land, L21-23 | - |  |

**Camps and guard posts:**

- anchor_026 Rimebell Watch at -2300, -1250: guard post, guard_accord × 2-3, respawn 180-360 s, level there L28.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 9 | secondary | anchor_014 (Tarnwatch Fold, elandor_frostbarrow_shelf) | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | 477 / 382 | -2389,-1585 → -2151,-1700 |
| 33 | trail | anchor_026 (Rimebell Watch, elandor_frostbarrow_shelf) | joins road 9 | 628 / 196 | -2290,-1244 → -2115,-1311 |
| 62 | trail | anchor_061 (Tarncut Mine, elandor_frostbarrow_shelf) | joins road 9 | 548 / 542 | -2417,-1309 → -2378,-1661 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

