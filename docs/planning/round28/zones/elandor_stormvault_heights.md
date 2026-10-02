# Stormvault Heights (`elandor_stormvault_heights`)

Zone 5 · contested 31-40 · contested · race region **dwarf** · levels **31-40** · contested · relief `highland` · seed 42

Map: [maps/elandor_stormvault_heights.png](maps/elandor_stormvault_heights.png). Machine-readable: [elandor_stormvault_heights.json](elandor_stormvault_heights.json). Coordinates are world nodes (x east, z north, y up).

Race track (dwarf): step 5 of the track Hearthpine Vale → Copperfell Foothills → Dur Brannoc → Frostbarrow Shelf → Stormvault Heights.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2480..-872, z -1172..-352 (centroid -1658, -743) |
| Land area | 971040 nodes² (≈ 0.97 km²) |
| Hub point (authored) | -1800, -700 |
| Height above sea | min 0, p10 125, median 228, p90 337, max 473 |
| Slope | 61.9% steep (>1 node/node), 25.8% cliff (>2) |
| Biomes (measured) | crags 57.1%, crags_snowy 41.1%, deep_forest 0.5%, meadows 0.4%, pine_hills 0.3%, bone_forest 0.3%, beach 0.1%, swamp 0.1%, blight 0.1% |
| Neighbours (land border) | elandor_ashenward_march (324 nodes, mid -877,-817), elandor_dur_brannoc (848 nodes, mid -1708,-1091), elandor_frostbarrow_shelf (552 nodes, mid -2246,-1043), elandor_whitebridge_shire (756 nodes, mid -1131,-1068), front_broken_causeway (1068 nodes, mid -1162,-467), front_gravesalt_escarpment (1140 nodes, mid -1994,-383) |
| Sea coast | 1004 nodes of coastline; sea-beach sand 2016 nodes²; lake/river-bank sand 992 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 34192 nodes² |
| Protected / drift band | 1.7% of land protected (towns, villages, camps/POIs, road corridors); 7.9% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -2388, -708 | x -2412..-2364, z -732..-688 | 1008 | L35-36 |
| B2 | -2444, -502 | x -2460..-2420, z -532..-468 | 944 | L38-39 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 11.5%, L32 12.0%, L33 11.0%, L34 11.6%, L35 11.9%, L36 10.8%, L37 7.4%, L38 7.0%, L39 7.0%, L40 9.8%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_027 | outpost | Splitbolt Station | -2074 | 325 | -826 | 34 | poi x -2082..-2067, z -834..-819 |
| anchor_028 | outpost | Archshadow Post | -1500 | 257 | -570 | 38 | poi x -1508..-1493, z -578..-563 |
| anchor_050 | bandit hideout | Slatehook Hideout | -1824 | 287 | -526 | 38 | camp x -1832..-1817, z -534..-519 |
| anchor_093 | rare route | The Bane's Scar | -1874 | 187 | -716 | 35 | poi x -1880..-1869, z -722..-711 |

## Protected areas

- poi Splitbolt Station (anchor_027): x -2082..-2067, z -834..-819
- poi Archshadow Post (anchor_028): x -1508..-1493, z -578..-563
- camp Slatehook Hideout (anchor_050): x -1832..-1817, z -534..-519
- poi The Bane's Scar (anchor_093): x -1880..-1869, z -722..-711
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Splitbolt Station (`r20_anchor_027`, anchor_027) at -2074, 325, -826

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Borin Splitbolt | -2072, 326, -826 | r20_anchor_027_01, r20_anchor_027_02, r20_anchor_027_03 |

Distances: zone edge N 432 (front_gravesalt_escarpment), S 276 (elandor_frostbarrow_shelf), E 1192 (elandor_ashenward_march), W 308 (coastal_shelf); nearest other-zone land 248 S; sea 274 W; sea-beach sand 318 NW; nearest road 13.
Nearest hubs (straight / by road): Archshadow Post 628 / 2195; Cinderline Watch 1724 / 4214; Last Hedge Redoubt 2388 / 5354; Tornstandard Hold 2746 / 6655; Glassroot Gate 4008 / 7209.

### Archshadow Post (`r20_anchor_028`, anchor_028) at -1500, 257, -570

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Alna Archsight | -1498, 258, -570 | r20_anchor_028_01, r20_anchor_028_02, r20_anchor_028_03 |

Distances: zone edge N 160 (front_broken_causeway), S 548 (elandor_dur_brannoc), E 516 (front_broken_causeway), W 900 (coastal_shelf); nearest other-zone land 158 N; sea 868 W; sea-beach sand 873 W; nearest road 13.
Nearest hubs (straight / by road): Splitbolt Station 628 / 2195; Cinderline Watch 1184 / 4005; Last Hedge Redoubt 1800 / 5145; Tornstandard Hold 2123 / 6446; Glassroot Gate 3434 / 6999.

### Current quests (6, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_027_01 | Shutters Against the Storm | Borin Splitbolt (Splitbolt Station) | 31 | bring 8 default:pine_wood | 1220 | - |
| r20_anchor_027_02 | The Frost That Walks | Borin Splitbolt (Splitbolt Station) | 31 | kill 4 frost_stray or rime_skeleton_stray [in elandor_stormvault_heights] | 1220 | - |
| r20_anchor_028_01 | Stones for the Sighting Line | Alna Archsight (Archshadow Post) | 31 | bring 8 default:cobble | 1220 | - |
| r20_anchor_028_02 | Wings Over the Crossing | Alna Archsight (Archshadow Post) | 31 | kill 3 crag_eagle or ridge_crag_eagle [in elandor_stormvault_heights] | 1220 | - |
| r20_anchor_027_03 | Slatehook's Cargo | Borin Splitbolt (Splitbolt Station) | 33 | kill 4 bandit_archer [in elandor_stormvault_heights] | 1300 | r20_anchor_027_02 |
| r20_anchor_028_03 | The Watch Beyond the Ash Wind | Alna Archsight (Archshadow Post) | 40 | kill 3 guard_throng [in kragmar_blackwind_rise] | 1975 | r20_anchor_028_02 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| breakwater_crab | Breakwater Crab | aggressive | 0.6% of land, L34-37 | - |  |
| entrenched_bandit_archer | Entrenched Bandit Archer | aggressive | 1.3% of land, L38-40 | 1.3% of land, L38-40 |  |
| gull | Gull | critter | 1376 nodes² | - | sand |
| marching_zombie | Marching Zombie | aggressive | - | 10.3% of land, L31-35 |  |
| prowling_snow_leopard | Crag Snow Leopard | aggressive | - | 60.4% of land, L34-40 |  |
| ridge_crag_eagle | Ridge Crag Eagle | aggressive | 30.0% of land, L31-33 | - |  |
| ridge_ibex | Ridge Ibex | neutral | 47.9% of land, L31-40 | - |  |
| rime_skeleton_stray | Rime Skeleton Stray | aggressive | - | 30.0% of land, L31-33 |  |
| shore_crab | Shore Crab | neutral | 2016 nodes², L35-39 | 2016 nodes², L35-39 | sand (dry, within 6 nodes of water) |
| siege_goblin | Siege Goblin | aggressive | 0.9% of land, L34-37 | 0.9% of land, L34-37 |  |
| siege_goblin_slinger | Siege Goblin Slinger | aggressive | 0.9% of land, L34-37 | 0.9% of land, L34-37 |  |
| storm_ridge_ram | Storm-Ridge Ram | neutral | 94.2% of land, L31-40 | - |  |
| unrelenting_zombie | Trench Shambler | aggressive | - | 14.0% of land, L36-40 |  |

**Camps and guard posts:**

- anchor_027 Splitbolt Station at -2074, -826: guard post, guard_accord × 2-3, respawn 180-360 s, level there L34.
- anchor_028 Archshadow Post at -1500, -570: guard post, guard_accord × 2-3, respawn 180-360 s, level there L38.
- anchor_050 Slatehook Hideout at -1824, -526: bandit, bandit/bandit_archer × 3-5, respawn 30-60 s, level there L38.

**Rares (knowledge rewards, not quest targets):** Korgan's Bane (stone_golem, the high crags, route -1922,-740 → -1858,-676 → -1818,-732, L35, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 12 | secondary | anchor_027 (Splitbolt Station, elandor_stormvault_heights) | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | 1736 / 1328 | -2080,-815 → -1233,-1108 |
| 34 | trail | anchor_028 (Archshadow Post, elandor_stormvault_heights) | joins road 12 | 983 / 968 | -1490,-578 → -1158,-979 |
| 51 | trail | anchor_050 (Slatehook Hideout, elandor_stormvault_heights) | joins road 12 | 322 / 318 | -1815,-537 → -1926,-771 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

