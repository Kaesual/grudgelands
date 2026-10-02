# Gravesalt Escarpment (`front_gravesalt_escarpment`)

Zone 34 · front zone · contested · race region **undead** · levels **51-60** · contested · relief `highland` · seed 42

Map: [maps/front_gravesalt_escarpment.png](maps/front_gravesalt_escarpment.png). Machine-readable: [front_gravesalt_escarpment.json](front_gravesalt_escarpment.json). Coordinates are world nodes (x east, z north, y up).

**Front:** Battlegrounds band around z = 0: Accord comes from -z (south), Throng from +z (north).

## Geometry

| Fact | Value |
|---|---|
| Land extent | x -2528..-1236, z -416..440 (centroid -1944, 3) |
| Land area | 656416 nodes² (≈ 0.66 km²) |
| Hub point (authored) | -2000, 0 |
| Height above sea | min 0, p10 73, median 170, p90 263, max 372 |
| Slope | 62.8% steep (>1 node/node), 24.6% cliff (>2) |
| Biomes (measured) | bone_forest 52.4%, beach 19.1%, blight 15.0%, swamp 12.0%, crags 0.5%, meadows 0.4%, crags_snowy 0.3%, deep_forest 0.2% |
| Neighbours (land border) | elandor_stormvault_heights (1140 nodes, mid -1992,-388), front_broken_causeway (1140 nodes, mid -1380,17), kragmar_blackwind_rise (1328 nodes, mid -1841,342) |
| Sea coast | 1216 nodes of coastline; sea-beach sand 3248 nodes²; lake/river-bank sand 1616 nodes² |
| Water inside | bay 0 nodes², rivers/lakes 121136 nodes² |
| Protected / drift band | 0.3% of land protected (towns, villages, camps/POIs, road corridors); 1.0% within 16 nodes of a road, town or village (aggressive idle mobs drift away, Ruling 2) |

**Sea beaches (sand within ~60 nodes of sea water; ≥ 128 nodes²):**

| Id | Centre | Box | Area | Levels |
|---|---|---|---|---|
| B1 | -2439, -189 | x -2480..-2396, z -216..-168 | 1264 | L54-55 |
| B2 | -2496, 100 | x -2512..-2484, z 60..140 | 896 | L56-59 |
| B3 | -2467, 335 | x -2492..-2440, z 304..352 | 768 | L51-52 |
| B4 | -2405, -238 | x -2416..-2392, z -248..-224 | 224 | L53-54 |

## Levels

Zone field (simple_map.lua zone_level_at): the range split in thirds, rising along z toward the front (or toward the zone middle for front zones); the start bands (L1 <= 100, L2 <= 150 nodes) override near start anchors.

Share of land per level: L51 13.0%, L52 7.6%, L53 7.9%, L54 9.1%, L55 12.1%, L56 12.1%, L57 8.8%, L58 10.0%, L59 10.0%, L60 9.4%

## Anchors

| Id | Kind | Name | x | y | z | Level there | Protected box |
|---|---|---|---|---|---|---|---|
| anchor_076 | clash site | Saltgate Remnant | -2200 | 106 | -80 | 58 | poi x -2208..-2193, z -88..-73 |
| anchor_077 | clash site | Tombroad Ambush | -1768 | 132 | 64 | 58 | poi x -1776..-1761, z 56..71 |

## Protected areas

- poi Saltgate Remnant (anchor_076): x -2208..-2193, z -88..-73
- poi Tombroad Ambush (anchor_077): x -1776..-1761, z 56..71
- Roads: road corridor = half width + 1 node beside the edge after Ruling 1 (today +3), +-5 vertical.

## Hubs, NPCs and current quests

No quest is given in this zone today.

## Mobs by spawn region

Where each species spawns on this seed: the zone's spawn regions (its recipe, built in the engine). Share = of the zone's land cells whose region spawns it at that clock (not a density); levels = the role's range there (crabs: measured on sea-beach sand; gulls: the beach biome).

| Mob | Name | Disposition | Day | Night | Host nodes |
|---|---|---|---|---|---|
| gull | Gull | critter | 125584 nodes² | - | sand |
| last_pay_archer | Last-Pay Archer | aggressive | 17.3% of land, L56-60 | 17.3% of land, L56-60 |  |
| last_watch_husk | Last-Watch Mummy | aggressive | 25.8% of land, L56-60 | - |  |
| last_watch_skeleton_raider | Last-Watch Skeleton Raider | aggressive | - | 71.6% of land, L51-60 |  |
| last_watch_zombie | Last Watchman | aggressive | - | 20.9% of land, L56-60 |  |
| reef_lurker | Reef Lurker | neutral | 3248 nodes², L51-59 | 3248 nodes², L51-59 | sand (dry, within 6 nodes of water) |
| salt_antler_stag | Salt-Antler Gaunt Stag | neutral | 15.1% of land, L51-57 | - |  |
| salt_boring_weevil | Salt-Boring Weevil | aggressive | 11.6% of land, L51-59 | - |  |
| salt_hex_witch | Salt-Hex Bog Witch | aggressive | - | 11.2% of land, L54-60 |  |
| salt_hide_bear | Salt-Hide Plaguehide Bear | aggressive | 45.9% of land, L51-59 | - |  |
| salt_web_spider | Salt-Web Bonelurker Spider | aggressive | - | 50.8% of land, L51-59 |  |
| saltbound_husk | Saltbound Sun-Dried Husk | aggressive | 3.7% of land, L51-55 | - |  |
| saltbound_zombie | Saltbound Zombie | aggressive | - | 7.8% of land, L51-55 |  |
| saltpack_wolf | Saltpack Blightfang Wolf | aggressive | 50.8% of land, L51-59 | - |  |
| saltroad_deserter | Saltroad Deserter | aggressive | 20.5% of land, L51-55 | 20.5% of land, L51-55 |  |
| watchful_carrion_crow | Battlefield Crow | neutral | 9.3% of land, L58-60 | - |  |

## Roads and trails touching the zone

| Id | Kind | From | To | Length (total / in zone) | Enters / leaves zone |
|---|---|---|---|---|---|
| 57 | trail | anchor_056 (Pallcloth Den, kragmar_blackwind_rise) | joins road 29 | 2074 / 238 | -1581,373 → -1255,391 |

Simplified polylines are in the JSON (`roads[].polyline_simplified`, 12-node tolerance).

