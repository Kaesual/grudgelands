# Moonfall Wood (`elandor_moonfall_wood`)

Zone 15 · home zone 21-30 · accord · race region **elf** · levels **21-30** · peaceful · relief `lowland` · seed 42

Map: [maps/elandor_moonfall_wood.png](maps/elandor_moonfall_wood.png). Machine-readable: [elandor_moonfall_wood.json](elandor_moonfall_wood.json). Coordinates are world nodes (x east, z north, y up).

Race track (elf): step 5 of the track Silverleaf Glades → Starbough Vale → Lethariel → Lorindor → Moonfall Wood → Glassroot Wilds.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 1924..2720, z -2416..-936 (centroid 2392, -1608) |
| Land area | 551568 nodes² (≈ 0.55 km²) |
| Hub point (authored) | 2400, -1500 |
| Height above sea | min 0, p10 11, median 37, p90 77, max 102 |
| Slope | 3.1% steep (>1 node/node), 0.4% cliff (>2) |
| Biomes (measured) | elf_forest 55.2%, deep_forest 38.0%, swamp 6.5%, jungle_fringe 0.3% |
| Neighbours (land border) | elandor_glassroot_wilds (820 nodes, mid 2207,-984), elandor_lethariel (1384 nodes, mid 2146,-1462), elandor_silverleaf_glades (212 nodes, mid 2504,-2375), elandor_starbough_vale (528 nodes, mid 2309,-2200) |
| Sea coast | 2016 nodes of coastline; sea-beach sand 19728 nodes²; lake/river-bank sand 11792 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 21520 nodes² |
| Protected / drift band | 0.3% of land protected (towns, villages, camps/POIs, road corridors); 1.6% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 2570, -1230 | x 2544..2612, z -1316..-1140 | 4592 | L28-29 |
| B2 | 2671, -1592 | x 2624..2700, z -1696..-1504 | 4448 | L25-26 |
| B3 | 2555, -2351 | x 2528..2580, z -2416..-2284 | 3632 | L21 |
| B4 | 2561, -2150 | x 2528..2592, z -2232..-2092 | 3360 | L21-22 |
| B5 | 2664, -1969 | x 2604..2704, z -2040..-1920 | 2304 | L22-23 |
| B6 | 2597, -1713 | x 2588..2604, z -1716..-1708 | 176 | L24-25 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L21 8.7%, L22 9.4%, L23 12.6%, L24 12.1%, L25 11.0%, L26 9.5%, L27 7.5%, L28 8.3%, L29 9.6%, L30 11.2%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_035 | outpost | Moonfall Observatory | 2376 | 22 | -1326 | 27 | poi x 2368..2383, z -1334..-1319 |

## Protected areas

- poi Moonfall Observatory (anchor_035): x 2368..2383, z -1334..-1319
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Moonfall Observatory (`r20_anchor_035`, anchor_035) at 2376, 22, -1326

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Lethen Moonledger | 2378, 23, -1326 | r20_anchor_035_01, r20_anchor_035_02, r20_anchor_035_03 |

Distances: zone edge N 316 (elandor_glassroot_wilds), S 968 (elandor_starbough_vale), E 232 (coastal_shelf), W 216 (elandor_lethariel); nearest other-zone land 197 W; sea 216 E; sea-beach sand 144 E; nearest road 13.
Nearest hubs (straight / by road): Lethariel 602 / 1180; Glassroot Gate 880 / 1442; Starbough Village 842 / 1848; Starbough Bandit Camp 1049 / 1925; Paleroot Cutting 1352 / 2035.

### Current quests (3, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_035_01 | A Chart Table Repaired | Lethen Moonledger (Moonfall Observatory) | 21 | bring 8 default:wood | 820 | - |
| r20_anchor_035_02 | Fangs Beneath the Fallen Bough | Lethen Moonledger (Moonfall Observatory) | 21 | kill 4 wolf [in elandor_moonfall_wood] | 820 | - |
| r20_anchor_035_03 | The Moonlit Snare Line | Lethen Moonledger (Moonfall Observatory) | 23 | kill 4 poacher [in elandor_moonfall_wood] | 900 | r20_anchor_035_02 |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bear | Bear | aggressive | 92.6% of land, L21-30 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| giant_spider | Giant Spider | aggressive | - | 92.6% of land, L21-30 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| poacher | Poacher | aggressive | - | 92.6% of land, L21-30 | dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| shore_crab | Shore Crab | neutral | 19728 nodes², L21-29 | 19728 nodes², L21-29 | sand (dry, within 6 nodes of water) |
| stag | Stag | neutral | 37.5% of land, L21-30 | - | dirt_with_grass, dirt_with_forest_litter |
| wisp | Wisp | aggressive | - | 100.0% of land, L21-30 | dirt_with_rainforest_litter, dirt_with_bone_litter, dirt_with_canopy_litter, dirt_with_forest_litter, dirt_with_silver_litter, mud |
| wolf | Wolf | aggressive | 37.5% of land, L21-30 | 37.5% of land, L21-30 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter |

In the palette but no host ground in this zone: Blightfang Wolf, Bone Weevil, Bonelurker Spider, Gaunt Stag, Plaguehide Bear, Skeleton Archer.

**Camps and guard posts:**

- anchor_035 Moonfall Observatory at 2376, -1326: guard post, guard_accord × 2-3, respawn 180-360 s, level there L27.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 39 | trail | anchor_035 (Moonfall Observatory, elandor_moonfall_wood) | joins road 14 | 667 / 308 | 2366,-1334 → 2131,-1276 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

