# Raincall Basin (`kragmar_raincall_basin`)

Zone 28 · home zone 11-20 · throng · race region **troll** · levels **11-20** · peaceful · relief `rolling_hills` · seed 42

Map: [maps/kragmar_raincall_basin.png](maps/kragmar_raincall_basin.png). Machine-readable: [kragmar_raincall_basin.json](kragmar_raincall_basin.json). Coordinates are world nodes (x east, z north, y up).

Race track (troll): step 2 of the track Kapok Cradle → Raincall Basin → Kezamba → Whispering Reedlands → Totemwater Reach → Thunderroot Wilds.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 1056..2496, z 1772..2340 (centroid 1732, 2096) |
| Land area | 492352 nodes² (≈ 0.49 km²) |
| Hub point (authored) | 1800, 2050 |
| Height above sea | min 0, p10 24, median 60, p90 89, max 143 |
| Slope | 6.0% steep (>1 node/node), 0.1% cliff (>2) |
| Biomes (measured) | jungle_edge 60.7%, deep_jungle 21.7%, swamp 17.6% |
| Neighbours (land border) | kragmar_kapok_cradle (1528 nodes, mid 1883,2282), kragmar_kezamba (996 nodes, mid 1730,1856), kragmar_totemwater_reach (792 nodes, mid 2297,1985), kragmar_whispering_reedlands (516 nodes, mid 1187,2031) |
| Sea coast | 372 nodes of coastline; sea-beach sand 4464 nodes²; lake/river-bank sand 15104 nodes² |
| Water inside | bay 13232 nodes², rivers/lakes 13552 nodes² |
| Protected / drift band | 2.7% of land protected (towns, villages, camps/POIs, road corridors); 9.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 1177, 2254 | x 1096..1236, z 2216..2308 | 3856 | L11-13 |
| B2 | 1066, 2176 | x 1056..1076, z 2148..2204 | 592 | L13-14 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L11 8.8%, L12 11.1%, L13 13.6%, L14 14.4%, L15 12.6%, L16 11.2%, L17 7.4%, L18 8.0%, L19 7.2%, L20 5.6%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_023 | village | Raincall Village | 1876 | 73 | 2044 | 16 | village x 1864..1887, z 2032..2055 |
| anchor_045 | outpost | Raincall Outpost | 2132 | 70 | 2084 | 15 | poi x 2124..2139, z 2076..2091 |
| anchor_059 | bandit camp | Raincall Bandit Camp | 1632 | 61 | 2034 | 16 | camp x 1620..1643, z 2022..2045 |

## Protected areas

- village Raincall Village (anchor_023): x 1864..1887, z 2032..2055
- poi Raincall Outpost (anchor_045): x 2124..2139, z 2076..2091
- camp Raincall Bandit Camp (anchor_059): x 1620..1643, z 2022..2045
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Raincall Village (`raincall_village`, anchor_023) at 1876, 73, 2044

Residents/guards: idle 2, quest 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_steward | quest giver | Daro Kapok | 1878, 74, 2044 | raincall_bounty_village, raincall_rains_01, raincall_rains_02, raincall_rains_03, raincall_rains_04 |
| quest_local | quest giver | Amari Palmweave | 1874, 74, 2042 | raincall_weave_01, raincall_weave_02, raincall_weave_03, raincall_weave_04 |

Distances: zone edge N 272 (kragmar_kapok_cradle), S 192 (kragmar_kezamba), E 424 (kragmar_totemwater_reach), W 688 (kragmar_whispering_reedlands); nearest other-zone land 188 S; sea 645 NE; sea-beach sand 618 NE; nearest road 16.
Nearest hubs (straight / by road): Raincall Outpost 259 / 422; Kapok 512 / 707; Raincall Bandit Camp 244 / 1191; Kezamba 549 / 1741; Whisperreed Landing 1093 / 1796.

### Raincall Outpost (`raincall_outpost`, anchor_045) at 2132, 70, 2084

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_scout | quest giver | Neshi Reedstep | 2135, 71, 2081 | raincall_bounty_outpost, raincall_watch_01, raincall_watch_02, raincall_watch_03, raincall_watch_04 |

Distances: zone edge N 164 (kragmar_kapok_cradle), S 316 (kragmar_kezamba), E 232 (kragmar_totemwater_reach), W 984 (kragmar_whispering_reedlands); nearest other-zone land 164 N; sea 411 NE; sea-beach sand 383 NE; nearest road 11.
Nearest hubs (straight / by road): Raincall Village 259 / 422; Kapok 572 / 945; Raincall Bandit Camp 502 / 1429; Kezamba 672 / 1979; Whisperreed Landing 1345 / 2034.

### Raincall Bandit Camp (`raincall_bandit_camp`, anchor_059) at 1632, 61, 2034

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_captive | quest giver | Veko Bluefeather | 1642, 62, 2044 | raincall_departure, raincall_tithe_01 |

Distances: zone edge N 292 (kragmar_kapok_cradle), S 144 (kragmar_kezamba), E 672 (kragmar_totemwater_reach), W 432 (kragmar_whispering_reedlands); nearest other-zone land 141 S; sea 494 NW; sea-beach sand 466 NW; nearest road 17.
Nearest hubs (straight / by road): Kezamba 560 / 1008; Whisperreed Landing 870 / 1062; Kapok 543 / 1089; Raincall Village 244 / 1191; Reedstone Cut 949 / 1202.

### Current quests (16, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| raincall_rains_01 | A Garden Is No Wallow | Daro Kapok (Raincall Village) | 10 | kill 8 reed_tapir [in kragmar_raincall_basin/rainwood] | 320 | kapok_departure |
| raincall_rains_02 | Mind Where the Path Hisses | Daro Kapok (Raincall Village) | 11 | kill 8 reed_fang_viper [in kragmar_raincall_basin/rainwood] | 340 | raincall_rains_01 |
| raincall_weave_01 | Capes Before the Downpour | Amari Palmweave (Raincall Village) | 11 | bring 3 mobs:leather | 213 | kapok_departure |
| raincall_rains_03 | The Rain Owes You Nothing | Daro Kapok (Raincall Village) | 12 | kill 6 quarrelsome_bandit [in kragmar_raincall_basin/rainwood] | 360 | raincall_rains_02 |
| raincall_rains_04 | Let the Scouts Hear It | Daro Kapok (Raincall Village) | 13 | talk to Neshi Reedstep (raincall_outpost) | 95 | raincall_rains_03 |
| raincall_weave_02 | Houses Should Not Bow | Amari Palmweave (Raincall Village) | 13 | bring 4 grug_materials:iron_bar; bring 4 default:coal_lump | 285 | raincall_weave_01 |
| raincall_watch_01 | A Trail with Claws | Neshi Reedstep (Raincall Outpost) | 14 | kill 8 reed_jungle_lynx [in kragmar_raincall_basin/cloudwood] | 450 | raincall_rains_04 |
| raincall_watch_02 | Someone Ate the Trail | Neshi Reedstep (Raincall Outpost) | 15 | kill 8 mangy_rat [in kragmar_raincall_basin/cloudwood] | 473 | raincall_watch_01 |
| raincall_weave_03 | Claws at the Loom | Amari Palmweave (Raincall Village) | 15 | bring 2 grug_mobs:hooked_cat_claw | 315 | raincall_weave_02 |
| raincall_bounty_village | Bounty: Claws Above the Gardens (repeatable) | Daro Kapok (Raincall Village) | 17 | kill 6 reed_jungle_lynx [in kragmar_raincall_basin/highwood] | 300 | raincall_rains_04 |
| raincall_watch_03 | Eyes on the Bowstrings | Neshi Reedstep (Raincall Outpost) | 17 | kill 8 vigilant_bandit_archer [in kragmar_raincall_basin/bandit_camp] | 518 | raincall_watch_02 |
| raincall_weave_04 | Our Tithe, Their Shirts | Amari Palmweave (Raincall Village) | 17 | bring 3 grug_mobs:linen_cloth | 288 | raincall_weave_03 |
| raincall_bounty_outpost | Bounty: Teeth on the Ropes (repeatable) | Neshi Reedstep (Raincall Outpost) | 18 | kill 8 mangy_rat [in kragmar_raincall_basin/highwood] | 300 | raincall_watch_03 |
| raincall_tithe_01 | Vek Can Keep the Bill | Veko Bluefeather (Raincall Bandit Camp) | 18 | kill 1 tithe_keeper_vek | 720 | raincall_watch_04 |
| raincall_watch_04 | A Voice Behind the Bows | Neshi Reedstep (Raincall Outpost) | 18 | talk to Veko Bluefeather (raincall_bandit_camp) | 115 | raincall_watch_03 |
| raincall_departure | News Too Good to Whisper | Veko Bluefeather (Raincall Bandit Camp) | 19 | talk to Nalo Pathdrum (kezamba) | 180 | raincall_tithe_01 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bristling_boar | Ridgeback Tusker | aggressive | 67.6% of land, L15-20 | - |  |
| granary_rat | Granary Rat | aggressive | - | 29.9% of land, L14 |  |
| mangy_rat | Burrow Gnawer | aggressive | - | 48.7% of land, L15-20 |  |
| moaning_zombie | Cairn Zombie | aggressive | - | 18.7% of land, L11-15 |  |
| muttering_zombie | Pauper Shambler | aggressive | - | 37.7% of land, L16-20 |  |
| quarrelsome_bandit | Roadside Bandit | aggressive | - | 19.6% of land, L11-13 |  |
| reed_fang_viper | Reed-Fang Viper | aggressive | - | 19.6% of land, L11-13 |  |
| reed_jungle_lynx | Reed Jungle Lynx | aggressive | 53.6% of land, L14-20 | - |  |
| reed_tapir | Reed Tapir | neutral | 29.9% of land, L11-13 | - |  |
| shore_crab | Shore Crab | neutral | 4464 nodes², L11-14 | 4464 nodes², L11-14 | sand (dry, within 6 nodes of water) |
| vigilant_bandit_archer | Bandit Lookout | aggressive | 2.4% of land, L18-20 | 2.4% of land, L18-20 |  |
| young_boar | Rooting Boar | neutral | 33.4% of land, L11-14 | - |  |

**Camps and guard posts:**

- anchor_045 Raincall Outpost at 2132, 2084: guard post, guard_throng × 2-3, respawn 180-360 s, level there L15.
- anchor_059 Raincall Bandit Camp at 1632, 2034: bandit, bandit/bandit_archer × 3-5, respawn 30-60 s, level there L16.

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 19 | primary | anchor_006 (Kapok, kragmar_kapok_cradle) | joins road 16 | 984 / 486 | 1513,2333 → 1406,1886 |
| 22 | secondary | anchor_023 (Raincall Village, kragmar_raincall_basin) | joins road 19 | 389 / 364 | 1873,2060 → 1638,2324 |
| 30 | secondary | anchor_012 (Kezamba, kragmar_kezamba) | anchor_023 (Raincall Village, kragmar_raincall_basin) | 352 / 216 | 1764,1863 → 1860,2039 |
| 47 | trail | anchor_045 (Raincall Outpost, kragmar_raincall_basin) | joins road 22 | 321 / 318 | 2121,2082 → 1822,2108 |
| 60 | trail | anchor_059 (Raincall Bandit Camp, kragmar_raincall_basin) | joins road 19 | 212 / 214 | 1617,2026 → 1434,1938 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

