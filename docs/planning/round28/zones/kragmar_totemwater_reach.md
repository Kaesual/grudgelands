# Totemwater Reach (`kragmar_totemwater_reach`)

Zone 31 · home zone 21-30 · throng · race region **troll** · levels **21-30** · peaceful · relief `wetland_delta` · seed 42

Map: [maps/kragmar_totemwater_reach.png](maps/kragmar_totemwater_reach.png). Machine-readable: [kragmar_totemwater_reach.json](kragmar_totemwater_reach.json). Coordinates are world nodes (x east, z north, y up).

Race track (troll): step 5 of the track Kapok Cradle → Raincall Basin → Kezamba → Whispering Reedlands → Totemwater Reach → Thunderroot Wilds.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 2064..2728, z 992..2168 (centroid 2401, 1547) |
| Land area | 501424 nodes² (≈ 0.50 km²) |
| Hub point (authored) | 2400, 1500 |
| Height above sea | min 0, p10 2, median 13, p90 76, max 164 |
| Slope | 8.2% steep (>1 node/node), 2.1% cliff (>2) |
| Biomes (measured) | deep_jungle 37.4%, jungle_edge 36.7%, swamp 25.8% |
| Neighbours (land border) | kragmar_kapok_cradle (212 nodes, mid 2586,2163), kragmar_kezamba (848 nodes, mid 2113,1410), kragmar_raincall_basin (796 nodes, mid 2293,1989), kragmar_thunderroot_wilds (580 nodes, mid 2313,1042) |
| Sea coast | 2564 nodes of coastline; sea-beach sand 50976 nodes²; lake/river-bank sand 10992 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 19056 nodes² |
| Protected / drift band | 0.3% of land protected (towns, villages, camps/POIs, road corridors); 1.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 2626, 1403 | x 2512..2728, z 1248..1576 | 22864 | L25-28 |
| B2 | 2596, 1967 | x 2524..2696, z 1752..2168 | 22352 | L21-24 |
| B3 | 2595, 1634 | x 2556..2620, z 1572..1744 | 5024 | L24-25 |
| B4 | 2603, 1046 | x 2596..2608, z 1020..1072 | 400 | L30 |
| B5 | 2592, 1003 | x 2584..2596, z 996..1012 | 144 | L30 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L21 8.7%, L22 9.1%, L23 10.6%, L24 11.4%, L25 10.7%, L26 13.7%, L27 9.9%, L28 9.1%, L29 8.9%, L30 7.9%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_047 | outpost | Totemwater Post | 2400 | 3 | 1350 | 27 | poi x 2392..2407, z 1342..1357 |

## Protected areas

- poi Totemwater Post (anchor_047): x 2392..2407, z 1342..1357
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Totemwater Post (`r20_anchor_047`, anchor_047) at 2400, 3, 1350

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Tokai Knotreader | 2402, 4, 1350 | r20_anchor_047_01, r20_anchor_047_02, r20_anchor_047_03 |

Distances: zone edge N 752 (kragmar_raincall_basin), S 340 (inland_water), E 292 (coastal_shelf), W 288 (kragmar_kezamba); nearest other-zone land 269 W; sea 164 E; sea-beach sand 121 E; nearest road 10.
Nearest hubs (straight / by road): Thunderstep Watch 844 / 1071; Kezamba 618 / 1158; Raincall Bandit Camp 1028 / 1960; Whisperreed Landing 1545 / 2197; Reedstone Cut 1375 / 2336.

### Current quests (3, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_047_01 | Rope Rack Timbers | Tokai Knotreader (Totemwater Post) | 21 | bring 8 default:junglewood | 820 | - |
| r20_anchor_047_02 | Jaws at the River Path | Tokai Knotreader (Totemwater Post) | 21 | kill 3 crocodile or reed_crocodile [in kragmar_totemwater_reach] | 820 | - |
| r20_anchor_047_03 | Mud Around the Marker | Tokai Knotreader (Totemwater Post) | 23 | kill 4 bog_ooze or sullen_bog_ooze [in kragmar_totemwater_reach] | 900 | r20_anchor_047_02 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| armored_crab | Barnacle Pincher | aggressive | 4.6% of land, L25-30 | - |  |
| bank_crab | Bank Crab | neutral | 4.0% of land, L21-24 | - |  |
| reed_crocodile | Reed Crocodile | aggressive | 8.4% of land, L21-23 | 1.6% of land, L21-23 |  |
| reed_jungle_lynx | Reed Jungle Lynx | aggressive | 66.7% of land, L21-30 | - |  |
| reed_tapir | Reed Tapir | neutral | 60.2% of land, L21-30 | - |  |
| shore_crab | Shore Crab | neutral | 50976 nodes², L21-30 | 50976 nodes², L21-30 | sand (dry, within 6 nodes of water) |
| sullen_bog_ooze | Bubbling Bog Ooze | aggressive | 8.4% of land, L21-23 | 28.3% of land, L21-23 |  |
| wandering_wisp | Wandering Wisp | aggressive | - | 98.4% of land, L21-30 |  |

**Camps and guard posts:**

- anchor_047 Totemwater Post at 2400, 1350: guard post, guard_throng × 2-3, respawn 180-360 s, level there L27.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 49 | trail | anchor_047 (Totemwater Post, kragmar_totemwater_reach) | joins road 28 | 561 / 286 | 2390,1349 → 2142,1250 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

