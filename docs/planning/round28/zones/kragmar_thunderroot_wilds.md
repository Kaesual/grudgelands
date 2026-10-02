# Thunderroot Wilds (`kragmar_thunderroot_wilds`)

Zone 32 · contested 31-40 · contested · race region **troll** · levels **31-40** · contested · relief `highland` · seed 42

Map: [maps/kragmar_thunderroot_wilds.png](maps/kragmar_thunderroot_wilds.png). Machine-readable: [kragmar_thunderroot_wilds.json](kragmar_thunderroot_wilds.json). Coordinates are world nodes (x east, z north, y up).

Race track (troll): step 6 of the track Kapok Cradle → Raincall Basin → Kezamba → Whispering Reedlands → Totemwater Reach → Thunderroot Wilds.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 908..2676, z 332..1096 (centroid 1754, 726) |
| Land area | 996656 nodes² (≈ 1.00 km²) |
| Hub point (authored) | 1800, 700 |
| Height above sea | min 0, p10 63, median 131, p90 213, max 386 |
| Slope | 26.9% steep (>1 node/node), 5.1% cliff (>2) |
| Biomes (measured) | deep_jungle 61.7%, swamp 24.0%, badlands_east 12.7%, jungle_fringe 0.7%, jungle_edge 0.6%, badlands 0.3%, savanna 0.1% |
| Neighbours (land border) | front_shattered_line (376 nodes, mid 1189,351), front_skyglass_canopy (1320 nodes, mid 2058,417), kragmar_bannerbreak_mesa (732 nodes, mid 972,646), kragmar_kezamba (852 nodes, mid 1736,1037), kragmar_totemwater_reach (568 nodes, mid 2319,1046), kragmar_whispering_reedlands (744 nodes, mid 1141,1032) |
| Sea coast | 884 nodes of coastline; sea-beach sand 5392 nodes²; lake/river-bank sand 5568 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 56704 nodes² |
| Protected / drift band | 0.7% of land protected (towns, villages, camps/POIs, road corridors); 3.2% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 2573, 905 | x 2552..2616, z 820..996 | 3664 | L31-34 |
| B2 | 2647, 608 | x 2612..2664, z 568..652 | 1648 | L36-38 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 10.9%, L32 11.3%, L33 11.3%, L34 11.7%, L35 10.7%, L36 10.4%, L37 7.5%, L38 7.6%, L39 8.3%, L40 10.3%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_048 | outpost | Thunderstep Watch | 1900 | 163 | 670 | 36 | poi x 1892..1907, z 662..677 |
| anchor_060 | bandit hideout | Rainchar Camp | 1776 | 247 | 574 | 37 | camp x 1768..1783, z 566..581 |

## Protected areas

- poi Thunderstep Watch (anchor_048): x 1892..1907, z 662..677
- camp Rainchar Camp (anchor_060): x 1768..1783, z 566..581
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Thunderstep Watch (`r20_anchor_048`, anchor_048) at 1900, 163, 670

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Rumela Stormstep | 1902, 164, 670 | r20_anchor_048_01, r20_anchor_048_02, r20_anchor_048_03 |

Distances: zone edge N 376 (kragmar_kezamba), S 268 (front_skyglass_canopy), E 768 (coastal_shelf), W 940 (kragmar_bannerbreak_mesa); nearest other-zone land 260 S; sea 704 E; sea-beach sand 680 E; nearest road 13.
Nearest hubs (straight / by road): Red Ramp Post 2283 / 3936; Tornstandard Hold 1626 / 4369; Hollowarch Station 3370 / 5327; Last Hedge Redoubt 2024 / 5601; Ashveil Watch 3921 / 6312.

### Current quests (3, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_048_01 | A Gutter Before the Rain | Rumela Stormstep (Thunderstep Watch) | 31 | bring 8 default:cobble | 1220 | - |
| r20_anchor_048_02 | Rainchar's Burning Cargo | Rumela Stormstep (Thunderstep Watch) | 31 | kill 4 bandit or entrenched_bandit [in kragmar_thunderroot_wilds] | 1220 | - |
| r20_anchor_048_03 | Across the Glass Passage | Rumela Stormstep (Thunderstep Watch) | 40 | kill 3 guard_accord [in elandor_glassroot_wilds] | 1975 | r20_anchor_048_02 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| breakwater_crab | Breakwater Crab | aggressive | 0.3% of land, L34-37 | - |  |
| canopy_web_spider | Canopy-Web Jungle Spider | aggressive | - | 62.0% of land, L31-40 |  |
| coiled_serpent | Coiled Serpent | aggressive | 95.4% of land, L31-40 | 15.5% of land, L31-33 |  |
| entrenched_bandit | Entrenched Bandit | aggressive | - | 4.9% of land, L31-33 |  |
| entrenched_bandit_archer | Entrenched Bandit Archer | aggressive | 1.2% of land, L38-40 | 1.2% of land, L38-40 |  |
| marching_zombie | Marching Zombie | aggressive | - | 6.9% of land, L31-35 |  |
| reed_hex_witch | Reed-Hex Bog Witch | aggressive | - | 24.9% of land, L31-37 |  |
| shore_crab | Shore Crab | neutral | 5392 nodes², L31-38 | 5392 nodes², L31-38 | sand (dry, within 6 nodes of water) |
| stalking_panther | Shade Panther | aggressive | - | 66.9% of land, L31-40 |  |
| territorial_ape | Treetop Jungle Ape | aggressive | 68.6% of land, L31-40 | - |  |
| unrelenting_zombie | Trench Shambler | aggressive | - | 3.9% of land, L36-40 |  |

**Camps and guard posts:**

- anchor_048 Thunderstep Watch at 1900, 670: guard post, guard_throng × 2-3, respawn 180-360 s, level there L36.
- anchor_060 Rainchar Camp at 1776, 574: bandit, bandit/bandit_archer × 3-5, respawn 30-60 s, level there L37.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 28 | secondary | anchor_048 (Thunderstep Watch, kragmar_thunderroot_wilds) | anchor_012 (Kezamba, kragmar_kezamba) | 613 / 388 | 1906,682 → 1954,1050 |
| 61 | trail | anchor_060 (Rainchar Camp, kragmar_thunderroot_wilds) | joins road 28 | 891 / 688 | 1782,563 → 1966,832 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

