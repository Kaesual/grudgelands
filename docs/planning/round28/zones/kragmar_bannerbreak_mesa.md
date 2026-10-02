# Bannerbreak Mesa (`kragmar_bannerbreak_mesa`)

Zone 26 · contested 31-40 · contested · race region **orc** · levels **31-40** · contested · relief `plateau` · seed 42

Map: [maps/kragmar_bannerbreak_mesa.png](maps/kragmar_bannerbreak_mesa.png). Machine-readable: [kragmar_bannerbreak_mesa.json](kragmar_bannerbreak_mesa.json). Coordinates are world nodes (x east, z north, y up).

Race track (orc): step 5 of the track Sunscar Flats → Redtusk Savanna → Gor Drazhak → Speargrass Reach → Bannerbreak Mesa.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -940..1052, z 332..1184 (centroid 61, 727) |
| Land area | 1280288 nodes² (≈ 1.28 km²) |
| Hub point (authored) | 0, 700 |
| Height above sea | min 44, p10 70, median 97, p90 131, max 280 |
| Slope | 9.1% steep (>1 node/node), 0.7% cliff (>2) |
| Biomes (measured) | badlands 68.3%, savanna 23.1%, swamp 7.9%, meadows 0.3%, bone_forest 0.1%, deep_jungle 0.1%, deep_forest 0.1%, jungle_edge 0.0% |
| Neighbours (land border) | front_broken_causeway (1360 nodes, mid -446,410), front_shattered_line (1276 nodes, mid 536,366), kragmar_blackwind_rise (488 nodes, mid -921,727), kragmar_gor_drazhak (1212 nodes, mid 9,1106), kragmar_speargrass_reach (660 nodes, mid -707,1011), kragmar_thunderroot_wilds (732 nodes, mid 977,647), kragmar_whispering_reedlands (664 nodes, mid 703,1074) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 6336 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 6080 nodes² |
| Protected / drift band | 1.3% of land protected (towns, villages, camps/POIs, road corridors); 5.3% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L31 8.3%, L32 10.0%, L33 11.2%, L34 12.0%, L35 11.0%, L36 11.6%, L37 8.8%, L38 8.9%, L39 8.5%, L40 9.6%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_043 | outpost | Red Ramp Post | -374 | 77 | 874 | 33 | poi x -382..-367, z 866..881 |
| anchor_044 | outpost | Tornstandard Hold | 276 | 129 | 594 | 37 | poi x 268..283, z 586..601 |
| anchor_058 | bandit hideout | Sunderstrap Camp | 96 | 118 | 534 | 38 | camp x 88..103, z 526..541 |
| anchor_073 | clash site | Redcut Breach | -218 | 69 | 424 | 40 | poi x -226..-211, z 416..431 |
| anchor_074 | clash site | Bannerfall Pocket | 282 | 133 | 424 | 40 | poi x 274..289, z 416..431 |
| anchor_096 | rare route | Dustwing's Perch | 156 | 118 | 794 | 34 | poi x 150..161, z 788..799 |

## Protected areas

- poi Red Ramp Post (anchor_043): x -382..-367, z 866..881
- poi Tornstandard Hold (anchor_044): x 268..283, z 586..601
- camp Sunderstrap Camp (anchor_058): x 88..103, z 526..541
- poi Redcut Breach (anchor_073): x -226..-211, z 416..431
- poi Bannerfall Pocket (anchor_074): x 274..289, z 416..431
- poi Dustwing's Perch (anchor_096): x 150..161, z 788..799
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Red Ramp Post (`r20_anchor_043`, anchor_043) at -374, 77, 874

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Drek Rampbinder | -372, 78, 874 | bannerbreak_ramp_01, bannerbreak_ramp_02, bannerbreak_ramp_03, bannerbreak_ramp_bounty, bb_front_ramp_01, bb_front_ramp_02, bb_front_ramp_03, bb_front_ramp_04, bb_front_ramp_05, bb_front_ramp_bounty |

Distances: zone edge N 236 (kragmar_gor_drazhak), S 480 (front_broken_causeway), E 1292 (kragmar_thunderroot_wilds), W 552 (kragmar_blackwind_rise); nearest other-zone land 238 N; sea 1207 NW; sea-beach sand 1170 NW; nearest road 13.
Nearest hubs (straight / by road): Hollowarch Station 1140 / 1520; Tornstandard Hold 708 / 1704; Last Hedge Redoubt 1594 / 2935; Thunderstep Watch 2283 / 3936; Ashveil Watch 1644 / 4043.

### Tornstandard Hold (`r20_anchor_044`, anchor_044) at 276, 129, 594

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Yarra Standardmender | 278, 130, 594 | bannerbreak_standard_01, bannerbreak_standard_02, bannerbreak_standard_03, bannerbreak_standard_04, bannerbreak_standard_bounty, bannerbreak_standard_group, bb_front_torn_01, bb_front_torn_02, bb_front_torn_03, bb_front_torn_04, bb_front_torn_05, bb_front_torn_06, bb_front_torn_07, bb_front_torn_bounty |

Distances: zone edge N 516 (kragmar_gor_drazhak), S 224 (front_shattered_line), E 692 (kragmar_thunderroot_wilds), W 1204 (kragmar_blackwind_rise); nearest other-zone land 216 SW; sea 1478 N; sea-beach sand 1437 N; nearest road 11.
Nearest hubs (straight / by road): Red Ramp Post 708 / 1704; Last Hedge Redoubt 1164 / 1851; Hollowarch Station 1744 / 3094; Cinderline Watch 1574 / 3287; Thunderstep Watch 1626 / 4369.

### Current quests (24, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| bannerbreak_ramp_01 | The Last Laugh | Drek Rampbinder (Red Ramp Post) | 29 | kill 4 warpack_hyena [in kragmar_bannerbreak_mesa/badlands] | 630 | - |
| bannerbreak_standard_01 | Inspect Your Bedroll | Yarra Standardmender (Tornstandard Hold) | 29 | kill 4 war_stinger [in kragmar_bannerbreak_mesa/badlands]; bring 2 grug_mobs:venom_sac | 720 | - |
| bannerbreak_ramp_02 | A Blade for Yarra | Drek Rampbinder (Red Ramp Post) | 31 | talk to Yarra Standardmender (r20_anchor_044) | 278 | bannerbreak_ramp_01 |
| bannerbreak_standard_02 | Where the Rain Fights Back | Yarra Standardmender (Tornstandard Hold) | 32 | talk to Rumela Stormstep (r20_anchor_048) | 285 | bannerbreak_standard_01 |
| bannerbreak_standard_03 | A Scout Is Worth More | Yarra Standardmender (Tornstandard Hold) | 33 | kill 4 reed_stalking_tiger [in kragmar_bannerbreak_mesa/warplains] | 700 | bannerbreak_standard_01 |
| bannerbreak_ramp_03 | Rattle's Bad Arithmetic | Drek Rampbinder (Red Ramp Post) | 34 | kill 4 siege_goblin or siege_goblin_slinger [in kragmar_bannerbreak_mesa/supply_camp]; kill 1 provisioner_rattle | 1025 | bannerbreak_ramp_01 |
| bannerbreak_ramp_bounty | Bounty: Teeth After Dark (repeatable) | Drek Rampbinder (Red Ramp Post) | 35 | kill 6 warpack_hyena [in kragmar_bannerbreak_mesa/warplains] | 410 | bannerbreak_ramp_03 |
| bannerbreak_standard_04 | A Soldier's Due | Yarra Standardmender (Tornstandard Hold) | 37 | kill 4 unrelenting_husk [in kragmar_bannerbreak_mesa/redcut_flats] | 753 | bannerbreak_standard_03 |
| bannerbreak_standard_bounty | Bounty: Arrows from Sunderstrap Camp (repeatable) | Yarra Standardmender (Tornstandard Hold) | 37 | kill 6 entrenched_bandit_archer [in kragmar_bannerbreak_mesa/sunderstrap_camp] | 440 | bannerbreak_standard_04 |
| bannerbreak_standard_group | Group: No Banner for Supper | Yarra Standardmender (Tornstandard Hold) | 38 | kill 1 banner_eater | 880 | bannerbreak_standard_04 |
| bb_front_ramp_01 | Make the Mud Keep Them | Drek Rampbinder (Red Ramp Post) | 40 | kill 5 causeway_mire_husk [in front_broken_causeway/floodmeadows] | 823 | - |
| bb_front_torn_01 | Nobody Laughs at Supper | Yarra Standardmender (Tornstandard Hold) | 40 | kill 5 warpack_hyena [in front_shattered_line/approaches] | 823 | - |
| bb_front_torn_02 | Mind the Boots | Yarra Standardmender (Tornstandard Hold) | 40 | kill 5 war_stinger [in front_shattered_line/bluffs] | 823 | - |
| bb_front_ramp_02 | No Marching After Death | Drek Rampbinder (Red Ramp Post) | 41 | kill 5 causeway_ford_zombie [in front_broken_causeway/reedmire] | 840 | bb_front_ramp_01 |
| bb_front_torn_03 | A Standard with Claws | Yarra Standardmender (Tornstandard Hold) | 42 | kill 4 reed_stalking_tiger [in front_shattered_line/bluffs]; bring 2 grug_mobs:siege_cat_claw | 1103 | bb_front_torn_01 |
| bb_front_ramp_03 | Teeth in the Dark | Drek Rampbinder (Red Ramp Post) | 43 | kill 5 causeway_fenrunner_wolf [in front_broken_causeway/wraithwood] | 1000 | bb_front_ramp_01 |
| bb_front_torn_04 | Stings for Our Side | Yarra Standardmender (Tornstandard Hold) | 45 | kill 5 war_stinger [in front_shattered_line/ramparts]; bring 2 grug_mobs:scorch_venom | 1170 | bb_front_torn_02 |
| bb_front_ramp_04 | Payment in Full | Drek Rampbinder (Red Ramp Post) | 46 | kill 4 causeway_aqueduct_bowman [in front_broken_causeway/toll_camp]; kill 1 toll_taker_senn | 1590 | bb_front_ramp_02, bb_front_ramp_03 |
| bb_front_ramp_bounty | Bounty: Bad Career Choices (repeatable) | Drek Rampbinder (Red Ramp Post) | 46 | kill 5 causeway_brigand [in front_broken_causeway/wraithwood] | 650 | bb_front_ramp_04 |
| bb_front_torn_05 | Let That Banner Fall | Yarra Standardmender (Tornstandard Hold) | 46 | kill 4 siege_skeleton_raider [in front_shattered_line/breach]; kill 1 standard_bearer_ninepins | 1590 | bb_front_torn_03, bb_front_torn_04 |
| bb_front_ramp_05 | A Name Worth Sending | Drek Rampbinder (Red Ramp Post) | 47 | talk to Orrel Hollowstep (r20_anchor_040) | 265 | bb_front_ramp_04 |
| bb_front_torn_06 | Group: Break the War Machine | Yarra Standardmender (Tornstandard Hold) | 48 | kill 1 siege_engine_nine | 1100 | bb_front_torn_05 |
| bb_front_torn_bounty | Bounty: Stripes at the Front (repeatable) | Yarra Standardmender (Tornstandard Hold) | 48 | kill 5 reed_stalking_tiger [in front_shattered_line/siegecrest] | 810 | bb_front_torn_05 |
| bb_front_torn_07 | Send a Fighter, Save a Banner | Yarra Standardmender (Tornstandard Hold) | 49 | talk to Nalo Pathdrum (kezamba) | 275 | bb_front_torn_05 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| dustwing_vulture | Mesa Vulture | aggressive | 16.2% of land, L31-40 | - |  |
| entrenched_bandit | Entrenched Bandit | aggressive | - | 26.9% of land, L31-33 |  |
| entrenched_bandit_archer | Entrenched Bandit Archer | aggressive | 1.0% of land, L38-40 | 1.0% of land, L38-40 |  |
| march_skeleton_raider | March Skeleton Raider | aggressive | - | 3.1% of land, L31-33 |  |
| marching_husk | Marching Sun-Dried Husk | aggressive | 30.0% of land, L31-33 | 37.2% of land, L34-35 |  |
| reed_stalking_tiger | Tallgrass Tiger | aggressive | 42.8% of land, L34-40 | - |  |
| siege_goblin | Siege Goblin | aggressive | 1.4% of land, L34-40 | 1.4% of land, L34-40 |  |
| siege_goblin_hound | Siege Goblin Hound | aggressive | 0.7% of land, L38-40 | 0.7% of land, L38-40 |  |
| siege_goblin_slinger | Siege Goblin Slinger | aggressive | 0.7% of land, L34-37 | 0.7% of land, L34-37 |  |
| unrelenting_husk | Trench Mummy | aggressive | 18.4% of land, L38-40 | 35.6% of land, L36-40 |  |
| war_stinger | War-Stinger Scorpion | aggressive | - | 30.0% of land, L31-33 |  |
| warpack_hyena | Warpack Hyena | aggressive | 75.1% of land, L31-40 | 48.1% of land, L34-40 |  |
| watchful_carrion_crow | Battlefield Crow | neutral | 6.3% of land, L34-40 | 2.4% of land, L34-37 |  |

**Camps and guard posts:**

- anchor_043 Red Ramp Post at -374, 874: guard post, guard_throng × 2-3, respawn 180-360 s, level there L33.
- anchor_044 Tornstandard Hold at 276, 594: guard post, guard_throng × 2-3, respawn 180-360 s, level there L37.
- anchor_058 Sunderstrap Camp at 96, 534: bandit, bandit/bandit_archer × 3-5, respawn 30-60 s, level there L38.

**Rares (knowledge rewards, not quest targets):** Dustwing (vulture, the badlands, route 108,770 → 172,834 → 212,778, L35, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 27 | secondary | anchor_043 (Red Ramp Post, kragmar_bannerbreak_mesa) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 391 / 262 | -367,885 → -291,1116 |
| 29 | primary | anchor_008 (Highcourt, elandor_highcourt) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 2860 / 692 | 54,454 → -35,1076 |
| 43 | trail | anchor_040 (Hollowarch Station, kragmar_blackwind_rise) | joins road 27 | 1445 / 722 | -813,500 → -336,928 |
| 46 | trail | anchor_044 (Tornstandard Hold, kragmar_bannerbreak_mesa) | joins road 29 | 300 / 296 | 266,598 → 9,572 |
| 57 | trail | anchor_056 (Pallcloth Den, kragmar_blackwind_rise) | joins road 29 | 2074 / 306 | -571,363 → -135,363 |
| 59 | trail | anchor_058 (Sunderstrap Camp, kragmar_bannerbreak_mesa) | joins road 29 | 207 / 76 | 100,524 → 91,455 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

