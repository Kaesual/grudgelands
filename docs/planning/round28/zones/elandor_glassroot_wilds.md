# Glassroot Wilds (`elandor_glassroot_wilds`)

Zone 16 · contested 31-40 · contested · race region **elf** · levels **31-40** · contested · relief `highland` · seed 42

Map: [maps/elandor_glassroot_wilds.png](maps/elandor_glassroot_wilds.png). Machine-readable: [elandor_glassroot_wilds.json](elandor_glassroot_wilds.json). Coordinates are world nodes (x east, z north, y up).

Race track (elf): step 6 of the track Silverleaf Glades → Starbough Vale → Lethariel → Lorindor → Moonfall Wood → Glassroot Wilds.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 756..2616, z -1192..-192 (centroid 1662, -683) |
| Land area | 1254320 nodes² (≈ 1.25 km²) |
| Hub point (authored) | 1800, -700 |
| Height above sea | min 0, p10 77, median 145, p90 215, max 316 |
| Slope | 38.8% steep (>1 node/node), 10.6% cliff (>2) |
| Biomes (measured) | deep_forest 48.0%, jungle_fringe 35.4%, swamp 8.6%, elf_forest 7.7%, badlands 0.2%, meadows 0.1% |
| Neighbours (land border) | elandor_ashenward_march (832 nodes, mid 841,-761), elandor_lethariel (780 nodes, mid 1612,-1066), elandor_lorindor (760 nodes, mid 1032,-1155), elandor_moonfall_wood (820 nodes, mid 2209,-989), front_shattered_line (536 nodes, mid 1189,-279), front_skyglass_canopy (1284 nodes, mid 2056,-231) |
| Sea coast | 1312 nodes of coastline; sea-beach sand 4032 nodes²; lake/river-bank sand 8272 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 100992 nodes² |
| Protected / drift band | 0.5% of land protected (towns, villages, camps/POIs, road corridors); 2.1% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 2491, -941 | x 2468..2528, z -1012..-868 | 2288 | L32-33 |
| B2 | 2512, -577 | x 2492..2548, z -624..-528 | 1280 | L36-37 |
| B3 | 2537, -322 | x 2528..2544, z -332..-308 | 256 | L39-40 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 8.0%, L32 10.7%, L33 13.2%, L34 13.8%, L35 11.6%, L36 11.0%, L37 6.9%, L38 6.5%, L39 7.9%, L40 10.3%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_036 | outpost | Glassroot Gate | 1932 | 171 | -566 | 36 | poi x 1924..1939, z -574..-559 |
| anchor_054 | bandit hideout | Rootsnare Camp | 1776 | 181 | -406 | 38 | camp x 1768..1783, z -414..-399 |

## Protected areas

- poi Glassroot Gate (anchor_036): x 1924..1939, z -574..-559
- camp Rootsnare Camp (anchor_054): x 1768..1783, z -414..-399
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Glassroot Gate (`r20_anchor_036`, anchor_036) at 1932, 171, -566

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Faeris Rootbinder | 1934, 172, -566 | r20_anchor_036_01, r20_anchor_036_02, r20_anchor_036_03 |

Distances: zone edge N 316 (front_skyglass_canopy), S 448 (elandor_moonfall_wood), E 580 (coastal_shelf), W 1048 (inland_water); nearest other-zone land 314 N; sea 551 E; sea-beach sand 560 E; nearest road 14.
Nearest hubs (straight / by road): Thunderstep Watch 1116 / no road; Tornstandard Hold 1955 / no road; Red Ramp Post 2719 / no road; Cinderline Watch 2300 / 4128; Last Hedge Redoubt 1636 / 4938.

### Current quests (3, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_036_01 | Stone Under the Passage | Faeris Rootbinder (Glassroot Gate) | 31 | bring 10 default:cobble | 1220 | - |
| r20_anchor_036_02 | Rootsnare's Stolen Cloth | Faeris Rootbinder (Glassroot Gate) | 31 | kill 4 bandit [in elandor_glassroot_wilds] | 1220 | - |
| r20_anchor_036_03 | The Other Rootwatch | Faeris Rootbinder (Glassroot Gate) | 40 | kill 3 guard_throng [in kragmar_thunderroot_wilds] | 1975 | r20_anchor_036_02 |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bear | Bear | aggressive | 55.4% of land, L31-40 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| jungle_ape | Jungle Ape | aggressive | 35.6% of land, L31-40 | - | dirt_with_rainforest_litter, dirt_with_canopy_litter |
| jungle_spider | Jungle Spider | aggressive | - | 90.8% of land, L31-40 | dirt_with_rainforest_litter, dirt_with_canopy_litter, dirt_with_forest_litter, dirt_with_silver_litter |
| panther | Panther | aggressive | - | 35.6% of land, L31-40 | dirt_with_rainforest_litter, dirt_with_canopy_litter |
| serpent | Serpent | aggressive | 44.3% of land, L31-40 | - | dirt_with_rainforest_litter, dirt_with_canopy_litter, mud |
| shore_crab | Shore Crab | neutral | 4032 nodes², L32-40 | 4032 nodes², L32-40 | sand (dry, within 6 nodes of water) |
| stag | Stag | neutral | 47.7% of land, L31-40 | - | dirt_with_grass, dirt_with_forest_litter |
| wisp | Wisp | aggressive | - | 99.6% of land, L31-40 | dirt_with_rainforest_litter, dirt_with_bone_litter, dirt_with_canopy_litter, dirt_with_forest_litter, dirt_with_silver_litter, mud |
| wolf | Wolf | aggressive | 47.7% of land, L31-40 | 47.7% of land, L31-40 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter |

In the palette but no host ground in this zone: Blightfang Wolf, Bone Weevil, Gaunt Stag, Plaguehide Bear, Skeleton Archer.

**Camps and guard posts:**

- anchor_036 Glassroot Gate at 1932, -566: guard post, guard_accord × 2-3, respawn 180-360 s, level there L36.
- anchor_054 Rootsnare Camp at 1776, -406: bandit, bandit/bandit_archer × 3-5, respawn 120-300 s, level there L38.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 14 | secondary | anchor_036 (Glassroot Gate, elandor_glassroot_wilds) | anchor_009 (Lethariel, elandor_lethariel) | 897 / 642 | 1924,-578 → 1835,-1004 |
| 54 | trail | anchor_054 (Rootsnare Camp, elandor_glassroot_wilds) | joins road 14 | 246 / 246 | 1778,-417 → 1910,-610 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

