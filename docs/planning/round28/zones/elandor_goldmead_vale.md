# Goldmead Vale (`elandor_goldmead_vale`)

Zone 7 · home zone 11-20 · accord · race region **human** · levels **11-20** · peaceful · relief `lowland` · seed 42

Map: [maps/elandor_goldmead_vale.png](maps/elandor_goldmead_vale.png). Machine-readable: [elandor_goldmead_vale.json](elandor_goldmead_vale.json). Coordinates are world nodes (x east, z north, y up).

Race track (human): step 2 of the track Dawnmere Fields → Goldmead Vale → Highcourt → Whitebridge Shire → Ashenward March.

**Front:** Battlegrounds lie north (+z); the home coast/ocean is south (-z).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -796..640, z -2344..-1656 (centroid -71, -2053) |
| Land area | 572272 nodes² (≈ 0.57 km²) |
| Hub point (authored) | 0, -2050 |
| Height above sea | min 0, p10 19, median 35, p90 65, max 119 |
| Slope | 2.6% steep (>1 node/node), 0.1% cliff (>2) |
| Biomes (measured) | meadows 68.7%, deep_forest 23.1%, swamp 8.0%, elf_forest 0.2% |
| Neighbours (land border) | elandor_dawnmere_fields (1484 nodes, mid -163,-2299), elandor_highcourt (1456 nodes, mid -24,-1812), elandor_lorindor (464 nodes, mid 565,-1796), elandor_whitebridge_shire (588 nodes, mid -665,-2031) |
| Sea coast | 596 nodes of coastline; sea-beach sand 16288 nodes²; lake/river-bank sand 9584 nodes² |
| Water inside | bay 21008 nodes², rivers/lakes 10288 nodes² |
| Protected / drift band | 2.0% of land protected (towns, villages, camps/POIs, road corridors); 6.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | 502, -2058 | x 380..640, z -2200..-1940 | 14544 | L12-17 |
| B2 | -779, -2250 | x -796..-760, z -2284..-2212 | 1248 | L11-12 |
| B3 | -737, -2177 | x -748..-728, z -2188..-2164 | 400 | L12-13 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L11 12.1%, L12 10.8%, L13 11.1%, L14 12.2%, L15 12.6%, L16 12.1%, L17 9.5%, L18 8.3%, L19 5.9%, L20 5.3%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_015 | village | Goldmead Village | -120 | 37 | -2020 | 15 | village x -132..-109, z -2032..-2009 |
| anchor_029 | outpost | Goldmead Outpost | 176 | 53 | -2026 | 15 | poi x 168..183, z -2034..-2019 |
| anchor_051 | bandit camp | Goldmead Bandit Camp | 320 | 57 | -1980 | 16 | camp x 308..331, z -1992..-1969 |
| anchor_091 | rare route | Grimtusk's Rooting | 152 | 73 | -2116 | 14 | poi x 146..157, z -2122..-2111 |

## Protected areas

- village Goldmead Village (anchor_015): x -132..-109, z -2032..-2009
- poi Goldmead Outpost (anchor_029): x 168..183, z -2034..-2019
- camp Goldmead Bandit Camp (anchor_051): x 308..331, z -1992..-1969
- poi Grimtusk's Rooting (anchor_091): x 146..157, z -2122..-2111
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

### Goldmead Village (`goldmead_village`, anchor_015) at -120, 37, -2020

Residents/guards: idle 2, quest 2.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_steward | quest giver | Marta Millward | -118, 38, -2020 | goldmead_harvest_01, goldmead_harvest_02, goldmead_harvest_03, goldmead_harvest_04, goldmead_supplies_01, goldmead_supplies_02 |
| quest_local | quest giver | Alda Sheaf | -122, 38, -2022 | goldmead_bounty_rats, goldmead_stores_01, goldmead_stores_02 |

Distances: zone edge N 136 (elandor_highcourt), S 304 (elandor_dawnmere_fields), E 700 (coastal_shelf), W 532 (elandor_whitebridge_shire); nearest other-zone land 136 N; sea 563 E; sea-beach sand 526 E; nearest road 16.
Nearest hubs (straight / by road): Highcourt 534 / 880; Goldmead Bandit Camp 442 / 1037; Goldmead Outpost 296 / 1076; Dawnmere 543 / 1576; Petalbank Wardenry 1089 / 1687.

### Goldmead Outpost (`goldmead_outpost`, anchor_029) at 176, 53, -2026

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_scout | quest giver | Jon Vale | 179, 54, -2029 | goldmead_bounty_bandits, goldmead_watch_01, goldmead_watch_02, goldmead_watch_03 |

Distances: zone edge N 208 (elandor_highcourt), S 260 (elandor_dawnmere_fields), E 400 (coastal_shelf), W 832 (elandor_whitebridge_shire); nearest other-zone land 194 N; sea 291 SE; sea-beach sand 242 E; nearest road 11.
Nearest hubs (straight / by road): Goldmead Bandit Camp 151 / 522; Dawnmere 553 / 686; Highcourt 555 / 866; Goldmead Village 296 / 1076; Petalbank Wardenry 918 / 1673.

### Goldmead Bandit Camp (`goldmead_bandit_camp`, anchor_051) at 320, 57, -1980

Residents/guards: quest 1.

| Socket | Role | Who / what | Position | Quests given |
|---|---|---|---|---|
| quest_captive | quest giver | Pella Thatch | 330, 58, -1970 | goldmead_departure, goldmead_testimony_01, goldmead_testimony_02 |

Distances: zone edge N 204 (elandor_highcourt), S 224 (elandor_dawnmere_fields), E 312 (coastal_shelf), W 952 (elandor_whitebridge_shire); nearest other-zone land 188 NW; sea 206 SE; sea-beach sand 151 SE; nearest road 18.
Nearest hubs (straight / by road): Goldmead Outpost 151 / 522; Highcourt 577 / 828; Dawnmere 654 / 1022; Goldmead Village 442 / 1037; Petalbank Wardenry 814 / 1635.

### Current quests (16, given in this zone)

| Id | Title | Giver | Min L | Objectives | XP | Needs |
|---|---|---|---|---|---|---|
| goldmead_harvest_01 | A Harvest Worth Stealing | Marta Millward (Goldmead Village) | 9 | kill 8 young_fox [in elandor_goldmead_vale/orchards] | 280 | dawnmere_departure |
| goldmead_stores_01 | Feed the Counters | Alda Sheaf (Goldmead Village) | 10 | bring 8 mobs:meat_raw | 160 | dawnmere_departure |
| goldmead_harvest_02 | The Granary Has Teeth | Marta Millward (Goldmead Village) | 11 | kill 8 granary_rat [in elandor_goldmead_vale/orchards] | 298 | goldmead_harvest_01 |
| goldmead_supplies_01 | Iron Before Promises | Marta Millward (Goldmead Village) | 12 | bring 6 grug_materials:iron_bar; bring 4 default:coal_lump | 285 | goldmead_harvest_01 |
| goldmead_harvest_03 | Tusks in the Wheat | Marta Millward (Goldmead Village) | 13 | kill 8 bristling_boar [in elandor_goldmead_vale/wheatfields] | 400 | goldmead_harvest_02 |
| goldmead_harvest_04 | Jon Has the Other Half | Marta Millward (Goldmead Village) | 13 | talk to Jon Vale (goldmead_outpost) | 95 | goldmead_harvest_02 |
| goldmead_watch_01 | Collectors Without a Collection | Jon Vale (Goldmead Outpost) | 14 | kill 8 quarrelsome_bandit [in elandor_goldmead_vale/bandit_camp] | 420 | goldmead_harvest_04 |
| goldmead_supplies_02 | Counted and Sealed | Marta Millward (Goldmead Village) | 15 | bring 4 grug_materials:iron_bar; bring 6 group:wood | 330 | goldmead_supplies_01 |
| goldmead_watch_02 | Teeth Along the Cart Track | Jon Vale (Goldmead Outpost) | 15 | kill 6 rabid_fox [in elandor_goldmead_vale/thickets] | 368 | goldmead_watch_01 |
| goldmead_stores_02 | Cloth Around the Truth | Alda Sheaf (Goldmead Village) | 16 | bring 2 grug_mobs:linen_cloth | 275 | goldmead_stores_01, goldmead_watch_01 |
| goldmead_bounty_bandits | Bounty: Roadside Bandits (repeatable) | Jon Vale (Goldmead Outpost) | 17 | kill 8 quarrelsome_bandit [in elandor_goldmead_vale/bandit_camp] | 220 | goldmead_watch_03 |
| goldmead_testimony_01 | Nobody Requisitions Pella | Pella Thatch (Goldmead Bandit Camp) | 17 | kill 8 vigilant_bandit_archer [in elandor_goldmead_vale/requisition_camp] | 460 | goldmead_watch_03 |
| goldmead_watch_03 | A Witness, Not Cargo | Jon Vale (Goldmead Outpost) | 17 | talk to Pella Thatch (goldmead_bandit_camp) | 110 | goldmead_watch_02 |
| goldmead_bounty_rats | Bounty: Burrow Gnawers (repeatable) | Alda Sheaf (Goldmead Village) | 18 | kill 8 mangy_rat [in elandor_goldmead_vale/hedgerows] | 240 | goldmead_harvest_03 |
| goldmead_testimony_02 | Hobb's Last Requisition | Pella Thatch (Goldmead Bandit Camp) | 18 | kill 1 requisitioner_hobb | 600 | goldmead_testimony_01 |
| goldmead_departure | Highcourt Must Hear This | Pella Thatch (Goldmead Bandit Camp) | 19 | talk to Mariel Waybook (highcourt) | 120 | goldmead_testimony_02 |

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| bristling_boar | Ridgeback Tusker | aggressive | 49.4% of land, L15-20 | - |  |
| granary_rat | Granary Rat | aggressive | - | 41.0% of land, L11-14 |  |
| mangy_rat | Burrow Gnawer | aggressive | - | 42.8% of land, L15-20 |  |
| moaning_zombie | Cairn Zombie | aggressive | - | 26.3% of land, L11-15 |  |
| muttering_zombie | Pauper Shambler | aggressive | - | 23.5% of land, L16-20 |  |
| quarrelsome_bandit | Roadside Bandit | aggressive | 2.1% of land, L14-15 | 2.1% of land, L14-15 |  |
| rabid_fox | Thicket Vixen | aggressive | 16.9% of land, L15-20 | - |  |
| shore_crab | Shore Crab | neutral | 16288 nodes², L11-17 | 16288 nodes², L11-17 | sand (dry, within 6 nodes of water) |
| snaring_poacher | Snaring Poacher | aggressive | - | 19.0% of land, L11-13 |  |
| vigilant_bandit_archer | Bandit Lookout | aggressive | 3.7% of land, L16-20 | 3.7% of land, L16-20 |  |
| young_boar | Rooting Boar | neutral | 67.3% of land, L11-14 | - |  |
| young_fox | Bracken Fox | neutral | 30.1% of land, L11-13 | - |  |

**Camps and guard posts:**

- anchor_029 Goldmead Outpost at 176, -2026: guard post, guard_accord × 2-3, respawn 180-360 s, level there L15.
- anchor_051 Goldmead Bandit Camp at 320, -1980: bandit, bandit/bandit_archer × 3-5, respawn 30-60 s, level there L16.

**Rares (knowledge rewards, not quest targets):** Grimtusk (boar, the central meadows, route 104,-2140 → 168,-2076 → 208,-2132, L13, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 4 | primary | anchor_002 (Dawnmere, elandor_dawnmere_fields) | anchor_008 (Highcourt, elandor_highcourt) | 796 / 528 | -14,-2317 → 132,-1835 |
| 7 | secondary | anchor_015 (Goldmead Village, elandor_goldmead_vale) | anchor_008 (Highcourt, elandor_highcourt) | 277 / 134 | -115,-2005 → -158,-1886 |
| 35 | trail | anchor_029 (Goldmead Outpost, elandor_goldmead_vale) | joins road 4 | 83 / 84 | 166,-2030 → 88,-2012 |
| 52 | trail | anchor_051 (Goldmead Bandit Camp, elandor_goldmead_vale) | joins road 4 | 225 / 222 | 306,-1969 → 131,-1839 |
| 68 | trail | anchor_067 (Siltbasket Camp, elandor_whitebridge_shire) | joins road 7 | 500 / 380 | -511,-1827 → -160,-1920 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

