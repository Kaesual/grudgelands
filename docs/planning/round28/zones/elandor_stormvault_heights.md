# Stormvault Heights (`elandor_stormvault_heights`)

Zone 5 · contested 31-40 · contested · race region **dwarf** · levels **31-40** · contested · relief `highland` · seed 42

Map: [maps/elandor_stormvault_heights.png](maps/elandor_stormvault_heights.png). Machine-readable: [elandor_stormvault_heights.json](elandor_stormvault_heights.json). Coordinates are world nodes (x east, z north, y up).

Race track (dwarf): step 5 of the track Hearthpine Vale → Copperfell Foothills → Dur Brannoc → Frostbarrow Shelf → Stormvault Heights.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2480..-864, z -1172..-212 (centroid -1652, -690) |
| Land area | 1148464 nodes² (≈ 1.15 km²) |
| Hub point (authored) | -1800, -700 |
| Height above sea | min 0, p10 127, median 225, p90 341, max 473 |
| Slope | 63.5% steep (>1 node/node), 26.4% cliff (>2) |
| Biomes (measured) | crags 60.5%, crags_snowy 38.0%, meadows 0.5%, deep_forest 0.4%, pine_hills 0.2%, bone_forest 0.2%, blight 0.1%, beach 0.1%, swamp 0.0% |
| Neighbours (land border) | elandor_ashenward_march (516 nodes, mid -876,-738), elandor_dur_brannoc (848 nodes, mid -1708,-1091), elandor_frostbarrow_shelf (552 nodes, mid -2246,-1043), elandor_whitebridge_shire (756 nodes, mid -1131,-1068), front_broken_causeway (1004 nodes, mid -1159,-321), front_gravesalt_escarpment (624 nodes, mid -2065,-289) |
| Sea coast | 1180 nodes of coastline; sea-beach sand 2064 nodes²; lake/river-bank sand 2416 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 33712 nodes² |
| Protected / drift band | 1.5% of land protected (towns, villages, camps/POIs, road corridors); 6.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -2388, -708 | x -2412..-2364, z -732..-688 | 1008 | L34-35 |
| B2 | -2444, -502 | x -2460..-2420, z -532..-468 | 928 | L37-38 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 11.3%, L32 11.2%, L33 10.8%, L34 11.5%, L35 11.1%, L36 10.7%, L37 8.5%, L38 8.5%, L39 8.0%, L40 8.3%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_027 | outpost | Splitbolt Station | -2074 | 325 | -826 | 33 | poi x -2082..-2067, z -834..-819 |
| anchor_028 | outpost | Archshadow Post | -1500 | 84 | -450 | 38 | poi x -1508..-1493, z -458..-443 |
| anchor_050 | bandit hideout | Slatehook Hideout | -1824 | 205 | -406 | 39 | camp x -1832..-1817, z -414..-399 |
| anchor_093 | rare route | The Bane's Scar | -1874 | 145 | -596 | 36 | poi x -1880..-1869, z -602..-591 |

## Protected areas

- poi Splitbolt Station (anchor_027): x -2082..-2067, z -834..-819
- poi Archshadow Post (anchor_028): x -1508..-1493, z -458..-443
- camp Slatehook Hideout (anchor_050): x -1832..-1817, z -414..-399
- poi The Bane's Scar (anchor_093): x -1880..-1869, z -602..-591
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Splitbolt Station (`r20_anchor_027`, anchor_027) at -2074, 325, -826

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Borin Splitbolt | -2072, 326, -826 | r20_anchor_027_01, r20_anchor_027_02, r20_anchor_027_03 |

Distances: zone edge N 528 (front_gravesalt_escarpment), S 276 (elandor_frostbarrow_shelf), E 1192 (elandor_ashenward_march), W 308 (coastal_shelf); nearest other-zone land 248 S; sea 274 W; sea-beach sand 318 NW; nearest road 13.
Nearest hubs (straight / by road): Hollowarch Station 1398 / no road; Ashveil Watch 1661 / no road; Red Ramp Post 2404 / no road; Tornstandard Hold 2686 / no road; Cinderline Watch 1724 / 4074.

### Archshadow Post (`r20_anchor_028`, anchor_028) at -1500, 84, -450

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Alna Archsight | -1498, 85, -450 | r20_anchor_028_01, r20_anchor_028_02, r20_anchor_028_03 |

Distances: zone edge N 160 (front_gravesalt_escarpment), S 668 (elandor_dur_brannoc), E 548 (front_broken_causeway), W 972 (coastal_shelf); nearest other-zone land 155 N; sea 880 W; sea-beach sand 898 W; nearest road 11.
Nearest hubs (straight / by road): Hollowarch Station 885 / no road; Cinderline Watch 1218 / 1795; Ashveil Watch 1385 / no road; Red Ramp Post 1738 / no road; Last Hedge Redoubt 1800 / 2824.

### Current quests (6, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_027_01 | Shutters Against the Storm | Borin Splitbolt (Splitbolt Station) | 31 | bring 8 default:pine_wood | 1220 | - |
| r20_anchor_027_02 | The Frost That Walks | Borin Splitbolt (Splitbolt Station) | 31 | kill 4 frost_stray [in elandor_stormvault_heights] | 1220 | - |
| r20_anchor_028_01 | Stones for the Sighting Line | Alna Archsight (Archshadow Post) | 31 | bring 8 default:cobble | 1220 | - |
| r20_anchor_028_02 | Wings Over the Crossing | Alna Archsight (Archshadow Post) | 31 | kill 3 crag_eagle [in elandor_stormvault_heights] | 1220 | - |
| r20_anchor_027_03 | Slatehook's Cargo | Borin Splitbolt (Splitbolt Station) | 33 | kill 4 bandit_archer [in elandor_stormvault_heights] | 1300 | r20_anchor_027_02 |
| r20_anchor_028_03 | The Watch Beyond the Ash Wind | Alna Archsight (Archshadow Post) | 40 | kill 3 guard_throng [in kragmar_blackwind_rise] | 1975 | r20_anchor_028_02 |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| crag_eagle | Crag Eagle | aggressive | 98.9% of land, L31-40 | - | gravel, snowblock |
| frost_stray | Frost Stray | aggressive | - | 98.9% of land, L31-40 | gravel, snowblock |
| goblin_hound | Goblin Raider Hound | aggressive | - | 99.0% of land, L31-40 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| goblin_raider | Goblin Raider | aggressive | - | 99.0% of land, L31-40 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| goblin_slinger | Goblin Slinger | aggressive | - | 99.0% of land, L31-40 | dirt_with_coniferous_litter, dry_dirt_with_dry_grass, gravel, snowblock, mesa_clay |
| gull | Gull | critter | 624 nodes² | - | sand |
| ibex | Ibex | neutral | 99.0% of land, L31-40 | - | dirt_with_coniferous_litter, gravel, snowblock |
| mountain_ram | Mountain Ram | neutral | 98.9% of land, L31-40 | - | gravel, snowblock |
| shore_crab | Shore Crab | neutral | 2064 nodes², L34-40 | 2064 nodes², L34-40 | sand (dry, within 6 nodes of water) |
| snow_leopard | Snow Leopard | aggressive | - | 98.9% of land, L31-40 | gravel, snowblock |
| stone_golem | Stone Golem | aggressive | 98.9% of land, L31-40 | 98.9% of land, L31-40 | gravel, snowblock, stone |

In the palette but no host ground in this zone: Hyena, Vulture.

**Camps and guard posts:**

- anchor_027 Splitbolt Station at -2074, -826: guard post, guard_accord × 2-3, respawn 180-360 s, level there L33.
- anchor_028 Archshadow Post at -1500, -450: guard post, guard_accord × 2-3, respawn 180-360 s, level there L38.
- anchor_050 Slatehook Hideout at -1824, -406: bandit, bandit/bandit_archer × 3-5, respawn 120-300 s, level there L39.

**Rares (knowledge rewards, not quest targets):** Korgan's Bane (stone_golem, the high crags, route -1922,-620 → -1858,-556 → -1818,-612, L36, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 12 | secondary | anchor_027 (Splitbolt Station, elandor_stormvault_heights) | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | 1736 / 1328 | -2080,-815 → -1233,-1108 |
| 33 | trail | anchor_028 (Archshadow Post, elandor_stormvault_heights) | joins road 13 | 1729 / 358 | -1497,-439 → -1231,-222 |
| 50 | trail | anchor_050 (Slatehook Hideout, elandor_stormvault_heights) | joins road 12 | 1008 / 996 | -1835,-399 → -1811,-838 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

