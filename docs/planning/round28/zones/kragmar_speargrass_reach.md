# Speargrass Reach (`kragmar_speargrass_reach`)

Zone 25 · home zone 21-30 · throng · race region **orc** · levels **21-30** · peaceful · relief `rolling_hills` · seed 42

Map: [maps/kragmar_speargrass_reach.png](maps/kragmar_speargrass_reach.png). Machine-readable: [kragmar_speargrass_reach.json](kragmar_speargrass_reach.json). Coordinates are world nodes (x east, z north, y up).

Race track (orc): step 4 of the track Sunscar Flats → Redtusk Savanna → Gor Drazhak → Speargrass Reach → Bannerbreak Mesa.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -1420..-460, z 920..2488 (centroid -921, 1519) |
| Land area | 788496 nodes² (≈ 0.79 km²) |
| Hub point (authored) | -900, 1500 |
| Height above sea | min 0, p10 46, median 95, p90 139, max 235 |
| Slope | 23.6% steep (>1 node/node), 1.9% cliff (>2) |
| Biomes (measured) | savanna 58.7%, badlands 40.3%, blight 0.5%, bone_forest 0.4%, swamp 0.2% |
| Neighbours (land border) | kragmar_bannerbreak_mesa (660 nodes, mid -703,1007), kragmar_blackwind_rise (480 nodes, mid -1154,1024), kragmar_gor_drazhak (680 nodes, mid -474,1405), kragmar_mournfen (408 nodes, mid -1397,1968), kragmar_nhal_veyr (796 nodes, mid -1355,1495), kragmar_redtusk_savanna (996 nodes, mid -649,2001), kragmar_sunscar_flats (84 nodes, mid -767,2460) |
| Sea coast | 1640 nodes of coastline; sea-beach sand 9920 nodes²; lake/river-bank sand 6688 nodes² |
| Water inside | bay 248352 nodes², rivers/lakes 46672 nodes² |
| Protected / drift band | 2.5% of land protected (towns, villages, camps/POIs, road corridors); 9.3% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -1146, 1861 | x -1312..-996, z 1804..1952 | 9104 | L22-23 |
| B2 | -1340, 2062 | x -1356..-1324, z 2044..2088 | 768 | L21 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L21 6.6%, L22 8.4%, L23 13.2%, L24 13.6%, L25 12.7%, L26 11.9%, L27 7.4%, L28 9.0%, L29 8.9%, L30 8.3%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_022 | village | Speargrass Wellhold | -868 | 110 | 1564 | 25 | village x -880..-857, z 1552..1575 |
| anchor_042 | outpost | Cutgrass Watch | -650 | 56 | 1250 | 28 | poi x -658..-643, z 1242..1257 |
| anchor_065 | mine | Redpick Yard | -1050 | 72 | 1280 | 27 | poi x -1060..-1041, z 1270..1289 |

## Protected areas

- village Speargrass Wellhold (anchor_022): x -880..-857, z 1552..1575
- poi Cutgrass Watch (anchor_042): x -658..-643, z 1242..1257
- poi Redpick Yard (anchor_065): x -1060..-1041, z 1270..1289
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Speargrass Wellhold (`r20_anchor_022`, anchor_022) at -868, 110, 1564

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Brakka Jarward | -866, 111, 1564 | r20_anchor_022_01, r20_anchor_022_02, r20_anchor_022_03, r20_orc_journey_02 |

Distances: zone edge N 532 (coastal_shelf), S 628 (kragmar_bannerbreak_mesa), E 396 (kragmar_gor_drazhak), W 480 (kragmar_nhal_veyr); nearest other-zone land 389 E; sea 359 NW; sea-beach sand 322 NW; nearest road 16.
Nearest hubs (straight / by road): Redpick Yard 337 / 754; Mournfen Bandit Camp 879 / 1342; Nhal Veyr 934 / 1421; Mournfen Village 1128 / 1705; Ossuary Ledgerstead 1512 / 1861.

### Cutgrass Watch (`r20_anchor_042`, anchor_042) at -650, 56, 1250

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Morga Cutgrass | -648, 57, 1250 | r20_anchor_042_01, r20_anchor_042_02, r20_anchor_042_03 |

Distances: zone edge N 692 (kragmar_redtusk_savanna), S 216 (kragmar_bannerbreak_mesa), E 160 (kragmar_gor_drazhak), W 700 (kragmar_nhal_veyr); nearest other-zone land 156 E; sea 740 NW; sea-beach sand 704 NW; nearest road 13.
Nearest hubs (straight / by road): Gor Drazhak 696 / 982; Redtusk Village 940 / 1507; Mournfen Bandit Camp 1242 / 1645; Redtusk Bandit Camp 1214 / 1823; Red Ramp Post 466 / 1826.

### Redpick Yard (`r20_anchor_065`, anchor_065) at -1050, 72, 1280

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Gorren Redpick | -1048, 73, 1280 | r20_anchor_065_01, r20_anchor_065_02, r20_anchor_065_03, r20_orc_journey_03 |

Distances: zone edge N 636 (bay_water), S 300 (kragmar_blackwind_rise), E 576 (kragmar_gor_drazhak), W 292 (kragmar_nhal_veyr); nearest other-zone land 274 S; sea 562 N; sea-beach sand 533 N; nearest road 14.
Nearest hubs (straight / by road): Speargrass Wellhold 337 / 754; Mournfen Bandit Camp 946 / 1452; Nhal Veyr 782 / 1531; Mournfen Village 1127 / 1815; Ossuary Ledgerstead 1368 / 1971.

### Current quests (11, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_022_01 | Shade Before Strength | Brakka Jarward (Speargrass Wellhold) | 21 | bring 8 default:acacia_wood | 820 | - |
| r20_anchor_022_02 | Stripes in the Cutting Grass | Brakka Jarward (Speargrass Wellhold) | 21 | kill 3 speargrass_tiger [in kragmar_speargrass_reach] | 820 | - |
| r20_anchor_042_01 | Posts for the Shade | Morga Cutgrass (Cutgrass Watch) | 21 | bring 8 default:acacia_wood | 820 | - |
| r20_anchor_042_02 | The Cutters' Long Walk | Morga Cutgrass (Cutgrass Watch) | 21 | kill 3 speargrass_tiger [in kragmar_speargrass_reach] | 820 | - |
| r20_anchor_065_01 | Roof Over the Sorting Trays | Gorren Redpick (Redpick Yard) | 21 | bring 10 default:acacia_wood | 820 | - |
| r20_anchor_065_02 | Hunters at the Water Shade | Gorren Redpick (Redpick Yard) | 21 | kill 4 hyena [in kragmar_speargrass_reach] | 820 | - |
| r20_anchor_022_03 | Night at the Water Jars | Brakka Jarward (Speargrass Wellhold) | 23 | kill 4 scorpion [in kragmar_speargrass_reach] | 900 | r20_anchor_022_02 |
| r20_anchor_042_03 | Raiders at the Signal Fire | Morga Cutgrass (Cutgrass Watch) | 23 | kill 4 goblin_raider [in kragmar_speargrass_reach] | 900 | r20_anchor_042_02 |
| r20_anchor_065_03 | Stings in the Drill Stack | Gorren Redpick (Redpick Yard) | 23 | kill 4 scorpion [in kragmar_speargrass_reach] | 900 | r20_anchor_065_02 |
| r20_orc_journey_02 | Word for Gorren Redpick | Brakka Jarward (Speargrass Wellhold) | 24 | talk to Gorren Redpick (r20_anchor_065) | 705 | - |
| r20_orc_journey_03 | Word for Drek Rampbinder | Gorren Redpick (Redpick Yard) | 31 | talk to Drek Rampbinder (r20_anchor_043) | 915 | - |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| goblin_hound | Goblin Raider Hound | aggressive | - | 98.8% of land, L21-30 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| goblin_raider | Goblin Raider | aggressive | - | 98.8% of land, L21-30 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| goblin_slinger | Goblin Slinger | aggressive | - | 98.8% of land, L21-30 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| hyena | Hyena | aggressive | 98.8% of land, L21-30 | 98.8% of land, L21-30 | dry_dirt_with_dry_grass, mesa_clay |
| mesa_golem | Mesa Golem | aggressive | 39.8% of land, L21-30 | 39.8% of land, L21-30 | stone, mesa_clay |
| scorpion | Scorpion | aggressive | - | 98.8% of land, L21-30 | dry_dirt_with_dry_grass, mesa_clay |
| shore_crab | Shore Crab | neutral | 9920 nodes², L21-23 | 9920 nodes², L21-23 | sand (dry, within 6 nodes of water) |
| speargrass_tiger | Speargrass Tiger | aggressive | 98.8% of land, L21-30 | - | dry_dirt_with_dry_grass, mesa_clay |
| vulture | Vulture | aggressive | 39.8% of land, L21-30 | - | mesa_clay |
| zebra | Zebra | neutral | 59.0% of land, L21-30 | - | dry_dirt_with_dry_grass |

In the palette but no host ground in this zone: Crag Eagle, Mountain Ram.

**Camps and guard posts:**

- anchor_042 Cutgrass Watch at -650, 1250: guard post, guard_throng × 2-3, respawn 180-360 s, level there L28.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 15 | primary | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 1440 / 1044 | -1413,1844 → -483,1535 |
| 24 | secondary | anchor_022 (Speargrass Wellhold, kragmar_speargrass_reach) | joins road 15 | 234 / 234 | -852,1566 → -636,1543 |
| 30 | secondary | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | anchor_022 (Speargrass Wellhold, kragmar_speargrass_reach) | 802 / 524 | -1345,1563 → -883,1569 |
| 44 | trail | anchor_042 (Cutgrass Watch, kragmar_speargrass_reach) | joins road 15 | 322 / 320 | -639,1256 → -563,1511 |
| 65 | trail | anchor_065 (Redpick Yard, kragmar_speargrass_reach) | joins road 30 | 418 / 414 | -1058,1292 → -1156,1638 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

