# Kapok Cradle (`kragmar_kapok_cradle`)

Zone 27 · start zone · throng · race region **troll** · levels **1-10** · peaceful · relief `lowland` · seed 42

Map: [maps/kragmar_kapok_cradle.png](maps/kragmar_kapok_cradle.png). Machine-readable: [kragmar_kapok_cradle.json](kragmar_kapok_cradle.json). Coordinates are world nodes (x east, z north, y up).

Race track (troll): step 1 of the track Kapok Cradle → Raincall Basin → Kezamba → Whispering Reedlands → Totemwater Reach → Thunderroot Wilds.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 1228..2680, z 2152..3008 (centroid 1900, 2541) |
| Land area | 604704 nodes² (≈ 0.60 km²) |
| Hub point (authored) | 1800, 2550 |
| Height above sea | min 0, p10 4, median 15, p90 33, max 70 |
| Slope | 1.0% steep (>1 node/node), 0.2% cliff (>2) |
| Biomes (measured) | jungle_edge 85.2%, swamp 14.7%, deep_jungle 0.1% |
| Neighbours (land border) | kragmar_raincall_basin (1536 nodes, mid 1883,2278), kragmar_totemwater_reach (216 nodes, mid 2584,2159) |
| Sea coast | 3520 nodes of coastline; sea-beach sand 44144 nodes²; lake/river-bank sand 4832 nodes² |
| Water inside | bay 243312 nodes², rivers/lakes 2368 nodes² |
| Protected / drift band | 4.3% of land protected (towns, villages, camps/POIs, road corridors); 3.1% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 1488, 2765 | x 1380..1560, z 2600..2912 | 14928 | L3 |
| B2 | 2564, 2283 | x 2420..2680, z 2168..2376 | 13904 | L6-10 |
| B3 | 2258, 2573 | x 2160..2360, z 2516..2632 | 6176 | L3-4 |
| B4 | 1737, 2962 | x 1660..1812, z 2932..3008 | 2688 | L3 |
| B5 | 2075, 2800 | x 2048..2104, z 2768..2852 | 2480 | L3 |
| B6 | 2157, 2651 | x 2128..2200, z 2624..2684 | 1472 | L3 |
| B7 | 2391, 2532 | x 2368..2408, z 2512..2552 | 800 | L4 |
| B8 | 2092, 2744 | x 2064..2120, z 2720..2760 | 592 | L3 |
| B9 | 2438, 2446 | x 2436..2444, z 2436..2460 | 176 | L5 |
| B10 | 1247, 2384 | x 1236..1256, z 2376..2392 | 144 | L9 |

## Levels

Start-zone gradient (zones.lua): L1 within 100 nodes of the start anchor, L2 to 150; beyond, band 1 top (L3) behind and beside the town, rising through band 2 (L4-6) and band 3 (L7-10) toward the front border (-z), reaching L10 at the border.

Share of land per level: L1 5.2%, L2 6.5%, L3 46.8%, L4 7.2%, L5 6.8%, L6 6.2%, L7 5.8%, L8 5.5%, L9 4.9%, L10 5.0%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_006 | start town | Kapok | 1800 | 7 | 2550 | 1 | - |

## Protected areas

- Start town: pad x 1736..1863, z 2486..2613 plus a 12-node band (outer box x 1724..1875, z 2474..2625); hard protected, hostile spawns refused.
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Kapok (`kapok`, anchor_006) at 1800, 7, 2550

Residents/guards: guard_patrol 5, guard_post 2, idle 6, innkeeper 1, public_station 1, quest 2, trainer 1, vendor 1, waypoint 1, work 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| clearing_vendor | vendor | vendor kind: race | 1807, 8, 2546 | - |
| idle_lodge_door | innkeeper (respawn bind) |  | 1798, 8, 2567 | - |
| hall_quest | quest giver | Zalima Rainhum | 1803, 8, 2567 | kapok_departure, kapok_hunt_01, kapok_hunt_02, kapok_hunt_03, kapok_hunt_04, kapok_hunt_05, kapok_tools_01, kapok_tools_02, kapok_tools_03, kapok_tools_04 |
| travel_waypoint | waypoint |  | 1788, 8, 2555 | - |
| trainer_cooking | profession trainer | trains: cooking | 1802, 8, 2540 | - |
| quest_cook | quest giver | Zemi Sweetroot | 1802, 8, 2537 | kapok_kitchen_01, kapok_kitchen_02, kapok_kitchen_03, kapok_pantry_01, kapok_pantry_02, kapok_pantry_03 |

Public stations: cook_oven (furnace).

Distances: zone edge N 424 (coastal_shelf), S 220 (kragmar_raincall_basin), E 536 (coastal_shelf), W 464 (coastal_shelf); nearest other-zone land 222 S; sea 352 NW; sea-beach sand 310 NW; nearest road 64.
Nearest hubs (straight / by road): Raincall Village 512 / 707; Raincall Outpost 572 / 945; Raincall Bandit Camp 543 / 1089; Kezamba 1050 / 1639; Whisperreed Landing 1322 / 1694.

### Current quests (16, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| kapok_hunt_01 | A Boar Has No Use for Beads | Zalima Rainhum (Kapok) | 1 | kill 8 small_boar [in kragmar_kapok_cradle/yam_beds] | 105 | - |
| kapok_kitchen_01 | The Pot Is Waiting | Zemi Sweetroot (Kapok) | 1 | bring 5 group:tree | 30 | - |
| kapok_tools_01 | Save Your Knuckles | Zalima Rainhum (Kapok) | 1 | bring 1 grug_materials:axe_wood; bring 1 grug_materials:pick_wood | 30 | - |
| kapok_hunt_02 | One Squeak, Many Cousins | Zalima Rainhum (Kapok) | 2 | kill 8 large_rat [in kragmar_kapok_cradle/yam_beds] | 105 | kapok_hunt_01 |
| kapok_kitchen_02 | Heat Before Hospitality | Zemi Sweetroot (Kapok) | 2 | bring 5 default:coal_lump | 60 | kapok_kitchen_01 |
| kapok_tools_02 | A Lesson Under the Moss | Zalima Rainhum (Kapok) | 2 | bring 1 grug_materials:axe_stone; bring 1 grug_materials:pick_stone | 60 | kapok_tools_01 |
| kapok_hunt_03 | The Roots Remember Feet | Zalima Rainhum (Kapok) | 3 | kill 6 braindead_zombie [in kragmar_kapok_cradle/rootways] | 135 | kapok_hunt_02 |
| kapok_pantry_01 | You Chew It, You Patch It | Zemi Sweetroot (Kapok) | 3 | bring 2 grug_mobs:rat_fur_patch | 60 | kapok_hunt_02 |
| kapok_kitchen_03 | A Hunter Worth Inviting | Zemi Sweetroot (Kapok) | 4 | bring 5 mobs:meat | 75 | kapok_kitchen_02, kapok_hunt_01 |
| kapok_pantry_02 | Guests with Pincers | Zemi Sweetroot (Kapok) | 4 | bring 2 grug_mobs:crab_leg | 90 | kapok_pantry_01 |
| kapok_pantry_03 | Supper Above the Mud | Zemi Sweetroot (Kapok) | 5 | bring 2 grug_mobs:fine_sinew | 110 | kapok_pantry_02 |
| kapok_tools_03 | What the Fire Leaves | Zalima Rainhum (Kapok) | 5 | bring 3 grug_materials:copper_bar; bring 3 grug_materials:tin_bar | 83 | kapok_tools_02 |
| kapok_hunt_04 | Read the Tusks | Zalima Rainhum (Kapok) | 7 | kill 8 aggressive_boar [in kragmar_kapok_cradle/thornwood] | 245 | kapok_hunt_03 |
| kapok_tools_04 | Two Voices in the Fire | Zalima Rainhum (Kapok) | 7 | bring 3 grug_materials:bronze_bar | 130 | kapok_tools_03 |
| kapok_hunt_05 | Luck Stolen Twice | Zalima Rainhum (Kapok) | 8 | kill 6 confused_bandit [in kragmar_kapok_cradle/thieves_camp]; kill 1 offering_thief_chief | 315 | kapok_hunt_04 |
| kapok_departure | Roots Hold, Feet Travel | Zalima Rainhum (Kapok) | 9 | talk to Daro Kapok (raincall_village) | 70 | kapok_hunt_05 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| aggressive_boar | Aggressive Boar | aggressive | 29.3% of land, L5-10 | - |  |
| braindead_zombie | Braindead Zombie | aggressive | - | 32.8% of land, L3-4 |  |
| confused_bandit | Confused Bandit | aggressive | 1.5% of land, L9-10 | 1.5% of land, L9-10 |  |
| drowned_zombie | Monstrous Drowned Zombie | aggressive | - | 2.0% of land, L8-10 |  |
| giant_crab | Monstrous Crab | aggressive | 4.5% of land, L7-10 | - |  |
| giant_viper | Monstrous Viper | aggressive | 26.5% of land, L8-9 | 26.5% of land, L8-9 |  |
| large_rat | Large Rat | aggressive | - | 31.2% of land, L1-4 |  |
| monstrous_rat | Monstrous Rat | aggressive | - | 26.5% of land, L8-10 |  |
| prowling_jungle_lynx | Aggressive Jungle Lynx | aggressive | 24.0% of land, L5-7 | - |  |
| quiet_shore_crab | Small Crab | neutral | 6.2% of land, L3-6 | - |  |
| rabid_rat | Aggressive Rat | aggressive | - | 24.0% of land, L5-7 |  |
| reed_viper | Aggressive Viper | aggressive | 2.8% of land, L5-7 | 26.8% of land, L5-7 |  |
| shore_crab | Shore Crab | neutral | 44144 nodes², L3-10 | 44144 nodes², L3-10 | sand (dry, within 6 nodes of water) |
| sluggish_zombie | Sluggish Zombie | aggressive | - | 5.4% of land, L5-7 |  |
| small_boar | Small Boar | neutral | 37.0% of land, L1-4 | - |  |
| young_tapir | Young Tapir | neutral | 24.0% of land, L5-7 | - |  |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 19 | primary | anchor_006 (Kapok, kragmar_kapok_cradle) | joins road 16 | 984 / 358 | 1800,2486 → 1515,2334 |
| 22 | secondary | anchor_023 (Raincall Village, kragmar_raincall_basin) | joins road 19 | 389 / 22 | 1637,2326 → 1629,2343 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

