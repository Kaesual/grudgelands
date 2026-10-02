# Whispering Reedlands (`kragmar_whispering_reedlands`)

Zone 30 · home zone 21-30 · throng · race region **troll** · levels **21-30** · peaceful · relief `wetland_delta` · seed 42

Map: [maps/kragmar_whispering_reedlands.png](maps/kragmar_whispering_reedlands.png). Machine-readable: [kragmar_whispering_reedlands.json](kragmar_whispering_reedlands.json). Coordinates are world nodes (x east, z north, y up).

Race track (troll): step 4 of the track Kapok Cradle → Raincall Basin → Kezamba → Whispering Reedlands → Totemwater Reach → Thunderroot Wilds.

**Front:** Battlegrounds lie south (-z); the home coast/ocean is north (+z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x 488..1412, z 940..2156 (centroid 932, 1519) |
| Land area | 744800 nodes² (≈ 0.74 km²) |
| Hub point (authored) | 900, 1500 |
| Height above sea | min 0, p10 5, median 22, p90 53, max 84 |
| Slope | 0.2% steep (>1 node/node), 0.0% cliff (>2) |
| Biomes (measured) | jungle_edge 46.9%, swamp 26.5%, deep_jungle 25.5%, savanna 0.8%, badlands 0.2%, badlands_east 0.1% |
| Neighbours (land border) | kragmar_bannerbreak_mesa (664 nodes, mid 699,1070), kragmar_gor_drazhak (760 nodes, mid 514,1505), kragmar_kezamba (1036 nodes, mid 1326,1472), kragmar_raincall_basin (520 nodes, mid 1190,2036), kragmar_redtusk_savanna (428 nodes, mid 624,1955), kragmar_thunderroot_wilds (736 nodes, mid 1143,1027) |
| Sea coast | 824 nodes of coastline; sea-beach sand 21648 nodes²; lake/river-bank sand 27664 nodes² |
| Water inside | bay 59664 nodes², rivers/lakes 32800 nodes² |
| Protected / drift band | 1.9% of land protected (towns, villages, camps/POIs, road corridors); 6.6% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 786, 2007 | x 708..916, z 1896..2112 | 12864 | L21-22 |
| B2 | 1002, 2046 | x 928..1080, z 1912..2152 | 8528 | L21-22 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L21 8.9%, L22 10.3%, L23 11.0%, L24 11.3%, L25 10.3%, L26 11.3%, L27 8.8%, L28 9.5%, L29 9.0%, L30 9.7%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_024 | village | Whisperreed Landing | 876 | 11 | 1604 | 24 | village x 864..887, z 1592..1615 |
| anchor_046 | outpost | Reedvoice Station | 682 | 44 | 1234 | 28 | poi x 674..689, z 1226..1241 |
| anchor_066 | mine | Reedstone Cut | 1026 | 26 | 1304 | 27 | poi x 1016..1035, z 1294..1313 |
| anchor_070 | mirefolk camp | Hushwater Nests | 1096 | 20 | 1764 | 23 | camp x 1088..1103, z 1756..1771 |

## Protected areas

- village Whisperreed Landing (anchor_024): x 864..887, z 1592..1615
- poi Reedvoice Station (anchor_046): x 674..689, z 1226..1241
- poi Reedstone Cut (anchor_066): x 1016..1035, z 1294..1313
- camp Hushwater Nests (anchor_070): x 1088..1103, z 1756..1771
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Whisperreed Landing (`r20_anchor_024`, anchor_024) at 876, 11, 1604

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Taleko Drycord | 878, 12, 1604 | r20_anchor_024_01, r20_anchor_024_02, r20_anchor_024_03, r20_troll_journey_02 |

Distances: zone edge N 352 (coastal_shelf), S 644 (kragmar_bannerbreak_mesa), E 396 (kragmar_kezamba), W 368 (kragmar_gor_drazhak); nearest other-zone land 357 W; sea 337 N; sea-beach sand 283 N; nearest road 15.
Nearest hubs (straight / by road): Reedstone Cut 335 / 787; Raincall Bandit Camp 870 / 1062; Redtusk Bandit Camp 671 / 1120; Reedvoice Station 418 / 1184; Kezamba 930 / 1244.

### Reedvoice Station (`r20_anchor_046`, anchor_046) at 682, 44, 1234

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Enashi Reedvoice | 684, 45, 1234 | r20_anchor_046_01, r20_anchor_046_02, r20_anchor_046_03 |

Distances: zone edge N 804 (kragmar_redtusk_savanna), S 144 (kragmar_bannerbreak_mesa), E 700 (kragmar_kezamba), W 184 (kragmar_gor_drazhak); nearest other-zone land 122 SW; sea 739 N; sea-beach sand 692 N; nearest road 11.
Nearest hubs (straight / by road): Redtusk Bandit Camp 829 / 1001; Whisperreed Landing 418 / 1184; Gor Drazhak 732 / 1267; Redtusk Village 1089 / 1526; Reedstone Cut 351 / 1726.

### Reedstone Cut (`r20_anchor_066`, anchor_066) at 1026, 26, 1304

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_host | quest giver | Zali Runoff | 1028, 27, 1304 | r20_anchor_066_01, r20_anchor_066_02, r20_anchor_066_03, r20_troll_journey_03 |

Distances: zone edge N 808 (bay_water), S 308 (kragmar_thunderroot_wilds), E 332 (kragmar_kezamba), W 528 (kragmar_gor_drazhak); nearest other-zone land 258 SE; sea 646 N; sea-beach sand 580 N; nearest road 18.
Nearest hubs (straight / by road): Whisperreed Landing 335 / 787; Raincall Bandit Camp 949 / 1202; Kezamba 798 / 1384; Redtusk Bandit Camp 977 / 1662; Reedvoice Station 351 / 1726.

### Current quests (11, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| r20_anchor_024_01 | A Landing That Holds | Taleko Drycord (Whisperreed Landing) | 21 | bring 8 default:junglewood | 820 | - |
| r20_anchor_024_02 | Tapirs on the Dry Path | Taleko Drycord (Whisperreed Landing) | 21 | kill 4 tapir or reed_tapir [in kragmar_whispering_reedlands] | 820 | - |
| r20_anchor_046_01 | A Dry Signal Shelf | Enashi Reedvoice (Reedvoice Station) | 21 | bring 8 default:junglewood | 820 | - |
| r20_anchor_046_02 | Cats by the Reed Pipes | Enashi Reedvoice (Reedvoice Station) | 21 | kill 4 jungle_lynx [in kragmar_whispering_reedlands] | 820 | - |
| r20_anchor_066_01 | Timbers Kept Above Water | Zali Runoff (Reedstone Cut) | 21 | bring 8 default:junglewood | 820 | - |
| r20_anchor_066_02 | The Quarry Pool Moves | Zali Runoff (Reedstone Cut) | 21 | kill 4 bog_ooze [in kragmar_whispering_reedlands] | 820 | - |
| r20_anchor_024_03 | Cold Lights in the Reeds | Taleko Drycord (Whisperreed Landing) | 23 | kill 3 wisp or wandering_wisp [in kragmar_whispering_reedlands] | 900 | r20_anchor_024_02 |
| r20_anchor_046_03 | The False Answering Lights | Enashi Reedvoice (Reedvoice Station) | 23 | kill 3 wisp or wandering_wisp [in kragmar_whispering_reedlands] | 900 | r20_anchor_046_02 |
| r20_anchor_066_03 | Jaws Along the Haul Path | Zali Runoff (Reedstone Cut) | 23 | kill 3 crocodile [in kragmar_whispering_reedlands] | 900 | r20_anchor_066_02 |
| r20_troll_journey_02 | Word for Zali Runoff | Taleko Drycord (Whisperreed Landing) | 24 | talk to Zali Runoff (r20_anchor_066) | 705 | - |
| r20_troll_journey_03 | Word for Rumela Stormstep | Zali Runoff (Reedstone Cut) | 31 | talk to Rumela Stormstep (r20_anchor_048) | 915 | - |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bank_crab | Bank Crab | neutral | 1.7% of land, L21-23 | - |  |
| reed_crocodile | Reed Crocodile | aggressive | 13.1% of land, L24-30 | 75.5% of land, L21-30 |  |
| reed_jungle_lynx | Reed Jungle Lynx | aggressive | 60.6% of land, L21-30 | - |  |
| reed_tapir | Reed Tapir | neutral | 21.4% of land, L21-23 | - |  |
| shore_crab | Shore Crab | neutral | 21648 nodes², L21-22 | 21648 nodes², L21-22 | sand (dry, within 6 nodes of water) |
| sullen_bog_ooze | Bubbling Bog Ooze | aggressive | 21.8% of land, L21-30 | 61.0% of land, L21-30 |  |
| toll_mirefolk | Toll Mirefolk | aggressive | 2.7% of land, L21-30 | 2.7% of land, L21-30 |  |
| wandering_wisp | Wandering Wisp | aggressive | - | 28.3% of land, L21-23 |  |

**Camps and guard posts:**

- anchor_046 Reedvoice Station at 682, 1234: guard post, guard_throng × 2-3, respawn 180-360 s, level there L28.
- anchor_070 Hushwater Nests at 1096, 1764: mirefolk camp, EMPTY today: no camp fire is placed (anchor roster lists only capital, outpost and bandit populations) (level there L23).

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 16 | primary | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | anchor_012 (Kezamba, kragmar_kezamba) | 1364 / 826 | 523,1671 → 1292,1771 |
| 25 | secondary | anchor_024 (Whisperreed Landing, kragmar_whispering_reedlands) | joins road 16 | 108 / 110 | 878,1619 → 927,1714 |
| 48 | trail | anchor_046 (Reedvoice Station, kragmar_whispering_reedlands) | joins road 16 | 522 / 206 | 671,1231 → 510,1342 |
| 67 | trail | anchor_066 (Reedstone Cut, kragmar_whispering_reedlands) | joins road 16 | 446 / 440 | 1038,1317 → 1116,1702 |
| 71 | trail | anchor_070 (Hushwater Nests, kragmar_whispering_reedlands) | joins road 16 | 87 / 90 | 1086,1756 → 1037,1688 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

