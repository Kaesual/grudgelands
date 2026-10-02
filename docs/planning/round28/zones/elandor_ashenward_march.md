# Ashenward March (`elandor_ashenward_march`)

Zone 10 · contested 31-40 · contested · race region **human** · levels **31-40** · contested · relief `rolling_hills` · seed 42

Map: [maps/elandor_ashenward_march.png](maps/elandor_ashenward_march.png). Machine-readable: [elandor_ashenward_march.json](elandor_ashenward_march.json). Coordinates are world nodes (x east, z north, y up).

Race track (human): step 5 of the track Dawnmere Fields → Goldmead Vale → Highcourt → Whitebridge Shire → Ashenward March.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -888..948, z -1276..-320 (centroid 48, -771) |
| Land area | 1216672 nodes² (≈ 1.22 km²) |
| Hub point (authored) | 0, -700 |
| Height above sea | min 21, p10 47, median 67, p90 93, max 238 |
| Slope | 3.8% steep (>1 node/node), 0.1% cliff (>2) |
| Biomes (measured) | deep_forest 54.1%, meadows 31.4%, swamp 13.5%, badlands 0.4%, jungle_fringe 0.2%, elf_forest 0.1%, savanna 0.1%, crags_snowy 0.1%, crags 0.1% |
| Neighbours (land border) | elandor_glassroot_wilds (908 nodes, mid 844,-759), elandor_highcourt (1340 nodes, mid -27,-1150), elandor_lorindor (500 nodes, mid 588,-1181), elandor_stormvault_heights (320 nodes, mid -882,-815), elandor_whitebridge_shire (644 nodes, mid -688,-1108), front_broken_causeway (1276 nodes, mid -436,-472), front_shattered_line (1196 nodes, mid 494,-366) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 16176 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 23360 nodes² |
| Protected / drift band | 1.2% of land protected (towns, villages, camps/POIs, road corridors); 4.4% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 8.9%, L32 10.9%, L33 11.9%, L34 12.1%, L35 11.5%, L36 12.1%, L37 8.4%, L38 8.4%, L39 6.9%, L40 8.8%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_031 | outpost | Cinderline Watch | -350 | 53 | -850 | 34 | poi x -358..-343, z -858..-843 |
| anchor_032 | outpost | Last Hedge Redoubt | 300 | 71 | -570 | 38 | poi x 292..307, z -578..-563 |
| anchor_052 | bandit hideout | Coalbrand Yard | -96 | 46 | -526 | 38 | camp x -104..-89, z -534..-519 |
| anchor_071 | clash site | Ashen Wheelbreak | -274 | 91 | -416 | 40 | poi x -282..-267, z -424..-409 |
| anchor_072 | clash site | Hedgefire Crossing | 250 | 84 | -440 | 40 | poi x 242..257, z -448..-433 |
| anchor_092 | rare route | Whitefang's Cold Den | -180 | 41 | -770 | 35 | poi x -186..-175, z -776..-765 |

## Protected areas

- poi Cinderline Watch (anchor_031): x -358..-343, z -858..-843
- poi Last Hedge Redoubt (anchor_032): x 292..307, z -578..-563
- camp Coalbrand Yard (anchor_052): x -104..-89, z -534..-519
- poi Ashen Wheelbreak (anchor_071): x -282..-267, z -424..-409
- poi Hedgefire Crossing (anchor_072): x 242..257, z -448..-433
- poi Whitefang's Cold Den (anchor_092): x -186..-175, z -776..-765
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Cinderline Watch (`r20_anchor_031`, anchor_031) at -350, 53, -850

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Toren Waterbarrel | -348, 54, -850 | r20_anchor_031_01, r20_anchor_031_02, r20_anchor_031_03 |

Distances: zone edge N 504 (front_broken_causeway), S 332 (elandor_highcourt), E 1156 (elandor_glassroot_wilds), W 544 (elandor_stormvault_heights); nearest other-zone land 291 S; sea 1247 SW; sea-beach sand 1177 SW; nearest road 11.
Nearest hubs (straight / by road): Last Hedge Redoubt 708 / 1987; Tornstandard Hold 1574 / 3287; Glassroot Gate 2288 / 3841; Archshadow Post 1184 / 4005; Splitbolt Station 1724 / 4214.

### Last Hedge Redoubt (`r20_anchor_032`, anchor_032) at 300, 71, -570

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Nella Hedgeward | 302, 72, -570 | r20_anchor_032_01, r20_anchor_032_02, r20_anchor_032_03 |

Distances: zone edge N 192 (front_shattered_line), S 620 (elandor_highcourt), E 588 (elandor_glassroot_wilds), W 996 (front_broken_causeway); nearest other-zone land 190 N; sea 1302 SE; sea-beach sand 1310 S; nearest road 14.
Nearest hubs (straight / by road): Tornstandard Hold 1164 / 1851; Cinderline Watch 708 / 1987; Red Ramp Post 1594 / 2935; Hollowarch Station 2095 / 4326; Glassroot Gate 1636 / 4361.

### Current quests (6, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_031_01 | A Wall Against Embers | Toren Waterbarrel (Cinderline Watch) | 31 | bring 10 default:cobble | 1220 | - |
| r20_anchor_031_02 | The Ashen Wood Stirs | Toren Waterbarrel (Cinderline Watch) | 31 | kill 3 ashen_treant or rootbound_treant [in elandor_ashenward_march] | 1220 | - |
| r20_anchor_032_01 | Posts for the Last Hedge | Nella Hedgeward (Last Hedge Redoubt) | 31 | bring 8 default:wood | 1220 | - |
| r20_anchor_032_02 | Dead on the Dispatch Road | Nella Hedgeward (Last Hedge Redoubt) | 31 | kill 4 skeleton_raider or march_skeleton_raider [in elandor_ashenward_march] | 1220 | - |
| r20_anchor_031_03 | Coalbrand's Watchers | Toren Waterbarrel (Cinderline Watch) | 33 | kill 4 bandit_archer [in elandor_ashenward_march] | 1300 | r20_anchor_031_02 |
| r20_anchor_032_03 | Standards Across the Mesa | Nella Hedgeward (Last Hedge Redoubt) | 40 | kill 3 guard_throng [in kragmar_bannerbreak_mesa] | 1975 | r20_anchor_032_02 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| battle_wisp | Battle Wisp | aggressive | - | 29.2% of land, L34-40 |  |
| briar_web_spider | Briar-Web Spider | aggressive | - | 37.5% of land, L34-40 |  |
| briarpack_wolf | Briarpack Wolf | aggressive | 70.2% of land, L31-40 | - |  |
| entrenched_bandit | Entrenched Bandit | aggressive | 0.8% of land, L31-33 | 0.8% of land, L31-33 |  |
| entrenched_bandit_archer | Entrenched Bandit Archer | aggressive | 1.0% of land, L38-40 | 1.0% of land, L38-40 |  |
| march_skeleton_raider | March Skeleton Raider | aggressive | - | 23.4% of land, L31-33 |  |
| marching_zombie | Marching Zombie | aggressive | - | 22.5% of land, L31-35 |  |
| rootbound_treant | Rootbound Ashen Treant | aggressive | - | 18.0% of land, L31-33 |  |
| territorial_bear | Bramble Bear | aggressive | 37.5% of land, L34-40 | - |  |
| unrelenting_zombie | Trench Shambler | aggressive | - | 38.8% of land, L36-40 |  |
| wartrail_poacher | Wartrail Poacher | aggressive | 0.8% of land, L38-40 | 0.8% of land, L38-40 |  |
| watchful_carrion_crow | Battlefield Crow | neutral | 42.0% of land, L31-40 | - |  |
| watchful_stag | Greatwood Stag | neutral | 30.4% of land, L31-40 | - |  |

**Camps and guard posts:**

- anchor_031 Cinderline Watch at -350, -850: guard post, guard_accord × 2-3, respawn 180-360 s, level there L34.
- anchor_032 Last Hedge Redoubt at 300, -570: guard post, guard_accord × 2-3, respawn 180-360 s, level there L38.
- anchor_052 Coalbrand Yard at -96, -526: bandit, bandit/bandit_archer × 3-5, respawn 30-60 s, level there L38.

**Rares (knowledge rewards, not quest targets):** Old Whitefang (wolf, the deep forest, route -228,-794 → -164,-730 → -124,-786, L35, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 1 | primary | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | anchor_008 (Highcourt, elandor_highcourt) | 1402 / 52 | -480,-1253 → -430,-1234 |
| 13 | secondary | anchor_031 (Cinderline Watch, elandor_ashenward_march) | joins road 1 | 413 / 346 | -350,-861 → -370,-1180 |
| 29 | primary | anchor_008 (Highcourt, elandor_highcourt) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 2860 / 776 | -10,-1061 → -14,-403 |
| 37 | trail | anchor_032 (Last Hedge Redoubt, elandor_ashenward_march) | joins road 29 | 262 / 262 | 289,-561 → 49,-482 |
| 39 | trail | anchor_034 (Petalbank Wardenry, elandor_lorindor) | joins road 2 | 488 / 280 | 613,-1158 → 408,-1269 |
| 53 | trail | anchor_052 (Coalbrand Yard, elandor_ashenward_march) | joins road 29 | 103 / 104 | -91,-536 → -10,-594 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

