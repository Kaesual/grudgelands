# Glassroot Wilds (`elandor_glassroot_wilds`)

Zone 16 · contested 31-40 · contested · race region **elf** · levels **31-40** · contested · relief `highland` · seed 42

Map: [maps/elandor_glassroot_wilds.png](maps/elandor_glassroot_wilds.png). Machine-readable: [elandor_glassroot_wilds.json](elandor_glassroot_wilds.json). Coordinates are world nodes (x east, z north, y up).

Race track (elf): step 6 of the track Silverleaf Glades → Starbough Vale → Lethariel → Lorindor → Moonfall Wood → Glassroot Wilds.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 756..2616, z -1192..-312 (centroid 1631, -735) |
| Land area | 1112400 nodes² (≈ 1.11 km²) |
| Hub point (authored) | 1800, -700 |
| Height above sea | min 0, p10 72, median 140, p90 212, max 313 |
| Slope | 37.6% steep (>1 node/node), 10.8% cliff (>2) |
| Biomes (measured) | deep_forest 43.1%, jungle_fringe 38.2%, swamp 9.7%, elf_forest 8.5%, badlands 0.2%, meadows 0.2%, savanna 0.0% |
| Neighbours (land border) | elandor_ashenward_march (908 nodes, mid 839,-758), elandor_lethariel (780 nodes, mid 1612,-1066), elandor_lorindor (760 nodes, mid 1032,-1155), elandor_moonfall_wood (816 nodes, mid 2210,-989), front_shattered_line (604 nodes, mid 1178,-370), front_skyglass_canopy (1288 nodes, mid 1939,-334) |
| Sea coast | 1080 nodes of coastline; sea-beach sand 3728 nodes²; lake/river-bank sand 4000 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 86736 nodes² |
| Protected / drift band | 0.5% of land protected (towns, villages, camps/POIs, road corridors); 2.0% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 2491, -941 | x 2468..2528, z -1012..-868 | 2288 | L32-33 |
| B2 | 2512, -577 | x 2492..2548, z -624..-528 | 1280 | L36-38 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 8.3%, L32 9.9%, L33 12.9%, L34 13.6%, L35 12.9%, L36 11.5%, L37 8.5%, L38 7.4%, L39 6.5%, L40 8.6%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_036 | outpost | Glassroot Gate | 1932 | 155 | -686 | 36 | poi x 1924..1939, z -694..-679 |
| anchor_054 | bandit hideout | Rootsnare Camp | 1776 | 186 | -526 | 38 | camp x 1768..1783, z -534..-519 |

## Protected areas

- poi Glassroot Gate (anchor_036): x 1924..1939, z -694..-679
- camp Rootsnare Camp (anchor_054): x 1768..1783, z -534..-519
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Glassroot Gate (`r20_anchor_036`, anchor_036) at 1932, 155, -686

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Faeris Rootbinder | 1934, 156, -686 | glassroot_bounty_spiders, glassroot_canopy_01, glassroot_canopy_02, glassroot_canopy_03, glassroot_canopy_04, glassroot_canopy_05, glassroot_fringe_01, glassroot_fringe_02, glassroot_road_ashenward, glassroot_road_front |

Distances: zone edge N 348 (front_skyglass_canopy), S 328 (elandor_moonfall_wood), E 652 (coastal_shelf), W 1064 (elandor_ashenward_march); nearest other-zone land 258 S; sea 589 E; sea-beach sand 571 E; nearest road 12.
Nearest hubs (straight / by road): Cinderline Watch 2288 / 3841; Last Hedge Redoubt 1636 / 4361; Tornstandard Hold 2093 / 5661; Red Ramp Post 2784 / 6745; Archshadow Post 3434 / 6999.

### Current quests (10, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| glassroot_fringe_01 | Room for the Living | Faeris Rootbinder (Glassroot Gate) | 30 | kill 5 briarpack_wolf [in elandor_glassroot_wilds/fringe] | 540 | - |
| glassroot_fringe_02 | A Warning Without Words | Faeris Rootbinder (Glassroot Gate) | 31 | bring 3 grug_mobs:warpack_fang | 370 | glassroot_fringe_01 |
| glassroot_road_ashenward | Regards, and a Leaking Barrel | Faeris Rootbinder (Glassroot Gate) | 31 | talk to Toren Waterbarrel (r20_anchor_031) | 190 | glassroot_fringe_01 |
| glassroot_canopy_01 | An Unwelcome Rain of Branches | Faeris Rootbinder (Glassroot Gate) | 34 | kill 5 territorial_ape [in elandor_glassroot_wilds/tangle] | 600 | - |
| glassroot_canopy_02 | When the Branches Fall Silent | Faeris Rootbinder (Glassroot Gate) | 35 | kill 5 stalking_panther [in elandor_glassroot_wilds/tangle] | 615 | glassroot_canopy_01 |
| glassroot_canopy_03 | Years Felled for Arrows | Faeris Rootbinder (Glassroot Gate) | 37 | kill 5 entrenched_bandit_archer [in elandor_glassroot_wilds/rootsnare] | 770 | glassroot_canopy_02 |
| glassroot_canopy_04 | No Picnic for Basket-Biter | Faeris Rootbinder (Glassroot Gate) | 37 | kill 1 basket_biter | 880 | glassroot_canopy_03 |
| glassroot_bounty_spiders | Bounty: Leave a Path Unspun (repeatable) | Faeris Rootbinder (Glassroot Gate) | 38 | kill 8 canopy_web_spider [in elandor_glassroot_wilds/canopy] | 440 | glassroot_canopy_03 |
| glassroot_canopy_05 | Group: No More Broken Bows | Faeris Rootbinder (Glassroot Gate) | 38 | kill 1 canopy_knuckle | 1320 | glassroot_canopy_04 |
| glassroot_road_front | What We Keep Behind Us | Faeris Rootbinder (Glassroot Gate) | 38 | talk to Nella Hedgeward (r20_anchor_032) | 225 | glassroot_canopy_04 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| battle_wisp | Battle Wisp | aggressive | - | 0.8% of land, L38-40 |  |
| breakwater_crab | Breakwater Crab | aggressive | 0.3% of land, L38-40 | - |  |
| briarpack_wolf | Briarpack Wolf | aggressive | 30.0% of land, L31-33 | 30.0% of land, L31-33 |  |
| canopy_web_spider | Canopy-Web Jungle Spider | aggressive | - | 57.2% of land, L34-40 |  |
| coiled_serpent | Coiled Serpent | aggressive | 30.4% of land, L34-40 | 4.0% of land, L34-40 |  |
| entrenched_bandit | Entrenched Bandit | aggressive | - | 30.0% of land, L31-33 |  |
| entrenched_bandit_archer | Entrenched Bandit Archer | aggressive | 0.8% of land, L38-40 | 0.8% of land, L38-40 |  |
| marching_zombie | Marching Zombie | aggressive | - | 7.2% of land, L34-35 |  |
| shore_crab | Shore Crab | neutral | 3728 nodes², L32-38 | 3728 nodes², L32-38 | sand (dry, within 6 nodes of water) |
| stalking_panther | Shade Panther | aggressive | - | 57.2% of land, L34-40 |  |
| territorial_ape | Treetop Jungle Ape | aggressive | 64.9% of land, L34-40 | - |  |
| territorial_bear | Bramble Bear | aggressive | 38.5% of land, L34-37 | - |  |
| unrelenting_zombie | Trench Shambler | aggressive | - | 8.0% of land, L36-40 |  |
| watchful_stag | Greatwood Stag | neutral | 30.0% of land, L31-33 | - |  |

**Camps and guard posts:**

- anchor_036 Glassroot Gate at 1932, -686: guard post, guard_accord × 2-3, respawn 180-360 s, level there L36.
- anchor_054 Rootsnare Camp at 1776, -526: bandit, bandit/bandit_archer × 3-5, respawn 30-60 s, level there L38.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 14 | secondary | anchor_036 (Glassroot Gate, elandor_glassroot_wilds) | anchor_009 (Lethariel, elandor_lethariel) | 766 / 514 | 1935,-698 → 1835,-1005 |
| 55 | trail | anchor_054 (Rootsnare Camp, elandor_glassroot_wilds) | joins road 14 | 273 / 270 | 1767,-537 → 1889,-735 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

