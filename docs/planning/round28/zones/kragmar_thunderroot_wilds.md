# Thunderroot Wilds (`kragmar_thunderroot_wilds`)

Zone 32 · contested 31-40 · contested · race region **troll** · levels **31-40** · contested · relief `highland` · seed 42

Map: [maps/kragmar_thunderroot_wilds.png](maps/kragmar_thunderroot_wilds.png). Machine-readable: [kragmar_thunderroot_wilds.json](kragmar_thunderroot_wilds.json). Coordinates are world nodes (x east, z north, y up).

Race track (troll): step 6 of the track Kapok Cradle → Raincall Basin → Kezamba → Whispering Reedlands → Totemwater Reach → Thunderroot Wilds.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 908..2676, z 224..1096 (centroid 1776, 680) |
| Land area | 1141168 nodes² (≈ 1.14 km²) |
| Hub point (authored) | 1800, 700 |
| Height above sea | min 0, p10 65, median 136, p90 213, max 397 |
| Slope | 28.0% steep (>1 node/node), 5.3% cliff (>2) |
| Biomes (measured) | deep_jungle 64.9%, swamp 21.2%, badlands_east 12.6%, jungle_edge 0.5%, badlands 0.3%, jungle_fringe 0.2%, elf_forest 0.1%, savanna 0.1%, deep_forest 0.1% |
| Neighbours (land border) | front_shattered_line (544 nodes, mid 1253,246), front_skyglass_canopy (1004 nodes, mid 2164,306), kragmar_bannerbreak_mesa (840 nodes, mid 983,607), kragmar_kezamba (852 nodes, mid 1736,1037), kragmar_totemwater_reach (568 nodes, mid 2319,1046), kragmar_whispering_reedlands (744 nodes, mid 1141,1032) |
| Sea coast | 1112 nodes of coastline; sea-beach sand 5440 nodes²; lake/river-bank sand 11712 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 81600 nodes² |
| Protected / drift band | 0.6% of land protected (towns, villages, camps/POIs, road corridors); 2.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 2573, 905 | x 2552..2616, z 820..996 | 3664 | L31-33 |
| B2 | 2646, 608 | x 2612..2664, z 568..652 | 1696 | L35-36 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 11.3%, L32 11.7%, L33 12.2%, L34 11.2%, L35 11.4%, L36 10.2%, L37 8.3%, L38 8.8%, L39 7.4%, L40 7.6%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_048 | outpost | Thunderstep Watch | 1900 | 156 | 550 | 36 | poi x 1892..1907, z 542..557 |
| anchor_060 | bandit hideout | Rainchar Camp | 1776 | 161 | 454 | 38 | camp x 1768..1783, z 446..461 |

## Protected areas

- poi Thunderstep Watch (anchor_048): x 1892..1907, z 542..557
- camp Rainchar Camp (anchor_060): x 1768..1783, z 446..461
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Thunderstep Watch (`r20_anchor_048`, anchor_048) at 1900, 156, 550

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Rumela Stormstep | 1902, 157, 550 | r20_anchor_048_01, r20_anchor_048_02, r20_anchor_048_03 |

Distances: zone edge N 496 (kragmar_kezamba), S 236 (front_skyglass_canopy), E 708 (coastal_shelf), W 908 (kragmar_bannerbreak_mesa); nearest other-zone land 231 S; sea 686 E; sea-beach sand 712 E; nearest road 14.
Nearest hubs (straight / by road): Glassroot Gate 1116 / no road; Last Hedge Redoubt 1887 / no road; Cinderline Watch 2650 / no road; Red Ramp Post 2297 / 4052; Tornstandard Hold 1626 / 4723.

### Current quests (3, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_048_01 | A Gutter Before the Rain | Rumela Stormstep (Thunderstep Watch) | 31 | bring 8 default:cobble | 1220 | - |
| r20_anchor_048_02 | Rainchar's Burning Cargo | Rumela Stormstep (Thunderstep Watch) | 31 | kill 4 bandit [in kragmar_thunderroot_wilds] | 1220 | - |
| r20_anchor_048_03 | Across the Glass Passage | Rumela Stormstep (Thunderstep Watch) | 40 | kill 3 guard_accord [in elandor_glassroot_wilds] | 1975 | r20_anchor_048_02 |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bog_witch | Bog Witch | aggressive | - | 87.0% of land, L31-40 | dirt_with_rainforest_litter, dirt_with_bone_litter, dirt_with_canopy_litter, mud |
| jungle_ape | Jungle Ape | aggressive | 65.5% of land, L31-40 | - | dirt_with_rainforest_litter, dirt_with_canopy_litter |
| jungle_spider | Jungle Spider | aggressive | - | 65.6% of land, L31-40 | dirt_with_rainforest_litter, dirt_with_canopy_litter, dirt_with_forest_litter, dirt_with_silver_litter |
| panther | Panther | aggressive | - | 65.5% of land, L31-40 | dirt_with_rainforest_litter, dirt_with_canopy_litter |
| serpent | Serpent | aggressive | 87.0% of land, L31-40 | - | dirt_with_rainforest_litter, dirt_with_canopy_litter, mud |
| shore_crab | Shore Crab | neutral | 5440 nodes², L31-39 | 5440 nodes², L31-39 | sand (dry, within 6 nodes of water) |

**Camps and guard posts:**

- anchor_048 Thunderstep Watch at 1900, 550: guard post, guard_throng × 2-3, respawn 180-360 s, level there L36.
- anchor_060 Rainchar Camp at 1776, 454: bandit, bandit/bandit_archer × 3-5, respawn 120-300 s, level there L38.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 28 | secondary | anchor_048 (Thunderstep Watch, kragmar_thunderroot_wilds) | anchor_012 (Kezamba, kragmar_kezamba) | 733 / 506 | 1909,561 → 1954,1050 |
| 60 | trail | anchor_060 (Rainchar Camp, kragmar_thunderroot_wilds) | joins road 28 | 569 / 562 | 1786,450 → 1929,610 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

