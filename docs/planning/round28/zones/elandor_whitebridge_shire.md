# Whitebridge Shire (`elandor_whitebridge_shire`)

Zone 9 · home zone 21-30 · accord · race region **human** · levels **21-30** · peaceful · relief `lowland` · seed 42

Map: [maps/elandor_whitebridge_shire.png](maps/elandor_whitebridge_shire.png). Machine-readable: [elandor_whitebridge_shire.json](elandor_whitebridge_shire.json). Coordinates are world nodes (x east, z north, y up).

Race track (human): step 4 of the track Dawnmere Fields → Goldmead Vale → Highcourt → Whitebridge Shire → Ashenward March.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -1388..-480, z -2232..-952 (centroid -893, -1524) |
| Land area | 676896 nodes² (≈ 0.68 km²) |
| Hub point (authored) | -900, -1500 |
| Height above sea | min -2, p10 19, median 42, p90 84, max 236 |
| Slope | 5.3% steep (>1 node/node), 0.2% cliff (>2) |
| Biomes (measured) | deep_forest 46.8%, meadows 42.1%, swamp 9.9%, crags 0.5%, pine_hills 0.5%, crags_snowy 0.3% |
| Neighbours (land border) | elandor_ashenward_march (676 nodes, mid -684,-1105), elandor_copperfell_foothills (252 nodes, mid -1173,-1921), elandor_dur_brannoc (920 nodes, mid -1275,-1502), elandor_goldmead_vale (592 nodes, mid -662,-2036), elandor_highcourt (732 nodes, mid -497,-1554), elandor_stormvault_heights (760 nodes, mid -1133,-1063) |
| Sea coast | 656 nodes of coastline; sea-beach sand 9424 nodes²; lake/river-bank sand 12176 nodes² |
| Water inside | bay 99648 nodes², rivers/lakes 33568 nodes² |
| Protected / drift band | 1.9% of land protected (towns, villages, camps/POIs, road corridors); 6.1% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -940, -1981 | x -988..-892, z -2032..-1916 | 3808 | L21-22 |
| B2 | -800, -2140 | x -852..-760, z -2168..-2112 | 2720 | L21 |
| B3 | -769, -2191 | x -792..-736, z -2232..-2148 | 1472 | L21 |
| B4 | -1017, -1892 | x -1040..-992, z -1916..-1876 | 512 | L22 |
| B5 | -968, -1862 | x -976..-960, z -1868..-1856 | 192 | L22 |
| B6 | -854, -2082 | x -860..-848, z -2092..-2076 | 160 | L21 |
| B7 | -938, -1894 | x -944..-936, z -1908..-1880 | 160 | L22 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L21 6.4%, L22 8.5%, L23 11.3%, L24 11.7%, L25 12.2%, L26 12.2%, L27 9.1%, L28 10.5%, L29 9.7%, L30 8.4%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_016 | village | Whitebridge Market Close | -924 | 29 | -1556 | 25 | village x -936..-913, z -1568..-1545 |
| anchor_030 | outpost | Oakspan Tollhouse | -618 | 46 | -1266 | 28 | poi x -626..-611, z -1274..-1259 |
| anchor_062 | mine | Bridgechalk Dig | -1074 | 28 | -1256 | 28 | poi x -1084..-1065, z -1266..-1247 |
| anchor_067 | mirefolk camp | Siltbasket Camp | -620 | 65 | -1760 | 23 | camp x -628..-613, z -1768..-1753 |

## Protected areas

- village Whitebridge Market Close (anchor_016): x -936..-913, z -1568..-1545
- poi Oakspan Tollhouse (anchor_030): x -626..-611, z -1274..-1259
- poi Bridgechalk Dig (anchor_062): x -1084..-1065, z -1266..-1247
- camp Siltbasket Camp (anchor_067): x -628..-613, z -1768..-1753
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Whitebridge Market Close (`r20_anchor_016`, anchor_016) at -924, 29, -1556

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Merren Oakstamp | -922, 30, -1556 | r20_anchor_016_01, r20_anchor_016_02, r20_anchor_016_03, r20_human_journey_02 |

Distances: zone edge N 564 (elandor_stormvault_heights), S 460 (bay_water), E 444 (elandor_highcourt), W 304 (elandor_dur_brannoc); nearest other-zone land 304 W; sea 365 S; sea-beach sand 302 S; nearest road 18.
Nearest hubs (straight / by road): Bridgechalk Dig 335 / 413; Oakspan Tollhouse 422 / 584; Cinderline Watch 910 / 1114; Dur Brannoc 878 / 1407; Highcourt 926 / 1464.

### Oakspan Tollhouse (`r20_anchor_030`, anchor_030) at -618, 46, -1266

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Jessa Axlewright | -616, 47, -1266 | r20_anchor_030_01, r20_anchor_030_02, r20_anchor_030_03 |

Distances: zone edge N 128 (elandor_ashenward_march), S 676 (elandor_goldmead_vale), E 128 (elandor_highcourt), W 732 (elandor_dur_brannoc); nearest other-zone land 91 NE; sea 753 SW; sea-beach sand 682 SW; nearest road 13.
Nearest hubs (straight / by road): Whitebridge Market Close 422 / 584; Cinderline Watch 495 / 598; Bridgechalk Dig 456 / 688; Highcourt 661 / 948; Last Hedge Redoubt 1228 / 1407.

### Bridgechalk Dig (`r20_anchor_062`, anchor_062) at -1074, 28, -1256

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Halen Chalkthumb | -1072, 29, -1256 | r20_anchor_062_01, r20_anchor_062_02, r20_anchor_062_03, r20_human_journey_03 |

Distances: zone edge N 196 (elandor_stormvault_heights), S 692 (coastal_shelf), E 592 (elandor_highcourt), W 276 (elandor_dur_brannoc); nearest other-zone land 195 N; sea 660 S; sea-beach sand 609 S; nearest road 13.
Nearest hubs (straight / by road): Whitebridge Market Close 335 / 413; Oakspan Tollhouse 456 / 688; Cinderline Watch 830 / 1219; Dur Brannoc 766 / 1326; Highcourt 1101 / 1569.

### Current quests (11, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_016_01 | The Press Frame | Merren Oakstamp (Whitebridge Market Close) | 21 | bring 8 default:wood | 820 | - |
| r20_anchor_016_02 | The Poacher's Market | Merren Oakstamp (Whitebridge Market Close) | 21 | kill 4 poacher [in elandor_whitebridge_shire] | 820 | - |
| r20_anchor_030_01 | An Axle for the Empty Cart | Jessa Axlewright (Oakspan Tollhouse) | 21 | bring 8 default:wood | 820 | - |
| r20_anchor_030_02 | The Tollhouse Snares | Jessa Axlewright (Oakspan Tollhouse) | 21 | kill 4 poacher [in elandor_whitebridge_shire] | 820 | - |
| r20_anchor_062_01 | Braces for the Pale Face | Halen Chalkthumb (Bridgechalk Dig) | 21 | bring 10 default:wood | 820 | - |
| r20_anchor_062_02 | The Surveyor's Snare | Halen Chalkthumb (Bridgechalk Dig) | 21 | kill 4 poacher [in elandor_whitebridge_shire] | 820 | - |
| r20_anchor_016_03 | A Light Beyond the Bridge | Merren Oakstamp (Whitebridge Market Close) | 23 | kill 3 wisp [in elandor_whitebridge_shire] | 900 | r20_anchor_016_02 |
| r20_anchor_030_03 | Night Lights at Oakspan | Jessa Axlewright (Oakspan Tollhouse) | 23 | kill 3 wisp [in elandor_whitebridge_shire] | 900 | r20_anchor_030_02 |
| r20_anchor_062_03 | A Quarry Hand's Pick | Halen Chalkthumb (Bridgechalk Dig) | 23 | bring 1 grug_materials:pick_stone | 900 | r20_anchor_062_02 |
| r20_human_journey_02 | Word for Halen Chalkthumb | Merren Oakstamp (Whitebridge Market Close) | 24 | talk to Halen Chalkthumb (r20_anchor_062) | 705 | - |
| r20_human_journey_03 | Word for Toren Waterbarrel | Halen Chalkthumb (Bridgechalk Dig) | 31 | talk to Toren Waterbarrel (r20_anchor_031) | 915 | - |

## Current mob palette (before Round 28)

Where each species may spawn on dry land today: the engine spawn policy sampled every 24 nodes, kept only on biomes whose top node is one of the species' host nodes (crabs: measured on sea-beach sand). Share = of the zone's dry land (not a density); levels = the level field there.

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bear | Bear | aggressive | 89.5% of land, L21-30 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| boar | Boar | neutral | 100.0% of land, L21-30 | - | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |
| giant_spider | Giant Spider | aggressive | - | 89.5% of land, L21-30 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| poacher | Poacher | aggressive | - | 89.1% of land, L21-30 | dirt_with_grass, dirt_with_forest_litter, dirt_with_silver_litter |
| rabbit | Rabbit | critter | 100.0% of land, L21-30 | - | dirt_with_coniferous_litter, dirt_with_grass, gravel, sand, snowblock, dirt_with_forest_litter … |
| shore_crab | Shore Crab | neutral | 9424 nodes², L21-22 | 9424 nodes², L21-22 | sand (dry, within 6 nodes of water) |
| stag | Stag | neutral | 89.1% of land, L21-30 | - | dirt_with_grass, dirt_with_forest_litter |
| wisp | Wisp | aggressive | - | 57.1% of land, L21-30 | dirt_with_rainforest_litter, dirt_with_bone_litter, dirt_with_canopy_litter, dirt_with_forest_litter, dirt_with_silver_litter, mud |
| wolf | Wolf | aggressive | 89.5% of land, L21-30 | 89.5% of land, L21-30 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_forest_litter |
| zombie | Zombie | aggressive | - | 100.0% of land, L21-30 | dirt_with_coniferous_litter, dirt_with_grass, dirt_with_rainforest_litter, dry_dirt_with_dry_grass, gravel, sand … |

In the palette but no host ground in this zone: Blightfang Wolf, Bone Weevil, Bonelurker Spider, Gaunt Stag, Plaguehide Bear, Skeleton Archer.

**Camps and guard posts:**

- anchor_030 Oakspan Tollhouse at -618, -1266: guard post, guard_accord × 2-3, respawn 180-360 s, level there L28.
- anchor_067 Siltbasket Camp at -620, -1760: mirefolk camp, EMPTY today: no camp fire is placed (anchor roster lists only capital, outpost and bandit populations) (level there L23).

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 1 | primary | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | anchor_008 (Highcourt, elandor_highcourt) | 1434 / 812 | -1233,-1524 → -527,-1218 |
| 10 | secondary | anchor_016 (Whitebridge Market Close, elandor_whitebridge_shire) | joins road 1 | 139 / 140 | -934,-1541 → -961,-1419 |
| 12 | secondary | anchor_027 (Splitbolt Station, elandor_stormvault_heights) | anchor_007 (Dur Brannoc, elandor_dur_brannoc) | 1736 / 180 | -1234,-1110 → -1368,-1212 |
| 35 | trail | anchor_030 (Oakspan Tollhouse, elandor_whitebridge_shire) | joins road 1 | 23 / 26 | -626,-1256 → -640,-1237 |
| 62 | trail | anchor_062 (Bridgechalk Dig, elandor_whitebridge_shire) | joins road 1 | 154 / 154 | -1076,-1269 → -1052,-1416 |
| 67 | trail | anchor_067 (Siltbasket Camp, elandor_whitebridge_shire) | joins road 7 | 500 / 74 | -609,-1769 → -548,-1807 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

