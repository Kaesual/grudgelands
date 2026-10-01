# Ossuary Reach (`kragmar_ossuary_reach`)

Zone 20 · home zone 21-30 · throng · race region **undead** · levels **21-30** · peaceful · relief `rolling_hills` · seed 42

Map: [maps/kragmar_ossuary_reach.png](maps/kragmar_ossuary_reach.png). Machine-readable: [kragmar_ossuary_reach.json](kragmar_ossuary_reach.json). Coordinates are world nodes (x east, z north, y up).

Race track (undead): step 4 of the track Stillgrave Hollow → Mournfen → Nhal Veyr → Ossuary Reach → Blackwind Rise.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2588..-2032, z 1036..2204 (centroid -2310, 1568) |
| Land area | 327136 nodes² (≈ 0.33 km²) |
| Hub point (authored) | -2400, 1500 |
| Height above sea | min 0, p10 7, median 56, p90 84, max 177 |
| Slope | 10.5% steep (>1 node/node), 1.2% cliff (>2) |
| Biomes (measured) | bone_forest 63.0%, blight 29.9%, swamp 7.1% |
| Neighbours (land border) | kragmar_blackwind_rise (508 nodes, mid -2210,1070), kragmar_mournfen (512 nodes, mid -2232,2029), kragmar_nhal_veyr (1040 nodes, mid -2143,1501), kragmar_stillgrave_hollow (268 nodes, mid -2470,2168) |
| Sea coast | 1736 nodes of coastline; sea-beach sand 16560 nodes²; lake/river-bank sand 0 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 0 nodes² |
| Protected / drift band | 1.9% of land protected (towns, villages, camps/POIs, road corridors); 8.2% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -2464, 1757 | x -2492..-2436, z 1620..1900 | 6384 | L22-25 |
| B2 | -2453, 2105 | x -2520..-2420, z 2052..2148 | 3744 | L21 |
| B3 | -2461, 1263 | x -2484..-2432, z 1180..1348 | 3184 | L28-29 |
| B4 | -2560, 2173 | x -2588..-2536, z 2132..2204 | 1952 | L21 |
| B5 | -2431, 1458 | x -2444..-2420, z 1432..1480 | 496 | L26-27 |
| B6 | -2391, 1045 | x -2400..-2380, z 1036..1056 | 352 | L30 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L21 9.0%, L22 10.3%, L23 11.8%, L24 10.0%, L25 9.4%, L26 10.0%, L27 7.3%, L28 9.3%, L29 10.5%, L30 12.5%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_020 | village | Ossuary Ledgerstead | -2380 | 50 | 1600 | 25 | village x -2392..-2369, z 1588..1611 |
| anchor_038 | outpost | Boneledger Post | -2268 | 56 | 1234 | 29 | poi x -2276..-2261, z 1226..1241 |
| anchor_064 | mine | Memoryvein Dig | -2418 | 31 | 1264 | 28 | poi x -2428..-2409, z 1254..1273 |

## Protected areas

- village Ossuary Ledgerstead (anchor_020): x -2392..-2369, z 1588..1611
- poi Boneledger Post (anchor_038): x -2276..-2261, z 1226..1241
- poi Memoryvein Dig (anchor_064): x -2428..-2409, z 1254..1273
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Ossuary Ledgerstead (`r20_anchor_020`, anchor_020) at -2380, 50, 1600

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Sovel Namekeeper | -2378, 51, 1600 | r20_anchor_020_01, r20_anchor_020_02, r20_anchor_020_03, r20_undead_journey_02 |

Distances: zone edge N 528 (kragmar_mournfen), S 560 (kragmar_blackwind_rise), E 176 (kragmar_nhal_veyr), W 84 (coastal_shelf); nearest other-zone land 172 E; sea 84 W; sea-beach sand 72 W; nearest road 19.
Nearest hubs (straight / by road): Memoryvein Dig 338 / 539; Nhal Veyr 589 / 677; Mournfen Village 638 / 1194; Mournfen Outpost 573 / 1411; Boneledger Post 383 / 1462.

### Boneledger Post (`r20_anchor_038`, anchor_038) at -2268, 56, 1234

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Mereth Rubbinghand | -2266, 57, 1234 | r20_anchor_038_01, r20_anchor_038_02, r20_anchor_038_03 |

Distances: zone edge N 836 (kragmar_mournfen), S 176 (kragmar_blackwind_rise), E 184 (kragmar_nhal_veyr), W 212 (coastal_shelf); nearest other-zone land 166 NE; sea 198 W; sea-beach sand 180 W; nearest road 14.
Nearest hubs (straight / by road): Ashveil Watch 472 / 738; Nhal Veyr 538 / 1012; Ossuary Ledgerstead 383 / 1462; Mournfen Village 868 / 1540; Mournfen Bandit Camp 1055 / 1679.

### Memoryvein Dig (`r20_anchor_064`, anchor_064) at -2418, 31, 1264

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Neris Fossilhand | -2416, 32, 1264 | r20_anchor_064_01, r20_anchor_064_02, r20_anchor_064_03, r20_undead_journey_03 |

Distances: zone edge N 876 (kragmar_stillgrave_hollow), S 176 (coastal_shelf), E 320 (kragmar_nhal_veyr), W 68 (coastal_shelf); nearest other-zone land 212 S; sea 60 W; sea-beach sand 34 W; nearest road 17.
Nearest hubs (straight / by road): Ossuary Ledgerstead 338 / 539; Nhal Veyr 662 / 1027; Mournfen Village 916 / 1544; Mournfen Outpost 894 / 1761; Boneledger Post 153 / 1812.

### Current quests (11, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_020_01 | Shelves for the Remembered | Sovel Namekeeper (Ossuary Ledgerstead) | 21 | bring 8 grug_trees:gravewood_wood | 820 | - |
| r20_anchor_020_02 | Teeth Beside the Archive | Sovel Namekeeper (Ossuary Ledgerstead) | 21 | kill 4 blightfang_wolf [in kragmar_ossuary_reach] | 820 | - |
| r20_anchor_038_01 | A Shelf for Stone Names | Mereth Rubbinghand (Boneledger Post) | 21 | bring 8 grug_trees:gravewood_wood | 820 | - |
| r20_anchor_038_02 | The Hungry Gravewood | Mereth Rubbinghand (Boneledger Post) | 21 | kill 3 gravewood_treant [in kragmar_ossuary_reach] | 820 | - |
| r20_anchor_064_01 | The Record Shed Frame | Neris Fossilhand (Memoryvein Dig) | 21 | bring 8 grug_trees:gravewood_wood | 820 | - |
| r20_anchor_064_02 | The Cutters' Uneasy Night | Neris Fossilhand (Memoryvein Dig) | 21 | kill 3 gravewood_treant [in kragmar_ossuary_reach] | 820 | - |
| r20_anchor_020_03 | The Trees That Refuse Rest | Sovel Namekeeper (Ossuary Ledgerstead) | 23 | kill 3 gravewood_treant [in kragmar_ossuary_reach] | 900 | r20_anchor_020_02 |
| r20_anchor_038_03 | A Pack on the Ledger Road | Mereth Rubbinghand (Boneledger Post) | 23 | kill 4 blightfang_wolf [in kragmar_ossuary_reach] | 900 | r20_anchor_038_02 |
| r20_anchor_064_03 | A Tool for Unnamed Stone | Neris Fossilhand (Memoryvein Dig) | 23 | bring 1 grug_materials:pick_stone | 900 | r20_anchor_064_02 |
| r20_undead_journey_02 | Word for Neris Fossilhand | Sovel Namekeeper (Ossuary Ledgerstead) | 24 | talk to Neris Fossilhand (r20_anchor_064) | 705 | - |
| r20_undead_journey_03 | Word for Vaska Ashlistener | Neris Fossilhand (Memoryvein Dig) | 31 | talk to Vaska Ashlistener (r20_anchor_039) | 915 | - |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| blightfang_wolf | Blightfang Wolf | aggressive | 60.7% of land, L21-30 | 60.7% of land, L21-30 | dirt_with_bone_litter |
| bone_weevil | Bone Weevil | critter | 92.7% of land, L21-30 | - | blight_dirt, dirt_with_bone_litter |
| gaunt_stag | Gaunt Stag | neutral | 60.7% of land, L21-30 | - | dirt_with_bone_litter |
| gravewood_treant | Gravewood Treant | aggressive | - | 60.7% of land, L21-30 | dirt_with_bone_litter |
| pale_spider | Bonelurker Spider | aggressive | - | 92.7% of land, L21-30 | dry_dirt_with_dry_grass, blight_dirt, dirt_with_bone_litter |
| plaguehide_bear | Plaguehide Bear | aggressive | 92.7% of land, L21-30 | - | dry_dirt_with_dry_grass, blight_dirt, dirt_with_bone_litter |
| shore_crab | Shore Crab | neutral | 16560 nodes², L21-30 | 16560 nodes², L21-30 | sand (dry, within 6 nodes of water) |
| skeleton_archer | Skeleton Archer | aggressive | - | 92.7% of land, L21-30 | blight_dirt, dirt_with_bone_litter |

In the palette but no host ground in this zone: Bear, Giant Spider, Stag, Wolf.

**Camps and guard posts:**

- anchor_038 Boneledger Post at -2268, 1234: guard post, guard_throng × 2-3, respawn 180-360 s, level there L29.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 23 | secondary | anchor_020 (Ossuary Ledgerstead, kragmar_ossuary_reach) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 324 / 176 | -2369,1616 → -2212,1646 |
| 26 | secondary | anchor_039 (Ashveil Watch, kragmar_blackwind_rise) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 584 / 8 | -2045,1102 → -2038,1109 |
| 41 | trail | anchor_038 (Boneledger Post, kragmar_ossuary_reach) | joins road 26 | 276 / 232 | -2258,1224 → -2046,1153 |
| 64 | trail | anchor_064 (Memoryvein Dig, kragmar_ossuary_reach) | joins road 23 | 430 / 424 | -2405,1275 → -2307,1639 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

