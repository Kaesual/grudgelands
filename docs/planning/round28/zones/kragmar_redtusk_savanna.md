# Redtusk Savanna (`kragmar_redtusk_savanna`)

Zone 23 · home zone 11-20 · throng · race region **orc** · levels **11-20** · peaceful · relief `rolling_hills` · seed 42

Map: [maps/kragmar_redtusk_savanna.png](maps/kragmar_redtusk_savanna.png). Machine-readable: [kragmar_redtusk_savanna.json](kragmar_redtusk_savanna.json). Coordinates are world nodes (x east, z north, y up).

Race track (orc): step 2 of the track Sunscar Flats → Redtusk Savanna → Gor Drazhak → Speargrass Reach → Bannerbreak Mesa.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -772..724, z 1688..2424 (centroid -88, 2060) |
| Land area | 612144 nodes² (≈ 0.61 km²) |
| Hub point (authored) | 0, 2050 |
| Height above sea | min 0, p10 16, median 60, p90 98, max 144 |
| Slope | 3.0% steep (>1 node/node), 0.1% cliff (>2) |
| Biomes (measured) | savanna 60.2%, badlands 39.5%, swamp 0.2%, jungle_edge 0.1% |
| Neighbours (land border) | kragmar_gor_drazhak (1232 nodes, mid 8,1814), kragmar_speargrass_reach (1004 nodes, mid -654,2000), kragmar_sunscar_flats (1724 nodes, mid -127,2305), kragmar_whispering_reedlands (432 nodes, mid 628,1949) |
| Sea coast | 1132 nodes of coastline; sea-beach sand 11280 nodes²; lake/river-bank sand 3952 nodes² |
| Water inside | bay 57344 nodes², rivers/lakes 6896 nodes² |
| Protected / drift band | 1.4% of land protected (towns, villages, camps/POIs, road corridors); 4.3% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 512, 2140 | x 460..568, z 2104..2204 | 3760 | L12-14 |
| B2 | 513, 2311 | x 448..564, z 2292..2332 | 3056 | L11 |
| B3 | -735, 2337 | x -768..-700, z 2292..2372 | 2624 | L11 |
| B4 | 694, 2135 | x 668..724, z 2120..2152 | 992 | L13-14 |
| B5 | -731, 2265 | x -740..-724, z 2256..2276 | 224 | L11-12 |
| B6 | 455, 2219 | x 444..464, z 2204..2232 | 192 | L12 |
| B7 | 651, 2148 | x 648..652, z 2136..2160 | 144 | L13-14 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L11 7.9%, L12 11.1%, L13 11.8%, L14 13.9%, L15 13.5%, L16 12.0%, L17 9.0%, L18 8.7%, L19 7.1%, L20 5.1%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_021 | village | Redtusk Village | -88 | 51 | 2004 | 16 | village x -100..-77, z 1992..2015 |
| anchor_041 | outpost | Redtusk Outpost | 176 | 55 | 2074 | 15 | poi x 168..183, z 2066..2081 |
| anchor_057 | bandit camp | Redtusk Bandit Camp | 320 | 88 | 1980 | 16 | camp x 308..331, z 1968..1991 |
| anchor_098 | rare route | Ashmaw's Burnt Hollow | 152 | 36 | 2084 | 15 | poi x 146..157, z 2078..2089 |

## Protected areas

- village Redtusk Village (anchor_021): x -100..-77, z 1992..2015
- poi Redtusk Outpost (anchor_041): x 168..183, z 2066..2081
- camp Redtusk Bandit Camp (anchor_057): x 308..331, z 1968..1991
- poi Ashmaw's Burnt Hollow (anchor_098): x 146..157, z 2078..2089
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Redtusk Village (`redtusk_village`, anchor_021) at -88, 51, 2004

Residents/guards: idle 2, quest 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_steward | quest giver | Borak Redgrass | -86, 52, 2004 | r14_orc_07_teeth_around_the_herd |
| quest_local | quest giver | Morga Clayhand | -90, 52, 2002 | r15_orc_local_01, r15_orc_local_02 |

Distances: zone edge N 256 (kragmar_sunscar_flats), S 172 (kragmar_gor_drazhak), E 748 (kragmar_whispering_reedlands), W 588 (kragmar_speargrass_reach); nearest other-zone land 168 S; sea 564 NE; sea-beach sand 563 NE; nearest road 17.
Nearest hubs (straight / by road): Gor Drazhak 512 / 675; Sunscar 553 / 793; Redtusk Outpost 273 / 1168; Redtusk Bandit Camp 409 / 1251; Cutgrass Watch 940 / 1507.

### Redtusk Outpost (`redtusk_outpost`, anchor_041) at 176, 55, 2074

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_scout | quest giver | Kesh Longstride | 179, 56, 2071 | r14_orc_08_scour_the_dry_wash, r14_orc_09_no_forge_made_this_brand, r15_orc_local_03, r15_orc_local_04 |

Distances: zone edge N 172 (kragmar_sunscar_flats), S 208 (kragmar_gor_drazhak), E 532 (kragmar_whispering_reedlands), W 892 (kragmar_speargrass_reach); nearest other-zone land 173 N; sea 298 NE; sea-beach sand 309 NE; nearest road 11.
Nearest hubs (straight / by road): Sunscar 507 / 617; Redtusk Village 273 / 1168; Gor Drazhak 600 / 1644; Redtusk Bandit Camp 172 / 2220; Cutgrass Watch 1167 / 2475.

### Redtusk Bandit Camp (`redtusk_bandit_camp`, anchor_057) at 320, 88, 1980

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_captive | quest giver | Rokka Emberhand | 330, 89, 1990 | r15_orc_local_05, r15_orc_local_06 |

Distances: zone edge N 292 (kragmar_sunscar_flats), S 136 (kragmar_gor_drazhak), E 324 (kragmar_whispering_reedlands), W 984 (kragmar_speargrass_reach); nearest other-zone land 132 S; sea 249 NE; sea-beach sand 211 NE; nearest road 17.
Nearest hubs (straight / by road): Gor Drazhak 577 / 992; Reedvoice Station 829 / 1001; Whisperreed Landing 671 / 1120; Redtusk Village 409 / 1251; Red Ramp Post 1306 / 1660.

### Current quests (9, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r14_orc_07_teeth_around_the_herd | Teeth Around the Herd | Borak Redgrass (Redtusk Village) | 10 | kill 6 hyena or dustpack_hyena [in kragmar_redtusk_savanna] | 380 | r14_orc_06_husks_on_redtusk_road |
| r15_orc_local_01 | Hide for the Low Annex | Morga Clayhand (Redtusk Village) | 10 | bring 2 mobs:leather | 285 | r14_orc_06_husks_on_redtusk_road |
| r15_orc_local_02 | Fangs Beyond the Annex | Morga Clayhand (Redtusk Village) | 10 | bring 2 grug_mobs:fang | 380 | r14_orc_06_husks_on_redtusk_road |
| r14_orc_08_scour_the_dry_wash | Scour the Dry Wash | Kesh Longstride (Redtusk Outpost) | 11 | kill 6 scorpion or dust_stinger [in kragmar_redtusk_savanna] | 525 | r14_orc_07_teeth_around_the_herd |
| r15_orc_local_03 | Howls Below the Lookout | Kesh Longstride (Redtusk Outpost) | 11 | kill 4 hyena or dustpack_hyena [in kragmar_redtusk_savanna] | 315 | r14_orc_07_teeth_around_the_herd |
| r15_orc_local_04 | Venom Beside the Palisade | Kesh Longstride (Redtusk Outpost) | 11 | bring 2 grug_mobs:venom_sac | 420 | r14_orc_07_teeth_around_the_herd |
| r14_orc_09_no_forge_made_this_brand | No Forge Made This Brand | Kesh Longstride (Redtusk Outpost) | 12 | kill 4 bandit or bandit_archer or quarrelsome_bandit [in kragmar_redtusk_savanna] | 805 | r14_orc_08_scour_the_dry_wash |
| r15_orc_local_05 | The Carriers' Cut | Rokka Emberhand (Redtusk Bandit Camp) | 12 | bring 2 grug_mobs:stolen_purse | 460 | r14_orc_08_scour_the_dry_wash |
| r15_orc_local_06 | Bindings from the Loaded Sled | Rokka Emberhand (Redtusk Bandit Camp) | 12 | bring 5 grug_mobs:linen_cloth | 575 | r14_orc_08_scour_the_dry_wash |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bristling_boar | Ridgeback Tusker | aggressive | 55.4% of land, L15-20 | - |  |
| dust_stinger | Dust-Stinger Scorpion | aggressive | - | 28.5% of land, L11-13 |  |
| dustpack_hyena | Dustpack Hyena | aggressive | 28.5% of land, L11-13 | - |  |
| granary_rat | Granary Rat | aggressive | - | 38.2% of land, L14 |  |
| mangy_rat | Burrow Gnawer | aggressive | - | 57.2% of land, L15-20 |  |
| muttering_husk | Cairn Sun-Dried Husk | aggressive | - | 2.1% of land, L11-15 |  |
| parched_husk | Pauper Mummy | aggressive | 10.2% of land, L18-20 | 29.9% of land, L16-20 |  |
| quarrelsome_bandit | Roadside Bandit | aggressive | - | 28.5% of land, L11-13 |  |
| reefclaw_crab | Reefclaw Snapper | aggressive | 0.7% of land, L15-17 | - |  |
| shore_crab | Shore Crab | neutral | 11280 nodes², L11-15 | 11280 nodes², L11-15 | sand (dry, within 6 nodes of water) |
| tidepool_crab | Tidepool Crab | neutral | 2.1% of land, L11-14 | - |  |
| vigilant_bandit_archer | Bandit Lookout | aggressive | 2.0% of land, L18-20 | 2.0% of land, L18-20 |  |
| watchful_zebra | Waterhole Zebra | neutral | 85.7% of land, L11-20 | - |  |

**Camps and guard posts:**

- anchor_041 Redtusk Outpost at 176, 2074: guard post, guard_throng × 2-3, respawn 180-360 s, level there L15.
- anchor_057 Redtusk Bandit Camp at 320, 1980: bandit, bandit/bandit_archer × 3-5, respawn 30-60 s, level there L16.

**Rares (knowledge rewards, not quest targets):** Ashmaw (boar, the savanna, route 104,2060 → 168,2124 → 208,2068, L15, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 18 | primary | anchor_005 (Sunscar, kragmar_sunscar_flats) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 799 / 450 | -112,2261 → -102,1835 |
| 20 | secondary | anchor_021 (Redtusk Village, kragmar_redtusk_savanna) | joins road 18 | 84 / 86 | -82,1988 → -108,1920 |
| 44 | trail | anchor_041 (Redtusk Outpost, kragmar_redtusk_savanna) | joins road 18 | 486 / 186 | 180,2084 → 198,2253 |
| 58 | trail | anchor_057 (Redtusk Bandit Camp, kragmar_redtusk_savanna) | joins road 16 | 349 / 128 | 328,1965 → 327,1844 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

