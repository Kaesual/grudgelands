# Moonfall Wood (`elandor_moonfall_wood`)

Zone 15 · home zone 21-30 · accord · race region **elf** · levels **21-30** · peaceful · relief `lowland` · seed 42

Map: [maps/elandor_moonfall_wood.png](maps/elandor_moonfall_wood.png). Machine-readable: [elandor_moonfall_wood.json](elandor_moonfall_wood.json). Coordinates are world nodes (x east, z north, y up).

Race track (elf): step 5 of the track Silverleaf Glades → Starbough Vale → Lethariel → Lorindor → Moonfall Wood → Glassroot Wilds.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 1924..2720, z -2416..-936 (centroid 2392, -1608) |
| Land area | 551584 nodes² (≈ 0.55 km²) |
| Hub point (authored) | 2400, -1500 |
| Height above sea | min 0, p10 11, median 37, p90 77, max 102 |
| Slope | 3.1% steep (>1 node/node), 0.4% cliff (>2) |
| Biomes (measured) | elf_forest 55.2%, deep_forest 38.0%, swamp 6.5%, jungle_fringe 0.3% |
| Neighbours (land border) | elandor_glassroot_wilds (820 nodes, mid 2207,-984), elandor_lethariel (1384 nodes, mid 2146,-1462), elandor_silverleaf_glades (212 nodes, mid 2504,-2375), elandor_starbough_vale (528 nodes, mid 2309,-2200) |
| Sea coast | 2016 nodes of coastline; sea-beach sand 19744 nodes²; lake/river-bank sand 11680 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 21504 nodes² |
| Protected / drift band | 0.4% of land protected (towns, villages, camps/POIs, road corridors); 1.6% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

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
| quest_host | quest giver | Lethen Moonledger | 2378, 23, -1326 | moonfall_snares_01, moonfall_snares_02, moonfall_snares_03, moonfall_snares_04, moonfall_snares_opt_01, moonfall_snares_opt_02, moonfall_stars_01, moonfall_stars_02, moonfall_stars_03, moonfall_stars_bounty, moonfall_stars_opt_01 |

Distances: zone edge N 316 (elandor_glassroot_wilds), S 968 (elandor_starbough_vale), E 232 (coastal_shelf), W 216 (elandor_lethariel); nearest other-zone land 197 W; sea 216 E; sea-beach sand 144 E; nearest road 13.
Nearest hubs (straight / by road): Lethariel 602 / 1182; Glassroot Gate 779 / 1311; Starbough Village 842 / 1850; Starbough Bandit Camp 1049 / 1926; Paleroot Cutting 1352 / 2037.

### Current quests (11, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| moonfall_stars_01 | The Stars Have No Need to Howl | Lethen Moonledger (Moonfall Observatory) | 21 | kill 5 briarpack_wolf [in elandor_moonfall_wood/eaves] | 338 | - |
| moonfall_snares_01 | The Wrong Kind of Binding | Lethen Moonledger (Moonfall Observatory) | 22 | kill 4 unlicensed_poacher [in elandor_moonfall_wood/eaves] | 280 | - |
| moonfall_snares_02 | A Clear View Needs Sound Wood | Lethen Moonledger (Moonfall Observatory) | 24 | bring 10 group:wood | 150 | moonfall_snares_01 |
| moonfall_stars_02 | A Bear in the Calculation | Lethen Moonledger (Moonfall Observatory) | 24 | kill 5 territorial_bear [in elandor_moonfall_wood/deepwood] | 375 | moonfall_stars_01 |
| moonfall_stars_03 | One Light, Properly Accounted For | Lethen Moonledger (Moonfall Observatory) | 25 | bring 1 grug_mobs:bound_wisp_mote | 233 | moonfall_stars_02 |
| moonfall_stars_bounty | Bounty: Keep the View Clear (repeatable) | Lethen Moonledger (Moonfall Observatory) | 25 | kill 6 briar_web_spider [in elandor_moonfall_wood/deepwood] | 310 | moonfall_stars_03 |
| moonfall_stars_opt_01 | Optional: An Astronomer's Ankles | Lethen Moonledger (Moonfall Observatory) | 25 | kill 5 armored_crab [in elandor_moonfall_wood/moonstrand] | 388 | moonfall_stars_02 |
| moonfall_snares_opt_01 | Optional: Teeth Along the Trail | Lethen Moonledger (Moonfall Observatory) | 27 | kill 6 territorial_bear [in elandor_moonfall_wood/elderwood] | 413 | moonfall_snares_02 |
| moonfall_snares_03 | A Warden in Name Alone | Lethen Moonledger (Moonfall Observatory) | 28 | kill 1 snarewarden_bracken | 680 | moonfall_snares_02 |
| moonfall_snares_opt_02 | Optional: Thread Across the Stars | Lethen Moonledger (Moonfall Observatory) | 28 | kill 6 briar_web_spider [in elandor_moonfall_wood/elderwood] | 425 | moonfall_snares_02 |
| moonfall_snares_04 | Beyond the Last Snare | Lethen Moonledger (Moonfall Observatory) | 29 | talk to Faeris Rootbinder (r20_anchor_036) | 175 | moonfall_snares_03 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| armored_crab | Barnacle Pincher | aggressive | 4.7% of land, L25-30 | - |  |
| bank_crab | Bank Crab | neutral | 2.0% of land, L24 | - |  |
| briar_web_spider | Briar-Web Spider | aggressive | - | 64.5% of land, L24-30 |  |
| briarpack_wolf | Briarpack Wolf | aggressive | 30.0% of land, L21-23 | 30.0% of land, L21-23 |  |
| moss_antler_stag | Moss-Antler Stag | neutral | 95.3% of land, L21-30 | - |  |
| shore_crab | Shore Crab | neutral | 19744 nodes², L21-29 | 19744 nodes², L21-29 | sand (dry, within 6 nodes of water) |
| territorial_bear | Bramble Bear | aggressive | 65.4% of land, L24-30 | - |  |
| unlicensed_poacher | Unlicensed Poacher | aggressive | - | 30.0% of land, L21-23 |  |
| wandering_wisp | Wandering Wisp | aggressive | - | 40.8% of land, L24-27 |  |

**Camps and guard posts:**

- anchor_035 Moonfall Observatory at 2376, -1326: guard post, guard_accord × 2-3, respawn 180-360 s, level there L27.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 40 | trail | anchor_035 (Moonfall Observatory, elandor_moonfall_wood) | joins road 14 | 668 / 308 | 2366,-1334 → 2131,-1276 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

