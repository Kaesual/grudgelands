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
| quest_host | quest giver | Toren Waterbarrel | -348, 54, -850 | ashenward_bounty_raiders, ashenward_rations_01, ashenward_rations_02, ashenward_rations_03, ashenward_road_glassroot, ashenward_road_last_hedge, ashenward_road_stormvault, cinderline_front_01, cinderline_front_02, cinderline_front_03, cinderline_front_04, cinderline_front_05 |

Distances: zone edge N 504 (front_broken_causeway), S 332 (elandor_highcourt), E 1156 (elandor_glassroot_wilds), W 544 (elandor_stormvault_heights); nearest other-zone land 291 S; sea 1247 SW; sea-beach sand 1177 SW; nearest road 11.
Nearest hubs (straight / by road): Last Hedge Redoubt 708 / 1987; Tornstandard Hold 1574 / 3287; Glassroot Gate 2288 / 3841; Archshadow Post 1184 / 4005; Splitbolt Station 1724 / 4214.

### Last Hedge Redoubt (`r20_anchor_032`, anchor_032) at 300, 71, -570

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Nella Hedgeward | 302, 72, -570 | ashenward_bounty_shamblers, ashenward_hedge_01, ashenward_hedge_02, ashenward_hedge_03, ashenward_hedge_04, ashenward_hedge_webs, lasthedge_front_01, lasthedge_front_02, lasthedge_front_03, lasthedge_front_04, lasthedge_front_05, lasthedge_front_06, lasthedge_front_07, lasthedge_front_bounty |

Distances: zone edge N 192 (front_shattered_line), S 620 (elandor_highcourt), E 588 (elandor_glassroot_wilds), W 996 (front_broken_causeway); nearest other-zone land 190 N; sea 1302 SE; sea-beach sand 1310 S; nearest road 14.
Nearest hubs (straight / by road): Tornstandard Hold 1164 / 1851; Cinderline Watch 708 / 1987; Red Ramp Post 1594 / 2935; Hollowarch Station 2095 / 4326; Glassroot Gate 1636 / 4361.

### Current quests (26, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| ashenward_rations_01 | Three Crates Out, Two Crates In | Toren Waterbarrel (Cinderline Watch) | 30 | kill 5 entrenched_bandit [in elandor_ashenward_march/ration_camp] | 540 | - |
| ashenward_rations_02 | The Trees Can Pay for That | Toren Waterbarrel (Cinderline Watch) | 31 | kill 5 rootbound_treant [in elandor_ashenward_march/cinderwood]; bring 2 grug_mobs:bitter_resin | 555 | ashenward_rations_01 |
| ashenward_bounty_raiders | Bounty: No Rations for the Dead (repeatable) | Toren Waterbarrel (Cinderline Watch) | 32 | kill 6 march_skeleton_raider [in elandor_ashenward_march/ashfields] | 370 | ashenward_rations_01 |
| ashenward_rations_03 | The Account of Quartermaster Scrip | Toren Waterbarrel (Cinderline Watch) | 32 | kill 1 quartermaster_scrip | 760 | ashenward_rations_02 |
| ashenward_road_glassroot | An Answer for Faeris | Toren Waterbarrel (Cinderline Watch) | 32 | talk to Faeris Rootbinder (r20_anchor_036) | 190 | ashenward_rations_03 |
| ashenward_road_stormvault | Bread for the Mountain Watch | Toren Waterbarrel (Cinderline Watch) | 32 | talk to Borin Splitbolt (r20_anchor_027) | 190 | ashenward_rations_03 |
| ashenward_hedge_01 | Honey Is Not Worth a Driver | Nella Hedgeward (Last Hedge Redoubt) | 34 | kill 4 territorial_bear [in elandor_ashenward_march/hedgewood] | 500 | - |
| ashenward_road_last_hedge | One More Pair of Hands | Toren Waterbarrel (Cinderline Watch) | 34 | talk to Nella Hedgeward (r20_anchor_032) | 195 | ashenward_rations_03 |
| ashenward_hedge_webs | Webs Across the Wagon Road | Nella Hedgeward (Last Hedge Redoubt) | 35 | kill 4 briar_web_spider [in elandor_ashenward_march/hedgewood] | 513 | ashenward_hedge_01 |
| ashenward_hedge_02 | A Uniform Is Not a Target | Nella Hedgeward (Last Hedge Redoubt) | 37 | kill 5 entrenched_bandit_archer [in elandor_ashenward_march/coalbrand_yard] | 770 | ashenward_hedge_webs |
| ashenward_hedge_03 | The Price of an Empty Pot | Nella Hedgeward (Last Hedge Redoubt) | 37 | kill 5 wartrail_poacher [in elandor_ashenward_march/poacher_camp] | 770 | ashenward_hedge_02 |
| ashenward_bounty_shamblers | Bounty: Let the Watch Come Home (repeatable) | Nella Hedgeward (Last Hedge Redoubt) | 38 | kill 8 unrelenting_zombie [in elandor_ashenward_march/warfields] | 440 | ashenward_hedge_02 |
| ashenward_hedge_04 | Group: The Last Receipt | Nella Hedgeward (Last Hedge Redoubt) | 38 | kill 1 red_receipt_marshal | 1320 | ashenward_hedge_03 |
| cinderline_front_01 | Bread Before Banners | Toren Waterbarrel (Cinderline Watch) | 40 | kill 5 causeway_mire_husk [in front_broken_causeway/floodmeadows] | 823 | - |
| cinderline_front_02 | The Night Shift Never Left | Toren Waterbarrel (Cinderline Watch) | 40 | kill 5 causeway_toll_skeleton [in front_broken_causeway/floodmeadows] | 823 | - |
| lasthedge_front_01 | Nobody's Laughing Here | Nella Hedgeward (Last Hedge Redoubt) | 40 | kill 5 warpack_hyena [in front_shattered_line/approaches] | 823 | - |
| cinderline_front_05 | Toll Collectors in the Alderwood | Toren Waterbarrel (Cinderline Watch) | 41 | kill 5 causeway_brigand [in front_broken_causeway/alderwood] | 1080 | cinderline_front_01 |
| lasthedge_front_02 | The Fletchers' Bright Idea | Nella Hedgeward (Last Hedge Redoubt) | 41 | bring 3 grug_mobs:siege_cat_claw | 960 | lasthedge_front_01 |
| cinderline_front_03 | What the War Left Standing | Toren Waterbarrel (Cinderline Watch) | 43 | kill 5 causeway_mire_husk or causeway_brigand [in front_broken_causeway/battlefield] | 1250 | cinderline_front_01, cinderline_front_02 |
| cinderline_front_04 | Cinderline Still Stands | Toren Waterbarrel (Cinderline Watch) | 44 | talk to Alna Archsight (r20_anchor_028) | 250 | cinderline_front_03 |
| lasthedge_front_03 | A Sentry Needs Somewhere to Stand | Nella Hedgeward (Last Hedge Redoubt) | 44 | kill 5 war_stinger [in front_shattered_line/ramparts] | 1275 | lasthedge_front_02 |
| lasthedge_front_07 | Raiders in the Trenches | Nella Hedgeward (Last Hedge Redoubt) | 45 | kill 5 siege_skeleton_raider [in front_shattered_line/trenches] | 1275 | lasthedge_front_03 |
| lasthedge_front_04 | Nobody Left to Rally | Nella Hedgeward (Last Hedge Redoubt) | 47 | kill 5 siege_skeleton_raider [in front_shattered_line/breach]; kill 1 standard_bearer_ninepins | 1620 | lasthedge_front_07 |
| lasthedge_front_bounty | Bounty: Room for a Lookout (repeatable) | Nella Hedgeward (Last Hedge Redoubt) | 47 | kill 5 reed_stalking_tiger [in front_shattered_line/siegecrest] | 663 | lasthedge_front_04 |
| lasthedge_front_05 | Group: An End to the Grinding | Nella Hedgeward (Last Hedge Redoubt) | 49 | kill 1 siege_engine_nine | 1100 | lasthedge_front_04 |
| lasthedge_front_06 | A Recommendation with Mud on It | Nella Hedgeward (Last Hedge Redoubt) | 49 | talk to Borin Splitbolt (r20_anchor_027) | 275 | lasthedge_front_04 |

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

