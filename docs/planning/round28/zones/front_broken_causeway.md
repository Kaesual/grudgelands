# The Broken Causeway (`front_broken_causeway`)

Zone 35 · front zone · contested · race region **human** · levels **41-50** · contested · relief `wetland_delta` · seed 42

Map: [maps/front_broken_causeway.png](maps/front_broken_causeway.png). Machine-readable: [front_broken_causeway.json](front_broken_causeway.json). Coordinates are world nodes (x east, z north, y up).

**Front:** Battlegrounds band around z = 0: Accord comes from -z (south), Throng from +z (north).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -1528..36, z -684..536 (centroid -712, -48) |
| Land area | 1153664 nodes² (≈ 1.15 km²) |
| Hub point (authored) | -750, 0 |
| Height above sea | min 19, p10 31, median 73, p90 154, max 381 |
| Slope | 14.2% steep (>1 node/node), 2.4% cliff (>2) |
| Biomes (measured) | meadows 41.6%, swamp 39.4%, deep_forest 17.3%, badlands 0.7%, bone_forest 0.4%, crags 0.3%, blight 0.1%, savanna 0.1%, crags_snowy 0.0%, beach 0.0% |
| Neighbours (land border) | elandor_ashenward_march (1268 nodes, mid -435,-477), elandor_stormvault_heights (1064 nodes, mid -1164,-471), front_gravesalt_escarpment (1136 nodes, mid -1386,15), front_shattered_line (1004 nodes, mid 15,38), kragmar_bannerbreak_mesa (1372 nodes, mid -442,415), kragmar_blackwind_rise (420 nodes, mid -1077,489) |
| Sea coast | 0 nodes of coastline; sea-beach sand 0 nodes²; lake/river-bank sand 36624 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 104896 nodes² |
| Protected / drift band | 1.2% of land protected (towns, villages, camps/POIs, road corridors); 4.8% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L41 9.5%, L42 8.4%, L43 10.2%, L44 12.7%, L45 11.9%, L46 12.1%, L47 8.3%, L48 9.4%, L49 8.5%, L50 8.9%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_078 | clash site | Causeway Toll Ruin | -1274 | 95 | -76 | 50 | poi x -1282..-1267, z -84..-69 |
| anchor_079 | clash site | Fordward Wreck | -774 | 28 | 124 | 46 | poi x -782..-767, z 116..131 |
| anchor_080 | clash site | Aqueduct Last Step | -274 | 54 | -76 | 50 | poi x -282..-267, z -84..-69 |
| anchor_099 | rare route | Bonerattle's Broken Toll | -568 | 29 | 64 | 48 | poi x -574..-563, z 58..69 |

## Protected areas

- poi Causeway Toll Ruin (anchor_078): x -1282..-1267, z -84..-69
- poi Fordward Wreck (anchor_079): x -782..-767, z 116..131
- poi Aqueduct Last Step (anchor_080): x -282..-267, z -84..-69
- poi Bonerattle's Broken Toll (anchor_099): x -574..-563, z 58..69
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

No quest is given in this zone today.

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| causeway_aqueduct_bowman | Aqueduct Bowman | aggressive | 17.7% of land, L44-50 | 13.5% of land, L44-50 |  |
| causeway_brigand | Causeway Brigand | aggressive | 22.1% of land, L41-50 | 3.5% of land, L41-50 |  |
| causeway_fenrunner_wolf | Fenrunner Wolf | aggressive | - | 23.8% of land, L41-50 |  |
| causeway_ford_zombie | Fordwater Zombie | aggressive | - | 75.4% of land, L41-50 |  |
| causeway_mire_husk | Mire-Cured Husk | aggressive | 79.6% of land, L41-50 | - |  |
| causeway_sinkmire_viper | Sinkmire Viper | aggressive | 38.3% of land, L41-50 | 48.1% of land, L41-50 |  |
| causeway_toll_skeleton | Tollroad Skeleton | aggressive | - | 35.7% of land, L41-50 |  |
| gull | Gull | critter | 192 nodes² | - | sand |
| watchful_carrion_crow | Battlefield Crow | neutral | 42.3% of land, L41-50 | - |  |

**Rares (knowledge rewards, not quest targets):** Captain Bonerattle (skeleton_raider, the war coast, route -616,40 → -552,104 → -512,48, L48, respawn 2-4 h)

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 29 | primary | anchor_008 (Highcourt, elandor_highcourt) | anchor_011 (Gor Drazhak, kragmar_gor_drazhak) | 2860 / 632 | -16,-402 → -7,141 |
| 43 | trail | anchor_040 (Hollowarch Station, kragmar_blackwind_rise) | joins road 27 | 1445 / 204 | -1003,514 → -815,499 |
| 57 | trail | anchor_056 (Pallcloth Den, kragmar_blackwind_rise) | joins road 29 | 2074 / 1044 | -1253,390 → 21,410 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

