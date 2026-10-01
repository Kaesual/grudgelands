# Ashenward March (`elandor_ashenward_march`)

Zone 10 · contested 31-40 · contested · race region **human** · levels **31-40** · contested · relief `rolling_hills` · seed 42

Map: [maps/elandor_ashenward_march.png](maps/elandor_ashenward_march.png). Machine-readable: [elandor_ashenward_march.json](elandor_ashenward_march.json). Coordinates are world nodes (x east, z north, y up).

Race track (human): step 5 of the track Dawnmere Fields → Goldmead Vale → Highcourt → Whitebridge Shire → Ashenward March.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -892..988, z -1276..-92 (centroid 7, -671) |
| Land area | 1533984 nodes² (≈ 1.53 km²) |
| Hub point (authored) | 0, -700 |
| Height above sea | min 32, p10 49, median 76, p90 151, max 349 |
| Slope | 9.1% steep (>1 node/node), 1.0% cliff (>2) |
| Biomes (measured) | deep_forest 53.2%, meadows 32.2%, swamp 13.9%, badlands 0.3%, jungle_fringe 0.2%, crags_snowy 0.1%, crags 0.1%, elf_forest 0.1%, savanna 0.0% |
| Neighbours (land border) | elandor_glassroot_wilds (832 nodes, mid 846,-763), elandor_highcourt (1340 nodes, mid -27,-1150), elandor_lorindor (500 nodes, mid 588,-1181), elandor_stormvault_heights (508 nodes, mid -880,-739), elandor_whitebridge_shire (672 nodes, mid -687,-1109), front_broken_causeway (1412 nodes, mid -482,-269), front_shattered_line (1304 nodes, mid 496,-195) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 19056 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 72768 nodes² |
| Protected / drift band | 1.5% of land protected (towns, villages, camps/POIs, road corridors); 7.3% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 9.1%, L32 11.1%, L33 11.3%, L34 11.6%, L35 12.0%, L36 12.1%, L37 7.9%, L38 8.3%, L39 8.2%, L40 8.5%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_031 | outpost | Cinderline Watch | -350 | 56 | -850 | 33 | poi x -358..-343, z -858..-843 |
| anchor_032 | outpost | Last Hedge Redoubt | 300 | 77 | -450 | 37 | poi x 292..307, z -458..-443 |
| anchor_052 | bandit hideout | Coalbrand Yard | -24 | 112 | -406 | 38 | camp x -32..-17, z -414..-399 |
| anchor_071 | clash site | Ashen Wheelbreak | -274 | 115 | -296 | 39 | poi x -282..-267, z -304..-289 |
| anchor_072 | clash site | Hedgefire Crossing | 250 | 160 | -320 | 39 | poi x 242..257, z -328..-313 |
| anchor_092 | rare route | Whitefang's Cold Den | -180 | 37 | -650 | 35 | poi x -186..-175, z -656..-645 |

## Protected areas

- poi Cinderline Watch (anchor_031): x -358..-343, z -858..-843
- poi Last Hedge Redoubt (anchor_032): x 292..307, z -458..-443
- camp Coalbrand Yard (anchor_052): x -32..-17, z -414..-399
- poi Ashen Wheelbreak (anchor_071): x -282..-267, z -304..-289
- poi Hedgefire Crossing (anchor_072): x 242..257, z -328..-313
- poi Whitefang's Cold Den (anchor_092): x -186..-175, z -656..-645
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Cinderline Watch (`r20_anchor_031`, anchor_031) at -350, 56, -850

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Toren Waterbarrel | -348, 57, -850 | r20_anchor_031_01, r20_anchor_031_02, r20_anchor_031_03 |

Distances: zone edge N 656 (front_broken_causeway), S 332 (elandor_highcourt), E 1156 (elandor_glassroot_wilds), W 544 (elandor_stormvault_heights); nearest other-zone land 291 S; sea 1247 SW; sea-beach sand 1176 SW; nearest road 12.
Nearest hubs (straight / by road): Last Hedge Redoubt 763 / 1144; Archshadow Post 1218 / 1795; Tornstandard Hold 1465 / no road; Hollowarch Station 1703 / no road; Red Ramp Post 1724 / no road.

### Last Hedge Redoubt (`r20_anchor_032`, anchor_032) at 300, 77, -450

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Nella Hedgeward | 302, 78, -450 | r20_anchor_032_01, r20_anchor_032_02, r20_anchor_032_03 |

Distances: zone edge N 280 (front_shattered_line), S 740 (elandor_highcourt), E 644 (inland_water), W 1148 (front_broken_causeway); nearest other-zone land 274 N; sea 1413 S; sea-beach sand 1425 S; nearest road 10.
Nearest hubs (straight / by road): Cinderline Watch 763 / 1144; Tornstandard Hold 924 / no road; Red Ramp Post 1486 / no road; Archshadow Post 1800 / 2824; Thunderstep Watch 1887 / no road.

### Current quests (6, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_031_01 | A Wall Against Embers | Toren Waterbarrel (Cinderline Watch) | 31 | bring 10 default:cobble | 1220 | - |
| r20_anchor_031_02 | The Ashen Wood Stirs | Toren Waterbarrel (Cinderline Watch) | 31 | kill 3 ashen_treant [in elandor_ashenward_march] | 1220 | - |
| r20_anchor_032_01 | Posts for the Last Hedge | Nella Hedgeward (Last Hedge Redoubt) | 31 | bring 8 default:wood | 1220 | - |
| r20_anchor_032_02 | Dead on the Dispatch Road | Nella Hedgeward (Last Hedge Redoubt) | 31 | kill 4 skeleton_raider [in elandor_ashenward_march] | 1220 | - |
| r20_anchor_031_03 | Coalbrand's Watchers | Toren Waterbarrel (Cinderline Watch) | 33 | kill 4 bandit_archer [in elandor_ashenward_march] | 1300 | r20_anchor_031_02 |
| r20_anchor_032_03 | Standards Across the Mesa | Nella Hedgeward (Last Hedge Redoubt) | 40 | kill 3 guard_throng [in kragmar_bannerbreak_mesa] | 1975 | r20_anchor_032_02 |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| ashen_treant | Ashen Treant | aggressive | - | 52.8% of land, L31-40 | dirt_with_forest_litter |
| bear | Bear | aggressive | 85.2% of land, L31-40 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| carrion_crow | Carrion Crow | neutral | 100.0% of land, L31-40 | 100.0% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, snowblock … |
| giant_spider | Giant Spider | aggressive | - | 85.2% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| poacher | Poacher | aggressive | - | 85.2% of land, L31-40 | dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| skeleton_raider | Skeleton Raider | aggressive | - | 100.0% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| stag | Stag | neutral | 85.1% of land, L31-40 | - | dirt_with_grass, dirt_with_forest_litter |
| wisp | Wisp | aggressive | - | 67.3% of land, L31-40 | dirt_with_rainforest_litter, dirt_with_bone_litter, dirt_with_canopy_litter, dirt_with_forest_litter, dirt_with_silver_litter, mud |
| wolf | Wolf | aggressive | 85.1% of land, L31-40 | 85.1% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter |
| zombie | Zombie | aggressive | - | 100.0% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

In the palette but no host ground in this zone: Blightfang Wolf, Bone Weevil, Bonelurker Spider, Gaunt Stag, Plaguehide Bear.

**Camps and guard posts:**

- anchor_031 Cinderline Watch at -350, -850: guard post, guard_accord × 2-3, respawn 180-360 s, level there L33.
- anchor_032 Last Hedge Redoubt at 300, -450: guard post, guard_accord × 2-3, respawn 180-360 s, level there L37.
- anchor_052 Coalbrand Yard at -24, -406: bandit, bandit/bandit_archer × 3-5, respawn 120-300 s, level there L38.

**Rares (knowledge rewards, not quest targets):** Old Whitefang (wolf, the deep forest, route -228,-674 → -164,-610 → -124,-666, L35, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 1 | primary | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | anchor_008 (Highcourt, elandor_highcourt) | 1434 / 100 | -525,-1218 → -430,-1234 |
| 13 | secondary | anchor_031 (Cinderline Watch, elandor_ashenward_march) | joins road 1 | 410 / 404 | -355,-861 → -501,-1223 |
| 33 | trail | anchor_028 (Archshadow Post, elandor_stormvault_heights) | joins road 13 | 1729 / 724 | -668,-308 → -377,-901 |
| 36 | trail | anchor_032 (Last Hedge Redoubt, elandor_ashenward_march) | joins road 13 | 967 / 948 | 290,-450 → -439,-988 |
| 38 | trail | anchor_034 (Petalbank Wardenry, elandor_lorindor) | joins road 2 | 488 / 280 | 613,-1158 → 408,-1269 |
| 52 | trail | anchor_052 (Coalbrand Yard, elandor_ashenward_march) | joins road 13 | 1486 / 1462 | -14,-410 → -471,-1054 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

