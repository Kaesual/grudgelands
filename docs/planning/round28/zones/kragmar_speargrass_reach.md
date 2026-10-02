# Speargrass Reach (`kragmar_speargrass_reach`)

Zone 25 · home zone 21-30 · throng · race region **orc** · levels **21-30** · peaceful · relief `rolling_hills` · seed 42

Map: [maps/kragmar_speargrass_reach.png](maps/kragmar_speargrass_reach.png). Machine-readable: [kragmar_speargrass_reach.json](kragmar_speargrass_reach.json). Coordinates are world nodes (x east, z north, y up).

Race track (orc): step 4 of the track Sunscar Flats → Redtusk Savanna → Gor Drazhak → Speargrass Reach → Bannerbreak Mesa.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -1420..-460, z 920..2488 (centroid -921, 1519) |
| Land area | 788496 nodes² (≈ 0.79 km²) |
| Hub point (authored) | -900, 1500 |
| Height above sea | min 0, p10 46, median 95, p90 139, max 235 |
| Slope | 23.6% steep (>1 node/node), 1.9% cliff (>2) |
| Biomes (measured) | savanna 58.7%, badlands 40.3%, blight 0.5%, bone_forest 0.4%, swamp 0.2% |
| Neighbours (land border) | kragmar_bannerbreak_mesa (660 nodes, mid -703,1007), kragmar_blackwind_rise (480 nodes, mid -1154,1024), kragmar_gor_drazhak (680 nodes, mid -474,1405), kragmar_mournfen (408 nodes, mid -1397,1968), kragmar_nhal_veyr (796 nodes, mid -1355,1495), kragmar_redtusk_savanna (996 nodes, mid -649,2001), kragmar_sunscar_flats (84 nodes, mid -767,2460) |
| Sea coast | 1640 nodes of coastline; sea-beach sand 9920 nodes²; lake/river-bank sand 6688 nodes² |
| Water inside | bay 248352 nodes², rivers/lakes 46672 nodes² |
| Protected / drift band | 2.5% of land protected (towns, villages, camps/POIs, road corridors); 9.3% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -1146, 1861 | x -1312..-996, z 1804..1952 | 9104 | L22-23 |
| B2 | -1340, 2062 | x -1356..-1324, z 2044..2088 | 768 | L21 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L21 6.6%, L22 8.4%, L23 13.2%, L24 13.6%, L25 12.7%, L26 11.9%, L27 7.4%, L28 9.0%, L29 8.9%, L30 8.3%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_022 | village | Speargrass Wellhold | -868 | 110 | 1564 | 25 | village x -880..-857, z 1552..1575 |
| anchor_042 | outpost | Cutgrass Watch | -650 | 56 | 1250 | 28 | poi x -658..-643, z 1242..1257 |
| anchor_065 | mine | Redpick Yard | -1050 | 72 | 1280 | 27 | poi x -1060..-1041, z 1270..1289 |

## Protected areas

- village Speargrass Wellhold (anchor_022): x -880..-857, z 1552..1575
- poi Cutgrass Watch (anchor_042): x -658..-643, z 1242..1257
- poi Redpick Yard (anchor_065): x -1060..-1041, z 1270..1289
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Speargrass Wellhold (`r20_anchor_022`, anchor_022) at -868, 110, 1564

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Brakka Jarward | -866, 111, 1564 | speargrass_grass_01, speargrass_grass_02, speargrass_journeys_01 |

Distances: zone edge N 532 (coastal_shelf), S 628 (kragmar_bannerbreak_mesa), E 396 (kragmar_gor_drazhak), W 480 (kragmar_nhal_veyr); nearest other-zone land 389 E; sea 359 NW; sea-beach sand 322 NW; nearest road 16.
Nearest hubs (straight / by road): Redpick Yard 337 / 754; Mournfen Bandit Camp 879 / 1350; Nhal Veyr 934 / 1462; Mournfen Village 1128 / 1741; Ossuary Ledgerstead 1512 / 1924.

### Cutgrass Watch (`r20_anchor_042`, anchor_042) at -650, 56, 1250

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Morga Cutgrass | -648, 57, 1250 | speargrass_watch_01, speargrass_watch_02, speargrass_watch_03 |

Distances: zone edge N 692 (kragmar_redtusk_savanna), S 216 (kragmar_bannerbreak_mesa), E 160 (kragmar_gor_drazhak), W 700 (kragmar_nhal_veyr); nearest other-zone land 156 E; sea 740 NW; sea-beach sand 704 NW; nearest road 13.
Nearest hubs (straight / by road): Gor Drazhak 696 / 982; Redtusk Village 940 / 1507; Mournfen Bandit Camp 1242 / 1645; Redtusk Bandit Camp 1214 / 1823; Red Ramp Post 466 / 1830.

### Redpick Yard (`r20_anchor_065`, anchor_065) at -1050, 72, 1280

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Gorren Redpick | -1048, 73, 1280 | speargrass_bounty, speargrass_yard_01, speargrass_yard_02 |

Distances: zone edge N 636 (bay_water), S 300 (kragmar_blackwind_rise), E 576 (kragmar_gor_drazhak), W 292 (kragmar_nhal_veyr); nearest other-zone land 274 S; sea 562 N; sea-beach sand 533 N; nearest road 14.
Nearest hubs (straight / by road): Speargrass Wellhold 337 / 754; Mournfen Bandit Camp 946 / 1460; Nhal Veyr 782 / 1572; Mournfen Village 1127 / 1851; Ossuary Ledgerstead 1368 / 2034.

### Current quests (9, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| speargrass_grass_01 | Still Using Those Ankles | Brakka Jarward (Speargrass Wellhold) | 21 | kill 8 dust_stinger [in kragmar_speargrass_reach/plains] | 608 | - |
| speargrass_journeys_01 | Promises Outlast Breath | Brakka Jarward (Speargrass Wellhold) | 22 | talk to Ossa Quietregister (nhal_veyr) | 210 | speargrass_grass_01 |
| speargrass_yard_01 | The Yard Eats Steel | Gorren Redpick (Redpick Yard) | 23 | bring 4 grug_materials:steel_bar | 653 | - |
| speargrass_grass_02 | Optional: Count the Cutters Home | Brakka Jarward (Speargrass Wellhold) | 24 | kill 8 reed_stalking_tiger [in kragmar_speargrass_reach/tallgrass] | 675 | speargrass_grass_01 |
| speargrass_yard_02 | Optional: Put the Claws to Work | Gorren Redpick (Redpick Yard) | 25 | bring 3 grug_mobs:shearing_cat_claw | 543 | speargrass_yard_01 |
| speargrass_watch_01 | Optional: Teeth Beyond the Watch | Morga Cutgrass (Cutgrass Watch) | 26 | kill 8 dustpack_hyena [in kragmar_speargrass_reach/hunting_grounds] | 743 | - |
| speargrass_bounty | Bounty: Stripes on the Payroll (repeatable) | Gorren Redpick (Redpick Yard) | 28 | kill 6 reed_stalking_tiger [in kragmar_speargrass_reach/hunting_grounds] | 425 | speargrass_yard_02 |
| speargrass_watch_02 | Our Colours Are Not for Sale | Morga Cutgrass (Cutgrass Watch) | 28 | kill 8 ore_thieving_goblin or rubble_goblin_slinger [in kragmar_speargrass_reach/goblin_camp]; kill 1 banner_broker_rakk | 1105 | - |
| speargrass_watch_03 | Stand Where the Ash Falls | Morga Cutgrass (Cutgrass Watch) | 29 | talk to Vaska Ashlistener (r20_anchor_039) | 255 | speargrass_watch_02 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| armored_crab | Barnacle Pincher | aggressive | 0.5% of land, L25-27 | - |  |
| bank_crab | Bank Crab | neutral | 2.9% of land, L21-24 | - |  |
| dust_stinger | Dust-Stinger Scorpion | aggressive | - | 30.0% of land, L21-23 |  |
| dustpack_hyena | Dustpack Hyena | aggressive | 27.0% of land, L21-30 | 84.4% of land, L21-30 |  |
| dustwing_vulture | Mesa Vulture | aggressive | 40.2% of land, L21-30 | - |  |
| ore_thieving_goblin | Ore-Thieving Goblin | aggressive | 1.2% of land, L28-30 | 1.2% of land, L28-30 |  |
| reed_stalking_tiger | Tallgrass Tiger | aggressive | 81.6% of land, L21-30 | - |  |
| rubble_goblin_slinger | Rubble Goblin Slinger | aggressive | 1.2% of land, L28-30 | 1.2% of land, L28-30 |  |
| shore_crab | Shore Crab | neutral | 9920 nodes², L21-23 | 9920 nodes², L21-23 | sand (dry, within 6 nodes of water) |
| watchful_zebra | Waterhole Zebra | neutral | 40.9% of land, L21-30 | - |  |

**Camps and guard posts:**

- anchor_042 Cutgrass Watch at -650, 1250: guard post, guard_throng × 2-3, respawn 180-360 s, level there L28.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 15 | primary | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 1440 / 1044 | -1413,1844 → -483,1535 |
| 24 | secondary | anchor_022 (Speargrass Wellhold, kragmar_speargrass_reach) | joins road 15 | 234 / 234 | -852,1566 → -636,1543 |
| 31 | secondary | anchor_010 (Nhal Veyr, kragmar_nhal_veyr) | anchor_022 (Speargrass Wellhold, kragmar_speargrass_reach) | 802 / 524 | -1345,1563 → -883,1569 |
| 45 | trail | anchor_042 (Cutgrass Watch, kragmar_speargrass_reach) | joins road 15 | 322 / 320 | -639,1256 → -563,1511 |
| 66 | trail | anchor_065 (Redpick Yard, kragmar_speargrass_reach) | joins road 31 | 418 / 414 | -1058,1292 → -1156,1638 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

