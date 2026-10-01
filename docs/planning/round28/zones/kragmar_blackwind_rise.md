# Blackwind Rise (`kragmar_blackwind_rise`)

Zone 21 · contested 31-40 · contested · race region **undead** · levels **31-40** · contested · relief `highland` · seed 42

Map: [maps/kragmar_blackwind_rise.png](maps/kragmar_blackwind_rise.png). Machine-readable: [kragmar_blackwind_rise.json](kragmar_blackwind_rise.json). Coordinates are world nodes (x east, z north, y up).

Race track (undead): step 5 of the track Stillgrave Hollow → Mournfen → Nhal Veyr → Ossuary Reach → Blackwind Rise.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2492..-904, z 100..1156 (centroid -1689, 630) |
| Land area | 1051360 nodes² (≈ 1.05 km²) |
| Hub point (authored) | -1800, 700 |
| Height above sea | min 0, p10 92, median 166, p90 262, max 372 |
| Slope | 58.1% steep (>1 node/node), 22.1% cliff (>2) |
| Biomes (measured) | bone_forest 71.2%, blight 25.3%, swamp 2.8%, badlands 0.4%, beach 0.2%, meadows 0.1%, savanna 0.1% |
| Neighbours (land border) | front_broken_causeway (568 nodes, mid -1103,377), front_gravesalt_escarpment (1632 nodes, mid -1878,172), kragmar_bannerbreak_mesa (576 nodes, mid -914,693), kragmar_nhal_veyr (892 nodes, mid -1691,1077), kragmar_ossuary_reach (504 nodes, mid -2212,1074), kragmar_speargrass_reach (476 nodes, mid -1149,1028) |
| Sea coast | 1624 nodes of coastline; sea-beach sand 3824 nodes²; lake/river-bank sand 6480 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 143760 nodes² |
| Protected / drift band | 1.2% of land protected (towns, villages, camps/POIs, road corridors); 6.1% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -2363, 1003 | x -2396..-2328, z 964..1040 | 2800 | L31 |
| B2 | -2461, 339 | x -2492..-2428, z 304..368 | 912 | L38-39 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 13.2%, L32 10.3%, L33 10.2%, L34 10.8%, L35 13.6%, L36 12.7%, L37 8.1%, L38 6.7%, L39 6.3%, L40 8.1%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_039 | outpost | Ashveil Watch | -2018 | 107 | 834 | 33 | poi x -2026..-2011, z 826..841 |
| anchor_040 | outpost | Hollowarch Station | -1468 | 179 | 434 | 37 | poi x -1476..-1461, z 426..441 |
| anchor_056 | bandit hideout | Pallcloth Den | -1800 | 159 | 430 | 37 | camp x -1808..-1793, z 422..437 |
| anchor_095 | rare route | Marrowclaw's Scrape | -1818 | 263 | 604 | 35 | poi x -1824..-1813, z 598..609 |

## Protected areas

- poi Ashveil Watch (anchor_039): x -2026..-2011, z 826..841
- poi Hollowarch Station (anchor_040): x -1476..-1461, z 426..441
- camp Pallcloth Den (anchor_056): x -1808..-1793, z 422..437
- poi Marrowclaw's Scrape (anchor_095): x -1824..-1813, z 598..609
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Ashveil Watch (`r20_anchor_039`, anchor_039) at -2018, 107, 834

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Vaska Ashlistener | -2016, 108, 834 | r20_anchor_039_01, r20_anchor_039_02, r20_anchor_039_03 |

Distances: zone edge N 284 (kragmar_nhal_veyr), S 712 (front_gravesalt_escarpment), E 1096 (kragmar_bannerbreak_mesa), W 236 (coastal_shelf); nearest other-zone land 252 NE; sea 227 W; sea-beach sand 267 W; nearest road 11.
Nearest hubs (straight / by road): Archshadow Post 1385 / no road; Splitbolt Station 1661 / no road; Cinderline Watch 2370 / no road; Last Hedge Redoubt 2650 / no road; Red Ramp Post 1644 / 4065.

### Hollowarch Station (`r20_anchor_040`, anchor_040) at -1468, 179, 434

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Orrel Hollowstep | -1466, 180, 434 | r20_anchor_040_01, r20_anchor_040_02, r20_anchor_040_03 |

Distances: zone edge N 668 (kragmar_nhal_veyr), S 232 (front_gravesalt_escarpment), E 492 (front_broken_causeway), W 864 (coastal_shelf); nearest other-zone land 200 SE; sea 849 W; sea-beach sand 873 W; nearest road 12.
Nearest hubs (straight / by road): Archshadow Post 885 / no road; Red Ramp Post 1179 / 1512; Splitbolt Station 1398 / no road; Tornstandard Hold 1744 / 2348; Cinderline Watch 1703 / no road.

### Current quests (6, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_039_01 | Keep the Lamps Burning | Vaska Ashlistener (Ashveil Watch) | 31 | bring 6 default:coal_lump | 1220 | - |
| r20_anchor_039_02 | Ash Among Living Branches | Vaska Ashlistener (Ashveil Watch) | 31 | kill 3 gravewood_treant [in kragmar_blackwind_rise] | 1220 | - |
| r20_anchor_040_01 | The Dispatch Shelf | Orrel Hollowstep (Hollowarch Station) | 31 | bring 8 grug_trees:gravewood_wood | 1220 | - |
| r20_anchor_040_02 | Claws Beneath the Arch | Orrel Hollowstep (Hollowarch Station) | 31 | kill 3 plaguehide_bear [in kragmar_blackwind_rise] | 1220 | - |
| r20_anchor_039_03 | The Pallcloth Thieves | Vaska Ashlistener (Ashveil Watch) | 33 | kill 4 bandit_archer [in kragmar_blackwind_rise] | 1300 | r20_anchor_039_02 |
| r20_anchor_040_03 | The Watch Under the Storm | Orrel Hollowstep (Hollowarch Station) | 40 | kill 3 guard_accord [in elandor_stormvault_heights] | 1975 | r20_anchor_040_02 |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| blightfang_wolf | Blightfang Wolf | aggressive | 70.9% of land, L31-40 | 70.9% of land, L31-40 | dirt_with_bone_litter |
| bone_weevil | Bone Weevil | critter | 96.3% of land, L31-40 | - | blight_dirt, dirt_with_bone_litter |
| gaunt_stag | Gaunt Stag | neutral | 70.9% of land, L31-40 | - | dirt_with_bone_litter |
| gravewood_treant | Gravewood Treant | aggressive | - | 70.9% of land, L31-40 | dirt_with_bone_litter |
| gull | Gull | critter | 2192 nodes² | - | sand |
| pale_spider | Bonelurker Spider | aggressive | - | 96.3% of land, L31-40 | dry_dirt_with_dry_grass, blight_dirt, dirt_with_bone_litter |
| plaguehide_bear | Plaguehide Bear | aggressive | 96.3% of land, L31-40 | - | dry_dirt_with_dry_grass, blight_dirt, dirt_with_bone_litter |
| shore_crab | Shore Crab | neutral | 3824 nodes², L31-39 | 3824 nodes², L31-39 | sand (dry, within 6 nodes of water) |
| skeleton_archer | Skeleton Archer | aggressive | - | 96.3% of land, L31-40 | blight_dirt, dirt_with_bone_litter |

In the palette but no host ground in this zone: Bear, Giant Spider, Stag, Wolf.

**Camps and guard posts:**

- anchor_039 Ashveil Watch at -2018, 834: guard post, guard_throng × 2-3, respawn 180-360 s, level there L33.
- anchor_040 Hollowarch Station at -1468, 434: guard post, guard_throng × 2-3, respawn 180-360 s, level there L37.
- anchor_056 Pallcloth Den at -1800, 430: bandit, bandit/bandit_archer × 3-5, respawn 120-300 s, level there L37.

**Rares (knowledge rewards, not quest targets):** Marrowclaw (plaguehide_bear, the bone forest, route -1866,580 → -1802,644 → -1762,588, L35, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 26 | secondary | anchor_039 (Ashveil Watch, kragmar_blackwind_rise) | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | 584 / 436 | -2007,823 → -2024,1117 |
| 42 | trail | anchor_040 (Hollowarch Station, kragmar_blackwind_rise) | joins road 27 | 1438 / 590 | -1458,428 → -908,485 |
| 56 | trail | anchor_056 (Pallcloth Den, kragmar_blackwind_rise) | joins road 30 | 1756 / 1134 | -1805,441 → -1487,1084 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

