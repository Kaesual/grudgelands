# Mournfen (`kragmar_mournfen`)

Zone 18 · home zone 11-20 · throng · race region **undead** · levels **11-20** · peaceful · relief `wetland_delta` · seed 42

Map: [maps/kragmar_mournfen.png](maps/kragmar_mournfen.png). Machine-readable: [kragmar_mournfen.json](kragmar_mournfen.json). Coordinates are world nodes (x east, z north, y up).

Race track (undead): step 2 of the track Stillgrave Hollow → Mournfen → Nhal Veyr → Ossuary Reach → Blackwind Rise.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2380..-1324, z 1812..2396 (centroid -1820, 2127) |
| Land area | 313088 nodes² (≈ 0.31 km²) |
| Hub point (authored) | -1800, 2050 |
| Height above sea | min 0, p10 9, median 26, p90 50, max 80 |
| Slope | 1.8% steep (>1 node/node), 0.0% cliff (>2) |
| Biomes (measured) | blight 61.9%, swamp 28.8%, bone_forest 8.6%, badlands 0.3%, savanna 0.3% |
| Neighbours (land border) | kragmar_nhal_veyr (904 nodes, mid -1749,1914), kragmar_ossuary_reach (508 nodes, mid -2236,2027), kragmar_speargrass_reach (400 nodes, mid -1394,1962), kragmar_stillgrave_hollow (1500 nodes, mid -1901,2301) |
| Sea coast | 508 nodes of coastline; sea-beach sand 15040 nodes²; lake/river-bank sand 10224 nodes² |
| Water inside | bay 50032 nodes², rivers/lakes 20384 nodes² |
| Protected / drift band | 2.9% of land protected (towns, villages, camps/POIs, road corridors); 9.3% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -1448, 2327 | x -1532..-1364, z 2256..2392 | 7344 | L11-12 |
| B2 | -1418, 2137 | x -1496..-1324, z 2064..2204 | 7136 | L13-16 |
| B3 | -1419, 2065 | x -1436..-1404, z 2052..2076 | 320 | L16-17 |
| B4 | -1514, 2221 | x -1532..-1500, z 2216..2224 | 192 | L13 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L11 8.2%, L12 9.9%, L13 11.0%, L14 11.7%, L15 16.0%, L16 13.4%, L17 9.1%, L18 9.0%, L19 6.8%, L20 4.9%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_019 | village | Mournfen Village | -1900 | 24 | 2020 | 17 | village x -1912..-1889, z 2008..2031 |
| anchor_037 | outpost | Mournfen Outpost | -2100 | 21 | 2100 | 16 | poi x -2108..-2093, z 2092..2107 |
| anchor_055 | bandit camp | Mournfen Bandit Camp | -1600 | 57 | 2050 | 17 | camp x -1612..-1589, z 2038..2061 |
| anchor_069 | mirefolk camp | Blackreed Enclosure | -2074 | 20 | 2274 | 12 | camp x -2082..-2067, z 2266..2281 |

## Protected areas

- village Mournfen Village (anchor_019): x -1912..-1889, z 2008..2031
- poi Mournfen Outpost (anchor_037): x -2108..-2093, z 2092..2107
- camp Mournfen Bandit Camp (anchor_055): x -1612..-1589, z 2038..2061
- camp Blackreed Enclosure (anchor_069): x -2082..-2067, z 2266..2281
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Mournfen Village (`mournfen_village`, anchor_019) at -1900, 24, 2020

Residents/guards: idle 2, quest 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_steward | quest giver | Mordec Silt | -1898, 25, 2020 | mournfen_bounty_fen, mournfen_fen_01, mournfen_fen_02, mournfen_fen_03, mournfen_fen_04 |
| quest_local | quest giver | Edris Wax | -1902, 25, 2018 | mournfen_stores_01, mournfen_stores_02, mournfen_wax_01 |

Distances: zone edge N 280 (kragmar_stillgrave_hollow), S 68 (kragmar_nhal_veyr), E 500 (kragmar_speargrass_reach), W 308 (kragmar_ossuary_reach); nearest other-zone land 68 S; sea 482 E; sea-beach sand 419 NE; nearest road 22.
Nearest hubs (straight / by road): Mournfen Outpost 215 / 261; Stillgrave 539 / 592; Nhal Veyr 530 / 717; Ossuary Ledgerstead 638 / 1179; Mournfen Bandit Camp 301 / 1422.

### Mournfen Outpost (`mournfen_outpost`, anchor_037) at -2100, 21, 2100

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_scout | quest giver | Sera Vane | -2097, 22, 2097 | mournfen_bounty_watch, mournfen_departure, mournfen_watch_01, mournfen_watch_02, mournfen_watch_03, mournfen_watch_04 |

Distances: zone edge N 228 (kragmar_stillgrave_hollow), S 208 (kragmar_nhal_veyr), E 772 (bay_water), W 212 (kragmar_ossuary_reach); nearest other-zone land 124 SW; sea 343 W; sea-beach sand 316 W; nearest road 11.
Nearest hubs (straight / by road): Mournfen Village 215 / 261; Stillgrave 541 / 761; Nhal Veyr 671 / 935; Ossuary Ledgerstead 573 / 1396; Mournfen Bandit Camp 502 / 1639.

### Mournfen Bandit Camp (`mournfen_bandit_camp`, anchor_055) at -1600, 57, 2050

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_captive | quest giver | Hollis Grey | -1590, 58, 2060 | mournfen_testimony_01 |

Distances: zone edge N 292 (kragmar_stillgrave_hollow), S 120 (kragmar_nhal_veyr), E 236 (kragmar_speargrass_reach), W 648 (kragmar_ossuary_reach); nearest other-zone land 116 S; sea 199 NE; sea-beach sand 160 NE; nearest road 16.
Nearest hubs (straight / by road): Nhal Veyr 585 / 1142; Speargrass Wellhold 879 / 1350; Mournfen Village 301 / 1422; Redpick Yard 946 / 1460; Ossuary Ledgerstead 900 / 1604.

### Current quests (15, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| mournfen_fen_01 | The Fen Gives Them Back | Mordec Silt (Mournfen Village) | 9 | kill 8 young_boar [in kragmar_mournfen/blightfields] | 320 | stillgrave_departure |
| mournfen_stores_01 | By the Light of Supper | Edris Wax (Mournfen Village) | 10 | bring 8 mobs:meat_raw | 200 | - |
| mournfen_fen_02 | The Marks in the Reeds | Mordec Silt (Mournfen Village) | 11 | talk to Sera Vane (mournfen_outpost) | 85 | mournfen_fen_01 |
| mournfen_watch_01 | Somebody's Grandfather as Wages | Sera Vane (Mournfen Outpost) | 11 | kill 8 reed_mirefolk [in kragmar_mournfen/blackreed_enclosure] | 405 | mournfen_fen_02 |
| mournfen_watch_02 | A Light Can Lie | Sera Vane (Mournfen Outpost) | 13 | kill 7 wandering_wisp [in kragmar_mournfen/wispfen] | 450 | mournfen_watch_01 |
| mournfen_fen_03 | Visiting Hours Are Cancelled | Mordec Silt (Mournfen Village) | 14 | kill 7 bristling_boar [in kragmar_mournfen/barrowfields] | 473 | mournfen_fen_02 |
| mournfen_stores_02 | Lanterns Belong Above the Mud | Edris Wax (Mournfen Village) | 14 | bring 6 grug_materials:iron_bar; bring 4 default:coal_lump | 300 | mournfen_stores_01 |
| mournfen_wax_01 | A Flame Worth Keeping | Edris Wax (Mournfen Village) | 15 | bring 3 grug_mobs:wisp_mote | 315 | mournfen_watch_02 |
| mournfen_bounty_fen | Repeatable: The Graves Need Minding (repeatable) | Mordec Silt (Mournfen Village) | 16 | kill 6 mangy_rat [in kragmar_mournfen/barrowfields] | 210 | mournfen_fen_03 |
| mournfen_fen_04 | A Place in the Book | Mordec Silt (Mournfen Village) | 16 | kill 6 muttering_zombie [in kragmar_mournfen/gravemoor] | 518 | mournfen_fen_03 |
| mournfen_watch_03 | Arrows Over the Evidence | Sera Vane (Mournfen Outpost) | 17 | kill 6 vigilant_bandit_archer [in kragmar_mournfen/bandit_camp] | 460 | mournfen_watch_02 |
| mournfen_testimony_01 | Strike Out the Counter | Hollis Grey (Mournfen Bandit Camp) | 18 | kill 5 reed_mirefolk [in kragmar_mournfen/mire_nests]; kill 1 reed_counter_silt | 720 | mournfen_watch_04 |
| mournfen_watch_04 | The Witness Is Still Talking | Sera Vane (Mournfen Outpost) | 18 | talk to Hollis Grey (mournfen_bandit_camp) | 115 | mournfen_watch_03 |
| mournfen_bounty_watch | Repeatable: Six Fewer False Lights (repeatable) | Sera Vane (Mournfen Outpost) | 19 | kill 6 wandering_wisp [in kragmar_mournfen/deepfen] | 300 | mournfen_watch_04 |
| mournfen_departure | Names Missing From the Register | Sera Vane (Mournfen Outpost) | 19 | talk to Ossa Quietregister (nhal_veyr) | 180 | mournfen_testimony_01 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bristling_boar | Ridgeback Tusker | aggressive | 62.5% of land, L15-20 | - |  |
| granary_rat | Granary Rat | aggressive | - | 23.4% of land, L11-13 |  |
| mangy_rat | Burrow Gnawer | aggressive | - | 27.2% of land, L15-20 |  |
| moaning_zombie | Cairn Zombie | aggressive | - | 27.9% of land, L11-15 |  |
| muttering_husk | Cairn Sun-Dried Husk | aggressive | 36.2% of land, L14-15 | - |  |
| muttering_zombie | Pauper Shambler | aggressive | - | 17.9% of land, L18-20 |  |
| parched_husk | Pauper Mummy | aggressive | 26.3% of land, L18-20 | - |  |
| quarrelsome_bandit | Roadside Bandit | aggressive | - | 23.4% of land, L11-13 |  |
| reed_crocodile | Reed Crocodile | aggressive | 4.2% of land, L11-13 | 4.2% of land, L11-13 |  |
| reed_mirefolk | Reed Mirefolk | aggressive | 7.1% of land, L11-20 | 7.1% of land, L11-20 |  |
| shore_crab | Shore Crab | neutral | 15040 nodes², L11-17 | 15040 nodes², L11-17 | sand (dry, within 6 nodes of water) |
| sullen_bog_ooze | Bubbling Bog Ooze | aggressive | 23.4% of land, L11-13 | - |  |
| tidepool_crab | Tidepool Crab | neutral | 3.2% of land, L11-13 | - |  |
| vigilant_bandit_archer | Bandit Lookout | aggressive | 3.8% of land, L18-20 | 3.8% of land, L18-20 |  |
| wandering_wisp | Wandering Wisp | aggressive | - | 30.4% of land, L14-20 |  |
| young_boar | Rooting Boar | neutral | 23.4% of land, L11-13 | - |  |

**Camps and guard posts:**

- anchor_037 Mournfen Outpost at -2100, 2100: guard post, guard_throng × 2-3, respawn 180-360 s, level there L16.
- anchor_055 Mournfen Bandit Camp at -1600, 2050: bandit, bandit/bandit_archer × 3-5, respawn 30-60 s, level there L17.
- anchor_069 Blackreed Enclosure at -2074, 2274: mirefolk camp, EMPTY today: no camp fire is placed (anchor roster lists only capital, outpost and bandit populations) (level there L12).

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 15 | primary | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 1440 / 34 | -1442,1827 → -1414,1843 |
| 17 | primary | anchor_004 (Stillgrave, kragmar_stillgrave_hollow) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 782 / 356 | -1836,2269 → -1937,1950 |
| 21 | secondary | anchor_019 (Mournfen Village, kragmar_mournfen) | joins road 17 | 28 / 32 | -1916,2004 → -1936,1984 |
| 41 | trail | anchor_037 (Mournfen Outpost, kragmar_mournfen) | joins road 17 | 205 / 204 | -2090,2095 → -1905,2049 |
| 56 | trail | anchor_055 (Mournfen Bandit Camp, kragmar_mournfen) | joins road 15 | 275 / 140 | -1593,2036 → -1553,1908 |
| 70 | trail | anchor_069 (Blackreed Enclosure, kragmar_mournfen) | joins road 17 | 246 / 244 | -2066,2264 → -1851,2162 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

