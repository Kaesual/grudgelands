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
| quest_host | quest giver | Borin Splitbolt | -2072, 326, -826 | splitbolt_front_01, splitbolt_front_02, splitbolt_front_03, splitbolt_front_04, splitbolt_front_05, splitbolt_front_06, splitbolt_front_07, splitbolt_front_08, splitbolt_front_bounty, stormvault_bounty_strays, stormvault_passes_01, stormvault_passes_02, stormvault_passes_03, stormvault_road_archshadow, stormvault_road_ashenward |

Distances: zone edge N 432 (front_gravesalt_escarpment), S 276 (elandor_frostbarrow_shelf), E 1192 (elandor_ashenward_march), W 308 (coastal_shelf); nearest other-zone land 248 S; sea 274 W; sea-beach sand 318 NW; nearest road 13.
Nearest hubs (straight / by road): Archshadow Post 628 / 2195; Cinderline Watch 1724 / 4214; Last Hedge Redoubt 2388 / 5354; Tornstandard Hold 2746 / 6655; Glassroot Gate 4008 / 7209.

### Archshadow Post (`r20_anchor_028`, anchor_028) at -1500, 257, -570

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Alna Archsight | -1498, 258, -570 | archshadow_front_01, archshadow_front_02, archshadow_front_03, archshadow_front_04, archshadow_front_05, archshadow_front_bounty, stormvault_bounty_shamblers, stormvault_sighting_01, stormvault_sighting_02, stormvault_sighting_03, stormvault_sighting_04, stormvault_sighting_05 |

Distances: zone edge N 160 (front_broken_causeway), S 548 (elandor_dur_brannoc), E 516 (front_broken_causeway), W 900 (coastal_shelf); nearest other-zone land 158 N; sea 868 W; sea-beach sand 873 W; nearest road 13.
Nearest hubs (straight / by road): Splitbolt Station 628 / 2195; Cinderline Watch 1184 / 4005; Last Hedge Redoubt 1800 / 5145; Tornstandard Hold 2123 / 6446; Glassroot Gate 3434 / 6999.

### Current quests (27, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| stormvault_passes_01 | Postage and Talons | Borin Splitbolt (Splitbolt Station) | 30 | kill 5 ridge_crag_eagle [in elandor_stormvault_heights/eagle_crags] | 540 | - |
| stormvault_passes_02 | The Mountain's Night Shift | Borin Splitbolt (Splitbolt Station) | 31 | kill 5 rime_skeleton_stray [in elandor_stormvault_heights/eagle_crags] | 555 | stormvault_passes_01 |
| stormvault_passes_03 | A Proper Introduction to Rock | Borin Splitbolt (Splitbolt Station) | 31 | bring 4 grug_materials:silversteel_bar | 380 | stormvault_passes_01 |
| stormvault_bounty_strays | Bounty: Bones Off the Road (repeatable) | Borin Splitbolt (Splitbolt Station) | 32 | kill 6 rime_skeleton_stray [in elandor_stormvault_heights/passes] | 370 | stormvault_passes_02 |
| stormvault_road_ashenward | Good News Travels on Foot | Borin Splitbolt (Splitbolt Station) | 32 | talk to Toren Waterbarrel (r20_anchor_031) | 190 | stormvault_passes_02 |
| stormvault_road_archshadow | Alna Keeps Count | Borin Splitbolt (Splitbolt Station) | 34 | talk to Alna Archsight (r20_anchor_028) | 195 | stormvault_passes_02 |
| stormvault_sighting_01 | Some Assembly Stolen | Alna Archsight (Archshadow Post) | 34 | kill 6 siege_goblin or siege_goblin_slinger [in elandor_stormvault_heights/goblin_camp] | 718 | - |
| stormvault_sighting_02 | No More Bolts for Bolt-Chewer | Alna Archsight (Archshadow Post) | 35 | kill 1 bolt_chewer | 820 | stormvault_sighting_01 |
| stormvault_sighting_04 | A Clearer View of Trouble | Alna Archsight (Archshadow Post) | 36 | bring 2 grug_materials:emberglass | 525 | stormvault_sighting_01 |
| stormvault_sighting_03 | A Toll Paid in Arrows | Alna Archsight (Archshadow Post) | 37 | kill 5 entrenched_bandit_archer [in elandor_stormvault_heights/slatehook] | 770 | stormvault_sighting_02 |
| stormvault_bounty_shamblers | Bounty: An Overdue Dismissal (repeatable) | Alna Archsight (Archshadow Post) | 38 | kill 8 unrelenting_zombie [in elandor_stormvault_heights/frostfields] | 440 | stormvault_sighting_03 |
| stormvault_sighting_05 | Group: A Crack Is Not a Weakness | Alna Archsight (Archshadow Post) | 38 | kill 1 split_seam_warden | 1320 | stormvault_sighting_03 |
| archshadow_front_01 | Bad Workmanship, Worse Company | Alna Archsight (Archshadow Post) | 45 | kill 5 causeway_brigand or causeway_aqueduct_bowman [in front_broken_causeway/wraithwood] | 1300 | - |
| archshadow_front_02 | A Runesmith's Awkward Questions | Alna Archsight (Archshadow Post) | 47 | bring 3 grug_mobs:siege_bone | 1350 | archshadow_front_01 |
| archshadow_front_03 | Collection Ends Here | Alna Archsight (Archshadow Post) | 48 | kill 5 causeway_aqueduct_bowman [in front_broken_causeway/toll_camp]; kill 1 toll_taker_senn | 1620 | archshadow_front_02 |
| archshadow_front_bounty | Bounty: An Arrow Too Many (repeatable) | Alna Archsight (Archshadow Post) | 48 | kill 5 causeway_aqueduct_bowman [in front_broken_causeway/gallows_wood] | 675 | archshadow_front_03 |
| archshadow_front_04 | Group: No More Toll | Alna Archsight (Archshadow Post) | 49 | kill 1 last_toll_construct | 1100 | archshadow_front_03 |
| archshadow_front_05 | Fit for Borin's Crew | Alna Archsight (Archshadow Post) | 49 | talk to Borin Splitbolt (r20_anchor_027) | 275 | archshadow_front_03 |
| splitbolt_front_01 | No Shoring, No Sense | Borin Splitbolt (Splitbolt Station) | 50 | kill 6 salt_boring_weevil [in front_gravesalt_escarpment/saltflats] | 1425 | - |
| splitbolt_front_02 | Rope with Opinions | Borin Splitbolt (Splitbolt Station) | 50 | kill 6 salt_web_spider [in front_gravesalt_escarpment/bonewood] | 1425 | - |
| splitbolt_front_03 | Something for the Mortar Crew | Borin Splitbolt (Splitbolt Station) | 53 | bring 3 grug_mobs:salt_chitin | 1650 | splitbolt_front_01, splitbolt_front_02 |
| splitbolt_front_04 | Leave the Graves Out of It | Borin Splitbolt (Splitbolt Station) | 54 | kill 6 salt_hex_witch [in front_gravesalt_escarpment/tomb_fen] | 1830 | splitbolt_front_03 |
| splitbolt_front_bounty | Bounty: Keep the Night Shift Moving (repeatable) | Borin Splitbolt (Splitbolt Station) | 54 | kill 5 salt_web_spider [in front_gravesalt_escarpment/tombwood] | 900 | splitbolt_front_05 |
| splitbolt_front_05 | An Overdue Dismissal | Borin Splitbolt (Splitbolt Station) | 55 | kill 5 last_pay_archer [in front_gravesalt_escarpment/saltroad_cliffs] | 1678 | splitbolt_front_04 |
| splitbolt_front_07 | The Whitewall Dead | Borin Splitbolt (Splitbolt Station) | 56 | kill 6 last_watch_husk [in front_gravesalt_escarpment/whitewall] | 1890 | splitbolt_front_05 |
| splitbolt_front_06 | Someone Who Came Back | Borin Splitbolt (Splitbolt Station) | 57 | talk to Eriath Boughwarden (lethariel) | 315 | splitbolt_front_08 |
| splitbolt_front_08 | The Last Watch Ends | Borin Splitbolt (Splitbolt Station) | 57 | kill 5 last_watch_skeleton_raider [in front_gravesalt_escarpment/ossuary_wood]; kill 1 watch_captain_huskell | 2240 | splitbolt_front_07 |

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

